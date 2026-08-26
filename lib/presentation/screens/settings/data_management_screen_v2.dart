import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../../data/services/peer_sync_service.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../viewmodels/integration_viewmodel.dart';
import '../../viewmodels/knowledge_base_viewmodel.dart';
import '../../viewmodels/settings_viewmodel.dart';
import '../../viewmodels/voc_viewmodel.dart';

class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({super.key});

  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  bool _peerSyncRunning = false;

  Future<void> _refresh() async {
    await context.read<VocViewModel>().loadVocs();
    await context.read<KnowledgeBaseViewModel>().loadEntries();
    await context.read<DashboardViewModel>().loadDashboard();
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
      final result = await PeerSyncService(context.read<SettingsViewModel>()).pullAllVocs();
      if (!mounted) return;
      await _refresh();
      _show(
        '상대 앱 VOC 가져오기 완료 · 원격 VOC ${result.remoteTotal}건 · '
        '신규 ${result.created}건 · 갱신 ${result.updated}건 · '
        '반영 ${result.applied}건 · 앱 성공 ${result.successApps}곳'
        '${result.failedApps > 0 ? ' · 앱 실패 ${result.failedApps}곳' : ''}',
        error: result.failedApps > 0,
      );
    } catch (e) {
      _show('상대 앱 VOC 가져오기 실패: $e', error: true);
    } finally {
      if (mounted) setState(() => _peerSyncRunning = false);
    }
  }

  Future<void> _bootstrapPeerData() async {
    if (_peerSyncRunning) return;
    setState(() => _peerSyncRunning = true);
    try {
      final result = await PeerSyncService(context.read<SettingsViewModel>()).bootstrap();
      if (!mounted) return;
      await _refresh();
      _show(
        '초기 핸드셰이크 완료\n'
        'VOC: 원격 ${result.vocRemoteTotal}건 · 신규 ${result.vocCreated}건 · 갱신 ${result.vocUpdated}건\n'
        '지식베이스: 원격 ${result.manualRemoteTotal}건 · 신규 ${result.manualCreated}건 · 중복/제외 ${result.manualSkipped}건\n'
        '앱: 성공 ${result.successApps}곳${result.failedApps > 0 ? ' · 실패 ${result.failedApps}곳' : ''}',
        error: result.failedApps > 0,
      );
    } catch (e) {
      _show('초기 핸드셰이크 실패: $e', error: true);
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
          TextButton(onPressed: () => Navigator.pop(ctx, 'append'), child: const Text('추가')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'overwrite'), child: const Text('덮어쓰기')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'skip'), child: const Text('건너뛰기')),
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
    final name = template ? 'VOC_Import_Template_$date.xlsx' : 'VOC_Backup_$date.xlsx';
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

  Future<bool> _confirm(String title, String body, {bool danger = false}) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
              FilledButton(
                style: danger ? FilledButton.styleFrom(backgroundColor: Colors.red) : null,
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
    return Scaffold(
      appBar: AppBar(title: const Text('데이터 관리')),
      body: LayoutBuilder(
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
                    _Header(active: vm.inAppReceiverRunning),
                    if (busy) ...[
                      const SizedBox(height: 14),
                      const LinearProgressIndicator(),
                    ],
                    const SizedBox(height: 16),
                    _Grid(
                      wide: wide,
                      children: [
                        _Group('시스템 간 동기화', Icons.sync_alt_outlined, [
                          _Cmd(
                            '전체 VOC · 매뉴얼 공유',
                            Icons.cloud_upload_outlined,
                            busy ? null : () => _run((v) => v.forwardFullVocAndManualToPeerApps()),
                          ),
                          _Cmd(
                            '상대 앱 VOC 가져오기',
                            Icons.cloud_download_outlined,
                            busy ? null : _pullPeerVocs,
                          ),
                          _Cmd(
                            '초기 핸드셰이크',
                            Icons.handshake_outlined,
                            busy ? null : _bootstrapPeerData,
                          ),
                          _Cmd(
                            '실패 동기화 재시도 (${vm.syncRetryQueueCount})',
                            Icons.refresh_outlined,
                            busy || vm.syncRetryQueueCount == 0
                                ? null
                                : () => _run((v) => v.retryPendingSyncQueue()),
                          ),
                        ]),
                        _Group('가져오기 · 백업', Icons.folder_copy_outlined, [
                          _Cmd(
                            'Outlook 메일에서 VOC 수집',
                            Icons.mark_email_read_outlined,
                            busy ? null : () => _run((v) async { await v.collectOutlookAndCreateVoc(top: 20); }, refresh: true),
                          ),
                          _Cmd('VOC 가져오기', Icons.file_upload_outlined, busy ? null : _importVoc),
                          _Cmd('VOC 내보내기', Icons.file_download_outlined, busy ? null : () => _export(false)),
                          _Cmd('VOC 입력 템플릿', Icons.description_outlined, busy ? null : () => _export(true)),
                        ]),
                        _Group('AI · 검색 데이터', Icons.auto_awesome_motion_outlined, [
                          _Cmd('Vector DB 재생성', Icons.hub_outlined, busy ? null : () => _run((v) async { await v.rebuildVectorDb(); })),
                          _Cmd('AI 캐시 초기화', Icons.cleaning_services_outlined, busy ? null : () async {
                            if (await _confirm('AI 캐시 초기화', 'AI 대화와 피드백 캐시를 초기화합니다. VOC 원문은 유지됩니다.')) {
                              await _run((v) => v.clearAiCache());
                            }
                          }),
                        ]),
                        _Group('초기화', Icons.warning_amber_rounded, [
                          _Cmd('VOC 데이터 전체 초기화', Icons.delete_forever_outlined, busy ? null : () async {
                            if (await _confirm(
                              'VOC 데이터 전체 초기화',
                              'VOC, 답변, 지식베이스, Vector DB와 AI 캐시가 삭제됩니다. 되돌릴 수 없습니다.',
                              danger: true,
                            )) {
                              await _run((v) => v.clearAllVocData(), refresh: true);
                            }
                          }, danger: true),
                        ], danger: true),
                      ],
                    ),
                    if (vm.syncRuntimeLogs.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Card(
                        child: ExpansionTile(
                          title: const Text('동기화 실행 로그'),
                          subtitle: Text('${vm.syncRuntimeLogs.length}개 기록'),
                          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 180,
                              child: SingleChildScrollView(
                                child: SelectableText(vm.syncRuntimeLogs.join('\n')),
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
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.active});
  final bool active;

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
                    '데이터 및 동기화 운영',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '가져오기, 백업, 동기화와 초기화 같은 실행 작업을 관리합니다.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Text(
              active ? '수신기 실행 중' : '수신기 확인 필요',
              style: TextStyle(color: tone, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
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
            children: children.map((e) => SizedBox(width: w, child: e)).toList(),
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
                  Icon(icon, color: danger ? Colors.red : Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
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
                      style: c.danger ? OutlinedButton.styleFrom(foregroundColor: Colors.red) : null,
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
