import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/photo_local_datasource.dart';
import '../../data/repositories/photo_repository_impl.dart';
import '../../domain/entities/photo.dart';
import '../../domain/repositories/photo_repository.dart';

// Datasource
final photoLocalDatasourceProvider = Provider<PhotoLocalDatasource>((ref) {
  return PhotoLocalDatasource();
});

// Repository
final photoRepositoryProvider = Provider<PhotoRepository>((ref) {
  return PhotoRepositoryImpl(ref.watch(photoLocalDatasourceProvider));
});

// Permission state
enum PermissionStatus { unknown, granted, denied, limited }

final permissionStatusProvider =
    NotifierProvider<PermissionNotifier, PermissionStatus>(
  PermissionNotifier.new,
);

class PermissionNotifier extends Notifier<PermissionStatus> {
  @override
  PermissionStatus build() => PermissionStatus.unknown;

  PhotoRepository get _repository => ref.read(photoRepositoryProvider);

  Future<void> checkPermission() async {
    final granted = await _repository.hasPermission();
    state = granted ? PermissionStatus.granted : PermissionStatus.denied;
  }

  Future<void> requestPermission() async {
    final granted = await _repository.requestPermission();
    state = granted ? PermissionStatus.granted : PermissionStatus.denied;
  }
}

// Photos
final photosProvider =
    NotifierProvider<PhotosNotifier, AsyncValue<List<Photo>>>(
  PhotosNotifier.new,
);

class PhotosNotifier extends Notifier<AsyncValue<List<Photo>>> {
  int _currentPage = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool _initialLoadTriggered = false;

  @override
  AsyncValue<List<Photo>> build() => const AsyncValue.loading();

  PhotoRepository get _repository => ref.read(photoRepositoryProvider);

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  /// Idempotent — calling this multiple times only triggers the fetch
  /// once. Resets on error so the caller can retry.
  Future<void> loadInitial() async {
    if (_initialLoadTriggered) return;
    _initialLoadTriggered = true;

    state = const AsyncValue.loading();
    _currentPage = 0;
    _hasMore = true;
    try {
      final photos = await _repository.getPhotos(page: 0);
      _hasMore = photos.length >= 80;
      state = AsyncValue.data(photos);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      _initialLoadTriggered = false;
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore) return;
    _isLoadingMore = true;

    try {
      _currentPage++;
      final newPhotos = await _repository.getPhotos(page: _currentPage);
      _hasMore = newPhotos.length >= 80;
      final current = state.value ?? [];
      state = AsyncValue.data([...current, ...newPhotos]);
    } catch (e, st) {
      _currentPage--;
      state = AsyncValue.error(e, st);
    } finally {
      _isLoadingMore = false;
    }
  }
}
