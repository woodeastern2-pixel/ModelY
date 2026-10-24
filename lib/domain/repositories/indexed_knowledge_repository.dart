import 'dart:typed_data';
import '../entities/knowledge_base_entity.dart';

abstract class IndexedKnowledgeRepository {
  Future<List<SimilarVocResult>> searchOffline(String query, {String? excludeVocId});
  Future<void> preserveOriginal({required String fileName, required String fingerprint,
    required Uint8List bytes, required String extractedText,
    required Map<String, Uint8List> images});
}
