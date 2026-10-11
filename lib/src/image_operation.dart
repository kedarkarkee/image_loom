import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show Alignment, EdgeInsets;
import 'package:vector_math/vector_math_64.dart' show Matrix4;

import 'geometry_state.dart';

part 'operations/crop.dart';
part 'operations/flip.dart';
part 'operations/pad.dart';
part 'operations/resize.dart';
part 'operations/rotate.dart';
part 'operations/scale.dart';
part 'operations/skew.dart';
part 'operations/translate.dart';

abstract class ImageOperation {
  const ImageOperation();

  GeometryState apply(GeometryState s);

  /// {@macro image_operation.crop}
  const factory ImageOperation.crop(Rect rect) = Crop;

  /// {@macro image_operation.cropToAspect}
  const factory ImageOperation.cropToAspect(
    double aspect, {
    Alignment alignment,
  }) = CropToAspect;

  /// {@macro image_operation.flip}
  const factory ImageOperation.flip({bool horizontal, bool vertical}) = Flip;

  /// {@macro image_operation.transpose}
  const factory ImageOperation.transpose() = Transpose;

  /// {@macro image_operation.transverse}
  const factory ImageOperation.transverse() = Transverse;

  /// {@macro image_operation.pad}
  const factory ImageOperation.pad(EdgeInsets padding) = Pad;

  /// {@macro image_operation.resize}
  const factory ImageOperation.resize(Size target) = Resize;

  /// {@macro image_operation.rotate}
  const factory ImageOperation.rotate(double degrees) = Rotate;

  /// {@macro image_operation.scale}
  const factory ImageOperation.scale(double factor) = Scale;

  /// {@macro image_operation.rotate}
  const factory ImageOperation.scaleToFit(Size box, {bool cover}) = ScaleToFit;

  /// {@macro image_operation.skew}
  const factory ImageOperation.skew({double xDegrees, double yDegrees}) = Skew;

  /// {@macro image_operation.translate}
  const factory ImageOperation.translate(Offset offset) = Translate;
}
