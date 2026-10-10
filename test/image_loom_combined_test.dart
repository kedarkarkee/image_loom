import 'dart:ui';

import 'package:flutter/painting.dart' show EdgeInsets, MatrixUtils;
import 'package:flutter_test/flutter_test.dart';
import 'package:image_loom/image_loom.dart';

const src = Size(400, 200);

const red = Offset(100, 50);
const green = Offset(300, 50);
const blue = Offset(100, 150);
const yellow = Offset(300, 150);

final loom = ImageLoom.withSize('x.jpg', src);

GeometryState plan(List<ImageOperation> ops) => loom.plan(ops);

void expectMaps(GeometryState s, Offset from, Offset to) {
  final p = MatrixUtils.transformPoint(s.matrix, from);
  expect(p.dx, closeTo(to.dx, 1e-6), reason: 'x for $from');
  expect(p.dy, closeTo(to.dy, 1e-6), reason: 'y for $from');
}

void expectSize(GeometryState s, Size expected, {double tol = 1e-6}) {
  expect(s.size.width, closeTo(expected.width, tol), reason: 'width');
  expect(s.size.height, closeTo(expected.height, tol), reason: 'height');
}

void expectAffine(GeometryState s, List<double> expected) {
  final a = s.toAffine();
  for (var i = 0; i < 6; i++) {
    expect(a[i], closeTo(expected[i], 1e-9), reason: 'affine[$i]');
  }
}

/// Same size and same six affine values.
void expectSame(GeometryState a, GeometryState b) {
  expectSize(a, b.size);
  expectAffine(a, b.toAffine());
}

void expectCornersFit(GeometryState s, {double tol = 1e-5}) {
  final corners = [
    Offset.zero,
    Offset(src.width, 0),
    Offset(src.width, src.height),
    Offset(0, src.height),
  ].map((p) => MatrixUtils.transformPoint(s.matrix, p)).toList();

  final minX = corners.map((p) => p.dx).reduce((a, b) => a < b ? a : b);
  final minY = corners.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
  final maxX = corners.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
  final maxY = corners.map((p) => p.dy).reduce((a, b) => a > b ? a : b);

  expect(minX, closeTo(0, tol));
  expect(minY, closeTo(0, tol));
  expect(maxX, closeTo(s.size.width, tol));
  expect(maxY, closeTo(s.size.height, tol));
}

