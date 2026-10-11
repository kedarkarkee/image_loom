# image_loom
[![pub package](https://img.shields.io/pub/v/image_loom.svg)](https://pub.dartlang.org/packages/image_loom)

Fast, native image editing for Flutter.

Describe your edits as a list of operations (rotate, flip, crop, resize, ...). `image_loom` folds them into a single transform in Dart, then renders the result with **one native pass** that decodes only the pixels it needs.

```dart
final loom = await ImageLoom.open(path);

await loom.apply(
  [
    const ImageOperation.flip(horizontal: true),
    const ImageOperation.rotate(90),
    const ImageOperation.crop(Rect.fromLTWH(120, 80, 800, 600)),
    const ImageOperation.scaleToFit(Size(1080, 1080)),
  ],
  outputPath: outPath,
  format: OutputFormat.jpeg,
  quality: 90,
);
```

## Motivation

`image_loom` is built around one idea: describe edits as lightweight operations in Dart, and do the pixel work natively

- **No bundled UI.** The plugin only edits images, so it works with any cropper design you build.
- **Edits are cheap until you render.** Operations only change a small matrix and a canvas size. Nothing touches pixels until you call `apply`, so rotating, flipping and cropping in a UI involve no image processing.
- **One native render.** `apply` makes a single native call. It works out which part of the source the output needs, decodes only that region where the platform supports it, draws once with the combined matrix, and encodes once.
- **No image bytes in Dart.** Only file paths and a few numbers cross the platform channel.
- **Smaller decodes for smaller outputs.** When the output is much smaller than the source (`resize`, `scaleToFit`), the native side asks the decoder for a reduced-size image where the decoder supports it.

## Platform support

| Platform | Minimum | Input formats | Output formats |
|----------|---------|---------------|----------------|
| Android  | API 24  | Whatever `BitmapFactory` decodes (JPEG, PNG, WebP, GIF, HEIC from API 28) | JPEG, PNG, WebP |
| iOS      | 15.0    | Whatever ImageIO decodes (JPEG, PNG, HEIC, ...) | JPEG, PNG, HEIC |
| macOS    | 10.15   | Whatever ImageIO decodes (JPEG, PNG, HEIC, ...) | JPEG, PNG, HEIC |

Asking for an unsupported output format (for example HEIC on Android or WebP on Apple platforms) throws a `PlatformException` with code `IMAGE_LOOM_ERROR`. Check the platform in Dart before offering those formats.

## Installation

```bash
flutter pub add image_loom
```

## Usage

### 1. Open an image

```dart
final loom = await ImageLoom.open('/path/to/photo.heic');
print(loom.size); // upright size in pixels, with EXIF orientation already applied
```

`open` makes one cheap native call to read the image size. Everything after that is synchronous until you render. If you already know the size, skip the call:

```dart
final loom = ImageLoom.withSize(path, const Size(4000, 3000));
```

### 2. Plan (synchronous, no pixels touched)

```dart
final state = loom.plan([
  const ImageOperation.rotate(90),
  const ImageOperation.crop(Rect.fromLTWH(0, 0, 200, 200)),
]);

print(state.size);   // final output size
print(state.matrix); // maps source pixels to output pixels
```

`plan` is safe to call in `build` methods and gesture callbacks. Use it to show the final size, drive previews, or unit-test your edits.

### 3. Apply (one native render)

```dart
final out = await loom.apply(
  [
    const ImageOperation.rotate(90),
    ImageOperation.crop(rect),
  ],
  outputPath: '/path/to/output.jpg',
  format: OutputFormat.jpeg,
  quality: 92,
);
```

For a single operation, use `planOne` and `applyOne`.

## Operations

Operations run in the order given. Each one works on the **canvas as it is at that point**, so `[rotate(90), crop(r)]` and `[crop(r), rotate(90)]` give different results.

| Operation | What it does |
|-----------|--------------|
| `ImageOperation.flip(horizontal:, vertical:)` | Mirrors the canvas. |
| `ImageOperation.rotate(degrees)` | Rotates clockwise. The canvas grows to the bounding box of the rotated image. |
| `ImageOperation.crop(rect)` | Crops to `rect` in the current canvas coordinates. The part outside the canvas is discarded, and a rect completely outside throws `ArgumentError`. |
| `ImageOperation.cropToAspect(aspect, alignment:)` | Crops the largest area with the given width/height ratio. |
| `ImageOperation.resize(target)` | Scales the canvas to exactly `target`. |
| `ImageOperation.scale(factor)` | Scales by a factor, keeping the aspect ratio. |
| `ImageOperation.scaleToFit(box, cover:)` | Scales to fit inside a box (default), or to cover it with `cover: true`. It only scales and does not crop. |
| `ImageOperation.translate(offset)` | Shifts the content inside the same canvas. |
| `ImageOperation.pad(padding)` | Grows the canvas around the content. The new area is transparent in PNG and white in JPEG. |
| `ImageOperation.skew(xDegrees:, yDegrees:)` | Skews the content. The canvas grows to fit. |
| `ImageOperation.transpose()` | Mirror over the main diagonal: `(x, y) -> (y, x)`. |
| `ImageOperation.transverse()` | Mirror over the anti-diagonal. |

All of them are `const` constructors when their arguments are constant.

### Writing your own operation

```dart
class MyOperation extends ImageOperation {
  const MyOperation();

  @override
  GeometryState apply(GeometryState s) {
    // Return a new state: a matrix applied after the current one, and optionally a new size.
    return s.transformed(Matrix4.translationValues(10, 0, 0));
  }
}
```

Any operation that can be written as an affine transform plus a canvas size works, and it is rendered in the same single pass.

## How it works

1. The native side reads the image size and EXIF orientation. `ImageLoom.size` is the **upright** size.
2. Each operation receives a `GeometryState` (a 4x4 `Matrix4` plus a `Size`) and returns a new one.
3. The final state is sent to native as six affine values (`a, b, c, d, tx, ty`) and an output size.
4. Native applies the EXIF orientation, then your transform, works out which part of the source image the output touches, decodes only that region, draws once, and encodes once.

The preview in your UI can use the same matrix. Scale it by `previewSize / sourceSize` and pass it to Flutter's `Transform` so rotating and flipping stay on the GPU.

## Coordinates and orientation

- All coordinates are in **source pixels**, in the upright (EXIF-corrected) image. When a UI works in preview pixels, multiply by `loom.size.width / previewWidth` first.
- The origin is the top-left corner, with `y` pointing down.
- Rotation is clockwise.
- Free-angle rotation never shrinks the canvas. Rotating by 37 degrees and back leaves a larger canvas, because the corners stay. Add a `crop` to trim it.

## Platform notes

- **HEIC on Android** is decoded from API 28. On API 24 to 27, HEIC files fail with a decode error.
- **Region decoding** is used where the platform supports it. When it does not (some formats on some devices), the Android side falls back to a full, subsampled decode, which is slower and uses more memory.
- **Subsampled decoding** on Apple platforms applies to JPEG only. Other formats are decoded at full size.
- **Metadata** (EXIF, GPS, ICC profile) is not copied to the output. The output pixels are already upright.
- **Very large outputs** allocate that many pixels. Cap `resize` and `scaleToFit` targets to what you need.

## Testing

The matrix logic is plain Dart, so you can test it without a device:

```dart
test('rotate 90 then crop', () {
  final loom = ImageLoom.withSize('x.jpg', const Size(400, 200));
  final s = loom.plan([
    const ImageOperation.rotate(90),
    const ImageOperation.crop(Rect.fromLTWH(0, 0, 200, 200)),
  ]);
  expect(s.size, const Size(200, 200));
});
```

A handy test image is a 400x200 image with four colored quadrants. Mapping each quadrant center through `state.matrix` shows exactly where it lands, and the expected values can be worked out by hand.

## Not included

- Color adjustments and filters (brightness, contrast, blur, ...).
- Masks such as circular crops.
- Perspective transforms (the native contract carries six affine values only).
- Copying metadata to the output.

### Reporting Issues
If you encounter any issues or have suggestions for improvement, please open an issue on the [GitHub repository](https://github.com/kedarkarkee/image_loom/issues).
