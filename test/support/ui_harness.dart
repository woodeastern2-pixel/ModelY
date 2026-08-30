import 'package:ai_voc_assistant/core/theme/app_theme.dart';
import 'package:ai_voc_assistant/domain/repositories/knowledge_base_repository.dart';
import 'package:ai_voc_assistant/domain/repositories/settings_repository.dart';
import 'package:ai_voc_assistant/domain/repositories/voc_repository.dart';
import 'package:ai_voc_assistant/domain/services/executive_dashboard_service.dart';
import 'package:ai_voc_assistant/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:ai_voc_assistant/presentation/screens/home/home_screen.dart';
import 'package:ai_voc_assistant/presentation/viewmodels/dashboard_viewmodel.dart';
import 'package:ai_voc_assistant/presentation/viewmodels/settings_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

Future<void> loadUiHarnessFonts() async {
  final loader = FontLoader('Pretendard')
    ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.otf'))
    ..addFont(rootBundle.load('assets/fonts/Pretendard-Bold.otf'));
  await loader.load();
}

class UiHarness {
  UiHarness({required this.viewModel, required this.widget});

  final HarnessDashboardViewModel viewModel;
  final Widget widget;
}

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
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HarnessKnowledgeRepository implements KnowledgeBaseRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
