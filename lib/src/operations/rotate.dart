part of '../image_operation.dart';

/// Rotates clockwise. The canvas grows to the bounding box of the rotated image.
class Rotate extends ImageOperation {
  const Rotate(this.degrees);

  final double degrees;

  @override
  GeometryState apply(GeometryState s) {
    final angle = degrees % 360;
    final r = angle * math.pi / 180;

    var c = math.cos(r), sn = math.sin(r);

    final isQuarterTurn = angle % 90 == 0;

    if (isQuarterTurn) {
      // Snap so quarter turns are exact in both the size and the matrix.
      c = c.roundToDouble();
      sn = sn.roundToDouble();
    }
    final w = s.size.width, h = s.size.height;

    final nw = isQuarterTurn
        ? (c.abs() == 1 ? w : h)
        : w * c.abs() + h * sn.abs();

    final nh = isQuarterTurn
        ? (c.abs() == 1 ? h : w)
        : w * sn.abs() + h * c.abs();

    final rotation = Matrix4(c, sn, 0, 0, -sn, c, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1);

    final op =
        Matrix4.translationValues(nw / 2, nh / 2, 0) *
        rotation *
        Matrix4.translationValues(-w / 2, -h / 2, 0);

    return s.transformed(op, size: Size(nw, nh));
  }
}
