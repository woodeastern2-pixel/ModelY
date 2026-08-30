import 'package:ai_voc_assistant/core/theme/app_theme.dart';
import 'package:ai_voc_assistant/core/constants/app_constants.dart';
import 'package:ai_voc_assistant/domain/entities/voc_entity.dart';
import 'package:ai_voc_assistant/domain/repositories/knowledge_base_repository.dart';
import 'package:ai_voc_assistant/domain/repositories/settings_repository.dart';
import 'package:ai_voc_assistant/domain/repositories/voc_repository.dart';
import 'package:ai_voc_assistant/domain/services/executive_dashboard_service.dart';
import 'package:ai_voc_assistant/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:ai_voc_assistant/presentation/screens/chat/ai_chat_screen.dart';
import 'package:ai_voc_assistant/presentation/screens/home/home_screen.dart';
import 'package:ai_voc_assistant/presentation/screens/voc/voc_list_screen.dart';
import 'package:ai_voc_assistant/presentation/viewmodels/ai_viewmodel.dart';
import 'package:ai_voc_assistant/presentation/viewmodels/dashboard_viewmodel.dart';
import 'package:ai_voc_assistant/presentation/viewmodels/settings_viewmodel.dart';
import 'package:ai_voc_assistant/presentation/viewmodels/voc_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

Future<void> loadUiHarnessFonts() async {
  final productFontLoader = FontLoader('Pretendard')
    ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.otf'))
    ..addFont(rootBundle.load('assets/fonts/Pretendard-Bold.otf'));
  final materialIconsLoader = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await Future.wait([
    productFontLoader.load(),
    materialIconsLoader.load(),
  ]);
}

class UiHarness {
  UiHarness({required this.viewModel, required this.widget});

  final HarnessDashboardViewModel viewModel;
  final Widget widget;
}

enum WorkspaceHarnessView { vocQueue, copilot }

class WorkspaceHarness {
  WorkspaceHarness({
    required this.vocViewModel,
    required this.settingsViewModel,
    required this.widget,
  });

  final VocViewModel vocViewModel;
  final SettingsViewModel settingsViewModel;
  final Widget widget;

  void dispose() {
    vocViewModel.dispose();
    settingsViewModel.dispose();
  }
}

