import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_loom/image_loom_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelImageLoom platform = MethodChannelImageLoom();
  const MethodChannel channel = MethodChannel('image_loom');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'getImageSize') {
            return {'width': 0, 'height': 0};
          }
          throw UnimplementedError(
            'Method ${methodCall.method} not implemented',
          );
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getImageSize', () async {
    expect(await platform.getImageSize(''), Size(0, 0));
  });
}
