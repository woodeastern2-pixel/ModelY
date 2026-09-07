// Demo Mode에서 실제 기능을 설명하는 3분 안내 흐름을 제공합니다.

/// 데모 단계
enum DemoPhase {
  idle, // 준비
  generating, // 샘플 데이터 생성
  analyzing, // AI 분석
  workflow, // 워크플로우 실행
  notifications, // Teams/Slack 알림
  dashboard, // 대시보드 업데이트
  completed, // 완료
}

/// 데모 진행 상태
class DemoStatus {
  final DemoPhase phase;
  final int progressPercent; // 0-100
  final String message;
  final List<String> logs; // 시연 로그
  final Duration elapsed;
  final Duration? totalDuration;

  DemoStatus({
    required this.phase,
    required this.progressPercent,
    required this.message,
    required this.logs,
    required this.elapsed,
    this.totalDuration,
  });

  double get percentComplete {
    if (totalDuration == null) return 0;
    return elapsed.inMilliseconds / totalDuration!.inMilliseconds;
  }
}

/// 데모 실행 콜백
typedef DemoProgressCallback = void Function(DemoStatus status);

/// Demo Mode 서비스
abstract class DemoModeService {
  /// 데모 시작
  Future<void> startDemo(DemoProgressCallback onProgress);

  /// 데모 중지
  Future<void> stopDemo();

  /// 진행 상태 조회
  DemoStatus? getCurrentStatus();

  /// 데모 중인지 확인
  bool isRunning();
}

/// 기본 Demo Mode 구현
class DefaultDemoModeService implements DemoModeService {
  DemoStatus? _currentStatus;
  bool _isRunning = false;
  final Duration _demoDuration = const Duration(minutes: 3);

  @override
  Future<void> startDemo(DemoProgressCallback onProgress) async {
    if (_isRunning) return;
    _isRunning = true;

    final startTime = DateTime.now();
    final logs = <String>[];

    // Phase 1: 샘플 데이터 생성
    await _runPhase(
      phase: DemoPhase.generating,
      duration: const Duration(seconds: 20),
      startTime: startTime,
      logs: logs,
      onProgress: onProgress,
      task: () async {
        logs.add('① 샘플 VOC 확인: 추가된 VOC를 목록에서 확인합니다.');
        logs.add('기존 VOC와 설정은 변경되지 않습니다.');
      },
    );

    if (!_isRunning) return;

    // Phase 2: AI 분석
    await _runPhase(
      phase: DemoPhase.analyzing,
      duration: const Duration(seconds: 30),
      startTime: startTime,
      logs: logs,
      onProgress: onProgress,
      task: () async {
        logs.add('② AI 분석 확인: VOC 유형, 긴급도와 유사 VOC 영역을 살펴봅니다.');
        logs.add('실제 AI 결과는 현재 AI 설정과 저장된 데이터에 따라 달라집니다.');
      },
    );

    if (!_isRunning) return;

    // Phase 3: 워크플로우 실행
    await _runPhase(
      phase: DemoPhase.workflow,
      duration: const Duration(seconds: 30),
      startTime: startTime,
      logs: logs,
      onProgress: onProgress,
      task: () async {
        logs.add('③ 답변 확인: VOC 상세에서 유사 사례와 AI 답변 초안을 살펴봅니다.');
        logs.add('④ 처리 완료: 답변 승인과 상태 변경은 VOC 상세 화면에서 직접 실행합니다.');
      },
    );

    if (!_isRunning) return;

    // Phase 4: 알림 발송
    await _runPhase(
      phase: DemoPhase.notifications,
      duration: const Duration(seconds: 20),
      startTime: startTime,
      logs: logs,
      onProgress: onProgress,
      task: () async {
        logs.add(
            '업무 도구 안내: Jira·Confluence·Teams·Slack은 연결된 경우에만 사용할 수 있습니다.');
        logs.add('기능 둘러보기 중에는 외부 시스템으로 데이터를 보내지 않습니다.');
      },
    );

    if (!_isRunning) return;

    // Phase 5: 대시보드 업데이트
    await _runPhase(
      phase: DemoPhase.dashboard,
      duration: const Duration(seconds: 20),
      startTime: startTime,
      logs: logs,
      onProgress: onProgress,
      task: () async {
        logs.add('⑤ 결과 확인: VOC 현황은 현재 저장된 데이터를 기준으로 계산됩니다.');
        logs.add('임의로 만든 성과 수치는 표시하지 않습니다.');
      },
    );

    if (!_isRunning) return;

    // Phase 6: 완료
    _currentStatus = DemoStatus(
      phase: DemoPhase.completed,
      progressPercent: 100,
      message: '기능 둘러보기를 마쳤습니다. 실제 결과는 각 업무 화면에서 확인하세요.',
      logs: logs,
      elapsed: DateTime.now().difference(startTime),
      totalDuration: _demoDuration,
    );

    onProgress(_currentStatus!);
    _isRunning = false;
  }

  Future<void> _runPhase({
    required DemoPhase phase,
    required Duration duration,
    required DateTime startTime,
    required List<String> logs,
    required DemoProgressCallback onProgress,
    required Future<void> Function() task,
  }) async {
    final phaseStart = DateTime.now();

    while (_isRunning && DateTime.now().difference(phaseStart) < duration) {
      _currentStatus = DemoStatus(
        phase: phase,
        progressPercent: ((DateTime.now().difference(startTime).inMilliseconds /
                    _demoDuration.inMilliseconds) *
                100)
            .toInt()
            .clamp(0, 99),
        message: _getPhaseMessage(phase),
        logs: List.from(logs),
        elapsed: DateTime.now().difference(startTime),
        totalDuration: _demoDuration,
      );

      onProgress(_currentStatus!);
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (_isRunning) {
      await task();
    }
  }

  String _getPhaseMessage(DemoPhase phase) {
    switch (phase) {
      case DemoPhase.generating:
        return '샘플 VOC를 추가하고 있습니다.';
      case DemoPhase.analyzing:
        return 'AI 분석 화면을 안내하고 있습니다.';
      case DemoPhase.workflow:
        return 'VOC 처리 과정을 안내하고 있습니다.';
      case DemoPhase.notifications:
        return '업무 도구 사용 방법을 안내하고 있습니다.';
      case DemoPhase.dashboard:
        return 'VOC 현황 화면을 안내하고 있습니다.';
      case DemoPhase.completed:
        return '기능 둘러보기 완료';
      default:
        return '기능 둘러보기를 준비하고 있습니다.';
    }
  }

  @override
  Future<void> stopDemo() async {
    _isRunning = false;
  }

  @override
  DemoStatus? getCurrentStatus() {
    return _currentStatus;
  }

  @override
  bool isRunning() {
    return _isRunning;
  }
}
