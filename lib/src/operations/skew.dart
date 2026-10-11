part of '../image_operation.dart';

/// {@template image_operation.skew}
///
/// Skew along horizontal or vertical axis
///
/// {@endtemplate}
class Skew extends ImageOperation {
  const Skew({this.xDegrees = 0, this.yDegrees = 0});

  final double xDegrees;
  final double yDegrees;

  @override
  GeometryState apply(GeometryState s) {
    final kx = math.tan(xDegrees * math.pi / 180);
    final ky = math.tan(yDegrees * math.pi / 180);
    final w = s.size.width, h = s.size.height;
    final skew = Matrix4.identity()
      ..setEntry(0, 1, kx)
      ..setEntry(1, 0, ky);
    // Shift so the result starts at (0, 0).
    final shift = Matrix4.translationValues(
      kx < 0 ? -h * kx : 0,
      ky < 0 ? -w * ky : 0,
      0,
    );
    return s.transformed(
      shift * skew,
      size: Size(w + h * kx.abs(), h + w * ky.abs()),
    );
  }
}