WorkspaceHarness createWorkspaceHarness({
  required WorkspaceHarnessView view,
  ThemeMode themeMode = ThemeMode.light,
  double textScale = 1,
}) {
  final vocViewModel = VocViewModel(
    _HarnessVocRepository(_workspaceVocs),
  );
  final settingsViewModel = SettingsViewModel(_HarnessSettingsRepository());
  final screen = switch (view) {
    WorkspaceHarnessView.vocQueue => const VocListScreen(),
    WorkspaceHarnessView.copilot => AiChatScreen(
        previewSessions: _copilotSessions,
      ),
  };

  final app = MultiProvider(
    providers: [
      ChangeNotifierProvider<VocViewModel>.value(value: vocViewModel),
      ChangeNotifierProvider<SettingsViewModel>.value(
        value: settingsViewModel,
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(textScale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: RepaintBoundary(
        key: const Key('workspace-preview-root'),
        child: screen,
      ),
    ),
  );

  return WorkspaceHarness(
    vocViewModel: vocViewModel,
    settingsViewModel: settingsViewModel,
    widget: app,
  );
}

final _workspaceVocs = <VocEntity>[
  VocEntity(
    id: 'voc-1042',
    title: '로그인 후 대시보드 로딩이 지연됩니다',
    content: '오늘 오전부터 로그인 완료 후 대시보드가 뜨기까지 20초 이상 걸립니다.',
    category: '장애',
    customer: '에이프릴 커머스',
    project: 'Commerce Cloud | CC | 1042',
    priority: AppConstants.priorityHigh,
    status: AppConstants.vocStatusOpen,
    businessType: '기술 지원',
    department: '플랫폼팀',
    assignee: '김민준',
    createdAt: DateTime(2026, 8, 30, 9, 10),
    updatedAt: DateTime(2026, 8, 30, 9, 32),
  ),
  VocEntity(
    id: 'voc-1041',
    title: '엔터프라이즈 SSO 계정 권한 변경 문의',
    content: '신규 조직 관리자의 SSO 권한 변경 절차와 적용 시점을 확인해 주세요.',
    category: '계정·권한',
    customer: '노스스타 금융',
    project: 'Enterprise Hub | EH | 1041',
    priority: AppConstants.priorityMedium,
    status: AppConstants.vocStatusInProgress,
    businessType: '운영 문의',
    department: '보안팀',
    assignee: '이서연',
    createdAt: DateTime(2026, 8, 29, 16, 20),
    updatedAt: DateTime(2026, 8, 30, 8, 45),
  ),
  VocEntity(
    id: 'voc-1039',
    title: '월별 청구서에 부가세 표기가 누락됩니다',
    content: '법인 월별 청구서 PDF에서 부가세 항목이 보이지 않아 회계 처리가 어렵습니다.',
    category: '결제',
    customer: '파인랩',
    project: 'Billing | BL | 1039',
    priority: AppConstants.priorityHigh,
    status: AppConstants.vocStatusResolved,
    businessType: '결제 문의',
    assignee: '박지훈',
    createdAt: DateTime(2026, 8, 28, 11, 4),
    updatedAt: DateTime(2026, 8, 29, 18, 14),
  ),
  VocEntity(
    id: 'voc-1037',
    title: '데이터 내보내기 필터 조건 저장 요청',
    content: '매번 반복하는 CSV 내보내기 필터를 작업자별로 저장할 수 있으면 좋겠습니다.',
    category: '기능 문의',
    customer: '모노 리테일',
    project: 'Analytics | AN | 1037',
    priority: AppConstants.priorityLow,
    status: AppConstants.vocStatusOpen,
    businessType: '기능 개선',
    createdAt: DateTime(2026, 8, 27, 14, 2),
    updatedAt: DateTime(2026, 8, 28, 9, 16),
  ),
  VocEntity(
    id: 'voc-1035',
    title: '초보 관리자용 권한 설정 가이드가 필요합니다',
    content: '처음 배포하는 관리자가 따라 할 수 있는 권한 설정 안내를 찾고 있습니다.',
    category: '사용 방법',
    customer: '하루 모빌리티',
    project: 'Admin | AD | 1035',
    priority: AppConstants.priorityMedium,
    status: AppConstants.vocStatusResolved,
    businessType: '사용 문의',
    createdAt: DateTime(2026, 8, 26, 10, 28),
    updatedAt: DateTime(2026, 8, 27, 12, 40),
  ),
];

final _copilotSessions = <AiChatSessionSummary>[
  AiChatSessionSummary(
    sessionId: 'session-1',
    title: '로그인 지연 VOC 원인과 우선순위',
    preview: '오전 접수 건 중 엔터프라이즈 고객 영향을 우선 분석했습니다.',
    messageCount: 8,
    updatedAt: DateTime(2026, 8, 30, 10, 5),
  ),
  AiChatSessionSummary(
    sessionId: 'session-2',
    title: '주간 고객 이슈 경영진 보고',
    preview: '핵심 이슈, 고객 영향, 권고 조치 순으로 요약했습니다.',
    messageCount: 5,
    updatedAt: DateTime(2026, 8, 29, 17, 42),
  ),
  AiChatSessionSummary(
    sessionId: 'session-3',
    title: '반복 결제 문의 패턴 분석',
    preview: '청구서 표기와 관련된 반복 패턴 3개를 확인했습니다.',
    messageCount: 11,
    updatedAt: DateTime(2026, 8, 28, 13, 18),
  ),
];

UiHarness createUiHarness({
  ThemeMode themeMode = ThemeMode.light,
  double textScale = 1,
  bool includeShell = true,
}) {
  final viewModel = HarnessDashboardViewModel();
  final screens = <Widget>[
    const DashboardScreen(),
    for (var index = 1; index < 6; index++) _HarnessPage(index: index),
  ];

  final app = ChangeNotifierProvider<DashboardViewModel>.value(
    value: viewModel,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(textScale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: RepaintBoundary(
        key: const Key('ui-preview-root'),
        child: includeShell
            ? HomeScreen(screenOverrides: screens)
            : const DashboardScreen(),
      ),
    ),
  );

  return UiHarness(viewModel: viewModel, widget: app);
}

class HarnessDashboardViewModel extends DashboardViewModel {
  HarnessDashboardViewModel()
      : super(
          _HarnessVocRepository(),
          _HarnessKnowledgeRepository(),
          SettingsViewModel(_HarnessSettingsRepository()),
        );

  @override
  Future<void> loadDashboard() async {}

  @override
  Map<String, int> get vocByStatus => const {
        'OPEN': 20,
        'IN_PROGRESS': 10,
        'RESOLVED': 98,
      };

  @override
  Map<String, int> get vocByCategory => const {
        '기능 문의': 38,
        '계정·권한': 27,
        '결제': 24,
        '장애': 21,
        '사용 방법': 18,
      };

  @override
  List<Map<String, dynamic>> get monthlyStats => const [
        {'month': '2026-03', 'total': 84, 'resolved': 62},
        {'month': '2026-04', 'total': 91, 'resolved': 69},
        {'month': '2026-05', 'total': 103, 'resolved': 78},
        {'month': '2026-06', 'total': 96, 'resolved': 80},
        {'month': '2026-07', 'total': 118, 'resolved': 91},
        {'month': '2026-08', 'total': 128, 'resolved': 98},
      ];

  @override
  int get totalVocs => 128;

  @override
  int get resolvedVocs => 98;

  @override
  int get kbCount => 412;

  @override
  double get duplicateReductionRate => 0.31;

  @override
  double get aiUsageRate => 0.72;

  @override
  double get avgProcessMinutes => 146;

  @override
  List<Map<String, dynamic>> get assigneeStats => const [
        {'assignee': '김민준', 'handled': 34},
        {'assignee': '이서연', 'handled': 29},
        {'assignee': '박지훈', 'handled': 24},
        {'assignee': '최유진', 'handled': 20},
      ];

  @override
  double get reopenRate => 0.047;

  @override
  int get reopenedCount => 5;

  @override
  int get resolvedForReopenRate => 98;

  @override
  String get risingKeyword => '로그인 지연';

  @override
  int get risingKeywordDelta => 11;

  @override
  String get topSegmentName => '엔터프라이즈';

  @override
  double get topSegmentScore => 7.8;

  @override
  int get topSegmentVolume => 19;

  @override
  RoiResult get roiResult => RoiResult(
        monthlySavingsHours: 219,
        monthlySavingsCost: 7665,
        monthlyNetSavingsCost: 5165,
        yearlySavingsCost: 61980,
        implementationPaybackMonths: 9.7,
        productivityGainPercent: 72,
        roi: 77.5,
        aiEffectiveness: 84.4,
        recommendation: 'AI 적용 범위를 확대하세요.',
      );

  @override
  double get aiOverallAccuracy => 0.914;

  @override
  double get aiAnswerAdoptionRate => 0.768;

  @override
  List<String> get accuracyRecommendations => const [];

  @override
  List<String> get executiveAiRecommendations => const [
        '로그인 지연 문의를 우선 FAQ로 승격하세요.',
        '미처리 VOC 20건의 담당자 배분을 오늘 안에 완료하세요.',
        '답변 채택률이 높은 템플릿을 계정·권한 카테고리에 확장하세요.',
      ];

  @override
  DateTime get executiveAiUpdatedAt => DateTime(2026, 8, 30, 9, 30);

  @override
  RoiCalculatorInput get roiInputSnapshot => RoiCalculatorInput(
        monthlyVocVolume: 128,
        avgHandleTimeHours: 2.43,
        hourlyLaborCost: 35,
        aiImplementationCost: 50000,
        monthlyAiMaintenanceCost: 2500,
        automationRate: 0.72,
        aiAccuracyRate: 0.914,
      );

  @override
  bool get isLoading => false;

  @override
  String? get error => null;

  @override
  double get resolutionRate => resolvedVocs / totalVocs;

  @override
  int get openVocs => 20;

  @override
  int get inProgressVocs => 10;

  @override
  int get backlogVocs => openVocs + inProgressVocs;

  @override
  double get backlogRate => backlogVocs / totalVocs;

  @override
  double get monthlyVocTrendPercent => 0.085;
}

class _HarnessPage extends StatelessWidget {
  const _HarnessPage({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('테스트 화면 $index')),
      body: Center(child: Text('화면 $index', key: Key('harness-page-$index'))),
    );
  }
}

class _HarnessSettingsRepository implements SettingsRepository {
  @override
  Future<Map<String, String>> getAllSettings() async => const {};

  @override
  Future<String?> getValue(String key) async => null;

  @override
  Future<void> setMultiple(Map<String, String> settings) async {}

  @override
  Future<void> setValue(String key, String value) async {}
}

class _HarnessVocRepository implements VocRepository {
  const _HarnessVocRepository([this.vocs = const []]);

  final List<VocEntity> vocs;

  @override
  Future<List<VocEntity>> getAllVocs() async => List.of(vocs);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HarnessKnowledgeRepository implements KnowledgeBaseRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
