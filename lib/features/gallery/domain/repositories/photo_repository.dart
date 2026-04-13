import 'dart:typed_data';

import '../entities/photo.dart';

abstract class PhotoRepository {
  Future<bool> requestPermission();
  Future<bool> hasPermission();
  Future<List<Photo>> getPhotos({required int page, int pageSize = 80});
  Future<Uint8List?> getThumbnail(String assetId, {int width, int height});
  Future<int> getTotalCount();
}
