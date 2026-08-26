import 'dart:io';

import 'package:excel/excel.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/voc_entity.dart';

class ExcelService {
  Future<List<Map<String, String>>> importVocRows(String filePath) async {
    final normalized = filePath.toLowerCase();
    if (normalized.endsWith('.csv')) {
      return _importFromCsv(filePath);
    }

    final bytes = await File(filePath).readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return [];

    final sheet = _pickImportSheet(excel);
    if (sheet == null || sheet.rows.isEmpty) return [];

    final header = sheet.rows.first
        .map((c) => c?.value?.toString().trim() ?? '')
        .toList();

    final rows = <Map<String, String>>[];
    for (int i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (row.every((c) => c == null || (c.value?.toString().trim().isEmpty ?? true))) {
        continue;
      }

      final map = <String, String>{};
      for (int j = 0; j < header.length; j++) {
        final key = header[j];
        if (key.isEmpty) continue;
        final value = j < row.length ? (row[j]?.value?.toString() ?? '') : '';
        map[key] = value;
      }
      rows.add(map);
    }

    return rows;
  }

  Sheet? _pickImportSheet(Excel excel) {
    // 1) 템플릿 시트명을 우선 사용
    final template = excel.tables['VOC_IMPORT_TEMPLATE'];
    if (template != null && template.rows.isNotEmpty) {
      return template;
    }

    // 2) 헤더에 VOC 컬럼이 포함된 시트를 탐색
    for (final sheet in excel.tables.values) {
      if (sheet == null || sheet.rows.isEmpty) continue;
      final headers = sheet.rows.first
          .map((c) => c?.value?.toString().trim().toLowerCase() ?? '')
          .toSet();

      final hasVocColumns = headers.contains('voc 제목') ||
          headers.contains('voc 내용') ||
          headers.contains('title') ||
          headers.contains('content');

      if (hasVocColumns) {
        return sheet;
      }
    }

    // 3) 완전 빈 시트를 제외한 첫 번째 시트 사용
    for (final sheet in excel.tables.values) {
      if (sheet == null || sheet.rows.isEmpty) continue;
      final hasAnyData = sheet.rows.any(
        (row) => row.any(
          (c) => c != null && (c.value?.toString().trim().isNotEmpty ?? false),
        ),
      );
      if (hasAnyData) return sheet;
    }

    return excel.tables.values.first;
  }

