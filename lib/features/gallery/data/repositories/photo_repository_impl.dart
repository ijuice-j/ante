import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';

import '../../domain/entities/photo.dart';
import '../../domain/repositories/photo_repository.dart';
import '../datasources/photo_local_datasource.dart';

class PhotoRepositoryImpl implements PhotoRepository {
  final PhotoLocalDatasource _datasource;

  PhotoRepositoryImpl(this._datasource);

  @override
  Future<bool> requestPermission() async {
    final state = await _datasource.requestPermission();
    return state.isAuth;
  }

  @override
  Future<bool> hasPermission() async {
    final state = await _datasource.checkPermission();
    return state.isAuth;
  }

  @override
  Future<List<Photo>> getPhotos({required int page, int pageSize = 80}) async {
    final assets = await _datasource.getAssets(page: page, pageSize: pageSize);
    return Future.wait(assets.map(_mapAssetToPhoto));
  }

  @override
  Future<Uint8List?> getThumbnail(
    String assetId, {
    int width = 200,
    int height = 200,
  }) {
    return _datasource.getThumbnail(assetId, width: width, height: height);
  }

  @override
  Future<int> getTotalCount() => _datasource.getTotalAssetCount();

  Future<Photo> _mapAssetToPhoto(AssetEntity asset) async {
    final thumb = await asset.thumbnailDataWithSize(const ThumbnailSize(200, 200));
    return Photo(
      id: asset.id,
      title: asset.title ?? '',
      width: asset.width,
      height: asset.height,
      createDateTime: asset.createDateTime,
      duration: Duration(seconds: asset.duration),
      thumbnail: thumb,
    );
  }
}
