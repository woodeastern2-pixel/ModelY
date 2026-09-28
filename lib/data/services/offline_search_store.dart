import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../../domain/entities/knowledge_base_entity.dart';
import 'offline_search_index.dart';
import 'original_media_registry.dart';
import 'manual_media_store.dart';
import 'manual_content.dart';
import 'bundled_manual_service.dart';

class OfflineSearchStore {
  final Database db;
  final OfflineSearchIndex index = OfflineSearchIndex();
  final Directory? directory;
  final _contexts = <String, Map<String,dynamic>>{};
  final _sourceSections = <String, Set<String>>{};
  Future<void>? _updating;
  Timer? _timer;
  static final _instances = Expando<OfflineSearchStore>();
  static OfflineSearchStore forDatabase(Database db) =>
      _instances[db] ??= OfflineSearchStore(db);
  OfflineSearchStore(this.db, {this.directory});

  Future<void> initialize({bool bundled = true, bool maintenance = true}) async {
    await db.execute('CREATE TABLE IF NOT EXISTS offline_records (id TEXT PRIMARY KEY, record TEXT NOT NULL, tokens TEXT NOT NULL)');
    await db.execute('CREATE TABLE IF NOT EXISTS original_documents (id TEXT PRIMARY KEY, name TEXT NOT NULL, fingerprint TEXT NOT NULL, original_path TEXT, content TEXT NOT NULL)');
    await db.execute('CREATE TABLE IF NOT EXISTS offline_dirty (kind TEXT NOT NULL, id TEXT NOT NULL, revision INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(kind,id))');
    await db.execute('CREATE TABLE IF NOT EXISTS offline_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
    for (final table in ['knowledge_base', 'responses', 'vocs']) {
      for (final event in ['INSERT', 'UPDATE', 'DELETE']) {
        final ref = event == 'DELETE' ? 'OLD' : 'NEW';
        final kind = table == 'knowledge_base' ? 'kb' : 'voc';
        final column = table == 'responses' ? 'voc_id' : 'id';
        await db.execute('CREATE TRIGGER IF NOT EXISTS offline_${table}_${event.toLowerCase()} AFTER $event ON $table BEGIN INSERT OR REPLACE INTO offline_dirty(kind,id,revision) VALUES (\'$kind\',$ref.$column,COALESCE((SELECT revision FROM offline_dirty WHERE kind=\'$kind\' AND id=$ref.$column),0)+1); END');
      }
    }
    final installed = await db.query('offline_meta', where: 'key = ?', whereArgs: ['version']);
    if (installed.isEmpty) {
      if (bundled) {
        final manifest = jsonDecode(await rootBundle.loadString('assets/manuals/originals/manifest.json')) as List;
        for (final doc in manifest) {
          final parts = <Map<String,dynamic>>[];
          for(final file in doc['files'] as List) {
            parts.add(jsonDecode(await rootBundle.loadString('assets/manuals/originals/$file')) as Map<String,dynamic>);
          }
          await installOriginal({...parts.first, 'blocks':[for(final part in parts) ...part['blocks'] as List]});
        }
      }
      await db.execute("INSERT OR IGNORE INTO offline_dirty(kind,id) SELECT 'kb',id FROM knowledge_base");
      await db.execute("INSERT OR IGNORE INTO offline_dirty(kind,id) SELECT 'voc',id FROM vocs");
      await refresh();
      await db.insert('offline_meta', {'key':'version','value':'1'});
    } else {
      for (final row in await db.query('offline_records')) {
        _load(jsonDecode(row['record'] as String) as Map<String, dynamic>,
            (jsonDecode(row['tokens'] as String) as List).cast<String>());
      }
      for(final row in await db.query('original_documents',columns:['content'])) {
        _prepareContexts(jsonDecode(row['content'] as String) as Map<String,dynamic>);
      }
      await refresh();
    }
    if (maintenance) _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (db.isOpen) { unawaited(refresh().catchError((Object _) {})); } else { _timer?.cancel(); }
    });
  }

  void dispose() { _timer?.cancel(); }

  void _load(Map<String, dynamic> r, List<String> tokens) {
    final now = DateTime(2026);
    index.put(KnowledgeBaseEntity(id:r['id'] as String, question:r['title'] as String,
      answer:r['body'] as String, category:r['category'] as String? ?? '시스템매뉴얼',
      customer:r['source'] as String?, project:r['project'] as String?, vocId:r['vocId'] as String?,
      createdAt:now, resolvedAt:now), keys:tokens);
    if (r['images'] is List) {
      OriginalMediaRegistry.images[r['id'] as String] = (r['images'] as List)
          .map((e) => Map<String,dynamic>.from(e as Map)).toList();
    }
  }

  Future<void> _putMany(List<Map<String,dynamic>> rows) async {
    // Tokenization runs away from the interface. It is done on document/data
    // changes, never as a whole-corpus operation in the answer path.
    final encoded = await Isolate.run(() => rows.map((r) => <String,dynamic>{
      'row':r, 'tokens':OfflineSearchIndex.keysFor('${r['title']} ${r['body']}').toList(),
    }).toList());
    final batch = db.batch();
    for (final item in encoded) {
      final row = item['row'] as Map<String,dynamic>;
      batch.insert('offline_records', {'id':row['id'],'record':jsonEncode(row),'tokens':jsonEncode(item['tokens'])}, conflictAlgorithm:ConflictAlgorithm.replace);
    }
    await batch.commit(noResult:true);
    for (final item in encoded) _load(item['row'] as Map<String,dynamic>, (item['tokens'] as List).cast<String>());
  }

  void _prepareContexts(Map<String,dynamic> document) {
    final groups=<Object?,List<Map<String,dynamic>>>{};
    for(final raw in document['blocks'] as List) {
      final block=Map<String,dynamic>.from(raw as Map);
      (groups[block['section']] ??= []).add(block);
    }
    for(final group in groups.values) {
      final text=group.map((b)=>b['text'] as String).where((s)=>s.trim().isNotEmpty).join('\n\n');
      final ocr=group.map((b)=>b['ocr'] as String? ?? '').where((s)=>s.trim().isNotEmpty).join('\n');
      final images=<String,Map<String,dynamic>>{};
      for(final block in group) {
        for(final raw in block['images'] as List? ?? []) {
          final image=Map<String,dynamic>.from(raw as Map);images[image['id'] as String]=image;
        }
      }
      final identity=jsonEncode([document['id'],document['sha256'],group.first['section']]);
      final source='${document['filename']} · ${group.first['title']}';
      (_sourceSections[source] ??= <String>{}).add(identity);
      final context=<String,dynamic>{'title':group.first['title'],
        'identity':identity,'source':source,
        'body':'$text${ocr.isEmpty ? '' : '\n\n[이미지에서 읽은 글자: 원본 대조 필요]\n$ocr'}\n\n[출처] ${document['filename']} · ${group.first['title']}',
        'images':images.values.toList()};
      for(final block in group) {
        _contexts[block['id'] as String]=context;
      }
    }
  }

  Future<void> installOriginal(Map<String,dynamic> document, {String? originalPath}) async {
    final id = document['id'] as String;
    final blocks = (document['blocks'] as List).cast<Map<String,dynamic>>();
    final rows = <Map<String,dynamic>>[];
    for (var i=0;i<blocks.length;i++) {
      final block = blocks[i];
      final context = <Map<String,dynamic>>[];
      for (var j=i-1;j<=i+2;j++) {
        if(j>=0 && j<blocks.length && blocks[j]['section']==block['section']) context.add(blocks[j]);
      }
      final text=context.map((b)=>b['text'] as String).where((s)=>s.trim().isNotEmpty).join('\n\n');
      final ocr=context.map((b)=>b['ocr'] as String? ?? '').where((s)=>s.trim().isNotEmpty).join('\n');
      final images=<String,Map<String,dynamic>>{};
      for(final b in context) {
        for(final raw in b['images'] as List? ?? []) {
          final image=Map<String,dynamic>.from(raw as Map); images[image['id'] as String]=image;
        }
      }
      // OCR contributes searchable evidence, explicitly labelled as unverified.
      final body='$text${ocr.isEmpty ? '' : '\n\n[이미지에서 읽은 글자: 원본 대조 필요]\n$ocr'}\n\n[출처] ${document['filename']} · 원문 구간 ${block['ordinal']}';
      rows.add({'id':block['id'],'title':'${block['title']} · 원문 구간 ${block['ordinal']}',
        'body':body,'source':'${document['filename']} · 원문 ${document['sha256'].toString().substring(0,8)}','project':document['project'],
        'documentId':id,'images':images.values.toList()});
    }
    await _putMany(rows);
    _prepareContexts(document);
    await db.insert('original_documents', {'id':id,'name':document['filename'],
      'fingerprint':document['sha256'],'original_path':originalPath,'content':jsonEncode(document)}, conflictAlgorithm:ConflictAlgorithm.replace);
  }

  Future<void> preserveOriginal({required String fileName, required String fingerprint,
    required Uint8List bytes, required String extractedText, required Map<String,Uint8List> images}) async {
    final root=directory ?? Directory(p.join((await getApplicationSupportDirectory()).path,'original_manuals'));
    await root.create(recursive:true);
    final file=File(p.join(root.path,'$fingerprint${p.extension(fileName)}'));
    if(!await file.exists()) await file.writeAsBytes(bytes,flush:true);
    await ManualMediaStore(directory:directory == null ? null : Directory(p.join(root.path,'media'))).save('manual-source-$fingerprint',images);
    final paragraphs=extractedText.split(RegExp(r'\n\s*\n')).where((s)=>s.trim().isNotEmpty).toList();
    final blocks=<Map<String,dynamic>>[];
    var section=0;
    var sectionLength=0;
    for(var i=0;i<paragraphs.length;i++) {
      final ids=RegExp(r'\[manual-image:([a-z0-9-]+)\]').allMatches(paragraphs[i]).map((m)=>m.group(1)!);
      if(sectionLength+paragraphs[i].length>2400 || paragraphs[i].startsWith('[페이지 ')) {section++;sectionLength=0;}
      sectionLength+=paragraphs[i].length;
      blocks.add({'id':'raw-$fingerprint-$i','title':fileName,'ordinal':i,'section':section,
        'text':paragraphs[i].replaceAll(RegExp(r'\[manual-image:[a-z0-9-]+\]'),''),
        'ocr':'','images':[for(final id in ids) {'id':id,'kind':'imported'}]});
    }
    await installOriginal({'id':fingerprint,'filename':fileName,'sha256':fingerprint,
      'project':'manual-upload','blocks':blocks},originalPath:file.path);
  }

  Future<void> refresh() => _updating ??= _refresh().whenComplete(()=>_updating=null);
  Future<void> _refresh() async {
    // Revision guards preserve changes arriving while a snapshot is indexed.
    final dirty=await db.query('offline_dirty');
    try {
      final records=<Map<String,dynamic>>[];
      for(final change in dirty) {
        final id=change['id'] as String;
        if(change['kind']=='kb') {
          final rows=await db.query('knowledge_base',where:'id = ?',whereArgs:[id]);
          index.remove(id); await db.delete('offline_records',where:'id = ?',whereArgs:[id]);
          if(rows.isNotEmpty) { final r=rows.first;
            records.add({'id':id,'title':r['question'],'body':r['answer'],'category':r['category'],
              'source':r['customer'],'project':r['project'],'vocId':r['voc_id']});
          }
        } else {
          final key='approved-index-$id';
          index.remove(key); await db.delete('offline_records',where:'id = ?',whereArgs:[key]);
          final rows=await db.rawQuery("SELECT v.title,v.content,v.category,v.customer,v.project,r.content AS answer FROM vocs v JOIN responses r ON r.voc_id=v.id WHERE v.id=? AND r.status='APPROVED' ORDER BY r.updated_at DESC LIMIT 1",[id]);
          if(rows.isNotEmpty) {final r=rows.first;
            records.add({'id':key,'title':'${r['title']} ${r['content']}','body':r['answer'],
              'category':r['category'],'source':r['customer'],'project':r['project'],'vocId':id});
          }
        }
      }
      if(records.isNotEmpty) await _putMany(records);
      final batch=db.batch();
      for(final row in dirty) {
        batch.delete('offline_dirty',where:'kind=? AND id=? AND revision=?',
            whereArgs:[row['kind'],row['id'],row['revision']]);
      }
      await batch.commit(noResult:true);
    } catch (_) { rethrow; }
  }

  Future<List<SimilarVocResult>> search(String query,{String? excludeVocId}) async {
    // Registration and background maintenance prepare the index. A bulk update
    // must not become a multi-second full rebuild inside an answer request.
    final pending=Sqflite.firstIntValue(await db.rawQuery('SELECT count(*) FROM offline_dirty')) ?? 0;
    if(pending>32) {
      unawaited(refresh().catchError((Object _) {}));
      throw StateError('새 자료의 검색 색인을 준비 중입니다. 등록 완료 후 다시 질문해 주세요.');
    }
    if(_updating!=null) await _updating!.timeout(const Duration(seconds:2));
    await refresh().timeout(const Duration(seconds:2));
    final matches=index.search(query,excludeVocId:excludeVocId);
    final expanded=matches.map((r) {
      final e=r.knowledgeBase;
      final context=_contexts[e.id];
      if(context==null) return r;
      OriginalMediaRegistry.images[e.id]=(context['images'] as List).cast<Map<String,dynamic>>();
      return SimilarVocResult(knowledgeBase:KnowledgeBaseEntity(
        id:e.id,question:'원문 · ${context['title']}',answer:context['body'] as String,
        category:e.category,customer:e.customer,project:e.project,
        resolvedAt:e.resolvedAt,createdAt:e.createdAt),similarityScore:r.similarityScore);
    }).toList();
    return _distinctReferences(expanded);
  }

  // Search every indexed passage as before. Consolidate only after expanding
  // hits to complete sections, so distant restrictions and images survive.
  Future<List<SimilarVocResult>> _distinctReferences(
      List<SimilarVocResult> matches) async {
    final rawGroups=<String,SimilarVocResult>{};
    final sources=<String,List<String>>{};
    for(final result in matches) {
      final context=_contexts[result.knowledgeBase.id];
      if(context==null) continue;
      final key=context['identity'] as String;
      final previous=rawGroups[key];
      if(previous==null) {
        rawGroups[key]=result;
        (sources[context['source'] as String] ??= []).add(key);
      } else if(result.similarityScore>previous.similarityScore) {
        rawGroups[key]=result;
      }
    }
    final output=<String,SimilarVocResult>{};
    for(final result in matches) {
      final entry=result.knowledgeBase;
      final context=_contexts[entry.id];
      String? group=context?['identity'] as String?;
      if(group==null && entry.vocId==null) {
        final source=_sourceOf(entry.answer);
        final candidates=sources[source];
        // A filename/title alone cannot distinguish versions or repeated headings.
        if(candidates?.length==1 && _sourceSections[source]?.length==1) {
          final key=candidates!.single;
          final original=rawGroups[key]!.knowledgeBase;
          if(entry.project==original.project && _covered(entry.answer,original.answer)) {
            final available=(OriginalMediaRegistry.images[original.id] ?? [])
                .map((image)=>image['id']).toSet();
            try {
              final images=await BundledManualService.imagesFor(entry.id);
              if(images.every((image)=>available.contains(image['id']))) group=key;
            } catch (_) {
              // If attachment coverage cannot be verified, retain the entry.
            }
          }
        }
      }
      final key=group==null ? 'entry:${entry.id}' : 'section:$group';
      final representative=group==null ? result : rawGroups[group]!;
      final previous=output[key];
      final score=[result.similarityScore,representative.similarityScore,
        if(previous!=null) previous.similarityScore].reduce((a,b)=>a>b?a:b);
      output[key]=SimilarVocResult(knowledgeBase:representative.knowledgeBase,
        similarityScore:score,adoptionCount:representative.adoptionCount,
        usageCount:representative.usageCount,lastUsedAt:representative.lastUsedAt);
    }
    return output.values.toList();
  }

  static String? _sourceOf(String text) {
    final position=text.lastIndexOf('[출처]');
    return position<0 ? null : text.substring(position+4).trim();
  }

  static bool _covered(String candidate,String original) {
    final a=ManualContent.parse(candidate), b=ManualContent.parse(original);
    String normalize(String value)=>value.replaceAll(RegExp(r'\s+'),'');
    bool includes(String shorter,String longer) {
      final full=normalize(longer.split('[출처]').first);
      final lines=shorter.split('[출처]').first.split('\n')
          .map(normalize).where((line)=>line.isNotEmpty);
      return lines.every(full.contains);
    }
    return includes(a.body,b.body) && includes(a.transcription,b.transcription);
  }
}


