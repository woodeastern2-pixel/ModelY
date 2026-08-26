import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/voc_category_catalog.dart';
import '../../../domain/entities/voc_entity.dart';
import '../../viewmodels/ai_viewmodel.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../viewmodels/integration_viewmodel.dart';
import '../../viewmodels/settings_viewmodel.dart';
import '../../viewmodels/voc_viewmodel.dart';
import 'voc_detail_screen.dart';

class VocRegisterScreen extends StatefulWidget {
  const VocRegisterScreen({super.key});

  @override
  State<VocRegisterScreen> createState() => _VocRegisterScreenState();
}

class _VocRegisterScreenState extends State<VocRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _customerController = TextEditingController();
  final _vocNumberController = TextEditingController();

  String _selectedProjectCode = '';
  String _selectedBusinessType = '';
  String _selectedProjectName = '';
  bool _selectionsInitialized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _customerController.dispose();
    _vocNumberController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectionsInitialized) return;

    final settingsVm = context.read<SettingsViewModel>();
    final codes = settingsVm.projectCodes;
    _selectedProjectCode = codes.isEmpty ? '' : codes.first;

    final types = settingsVm.businessTypeOptions;
    _selectedBusinessType = types.isEmpty ? '' : types.first;

    final names = settingsVm.projectNameOptions;
    _selectedProjectName = names.isEmpty ? '' : names.first;
    _selectionsInitialized = true;
  }

  String _buildProjectFieldValue() {
    final projectName = _selectedProjectName.trim();
    final code = _selectedProjectCode.trim().toUpperCase();
    final vocNumber = _vocNumberController.text.trim().toUpperCase();
    final parts = <String>[];
    if (projectName.isNotEmpty) parts.add(projectName);
    if (code.isNotEmpty) parts.add(code);
    if (vocNumber.isNotEmpty) parts.add(vocNumber);
    return parts.join(' | ');
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final vocVm = context.read<VocViewModel>();
    final aiVm = context.read<AiViewModel>();
    final integrationVm = context.read<IntegrationViewModel>();
    final dashboardVm = context.read<DashboardViewModel>();
    final settingsVm = context.read<SettingsViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    late final VocEntity voc;

    try {
      final autoCategory = VocCategoryCatalog.normalize(
        VocCategoryCatalog.fallbackCategory,
        title: title,
        content: content,
      );
      final autoPriority = _priorityFromUrgency(null);
      final autoTags = _buildAutoTags(
        category: autoCategory,
        businessType: _selectedBusinessType,
      );
      voc = await vocVm.createVoc(
        title: title,
        content: content,
        category: autoCategory,
        tags: autoTags,
        customer: _customerController.text.trim(),
        project: _buildProjectFieldValue(),
        businessType: _selectedBusinessType.trim(),
        priority: autoPriority,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('등록 오류: $e'), backgroundColor: Colors.red),
      );
      return;
    }

    if (!mounted) return;
    unawaited(dashboardVm.loadDashboard());
    messenger.showSnackBar(const SnackBar(
      content: Text('VOC가 등록되었습니다. AI 분석은 백그라운드에서 진행합니다.'),
    ));

    unawaited(
      integrationVm
          .forwardVocToPeerApps(voc)
          .timeout(const Duration(seconds: 8))
          .then((message) {
        if (!mounted || message == null) return;
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }).catchError((_) {}),
    );

    unawaited(_runPostRegistrationAi(
      vocVm: vocVm,
      aiVm: aiVm,
      vocId: voc.id,
      title: voc.title,
      content: voc.content,
      autoAnswer: settingsVm.aiAutoAnswerOnVocRegister,
    ));

    setState(() => _isSaving = false);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => VocDetailScreen(vocId: voc.id)),
    );
  }

  Future<void> _runPostRegistrationAi({
    required VocViewModel vocVm,
    required AiViewModel aiVm,
    required String vocId,
    required String title,
    required String content,
    required bool autoAnswer,
  }) async {
    try {
      final intelligence = await aiVm.analyzeVocIntelligence(title, content);
      if (intelligence == null) return;
      await vocVm.updateVocWithAiAnalysis(
        vocId,
        isBusinessRelated: intelligence.isBusiness,
        aiCategory: intelligence.category,
        businessScore: intelligence.businessScore,
        categoryScore: intelligence.categoryScore,
        urgency: intelligence.urgency,
        urgencyScore: intelligence.urgencyScore,
        department: intelligence.department,
        departmentScore: intelligence.departmentScore,
        assignee: intelligence.assignee,
        assigneeScore: intelligence.assigneeScore,
        duplicateOfVocId: intelligence.duplicateOfVocId,
        duplicateScore: intelligence.duplicateScore,
        jiraRequired: intelligence.jiraRequired,
        jiraScore: intelligence.jiraScore,
        analysisReason: intelligence.reason,
      );
      if (!autoAnswer || !intelligence.isBusiness) return;
      await aiVm.searchSimilarVocs('$title $content');
      final answer = await aiVm.generateAnswer(title, content);
      if (answer == null || answer.answer.trim().isEmpty) return;
      await vocVm.createDraftResponse(
        vocId: vocId,
        content: answer.answer,
        aiGenerated: true,
        confidence: answer.confidence,
        referencedVocIds: aiVm.similarVocs
            .map((item) => item.knowledgeBase.vocId)
            .whereType<String>()
            .toList(),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsViewModel>();
    final projectCodes = settings.projectCodes;
    final businessTypes = settings.businessTypeOptions;
    final projectNames = settings.projectNameOptions;
    final businessTypeValue = businessTypes.contains(_selectedBusinessType)
        ? _selectedBusinessType
        : (businessTypes.isEmpty ? '' : businessTypes.first);
    final projectNameValue = projectNames.contains(_selectedProjectName)
        ? _selectedProjectName
        : (projectNames.isEmpty ? '' : projectNames.first);

    return Scaffold(
      appBar: AppBar(title: const Text('VOC 등록')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 900;
          final horizontal = desktop ? 32.0 : 16.0;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _RegisterIntro(desktop: desktop),
                      const SizedBox(height: 18),
                      _SectionCard(
                        title: '기본 정보',
                        subtitle: 'VOC가 어디에서 발생했는지 식별하기 위한 정보입니다. 선택 항목은 비워둘 수 있습니다.',
                        child: _ResponsiveGrid(
                          minItemWidth: 360,
                          children: [
                            _buildTextField(
                              controller: _customerController,
                              label: '고객명 (선택)',
                              icon: Icons.person_outline,
                              required: false,
                            ),
                            _selectField(
                              label: '업무 구분 (선택)',
                              icon: Icons.work_outline,
                              value: businessTypeValue,
                              items: businessTypes,
                              onChanged: (v) => setState(() => _selectedBusinessType = v),
                            ),
                            _selectField(
                              label: '프로젝트명 (선택)',
                              icon: Icons.folder_outlined,
                              value: projectNameValue,
                              items: projectNames,
                              onChanged: (v) => setState(() => _selectedProjectName = v),
                            ),
                            _selectField(
                              label: '프로젝트 코드 (선택)',
                              icon: Icons.qr_code_2_outlined,
                              value: projectCodes.contains(_selectedProjectCode)
                                  ? _selectedProjectCode
                                  : '',
                              items: projectCodes,
                              onChanged: (v) => setState(() => _selectedProjectCode = v),
                            ),
                            _buildTextField(
                              controller: _vocNumberController,
                              label: 'VOC 번호 (선택)',
                              hint: '예: 12345',
                              icon: Icons.confirmation_number_outlined,
                              required: false,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'VOC 내용',
                        subtitle: '제목과 내용을 입력하면 등록 직후 AI가 분류·긴급도·담당 정보를 백그라운드에서 분석합니다.',
                        child: Column(
                          children: [
                            _buildTextField(
                              controller: _titleController,
                              label: 'VOC 제목 *',
                              icon: Icons.title,
                              minLength: 4,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _contentController,
                              minLines: desktop ? 8 : 6,
                              maxLines: desktop ? 12 : 10,
                              decoration: const InputDecoration(
                                labelText: 'VOC 내용 *',
                                hintText: '고객 문의나 이슈 내용을 구체적으로 입력해 주세요.',
                                alignLabelWithHint: true,
                                prefixIcon: Padding(
                                  padding: EdgeInsets.only(bottom: 120),
                                  child: Icon(Icons.description_outlined),
                                ),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'VOC 내용을 입력해 주세요'
                                  : v.trim().length < 10
                                      ? 'VOC 내용은 최소 10자 이상 입력해 주세요'
                                      : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      _SubmitBar(
                        saving: _isSaving,
                        desktop: desktop,
                        onSubmit: _submit,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _selectField({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      items: [
        const DropdownMenuItem(value: '', child: Text('선택 안함')),
        ...items.map((item) => DropdownMenuItem(value: item, child: Text(item))),
      ],
      onChanged: (v) => onChanged(v ?? ''),
    );
  }

  String _priorityFromUrgency(String? urgency) {
    final normalized = urgency?.trim().toLowerCase() ?? '';
    if (normalized.contains('high') ||
        normalized.contains('critical') ||
        normalized.contains('긴급')) {
      return AppConstants.priorityHigh;
    }
    if (normalized.contains('low') || normalized.contains('낮')) {
      return AppConstants.priorityLow;
    }
    return AppConstants.priorityMedium;
  }

  String _buildAutoTags({
    required String category,
    String? urgency,
    String? department,
    String? businessType,
  }) {
    final values = <String>{
      category.trim(),
      if (urgency?.trim().isNotEmpty == true) urgency!.trim(),
      if (department?.trim().isNotEmpty == true) department!.trim(),
      if (businessType?.trim().isNotEmpty == true) businessType!.trim(),
    };
    return values.join(', ');
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = true,
    int? minLength,
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
      validator: (v) {
        final text = v?.trim() ?? '';
        if (!required && text.isEmpty) return null;
        if (required && text.isEmpty) return '$label을 입력해 주세요';
        if (minLength != null && text.length < minLength) {
          return '$label은 최소 $minLength자 이상 입력해 주세요';
        }
        return null;
      },
    );
  }
}

class _RegisterIntro extends StatelessWidget {
  const _RegisterIntro({required this.desktop});
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(desktop ? 22 : 18),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: .22),
        border: Border.all(color: cs.primary.withValues(alpha: .12)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.add_comment_outlined, color: cs.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('새 VOC 등록',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  '필수 내용만 입력하면 바로 등록됩니다. AI 분석과 답변 초안은 저장 후 백그라운드에서 처리됩니다.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({required this.children, required this.minItemWidth});
  final List<Widget> children;
  final double minItemWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final twoColumns = constraints.maxWidth >= minItemWidth * 2 + 14;
      final width = twoColumns ? (constraints.maxWidth - 14) / 2 : constraints.maxWidth;
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children: children.map((child) => SizedBox(width: width, child: child)).toList(),
      );
    });
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.saving,
    required this.desktop,
    required this.onSubmit,
  });
  final bool saving;
  final bool desktop;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton.icon(
      onPressed: saving ? null : onSubmit,
      icon: saving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.save_outlined),
      label: Text(saving ? '저장 중...' : 'VOC 등록'),
    );
    if (!desktop) return SizedBox(height: 52, child: button);
    return Row(
      children: [
        Expanded(
          child: Text(
            '등록 후 상세 화면으로 이동하며 AI 분석은 별도로 진행됩니다.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(width: 20),
        SizedBox(width: 180, height: 48, child: button),
      ],
    );
  }
}
