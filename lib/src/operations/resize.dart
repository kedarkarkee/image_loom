part of '../image_operation.dart';

/// {@template image_operation.resize}
///
/// Scales the canvas to exactly [target].
///
/// {@endtemplate}
class Resize extends ImageOperation {
  const Resize(this.target);

  final Size target;

  @override
  GeometryState apply(GeometryState s) {
    if (target.isEmpty) throw ArgumentError('Resize target must not be empty');
    return s.transformed(
      Matrix4.diagonal3Values(
        target.width / s.size.width,
        target.height / s.size.height,
        1,
      ),
      size: target,
    );
  }
}
