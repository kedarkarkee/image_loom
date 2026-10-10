import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_loom/image_loom.dart';
import 'package:image_loom/image_loom_platform_interface.dart';
import 'package:image_loom/image_loom_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockImageLoomPlatform
    with MockPlatformInterfaceMixin
    implements ImageLoomPlatform {
  @override
  Future<Size> getImageSize(String path) async => const Size(400, 200);

  @override
  Future<String> render({
    required String inputPath,
    required String outputPath,
    required List<double> affine,
    required int outWidth,
    required int outHeight,
    required String format,
    required int quality,
  }) async {
    return inputPath;
  }
}

void main() {
  final ImageLoomPlatform initialPlatform = ImageLoomPlatform.instance;

  test('$MethodChannelImageLoom is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelImageLoom>());
  });

  test('rotate 90 then crop', () async {
    final loom = ImageLoom('x.jpg');
    MockImageLoomPlatform fakePlatform = MockImageLoomPlatform();
    ImageLoomPlatform.instance = fakePlatform;
    final s = await loom.plan([
      const Rotate(90),
      Crop(const Rect.fromLTWH(0, 0, 200, 200)),
    ]);
    expect(s.size, const Size(200, 200));
  });
}
