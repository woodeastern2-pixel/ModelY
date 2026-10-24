import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ai_voc_assistant/data/services/bundled_qwen_service.dart';
import 'package:flutter/services.dart';
import 'package:ai_voc_assistant/data/services/ai_service.dart';
import 'package:ai_voc_assistant/domain/entities/knowledge_base_entity.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('bundled model runs in the Windows app without Ollama', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: Center(child: Text('VoC Mate · 내장 Qwen 실행 검증')),
    )));
    final root = Platform.environment['VOC_QWEN_SMOKE_ROOT'];
    expect(root, isNotNull);
    final service = BundledQwenService(bundleDirectory: Directory(root!));
    final results = <Map<String, Object>>[];
    try {
      expect(service.isInstalled, isTrue);
      final pack=jsonDecode(await rootBundle.loadString('assets/manuals/brity_documents.json')) as Map<String,dynamic>;
      final row=(pack['entries'] as List).singleWhere((r)=>r['id']=='manual-pack-works-3-0671');
      final evidence=[SimilarVocResult(knowledgeBase:KnowledgeBaseEntity(
        id:row['id'],question:row['question'],answer:row['answer'],category:'시스템매뉴얼',
        customer:row['sourceName'],project:row['project'],
        createdAt:DateTime(2026),resolvedAt:DateTime(2026)),similarityScore:1)];
      final ai = AiService()..configureBundledQwen();
      final clock = Stopwatch()..start();
      final raw = await service.generate(ai.reviewDraftSystemPrompt,
        AiPrompts.answerGenerationUser('메신저 알림 설정',
          '메시지 알림과 알림음은 어디에서 설정하나요?',evidence),maxTokens:512);
      final result=ai.parseReviewDraft(raw,evidence);
      results.add({'case':'korean_notification_original','answer':result.answer,
        'sources':result.referencedCaseIds,'elapsed_ms':clock.elapsedMilliseconds});
      expect(result.answer,contains('알림'));
      expect(result.answer,contains('환경설정'));
      expect(result.answer,contains('알림음'));
      expect(result.referencedCaseIds,contains(row['id']));
      expect(result.answer, isNot(contains('<think>')));
      final unknown = await service.generate(
        '주어진 자료만 사용하세요. 답이 자료에 없으면 반드시 "자료에서 확인할 수 없습니다"라고 답하세요.',
        '[자료] 메신저 새 메시지 알림을 켤 수 있습니다.\n'
        '[질문] 이 회사의 메신저 메시지 보관 기간은 며칠인가요?',
        maxTokens: 96,
      );
      results.add({'case': 'unsupported_policy', 'answer': unknown});
      expect(unknown, contains('확인할 수 없'));
      expect(RegExp(r'\d+\s*일').hasMatch(unknown), isFalse);
    } catch (error) {
      results.add({'case': 'native_model_failure', 'error': error.toString()});
      rethrow;
    } finally {
      await service.stop();
      final report = File('artifacts/bundled-qwen-smoke.json');
      await report.parent.create(recursive: true);
      await report.writeAsString(const JsonEncoder.withIndent('  ').convert(results));
    }
  }, timeout: const Timeout(Duration(minutes: 7)));
}
