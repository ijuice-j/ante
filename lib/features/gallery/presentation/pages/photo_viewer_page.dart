import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../domain/entities/photo.dart';

/// Typed arguments passed via go_router's `extra` when pushing `/viewer`.
class PhotoViewerArgs {
  final List<Photo> photos;
  final int initialIndex;

  const PhotoViewerArgs({
    required this.photos,
    required this.initialIndex,
  });
}

/// Full-screen photo viewer built on `photo_view`. PhotoViewGallery handles
/// the PageView ↔ InteractiveViewer gesture conflict internally, so pinch
/// zoom in both directions and swipe between pages all work together the
/// way users expect.
class PhotoViewerPage extends StatefulWidget {
  final List<Photo> photos;
  final int initialIndex;

  const PhotoViewerPage({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {
  late final PageController _pageController;
  late int _currentIndex;

  // Cache the resolved File for each photo so we don't re-resolve every
  // time the user scrubs past a page.
  final Map<String, Future<File?>> _fileFutures = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<File?> _fileFor(Photo photo) {
    return _fileFutures.putIfAbsent(photo.id, () async {
      final asset = await AssetEntity.fromId(photo.id);
      return asset?.file;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.black.withValues(alpha: 0.35),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(
            '${_currentIndex + 1} / ${widget.photos.length}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: PhotoViewGallery.builder(
          pageController: _pageController,
          itemCount: widget.photos.length,
          scrollPhysics: const BouncingScrollPhysics(),
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          onPageChanged: (i) => setState(() => _currentIndex = i),
          builder: (context, index) {
            final photo = widget.photos[index];
            return PhotoViewGalleryPageOptions.customChild(
              initialScale: PhotoViewComputedScale.contained,
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.contained * 4,
              child: _PhotoContent(
                photo: photo,
                fileFuture: _fileFor(photo),
              ),
            );
          },
          loadingBuilder: (context, _) =>
              const Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      ),
    );
  }
}

class _PhotoContent extends StatelessWidget {
  final Photo photo;
  final Future<File?> fileFuture;

  const _PhotoContent({required this.photo, required this.fileFuture});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: fileFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Image.file(
            snapshot.data!,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            // Let the image take the natural size so PhotoView can center
            // and scale it correctly.
            width: double.infinity,
            height: double.infinity,
          );
        }
        // Fall back to the cached thumbnail so the user sees something
        // immediately while the full file resolves.
        final thumb = photo.thumbnail;
        if (thumb != null) {
          return Image.memory(
            thumb,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            width: double.infinity,
            height: double.infinity,
          );
        }
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      },
    );
  }
}