  Future<String> exportVocs({
    required String filePath,
    required List<VocEntity> vocs,
    required List<Map<String, dynamic>> responses,
  }) async {
    if (filePath.toLowerCase().endsWith('.csv')) {
      final csv = StringBuffer();
      csv.writeln([
        'id',
        'title',
        'content',
        'category',
        'tags',
        'customer',
        'project',
        'priority',
        'status',
        'urgency',
        'business_type',
        'department',
        'assignee',
        'duplicate_score',
        'jira_required',
        'created_at',
      ].map(_escapeCsv).join(','));
      for (final v in vocs) {
        csv.writeln([
          v.id,
          v.title,
          v.content,
          v.category,
          v.tags ?? '',
          v.customer,
          v.project,
          v.priority,
          v.status,
          v.urgency ?? '',
          v.businessType ?? '',
          v.department ?? '',
          v.assignee ?? '',
          '${v.duplicateScore ?? 0}',
          v.jiraRequired ? 'Y' : 'N',
          v.createdAt.toIso8601String(),
        ].map(_escapeCsv).join(','));
      }

      csv.writeln();
      csv.writeln([
        'id',
        'voc_id',
        'content',
        'status',
        'ai_generated',
        'confidence_score',
        'approved_by',
        'adoption_count',
        'usage_count',
        'last_used_at',
        'created_at',
      ].map(_escapeCsv).join(','));
      for (final r in responses) {
        csv.writeln([
          r['id'] ?? '',
          r['voc_id'] ?? '',
          r['content'] ?? '',
          r['status'] ?? '',
          r['ai_generated'] ?? '',
          r['confidence_score'] ?? '',
          r['approved_by'] ?? '',
          r['adoption_count'] ?? '',
          r['usage_count'] ?? '',
          r['last_used_at'] ?? '',
          r['created_at'] ?? '',
        ].map(_escapeCsv).join(','));
      }

      await File(filePath).writeAsString(csv.toString());
      return filePath;
    }

    final excel = Excel.createExcel();
    final sheet = excel['VOC'];

    final header = [
      'id',
      'title',
      'content',
      'category',
      'tags',
      'customer',
      'project',
      'priority',
      'status',
      'urgency',
      'business_type',
      'department',
      'assignee',
      'duplicate_score',
      'jira_required',
      'created_at',
    ];

    sheet.appendRow(header.map(TextCellValue.new).toList());

    for (final v in vocs) {
      sheet.appendRow([
        TextCellValue(v.id),
        TextCellValue(v.title),
        TextCellValue(v.content),
        TextCellValue(v.category),
        TextCellValue(v.tags ?? ''),
        TextCellValue(v.customer),
        TextCellValue(v.project),
        TextCellValue(v.priority),
        TextCellValue(v.status),
        TextCellValue(v.urgency ?? ''),
        TextCellValue(v.businessType ?? ''),
        TextCellValue(v.department ?? ''),
        TextCellValue(v.assignee ?? ''),
        TextCellValue('${v.duplicateScore ?? 0}'),
        TextCellValue(v.jiraRequired ? 'Y' : 'N'),
        TextCellValue(v.createdAt.toIso8601String()),
      ]);
    }

    final responseSheet = excel['Responses'];
    responseSheet.appendRow([
      TextCellValue('id'),
      TextCellValue('voc_id'),
      TextCellValue('content'),
      TextCellValue('status'),
      TextCellValue('ai_generated'),
      TextCellValue('confidence_score'),
      TextCellValue('approved_by'),
      TextCellValue('adoption_count'),
      TextCellValue('usage_count'),
      TextCellValue('last_used_at'),
      TextCellValue('created_at'),
    ]);

    for (final r in responses) {
      responseSheet.appendRow([
        TextCellValue((r['id'] ?? '').toString()),
        TextCellValue((r['voc_id'] ?? '').toString()),
        TextCellValue((r['content'] ?? '').toString()),
        TextCellValue((r['status'] ?? '').toString()),
        TextCellValue((r['ai_generated'] ?? '').toString()),
        TextCellValue((r['confidence_score'] ?? '').toString()),
        TextCellValue((r['approved_by'] ?? '').toString()),
        TextCellValue((r['adoption_count'] ?? '').toString()),
        TextCellValue((r['usage_count'] ?? '').toString()),
        TextCellValue((r['last_used_at'] ?? '').toString()),
        TextCellValue((r['created_at'] ?? '').toString()),
      ]);
    }

    final data = excel.encode();
    if (data == null) {
      throw Exception('엑셀 인코딩 실패');
    }
    await File(filePath).writeAsBytes(data);
    return filePath;
  }

