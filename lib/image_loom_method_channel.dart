import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'image_loom_platform_interface.dart';

/// An implementation of [ImageLoomPlatform] that uses method channels.
class MethodChannelImageLoom extends ImageLoomPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('image_loom');

  @override
  Future<Size> getImageSize(String path) async {
    final m = await methodChannel.invokeMapMethod<String, int>('getImageSize', {
      'path': path,
    });
    return Size(m!['width']!.toDouble(), m['height']!.toDouble());
  }

  @override
  Future<String?> render({
    required String inputPath,
    required String outputPath,
    required List<double> affine,
    required int outWidth,
    required int outHeight,
    required String format,
    required int quality,
  }) async {
    final res = await methodChannel.invokeMethod<String>('render', {
      'path': inputPath,
      'outputPath': outputPath,
      'affine': affine,
      'outWidth': outWidth,
      'outHeight': outHeight,
      'format': format,
      'quality': quality,
    });
    return res;
  }
}
