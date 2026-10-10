part of '../image_operation.dart';

/// Shifts the content inside the same canvas. Anything pushed outside
/// is cut off.
class Translate extends ImageOperation {
  const Translate(this.offset);

  final Offset offset;

  @override
  GeometryState apply(GeometryState s) {
    return s.transformed(Matrix4.translationValues(offset.dx, offset.dy, 0));
  }
}
