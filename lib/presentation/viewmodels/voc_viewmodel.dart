import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/database/database_helper.dart';
import '../../core/utils/voc_category_catalog.dart';
import '../../core/utils/vector_utils.dart';
import '../../domain/entities/voc_entity.dart';
import '../../domain/entities/response_entity.dart';
import '../../domain/repositories/voc_repository.dart';
import '../../data/services/ai_service.dart';

class VocViewModel extends ChangeNotifier {
  final VocRepository _repository;
  final _uuid = const Uuid();

  List<VocEntity> _vocs = [];
  VocEntity? _selectedVoc;
  List<ResponseEntity> _responses = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String _filterStatus = '';
  String _filterCategory = '';
  bool _isBulkAutoClassifying = false;
  bool _isBulkRecategorizing = false;
  bool _isBulkAutoResolving = false;
  bool _bulkAutoResolveStopRequested = false;
  final Map<String, Future<VocEntity>> _pendingVocCreates = {};

  VocViewModel(this._repository) {
    loadVocs();
  }

  List<VocEntity> get vocs => _filteredVocs;
  int get pendingVocCount => _vocs
      .where(
        (voc) =>
            voc.status == AppConstants.vocStatusOpen ||
            voc.status == AppConstants.vocStatusInProgress,
      )
      .length;
  List<VocEntity> get allVocs => _vocs;
  VocEntity? get selectedVoc => _selectedVoc;
  List<ResponseEntity> get responses => _responses;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String get filterStatus => _filterStatus;
  String get filterCategory => _filterCategory;
  bool get isBulkRecategorizing => _isBulkRecategorizing;
  bool get isBulkAutoResolving => _isBulkAutoResolving;
  bool get bulkAutoResolveStopRequested => _bulkAutoResolveStopRequested;

  void stopBulkAutoResolve() {
    if (!_isBulkAutoResolving) return;
    _bulkAutoResolveStopRequested = true;
    notifyListeners();
  }

