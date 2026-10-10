import 'dart:ui';

import 'package:flutter/painting.dart' show Alignment, EdgeInsets, MatrixUtils;
import 'package:flutter_test/flutter_test.dart';
import 'package:image_loom/image_loom.dart';

const src = Size(400, 200);

// Quadrant centers of the source image
const red = Offset(100, 50);
const green = Offset(300, 50);
const blue = Offset(100, 150);
const yellow = Offset(300, 150);

final loom = ImageLoom.withSize('x.jpg', src);

GeometryState plan(ImageOperation op) => loom.planOne(op);

void expectMaps(GeometryState s, Offset from, Offset to) {
  final p = MatrixUtils.transformPoint(s.matrix, from);
  expect(p.dx, closeTo(to.dx, 1e-6), reason: 'x for $from');
  expect(p.dy, closeTo(to.dy, 1e-6), reason: 'y for $from');
}

void expectSize(GeometryState s, Size expected, {double tol = 1e-6}) {
  expect(s.size.width, closeTo(expected.width, tol), reason: 'width');
  expect(s.size.height, closeTo(expected.height, tol), reason: 'height');
}

/// Bounding box of the four source corners after the transform.
Rect cornerBounds(GeometryState s) {
  final pts = [
    Offset.zero,
    Offset(src.width, 0),
    Offset(src.width, src.height),
    Offset(0, src.height),
  ].map((p) => MatrixUtils.transformPoint(s.matrix, p));
  final xs = pts.map((p) => p.dx), ys = pts.map((p) => p.dy);
  return Rect.fromLTRB(
    xs.reduce((a, b) => a < b ? a : b),
    ys.reduce((a, b) => a < b ? a : b),
    xs.reduce((a, b) => a > b ? a : b),
    ys.reduce((a, b) => a > b ? a : b),
  );
}

