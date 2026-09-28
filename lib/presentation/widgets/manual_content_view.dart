import 'package:flutter/material.dart';
import '../../data/services/manual_content.dart';
import 'manual_image_gallery.dart';

/// Used in knowledge entries AND the selected answer evidence panel.
class ManualContentView extends StatelessWidget {
  final String content;
  final String entryId;
  const ManualContentView({super.key, required this.content, required this.entryId});

  @override
  Widget build(BuildContext context) {
    final parsed = ManualContent.parse(content);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (parsed.body.isNotEmpty)
        SelectableText(parsed.body, style: const TextStyle(height: 1.55)),
      ManualImageGallery(entryId: entryId,
          expectImages: parsed.transcription.isNotEmpty),
      if (parsed.transcription.isNotEmpty)
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('이미지 자동 인식 글자 확인', style: TextStyle(fontSize: 13)),
          subtitle: const Text('글자 인식에 오류가 있을 수 있습니다. 원본 이미지를 기준으로 확인하세요.',
              style: TextStyle(fontSize: 12)),
          children: [Padding(padding: const EdgeInsets.only(bottom: 12),
            child: SelectableText(parsed.transcription, style: const TextStyle(fontSize: 12)))],
        ),
    ]);
  }
}
