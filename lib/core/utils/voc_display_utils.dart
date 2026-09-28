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

  static String label(VocEntity voc) => '${code(voc)} · ${voc.title}';
}
