import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/database/database_helper.dart';
import '../../core/utils/voc_category_catalog.dart';
import '../../data/services/connectors/default_connector_registry.dart';
import '../../data/services/excel_service.dart';
import '../../data/services/in_app_sync_receiver_service.dart';
import '../../data/services/webhook_service.dart';
import '../../core/utils/vector_utils.dart';
import '../../domain/entities/response_entity.dart';
import '../../domain/entities/voc_entity.dart';
import '../../domain/repositories/voc_repository.dart';
import 'settings_viewmodel.dart';

class IntegrationViewModel extends ChangeNotifier {
  final VocRepository _vocRepository;
  final SettingsViewModel _settingsViewModel;
  final void Function(String message)? _onInboundSyncEvent;
  final _uuid = const Uuid();

  final _excel = ExcelService();
  final _webhook = WebhookService();
  late final DefaultConnectorRegistry _connectors;

  bool _isLoading = false;
  String? _error;
  String? _success;
  String? _lastSyncErrorDetails;
  bool _isSyncingFull = false;
  int _syncTotalTargets = 0;
  int _syncCompletedTargets = 0;
  String? _syncCurrentTarget;
  final List<String> _syncRuntimeLogs = [];
  final List<InboundSyncEvent> _recentInboundEvents = [];
  List<String> _lastImportInvalidRows = [];
  final List<_SyncRetryTask> _syncRetryQueue = [];
  bool _retryQueueRestored = false;
  Timer? _inboundEventPoller;
  int _lastSeenSyncEventSeq = 0;
  bool _inAppReceiverRunning = false;
  String? _inAppReceiverLastError;
  bool _isBootstrapping = false;
  String? _bootstrapStatus;

  static const int _maxSyncRetries = 3;
  static const int _syncRetryBackoffMs = 600;

  IntegrationViewModel(
    this._vocRepository,
    this._settingsViewModel, {
    void Function(String message)? onInboundSyncEvent,
  }) : _onInboundSyncEvent = onInboundSyncEvent {
    _connectors = DefaultConnectorRegistry(_settingsViewModel);
    _settingsViewModel.addListener(_restoreRetryQueueIfReady);
    _restoreRetryQueueIfReady();
    _startInboundSyncEventWatcher();
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get success => _success;
  String? get lastSyncErrorDetails => _lastSyncErrorDetails;
  bool get isSyncingFull => _isSyncingFull;
  int get syncTotalTargets => _syncTotalTargets;
  int get syncCompletedTargets => _syncCompletedTargets;
  String? get syncCurrentTarget => _syncCurrentTarget;
  List<String> get syncRuntimeLogs => List.unmodifiable(_syncRuntimeLogs);
  List<InboundSyncEvent> get recentInboundEvents =>
      List.unmodifiable(_recentInboundEvents);
  List<String> get lastImportInvalidRows => _lastImportInvalidRows;
  int get syncRetryQueueCount => _syncRetryQueue.length;
  bool get inAppReceiverRunning => _inAppReceiverRunning;
  String? get inAppReceiverLastError => _inAppReceiverLastError;
  bool get isBootstrapping => _isBootstrapping;
  String? get bootstrapStatus => _bootstrapStatus ?? _inAppReceiverLastError;

  @override
  void dispose() {
    _inboundEventPoller?.cancel();
    _settingsViewModel.removeListener(_restoreRetryQueueIfReady);
    super.dispose();
  }

  void clearMessages() {
    _error = null;
    _success = null;
    _lastSyncErrorDetails = null;
    notifyListeners();
  }

  void clearSyncRuntimeLogs() {
    _syncRuntimeLogs.clear();
    notifyListeners();
  }

  void clearInboundSyncEvents() {
    _recentInboundEvents.clear();
    notifyListeners();
  }

  Future<int> importVocFromExcel(String filePath) async {
    return importVocFromFile(filePath, duplicateStrategy: 'skip');
  }

  Future<int> importVocFromFile(
    String filePath, {
    String duplicateStrategy = 'skip',
  }) async {
    _start();
    _lastImportInvalidRows = [];
    try {
      final rows = await _excel.importVocRows(filePath);
      final existingVocs = await _vocRepository.getAllVocs();
      final existingMap = {
        for (final voc in existingVocs) _duplicateKey(voc): voc,
      };

      int imported = 0;
      int updated = 0;
      int skipped = 0;
      int invalid = 0;

      for (int index = 0; index < rows.length; index++) {
        final row = rows[index];
        final titleRaw =
            (row['VOC 제목'] ?? row['voc 제목'] ?? row['title'] ?? row['제목'] ?? '')
                .trim();
        final contentRaw =
            (row['VOC 내용'] ?? row['voc 내용'] ?? row['content'] ?? row['내용'] ?? '')
                .trim();
        final title = titleRaw.isEmpty ? '제목없음-${index + 2}' : titleRaw;
        final content = contentRaw.isEmpty ? '내용 없음' : contentRaw;
        final answers = _extractAnswers(row);

        final projectName = (row['프로젝트명'] ?? row['project'] ?? '').toString().trim();
        final businessType = (row['업무 구분'] ?? row['business_type'] ?? '').toString().trim();
        final projectCode =
            (row['프로젝트 코드'] ?? row['project_code'] ?? '').toString().trim();
        final vocNumber =
            (row['VOC 번호'] ?? row['voc_number'] ?? '').toString().trim();
        final project = _buildProjectDisplay(
          projectName: projectName,
          projectCode: projectCode,
          vocNumber: vocNumber,
        );

        final key = _duplicateKeyByText(title, content);
        final existing = existingMap[key];
        final shouldOverwrite = existing != null && duplicateStrategy == 'overwrite';
        final shouldSkip = existing != null && duplicateStrategy == 'skip';

        final now = DateTime.now();
        final status = answers.isNotEmpty
            ? AppConstants.vocStatusResolved
            : _requiredText(row['status'], fallback: AppConstants.vocStatusOpen);
        final voc = VocEntity(
          id: shouldOverwrite ? existing.id : _uuid.v4(),
          title: title,
          content: content,
          category: (row['카테고리'] ?? row['category'] ?? '기능문의').trim(),
          tags: _optionalText(row['tags'] ?? row['태그']),
          customer: _requiredText(row['고객명'] ?? row['customer'], fallback: '미입력'),
          project: project,
          priority: _excel.normalizePriority(
            row['우선순위'] ?? row['priority'] ?? 'MEDIUM',
          ),
          status: status,
          urgency: null,
          businessType: businessType.isEmpty ? null : businessType,
          department: null,
          assignee: null,
          source: 'excel',
          sourceRef: vocNumber.isEmpty ? filePath : vocNumber,
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
        );

        if (shouldSkip) {
          skipped += 1;
          continue;
        }

        final savedVoc = shouldOverwrite
            ? await _vocRepository.updateVoc(voc.copyWith(updatedAt: now))
            : await _vocRepository.createVoc(voc);

        if (shouldOverwrite) {
          final db = await DatabaseHelper.instance.database;
          await db.delete(
            AppConstants.tableResponses,
            where: 'voc_id = ?',
            whereArgs: [savedVoc.id],
          );
        }

        for (final answer in answers) {
          final response = ResponseEntity(
            id: _uuid.v4(),
            vocId: savedVoc.id,
            content: answer,
            status: AppConstants.responseApproved,
            aiGenerated: false,
            adoptionCount: 1,
            usageCount: 1,
            lastUsedAt: now,
            approvedBy: 'Import',
            approvedAt: now,
            createdAt: now,
            updatedAt: now,
          );
          await _vocRepository.createResponse(response);
        }

        if (shouldOverwrite) {
          updated += 1;
        } else {
          imported += 1;
          existingMap[key] = savedVoc;
        }
      }

      _success =
          'VOC 가져오기 완료: 추가 $imported건, 갱신 $updated건, 건너뜀 $skipped건, 필수값 누락 $invalid건';
      return imported + updated;
    } catch (e) {
      _error = '엑셀 Import 실패: $e';
      return 0;
    } finally {
      _end();
    }
  }

  Future<String?> exportVocToExcel(String filePath) async {
    _start();
    try {
      final vocs = await _vocRepository.getAllVocs();
      final db = await DatabaseHelper.instance.database;
      final responses = await db.query(AppConstants.tableResponses);
      final out = await _excel.exportVocs(
        filePath: filePath,
        vocs: vocs,
        responses: responses,
      );
      _success = 'VOC/답변 Export 완료: $out';
      return out;
    } catch (e) {
      _error = 'VOC Export 실패: $e';
      return null;
    } finally {
      _end();
    }
  }

  Future<String?> exportVocTemplate(String filePath) async {
    _start();
    try {
      final out = await _excel.exportVocTemplate(filePath: filePath);
      _success = 'VOC 템플릿 다운로드 완료: $out';
      return out;
    } catch (e) {
      _error = 'VOC 템플릿 다운로드 실패: $e';
      return null;
    } finally {
      _end();
    }
  }

  Future<void> clearAllVocData() async {
    _start();
    try {
      final db = await DatabaseHelper.instance.database;

      // 업무 데이터 + AI 캐시 + 벡터 저장소를 함께 정리
      await db.delete('ai_chat_messages');
      await db.delete('ai_feedback');
      await db.delete(AppConstants.tableResponses);
      await db.delete(AppConstants.tableVocs);
      await db.delete(AppConstants.tableKnowledgeBase);
      await db.delete(AppConstants.tableJiraLinks);
      await db.delete(AppConstants.tableEmails);
      await db.delete(AppConstants.tableEmailAttachments);

      _success = 'VOC/Vector DB/AI 캐시를 모두 초기화했습니다.';
    } catch (e) {
      _error = 'VOC 초기화 실패: $e';
    } finally {
      _end();
    }
  }

  Future<int> rebuildVectorDb() async {
    _start();
    try {
      final vocs = await _vocRepository.getAllVocs();
      int updated = 0;
      for (final voc in vocs) {
        final next = voc.copyWith(
          embedding: VectorUtils.simpleTextEmbedding('${voc.title} ${voc.content}'),
          updatedAt: DateTime.now(),
        );
        await _vocRepository.updateVoc(next);
        updated += 1;
      }
      _success = 'Vector DB 재생성 완료: $updated건';
      return updated;
    } catch (e) {
      _error = 'Vector DB 재생성 실패: $e';
      return 0;
    } finally {
      _end();
    }
  }

  Future<void> clearAiCache() async {
    _start();
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('ai_feedback');
      await db.delete('ai_chat_messages');
      _success = 'AI 캐시를 초기화했습니다.';
    } catch (e) {
      _error = 'AI 캐시 초기화 실패: $e';
    } finally {
      _end();
    }
  }

