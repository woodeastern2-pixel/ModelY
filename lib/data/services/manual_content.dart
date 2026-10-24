
/// Separates machine transcription from the authored manual explanation.
/// The stored source stays unchanged and remains searchable.
class ManualContent {
  final String body;
  final String transcription;
  final String original;
  const ManualContent(this.body, this.transcription, {this.original = ''});

  /// Presentation only: retrieval and the stored source are not rewritten.
  factory ManualContent.forDisplay(String text, {required String entryId}) {
    final parsed = ManualContent.parse(text);
    return ManualContent(
      cleanDiagramLabels(parsed.body),
      parsed.transcription,
      original: '',
    );
  }

  /// Remove detached diagram letters only if at least three distinct letters
  /// have matching prose definitions. Keep real lists, codes and equations.
  static String cleanDiagramLabels(String text) {
    final lines = text.split('\n');
    final definitions = RegExp(r'^\s*([a-z])\.\s+\S', multiLine: true)
        .allMatches(text).map((m) => m.group(1)!).toSet();
    final detached = lines.where((line) => RegExp(r'^\s*[a-z]\s*$').hasMatch(line))
        .map((line) => line.trim()).toSet();
    final removable = detached.intersection(definitions);
    final cleaned = lines.where((line) =>
        removable.length < 3 || !removable.contains(line.trim()))
        .map((line) => removable.length >= 3 ? line.trim() : line.trimRight())
        .join('\n');
    return cleaned.replaceAll(RegExp(r'\n[ \t]*\n(?:[ \t]*\n)+'), '\n\n').trim();
  }

  factory ManualContent.parse(String text) {
    final marker = RegExp(r'\[이미지에서 읽은 글자[^\]]*\]').firstMatch(text);
    if (marker == null) return ManualContent(text.trim(), '');
    final source = text.indexOf('[출처]', marker.end);
    final end = source < 0 ? text.length : source;
    return ManualContent(
      [text.substring(0, marker.start).trim(),
        if (source >= 0) text.substring(source).trim()]
          .where((s) => s.isNotEmpty).join('\n\n'),
      text.substring(marker.end, end).trim(),
    );
  }
}

