import 'package:ai_voc_assistant/data/services/voc_keyword_extractor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ordinary Korean sentence fragments do not become topics', () {
    expect(VocKeywordExtractor.extract('받은 하는 있는 해당 문의 입니다 주세요 확인 요청'), isEmpty);
    expect(VocKeywordExtractor.extract('2026 12345 the and this'), isEmpty);
  });
  test('Korean particles and English aliases share a meaningful topic', () {
    expect(VocKeywordExtractor.extract('로그인이 login 로그인은 로그인을'), {'로그인'});
    expect(VocKeywordExtractor.extract('메일에서 받은 첨부파일이 열리지 않습니다.'), {'첨부파일'});
    expect(VocKeywordExtractor.extract('메일 발송이 안됩니다'), {'메일 발송'});
  });
  test('technical error identifiers survive filtering', () {
    expect(VocKeywordExtractor.extract('ERR_CONNECTION_RESET 오류 발생'), contains('ERR_CONNECTION_RESET'));
    expect(VocKeywordExtractor.extract('HTTP 503 응답'), contains('HTTP 503'));
  });
}