  String _duplicateKey(VocEntity voc) =>
      _duplicateKeyByText(voc.title, voc.content);

  String _duplicateKeyByText(String title, String content) =>
      '${title.trim().toLowerCase()}|${content.trim().toLowerCase()}';

  String? _optionalText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  String _requiredText(dynamic value, {required String fallback}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _buildProjectDisplay({
    required String projectName,
    required String projectCode,
    required String vocNumber,
  }) {
    final items = <String>[];
    if (projectName.trim().isNotEmpty) {
      items.add(projectName.trim());
    }
    if (projectCode.trim().isNotEmpty) {
      items.add(projectCode.trim().toUpperCase());
    }
    if (vocNumber.trim().isNotEmpty) {
      items.add(vocNumber.trim().toUpperCase());
    }
    if (items.isEmpty) return '미입력';
    return items.join(' | ');
  }

  List<String> _extractAnswers(Map<String, String> row) {
    final answers = <String>[];
    row.forEach((key, value) {
      final lower = key.trim().toLowerCase();
      final isAnswerColumn = lower == 'answer' ||
          lower == '답변' ||
          lower.startsWith('answer') ||
          lower.startsWith('답변');
      if (!isAnswerColumn) return;

      final raw = value.trim();
      if (raw.isEmpty) return;

      // 한 컬럼은 줄바꿈 포함 원문 그대로 1개의 답변으로 처리한다.
      answers.add(raw);
    });

    return answers;
  }

  Future<int> collectOutlookAndCreateVoc({int top = 20}) async {
    _start();
    try {
      final mails = await _connectors.outlookCollector.collectMails(top: top);

      final db = await DatabaseHelper.instance.database;
      int imported = 0;

      for (final m in mails) {
        final exists = await db.query(
          AppConstants.tableEmails,
          where: 'outlook_message_id = ?',
          whereArgs: [m.id],
          limit: 1,
        );
        if (exists.isNotEmpty) continue;

        final now = DateTime.now();
        final voc = VocEntity(
          id: _uuid.v4(),
          title: '[메일] ${m.subject}',
          content: m.bodyPreview,
          category: '운영문의',
          customer: m.sender.isEmpty ? '메일고객' : m.sender,
          project: '메일유입',
          priority: AppConstants.priorityMedium,
          status: AppConstants.vocStatusOpen,
          source: 'outlook',
          sourceRef: m.id,
          createdAt: now,
          updatedAt: now,
        );

        await _vocRepository.createVoc(voc);

        final emailId = _uuid.v4();
        await db.insert(AppConstants.tableEmails, {
          'id': emailId,
          'outlook_message_id': m.id,
          'sender': m.sender,
          'subject': m.subject,
          'body_preview': m.bodyPreview,
          'received_at': m.receivedAt?.toIso8601String(),
          'imported_voc_id': voc.id,
          'created_at': now.toIso8601String(),
        });

        for (final att in m.attachments) {
          final savedPath = await _connectors.outlookCollector.saveAttachment(att);
          if (savedPath == null) continue;
          await db.insert(AppConstants.tableEmailAttachments, {
            'id': _uuid.v4(),
            'email_id': emailId,
            'file_name': att.name,
            'file_path': savedPath,
            'content_type': att.contentType,
            'size': att.size,
            'created_at': now.toIso8601String(),
          });
        }

        imported += 1;
      }

      _success = 'Outlook 메일 기반 VOC $imported건 생성 완료';
      return imported;
    } catch (e) {
      _error = 'Outlook 연동 실패: $e';
      return 0;
    } finally {
      _end();
    }
  }

  Future<void> notifyUrgentVocToTeams(VocEntity voc) async {
    if (!_connectors.teamsNotifier.isConfigured) {
      _error = 'Teams Webhook이 설정되지 않았습니다.';
      notifyListeners();
      return;
    }

    _start();
    try {
      await _connectors.teamsNotifier.sendUrgentVoc(voc);
      _success = 'Teams 긴급 알림 전송 완료';
    } catch (e) {
      _error = 'Teams 알림 실패: $e';
    } finally {
      _end();
    }
  }

  Future<void> shareAiAnswerToTeams({
    required VocEntity voc,
    required String answer,
  }) async {
    if (!_connectors.teamsNotifier.isConfigured) {
      _error = 'Teams Webhook이 설정되지 않았습니다.';
      notifyListeners();
      return;
    }

    _start();
    try {
      await _connectors.teamsNotifier.shareAiAnswer(
        voc: voc,
        answer: answer,
      );
      _success = 'Teams AI 답변 공유 완료';
    } catch (e) {
      _error = 'Teams 공유 실패: $e';
    } finally {
      _end();
    }
  }

  Future<void> shareVocToSlack({
    required VocEntity voc,
  }) async {
    if (!_connectors.slackNotifier.isConfigured) {
      _error = 'Slack Webhook이 설정되지 않았습니다.';
      notifyListeners();
      return;
    }

    _start();
    try {
      await _connectors.slackNotifier.shareVoc(voc);
      _success = 'Slack VOC 공유 완료';
    } catch (e) {
      _error = 'Slack 공유 실패: $e';
    } finally {
      _end();
    }
  }

  Future<void> shareAiAnswerToSlack({
    required VocEntity voc,
    required String answer,
  }) async {
    if (!_connectors.slackNotifier.isConfigured) {
      _error = 'Slack Webhook이 설정되지 않았습니다.';
      notifyListeners();
      return;
    }

    _start();
    try {
      await _connectors.slackNotifier.shareAiAnswer(
        voc: voc,
        answer: answer,
      );
      _success = 'Slack 공유 완료';
    } catch (e) {
      _error = 'Slack 공유 실패: $e';
    } finally {
      _end();
    }
  }

  Future<String?> forwardVocToPeerApps(VocEntity voc) async {
    if (!_settingsViewModel.vocAutoForwardEnabled) {
      return null;
    }

    final targets = _settingsViewModel.vocForwardWebhookTargets;
    if (targets.isEmpty) {
      return '앱 동기화가 켜져 있지만 수신 URL이 없습니다.';
    }

    final payload = {
      'event': 'voc.created',
      'sent_at': DateTime.now().toIso8601String(),
      'source_app': _settingsViewModel.appInstanceName,
      'voc': {
        'id': voc.id,
        'title': voc.title,
        'content': voc.content,
        'category': voc.category,
        'tags': voc.tags,
        'customer': voc.customer,
        'project': voc.project,
        'priority': voc.priority,
        'status': voc.status,
        'business_type': voc.businessType,
        'urgency': voc.urgency,
        'created_at': voc.createdAt.toIso8601String(),
        'updated_at': voc.updatedAt.toIso8601String(),
      },
    };

    var successCount = 0;
    final failedTargets = <String>[];
    final authHeaders = _syncAuthHeaders();

    for (final target in targets) {
      final vocTarget = _toVocEndpoint(target);
      try {
        await _postWithRetry(
          webhookUrl: vocTarget,
          body: payload,
          headers: authHeaders,
        );
        successCount += 1;
        _appendSyncLog('단건 전송 성공: $vocTarget');
      } catch (e) {
        failedTargets.add(vocTarget);
        _appendSyncLog('단건 전송 실패: $vocTarget / $e');
        await _enqueueRetry(
          endpoint: vocTarget,
          payload: payload,
          headers: authHeaders,
          label: 'voc.created',
          lastError: '$e',
        );
      }
    }

    if (failedTargets.isEmpty) {
      _lastSyncErrorDetails = null;
      return '앱 동기화 전송 완료: $successCount개 앱';
    }

    _lastSyncErrorDetails = _buildSyncFailureDetails(
      title: '단건 자동 포워딩 실패 상세',
      targets: failedTargets,
    );

    return '앱 동기화 일부 실패: 성공 $successCount개, 실패 ${failedTargets.length}개 (재시도 대기 ${_syncRetryQueue.length}건)';
  }

  Future<String?> forwardVocChangeToPeerApps({
    required VocEntity voc,
    required String event,
    ResponseEntity? response,
  }) async {
    if (!_settingsViewModel.vocAutoForwardEnabled) {
      return null;
    }

    final targets = _settingsViewModel.vocForwardWebhookTargets;
    if (targets.isEmpty) {
      return '앱 동기화가 켜져 있지만 수신 URL이 없습니다.';
    }

    final payload = {
      'event': event,
      'sent_at': DateTime.now().toIso8601String(),
      'source_app': _settingsViewModel.appInstanceName,
      'voc': {
        'id': voc.id,
        'title': voc.title,
        'content': voc.content,
        'category': voc.category,
        'tags': voc.tags,
        'customer': voc.customer,
        'project': voc.project,
        'priority': voc.priority,
        'status': voc.status,
        'business_type': voc.businessType,
        'urgency': voc.urgency,
        'created_at': voc.createdAt.toIso8601String(),
        'updated_at': voc.updatedAt.toIso8601String(),
      },
      if (response != null)
        'response': {
          'id': response.id,
          'voc_id': response.vocId,
          'content': response.content,
          'status': response.status,
          'ai_generated': response.aiGenerated,
          'confidence_score': response.confidenceScore,
          'referenced_voc_ids': response.referencedVocIds,
          'approved_by': response.approvedBy,
          'approved_at': response.approvedAt?.toIso8601String(),
          'adoption_count': response.adoptionCount,
          'usage_count': response.usageCount,
          'last_used_at': response.lastUsedAt?.toIso8601String(),
          'created_at': response.createdAt.toIso8601String(),
          'updated_at': response.updatedAt.toIso8601String(),
        },
    };

    var successCount = 0;
    final failedTargets = <String>[];
    final authHeaders = _syncAuthHeaders();

    for (final target in targets) {
      final vocTarget = _toVocEndpoint(target);
      try {
        await _postWithRetry(
          webhookUrl: vocTarget,
          body: payload,
          headers: authHeaders,
        );
        successCount += 1;
        _appendSyncLog('변경 전송 성공($event): $vocTarget');
      } catch (e) {
        failedTargets.add(vocTarget);
        _appendSyncLog('변경 전송 실패($event): $vocTarget / $e');
        await _enqueueRetry(
          endpoint: vocTarget,
          payload: payload,
          headers: authHeaders,
          label: event,
          lastError: '$e',
        );
      }
    }

    if (failedTargets.isEmpty) {
      _lastSyncErrorDetails = null;
      return '앱 동기화 전송 완료: $successCount개 앱';
    }

    _lastSyncErrorDetails = _buildSyncFailureDetails(
      title: '변경 동기화 실패 상세',
      targets: failedTargets,
    );

    return '앱 동기화 일부 실패: 성공 $successCount개, 실패 ${failedTargets.length}개 (재시도 대기 ${_syncRetryQueue.length}건)';
  }

  Future<void> forwardFullVocAndManualToPeerApps() async {
    _start();
    try {
      final targets = _settingsViewModel.vocForwardWebhookTargets;
      if (targets.isEmpty) {
        _error = '전체 동기화 대상 URL이 없습니다.';
        _appendSyncLog('전체 동기화 실패: 대상 URL 미설정');
        return;
      }

      _beginFullSyncProgress(totalTargets: targets.length);
      _appendSyncLog('전체 동기화 시작: 대상 ${targets.length}개');

      final db = await DatabaseHelper.instance.database;
      final vocRows = await db.query(AppConstants.tableVocs);
      final responseRows = await db.query(AppConstants.tableResponses);
      final manualRows = await db.query(
        AppConstants.tableKnowledgeBase,
        where: 'category = ? OR project = ?',
        whereArgs: const ['시스템매뉴얼', 'manual-upload'],
      );

      final payload = {
        'event': 'sync.full',
        'sent_at': DateTime.now().toIso8601String(),
        'source_app': _settingsViewModel.appInstanceName,
        'sync_mode': 'upsert',
        'snapshot': {
          'vocs': vocRows,
          'responses': responseRows,
          'manuals': manualRows,
        },
      };

      final failedTargets = <String>[];
      var successCount = 0;
      final authHeaders = _syncAuthHeaders();

      for (final target in targets) {
        final syncTarget = _toFullSyncEndpoint(target);
        _syncCurrentTarget = syncTarget;
        notifyListeners();
        try {
          await _postWithRetry(
            webhookUrl: syncTarget,
            body: payload,
            headers: authHeaders,
          );
          successCount += 1;
          _appendSyncLog('전체 동기화 성공: $syncTarget');
        } catch (e) {
          failedTargets.add(syncTarget);
          _appendSyncLog('전체 동기화 실패: $syncTarget / $e');
          await _enqueueRetry(
            endpoint: syncTarget,
            payload: payload,
            headers: authHeaders,
            label: 'sync.full',
            lastError: '$e',
          );
        } finally {
          _syncCompletedTargets += 1;
          notifyListeners();
        }
      }

      if (failedTargets.isEmpty) {
        _lastSyncErrorDetails = null;
        _success =
            '전체 동기화 전송 완료: 앱 $successCount개, VOC ${vocRows.length}건, 매뉴얼 ${manualRows.length}건';
      } else {
        _lastSyncErrorDetails = _buildSyncFailureDetails(
          title: '전체 VOC/매뉴얼 동기화 실패 상세',
          targets: failedTargets,
        );
        _error =
            '전체 동기화 일부 실패: 성공 $successCount개, 실패 ${failedTargets.length}개 (재시도 대기 ${_syncRetryQueue.length}건)';
      }
    } catch (e) {
      _lastSyncErrorDetails = '전체 동기화 예외\n- $e';
      _appendSyncLog('전체 동기화 예외: $e');
      _error = '전체 동기화 전송 실패: $e';
    } finally {
      _endFullSyncProgress();
      _end();
    }
  }

  Future<int> pullVocFromPeerApps() async {
    _start();
    try {
      final targets = _settingsViewModel.vocForwardWebhookTargets;
      if (targets.isEmpty) {
        _error = '가져올 대상 앱 URL이 없습니다.';
        return 0;
      }

      final existingVocs = await _vocRepository.getAllVocs();
      final existingKeys = {
        for (final voc in existingVocs) _duplicateKey(voc),
      };
      final incomingKeys = <String>{};

      final authHeaders = _syncAuthHeaders();
      var successTargets = 0;
      var imported = 0;
      var duplicateSkipped = 0;
      var remoteTotal = 0;
      final failedTargets = <String>[];

      for (final target in targets) {
        final exportTarget = _toVocExportEndpoint(target);
        _syncCurrentTarget = exportTarget;
        notifyListeners();
        try {
          final payload = await _webhook.getJsonForMap(
            url: exportTarget,
            headers: authHeaders,
          );
          successTargets += 1;

          final sourceApp = payload['source_app']?.toString().trim().isNotEmpty == true
              ? payload['source_app'].toString().trim()
              : 'unknown-app';
          final snapshot = payload['snapshot'] is Map
              ? Map<String, dynamic>.from(payload['snapshot'] as Map)
              : const <String, dynamic>{};
          final vocs = (snapshot['vocs'] as List?) ?? const [];

          for (final item in vocs) {
            if (item is! Map) {
              continue;
            }
            final row = Map<String, dynamic>.from(item);
            final titleRaw = row['title']?.toString().trim() ?? '';
            final contentRaw = row['content']?.toString().trim() ?? '';
            final title = titleRaw.isEmpty ? '제목없음' : titleRaw;
            final content = contentRaw.isEmpty ? '내용 없음' : contentRaw;

            final key = _duplicateKeyByText(title, content);
            remoteTotal += 1;
            if (existingKeys.contains(key) || incomingKeys.contains(key)) {
              duplicateSkipped += 1;
              continue;
            }

            final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '');
            final updatedAt = DateTime.tryParse(row['updated_at']?.toString() ?? '');
            final now = DateTime.now();
            final normalizedCategory = VocCategoryCatalog.normalize(
              row['category']?.toString(),
              title: title,
              content: content,
              aiCategory: row['ai_category']?.toString(),
              tags: row['tags']?.toString(),
            );

            final voc = VocEntity(
              id: _uuid.v4(),
              title: title,
              content: content,
              category: normalizedCategory,
              tags: _optionalText(row['tags']),
              customer: _requiredText(row['customer'], fallback: '미입력'),
              project: _requiredText(row['project'], fallback: '미입력'),
              priority: _excel.normalizePriority(row['priority'] ?? AppConstants.priorityMedium),
              status: _normalizeVocStatus(row['status']?.toString()),
              aiCategory: _optionalText(row['ai_category']),
              urgency: _optionalText(row['urgency']),
              businessType: _optionalText(row['business_type']),
              department: _optionalText(row['department']),
              assignee: _optionalText(row['assignee']),
              source: 'peer-pull',
              sourceRef: '$sourceApp:${row['id'] ?? key}',
              createdAt: createdAt ?? now,
              updatedAt: updatedAt ?? now,
            );

            await _vocRepository.createVoc(voc);
            existingKeys.add(key);
            incomingKeys.add(key);
            imported += 1;
          }

          _appendSyncLog('상대 앱 VOC 가져오기 성공: $exportTarget (${vocs.length}건 확인)');
        } catch (e) {
          failedTargets.add(exportTarget);
          _appendSyncLog('상대 앱 VOC 가져오기 실패: $exportTarget / $e');
        }
      }

      _syncCurrentTarget = null;

      if (failedTargets.isNotEmpty) {
        _lastSyncErrorDetails = _buildSyncFailureDetails(
          title: '상대 앱 VOC 가져오기 실패 상세',
          targets: failedTargets,
        );
        _error =
            '상대 앱 VOC 가져오기 일부 실패: 성공 $successTargets개 앱, 실패 ${failedTargets.length}개 앱 (총 $remoteTotal건 확인, 중복 제외 $duplicateSkipped건, 반영 $imported건)';
      } else {
        _lastSyncErrorDetails = null;
        _success =
            '상대 앱 VOC 가져오기 완료: 앱 $successTargets개, 총 $remoteTotal건 확인, 중복 제외 $duplicateSkipped건, 반영 $imported건';
      }

      return imported;
    } catch (e) {
      _syncCurrentTarget = null;
      _error = '상대 앱 VOC 가져오기 실패: $e';
      return 0;
    } finally {
      _end();
    }
  }

