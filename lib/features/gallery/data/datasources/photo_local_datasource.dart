import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';

class PhotoLocalDatasource {
  Future<PermissionState> requestPermission() async {
    return PhotoManager.requestPermissionExtend();
  }

  Future<PermissionState> checkPermission() async {
    return PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        iosAccessLevel: IosAccessLevel.readWrite,
      ),
    );
  }

  Future<List<AssetEntity>> getAssets({
    required int page,
    int pageSize = 80,
  }) async {
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      filterOption: FilterOptionGroup(
        orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
      ),
    );

    if (albums.isEmpty) return [];

    final recentAlbum = albums.first;
    return recentAlbum.getAssetListPaged(page: page, size: pageSize);
  }

  Future<Uint8List?> getThumbnail(
    String assetId, {
    int width = 200,
    int height = 200,
  }) async {
    final asset = await AssetEntity.fromId(assetId);
    if (asset == null) return null;
    return asset.thumbnailDataWithSize(ThumbnailSize(width, height));
  }

  Future<int> getTotalAssetCount() async {
    final albums = await PhotoManager.getAssetPathList(type: RequestType.common);
    if (albums.isEmpty) return 0;
    return albums.first.assetCountAsync;
  }
}
