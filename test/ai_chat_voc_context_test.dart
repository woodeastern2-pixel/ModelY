import 'package:ai_voc_assistant/data/services/ai_service.dart';
import 'package:ai_voc_assistant/domain/entities/knowledge_base_entity.dart';
import 'package:ai_voc_assistant/domain/entities/voc_entity.dart';
import 'package:ai_voc_assistant/domain/entities/response_entity.dart';
import 'package:ai_voc_assistant/domain/repositories/knowledge_base_repository.dart';
import 'package:ai_voc_assistant/domain/repositories/settings_repository.dart';
import 'package:ai_voc_assistant/domain/repositories/voc_repository.dart';
import 'package:ai_voc_assistant/presentation/viewmodels/ai_viewmodel.dart';
import 'package:ai_voc_assistant/presentation/viewmodels/settings_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unanswered requests are context only, never offline answers', () async {
    final now = DateTime(2026, 9, 28);
    final voc = VocEntity(id: 'question-only', title: '진행권 부여 방법',
      content: '참석자 메뉴는 어디에 있나요?', category: '문의',
      customer: '고객', project: '미팅', priority: 'NORMAL', status: 'OPEN',
      createdAt: now, updatedAt: now);
    final settings = SettingsViewModel(_EmptySettingsRepository());
    final vm = AiViewModel(_EmptyKnowledgeBaseRepository(), _VocRepository([voc]), settings);
    addTearDown(vm.dispose);
    addTearDown(settings.dispose);
    expect(await vm.searchSimilarVocs('진행권 부여 방법'), isEmpty);
    expect(await vm.generateAnswer(voc.title, voc.content), isNull);
    expect(vm.hasAnswer, isFalse);
    expect(vm.error, contains('등록된 질문은 답변으로 표시하지 않습니다'));
    expect(await vm.resolveChatReferences('진행권 부여 방법'), hasLength(1));
  });

  test('configured but unreachable AI cannot create a copilot answer', () async {
    final settings = SettingsViewModel(_EmptySettingsRepository());
    final vm = AiViewModel(_EmptyKnowledgeBaseRepository(), _VocRepository([]), settings,
        aiService: _ConnectionService(fail: true));
    addTearDown(vm.dispose);
    addTearDown(settings.dispose);
    expect(await vm.checkCopilotConnection(), isFalse);
    expect(await vm.sendChatMessage('로그인 오류 해결 방법'), isNull);
    expect(vm.chatMessages, isEmpty);
    expect(vm.isAiConnected, isFalse);
    expect(vm.chatError, AiViewModel.copilotUnavailable);
    expect(vm.isChatting, isFalse);
  });

  test('copilot readiness requires a nonempty live response', () async {
    final settings = SettingsViewModel(_EmptySettingsRepository());
    final service = _ConnectionService();
    final vm = AiViewModel(_EmptyKnowledgeBaseRepository(), _VocRepository([]), settings,
        aiService: service);
    addTearDown(vm.dispose);
    addTearDown(settings.dispose);
    expect(vm.isAiConnected, isFalse);
    expect(await vm.checkCopilotConnection(), isTrue);
    expect(vm.isAiConnected, isTrue);
    service.empty = true;
    expect(await vm.checkCopilotConnection(), isFalse);
    expect(vm.isAiConnected, isFalse);
  });

  test(
    'AI Chat includes a matching registered VOC without a saved answer',
    () async {
      final now = DateTime(2026, 8, 14);
      final voc = VocEntity(
        id: 'voc-1',
        title: '로그인 오류 문의',
        content: '사용자가 로그인 버튼을 누르면 인증 오류가 발생합니다.',
        category: '장애',
        customer: '테스트 고객사',
        project: 'VOC 시스템',
        priority: 'HIGH',
        status: '미처리',
        createdAt: now,
        updatedAt: now,
      );
      final settings = SettingsViewModel(_EmptySettingsRepository());
      final viewModel = AiViewModel(
        _EmptyKnowledgeBaseRepository(),
        _VocRepository([voc]),
        settings,
      );

      final references = await viewModel.resolveChatReferences('로그인 인증 오류');

      expect(references, hasLength(1));
      expect(references.single.knowledgeBase.vocId, 'voc-1');
      expect(
        references.single.knowledgeBase.answer,
        contains('사용자가 로그인 버튼을 누르면 인증 오류가 발생합니다.'),
      );

      final prompt = AiPrompts.chatUser(
        '로그인 오류가 얼마나 있나요?',
        const [],
        references,
      );
      expect(prompt, contains('출처: 등록 VOC'));
      expect(prompt, contains('상태: 미처리'));
      expect(AiPrompts.chatSystem, contains('실제로 적힌 사실만'));
      expect(AiPrompts.chatSystem, contains('확인된 후보 중'));

      final followUpReferences = await viewModel.resolveChatReferences(
        '그럼 그 VOC의 내용을 다시 보여줘',
        preferredVocIds: const ['voc-1'],
      );
      expect(
        followUpReferences.map((item) => item.knowledgeBase.vocId),
        contains('voc-1'),
      );

      viewModel.dispose();
    },
  );
}

class _EmptyKnowledgeBaseRepository implements KnowledgeBaseRepository {
  @override
  Future<List<KnowledgeBaseEntity>> getAllEntries() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _VocRepository implements VocRepository {
  final List<VocEntity> vocs;

  _VocRepository(this.vocs);

  @override
  Future<List<VocEntity>> getAllVocs() async => vocs;

  @override
  Future<List<ResponseEntity>> getResponsesByVocId(String vocId) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptySettingsRepository implements SettingsRepository {
  @override
  Future<Map<String, String>> getAllSettings() async => const {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}


class _ConnectionService extends AiService {
  _ConnectionService({this.fail = false});
  bool fail;
  bool empty = false;
  @override
  bool get isConfigured => true;
  @override
  Future<String> testConnection() async {
    if (fail) throw StateError('offline');
    return empty ? '' : 'connected';
  }
}
