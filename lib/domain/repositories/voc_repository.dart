import '../entities/voc_entity.dart';
import '../entities/response_entity.dart';

abstract class VocRepository {
  Future<List<VocEntity>> getAllVocs();
  Future<VocEntity?> getVocById(String id);
  Future<List<VocEntity>> getVocsByStatus(String status);
  Future<List<VocEntity>> getVocsByCategory(String category);
  Future<List<VocEntity>> searchVocs(String query);
  Future<VocEntity> createVoc(VocEntity voc);
  Future<VocEntity> updateVoc(VocEntity voc);
  Future<int> reassignAllVocCategories();
  Future<void> deleteVoc(String id);

  // 통계
  Future<Map<String, int>> getVocCountByStatus();
  Future<Map<String, int>> getVocCountByCategory();
  Future<List<Map<String, dynamic>>> getMonthlyStats();
  Future<Map<String, dynamic>> getAdvancedMetrics();
  Future<List<Map<String, dynamic>>> getTopAssigneeStats({int topN = 3});
  Future<Map<String, dynamic>> getExecutiveInsightMetrics();

  // 답변
  Future<List<ResponseEntity>> getResponsesByVocId(String vocId);
  Future<ResponseEntity> createResponse(ResponseEntity response);
  Future<ResponseEntity> updateResponse(ResponseEntity response);
  Future<void> deleteResponse(String id);
}
