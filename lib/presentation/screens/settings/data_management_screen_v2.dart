import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/services/peer_sync_service.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../viewmodels/integration_viewmodel.dart';
import '../../viewmodels/knowledge_base_viewmodel.dart';
import '../../viewmodels/settings_viewmodel.dart';
import '../../viewmodels/voc_viewmodel.dart';

class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  bool _peerSyncRunning = false;

  Future<void> _refresh() async {
    final vocs = context.read<VocViewModel>();
    final knowledge = context.read<KnowledgeBaseViewModel>();
    final dashboard = context.read<DashboardViewModel>();
    await vocs.loadVocs();
    await knowledge.loadEntries();
    await dashboard.loadDashboard();
  }

  void _show(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? Colors.red : null),
    );
  }

  void _integrationMessage() {
    if (!mounted) return;
    final vm = context.read<IntegrationViewModel>();
    final text = vm.error ?? vm.success ?? vm.bootstrapStatus;
    if (text != null) _show(text, error: vm.error != null);
  }

  Future<void> _run(
    Future<void> Function(IntegrationViewModel vm) action, {
    bool refresh = false,
  }) async {
    final vm = context.read<IntegrationViewModel>()..clearMessages();
    await action(vm);
    if (refresh && mounted) await _refresh();
    _integrationMessage();
  }

  Future<void> _pullPeerVocs() async {
    if (_peerSyncRunning) return;
    setState(() => _peerSyncRunning = true);
    try {
      final result = await PeerSyncService(context.read<SettingsViewModel>())
          .pullAllVocs();
      if (!mounted) return;
      await _refresh();
      _show(
        '연결된 앱에서 VOC를 가져왔습니다. 전체 ${result.remoteTotal}개 · '
        '새 VOC ${result.created}개 · 업데이트 ${result.updated}개 · '
        '반영 ${result.applied}개 · 성공 ${result.successApps}곳'
        '${result.failedApps > 0 ? ' · 실패 ${result.failedApps}곳' : ''}',
        error: result.failedApps > 0,
      );
    } catch (e) {
      _show('연결된 앱에서 VOC를 가져오지 못했습니다: $e', error: true);
    } finally {
      if (mounted) setState(() => _peerSyncRunning = false);
    }
  }

  Future<void> _bootstrapPeerData() async {
    if (_peerSyncRunning) return;
    setState(() => _peerSyncRunning = true);
    try {
      final result =
          await PeerSyncService(context.read<SettingsViewModel>()).bootstrap();
      if (!mounted) return;
      await _refresh();
      _show(
        '초기 데이터 동기화를 완료했습니다.\n'
        'VOC: 전체 ${result.vocRemoteTotal}개 · 새 VOC ${result.vocCreated}개 · 업데이트 ${result.vocUpdated}개\n'
        '지식 자료: 전체 ${result.manualRemoteTotal}개 · 새 자료 ${result.manualCreated}개 · 제외 ${result.manualSkipped}개\n'
        '앱: 성공 ${result.successApps}곳${result.failedApps > 0 ? ' · 실패 ${result.failedApps}곳' : ''}',
        error: result.failedApps > 0,
      );
    } catch (e) {
      _show('초기 데이터 동기화에 실패했습니다: $e', error: true);
    } finally {
      if (mounted) setState(() => _peerSyncRunning = false);
    }
  }

  Future<void> _importVoc() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty || !mounted) return;
    final file = picked.files.single;
    String? path = file.path;
    if (path == null && file.bytes != null) {
      final dir = await getTemporaryDirectory();
      path = p.join(dir.path, file.name);
      await File(path).writeAsBytes(file.bytes!);
    }
    if (path == null || !mounted) return;
    final strategy = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('중복 VOC 처리'),
        content: const Text('같은 제목과 내용의 VOC가 이미 있을 때 처리 방식을 선택하세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'append'),
            child: const Text('추가'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'overwrite'),
            child: const Text('덮어쓰기'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'skip'),
            child: const Text('건너뛰기'),
          ),
        ],
      ),
    );
    if (strategy == null || !mounted) return;
    final vm = context.read<IntegrationViewModel>()..clearMessages();
    final count = await vm.importVocFromFile(path, duplicateStrategy: strategy);
    if (count > 0 && mounted) await _refresh();
    _integrationMessage();
  }

  Future<String?> _xlsxPath(String name) async {
    if (Platform.isAndroid || Platform.isIOS) {
      final dir = await getApplicationDocumentsDirectory();
      return p.join(dir.path, name);
    }
    return FilePicker.platform.saveFile(
      dialogTitle: '저장 위치 선택',
      fileName: name,
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
    );
  }

  Future<void> _export(bool template) async {
    final date = DateFormat('yyyyMMdd').format(DateTime.now());
    final name =
        template ? 'VOC_Import_Template_$date.xlsx' : 'VOC_Backup_$date.xlsx';
    final path = await _xlsxPath(name);
    if (path == null || !mounted) return;
    await _run((vm) async {
      if (template) {
        await vm.exportVocTemplate(path);
      } else {
        await vm.exportVocToExcel(path);
      }
    });
  }

  Future<bool> _confirm(
    String title,
    String body, {
    bool danger = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              FilledButton(
                style: danger
                    ? FilledButton.styleFrom(backgroundColor: Colors.red)
                    : null,
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(danger ? '초기화' : '실행'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<IntegrationViewModel>();
    final busy = vm.isLoading || _peerSyncRunning;
    final content = LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 920;
        final pad = constraints.maxWidth >= 900 ? 28.0 : 16.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(pad, 20, pad, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(
                    active: vm.inAppReceiverRunning,
                    error: vm.inAppReceiverLastError,
                  ),
                  if (busy) ...[
                    const SizedBox(height: 14),
                    const LinearProgressIndicator(),
                  ],
                  const SizedBox(height: 16),
                  const _VocSyncSettingsCard(),
                  const SizedBox(height: 16),
                  _Grid(
                    wide: wide,
                    children: [
                      _Group(
                          'AI VOC Assistant 간 동기화', Icons.sync_alt_outlined, [
                        _Cmd(
                          '전체 VOC와 매뉴얼 보내기',
                          Icons.cloud_upload_outlined,
                          busy
                              ? null
                              : () => _run(
                                    (v) =>
                                        v.forwardFullVocAndManualToPeerApps(),
                                  ),
                        ),
                        _Cmd(
                          '연결된 앱의 VOC 가져오기',
                          Icons.cloud_download_outlined,
                          busy ? null : _pullPeerVocs,
                        ),
                        _Cmd(
                          '초기 데이터 동기화',
                          Icons.handshake_outlined,
                          busy ? null : _bootstrapPeerData,
                        ),
                        _Cmd(
                          '실패한 동기화 다시 시도 (${vm.syncRetryQueueCount})',
                          Icons.refresh_outlined,
                          busy || vm.syncRetryQueueCount == 0
                              ? null
                              : () => _run((v) => v.retryPendingSyncQueue()),
                        ),
                      ]),
                      _Group('가져오기·내보내기', Icons.folder_copy_outlined, [
                        if (AppConstants.showCollaborationTools)
                          _Cmd(
                            'Outlook 메일에서 VOC 수집',
                            Icons.mark_email_read_outlined,
                            busy
                                ? null
                                : () => _run((v) async {
                                      await v.collectOutlookAndCreateVoc(
                                          top: 20);
                                    }, refresh: true),
                          ),
                        _Cmd(
                          'VOC 가져오기',
                          Icons.file_upload_outlined,
                          busy ? null : _importVoc,
                        ),
                        _Cmd(
                          'VOC 내보내기',
                          Icons.file_download_outlined,
                          busy ? null : () => _export(false),
                        ),
                        _Cmd(
                          'VOC 입력 템플릿',
                          Icons.description_outlined,
                          busy ? null : () => _export(true),
                        ),
                      ]),
                      _Group('AI 검색 데이터', Icons.auto_awesome_motion_outlined, [
                        _Cmd(
                          'AI 검색 데이터 다시 만들기',
                          Icons.hub_outlined,
                          busy
                              ? null
                              : () => _run((v) async {
                                    await v.rebuildVectorDb();
                                  }),
                        ),
                        _Cmd(
                          'AI 대화 기록 초기화',
                          Icons.cleaning_services_outlined,
                          busy
                              ? null
                              : () async {
                                  if (await _confirm(
                                    'AI 대화 기록 초기화',
                                    'AI 대화와 답변 평가 기록을 초기화합니다. '
                                        'VOC 원문은 유지됩니다.',
                                  )) {
                                    await _run((v) => v.clearAiCache());
                                  }
                                },
                        ),
                      ]),
                      _Group(
                          '초기화',
                          Icons.warning_amber_rounded,
                          [
                            _Cmd(
                              'VOC 데이터 전체 초기화',
                              Icons.delete_forever_outlined,
                              busy
                                  ? null
                                  : () async {
                                      if (await _confirm(
                                        'VOC 데이터 전체 초기화',
                                        'VOC, 답변, 지식 자료, AI 검색 데이터와 대화 기록이 '
                                            '삭제됩니다. 이 작업은 되돌릴 수 없습니다.',
                                        danger: true,
                                      )) {
                                        await _run(
                                          (v) => v.clearAllVocData(),
                                          refresh: true,
                                        );
                                      }
                                    },
                              danger: true,
                            ),
                          ],
                          danger: true),
                    ],
                  ),
                  if (vm.syncRuntimeLogs.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Card(
                      child: ExpansionTile(
                        title: const Text('동기화 실행 로그'),
                        subtitle: Text('${vm.syncRuntimeLogs.length}개 기록'),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          16,
                        ),
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 180,
                            child: SingleChildScrollView(
                              child: SelectableText(
                                vm.syncRuntimeLogs.join('\n'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('데이터 관리')),
      body: content,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.active, this.error});
  final bool active;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final tone = active ? Colors.green : Colors.orange;
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: tone.withValues(alpha: .12),
              child: Icon(Icons.storage_outlined, color: tone),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '데이터 및 동기화 관리',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'VOC를 관리하고 다른 AI VOC Assistant 설치본과 내부망으로 공유합니다.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  active ? '수신기 실행 중' : '수신기 상태 확인 필요',
                  style: TextStyle(color: tone, fontWeight: FontWeight.w700),
                ),
                if (!active && error != null)
                  SizedBox(
                    width: 260,
                    child: Text(
                      error!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: tone),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VocSyncSettingsCard extends StatefulWidget {
  const _VocSyncSettingsCard();

  @override
  State<_VocSyncSettingsCard> createState() => _VocSyncSettingsCardState();
}

class _VocSyncSettingsCardState extends State<_VocSyncSettingsCard> {
  TextEditingController? _instanceController;
  TextEditingController? _tokenController;
  List<String> _targets = [];
  bool _autoForward = false;
  bool _saving = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = Provider.of<SettingsViewModel>(context);
    if (_initialized || settings.isLoading) return;
    _instanceController = TextEditingController(text: settings.appInstanceName);
    _tokenController = TextEditingController(text: settings.vocSyncBearerToken);
    _targets = List<String>.from(settings.vocForwardWebhookTargets);
    _autoForward = settings.vocAutoForwardEnabled;
    _initialized = true;
  }

  @override
  void dispose() {
    _instanceController?.dispose();
    _tokenController?.dispose();
    super.dispose();
  }

  Future<String?> _askTarget({String initial = ''}) async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _TargetUrlDialog(initial: initial),
    );
    if (value == null || value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('http 또는 https 형식의 올바른 URL을 입력해 주세요.')),
        );
      }
      return null;
    }
    return value;
  }

  Future<void> _addTarget() async {
    final target = await _askTarget();
    if (target == null || !mounted) return;
    if (_targets.contains(target)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 등록된 URL입니다.')),
      );
      return;
    }
    setState(() => _targets.add(target));
  }

  Future<void> _editTarget(int index) async {
    final target = await _askTarget(initial: _targets[index]);
    if (target == null || !mounted) return;
    if (_targets.asMap().entries.any(
          (entry) => entry.key != index && entry.value == target,
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 등록된 URL입니다.')),
      );
      return;
    }
    setState(() => _targets[index] = target);
  }

  Future<void> _save() async {
    final instance = _instanceController?.text.trim() ?? '';
    if (instance.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('앱 인스턴스 이름을 입력해 주세요.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<SettingsViewModel>().saveSettings({
        AppConstants.settingAppInstanceName: instance,
        AppConstants.settingVocSyncBearerToken:
            _tokenController?.text.trim() ?? '',
        AppConstants.settingVocForwardWebhookTargets: _targets.join('\n'),
        AppConstants.settingVocAutoForwardEnabled: _autoForward.toString(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('VOC 동기화 설정을 저장했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsViewModel>();
    if (!_initialized || settings.isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final cs = Theme.of(context).colorScheme;
    return Card(
      key: const Key('voc-sync-settings-card'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.sync_outlined, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VOC 동기화 설정',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '다른 AI VOC Assistant 설치본과 VOC·매뉴얼을 주고받습니다.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.lan_outlined, size: 17),
                  label: Text('${_targets.length}개 연결'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 700;
                final instance = TextField(
                  key: const Key('voc-sync-instance-field'),
                  controller: _instanceController,
                  decoration: const InputDecoration(
                    labelText: '앱 인스턴스 이름',
                    hintText: '예: 본사 VOC, 고객지원팀',
                    prefixIcon: Icon(Icons.devices_outlined),
                  ),
                );
                final token = TextField(
                  key: const Key('voc-sync-token-field'),
                  controller: _tokenController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'VOC 동기화 Bearer 토큰',
                    hintText: '연결할 설치본에 동일한 토큰을 입력하세요',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                );
                if (!wide) {
                  return Column(
                    children: [
                      instance,
                      const SizedBox(height: 12),
                      token,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: instance),
                    const SizedBox(width: 12),
                    Expanded(child: token),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '연결 앱 수신 URL',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                FilledButton.tonalIcon(
                  key: const Key('voc-sync-add-target'),
                  onPressed: _addTarget,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('URL 추가'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_targets.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: const Text(
                  '등록된 연결 앱이 없습니다. 상대 앱의 수신 URL을 추가해 주세요.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              ..._targets.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: cs.primaryContainer,
                              child: Text('${entry.key + 1}'),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: SelectableText(entry.value)),
                            IconButton(
                              tooltip: '수정',
                              onPressed: () => _editTarget(entry.key),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: '삭제',
                              onPressed: () => setState(
                                () => _targets.removeAt(entry.key),
                              ),
                              icon: Icon(Icons.delete_outline, color: cs.error),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              key: const Key('voc-sync-auto-forward'),
              contentPadding: EdgeInsets.zero,
              value: _autoForward,
              title: const Text('VOC 자동 전달'),
              subtitle: const Text('VOC 등록 시 위 연결 앱으로 자동 공유합니다.'),
              onChanged: (value) => setState(() => _autoForward = value),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: const Key('voc-sync-save'),
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_saving ? '저장 중...' : '동기화 설정 저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetUrlDialog extends StatefulWidget {
  const _TargetUrlDialog({required this.initial});

  final String initial;

  @override
  State<_TargetUrlDialog> createState() => _TargetUrlDialogState();
}

class _TargetUrlDialogState extends State<_TargetUrlDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial.isEmpty ? '연결 앱 URL 추가' : '연결 앱 URL 수정'),
      content: SizedBox(
        width: 560,
        child: TextField(
          key: const Key('voc-sync-target-dialog-field'),
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: '상대 앱의 VOC 수신 URL',
            hintText: 'http://192.168.0.3:8788/webhook/voc',
            prefixIcon: Icon(Icons.link_outlined),
          ),
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _submit, child: const Text('확인')),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.wide, required this.children});
  final bool wide;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) {
          final w = wide ? (c.maxWidth - 14) / 2 : c.maxWidth;
          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children:
                children.map((e) => SizedBox(width: w, child: e)).toList(),
          );
        },
      );
}

class _Group extends StatelessWidget {
  const _Group(this.title, this.icon, this.commands, {this.danger = false});
  final String title;
  final IconData icon;
  final List<_Cmd> commands;
  final bool danger;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: danger
                        ? Colors.red
                        : Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...commands.map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: c.danger
                          ? OutlinedButton.styleFrom(
                              foregroundColor: Colors.red)
                          : null,
                      onPressed: c.action,
                      icon: Icon(c.icon),
                      label: Text(c.label),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _Cmd {
  const _Cmd(this.label, this.icon, this.action, {this.danger = false});
  final String label;
  final IconData icon;
  final VoidCallback? action;
  final bool danger;
}
