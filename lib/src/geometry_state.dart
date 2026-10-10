import 'dart:ui';

import 'package:vector_math/vector_math_64.dart';

/// Maps upright source pixels to pixels on the current canvas,
/// plus the size of that canvas.
class GeometryState {
  const GeometryState(this.matrix, this.size);

  factory GeometryState.identity(Size size) =>
      GeometryState(Matrix4.identity(), size);

  /// How source points move
  ///
  /// | a  c  0  tx |     x' = a·x + c·y + tx
  ///
  /// | b  d  0  ty |     y' = b·x + d·y + ty
  ///
  /// | 0  0  1  0  |
  ///
  /// | 0  0  0  1  |
  ///
  /// For 2D image work, only six numbers matter (a, b, c, d, tx, ty).
  /// The other entries stay at their identity values.
  final Matrix4 matrix;

  /// Size of the canvas
  final Size size;

  /// Returns a new state with [op] applied after the current matrix.
  /// The canvas keeps its size unless [size] is given.
  GeometryState transformed(Matrix4 op, {Size? size}) =>
      GeometryState(op * matrix, size ?? this.size);

  /// Six affine values for native: [a, b, c, d, tx, ty]
  /// where x' = a*x + c*y + tx and y' = b*x + d*y + ty.
  List<double> toAffine() {
    final m = matrix.storage; // column-major
    return [m[0], m[1], m[4], m[5], m[12], m[13]];
  }
}
