import 'dart:typed_data';

class Photo {
  final String id;
  final String title;
  final int width;
  final int height;
  final DateTime createDateTime;
  final Duration duration;
  final Uint8List? thumbnail;

  const Photo({
    required this.id,
    required this.title,
    required this.width,
    required this.height,
    required this.createDateTime,
    this.duration = Duration.zero,
    this.thumbnail,
  });

  bool get isVideo => duration > Duration.zero;
}