  Future<String> exportVocTemplate({required String filePath}) async {
    final headers = [
      '고객명',
      '업무 구분',
      '프로젝트명',
      '프로젝트 코드',
      'VOC 번호',
      '카테고리',
      '우선순위',
      'VOC 제목',
      'VOC 내용',
      '답변',
      '답변2',
    ];

    final samples = [
      [
        'A사',
        '운영',
        '포털 고도화',
        'GVBSO',
        'GVBSO-123',
        '장애',
        'HIGH',
        '로그인 실패 오류',
        '사내 포털 로그인 시 비밀번호 오류가 반복 발생합니다.',
        '불편을 드려 죄송합니다. 비밀번호 재설정을 먼저 진행해 주세요.',
        '동일 이슈가 반복되면 운영팀으로 추가 확인 요청 부탁드립니다.',
      ],
      [
        'B사',
        '개발',
        '운영 리포트',
        'GVBSO',
        'GVBSO-124',
        '기능문의',
        'MEDIUM',
        '엑셀 다운로드 지연',
        '리포트 엑셀 다운로드가 1분 이상 걸립니다.',
        '현재 트래픽 증가로 지연이 발생하고 있습니다. 잠시 후 재시도해 주세요.',
        '',
      ],
    ];

    if (filePath.toLowerCase().endsWith('.csv')) {
      final csv = StringBuffer();
      csv.writeln(headers.map(_escapeCsv).join(','));
      for (final row in samples) {
        csv.writeln(row.map(_escapeCsv).join(','));
      }
      await File(filePath).writeAsString(csv.toString());
      return filePath;
    }

    final excel = Excel.createExcel();
    // createExcel() 기본 시트를 그대로 사용해 첫 번째 빈 시트가 생기지 않게 한다.
    final firstSheetName = excel.tables.keys.first;
    final sheet = excel[firstSheetName];
    sheet.appendRow(headers.map(TextCellValue.new).toList());
    for (final row in samples) {
      sheet.appendRow(row.map(TextCellValue.new).toList());
    }

    final guide = excel['GUIDE'];
    guide.appendRow([TextCellValue('컬럼'), TextCellValue('설명')]);
    guide.appendRow([TextCellValue('고객명'), TextCellValue('필수 권장: 고객사 이름')]);
    guide.appendRow([TextCellValue('업무 구분'), TextCellValue('선택: 예) 운영/개발/문의')]);
    guide.appendRow([TextCellValue('프로젝트명'), TextCellValue('필수 권장: 프로젝트 이름')]);
    guide.appendRow([TextCellValue('프로젝트 코드'), TextCellValue('선택: 설정의 프로젝트 코드와 매칭 (예: GVBSO)')]);
    guide.appendRow([TextCellValue('VOC 번호'), TextCellValue('선택: 예) GVBSO-123')]);
    guide.appendRow([TextCellValue('카테고리'), TextCellValue('선택: 기본값 기능문의')]);
    guide.appendRow([TextCellValue('우선순위'), TextCellValue('선택: HIGH/MEDIUM/LOW')]);
    guide.appendRow([TextCellValue('VOC 제목'), TextCellValue('필수: VOC 제목')]);
    guide.appendRow([TextCellValue('VOC 내용'), TextCellValue('필수: VOC 내용')]);
    guide.appendRow([TextCellValue('답변/답변2..'), TextCellValue('선택: 여러 답변 컬럼 사용 가능, 한 셀에 여러 답변은 "||" 또는 줄바꿈으로 구분')]);

    final data = excel.encode();
    if (data == null) {
      throw Exception('템플릿 인코딩 실패');
    }
    await File(filePath).writeAsBytes(data);
    return filePath;
  }

  String normalizePriority(String raw) {
    final v = raw.trim().toUpperCase();
    if (v == 'HIGH' || v == 'H') return AppConstants.priorityHigh;
    if (v == 'LOW' || v == 'L') return AppConstants.priorityLow;
    return AppConstants.priorityMedium;
  }

  List<Map<String, String>> _importFromCsv(String filePath) {
    final lines = File(filePath)
        .readAsLinesSync()
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) return [];

    final header = _parseCsvLine(lines.first);
    final rows = <Map<String, String>>[];
    for (final line in lines.skip(1)) {
      final values = _parseCsvLine(line);
      if (values.isEmpty) continue;
      final map = <String, String>{};
      for (int i = 0; i < header.length; i++) {
        final key = header[i].trim();
        if (key.isEmpty) continue;
        map[key] = i < values.length ? values[i] : '';
      }
      rows.add(map);
    }

    return rows;
  }

  List<String> _parseCsvLine(String line) {
    final values = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i += 1;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }
      if (ch == ',' && !inQuotes) {
        values.add(buffer.toString());
        buffer.clear();
        continue;
      }
      buffer.write(ch);
    }

    values.add(buffer.toString());
    return values;
  }

  String _escapeCsv(Object? value) {
    final text = value?.toString() ?? '';
    if (text.contains(',') || text.contains('"') || text.contains('\n')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }
}
