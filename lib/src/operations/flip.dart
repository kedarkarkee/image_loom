part of '../image_operation.dart';

/// {@template image_operation.flip}
///
/// Flips the image
///
/// {@endtemplate}
class Flip extends ImageOperation {
  const Flip({this.horizontal = false, this.vertical = false});

  final bool horizontal;
  final bool vertical;

  @override
  GeometryState apply(GeometryState s) {
    final cx = s.size.width / 2, cy = s.size.height / 2;
    final op = Matrix4.translationValues(cx, cy, 0)
      ..scaleByDouble(horizontal ? -1.0 : 1.0, vertical ? -1.0 : 1.0, 1.0, 1.0)
      ..translateByDouble(-cx, -cy, 0.0, 1.0);
    return s.transformed(op);
  }
}

/// {@template image_operation.transpose}
///
/// Mirror over the main diagonal: (x, y) -> (y, x).
///
/// {@endtemplate}
class Transpose extends ImageOperation {
  const Transpose();

  @override
  GeometryState apply(GeometryState s) {
    return const Flip(vertical: true).apply(const Rotate(270).apply(s));
  }
}

/// {@template image_operation.transverse}
///
/// Mirror over the anti-diagonal: (x, y) -> (H - y, W - x).
///
/// {@endtemplate}
class Transverse extends ImageOperation {
  const Transverse();

  @override
  GeometryState apply(GeometryState s) {
    return const Flip(vertical: true).apply(const Rotate(90).apply(s));
  }
}
