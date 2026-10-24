/// Separates machine transcription from the authored manual explanation.
/// The stored source stays unchanged and remains searchable.
class ManualContent {
  final String body;
  final String transcription;
  const ManualContent(this.body, this.transcription);

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
