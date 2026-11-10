import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tawheeed/core/theme/theme.dart';

/// Full-screen photo viewer — swipe between pages, pinch-to-zoom and a share
/// button, so attached photos behave like a phone gallery.
class PhotoGalleryScreen extends StatefulWidget {
  final List<String> imagePaths;
  final int initialIndex;
  final String? title;

  const PhotoGalleryScreen({
    super.key,
    required this.imagePaths,
    this.initialIndex = 0,
    this.title,
  });

  @override
  State<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends State<PhotoGalleryScreen> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.imagePaths.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final path = widget.imagePaths[_index];
    await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.imagePaths.length;
    // Decode at twice the screen's physical width: sharp at 1x and through
    // the first zoom steps, while a 12 MP photo costs ~14 MB instead of ~48.
    final cacheWidth = (MediaQuery.sizeOf(context).width *
            MediaQuery.devicePixelRatioOf(context) *
            2)
        .round();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.title == null
              ? 'عکس ${_index + 1} از $total'
              : '${widget.title} — عکس ${_index + 1} از $total',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 15),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'ارسال عکس',
            icon: const Icon(Icons.share_outlined),
            onPressed: _share,
          ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: total,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) => InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: Image.file(
              File(widget.imagePaths[i]),
              cacheWidth: cacheWidth,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 48,
                  color: Colors.white54,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