void main() {
  group('no operations', () {
    test('identity', () {
      final s = loom.plan([]);
      expectSize(s, src);
      expectMaps(s, red, red);
      expectMaps(s, yellow, yellow);
    });

    test('planOne matches plan with a one item list', () {
      final a = loom.planOne(const Rotate(90));
      final b = loom.plan([const Rotate(90)]);
      expectSize(a, b.size);
      expect(a.toAffine(), b.toAffine());
    });
  });

  group('Flip', () {
    test('horizontal', () {
      final s = plan(const Flip(horizontal: true));
      expectSize(s, src);
      expectMaps(s, red, green);
      expectMaps(s, green, red);
      expectMaps(s, blue, yellow);
      expectMaps(s, yellow, blue);
    });

    test('vertical', () {
      final s = plan(const Flip(vertical: true));
      expectSize(s, src);
      expectMaps(s, red, blue);
      expectMaps(s, blue, red);
      expectMaps(s, green, yellow);
      expectMaps(s, yellow, green);
    });

    test('both axes equals a 180 turn', () {
      final s = plan(const Flip(horizontal: true, vertical: true));
      expectSize(s, src);
      expectMaps(s, red, yellow);
      expectMaps(s, green, blue);
    });

    test('no axis is identity', () {
      final s = plan(const Flip());
      expectMaps(s, red, red);
    });

    test('flipping twice is identity', () {
      final s = loom.plan([
        const Flip(horizontal: true),
        const Flip(horizontal: true),
      ]);
      expectMaps(s, red, red);
      expectMaps(s, yellow, yellow);
    });
  });

  group('Rotate', () {
    test('0 is identity', () {
      final s = plan(const Rotate(0));
      expectSize(s, src);
      expectMaps(s, red, red);
    });

    test('90 clockwise', () {
      final s = plan(const Rotate(90));
      expectSize(s, const Size(200, 400));
      expectMaps(s, red, const Offset(150, 100));
      expectMaps(s, green, const Offset(150, 300));
      expectMaps(s, blue, const Offset(50, 100));
      expectMaps(s, yellow, const Offset(50, 300));
    });

    test('180', () {
      final s = plan(const Rotate(180));
      expectSize(s, src);
      expectMaps(s, red, const Offset(300, 150));
      expectMaps(s, green, const Offset(100, 150));
      expectMaps(s, blue, const Offset(300, 50));
      expectMaps(s, yellow, const Offset(100, 50));
    });

    test('270 clockwise', () {
      final s = plan(const Rotate(270));
      expectSize(s, const Size(200, 400));
      expectMaps(s, red, const Offset(50, 300));
      expectMaps(s, green, const Offset(50, 100));
      expectMaps(s, blue, const Offset(150, 300));
      expectMaps(s, yellow, const Offset(150, 100));
    });

    test('-90 equals 270', () {
      final s = plan(const Rotate(-90));
      expectSize(s, const Size(200, 400));
      expectMaps(s, red, const Offset(50, 300));
    });

    test('360 returns to the original size with exact numbers', () {
      final s = plan(const Rotate(360));
      expect(s.size, src); // exact, no float noise
      expectMaps(s, red, red);
    });

    test('30 degrees: size and center', () {
      final s = plan(const Rotate(30));
      expectSize(s, const Size(446.410, 373.205), tol: 1e-3);
      expectMaps(
        s,
        const Offset(200, 100),
        Offset(s.size.width / 2, s.size.height / 2),
      );
    });

    test('rotated corners touch the canvas bounds for any angle', () {
      for (final deg in [15.0, 30.0, 45.0, 77.0, 123.0, 200.0, -40.0]) {
        final s = plan(Rotate(deg));
        final b = cornerBounds(s);
        expect(b.left, closeTo(0, 1e-6), reason: '$deg left');
        expect(b.top, closeTo(0, 1e-6), reason: '$deg top');
        expect(b.right, closeTo(s.size.width, 1e-6), reason: '$deg right');
        expect(b.bottom, closeTo(s.size.height, 1e-6), reason: '$deg bottom');
      }
    });

    test('four 90 degree turns return to identity', () {
      final s = loom.plan(List.filled(4, const Rotate(90)));
      expect(s.size, src);
      expectMaps(s, red, red);
      expectMaps(s, yellow, yellow);
    });

    test('negative 90 equals positive 270', () {
      final negative = plan(const Rotate(-90));
      final positive = plan(const Rotate(270));

      expect(negative.size, positive.size);
      expect(negative.toAffine(), positive.toAffine());
    });

    test('360 preserves exact dimensions and identity matrix', () {
      final s = plan(const Rotate(360));

      expect(s.size, src);
      expect(s.toAffine(), [1, 0, 0, 1, 0, 0]);
    });
  });

  group('Crop', () {
    test('top-right quadrant', () {
      final s = plan(Crop(const Rect.fromLTWH(200, 0, 200, 100)));
      expectSize(s, const Size(200, 100));
      expectMaps(s, green, const Offset(100, 50));
      expectMaps(s, const Offset(200, 0), Offset.zero);
    });

    test('full image is identity', () {
      final s = plan(Crop(Offset.zero & src));
      expectSize(s, src);
      expectMaps(s, red, red);
    });

    test('rect partly outside is clipped to the canvas', () {
      final s = plan(Crop(const Rect.fromLTWH(300, 100, 200, 200)));
      expectSize(s, const Size(100, 100));
      expectMaps(s, const Offset(300, 100), Offset.zero);
      expectMaps(s, yellow, const Offset(0, 50));
    });

    test('rect completely outside throws', () {
      expect(
        () => plan(Crop(const Rect.fromLTWH(500, 500, 10, 10))),
        throwsArgumentError,
      );
    });

    test('empty rect throws', () {
      expect(() => plan(Crop(Rect.zero)), throwsArgumentError);
    });

    test('partially out-of-bounds crop is clipped correctly', () {
      final s = plan(const Crop(Rect.fromLTWH(300, 100, 200, 200)));

      expectSize(s, const Size(100, 100));
      expectMaps(s, const Offset(300, 100), Offset.zero);
      expectMaps(s, yellow, const Offset(0, 50));
    });

    test('crop extending beyond right edge is clipped', () {
      final s = plan(const Crop(Rect.fromLTWH(350, 0, 100, 100)));

      expectSize(s, const Size(50, 100));
      expectMaps(s, const Offset(350, 0), Offset.zero);
      expectMaps(s, const Offset(400, 100), const Offset(50, 100));
    });

    test('completely outside crop throws ArgumentError', () {
      expect(
        () => plan(const Crop(Rect.fromLTWH(500, 500, 10, 10))),
        throwsArgumentError,
      );
    });
  });

  group('Resize', () {
    test('half size', () {
      final s = plan(const Resize(Size(200, 100)));
      expectSize(s, const Size(200, 100));
      expectMaps(s, red, const Offset(50, 25));
      expectMaps(s, yellow, const Offset(150, 75));
    });

    test('non-uniform', () {
      final s = plan(const Resize(Size(800, 100)));
      expectSize(s, const Size(800, 100));
      expectMaps(s, green, const Offset(600, 25));
    });

    test('empty target throws', () {
      expect(() => plan(const Resize(Size.zero)), throwsArgumentError);
    });
  });

  group('Scale', () {
    test('0.5', () {
      final s = plan(const Scale(0.5));
      expectSize(s, const Size(200, 100));
      expectMaps(s, yellow, const Offset(150, 75));
    });

    test('2', () {
      final s = plan(const Scale(2));
      expectSize(s, const Size(800, 400));
      expectMaps(s, red, const Offset(200, 100));
    });

    test('zero or negative throws', () {
      expect(() => plan(const Scale(0)), throwsArgumentError);
      expect(() => plan(const Scale(-1)), throwsArgumentError);
    });
  });

  group('Translate', () {
    test('positive offset keeps size and moves content', () {
      final s = plan(const Translate(Offset(10, 20)));
      expectSize(s, src);
      expectMaps(s, red, const Offset(110, 70));
    });

    test('negative offset', () {
      final s = plan(const Translate(Offset(-100, -50)));
      expectSize(s, src);
      expectMaps(s, red, Offset.zero);
    });
  });

  group('Pad', () {
    test('uniform', () {
      final s = plan(const Pad(EdgeInsets.all(10)));
      expectSize(s, const Size(420, 220));
      expectMaps(s, red, const Offset(110, 60));
    });

    test('different sides', () {
      final s = plan(const Pad(EdgeInsets.fromLTRB(10, 20, 30, 40)));
      expectSize(s, const Size(440, 260));
      expectMaps(s, red, const Offset(110, 70));
    });

    test('zero padding is identity', () {
      final s = plan(const Pad(EdgeInsets.zero));
      expectSize(s, src);
      expectMaps(s, red, red);
    });
  });

  group('Skew', () {
    test('no skew is identity', () {
      final s = plan(const Skew());
      expectSize(s, src);
      expectMaps(s, red, red);
    });

    test('x +45: x grows by y', () {
      final s = plan(const Skew(xDegrees: 45));
      expectSize(s, const Size(600, 200), tol: 1e-6);
      expectMaps(s, red, const Offset(150, 50));
      expectMaps(s, blue, const Offset(250, 150));
      expectMaps(s, green, const Offset(350, 50));
    });

    test('x -45: shifted so nothing is negative', () {
      final s = plan(const Skew(xDegrees: -45));
      expectSize(s, const Size(600, 200), tol: 1e-6);
      expectMaps(s, red, const Offset(250, 50));
      expectMaps(s, blue, const Offset(150, 150));
      final b = cornerBounds(s);
      expect(b.left, closeTo(0, 1e-6));
      expect(b.right, closeTo(600, 1e-6));
    });

    test('y +45: y grows by x', () {
      final s = plan(const Skew(yDegrees: 45));
      expectSize(s, const Size(400, 600), tol: 1e-6);
      expectMaps(s, red, const Offset(100, 150));
      expectMaps(s, green, const Offset(300, 350));
    });

    test('skewed corners touch the canvas bounds', () {
      for (final op in const [
        Skew(xDegrees: 20),
        Skew(xDegrees: -20),
        Skew(yDegrees: 30),
        Skew(yDegrees: -30),
        Skew(xDegrees: 15, yDegrees: -25),
      ]) {
        final s = plan(op);
        final b = cornerBounds(s);
        expect(b.left, closeTo(0, 1e-6));
        expect(b.top, closeTo(0, 1e-6));
        expect(b.right, closeTo(s.size.width, 1e-6));
        expect(b.bottom, closeTo(s.size.height, 1e-6));
      }
    });

    test('negative x skew shifts content into non-negative bounds', () {
      final s = plan(const Skew(xDegrees: -45));

      expectSize(s, const Size(600, 200));
      expectMaps(s, red, const Offset(250, 50));
      expectMaps(s, blue, const Offset(150, 150));

      final b = cornerBounds(s);
      expect(b.left, closeTo(0, 1e-6));
      expect(b.top, closeTo(0, 1e-6));
      expect(b.right, closeTo(s.size.width, 1e-6));
      expect(b.bottom, closeTo(s.size.height, 1e-6));
    });

    test('combined skew keeps all corners within output bounds', () {
      final s = plan(const Skew(xDegrees: 15, yDegrees: -25));

      final b = cornerBounds(s);

      expect(b.left, closeTo(0, 1e-6));
      expect(b.top, closeTo(0, 1e-6));
      expect(b.right, closeTo(s.size.width, 1e-6));
      expect(b.bottom, closeTo(s.size.height, 1e-6));
    });
  });

  group('CropToAspect', () {
    test('1:1 centered', () {
      final s = plan(const CropToAspect(1));
      expectSize(s, const Size(200, 200));
      expectMaps(s, const Offset(100, 100), const Offset(0, 100));
      expectMaps(s, const Offset(300, 200), const Offset(200, 200));
    });

    test('1:1 aligned top-left', () {
      final s = plan(const CropToAspect(1, alignment: Alignment.topLeft));
      expectSize(s, const Size(200, 200));
      expectMaps(s, red, red);
    });

    test('1:1 aligned center-right', () {
      final s = plan(const CropToAspect(1, alignment: Alignment.centerRight));
      expectSize(s, const Size(200, 200));
      expectMaps(s, green, const Offset(100, 50));
    });

    test('same aspect as the image is identity', () {
      final s = plan(const CropToAspect(2));
      expectSize(s, src);
      expectMaps(s, red, red);
    });

    test('tall 1:2', () {
      final s = plan(const CropToAspect(0.5));
      expectSize(s, const Size(100, 200));
      expectMaps(s, const Offset(150, 0), Offset.zero);
    });

    test('wide 4:1', () {
      final s = plan(const CropToAspect(4));
      expectSize(s, const Size(400, 100));
      expectMaps(s, red, const Offset(100, 0));
    });
  });

  group('Fit', () {
    test('contain downscales to fit inside the box', () {
      final s = plan(const ScaleToFit(Size(100, 100)));
      expectSize(s, const Size(100, 50));
      expectMaps(s, yellow, const Offset(75, 37.5));
    });

    test('cover scales so the box is fully covered (no crop)', () {
      final s = plan(const ScaleToFit(Size(100, 100), cover: true));
      expectSize(s, const Size(200, 100));
    });

    test('contain also upscales', () {
      final s = plan(const ScaleToFit(Size(800, 800)));
      expectSize(s, const Size(800, 400));
    });

    test('cover upscales', () {
      final s = plan(const ScaleToFit(Size(800, 800), cover: true));
      expectSize(s, const Size(1600, 800));
    });

    test('keeps the aspect ratio', () {
      final s = plan(const ScaleToFit(Size(333, 111)));
      expect(s.size.width / s.size.height, closeTo(2, 1e-9));
    });

    test('contain fits inside target without changing aspect ratio', () {
      const target = Size(100, 100);
      final s = plan(const ScaleToFit(target));

      expectSize(s, const Size(100, 50));
      expect(s.size.width, lessThanOrEqualTo(target.width));
      expect(s.size.height, lessThanOrEqualTo(target.height));
      expect(s.size.width / s.size.height, closeTo(2, 1e-9));
    });

    test('cover fills target but can exceed its dimensions', () {
      const target = Size(100, 100);
      final s = plan(const ScaleToFit(target, cover: true));

      expectSize(s, const Size(200, 100));
      expect(s.size.width, greaterThanOrEqualTo(target.width));
      expect(s.size.height, greaterThanOrEqualTo(target.height));
      expect(s.size.width / s.size.height, closeTo(2, 1e-9));
    });

    test('cover does not crop the transformed image', () {
      final s = plan(const ScaleToFit(Size(100, 100), cover: true));

      expectMaps(s, Offset.zero, Offset.zero);
      expectMaps(s, const Offset(400, 200), const Offset(200, 100));
    });
  });

  group('Transpose', () {
    test('mirrors over the main diagonal: (x, y) -> (y, x)', () {
      final s = plan(const Transpose());
      expectSize(s, const Size(200, 400));
      expectMaps(s, red, const Offset(50, 100));
      expectMaps(s, green, const Offset(50, 300));
      expectMaps(s, blue, const Offset(150, 100));
      expectMaps(s, yellow, const Offset(150, 300));
    });

    test('applying twice returns to identity', () {
      final s = loom.plan([const Transpose(), const Transpose()]);
      expectSize(s, src);
      expectMaps(s, red, red);
      expectMaps(s, yellow, yellow);
    });
  });

  group('Transverse', () {
    test('mirrors over the anti-diagonal: (x, y) -> (H - y, W - x)', () {
      final s = plan(const Transverse());
      expectSize(s, const Size(200, 400));
      expectMaps(s, red, const Offset(150, 300));
      expectMaps(s, green, const Offset(150, 100));
      expectMaps(s, blue, const Offset(50, 300));
      expectMaps(s, yellow, const Offset(50, 100));
    });

    test('applying twice returns to identity', () {
      final s = loom.plan([const Transverse(), const Transverse()]);
      expectSize(s, src);
      expectMaps(s, red, red);
    });
  });

  group('toAffine', () {
    test('identity', () {
      expect(loom.plan([]).toAffine(), [1, 0, 0, 1, 0, 0]);
    });

    test('translation puts tx and ty last', () {
      expect(plan(const Translate(Offset(10, 20))).toAffine(), [
        1,
        0,
        0,
        1,
        10,
        20,
      ]);
    });

    test('rotate 90 on 400x200: x\' = 200 - y, y\' = x', () {
      final a = plan(const Rotate(90)).toAffine();
      const expected = [0.0, 1.0, -1.0, 0.0, 200.0, 0.0]; // a, b, c, d, tx, ty
      for (var i = 0; i < 6; i++) {
        expect(a[i], closeTo(expected[i], 1e-9), reason: 'index $i');
      }
    });

    test('resize puts scale in a and d', () {
      expect(plan(const Resize(Size(200, 100))).toAffine(), [
        0.5,
        0,
        0,
        0.5,
        0,
        0,
      ]);
    });
  });
}
