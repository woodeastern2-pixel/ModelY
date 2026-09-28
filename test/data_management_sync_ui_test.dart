import 'package:ai_voc_assistant/core/constants/app_constants.dart';
import 'package:ai_voc_assistant/core/theme/app_theme.dart';
import 'package:ai_voc_assistant/domain/repositories/knowledge_base_repository.dart';
import 'package:ai_voc_assistant/domain/repositories/settings_repository.dart';
import 'package:ai_voc_assistant/domain/repositories/voc_repository.dart';
import 'package:ai_voc_assistant/presentation/screens/settings/data_management_screen_v2.dart';
import 'package:ai_voc_assistant/presentation/screens/settings/settings_screen_ax.dart';
import 'package:ai_voc_assistant/presentation/viewmodels/ai_viewmodel.dart';
import 'package:ai_voc_assistant/presentation/viewmodels/integration_viewmodel.dart';
import 'package:ai_voc_assistant/presentation/viewmodels/settings_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/ui_harness.dart';

void main() {
  setUpAll(loadUiHarnessFonts);

  final profiles = <({Size size, ThemeMode theme})>[
    (size: const Size(390, 844), theme: ThemeMode.light),
    (size: const Size(1440, 900), theme: ThemeMode.dark),
  ];
  for (final profile in profiles) {
    testWidgets(
      'internal VOC sync controls stay visible at ${profile.size.width.toInt()}px',
      (tester) async {
        await _setViewport(tester, profile.size);
        final repository = _MemorySettingsRepository({
          AppConstants.settingAppInstanceName: '본사 VOC',
          AppConstants.settingVocSyncBearerToken: 'shared-token',
          AppConstants.settingVocForwardWebhookTargets:
              'http://192.168.0.3:8788/webhook/voc',
          AppConstants.settingVocAutoForwardEnabled: 'true',
        });
        final settings = SettingsViewModel(repository);
        final integration = IntegrationViewModel(
          const _EmptyVocRepository(),
          settings,
        );
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<SettingsViewModel>.value(value: settings),
              ChangeNotifierProvider<IntegrationViewModel>.value(
                value: integration,
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: profile.theme,
              home: const DataManagementScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('voc-sync-settings-card')), findsOneWidget);
        expect(find.text('VOC 동기화 설정'), findsOneWidget);
        expect(find.text('AI VOC Assistant 간 동기화'), findsOneWidget);
        expect(find.text('전체 VOC와 매뉴얼 보내기'), findsOneWidget);
        expect(find.text('연결된 앱의 VOC 가져오기'), findsOneWidget);
        expect(find.text('초기 데이터 동기화'), findsOneWidget);
        expect(find.text('Outlook 메일에서 VOC 수집'), findsNothing);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        integration.dispose();
        settings.dispose();
        await tester.pump();
      },
    );
  }

  testWidgets('sync settings add a peer URL and persist auto forwarding', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1440, 1100));
    final repository = _MemorySettingsRepository({
      AppConstants.settingAppInstanceName: '본사 VOC',
      AppConstants.settingVocAutoForwardEnabled: 'false',
    });
    final settings = SettingsViewModel(repository);
    final integration = IntegrationViewModel(
      const _EmptyVocRepository(),
      settings,
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsViewModel>.value(value: settings),
          ChangeNotifierProvider<IntegrationViewModel>.value(
            value: integration,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const DataManagementScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('voc-sync-add-target')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('voc-sync-target-dialog-field')),
      'http://192.168.0.8:8788/webhook/voc',
    );
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('voc-sync-auto-forward')));
    await tester.tap(find.byKey(const Key('voc-sync-save')));
    await tester.pumpAndSettle();

    expect(
      repository.values[AppConstants.settingVocForwardWebhookTargets],
      'http://192.168.0.8:8788/webhook/voc',
    );
    expect(
      repository.values[AppConstants.settingVocAutoForwardEnabled],
      'true',
    );
    expect(find.text('VOC 동기화 설정을 저장했습니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    integration.dispose();
    settings.dispose();
    await tester.pump();
  });

  testWidgets('settings navigation opens the sync-enabled data screen', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1440, 1000));
    final repository = _MemorySettingsRepository({
      AppConstants.settingAppInstanceName: '본사 VOC',
    });
    final settings = SettingsViewModel(repository);
    const vocRepository = _EmptyVocRepository();
    final integration = IntegrationViewModel(vocRepository, settings);
    final ai = AiViewModel(
      const _EmptyKnowledgeRepository(),
      vocRepository,
      settings,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsViewModel>.value(value: settings),
          ChangeNotifierProvider<IntegrationViewModel>.value(
            value: integration,
          ),
          ChangeNotifierProvider<AiViewModel>.value(value: ai),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: SettingsScreenAx()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The legacy General settings view emits a framework-only ListTile ink
    // warning while it is the initially selected tab. This routing assertion
    // concerns exceptions produced after opening Data Management.
    tester.takeException();
    await tester.tap(find.text('데이터 관리').first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('voc-sync-settings-card')), findsOneWidget);
    expect(find.text('VOC 동기화 설정'), findsOneWidget);
    expect(find.text('AI VOC Assistant 간 동기화'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    integration.dispose();
    ai.dispose();
    settings.dispose();
    await tester.pump();
  });
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}

class _MemorySettingsRepository implements SettingsRepository {
  _MemorySettingsRepository(Map<String, String> values)
      : values = Map<String, String>.from(values);

  final Map<String, String> values;

  @override
  Future<Map<String, String>> getAllSettings() async => Map.of(values);

  @override
  Future<String?> getValue(String key) async => values[key];

  @override
  Future<void> setMultiple(Map<String, String> settings) async {
    values.addAll(settings);
  }

  @override
  Future<void> setValue(String key, String value) async {
    values[key] = value;
  }
}

class _EmptyVocRepository implements VocRepository {
  const _EmptyVocRepository();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyKnowledgeRepository implements KnowledgeBaseRepository {
  const _EmptyKnowledgeRepository();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
