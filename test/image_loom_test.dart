import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_loom/image_loom.dart';

// class MockImageLoomPlatform
//     with MockPlatformInterfaceMixin
//     implements ImageLoomPlatform {
//   @override
//   Future<Size> getImageSize(String path) async => const Size(0, 0);
//
//   @override
//   Future<String> render({
//     required String inputPath,
//     required String outputPath,
//     required List<double> affine,
//     required int outWidth,
//     required int outHeight,
//     required String format,
//     required int quality,
//   }) async {
//     return inputPath;
//   }
// }

void main() {
  //   final ImageLoomPlatform initialPlatform = ImageLoomPlatform.instance;
  //
  //   test('$MethodChannelImageLoom is the default instance', () {
  //     expect(initialPlatform, isInstanceOf<MethodChannelImageLoom>());
  //   });

  test('rotate 90 then crop', () {
    final loom = ImageLoom.withSize('x.jpg', const Size(400, 200));
    final s = loom.plan([
      const Rotate(90),
      Crop(const Rect.fromLTWH(0, 0, 200, 200)),
    ]);
    expect(s.size, const Size(200, 200));
  });
}
