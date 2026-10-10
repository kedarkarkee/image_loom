import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show Alignment, EdgeInsets;
import 'package:vector_math/vector_math_64.dart' show Matrix4;

import 'geometry_state.dart';

part 'operations/crop.dart';
part 'operations/flip.dart';
part 'operations/pad.dart';
part 'operations/resize.dart';
part 'operations/rotate.dart';
part 'operations/scale.dart';
part 'operations/skew.dart';
part 'operations/translate.dart';

abstract class ImageOperation {
  const ImageOperation();

  GeometryState apply(GeometryState s);
}
