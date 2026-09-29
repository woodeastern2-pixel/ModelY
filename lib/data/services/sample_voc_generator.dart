import '../../domain/entities/voc_entity.dart';
import 'demo_voc_catalog.dart';

/// Reproducible synthetic requests, never operational performance evidence.
class SampleVocGenerator {
  static const perField = 100;
  static const totalCount = 1000;
  static const batchId = 'brity-demo-v2';
  static const periodLabel = '2026.02.01 ~ 2026.09.29';
  static final start = DateTime.utc(2026, 2, 1);
  // Snapshot requested at 2026-09-29 17:01 Korea time. Never generates future rows.
  static final snapshotEnd = DateTime.utc(2026, 9, 29, 8, 1);
  static List<String> get fields => demoFields.map((f) => f.name).toList();
  static const categories = [
    '사용법', '기능문의', '장애', '성능', '권한',
    '보안', '데이터', '모바일', '개선요청', '운영문의',
  ];
  static bool isSample(VocEntity voc) => voc.source == 'demo' &&
      (voc.id.startsWith('$batchId-') ||
       RegExp(r'^demo-voc-00[1-8]$').hasMatch(voc.id));

  static List<VocEntity> generateSampleVocs({DateTime? now}) {
    final clock = (now ?? DateTime.now()).toUtc();
    final end = clock.isBefore(snapshotEnd) ? clock : snapshotEnd;
    if (!end.isAfter(start)) return [];
    const weights = [8, 10, 12, 12, 13, 14, 15, 16];
    final result = <VocEntity>[];
    for (var fieldIndex = 0; fieldIndex < demoFields.length; fieldIndex++) {
      final field = demoFields[fieldIndex];
      for (var i = 0; i < perField; i++) {
        final topic = field.topics[i ~/ 10];
        final variant = i % 10;
        final persona = demoPersonas[(variant + i ~/ 10 + fieldIndex) % 10];
        final slot = (i * 37 + fieldIndex * 11) % 100;
        var remaining = slot;
        var monthIndex = 0;
        while (remaining >= weights[monthIndex]) {
          remaining -= weights[monthIndex++];
        }
        final monthStart = DateTime.utc(2026, monthIndex + 2);
        final naturalEnd = DateTime.utc(2026, monthIndex + 3);
        final monthEnd = naturalEnd.isAfter(end) ? end : naturalEnd;
        // For a clock before the requested snapshot, spread every row over the
        // elapsed period instead of producing future timestamps.
        DateTime created;
        if (!monthStart.isBefore(end)) {
          created = start.add(Duration(minutes:
              end.difference(start).inMinutes * (slot + 1) ~/ 101));
        } else {
          created = monthStart.add(Duration(minutes:
              monthEnd.difference(monthStart).inMinutes * (remaining + 1) ~/
              (weights[monthIndex] + 1)));
        }
        // Office hours in Korea, with occasional out-of-hours requests.
        final korean = created.add(const Duration(hours: 9));
        if (i % 9 != 0) {
          created = DateTime.utc(korean.year, korean.month, korean.day,
              9 + (i + fieldIndex) % 9, (i * 13) % 60)
              .subtract(const Duration(hours: 9));
        }
        if (created.isBefore(start)) created = start;
        if (created.isAfter(end)) created = end;
        final roll = (i * 17 + fieldIndex * 7) % 100;
        final recent = end.difference(created).inDays < 30;
        var status = roll < (recent ? 45 : 75) ? 'RESOLVED'
            : roll < 90 ? 'IN_PROGRESS' : 'OPEN';
        final minutes = 25 + ((i * 71 + fieldIndex * 19) % 2850);
        var updated = status == 'OPEN' ? created
            : created.add(Duration(minutes: minutes));
        if (updated.isAfter(end)) {
          status = 'OPEN';
          updated = created;
        }
        final priority = variant == 2 || (variant == 5 && i % 3 == 0)
            ? 'HIGH' : variant == 8 || variant == 0 ? 'LOW' : 'MEDIUM';
        final prompts = [
          '${topic.goal} 처음 사용하는 직원도 따라 할 수 있도록 메뉴 위치와 순서를 알려주세요.',
          '${topic.goal} 현재 사용하는 환경에서 지원되는지, 필요한 설정이나 제한 조건이 있는지 확인 부탁드립니다.',
          '${topic.goal} ${topic.symptom} 같은 작업을 다시 해도 동일합니다. 원인 확인에 필요한 정보와 우회 방법을 알려주세요.',
          '${topic.goal} 해당 작업 화면의 응답이 늦어 여러 번 누르게 됩니다. 다른 메뉴와 비교해 확인할 항목과 진단 방법이 궁금합니다.',
          '${topic.goal} 동료 계정과 제 계정에서 가능한 작업이 다릅니다. 필요한 사용자 역할과 관리자 확인 항목을 알려주세요.',
          '${topic.goal} 업무상 민감한 정보가 포함될 수 있습니다. 다른 부서나 외부 사용자에게 노출되는 범위와 점검 방법을 확인하고 싶습니다.',
          '${topic.goal} 작업 후 다시 확인했을 때 기대한 결과와 화면 내용이 다릅니다. 원래 기록을 훼손하지 않고 변경 여부를 확인할 방법이 있나요?',
          '${topic.goal} 컴퓨터와 휴대폰에서 메뉴 또는 동작이 달라 진행하지 못하고 있습니다. 모바일 지원 범위와 가능한 대체 절차를 알려주세요.',
          '${topic.goal} 현재 진행 상태와 다음에 해야 할 작업이 한눈에 보이면 좋겠습니다. 완료 표시와 안내 문구 개선을 요청합니다.',
          '${topic.goal} 부서 구성원에게 공통으로 안내하기 전에 회사 정책과 서비스 설정 중 어느 부분을 확인해야 하는지 알려주세요.',
        ];
        const suffixes = [
          '처음 이용하는 절차', '지원 조건 확인', '진행되지 않는 문제',
          '응답 지연', '사용자별 권한 차이', '정보 공개 범위',
          '작업 결과 확인', '휴대폰 이용 차이', '진행 안내 개선', '부서 운영 기준',
        ];
        final id = '$batchId-${(fieldIndex + 1).toString().padLeft(2, '0')}-'
            '${(i + 1).toString().padLeft(3, '0')}';
        result.add(VocEntity(
          id: id,
          title: '[시연] ${field.name} · ${topic.name} ${suffixes[variant]}',
          content: '${persona.department}에서 ${persona.role} 역할로 '
              '${field.project}를 이용하고 있습니다. ${persona.context}\n\n'
              '${prompts[variant]}\n\n[시연용 가상 문의 — 실제 고객 접수나 확인된 제품 장애가 아닙니다.]',
          category: categories[variant],
          tags: '시연,${field.name},${topic.name},${persona.role}',
          customer: '시연 ${persona.department} ${persona.role}',
          project: field.project,
          businessType: const ['이메일', '사용자 직접 등록', '회의', '메신저'][i % 4],
          department: '${field.name} 지원',
          assignee: status == 'OPEN' ? null : '시연 담당자 ${(fieldIndex % 5) + 1}',
          priority: priority,
          status: status,
          isBusinessRelated: true,
          urgency: priority,
          source: 'demo',
          sourceRef: '$batchId/$id',
          processingMinutes: status == 'RESOLVED'
              ? updated.difference(created).inMinutes : null,
          analysisReason: '시연용 합성 자료. 실제 분석 결과·운영 실적이 아닙니다.',
          createdAt: created,
          updatedAt: updated,
        ));
      }
    }
    return result;
  }
}
