part of '../image_operation.dart';

/// Grows the canvas and keeps the content in place. The new area is empty
/// (transparent for PNG, native decides the fill for formats without alpha).
class Pad extends ImageOperation {
  const Pad(this.padding);

  final EdgeInsets padding;

  @override
  GeometryState apply(GeometryState s) => s.transformed(
    Matrix4.translationValues(padding.left, padding.top, 0),
    size: Size(
      s.size.width + padding.horizontal,
      s.size.height + padding.vertical,
    ),
  );
}
