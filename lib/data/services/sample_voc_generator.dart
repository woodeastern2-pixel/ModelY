import '../../domain/entities/voc_entity.dart';

class SampleVocGenerator {
  static List<VocEntity> generateSampleVocs() {
    final now = DateTime.now();
    return [
      _voc(
        id: 'demo-voc-001',
        title: '잘못 보낸 메일을 취소하고 싶습니다',
        content:
            '조금 전에 잘못된 수신인에게 메일을 보냈습니다. 상대방 받은 메일함에서도 삭제되도록 발신 취소하는 방법을 알려주세요.',
        category: '메일',
        priority: 'CRITICAL',
        status: 'OPEN',
        customer: '영업1팀 김서준',
        now: now,
        hoursAgo: 0,
      ),
      _voc(
        id: 'demo-voc-002',
        title: '50MB가 넘는 파일 첨부 문의',
        content:
            '약 800MB인 설계 자료를 메일로 보내야 합니다. 대용량 첨부로 보낼 수 있는지와 최대 용량을 확인해 주세요.',
        category: '메일',
        priority: 'HIGH',
        status: 'IN_PROGRESS',
        customer: '설계팀 박하린',
        now: now,
        hoursAgo: 2,
      ),
      _voc(
        id: 'demo-voc-003',
        title: '회의실을 찾아서 예약하는 방법',
        content: '내일 오후에 프로젝터가 있는 빈 회의실을 찾아 예약하려고 합니다. 어디에서 어떻게 예약하면 되나요?',
        category: '회의실',
        priority: 'MEDIUM',
        status: 'OPEN',
        customer: '상품기획팀 이지우',
        now: now,
        hoursAgo: 3,
      ),
      _voc(
        id: 'demo-voc-004',
        title: '회의실 일정 삭제 시 예약 취소 여부',
        content: '나의 캘린더에 등록된 회의실 일정을 삭제하면 회의실 예약도 함께 취소되는지 궁금합니다.',
        category: '회의실',
        priority: 'MEDIUM',
        status: 'RESOLVED',
        customer: '개발2팀 최도윤',
        now: now,
        hoursAgo: 25,
      ),
      _voc(
        id: 'demo-voc-005',
        title: '결재 문서를 새로 상신하고 싶습니다',
        content: 'Brity Mail에서 지출 결재 문서를 작성하고 결재 경로를 지정해 상신하는 기본 절차를 알려주세요.',
        category: '결재',
        priority: 'HIGH',
        status: 'OPEN',
        customer: '재무관리팀 정유진',
        now: now,
        hoursAgo: 1,
      ),
      _voc(
        id: 'demo-voc-006',
        title: 'Copilot 메일 요약 사용 문의',
        content: '내용이 긴 수신 메일을 Copilot으로 짧게 요약하고 싶습니다. 메뉴 위치와 사용 방법을 알려주세요.',
        category: 'Copilot',
        priority: 'MEDIUM',
        status: 'IN_PROGRESS',
        customer: '경영지원팀 윤가은',
        now: now,
        hoursAgo: 6,
      ),
      _voc(
        id: 'demo-voc-007',
        title: 'Copilot으로 답장 초안 작성',
        content: '받은 메일 내용을 바탕으로 정중한 답장 초안을 자동 작성하고 싶은데 어떻게 사용하나요?',
        category: 'Copilot',
        priority: 'LOW',
        status: 'OPEN',
        customer: '서비스운영팀 한지민',
        now: now,
        hoursAgo: 9,
      ),
      _voc(
        id: 'demo-voc-008',
        title: '외부 캘린더 구독 가능 여부',
        content: '외부에서 사용하는 캘린더 URL을 Brity Mail에 등록해서 일정만 함께 확인할 수 있나요?',
        category: '일정',
        priority: 'LOW',
        status: 'RESOLVED',
        customer: '인사팀 오수빈',
        now: now,
        hoursAgo: 32,
      ),
    ];
  }

  static VocEntity _voc({
    required String id,
    required String title,
    required String content,
    required String category,
    required String priority,
    required String status,
    required String customer,
    required DateTime now,
    required int hoursAgo,
  }) {
    final createdAt = now.subtract(Duration(hours: hoursAgo));
    return VocEntity(
      id: id,
      title: title,
      content: content,
      category: category,
      customer: customer,
      project: 'Brity Mail',
      priority: priority,
      status: status,
      isBusinessRelated: true,
      businessScore: 0.97,
      urgency: priority,
      source: 'demo',
      sourceRef: 'New Brity Mail 사용자매뉴얼',
      createdAt: createdAt,
      updatedAt: status == 'OPEN'
          ? createdAt
          : now.subtract(const Duration(hours: 1)),
    );
  }
}
