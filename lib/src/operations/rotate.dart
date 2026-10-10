part of '../image_operation.dart';

/// Rotates clockwise. The canvas grows to the bounding box of the rotated image.
class Rotate extends ImageOperation {
  const Rotate(this.degrees);

  final double degrees;

  @override
  GeometryState apply(GeometryState s) {
    final r = degrees * math.pi / 180;
    var c = math.cos(r), sn = math.sin(r);
    if (degrees % 90 == 0) {
      c = c.roundToDouble();
      sn = sn.roundToDouble();
    }
    final w = s.size.width, h = s.size.height;
    final nw = w * c.abs() + h * sn.abs();
    final nh = w * sn.abs() + h * c.abs();
    final op = Matrix4.translationValues(nw / 2, nh / 2, 0)
      ..rotateZ(r)
      ..translateByDouble(-w / 2, -h / 2, 0.0, 1.0);
    return s.transformed(op, size: Size(nw, nh));
  }
}
