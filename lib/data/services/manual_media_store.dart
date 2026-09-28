import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Durable offline media for documents imported on this device.
class ManualMediaStore {
  final Directory? directory;
  const ManualMediaStore({this.directory});

  Future<Directory> _root() async {
    final root = directory ?? Directory(p.join(
        (await getApplicationSupportDirectory()).path, 'manual_media'));
    await root.create(recursive: true);
    return root;
  }

  static bool _valid(String id) => RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id);

  Future<void> save(String entryId, Map<String, Uint8List> images) async {
    if (images.isEmpty) return;
    if (!_valid(entryId) || images.keys.any((id) => !_valid(id))) {
      throw const FormatException('잘못된 이미지 식별자입니다.');
    }
    final root = await _root();
    for (final image in images.entries) {
      final file = File(p.join(root.path, '${image.key}.media'));
      if (!await file.exists()) await file.writeAsBytes(image.value, flush: true);
    }
    final manifest = File(p.join(root.path, '$entryId.json'));
    final temporary = File('${manifest.path}.tmp');
    await temporary.writeAsString(jsonEncode(images.keys.toList()), flush: true);
    if (await manifest.exists()) await manifest.delete();
    await temporary.rename(manifest.path);
  }

  Future<List<Map<String, dynamic>>> imagesFor(String entryId) async {
    if (!entryId.startsWith('manual-source-') || !_valid(entryId)) return [];
    final file = File(p.join((await _root()).path, '$entryId.json'));
    if (!await file.exists()) return [];
    final ids = (jsonDecode(await file.readAsString()) as List).cast<String>();
    return ids.map((id) => <String, dynamic>{'id': id, 'kind': 'imported'}).toList();
  }

  Future<Uint8List> imageBytes(String id) async {
    if (!id.startsWith('local-') || !_valid(id)) {
      throw const FormatException('잘못된 이미지 식별자입니다.');
    }
    return File(p.join((await _root()).path, '$id.media')).readAsBytes();
  }
}