  Future<int> bootstrapFromPeerApps() async {
    if (_isBootstrapping) {
      return 0;
    }

    _isBootstrapping = true;
    _bootstrapStatus = '초기 동기화 준비 중...';
    notifyListeners();

    try {
      final targets = _settingsViewModel.vocForwardWebhookTargets;
      if (targets.isEmpty) {
        _bootstrapStatus = '초기 동기화 대상 앱이 없습니다.';
        notifyListeners();
        return 0;
      }

      final db = await DatabaseHelper.instance.database;
      final existingVocs = await _vocRepository.getAllVocs();
      final existingVocKeys = {
        for (final voc in existingVocs) _duplicateKey(voc),
      };

      final existingManuals = await db.query(
        AppConstants.tableKnowledgeBase,
        columns: ['question', 'answer'],
        where: 'category = ? OR project = ?',
        whereArgs: const ['시스템매뉴얼', 'manual-upload'],
      );
      final existingManualKeys = {
        for (final row in existingManuals)
          _manualKey(
            row['question']?.toString() ?? '',
            row['answer']?.toString() ?? '',
          ),
      };

      final authHeaders = _syncAuthHeaders();
      var importedVocs = 0;
      var importedManuals = 0;
      var duplicateSkips = 0;
      final failedTargets = <String>[];

      for (final target in targets) {
        final exportTarget = _toVocExportEndpoint(target);
        _bootstrapStatus = '초기 동기화 중: $exportTarget';
        notifyListeners();

        try {
          final payload = await _webhook.getJsonForMap(
            url: exportTarget,
            headers: authHeaders,
          );

          final snapshot = payload['snapshot'] is Map
              ? Map<String, dynamic>.from(payload['snapshot'] as Map)
              : const <String, dynamic>{};

          final vocs = (snapshot['vocs'] as List?) ?? const [];
          final manuals = (snapshot['manuals'] as List?) ?? const [];

          for (final item in vocs) {
            if (item is! Map) continue;
            final row = Map<String, dynamic>.from(item);
            final title = (row['title']?.toString().trim().isNotEmpty == true)
                ? row['title'].toString().trim()
                : '제목없음';
            final content = (row['content']?.toString().trim().isNotEmpty == true)
                ? row['content'].toString().trim()
                : '내용 없음';
            final key = _duplicateKeyByText(title, content);
            if (existingVocKeys.contains(key)) {
              duplicateSkips += 1;
              continue;
            }

            final now = DateTime.now();
            final normalizedCategory = VocCategoryCatalog.normalize(
              row['category']?.toString(),
              title: title,
              content: content,
              aiCategory: row['ai_category']?.toString(),
              tags: row['tags']?.toString(),
            );

            await _vocRepository.createVoc(
              VocEntity(
                id: _uuid.v4(),
                title: title,
                content: content,
                category: normalizedCategory,
                tags: row['tags']?.toString(),
                customer: _requiredText(row['customer'], fallback: '미입력'),
                project: _requiredText(row['project'], fallback: '미입력'),
                priority: _excel.normalizePriority(row['priority'] ?? AppConstants.priorityMedium),
                status: _normalizeVocStatus(row['status']?.toString()),
                aiCategory: row['ai_category']?.toString(),
                urgency: row['urgency']?.toString(),
                businessType: row['business_type']?.toString(),
                department: row['department']?.toString(),
                assignee: row['assignee']?.toString(),
                source: 'peer-bootstrap',
                sourceRef: '${payload['source_app'] ?? 'peer'}:${row['id'] ?? key}',
                createdAt: now,
                updatedAt: now,
              ),
            );
            existingVocKeys.add(key);
            importedVocs += 1;
          }

          for (final item in manuals) {
            if (item is! Map) continue;
            final row = Map<String, dynamic>.from(item);
            final question = row['question']?.toString().trim() ?? '';
            final answer = row['answer']?.toString().trim() ?? '';
            if (question.isEmpty || answer.isEmpty) continue;

            final key = _manualKey(question, answer);
            if (existingManualKeys.contains(key)) {
              duplicateSkips += 1;
              continue;
            }

            final now = DateTime.now();
            final id = _uuid.v4();
            await db.insert(
              AppConstants.tableKnowledgeBase,
              {
                'id': id,
                'question': question,
                'answer': answer,
                'category': row['category']?.toString() ?? '시스템매뉴얼',
                'customer': row['customer']?.toString(),
                'project': row['project']?.toString() ?? 'manual-upload',
                'voc_id': row['voc_id']?.toString(),
                'embedding': row['embedding']?.toString() ??
                    jsonEncode(VectorUtils.simpleTextEmbedding('$question $answer')),
                'resolved_at': row['resolved_at']?.toString() ?? now.toIso8601String(),
                'created_at': row['created_at']?.toString() ?? now.toIso8601String(),
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            existingManualKeys.add(key);
            importedManuals += 1;
          }

          _appendSyncLog('초기 동기화 성공: $exportTarget (VOC ${vocs.length}건 / 매뉴얼 ${manuals.length}건)');
        } catch (e) {
          failedTargets.add(exportTarget);
          _appendSyncLog('초기 동기화 실패: $exportTarget / $e');
        }
      }

      await _vocRepository.getAllVocs();
      if (failedTargets.isEmpty) {
        _bootstrapStatus =
            '초기 동기화 완료: VOC $importedVocs건, 매뉴얼 $importedManuals건, 중복 제외 $duplicateSkips건';
        _success = _bootstrapStatus;
      } else {
        _bootstrapStatus =
            '초기 동기화 일부 실패: 성공 ${targets.length - failedTargets.length}개 앱, 실패 ${failedTargets.length}개 앱';
        _error = _bootstrapStatus;
      }

      notifyListeners();
      return importedVocs + importedManuals;
    } catch (e) {
      _bootstrapStatus = '초기 동기화 실패: $e';
      _error = _bootstrapStatus;
      notifyListeners();
      return 0;
    } finally {
      _isBootstrapping = false;
      notifyListeners();
    }
  }

  Future<void> retryPendingSyncQueue() async {
    if (_syncRetryQueue.isEmpty) {
      _success = '재시도할 동기화 대기 건이 없습니다.';
      notifyListeners();
      return;
    }

    _start();
    try {
      final pending = List<_SyncRetryTask>.from(_syncRetryQueue);
      _syncRetryQueue.clear();
      await _persistRetryQueue();

      var successCount = 0;
      for (final task in pending) {
        try {
          await _postWithRetry(
            webhookUrl: task.endpoint,
            body: task.payload,
            headers: task.headers,
          );
          successCount += 1;
          _appendSyncLog('재시도 성공: ${task.endpoint}');
        } catch (e) {
          task.attempts += 1;
          task.lastError = '$e';
          _syncRetryQueue.add(task);
          _appendSyncLog('재시도 실패: ${task.endpoint} / $e');
        }
      }

      await _persistRetryQueue();

      if (_syncRetryQueue.isEmpty) {
        _lastSyncErrorDetails = null;
        _success = '동기화 재시도 완료: $successCount건 성공';
      } else {
        _lastSyncErrorDetails = _buildRetryFailureDetails();
        _error =
            '동기화 재시도 일부 실패: 성공 $successCount건, 잔여 ${_syncRetryQueue.length}건';
      }
    } finally {
      _end();
    }
  }

  Map<String, String>? _syncAuthHeaders() {
    final token = _normalizeBearerToken(_settingsViewModel.vocSyncBearerToken);
    if (token.isEmpty) return null;
    return {'Authorization': 'Bearer $token'};
  }

  String _normalizeBearerToken(String raw) {
    var token = raw.trim();
    if (token.toLowerCase().startsWith('bearer ')) {
      token = token.substring(7).trim();
    }
    return token;
  }

  Future<void> _postWithRetry({
    required String webhookUrl,
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    Object? lastError;
    for (var i = 0; i < _maxSyncRetries; i++) {
      try {
        await _webhook.postJson(
          webhookUrl: webhookUrl,
          body: body,
          headers: headers,
        );
        return;
      } catch (e) {
        lastError = e;
        if (i < _maxSyncRetries - 1) {
          final delay = _syncRetryBackoffMs * (1 << i);
          await Future.delayed(Duration(milliseconds: delay));
        }
      }
    }
    if (lastError != null) {
      throw lastError;
    }
    throw Exception('unknown sync error');
  }

  Future<void> _enqueueRetry({
    required String endpoint,
    required Map<String, dynamic> payload,
    required String label,
    Map<String, String>? headers,
    String? lastError,
  }) async {
    final event = payload['event']?.toString() ?? '';
    final duplicated = _syncRetryQueue.any(
      (item) => item.endpoint == endpoint && item.event == event,
    );
    if (duplicated) {
      return;
    }

    final payloadCopy =
        jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;

    _syncRetryQueue.add(
      _SyncRetryTask(
        endpoint: endpoint,
        payload: payloadCopy,
        headers: headers == null ? null : Map<String, String>.from(headers),
        label: label,
        event: event,
        attempts: 0,
        lastError: lastError,
      ),
    );
    await _persistRetryQueue();
    notifyListeners();
  }

  String _buildSyncFailureDetails({
    required String title,
    required List<String> targets,
  }) {
    final lines = <String>[title];
    for (final target in targets) {
      final task = _findLastRetryTaskByEndpoint(target);
      final reason = task?.lastError ?? '원인 미확인';
      lines.add('- $target');
      lines.add('  원인: $reason');
    }
    return lines.join('\n');
  }

  _SyncRetryTask? _findLastRetryTaskByEndpoint(String endpoint) {
    for (var i = _syncRetryQueue.length - 1; i >= 0; i--) {
      final task = _syncRetryQueue[i];
      if (task.endpoint == endpoint) {
        return task;
      }
    }
    return null;
  }

  String _buildRetryFailureDetails() {
    final lines = <String>['동기화 재시도 실패 상세'];
    for (final task in _syncRetryQueue) {
      lines.add('- ${task.endpoint}');
      lines.add('  시도횟수: ${task.attempts}');
      lines.add('  원인: ${task.lastError ?? '원인 미확인'}');
    }
    return lines.join('\n');
  }

  void _restoreRetryQueueIfReady() {
    if (_retryQueueRestored || _settingsViewModel.isLoading) {
      return;
    }
    unawaited(_restoreRetryQueue());
  }

  Future<void> _restoreRetryQueue() async {
    if (_retryQueueRestored) {
      return;
    }
    _retryQueueRestored = true;

    final raw = _settingsViewModel.vocSyncRetryQueueRaw.trim();
    if (raw.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return;
      }

      _syncRetryQueue
        ..clear()
        ..addAll(
          decoded
              .whereType<Map>()
              .map((e) => _SyncRetryTask.fromJson(Map<String, dynamic>.from(e))),
        );
      notifyListeners();
    } catch (_) {
      // 파싱 실패 시 잘못된 큐를 비워 앱 동작을 우선한다.
      await _settingsViewModel.saveSetting(
        AppConstants.settingVocSyncRetryQueue,
        '',
      );
    }
  }

  Future<void> _persistRetryQueue() async {
    final encoded = _syncRetryQueue.isEmpty
        ? ''
        : jsonEncode(_syncRetryQueue.map((e) => e.toJson()).toList());
    await _settingsViewModel.saveSetting(
      AppConstants.settingVocSyncRetryQueue,
      encoded,
    );
  }

  String _toFullSyncEndpoint(String target) {
    final trimmed = target.trim();
    if (trimmed.endsWith('/health')) {
      return '${trimmed.substring(0, trimmed.length - '/health'.length)}/webhook/sync/full';
    }
    if (trimmed.endsWith('/webhook/sync/full')) {
      return trimmed;
    }
    if (trimmed.endsWith('/webhook/sync')) {
      return '$trimmed/full';
    }
    if (trimmed.endsWith('/webhook/voc')) {
      return '${trimmed.substring(0, trimmed.length - '/webhook/voc'.length)}/webhook/sync/full';
    }
    if (trimmed.endsWith('/')) {
      return '${trimmed}webhook/sync/full';
    }
    return '$trimmed/webhook/sync/full';
  }

  String _toVocEndpoint(String target) {
    final trimmed = target.trim();
    if (trimmed.endsWith('/health')) {
      return '${trimmed.substring(0, trimmed.length - '/health'.length)}/webhook/voc';
    }
    if (trimmed.endsWith('/webhook/voc')) {
      return trimmed;
    }
    if (trimmed.endsWith('/webhook/sync/full')) {
      return '${trimmed.substring(0, trimmed.length - '/webhook/sync/full'.length)}/webhook/voc';
    }
    if (trimmed.endsWith('/webhook/sync')) {
      return '${trimmed.substring(0, trimmed.length - '/webhook/sync'.length)}/webhook/voc';
    }
    if (trimmed.endsWith('/')) {
      return '${trimmed}webhook/voc';
    }
    return '$trimmed/webhook/voc';
  }

  String _toVocExportEndpoint(String target) {
    final trimmed = target.trim();
    if (trimmed.endsWith('/health')) {
      return '${trimmed.substring(0, trimmed.length - '/health'.length)}/webhook/sync/export';
    }
    if (trimmed.endsWith('/webhook/sync/export') ||
        trimmed.endsWith('/webhook/voc/export')) {
      return trimmed;
    }
    if (trimmed.endsWith('/webhook/voc')) {
      return '${trimmed.substring(0, trimmed.length - '/webhook/voc'.length)}/webhook/sync/export';
    }
    if (trimmed.endsWith('/webhook/sync/full')) {
      return '${trimmed.substring(0, trimmed.length - '/webhook/sync/full'.length)}/webhook/sync/export';
    }
    if (trimmed.endsWith('/webhook/sync')) {
      return '$trimmed/export';
    }
    if (trimmed.endsWith('/')) {
      return '${trimmed}webhook/sync/export';
    }
    return '$trimmed/webhook/sync/export';
  }

  String _manualKey(String question, String answer) {
    return '${question.trim().toLowerCase()}|${answer.trim().toLowerCase()}';
  }

  String _normalizeVocStatus(String? rawStatus) {
    final value = (rawStatus ?? '').trim().toUpperCase();
    switch (value) {
      case AppConstants.vocStatusOpen:
      case AppConstants.vocStatusInProgress:
      case AppConstants.vocStatusResolved:
      case AppConstants.vocStatusRejected:
        return value;
      default:
        return AppConstants.vocStatusOpen;
    }
  }

  Future<String?> publishApprovedToConfluence({
    required VocEntity voc,
    required String approvedAnswer,
  }) async {
    _start();
    try {
      final pageUrl = await _connectors.confluencePublisher.publishApprovedAnswer(
        voc: voc,
        approvedAnswer: approvedAnswer,
      );
      _success = 'Confluence 문서화 완료';
      return pageUrl;
    } catch (e) {
      _error = 'Confluence 등록 실패: $e';
      return null;
    } finally {
      _end();
    }
  }

  void _start() {
    _isLoading = true;
    _error = null;
    _success = null;
    notifyListeners();
  }

  void _end() {
    _isLoading = false;
    notifyListeners();
  }

  void _beginFullSyncProgress({required int totalTargets}) {
    _isSyncingFull = true;
    _syncTotalTargets = totalTargets;
    _syncCompletedTargets = 0;
    _syncCurrentTarget = null;
    notifyListeners();
  }

  void _endFullSyncProgress() {
    _isSyncingFull = false;
    _syncCurrentTarget = null;
    notifyListeners();
  }

  void _appendSyncLog(String message) {
    final stamp = DateTime.now().toIso8601String();
    _syncRuntimeLogs.insert(0, '[$stamp] $message');
    if (_syncRuntimeLogs.length > 40) {
      _syncRuntimeLogs.removeRange(40, _syncRuntimeLogs.length);
    }
    notifyListeners();
  }

  void _startInboundSyncEventWatcher() {
    unawaited(_initializeInboundSyncEventCursor());
    _inboundEventPoller = Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(_pollInboundSyncEvents()),
    );
  }

  Future<void> _initializeInboundSyncEventCursor() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        AppConstants.tableSyncEvents,
        columns: ['seq'],
        orderBy: 'seq DESC',
        limit: 1,
      );
      if (rows.isNotEmpty) {
        _lastSeenSyncEventSeq = (rows.first['seq'] as int?) ?? 0;
      }
    } catch (_) {
      // 테이블이 아직 없는 초기 상태에서는 무시한다.
    }
  }

  Future<void> _pollInboundSyncEvents() async {
    final receiver = InAppSyncReceiverService.instance;
    final running = receiver.isRunning;
    final lastError = receiver.lastError;
    final receiverChanged =
        running != _inAppReceiverRunning || lastError != _inAppReceiverLastError;
    _inAppReceiverRunning = running;
    _inAppReceiverLastError = lastError;

    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        AppConstants.tableSyncEvents,
        where: 'seq > ?',
        whereArgs: [_lastSeenSyncEventSeq],
        orderBy: 'seq ASC',
      );

      if (rows.isEmpty) {
        if (receiverChanged) {
          notifyListeners();
        }
        return;
      }

      for (final row in rows) {
        final seq = (row['seq'] as int?) ?? 0;
        if (seq > _lastSeenSyncEventSeq) {
          _lastSeenSyncEventSeq = seq;
        }

        final event = InboundSyncEvent.fromMap(row);
        _recentInboundEvents.insert(0, event);
        if (_recentInboundEvents.length > 60) {
          _recentInboundEvents.removeRange(60, _recentInboundEvents.length);
        }

        final notifyText = _buildInboundEventNotificationText(event);
        _onInboundSyncEvent?.call(notifyText);
      }

      notifyListeners();
    } catch (_) {
      // 수신 이벤트 폴링 실패는 앱 동작을 막지 않는다.
      if (receiverChanged) {
        notifyListeners();
      }
    }
  }

  String _buildInboundEventNotificationText(InboundSyncEvent event) {
    final source = event.sourceApp?.trim().isNotEmpty == true
        ? event.sourceApp!.trim()
        : '다른 앱';
    final counts = event.counts;
    final vocs = counts['vocs'] ?? 0;
    final manuals = counts['manuals'] ?? 0;

    if (event.eventType == 'sync.full') {
      return '$source에서 전체 동기화 수신 (VOC $vocs건, 매뉴얼 $manuals건)';
    }
    return '$source에서 단건 VOC 동기화 수신';
  }
}

