import '../../domain/entities/voc_entity.dart';

class VocDisplayUtils {
  VocDisplayUtils._();

  static String code(VocEntity voc) => codeFromProject(voc.project);

  static String codeFromProject(String? project) {
    final parts = (project ?? '')
        .split('|')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty && value != '미입력')
        .toList();
    if (parts.isEmpty) return '등록 VOC';

    final last = parts.last;
    if (parts.length >= 2 && RegExp(r'^\d+$').hasMatch(last)) {
      return '${parts[parts.length - 2]}-$last';
    }
    return last;
  }

  /// Stored formats: project | code | number, project | CODE-123,
  /// or a plain project name. Never substitute a database UUID for a number.
  static ({String projectName, String number}) projectIdentity(String raw) {
    final parts = raw.split('|').map((s) => s.trim()).toList();
    String clean(String value) => value == '미입력' ? '' : value;
    if (parts.length >= 3) {
      final project = clean(parts.first);
      final code = clean(parts[parts.length - 2]);
      final number = clean(parts.last);
      return (projectName: project, number: number.isEmpty ? ''
          : RegExp(r'^\d+$').hasMatch(number) && code.isNotEmpty
              ? '$code-$number' : number);
    }
    if (parts.length == 2) {
      final first = clean(parts.first);
      final last = clean(parts.last);
      if (RegExp(r'^[A-Z][A-Z0-9_]*$').hasMatch(first) &&
          RegExp(r'^\d+$').hasMatch(last)) {
        return (projectName: '', number: '$first-$last');
      }
      return (projectName: first, number: last);
    }
    final value = clean(parts.first);
    if (RegExp(r'^[A-Za-z][A-Za-z0-9_]*-\d+$').hasMatch(value)) {
      return (projectName: '', number: value);
    }
    return (projectName: value, number: '');
  }

  static String label(VocEntity voc) => '${code(voc)} · ${voc.title}';
}

