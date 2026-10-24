import '../../domain/entities/knowledge_base_entity.dart';

/// Document-level policy. English product names inside Korean manuals are valid.
class ManualLanguagePolicy {
  static final _entryExclusions = Expando<bool>();
  static bool retiredSource(String id, String source) =>
      id.startsWith('brity-messenger-desktop-') ||
      id.startsWith('brity-messenger-mobile-') ||
      id.startsWith('brity-meeting-pc-') ||
      id.startsWith('brity-meeting-mobile-') ||
      id.startsWith('brity-drive-') ||
      id.startsWith('brity-copilot-') ||
      id.startsWith('raw-messenger-desktop-') ||
      id.startsWith('raw-messenger-mobile-') ||
      const {'messenger-desktop', 'messenger-mobile'}.contains(id) ||
      RegExp(
        r'https?://[^\s]+/(?:en|vn)(?:/|\b)|BrityMessenger_UserManual_.*_EN\.pdf|messenger-(?:desktop|mobile)\.pdf|Brity Messenger User (?:Manual|Guide)',
        caseSensitive: false,
      ).hasMatch(source);

  static bool englishDocument(String text) {
    final korean = RegExp(r'[가-힣]').allMatches(text).length;
    final latin = RegExp(r'[A-Za-z]').allMatches(text).length;
    return (latin >= 30 && korean == 0) ||
        (latin >= 100 && korean / (latin + korean) < 0.08);
  }

  static bool excludedEntry(KnowledgeBaseEntity entry) =>
      _entryExclusions[entry] ??= _evaluateEntry(entry);

  static bool _evaluateEntry(KnowledgeBaseEntity entry) {
    if (entry.vocId != null) return false;
    final source = '${entry.customer ?? ''}\n${entry.answer}';
    if (retiredSource(entry.id, source)) return true;
    // Original passages inherit the document-level decision made at install.
    // A Korean manual may have a table consisting entirely of English UI names.
    if (entry.id.startsWith('raw-')) return false;
    return entry.category == '시스템매뉴얼' && englishDocument(entry.answer);
  }

  static bool excludedRow(Map<String, dynamic> row) => excludedEntry(
        KnowledgeBaseEntity(
          id: row['id'] as String,
          question: row['question'] as String,
          answer: row['answer'] as String,
          category: row['category'] as String? ?? '',
          customer: row['customer'] as String?,
          project: row['project'] as String?,
          vocId: row['voc_id'] as String?,
          createdAt: DateTime(2026),
          resolvedAt: DateTime(2026),
        ),
      );

  static bool excludedDocument(Map<String, dynamic> document) =>
      document['language'] == 'en' ||
      retiredSource(
        document['id'] as String? ?? '',
        document['filename'] as String? ?? '',
      ) ||
      englishDocument(
        (document['blocks'] as List? ?? [])
            .map((b) => '${b['text'] ?? ''} ${b['ocr'] ?? ''}')
            .join('\n'),
      );
}
