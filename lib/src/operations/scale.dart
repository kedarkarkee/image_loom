part of '../image_operation.dart';

/// {@template image_operation.scale}
///
/// Scales the canvas by [factor], keeping the aspect ratio.
///
/// {@endtemplate}
class Scale extends ImageOperation {
  const Scale(this.factor);

  final double factor;

  @override
  GeometryState apply(GeometryState s) {
    if (factor <= 0) throw ArgumentError('Scale factor must be positive');
    return Resize(Size(s.size.width * factor, s.size.height * factor)).apply(s);
  }
}

/// {@template image_operation.scaleToFit}
///
/// Scales to fit inside [box] (contain) or to cover it ([cover]),
/// keeping the aspect ratio.
///
/// {@endtemplate}
class ScaleToFit extends ImageOperation {
  const ScaleToFit(this.box, {this.cover = false});

  final Size box;
  final bool cover;

  @override
  GeometryState apply(GeometryState s) {
    final fx = box.width / s.size.width, fy = box.height / s.size.height;
    return Scale(cover ? math.max(fx, fy) : math.min(fx, fy)).apply(s);
  }
}
