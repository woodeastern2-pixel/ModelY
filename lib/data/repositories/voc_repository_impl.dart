import '../datasources/local/voc_local_datasource.dart';
import '../../../domain/entities/voc_entity.dart';
import '../../../domain/entities/response_entity.dart';
import '../../../domain/repositories/voc_repository.dart';

class VocRepositoryImpl implements VocRepository {
  final VocLocalDatasource _localDatasource;

  VocRepositoryImpl(this._localDatasource);

  @override
  Future<List<VocEntity>> getAllVocs() => _localDatasource.getAllVocs();

  @override
  Future<VocEntity?> getVocById(String id) => _localDatasource.getVocById(id);

  @override
  Future<List<VocEntity>> getVocsByStatus(String status) =>
      _localDatasource.getVocsByStatus(status);

  @override
  Future<List<VocEntity>> getVocsByCategory(String category) =>
      _localDatasource.getVocsByCategory(category);

  @override
  Future<List<VocEntity>> searchVocs(String query) =>
      _localDatasource.searchVocs(query);

  @override
  Future<VocEntity> createVoc(VocEntity voc) =>
      _localDatasource.insertVoc(voc);

  @override
  Future<VocEntity> updateVoc(VocEntity voc) =>
      _localDatasource.updateVoc(voc);

  @override
  Future<int> reassignAllVocCategories() =>
      _localDatasource.reassignAllVocCategories();

  @override
  Future<void> deleteVoc(String id) => _localDatasource.deleteVoc(id);

  @override
  Future<Map<String, int>> getVocCountByStatus() =>
      _localDatasource.getVocCountByStatus();

  @override
  Future<Map<String, int>> getVocCountByCategory() =>
      _localDatasource.getVocCountByCategory();

  @override
  Future<List<Map<String, dynamic>>> getMonthlyStats() =>
      _localDatasource.getMonthlyStats();

  @override
  Future<Map<String, dynamic>> getAdvancedMetrics() =>
      _localDatasource.getAdvancedMetrics();

  @override
  Future<List<Map<String, dynamic>>> getTopAssigneeStats({int topN = 3}) =>
      _localDatasource.getTopAssigneeStats(topN: topN);

  @override
  Future<Map<String, dynamic>> getExecutiveInsightMetrics() =>
      _localDatasource.getExecutiveInsightMetrics();

  @override
  Future<List<ResponseEntity>> getResponsesByVocId(String vocId) =>
      _localDatasource.getResponsesByVocId(vocId);

  @override
  Future<ResponseEntity> createResponse(ResponseEntity response) =>
      _localDatasource.insertResponse(response);

  @override
  Future<ResponseEntity> updateResponse(ResponseEntity response) =>
      _localDatasource.updateResponse(response);

  @override
  Future<void> deleteResponse(String id) =>
      _localDatasource.deleteResponse(id);
}
