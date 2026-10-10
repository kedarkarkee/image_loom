part of '../image_operation.dart';

/// Crops to [rect], given in the coordinates of the canvas at this point
/// in the list. The part of [rect] outside the canvas is discarded.
class Crop extends ImageOperation {
  const Crop(this.rect);

  final Rect rect;

  @override
  GeometryState apply(GeometryState s) {
    final r = rect.intersect(Offset.zero & s.size);
    if (r.isEmpty) throw ArgumentError('Crop is outside the image');
    return s.transformed(
      Matrix4.translationValues(-r.left, -r.top, 0),
      size: r.size,
    );
  }
}

/// Crops the largest area with the given [aspect] (width / height).
class CropToAspect extends ImageOperation {
  const CropToAspect(this.aspect, {this.alignment = Alignment.center});

  final double aspect;
  final Alignment alignment;

  @override
  GeometryState apply(GeometryState s) {
    final w = s.size.width, h = s.size.height;
    final cw = math.min(w, h * aspect);
    final ch = cw / aspect;
    final x = (w - cw) * (alignment.x + 1) / 2;
    final y = (h - ch) * (alignment.y + 1) / 2;
    return Crop(Rect.fromLTWH(x, y, cw, ch)).apply(s);
  }
}
