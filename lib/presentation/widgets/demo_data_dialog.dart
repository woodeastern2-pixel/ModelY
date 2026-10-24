import 'package:flutter/material.dart';
import '../../data/services/demo_voc_store.dart';
import '../../data/services/sample_voc_generator.dart';

class DemoDataDialog extends StatefulWidget {
  const DemoDataDialog({super.key, required this.onImport,
    required this.onClear, this.existingCount = 0});
  final Future<DemoImportResult> Function() onImport;
  final Future<int> Function() onClear;
  final int existingCount;
  @override
  State<DemoDataDialog> createState() => _DemoDataDialogState();
}

class _DemoDataDialogState extends State<DemoDataDialog> {
  bool _busy = false;
  String? _message;
  bool _failed = false;
  late int _count = widget.existingCount;

  Future<void> _import() async {
    if (_busy) return;
    setState(() { _busy = true; _failed = false; _message = '시연 데이터를 입력하고 있습니다.'; });
    try {
      final result = await widget.onImport();
      if (!mounted) return;
      setState(() {
        _count += result.added;
        _message = '${result.added}건 추가 · 이미 등록된 ${result.skipped}건 제외';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _message = '입력을 완료하지 못했습니다. 저장 중 실패한 자료는 되돌렸습니다. 다시 시도해 주세요.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) =>
      AlertDialog(
        title: const Text('시연 데이터만 삭제할까요?'),
        content: const Text('시연 문의와 연결된 답변·처리 기록을 삭제합니다. 실제 문의와 지식자료는 유지됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('시연 데이터 삭제')),
        ],
      ));
    if (confirmed != true || !mounted) return;
    setState(() { _busy = true; _failed = false; _message = '시연 데이터를 정리하고 있습니다.'; });
    try {
      final removed = await widget.onClear();
      if (!mounted) return;
      setState(() { _count = 0; _message = '시연 문의 $removed건을 삭제했습니다.'; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _failed = true; _message = '시연 데이터를 삭제하지 못했습니다. 다시 시도해 주세요.'; });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('브리티웍스 시연 데이터'),
      scrollable: true,
      content: SizedBox(width: 560, child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('10개 분야 × 100건 = 1,000건', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('접수 기간: ${SampleVocGenerator.periodLabel}\n'
              '10가지 업무 페르소나와 10가지 문의 유형을 포함합니다.'),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 4, children: SampleVocGenerator.fields
              .map((field) => Chip(label: Text('$field 100건'))).toList()),
          const SizedBox(height: 12),
          const Text('신입·영업·인사·재무·개발·현장·팀장·총무·관리자·해외 협업 담당자의 가상 문의입니다. '
              '브리티웍스의 실제 장애나 운영 실적을 뜻하지 않습니다.'),
          const SizedBox(height: 8),
          const Text('현재 데이터에 추가되며 대시보드 집계에 포함됩니다. '
              '제목·본문에 시연 문구를 붙이지 않으며 내부 출처로 구분합니다. 반복 입력 시 기존 자료는 건너뜁니다. '
              '답변 화면에서 내부 자료로 초안을 만들며, 자료가 부족하면 추가 확인용 초안을 제공합니다. '
              '가상 답변을 승인된 지식자료로 자동 등록하지 않습니다.'),
          const SizedBox(height: 8),
          Text('현재 등록된 시연 문의: $_count건'),
          if (_busy) const Padding(padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator()),
          if (_message != null) Padding(padding: const EdgeInsets.only(top: 8),
            child: Text(_message!, key: const Key('demo-result'),
              style: TextStyle(color: _failed ? Theme.of(context).colorScheme.error : null))),
        ],
      )),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('닫기')),
        TextButton(onPressed: _busy || _count == 0 ? null : _clear,
            child: const Text('시연 데이터만 삭제')),
        FilledButton.icon(key: const Key('demo-import'),
          onPressed: _busy ? null : _import,
          icon: const Icon(Icons.play_arrow), label: const Text('시연 데이터 입력')),
      ],
    ),
  );
}
