import 'package:ai_voc_assistant/core/utils/search_query_expander.dart';
import 'package:ai_voc_assistant/core/utils/vector_utils.dart';
import 'package:ai_voc_assistant/core/utils/voc_category_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VectorUtils', () {
    test('returns one for identical vectors', () {
      expect(
        VectorUtils.cosineSimilarity([1, 2, 3], [1, 2, 3]),
        closeTo(1, 1e-12),
      );
    });

    test('returns zero for invalid or zero vectors', () {
      expect(VectorUtils.cosineSimilarity([], []), 0);
      expect(VectorUtils.cosineSimilarity([1], [1, 2]), 0);
      expect(VectorUtils.cosineSimilarity([0, 0], [1, 1]), 0);
    });

    test('text embedding has requested size and is normalized', () {
      final embedding = VectorUtils.simpleTextEmbedding('로그인 오류 오류', dim: 32);
      final squaredNorm = embedding.fold<double>(0, (sum, value) {
        return sum + (value * value);
      });

      expect(embedding, hasLength(32));
      expect(squaredNorm, closeTo(1, 1e-12));
    });
  });

  group('SearchQueryExpander', () {
    test('expands Korean and English Brity product names bidirectionally', () {
      expect(SearchQueryExpander.expand('미팅 화면 공유'), contains('meeting'));
      expect(SearchQueryExpander.expand('meeting 화면 공유'), contains('미팅'));
      expect(SearchQueryExpander.expand('메신저 알림'), contains('messenger'));
      expect(SearchQueryExpander.expand('drive 권한'), contains('드라이브'));
      expect(SearchQueryExpander.expand('코파일럿 요약'), contains('copilot'));
    });

    test(
      'matches a Korean product query against English knowledge metadata',
      () {
        expect(
          SearchQueryExpander.matches(
            '미팅 화면 공유',
            'Brity Meeting에서 화면 공유 기능은 어떻게 사용하나요?',
          ),
          isTrue,
        );
        expect(
          SearchQueryExpander.matches(
            '메신저 로그인',
            'Brity Messenger Desktop 로그인 및 계정 설정',
          ),
          isTrue,
        );
        expect(
          SearchQueryExpander.matches(
            '드라이브 권한',
            'Brity Drive 권한 안내',
          ),
          isTrue,
        );
        expect(
          SearchQueryExpander.matches(
            '미팅에서 화면 공유',
            'Brity Meeting에서 화면 공유 기능은 어떻게 사용하나요?',
          ),
          isTrue,
        );
      },
    );
  });

  group('VocCategoryCatalog', () {
    test('preserves an allowed category', () {
      expect(VocCategoryCatalog.normalize('장애'), '장애');
    });

    test('normalizes legacy categories using VOC text', () {
      expect(
        VocCategoryCatalog.normalize(
          'Legacy',
          title: '로그인 권한이 없습니다',
        ),
        '권한',
      );
    });

    test('aggregates legacy categories into normalized groups', () {
      expect(
        VocCategoryCatalog.aggregateCounts({
          '장애': 2,
          'error report': 3,
          'unknown': 4,
        }),
        {'장애': 5, '기타': 4},
      );
    });
  });
}