void main() {
  group('rotate and flip', () {
    test('flip h then rotate 90', () {
      final s = plan([const Flip(horizontal: true), const Rotate(90)]);
      expectSize(s, const Size(200, 400));
      expectMaps(s, red, const Offset(150, 300));
      expectMaps(s, green, const Offset(150, 100));
      expectMaps(s, blue, const Offset(50, 300));
      expectMaps(s, yellow, const Offset(50, 100));
    });

    test('rotate 90 then flip h', () {
      final s = plan([const Rotate(90), const Flip(horizontal: true)]);
      expectSize(s, const Size(200, 400));
      expectMaps(s, red, const Offset(50, 100));
      expectMaps(s, green, const Offset(50, 300));
      expectMaps(s, blue, const Offset(150, 100));
      expectMaps(s, yellow, const Offset(150, 300));
    });

    test('order matters: the two lists above differ', () {
      final a = plan([const Flip(horizontal: true), const Rotate(90)]);
      final b = plan([const Rotate(90), const Flip(horizontal: true)]);
      expect(a.toAffine(), isNot(b.toAffine()));
    });

    test('flip h + flip v equals rotate 180', () {
      final s = plan([
        const Flip(horizontal: true),
        const Flip(vertical: true),
      ]);
      expectAffine(s, [-1, 0, 0, -1, 400, 200]);
      expectSame(s, plan([const Rotate(180)]));
    });

    test('rotate 90 twice equals rotate 180', () {
      final s = plan([const Rotate(90), const Rotate(90)]);
      expectSize(s, src);
      expectSame(s, plan([const Rotate(180)]));
    });

    test('rotate 90 then rotate 270 is identity', () {
      final s = plan([const Rotate(90), const Rotate(270)]);
      expectSize(s, src);
      expectAffine(s, [1, 0, 0, 1, 0, 0]);
    });

    test('rotate 90 then flip h equals Transpose', () {
      final s = plan([const Rotate(90), const Flip(horizontal: true)]);
      expectAffine(s, [0, 1, 1, 0, 0, 0]); // (x, y) -> (y, x)
      expectSame(s, plan([const Transpose()]));
    });

    test('flip h then rotate 90 equals Transverse', () {
      final s = plan([const Flip(horizontal: true), const Rotate(90)]);
      expectAffine(s, [0, -1, -1, 0, 200, 400]); // (x, y) -> (200 - y, 400 - x)
      expectSame(s, plan([const Transverse()]));
    });
  });

  group('crop combined with other operations', () {
    test('rotate 90 then crop the top square', () {
      final s = plan([
        const Rotate(90),
        Crop(const Rect.fromLTWH(0, 0, 200, 200)),
      ]);
      expectSize(s, const Size(200, 200));
      expectMaps(s, blue, const Offset(50, 100));
      expectMaps(s, red, const Offset(150, 100));
    });

    test('rotate 90 then crop the bottom square', () {
      final s = plan([
        const Rotate(90),
        Crop(const Rect.fromLTWH(0, 200, 200, 200)),
      ]);
      expectSize(s, const Size(200, 200));
      expectMaps(s, yellow, const Offset(50, 100));
      expectMaps(s, green, const Offset(150, 100));
    });

    test('crop then rotate 90', () {
      final s = plan([
        Crop(const Rect.fromLTWH(200, 0, 200, 100)),
        const Rotate(90),
      ]);
      expectSize(s, const Size(100, 200));
      expectMaps(s, green, const Offset(50, 100));
    });

    test('order changes the result size', () {
      const rect = Rect.fromLTWH(0, 0, 200, 100);
      final cropFirst = plan([Crop(rect), const Rotate(90)]);
      final rotateFirst = plan([const Rotate(90), Crop(rect)]);
      expectSize(cropFirst, const Size(100, 200));
      expectSize(rotateFirst, const Size(200, 100));
      expectMaps(cropFirst, red, const Offset(50, 100));
    });

    test('two crops compose into one shift', () {
      final s = plan([
        Crop(const Rect.fromLTWH(100, 50, 200, 100)),
        Crop(const Rect.fromLTWH(50, 25, 100, 50)),
      ]);
      expectSize(s, const Size(100, 50));
      expectAffine(s, [1, 0, 0, 1, -150, -75]);
      expectMaps(s, const Offset(150, 75), Offset.zero);
      expectMaps(s, const Offset(250, 125), const Offset(100, 50));
    });

    test('a crop uses the coordinates of the current canvas', () {
      // After Rotate(90) the canvas is 200x400, so y = 300 exists.
      final s = plan([
        const Rotate(90),
        Crop(const Rect.fromLTWH(0, 300, 200, 100)),
      ]);
      expectSize(s, const Size(200, 100));
      expectMaps(s, yellow, const Offset(50, 0));
      // The same rect on the unrotated 400x200 canvas is outside the image.
      expect(
        () => plan([Crop(const Rect.fromLTWH(0, 300, 200, 100))]),
        throwsArgumentError,
      );
    });

    test('second crop outside the first crop throws', () {
      expect(
        () => plan([
          Crop(const Rect.fromLTWH(0, 0, 100, 100)),
          Crop(const Rect.fromLTWH(200, 200, 10, 10)),
        ]),
        throwsArgumentError,
      );
    });

    test('flip h then crop left half equals crop right half then flip h', () {
      final a = plan([
        const Flip(horizontal: true),
        Crop(const Rect.fromLTWH(0, 0, 200, 100)),
      ]);
      final b = plan([
        Crop(const Rect.fromLTWH(200, 0, 200, 100)),
        const Flip(horizontal: true),
      ]);
      expectAffine(a, [-1, 0, 0, 1, 400, 0]);
      expectSame(a, b);
      expectMaps(a, green, const Offset(100, 50));
    });

    test('fractional crop preserves exact dimensions and offsets', () {
      const rect = Rect.fromLTWH(10.5, 20.25, 100.5, 50.25);
      final s = plan([Crop(rect)]);

      expectSize(s, const Size(100.5, 50.25));
      expectMaps(s, const Offset(10.5, 20.25), Offset.zero);
      expectMaps(s, const Offset(111, 70.5), const Offset(100.5, 50.25));
    });

    test('fractional crops compose without losing precision', () {
      final s = plan([
        Crop(const Rect.fromLTWH(10.25, 5.5, 300.5, 150.25)),
        Crop(const Rect.fromLTWH(0.5, 0.25, 100.25, 50.5)),
      ]);

      expectSize(s, const Size(100.25, 50.5));
      expectMaps(s, const Offset(10.75, 5.75), Offset.zero);
      expectMaps(s, const Offset(111, 56.25), const Offset(100.25, 50.5));
    });
  });

  group('scale, resize and pad combined', () {
    test('resize then crop equals crop then resize', () {
      final a = plan([
        const Resize(Size(200, 100)),
        Crop(const Rect.fromLTWH(100, 0, 100, 50)),
      ]);
      final b = plan([
        Crop(const Rect.fromLTWH(200, 0, 200, 100)),
        const Resize(Size(100, 50)),
      ]);
      expectSize(a, const Size(100, 50));
      expectAffine(a, [0.5, 0, 0, 0.5, -100, 0]);
      expectSame(a, b);
      expectMaps(a, green, const Offset(50, 25));
    });

    test('flip and resize commute', () {
      final a = plan([
        const Flip(horizontal: true),
        const Resize(Size(200, 100)),
      ]);
      final b = plan([
        const Resize(Size(200, 100)),
        const Flip(horizontal: true),
      ]);
      expectAffine(a, [-0.5, 0, 0, 0.5, 200, 0]);
      expectSame(a, b);
    });

    test('scale 0.5 then rotate 90', () {
      final s = plan([const Scale(0.5), const Rotate(90)]);
      expectSize(s, const Size(100, 200));
      expectMaps(s, yellow, const Offset(25, 150));
      expectMaps(s, green, const Offset(75, 150));
    });

    test('Fit contain then CropToAspect 1:1', () {
      final s = plan([const ScaleToFit(Size(100, 100)), const CropToAspect(1)]);
      expectSize(s, const Size(50, 50));
      expectMaps(
        s,
        const Offset(200, 100),
        const Offset(25, 25),
      ); // image center
    });

    test('Fit cover then CropToAspect 1:1 makes a square thumbnail', () {
      final s = plan([
        const ScaleToFit(Size(100, 100), cover: true),
        const CropToAspect(1),
      ]);
      expectSize(s, const Size(100, 100));
      expectMaps(s, const Offset(200, 100), const Offset(50, 50));
      expectMaps(s, red, const Offset(0, 25)); // left edge of the square
      expectMaps(s, green, const Offset(100, 25)); // right edge of the square
    });

    test('uniform pad and rotate commute', () {
      final a = plan([const Pad(EdgeInsets.all(10)), const Rotate(90)]);
      final b = plan([const Rotate(90), const Pad(EdgeInsets.all(10))]);
      expectSize(a, const Size(220, 420));
      expectMaps(a, red, const Offset(160, 110));
      expectSame(a, b);
    });

    test('uneven pad and rotate do not commute', () {
      const pad = Pad(EdgeInsets.fromLTRB(10, 20, 30, 40));
      final padFirst = plan([pad, const Rotate(90)]);
      final rotateFirst = plan([const Rotate(90), pad]);
      expectSize(padFirst, const Size(260, 440));
      expectSize(rotateFirst, const Size(240, 460));
    });

    test('pad then crop of the original area undoes the pad', () {
      final s = plan([
        const Pad(EdgeInsets.all(10)),
        Crop(const Rect.fromLTWH(10, 10, 400, 200)),
      ]);
      expectSize(s, src);
      expectAffine(s, [1, 0, 0, 1, 0, 0]);
    });
  });

  group('free angles combined', () {
    test('rotate 45 then a centered 100x100 crop', () {
      final r = plan([const Rotate(45)]);
      final center = Offset(r.size.width / 2, r.size.height / 2);
      final s = plan([
        const Rotate(45),
        Crop(Rect.fromCenter(center: center, width: 100, height: 100)),
      ]);
      expectSize(s, const Size(100, 100));
      expectMaps(s, const Offset(200, 100), const Offset(50, 50));
    });

    test(
      'straighten then CropToAspect keeps the image center at the center',
      () {
        final s = plan([const Rotate(10), const CropToAspect(1)]);
        expect(s.size.width, closeTo(s.size.height, 1e-9));
        expectMaps(
          s,
          const Offset(200, 100),
          Offset(s.size.width / 2, s.size.height / 2),
        );
      },
    );
  });

  group('longer chains', () {
    test('flip h, rotate 90, crop top square, resize to 100x100', () {
      final s = plan([
        const Flip(horizontal: true),
        const Rotate(90),
        Crop(const Rect.fromLTWH(0, 0, 200, 200)),
        const Resize(Size(100, 100)),
      ]);
      expectSize(s, const Size(100, 100));
      expectMaps(s, green, const Offset(75, 50));
      expectMaps(s, yellow, const Offset(25, 50));
    });

    test('chains that cancel out give the identity', () {
      final chains = <List<ImageOperation>>[
        [
          const Rotate(90),
          const Flip(horizontal: true),
          const Flip(horizontal: true),
          const Rotate(270),
        ],
        [const Resize(Size(800, 400)), const Resize(Size(400, 200))],
        [const Translate(Offset(10, 20)), const Translate(Offset(-10, -20))],
        [const Transpose(), const Transpose()],
        [const Transverse(), const Transverse()],
      ];
      for (final ops in chains) {
        final s = plan(ops);
        expectSize(s, src);
        expectAffine(s, [1, 0, 0, 1, 0, 0]);
      }
    });
  });

  group('inverse operations', () {
    test('quarter turn then its inverse is the identity', () {
      final s = plan([const Rotate(90), const Rotate(-90)]);
      expectSame(s, plan([]));

      // This test is not valid for arbitrary values as
      // Quarter turns work because their bounding box is exactly the swapped size,
      // so Rotate(90) followed by Rotate(270) does return to 400×200.
      // A free angle can’t, because the enlarged canvas has no way to shrink back.
      //
      // For e.g.
      // Rotate(37.25) grows the canvas from 400×200 to its bounding box.
      // Rotate(-37.25) then rotates that bigger canvas and takes a new,
      // even larger bounding box
    });

    test('scale by fractional factor then inverse', () {
      final s = plan([const Scale(0.25), const Scale(4)]);

      expectSame(s, plan([]));
    });

    test('translate fractional offset then inverse', () {
      final s = plan([
        const Translate(Offset(12.75, -23.5)),
        const Translate(Offset(-12.75, 23.5)),
      ]);

      expectSame(s, plan([]));
    });

    test('resize up then resize back down', () {
      final s = plan([
        const Resize(Size(800, 400)),
        const Resize(Size(400, 200)),
      ]);

      expectSame(s, plan([]));
    });

    test('horizontal and vertical flips cancel independently', () {
      final s = plan([
        const Flip(horizontal: true),
        const Flip(vertical: true),
        const Flip(horizontal: true),
        const Flip(vertical: true),
      ]);

      expectSame(s, plan([]));
    });
  });

  group('geometry invariants across many values', () {
    test('rotated corners always fit the output bounds', () {
      for (var i = -24; i <= 48; i++) {
        final angle = i * 7.3;
        final s = plan([Rotate(angle)]);

        expectCornersFit(s);
        expect(s.size.width, greaterThan(0));
        expect(s.size.height, greaterThan(0));
      }
    });

    test('skewed corners always fit the output bounds', () {
      for (var i = -6; i <= 6; i++) {
        for (var j = -5; j <= 5; j++) {
          final s = plan([Skew(xDegrees: i * 7.0, yDegrees: j * 6.0)]);

          expectCornersFit(s);
          expect(s.size.width, greaterThan(0));
          expect(s.size.height, greaterThan(0));
        }
      }
    });
  });

  group('numerical stability', () {
    test('large rotation angles produce finite geometry', () {
      for (final angle in [-1000000000.0, -100000.0, 100000.0, 1000000000.0]) {
        final s = plan([Rotate(angle)]);

        expect(s.size.width.isFinite, isTrue, reason: '$angle width');
        expect(s.size.height.isFinite, isTrue, reason: '$angle height');
        expect(
          s.toAffine().every((v) => v.isFinite),
          isTrue,
          reason: '$angle affine matrix',
        );
      }
    });

    test('very small and large positive scales stay finite', () {
      for (final factor in [1e-9, 1e-6, 1e6, 1e9]) {
        final s = plan([Scale(factor)]);

        expect(s.size.width.isFinite, isTrue);
        expect(s.size.height.isFinite, isTrue);
        expect(s.size.width, greaterThan(0));
        expect(s.size.height, greaterThan(0));
        expect(s.toAffine().every((v) => v.isFinite), isTrue);
      }
    });

    test('skew near 90 degrees stays finite', () {
      final s = plan([const Skew(xDegrees: 89.999)]);

      expect(s.size.width.isFinite, isTrue);
      expect(s.size.height.isFinite, isTrue);
      expect(s.toAffine().every((v) => v.isFinite), isTrue);
    });
  });

  group('additional composition invariants', () {
    test('transpose then transverse equals a 180 degree rotation', () {
      final s = plan([const Transpose(), const Transverse()]);

      expectSame(s, plan([const Rotate(180)]));
    });

    test('uniform scale and rotation preserve operation composition', () {
      final a = plan([const Scale(2), const Rotate(90)]);

      final b = plan([const Rotate(90), const Scale(2)]);

      expectSame(a, b);
    });

    test('center remains centered after rotation and aspect crop', () {
      final s = plan([const Rotate(37.5), const CropToAspect(1)]);

      expect(s.size.width, closeTo(s.size.height, 1e-6));
      expectMaps(
        s,
        const Offset(200, 100),
        Offset(s.size.width / 2, s.size.height / 2),
      );
    });

    test('scale and inverse scale restore arbitrary source points', () {
      final s = plan([const Scale(3.5), const Scale(1 / 3.5)]);

      expectSame(s, plan([]));
      expectMaps(s, red, red);
      expectMaps(s, green, green);
      expectMaps(s, blue, blue);
      expectMaps(s, yellow, yellow);
    });
  });
}
