import 'dart:math' as math;
import 'dart:ui';

import 'package:image_loom/image_loom_platform_interface.dart';

import 'geometry_state.dart';
import 'image_operation.dart';

enum OutputFormat { jpeg, png, webp, heic }

class ImageLoom {
  ImageLoom(this.path);

  /// Path of the source image file.
  final String path;

  Size? _size;

  /// Upright (EXIF-applied) size in pixels. Read once, then cached.
  Future<Size> get size async =>
      _size ??= await ImageLoomPlatform.instance.getImageSize(path);

  /// Folds [operations] into one matrix and output size.
  Future<GeometryState> plan(List<ImageOperation> operations) async {
    var state = GeometryState.identity(await size);
    for (final op in operations) {
      state = op.apply(state);
    }
    return state;
  }

  /// Applies [operations] in order.
  /// Returns [outputPath] on success.
  Future<String?> apply(
    List<ImageOperation> operations, {
    required String outputPath,
    OutputFormat format = OutputFormat.jpeg,
    int quality = 92,
  }) async {
    final state = await plan(operations);
    return ImageLoomPlatform.instance.render(
      inputPath: path,
      outputPath: outputPath,
      affine: state.toAffine(),
      outWidth: math.max(1, state.size.width.round()),
      outHeight: math.max(1, state.size.height.round()),
      format: format.name,
      quality: quality.clamp(1, 100),
    );
  }
}
