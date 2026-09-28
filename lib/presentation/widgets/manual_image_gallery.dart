import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../data/services/bundled_manual_service.dart';

class ManualImageGallery extends StatefulWidget {
  final String entryId;
  final bool expectImages;
  const ManualImageGallery({super.key, required this.entryId, this.expectImages = false});

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
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.all(12),
              child: Text('원본 이미지를 불러오는 중입니다…'));
        }
        if (images.isEmpty) {
          return widget.expectImages
              ? const Text('이 항목의 원본 이미지 연결을 찾지 못했습니다. 원본 문서를 다시 추가해 주세요.')
              : const SizedBox.shrink();
        }
        // Preserve document order; show screenshots and small button icons.
        // More images are available in the paged reader without decoding all at once.
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 12),
          Text('매뉴얼 원본 이미지 ${images.length}개',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (var index = 0; index < images.length && index < 3; index++)
            Padding(padding: const EdgeInsets.only(bottom: 8),
              child: Semantics(button: true, label: '원본 이미지 ${index + 1} 확대',
                child: InkWell(
                  onTap: () => _open(images, index),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(height: images[index]['kind'] == 'icon' ? 64 : 260,
                      child: _ManualImage(key: ValueKey('inline-${images[index]['id']}'),
                          image: images[index], interactive: false)),
                    Text('이미지 ${index + 1} · 눌러서 확대',
                        style: Theme.of(context).textTheme.labelSmall),
                  ]),
                ),
              )),
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(
            icon: const Icon(Icons.photo_library_outlined),
            label: Text('매뉴얼 원본 이미지 ${images.length}개 보기'),
            onPressed: () => _open(images, 0),
          )),
        ]);
      },
    );
  }
  void _open(List<Map<String, dynamic>> images, int index) {
    showDialog<void>(context: context,
        builder: (_) => _ImageReader(images: images, initialPage: index));
  }
}

class _ImageReader extends StatefulWidget {
  final List<Map<String, dynamic>> images;
  final int initialPage;
  const _ImageReader({required this.images, this.initialPage = 0});

  @override
  State<_ImageReader> createState() => _ImageReaderState();
}

class _ImageReaderState extends State<_ImageReader> {
  late final _controller = PageController(initialPage: widget.initialPage);
  late int _page = widget.initialPage;

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
  final bool interactive;
  const _ManualImage({super.key, required this.image, this.interactive = true});

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
        final image = ColoredBox(color: Colors.white,
          child: Center(child: Image.memory(bytes,
            fit: BoxFit.contain,
            cacheWidth: widget.interactive || widget.image['kind'] == 'icon' ? null : 1080,
            errorBuilder: (_, __, ___) => const Text('이미지 형식을 읽지 못했습니다.'),
            semanticLabel: widget.image['kind'] == 'icon'
                ? '매뉴얼 버튼 아이콘' : '매뉴얼 화면 캡처')));
        return widget.interactive
            ? InteractiveViewer(minScale: 0.5, maxScale: 6, child: image)
            : image;
      },
    );
  }
}

