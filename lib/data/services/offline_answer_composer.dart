/// A source-bound answer plan, with no network calls or invented UI controls.
class OfflineAnswerFragment {
  final String text;
  final String source;
  const OfflineAnswerFragment(this.text, this.source);
}

class OfflineAnswerComposer {
  static final _procedure = RegExp(
      r'어떻게|방법|절차|하려면|등록|설정|복원|복구|설치|취소|how',
      caseSensitive: false);
  static final _action = RegExp(
      r'클릭|누르|누릅|선택|입력|저장|엽니|여세요|이동|실행|드래그|체크|click|select|enter|open|press',
      caseSensitive: false);
  static final _restriction = RegExp(
      r'주의|제한|불가|않습니다|없습니다|없으며|없으므로|최대|최소|경우에만|해야만|caution|warning|cannot|must|only|not available',
      caseSensitive: false);

  String compose(String query, List<OfflineAnswerFragment> fragments) {
    final sections = <String>[];
    final seen = <String>{};
    for (final fragment in fragments) {
      final statements = <String>[];
      final steps = <String>[];
      final conditions = <String>[];
      final provenance = <String>[];
      // Preserve table rows and conditional sentences as complete units.
      // Never split a sentence at 'if', '경우', or a Korean conjunctive ending.
      for (final paragraph in fragment.text.split('\n')) {
        final line = paragraph.trim();
        if (line.isEmpty) continue;
        if (line.startsWith('[출처]') || line.startsWith('출처:')) {
          provenance.add(line);
          continue;
        }
        if (line.startsWith('매뉴얼 근거 발췌')) continue;
        for (var sentence in line.split(RegExp(r'(?<=[.!?])\s+(?=[^0-9])'))) {
          sentence = sentence.replaceFirst(RegExp(r'^\s*(?:[-•]|\d+[.)])\s+'), '').trim();
          if (sentence.isEmpty || sentence == 'N/A' || sentence.endsWith('?')) continue;
          final identity = sentence.replaceAll(RegExp(r'\s+'), '');
          if (!seen.add(identity)) continue;
          if (_restriction.hasMatch(sentence)) {
            conditions.add(sentence);
          } else if (_procedure.hasMatch(query) && _action.hasMatch(sentence)) {
            steps.add(sentence);
          } else {
            statements.add(sentence);
          }
        }
      }
      if (statements.isEmpty && steps.isEmpty && conditions.isEmpty) continue;
      final parts = <String>[];
      if (steps.isNotEmpty) {
        parts.add('다음 순서로 진행해 주세요.\n${[
          for (var i = 0; i < steps.length; i++) '${i + 1}. ${steps[i]}'
        ].join('\n')}');
      }
      if (statements.isNotEmpty) parts.add(statements.join('\n'));
      if (conditions.isNotEmpty) {
        parts.add('확인할 조건\n${conditions.map((s) => '• $s').join('\n')}');
      }
      parts.add('근거: ${fragment.source}${provenance.isEmpty ? '' : '\n${provenance.join('\n')}'}');
      sections.add(parts.join('\n\n'));
    }
    // Different procedures retain their source boundaries; they are never
    // joined into a fictitious single workflow across versions or products.
    return sections.join('\n\n추가 참고 안내\n\n');
  }
}
