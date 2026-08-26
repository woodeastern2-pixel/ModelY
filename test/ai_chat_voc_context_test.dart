import 'package:ai_voc_assistant/data/services/ai_service.dart';
import 'package:ai_voc_assistant/domain/entities/knowledge_base_entity.dart';
import 'package:ai_voc_assistant/domain/entities/voc_entity.dart';
import 'package:ai_voc_assistant/domain/repositories/knowledge_base_repository.dart';
import 'package:ai_voc_assistant/domain/repositories/settings_repository.dart';
import 'package:ai_voc_assistant/domain/repositories/voc_repository.dart';
import 'package:ai_voc_assistant/presentation/viewmodels/ai_viewmodel.dart';
import 'package:ai_voc_assistant/presentation/viewmodels/settings_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptySettingsRepository implements SettingsRepository {
  @override
  Future<Map<String, String>> getAllSettings() async => const {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
