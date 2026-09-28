import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../data/services/bundled_manual_service.dart';

class ManualImageGallery extends StatefulWidget {
  final String entryId;
  const ManualImageGallery({super.key, required this.entryId});

  @override
  State<ManualImageGallery> createState() => _ManualImageGalleryState();
}

class _ManualImageGalleryState extends State<ManualImageGallery> {
  late Future<List<Map<String, dynamic>>> _images;

  @override
  void initState() {
    super.initState();
    _images = BundledManualService.imagesFor(widget.entryId);
  }

  @override
  void didUpdateWidget(covariant ManualImageGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entryId != widget.entryId) {
      _images = BundledManualService.imagesFor(widget.entryId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _images,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Text('매뉴얼 이미지를 읽지 못했습니다.');
        final images = snapshot.data ?? const [];
        if (images.isEmpty) return const SizedBox.shrink();
        return ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text('매뉴얼 원본 이미지 ${images.length}개'),
          subtitle: const Text('화면 캡처와 버튼 아이콘 · 눌러서 확대'),
          children: images.map((image) => _ManualImage(
            key: ValueKey(image['id']),
            image: image,
          )).toList(),
        );
      },
    );
  }
}

class _ManualImage extends StatefulWidget {
  final Map<String, dynamic> image;
  const _ManualImage({super.key, required this.image});

  @override
  State<_ManualImage> createState() => _ManualImageState();
}

class _ManualImageState extends State<_ManualImage> {
  late final Future<Uint8List> _bytes =
      BundledManualService.imageBytes(widget.image['id'] as String);

  @override
  Widget build(BuildContext context) {
    final isIcon = widget.image['kind'] == 'icon';
    final label = isIcon ? '매뉴얼 버튼 아이콘' : '매뉴얼 화면 캡처';
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Text('이미지를 읽지 못했습니다.');
        final bytes = snapshot.data;
        if (bytes == null) return const SizedBox(
          height: 32, child: Center(child: LinearProgressIndicator()));
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => Dialog.fullscreen(
                child: Scaffold(
                  appBar: AppBar(title: Text(label)),
                  body: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 6,
                    child: Center(child: Image.memory(bytes,
                      fit: BoxFit.contain, semanticLabel: label)),
                  ),
                ),
              ),
            ),
            child: Image.memory(bytes,
              height: isIcon ? 48 : 220,
              fit: BoxFit.contain,
              semanticLabel: label),
          ),
        );
      },
    );
  }
}
