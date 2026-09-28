import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'support/ui_harness.dart';
import 'package:ai_voc_assistant/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ai_voc_assistant/core/utils/search_query_expander.dart';
import 'package:ai_voc_assistant/data/services/bundled_manual_service.dart';
import 'package:ai_voc_assistant/data/seeds/brity_suite_manual_seed.dart';
import 'package:ai_voc_assistant/domain/entities/knowledge_base_entity.dart';
import 'package:ai_voc_assistant/domain/repositories/knowledge_base_repository.dart';
import 'package:ai_voc_assistant/domain/repositories/settings_repository.dart';
import 'package:ai_voc_assistant/presentation/viewmodels/settings_viewmodel.dart';
import 'package:ai_voc_assistant/presentation/viewmodels/knowledge_base_viewmodel.dart';
import 'package:ai_voc_assistant/presentation/screens/knowledge_base/knowledge_base_screen.dart';

void main() {
  setUpAll(loadUiHarnessFonts);
  test('prepared matching preserves Korean English aliases and all query terms', () {
    for (final query in ['미팅 개설', 'meeting 개설', '드라이브', '메신저', 'mail', '미팅', '']) {
      for (final body in ['Brity Meeting 회의 개설', '미팅 개설은 메신저에서',
          'Brity Drive', 'Brity Messenger', 'email 메일', '메일 개설', 'meeting 일정']) {
        expect(SearchQueryExpander.compile(query).matchesNormalized(SearchQueryExpander.normalize(body)),
            SearchQueryExpander.matches(query, body), reason: '$query / $body');
      }
    }
  });
  testWidgets('typing over 1008 full bodies stays local and filters once after a pause', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pack = await tester.runAsync(BundledManualService.load);
    final rows = [...BritySuiteManualSeed.entries, ...pack!['entries'] as List];
    final entries = rows.map((r) => KnowledgeBaseEntity(id:r['id'] as String,
      question:r['question'] as String, answer:r['answer'] as String,
      category:'시스템매뉴얼', customer:r['sourceName'] as String?, project:r['project'] as String?,
      createdAt:DateTime(2026), resolvedAt:DateTime(2026))).toList();
    final settings = SettingsViewModel(_Settings());
    late KnowledgeBaseViewModel vm;
    await tester.runAsync(() async {
      vm = KnowledgeBaseViewModel(_Repository(entries), settings);
      await vm.ready;
    });
    addTearDown(vm.dispose);
    addTearDown(settings.dispose);

    expect(vm.entries.length,1008);
    final boundary = GlobalKey();
    await tester.pumpWidget(ChangeNotifierProvider.value(value:vm,
      child:MaterialApp(theme:AppTheme.lightTheme, home:RepaintBoundary(key:boundary, child:const KnowledgeBaseScreen()))));
    await tester.pumpAndSettle();
    final initial = vm.searchPasses;
    final costs = <double>[];
    for (final value in ['미','미팅','미팅 ','미팅 개','미팅 개설']) {
      final watch = Stopwatch()..start();
      await tester.enterText(find.byType(TextField), value);
      await tester.pump(const Duration(milliseconds:30));
      watch.stop(); costs.add(watch.elapsedMicroseconds/1000);
      expect(vm.searchPasses, initial);
      expect(find.widgetWithText(TextField,value), findsOneWidget);
    }
    final watch = Stopwatch()..start();
    await tester.pump(const Duration(milliseconds:200));
    watch.stop();
    expect(vm.searchPasses, initial+1);
    expect(vm.entries.any((e)=>e.answer.contains('즉시시작')), isTrue);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final image = await (boundary.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage();
      final bytes = await image.toByteData(format:ui.ImageByteFormat.png);
      final file = File('test/goldens/knowledge-search-phone.png');
      await file.parent.create(recursive:true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    final cached = vm.entries;
    for(var i=0;i<1000;i++) { expect(identical(vm.entries,cached),isTrue); }
    expect(vm.searchPasses,initial+1);
    final removed=vm.entries.first.id;
    await vm.deleteEntry(removed);
    expect(vm.entries.any((e)=>e.id==removed),isFalse);
    vm.setSearch('미팅');
    vm.setSearch('');
    await tester.pump(const Duration(milliseconds:250));
    expect(vm.entries.length,1007);
    expect(tester.takeException(),isNull);
    await tester.runAsync(() async {
      final file=File('test/goldens/knowledge-input-performance.json');
      await file.parent.create(recursive:true);
      await file.writeAsString(jsonEncode({'entries':1008,'typingAndPumpMilliseconds':costs,
        'filterAndPumpMilliseconds':watch.elapsedMicroseconds/1000,
        'debounceMilliseconds':180,'environment':'Linux Flutter widget test; not device frame timings'}));
    });
  });
  testWidgets('disposing cancels pending query notifications', (tester) async {
    final settings=SettingsViewModel(_Settings());
    final vm=KnowledgeBaseViewModel(_Repository([]),settings);
    await tester.pump();
    vm.setSearch('미팅');vm.dispose();settings.dispose();
    await tester.pump(const Duration(milliseconds:250));
    expect(tester.takeException(),isNull);
  });
}
class _Repository implements KnowledgeBaseRepository {
  final List<KnowledgeBaseEntity> values;
  _Repository(this.values);
  @override
  Future<List<KnowledgeBaseEntity>> getAllEntries() async => values;
  @override
  Future<void> deleteEntry(String id) async {}
  @override
  dynamic noSuchMethod(Invocation i)=>super.noSuchMethod(i);
}
class _Settings implements SettingsRepository {
  @override
  Future<Map<String,String>> getAllSettings() async=>{};
  @override
  dynamic noSuchMethod(Invocation i)=>super.noSuchMethod(i);
}
