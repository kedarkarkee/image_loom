import 'dart:math' as math;
import 'dart:ui';

import 'package:image_loom/image_loom_platform_interface.dart';

import 'geometry_state.dart';
import 'image_operation.dart';

enum OutputFormat { jpeg, png, webp, heic }

class ImageLoom {
  /// Constructs an ImageLoom object when the upright size is already known.
  /// Use [ImageLoom.open] if upright (EXIF-applied) size is unknown.
  const ImageLoom.withSize(this.path, this.size);

  /// Reads the upright (EXIF-applied) size natively, then returns a ready instance.
  static Future<ImageLoom> open(String path) async {
    final size = await ImageLoomPlatform.instance.getImageSize(path);
    return ImageLoom.withSize(path, size);
  }

  /// Path of the source image file.
  final String path;

  /// Size of the image in pixels. Upright (EXIF-applied).
  final Size size;

  /// Folds [operations] into one matrix and output size.
  GeometryState plan(List<ImageOperation> operations) {
    var state = GeometryState.identity(size);
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
    final state = plan(operations);
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
