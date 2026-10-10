import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_loom/image_loom_platform_interface.dart';
import 'package:image_loom/image_loom_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockImageLoomPlatform
    with MockPlatformInterfaceMixin
    implements ImageLoomPlatform {
  @override
  Future<Size> getImageSize(String path) async => Size(0, 0);
}

void main() {
  final ImageLoomPlatform initialPlatform = ImageLoomPlatform.instance;

  test('$MethodChannelImageLoom is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelImageLoom>());
  });

  //   test('getPlatformVersion', () async {
  //     ImageLoom imageLoomPlugin = ImageLoom('');
  //     MockImageLoomPlatform fakePlatform = MockImageLoomPlatform();
  //     ImageLoomPlatform.instance = fakePlatform;
  //
  //     expect(await imageLoomPlugin.size(), '42');
  //   });
}
