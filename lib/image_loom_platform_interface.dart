import 'dart:ui';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'image_loom_method_channel.dart';

abstract class ImageLoomPlatform extends PlatformInterface {
  /// Constructs a ImageLoomPlatform.
  ImageLoomPlatform() : super(token: _token);

  static final Object _token = Object();

  static ImageLoomPlatform _instance = MethodChannelImageLoom();

  /// The default instance of [ImageLoomPlatform] to use.
  ///
  /// Defaults to [MethodChannelImageLoom].
  static ImageLoomPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [ImageLoomPlatform] when
  /// they register themselves.
  static set instance(ImageLoomPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<Size> getImageSize(String path) async {
    throw UnimplementedError('getImageSize() has not been implemented.');
  }

  Future<String?> render({
    required String inputPath,
    required String outputPath,
    required List<double> affine,
    required int outWidth,
    required int outHeight,
    required String format,
    required int quality,
  }) async {
    throw UnimplementedError('render() has not been implemented.');
  }
}
