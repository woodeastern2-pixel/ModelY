import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ai_voc_assistant/core/theme/app_theme.dart';
import 'package:ai_voc_assistant/domain/entities/knowledge_base_entity.dart';
import 'package:ai_voc_assistant/domain/repositories/knowledge_base_repository.dart';
import 'package:ai_voc_assistant/domain/repositories/settings_repository.dart';
import 'package:ai_voc_assistant/presentation/viewmodels/settings_viewmodel.dart';
import 'package:ai_voc_assistant/presentation/viewmodels/knowledge_base_viewmodel.dart';
import 'package:ai_voc_assistant/presentation/screens/knowledge_base/knowledge_base_screen.dart';
import 'support/ui_harness.dart';

KnowledgeBaseEntity entry(String id, String title, String category,
    String? product, String source) => KnowledgeBaseEntity(
  id: id, question: title, answer: '$title 안내 본문', category: category,
  project: product, customer: source, createdAt: DateTime(2026), resolvedAt: DateTime(2026));

void main() {
  setUpAll(loadUiHarnessFonts);
  for (final phone in [true, false]) {
    for (final dark in [false, true]) {
      testWidgets('single browsing scope and global reset ${phone ? "phone" : "desktop"} ${dark ? "dark" : "light"}', (tester) async {
        tester.view.physicalSize = phone ? const Size(412, 915) : const Size(1440, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final settings = SettingsViewModel(_Settings());
        final vm = KnowledgeBaseViewModel(_Repository([
          entry('drive', '드라이브 복원 방법', '시스템매뉴얼', 'Brity Drive', 'drive.docx'),
          entry('mail', '메일 알림 설정', '시스템매뉴얼', 'Brity Mail', 'mail.docx'),
          entry('case', '드라이브 접속 문의', '문의', 'Brity Drive', '고객사'),
          entry('other', '제품 미지정 업무 안내', '일반', null, '기타'),
        ]), settings);
        addTearDown(vm.dispose);addTearDown(settings.dispose);
        await tester.pump();
        await vm.ready;
        final key = GlobalKey();
        await tester.pumpWidget(ChangeNotifierProvider.value(value: vm,
          child: MaterialApp(theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
            home: RepaintBoundary(key: key, child: const KnowledgeBaseScreen()))));
        await tester.pumpAndSettle();
        Finder chip(String label) => find.widgetWithText(FilterChip, label);
        Future<void> choose(String label) async {
          await tester.ensureVisible(chip(label));
          await tester.tap(chip(label));
          await tester.pumpAndSettle();
        }
        void expectSelection(String label, Set<String> ids) {
          final selected = tester.widgetList<FilterChip>(find.byType(FilterChip))
              .where((chip) => chip.selected).toList();
          expect(selected, hasLength(1));
          expect((selected.single.label as Text).data, label);
          expect(vm.entries.map((e) => e.id).toSet(), ids);
        }
        expect(find.text('모든 제품'), findsNothing);
        expect(find.text('전체 문서'), findsNothing);
        expectSelection('전체', {'drive', 'mail', 'case', 'other'});
        await choose('Brity Drive');
        expectSelection('Brity Drive', {'drive', 'case'});
        expect(find.text('메일 알림 설정'), findsNothing);
        await choose('mail.docx (1)');
        expectSelection('mail.docx (1)', {'mail'});
        expect(vm.filterProduct, isEmpty);
        await choose('문의');
        expectSelection('문의', {'case'});
        expect(vm.manualFileFilter, isEmpty);
        await choose('Brity Mail');
        expectSelection('Brity Mail', {'mail'});
        expect(vm.filterCategory, isEmpty);
        await choose('전체');
        expectSelection('전체', {'drive', 'mail', 'case', 'other'});
        // Reset must cancel a pending input timer and clear its visible text.
        await tester.enterText(find.byType(TextField), '검색결과없음');
        await tester.pump(const Duration(milliseconds: 20));
        await choose('전체');
        await tester.pump(const Duration(milliseconds: 250));
        expect(vm.searchQuery, isEmpty);
        expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
        expectSelection('전체', {'drive', 'mail', 'case', 'other'});
        // Keyword search remains usable inside the selected scope.
        await tester.enterText(find.byType(TextField), '복원');
        await tester.pump(const Duration(milliseconds: 200));
        expect(vm.entries.map((e) => e.id), ['drive']);
        await choose('Brity Mail');
        expect(vm.entries, isEmpty);
        await choose('전체');
        expectSelection('전체', {'drive', 'mail', 'case', 'other'});
        await choose('Brity Mail');
        expectSelection('Brity Mail', {'mail'});
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image = await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('test/goldens/knowledge-filter-${phone ? "phone" : "desktop"}-${dark ? "dark" : "light"}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      });
    }
  }
}
class _Repository implements KnowledgeBaseRepository {
  final List<KnowledgeBaseEntity> values;
  _Repository(this.values);
  @override
  Future<List<KnowledgeBaseEntity>> getAllEntries() async => values;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
class _Settings implements SettingsRepository {
  @override
  Future<Map<String, String>> getAllSettings() async => {};
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
