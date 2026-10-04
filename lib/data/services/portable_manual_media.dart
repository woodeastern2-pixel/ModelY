import 'dart:convert';
import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';

/// Media restored with knowledge data survives app upgrades without depending
/// on the source device's filesystem paths or bundled asset identifiers.
class PortableManualMedia {
  static Database? database;

  static Future<void> initialize(Database db) async {
    await db.execute('CREATE TABLE IF NOT EXISTS knowledge_media '
        '(id TEXT PRIMARY KEY, bytes BLOB NOT NULL)');
    await db.execute('CREATE TABLE IF NOT EXISTS knowledge_media_links '
        '(entry_id TEXT PRIMARY KEY, images TEXT NOT NULL)');
    database = db;
  }

  static Future<List<Map<String, dynamic>>?> imagesFor(String id) async {
    final db = database;
    if (db == null || !db.isOpen) return null;
    final rows = await db.query('knowledge_media_links',
        where: 'entry_id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return (jsonDecode(rows.single['images'] as String) as List)
        .map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Uint8List?> bytes(String id) async {
    if (!id.startsWith('local-backup-')) return null;
    final db = database;
    if (db == null || !db.isOpen) return null;
    final rows = await db.query('knowledge_media', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Uint8List.fromList(rows.single['bytes'] as List<int>);
  }
}
