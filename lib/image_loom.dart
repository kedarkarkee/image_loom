import 'dart:ui';

import 'package:image_loom/image_loom_platform_interface.dart';

enum OutputFormat { jpeg, png, webp, heic }

class ImageLoom {
  ImageLoom(this.path);

  /// Path of the source image file.
  final String path;

  Size? _size;

  /// Upright (EXIF-applied) size in pixels. Read once, then cached.
  Future<Size> get size async =>
      _size ??= await ImageLoomPlatform.instance.getImageSize(path);
}
