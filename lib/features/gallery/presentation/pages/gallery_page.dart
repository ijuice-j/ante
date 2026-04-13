import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/photo.dart';
import '../providers/gallery_providers.dart';
import '../widgets/permission_denied_view.dart';
import '../widgets/photo_grid.dart';

class GalleryPage extends ConsumerStatefulWidget {
  const GalleryPage({super.key});

  @override
  ConsumerState<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends ConsumerState<GalleryPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Check permission on first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(permissionStatusProvider.notifier).requestPermission();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check when returning from settings
    if (state == AppLifecycleState.resumed) {
      ref.read(permissionStatusProvider.notifier).checkPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissionStatus = ref.watch(permissionStatusProvider);
    final photos = ref.watch(photosProvider);

    // Load photos when permission is granted
    ref.listen(permissionStatusProvider, (prev, next) {
      if (next == PermissionStatus.granted && prev != PermissionStatus.granted) {
        ref.read(photosProvider.notifier).loadInitial();
      }
    });

    return Scaffold(
      body: _buildBody(permissionStatus, photos),
    );
  }

  Widget _buildBody(
    PermissionStatus permissionStatus,
    AsyncValue<List<Photo>> photos,
  ) {
    switch (permissionStatus) {
      case PermissionStatus.unknown:
        return const Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        );

      case PermissionStatus.denied:
        return PermissionDeniedView(
          onRequestPermission: () {
            ref.read(permissionStatusProvider.notifier).requestPermission();
          },
          onOpenSettings: () => PhotoManager.openSetting(),
        );

      case PermissionStatus.limited:
      case PermissionStatus.granted:
        return _buildGallery(photos);
    }
  }

  Widget _buildGallery(AsyncValue<List<Photo>> photos) {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverAppBar(
          floating: true,
          snap: true,
          backgroundColor: AppTheme.scaffoldDark.withValues(alpha: 0.95),
          title: const Text('Gallery'),
          actions: [
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: () {},
            ),
            const SizedBox(width: 4),
          ],
        ),
      ],
      body: photos.when(
        loading: () => const PhotoShimmerGrid(),
        error: (error, _) => _buildErrorView(error),
        data: (photoList) {
          if (photoList.isEmpty) {
            return _buildEmptyView();
          }
          return PhotoGrid(
            photos: photoList,
            isLoadingMore: ref.read(photosProvider.notifier).isLoadingMore,
            onLoadMore: () => ref.read(photosProvider.notifier).loadMore(),
          );
        },
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_camera_outlined,
            size: 64,
            color: AppTheme.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No photos yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your photos will appear here',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.errorRed),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => ref.read(photosProvider.notifier).loadInitial(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
