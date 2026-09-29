import 'package:flutter/material.dart';

class VocDuplicateReviewDialog extends StatefulWidget {
  final List<List<Map<String, dynamic>>> groups;
  const VocDuplicateReviewDialog({super.key, required this.groups});
  @override
  State<VocDuplicateReviewDialog> createState() => _VocDuplicateReviewDialogState();
}

class _VocDuplicateReviewDialogState extends State<VocDuplicateReviewDialog> {
  final selected = <int>{};
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('중복 후보 ${widget.groups.length}묶음'),
    content: SizedBox(width: 620, height: MediaQuery.sizeOf(context).height * .5,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('고객·제품·제목·내용이 같지만 등록 시각 등이 다른 건입니다. '
            '같은 접수의 복사본인 경우에만 선택해 주세요. 병합해도 답변과 처리 이력은 보존됩니다.'),
        const SizedBox(height: 12),
        Expanded(child: ListView.builder(itemCount: widget.groups.length,
          itemBuilder: (context, i) {
            final rows = widget.groups[i];
            final first = rows.first;
            return Card(child: Padding(padding: const EdgeInsets.all(8), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                CheckboxListTile(contentPadding: EdgeInsets.zero,
                  value: selected.contains(i),
                  onChanged: (value) => setState(() {
                    if (value == true) { selected.add(i); } else { selected.remove(i); }
                  }),
                  title: Text('${first['title']} (${rows.length}건)'),
                  subtitle: Text('${first['customer'] ?? '미입력'} · ${first['project'] ?? '미입력'}')),
                ExpansionTile(title: const Text('내용과 등록 정보 비교'),
                  children: [for (final row in rows) Padding(
                    padding: const EdgeInsets.all(8),
                    child: Align(alignment: Alignment.centerLeft, child: SelectableText(
                      '등록: ${row['created_at']}\\n경로: ${row['source'] ?? '직접 등록'}\\n'
                      '상태: ${row['status']} · ID: ${row['id']}\\n${row['content']}'
                          .replaceAll(r'\n', '\n'))))]),
              ])));
          })),
      ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기')),
      FilledButton(onPressed: selected.isEmpty ? null : () => Navigator.pop(context,
        [for (final i in selected) widget.groups[i].map((r) => r['id'] as String).toList()]),
        child: Text('선택한 ${selected.length}묶음 병합')),
    ],
  );
}