  List<VocEntity> get _filteredVocs {
    var list = _vocs;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((v) =>
              v.title.toLowerCase().contains(q) ||
              v.content.toLowerCase().contains(q) ||
              v.customer.toLowerCase().contains(q) ||
              v.project.toLowerCase().contains(q))
          .toList();
    }
    if (_filterStatus.isNotEmpty) {
      list = list.where((v) => v.status == _filterStatus).toList();
    }
    if (_filterCategory.isNotEmpty) {
      list = list.where((v) => v.category == _filterCategory).toList();
    }
    return list;
  }

  Future<void> loadVocs() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _vocs = await _repository.getAllVocs();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectVoc(String id) async {
    _selectedVoc =
        _vocs.firstWhere((v) => v.id == id, orElse: () => _vocs.first);
    await loadResponsesForVoc(id);
    notifyListeners();
  }

  Future<void> loadResponsesForVoc(String vocId) async {
    _responses = await _repository.getResponsesByVocId(vocId);
    notifyListeners();
  }

  Future<VocEntity> createVoc({
    required String title,
    required String content,
    required String category,
    String? tags,
    String? customer,
    String? project,
    String? businessType,
    required String priority,
  }) {
    final requestKey = [
      title.trim().toLowerCase(),
      content.trim().toLowerCase(),
      customer?.trim().toLowerCase() ?? '',
      project?.trim().toLowerCase() ?? '',
    ].join('\u001f');
    final pending = _pendingVocCreates[requestKey];
    if (pending != null) return pending;

    final operation = _createVoc(
      title: title,
      content: content,
      category: category,
      tags: tags,
      customer: customer,
      project: project,
      businessType: businessType,
      priority: priority,
    );
    _pendingVocCreates[requestKey] = operation;
    operation.then<void>(
      (_) {
        _pendingVocCreates.remove(requestKey);
      },
      onError: (Object _, StackTrace __) {
        _pendingVocCreates.remove(requestKey);
      },
    );
    return operation;
  }

  Future<VocEntity> _createVoc({
    required String title,
    required String content,
    required String category,
    String? tags,
    String? customer,
    String? project,
    String? businessType,
    required String priority,
  }) async {
    final now = DateTime.now();
    final normalizedCategory = VocCategoryCatalog.normalize(
      category,
      title: title,
      content: content,
      tags: tags,
    );
    final voc = VocEntity(
      id: _uuid.v4(),
      title: title,
      content: content,
      category: normalizedCategory,
      tags: tags,
      customer: customer?.trim().isEmpty == true
          ? '미입력'
          : (customer?.trim().isNotEmpty == true ? customer!.trim() : '미입력'),
      project: project?.trim().isEmpty == true
          ? '미입력'
          : (project?.trim().isNotEmpty == true ? project!.trim() : '미입력'),
      businessType:
          businessType?.trim().isNotEmpty == true ? businessType!.trim() : null,
      priority: priority,
      status: AppConstants.vocStatusOpen,
      embedding: VectorUtils.simpleTextEmbedding('$title $content'),
      createdAt: now,
      updatedAt: now,
    );
    final created = await _repository.createVoc(voc);
    _vocs.insert(0, created);
    notifyListeners();
    return created;
  }

  Future<int> autoClassifyAllVocs({
    required Future<VocIntelligenceResult?> Function(
            String title, String content)
        analyzer,
    bool forceReanalyze = true,
  }) async {
    if (_isBulkAutoClassifying) return 0;

    _isBulkAutoClassifying = true;
    var updatedCount = 0;
    try {
      final allVocs = await _repository.getAllVocs();
      for (final voc in allVocs) {
        if (!forceReanalyze && voc.aiCategory?.trim().isNotEmpty == true) {
          continue;
        }

        final intelligence = await analyzer(voc.title, voc.content);
        if (intelligence == null) {
          continue;
        }

        final updated = voc.copyWith(
          category: VocCategoryCatalog.normalize(
            intelligence.category,
            title: voc.title,
            content: voc.content,
            aiCategory: intelligence.category,
            tags: voc.tags,
          ),
          tags: _buildAutoTags(voc, intelligence),
          priority: _priorityFromUrgency(intelligence.urgency),
          isBusinessRelated: intelligence.isBusiness,
          aiCategory: intelligence.category,
          businessScore: intelligence.businessScore,
          categoryScore: intelligence.categoryScore,
          urgency: intelligence.urgency,
          urgencyScore: intelligence.urgencyScore,
          department: intelligence.department,
          departmentScore: intelligence.departmentScore,
          assignee: intelligence.assignee,
          assigneeScore: intelligence.assigneeScore,
          duplicateOfVocId: intelligence.duplicateOfVocId,
          duplicateScore: intelligence.duplicateScore,
          jiraRequired: intelligence.jiraRequired,
          jiraScore: intelligence.jiraScore,
          analysisReason: intelligence.reason,
          status: intelligence.isBusiness
              ? voc.status
              : AppConstants.vocStatusRejected,
          updatedAt: DateTime.now(),
        );
        await _repository.updateVoc(updated);
        updatedCount++;
      }

      if (updatedCount > 0) {
        _vocs = await _repository.getAllVocs();
        notifyListeners();
      }
      return updatedCount;
    } finally {
      _isBulkAutoClassifying = false;
    }
  }

  Future<void> updateVocStatus(String id, String status) async {
    final idx = _vocs.indexWhere((v) => v.id == id);
    if (idx == -1) return;
    final updated = _vocs[idx].copyWith(
      status: status,
      updatedAt: DateTime.now(),
    );
    await _repository.updateVoc(updated);
    _vocs[idx] = updated;
    if (_selectedVoc?.id == id) _selectedVoc = updated;
    notifyListeners();
  }

  Future<void> updateVocFields(
    String id, {
    required String title,
    required String content,
    required String category,
    String? tags,
    String? customer,
    String? project,
    required String priority,
  }) async {
    final idx = _vocs.indexWhere((v) => v.id == id);
    if (idx == -1) return;

    final updated = _vocs[idx].copyWith(
      title: title,
      content: content,
      category: VocCategoryCatalog.normalize(
        category,
        title: title,
        content: content,
        tags: tags,
      ),
      tags: tags,
      customer: customer?.trim().isEmpty == true
          ? '미입력'
          : (customer?.trim().isNotEmpty == true ? customer!.trim() : '미입력'),
      project: project?.trim().isEmpty == true
          ? '미입력'
          : (project?.trim().isNotEmpty == true ? project!.trim() : '미입력'),
      priority: priority,
      updatedAt: DateTime.now(),
    );

    await _repository.updateVoc(updated);
    _vocs[idx] = updated;
    if (_selectedVoc?.id == id) _selectedVoc = updated;
    notifyListeners();
  }

  Future<int> reassignAllVocCategories() async {
    if (_isBulkRecategorizing) return 0;

    _isBulkRecategorizing = true;
    notifyListeners();

    try {
      final updatedCount = await _repository.reassignAllVocCategories();
      _vocs = await _repository.getAllVocs();
      if (_selectedVoc != null) {
        for (final voc in _vocs) {
          if (voc.id == _selectedVoc!.id) {
            _selectedVoc = voc;
            break;
          }
        }
      }
      notifyListeners();
      return updatedCount;
    } finally {
      _isBulkRecategorizing = false;
      notifyListeners();
    }
  }

  Future<BulkAiResolveSummary> autoResolvePendingWithAi({
    required Future<void> Function(String query) prepareSimilarCases,
    required Future<AiAnswerResult?> Function(String title, String content)
        generateAnswer,
    Future<void> Function(VocEntity voc, ResponseEntity response)?
        onResponseApproved,
    Future<void> Function(VocEntity voc)? onStatusChanged,
  }) async {
    if (_isBulkAutoResolving) {
      return const BulkAiResolveSummary();
    }

    _isBulkAutoResolving = true;
    _bulkAutoResolveStopRequested = false;
    notifyListeners();

    var targetCount = 0;
    var generatedCount = 0;
    var reusedApprovedCount = 0;
    var reusedAiCount = 0;
    var resolvedCount = 0;
    var skippedCount = 0;
    var failedCount = 0;
    var syncedCount = 0;
    var syncFailedCount = 0;
    var stopped = false;

    try {
      final allVocs = await _repository.getAllVocs();
      final pendingVocs = allVocs
          .where(
            (voc) =>
                voc.status == AppConstants.vocStatusOpen ||
                voc.status == AppConstants.vocStatusInProgress,
          )
          .toList();
      targetCount = pendingVocs.length;

      for (final voc in pendingVocs) {
        if (_bulkAutoResolveStopRequested) {
          stopped = true;
          break;
        }
        try {
          final responses = await _repository.getResponsesByVocId(voc.id);
          final retainedAiResponse = await _retainSingleAiResponse(responses);
          final hasApproved = responses.any(
            (r) => r.status == AppConstants.responseApproved,
          );

          if (hasApproved) {
            reusedApprovedCount += 1;
          } else if (retainedAiResponse != null) {
            final approvedResponse = await adoptAiAnswer(
              vocId: voc.id,
              content: retainedAiResponse.content,
              confidence: retainedAiResponse.confidenceScore,
              referencedVocIds: retainedAiResponse.referencedVocIds,
              responseId: retainedAiResponse.id,
            );
            reusedAiCount += 1;
            if (approvedResponse != null && onResponseApproved != null) {
              try {
                await onResponseApproved(voc, approvedResponse);
                syncedCount += 1;
              } catch (_) {
                syncFailedCount += 1;
              }
            }
          } else {
            await prepareSimilarCases('${voc.title} ${voc.content}');
            if (_bulkAutoResolveStopRequested) {
              stopped = true;
              break;
            }
            final aiAnswer = await generateAnswer(voc.title, voc.content);
            if (_bulkAutoResolveStopRequested) {
              stopped = true;
              break;
            }
            final answerText = aiAnswer?.answer.trim() ?? '';

            if (answerText.isEmpty) {
              skippedCount += 1;
              continue;
            }

            final approvedResponse = await adoptAiAnswer(
              vocId: voc.id,
              content: answerText,
              confidence: aiAnswer?.confidence,
              referencedVocIds: aiAnswer?.referencedCases,
            );

            if (approvedResponse != null && onResponseApproved != null) {
              try {
                await onResponseApproved(voc, approvedResponse);
                syncedCount += 1;
              } catch (_) {
                syncFailedCount += 1;
              }
            }

            generatedCount += 1;
          }

          if (voc.status != AppConstants.vocStatusResolved) {
            await updateVocStatus(voc.id, AppConstants.vocStatusResolved);
            if (onStatusChanged != null) {
              final updatedVoc = _vocs.firstWhere(
                (item) => item.id == voc.id,
                orElse: () => voc.copyWith(
                  status: AppConstants.vocStatusResolved,
                  updatedAt: DateTime.now(),
                ),
              );
              try {
                await onStatusChanged(updatedVoc);
                syncedCount += 1;
              } catch (_) {
                syncFailedCount += 1;
              }
            }
            resolvedCount += 1;
          }
        } catch (_) {
          failedCount += 1;
        }
      }

      _vocs = await _repository.getAllVocs();
      if (_selectedVoc != null) {
        final selectedId = _selectedVoc!.id;
        final selected = _vocs.where((v) => v.id == selectedId);
        _selectedVoc = selected.isEmpty ? null : selected.first;
      }
      notifyListeners();

      return BulkAiResolveSummary(
        targetCount: targetCount,
        generatedCount: generatedCount,
        reusedApprovedCount: reusedApprovedCount,
        reusedAiCount: reusedAiCount,
        resolvedCount: resolvedCount,
        skippedCount: skippedCount,
        failedCount: failedCount,
        syncedCount: syncedCount,
        syncFailedCount: syncFailedCount,
        stopped: stopped || _bulkAutoResolveStopRequested,
      );
    } finally {
      _isBulkAutoResolving = false;
      _bulkAutoResolveStopRequested = false;
      notifyListeners();
    }
  }

  Future<ResponseEntity?> _retainSingleAiResponse(
      List<ResponseEntity> responses) async {
    final aiResponses = responses.where((response) => response.aiGenerated).toList()
      ..sort((a, b) {
        final approvedOrder = (b.isApproved ? 1 : 0) - (a.isApproved ? 1 : 0);
        return approvedOrder != 0
            ? approvedOrder
            : b.updatedAt.compareTo(a.updatedAt);
      });
    if (aiResponses.isEmpty) return null;

    final retained = aiResponses.first;
    for (final duplicate in aiResponses.skip(1)) {
      await _repository.deleteResponse(duplicate.id);
      responses.removeWhere((response) => response.id == duplicate.id);
      _responses.removeWhere((response) => response.id == duplicate.id);
    }
    return retained;
  }

  Future<int> importSampleVocs(List<VocEntity> samples) async {
    final existingIds = _vocs.map((v) => v.id).toSet();
    var createdCount = 0;

    for (final sample in samples) {
      if (existingIds.contains(sample.id)) {
        continue;
      }
      await _repository.createVoc(sample);
      _vocs.insert(0, sample);
      existingIds.add(sample.id);
      createdCount++;
    }

    if (createdCount > 0) {
      notifyListeners();
    }
    return createdCount;
  }

  Future<void> updateVocWithAiAnalysis(
    String id, {
    required bool isBusinessRelated,
    required String aiCategory,
    double? businessScore,
    double? categoryScore,
    String? urgency,
    double? urgencyScore,
    String? department,
    double? departmentScore,
    String? assignee,
    double? assigneeScore,
    String? duplicateOfVocId,
    double? duplicateScore,
    bool? jiraRequired,
    double? jiraScore,
    String? analysisReason,
  }) async {
    final idx = _vocs.indexWhere((v) => v.id == id);
    if (idx == -1) return;
    final updated = _vocs[idx].copyWith(
      isBusinessRelated: isBusinessRelated,
      aiCategory: aiCategory,
      businessScore: businessScore,
      categoryScore: categoryScore,
      urgency: urgency,
      urgencyScore: urgencyScore,
      department: department,
      departmentScore: departmentScore,
      assignee: assignee,
      assigneeScore: assigneeScore,
      duplicateOfVocId: duplicateOfVocId,
      duplicateScore: duplicateScore,
      jiraRequired: jiraRequired,
      jiraScore: jiraScore,
      analysisReason: analysisReason,
      status: isBusinessRelated ? null : AppConstants.vocStatusRejected,
      updatedAt: DateTime.now(),
    );
    await _repository.updateVoc(updated);
    _vocs[idx] = updated;
    if (_selectedVoc?.id == id) _selectedVoc = updated;
    notifyListeners();
  }

  Future<void> deleteVoc(String id) async {
    await _repository.deleteVoc(id);
    _vocs.removeWhere((v) => v.id == id);
    if (_selectedVoc?.id == id) _selectedVoc = null;
    notifyListeners();
  }

  Future<ResponseEntity> createDraftResponse({
    required String vocId,
    required String content,
    bool aiGenerated = false,
    double? confidence,
    List<String>? referencedVocIds,
  }) async {
    final now = DateTime.now();
    final response = ResponseEntity(
      id: _uuid.v4(),
      vocId: vocId,
      content: content,
      status: AppConstants.responseDraft,
      aiGenerated: aiGenerated,
      confidenceScore: confidence,
      referencedVocIds: referencedVocIds ?? [],
      createdAt: now,
      updatedAt: now,
    );
    final created = await _repository.createResponse(response);
    _responses.insert(0, created);
    notifyListeners();
    return created;
  }

  Future<ResponseEntity?> adoptAiAnswer({
    required String vocId,
    required String content,
    double? confidence,
    List<String>? referencedVocIds,
    String? responseId,
  }) async {
    final now = DateTime.now();
    final existingIndex = responseId == null
        ? -1
        : _responses.indexWhere((r) => r.id == responseId);
    ResponseEntity? storedResponse;
    if (responseId != null && existingIndex < 0) {
      final storedResponses = await _repository.getResponsesByVocId(vocId);
      for (final candidate in storedResponses) {
        if (candidate.id == responseId) {
          storedResponse = candidate;
          break;
        }
      }
    }
    final existingResponse =
        existingIndex >= 0 ? _responses[existingIndex] : storedResponse;

    final response = existingResponse != null
        ? existingResponse.copyWith(
            content: content,
            status: AppConstants.responseApproved,
            confidenceScore: confidence,
            referencedVocIds:
                referencedVocIds ?? existingResponse.referencedVocIds,
            approvedBy: 'AI 채택',
            approvedAt: now,
            adoptionCount: existingResponse.adoptionCount + 1,
            usageCount: existingResponse.usageCount + 1,
            lastUsedAt: now,
            updatedAt: now,
          )
        : ResponseEntity(
            id: _uuid.v4(),
            vocId: vocId,
            content: content,
            status: AppConstants.responseApproved,
            aiGenerated: true,
            confidenceScore: confidence,
            referencedVocIds: referencedVocIds ?? const [],
            approvedBy: 'AI 채택',
            approvedAt: now,
            adoptionCount: 1,
            usageCount: 1,
            lastUsedAt: now,
            createdAt: now,
            updatedAt: now,
          );

    if (existingResponse != null) {
      await _repository.updateResponse(response);
      if (existingIndex >= 0) {
        _responses[existingIndex] = response;
      } else if (_selectedVoc?.id == vocId) {
        _responses.insert(0, response);
      }
    } else {
      final created = await _repository.createResponse(response);
      if (_selectedVoc?.id == vocId) {
        _responses.insert(0, created);
      }
    }

    notifyListeners();
    return response;
  }

  Future<void> recordAiFeedback({
    required String vocId,
    required String feedbackType,
    String? responseId,
    String? note,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'ai_feedback',
      {
        'id': _uuid.v4(),
        'voc_id': vocId,
        'response_id': responseId,
        'feedback_type': feedbackType,
        'note': note,
        'created_at': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> approveResponse(String responseId, String approvedBy) async {
    final idx = _responses.indexWhere((r) => r.id == responseId);
    if (idx == -1) return;
    final updated = _responses[idx].copyWith(
      status: AppConstants.responseApproved,
      approvedBy: approvedBy,
      approvedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _repository.updateResponse(updated);
    _responses[idx] = updated;
    notifyListeners();
  }

  Future<ResponseEntity?> updateResponseContent({
    required String responseId,
    required String content,
  }) async {
    final idx = _responses.indexWhere((r) => r.id == responseId);
    if (idx == -1) return null;
    final updated = _responses[idx].copyWith(
      content: content,
      updatedAt: DateTime.now(),
    );
    await _repository.updateResponse(updated);
    _responses[idx] = updated;
    notifyListeners();
    return updated;
  }

  void setSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setFilterStatus(String status) {
    _filterStatus = status;
    notifyListeners();
  }

  void setFilterCategory(String category) {
    _filterCategory = category;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _filterStatus = '';
    _filterCategory = '';
    notifyListeners();
  }

  String _priorityFromUrgency(String urgency) {
    final normalized = urgency.trim().toLowerCase();
    if (normalized.contains('high') ||
        normalized.contains('critical') ||
        normalized.contains('긴급')) {
      return AppConstants.priorityHigh;
    }
    if (normalized.contains('low') || normalized.contains('낮')) {
      return AppConstants.priorityLow;
    }
    return AppConstants.priorityMedium;
  }

  String _buildAutoTags(VocEntity voc, VocIntelligenceResult intelligence) {
    final values = <String>{
      intelligence.category.trim(),
      intelligence.urgency.trim(),
      intelligence.department.trim(),
      if (voc.businessType?.trim().isNotEmpty == true) voc.businessType!.trim(),
      if (voc.source?.trim().isNotEmpty == true) voc.source!.trim(),
    };
    values.removeWhere((item) => item.isEmpty);
    return values.join(', ');
  }
}

class BulkAiResolveSummary {
  final int targetCount;
  final int generatedCount;
  final int reusedApprovedCount;
  final int reusedAiCount;
  final int resolvedCount;
  final int skippedCount;
  final int failedCount;
  final int syncedCount;
  final int syncFailedCount;
  final bool stopped;

  const BulkAiResolveSummary({
    this.targetCount = 0,
    this.generatedCount = 0,
    this.reusedApprovedCount = 0,
    this.reusedAiCount = 0,
    this.resolvedCount = 0,
    this.skippedCount = 0,
    this.failedCount = 0,
    this.syncedCount = 0,
    this.syncFailedCount = 0,
    this.stopped = false,
  });
}
