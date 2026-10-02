import 'package:flutter/material.dart';

/// Dismissing a notice only changes its presentation, never the running task.
/// Give a new task or terminal result a new key to make it visible again.
class DismissibleNotice extends StatefulWidget {
  const DismissibleNotice({super.key, required this.child});

  final Widget child;

  @override
  State<DismissibleNotice> createState() => _DismissibleNoticeState();
}

class _DismissibleNoticeState extends State<DismissibleNotice> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: widget.child),
          SafeArea(
            left: false,
            top: false,
            child: IconButton(
              tooltip: '알림 닫기',
              onPressed: () => setState(() => _dismissed = true),
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    );
  }
}