class InboundSyncEvent {
  final int seq;
  final String eventType;
  final String? sourceApp;
  final String? status;
  final String? message;
  final Map<String, int> counts;
  final DateTime createdAt;

  InboundSyncEvent({
    required this.seq,
    required this.eventType,
    required this.sourceApp,
    required this.status,
    required this.message,
    required this.counts,
    required this.createdAt,
  });

  factory InboundSyncEvent.fromMap(Map<String, Object?> row) {
    final countsRaw = row['counts_json']?.toString() ?? '{}';
    final parsedCounts = <String, int>{};
    try {
      final countsJson = jsonDecode(countsRaw);
      if (countsJson is Map) {
        for (final entry in countsJson.entries) {
          final key = entry.key.toString();
          final value = int.tryParse('${entry.value}') ?? 0;
          parsedCounts[key] = value;
        }
      }
    } catch (_) {
      // malformed counts_json
    }

    final createdAtRaw = row['created_at']?.toString();
    final createdAt = DateTime.tryParse(createdAtRaw ?? '') ?? DateTime.now();

    return InboundSyncEvent(
      seq: (row['seq'] as int?) ?? 0,
      eventType: row['event_type']?.toString() ?? 'unknown',
      sourceApp: row['source_app']?.toString(),
      status: row['status']?.toString(),
      message: row['message']?.toString(),
      counts: parsedCounts,
      createdAt: createdAt,
    );
  }
}

class _SyncRetryTask {
  final String endpoint;
  final Map<String, dynamic> payload;
  final Map<String, String>? headers;
  final String label;
  final String event;
  int attempts;
  String? lastError;

  _SyncRetryTask({
    required this.endpoint,
    required this.payload,
    required this.headers,
    required this.label,
    required this.event,
    required this.attempts,
    required this.lastError,
  });

  Map<String, dynamic> toJson() => {
        'endpoint': endpoint,
        'payload': payload,
        'headers': headers,
        'label': label,
        'event': event,
        'attempts': attempts,
        'lastError': lastError,
      };

  factory _SyncRetryTask.fromJson(Map<String, dynamic> json) {
    return _SyncRetryTask(
      endpoint: json['endpoint']?.toString() ?? '',
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : <String, dynamic>{},
      headers: json['headers'] is Map
          ? (json['headers'] as Map)
              .map((key, value) => MapEntry('$key', '$value'))
          : null,
      label: json['label']?.toString() ?? '',
      event: json['event']?.toString() ?? '',
      attempts: int.tryParse('${json['attempts'] ?? 0}') ?? 0,
      lastError: json['lastError']?.toString(),
    );
  }
}
