class ManualSection {
  final String heading;
  final String body;
  const ManualSection(this.heading, this.body);
}

/// Headings define procedures; page breaks do not separate steps from caveats.
class ManualSectioner {
  static List<ManualSection> split(String text) {
    final paragraphs = text
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty);
    final sections = <ManualSection>[];
    final buffer = <String>[];
    var heading = '';
    var length = 0;
    void flush() {
      if (buffer.isEmpty) return;
      sections.add(ManualSection(heading, buffer.join('\n\n')));
      buffer.clear();
      length = 0;
    }

    for (var paragraph in paragraphs) {
      final first = paragraph.split('\n').first;
      final explicitHeading = first.startsWith('[제목] ') ||
          RegExp(r'^#{1,4}\s+|^\d+\.\d+(?:\.\d+)*\s*[^\d]').hasMatch(first);
      final condition =
          RegExp(r'주의|제한|조건|불가|않습니다|없습니다|경우|해야').hasMatch(paragraph);
      if (explicitHeading) {
        flush();
        paragraph = paragraph.replaceFirst(
          RegExp(r'^\[제목\]\s*|^#{1,4}\s+'),
          '',
        );
        heading = paragraph.split('\n').first;
      } else if (length > 6000 &&
          !condition &&
          !RegExp(r'^\d+[.)]\s|^\[페이지').hasMatch(first)) {
        flush();
      }
      if (heading.isEmpty) heading = paragraph.split('\n').first;
      buffer.add(paragraph);
      length += paragraph.length;
    }
    flush();
    return sections;
  }
}
