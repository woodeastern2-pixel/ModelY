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
        if (snapshot.hasError) {
          return const Text('매뉴얼 이미지를 읽지 못했습니다.');
        }
        final images = snapshot.data ?? const [];
        if (images.isEmpty) return const SizedBox.shrink();
        return TextButton.icon(
          icon: const Icon(Icons.photo_library_outlined),
          label: Text('매뉴얼 원본 이미지 ${images.length}개 보기'),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => _ImageReader(images: images),
          ),
        );
      },
    );
  }
}

class _ImageReader extends StatefulWidget {
  final List<Map<String, dynamic>> images;
  const _ImageReader({required this.images});

  @override
  State<_ImageReader> createState() => _ImageReaderState();
}

class _ImageReaderState extends State<_ImageReader> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(title: const Text('매뉴얼 원본 이미지')),
        body: Column(children: [
          Expanded(child: PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (value) => setState(() => _page = value),
            itemBuilder: (_, index) => _ManualImage(
              key: ValueKey(widget.images[index]['id']),
              image: widget.images[index],
            ),
          )),
          SafeArea(top: false, child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: '이전 이미지',
                onPressed: _page > 0 ? () => _controller.previousPage(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('${_page + 1} / ${widget.images.length}'),
              IconButton(
                tooltip: '다음 이미지',
                onPressed: _page + 1 < widget.images.length ? () => _controller.nextPage(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          )),
        ]),
      ),
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
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('이미지를 읽지 못했습니다.'));
        }
        final bytes = snapshot.data;
        if (bytes == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 6,
          child: Center(child: Image.memory(bytes,
            fit: BoxFit.contain,
            semanticLabel: widget.image['kind'] == 'icon'
                ? '매뉴얼 버튼 아이콘' : '매뉴얼 화면 캡처')),
        );
      },
    );
  }
}
