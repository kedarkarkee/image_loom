import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_loom/image_loom.dart';
import 'package:path_provider/path_provider.dart';

class _Preset {
  const _Preset(this.label, this.ratio);
  final String label;

  /// width / height, or null for a free-form box.
  final double? ratio;
}

enum _Handle { move, topLeft, topRight, bottomLeft, bottomRight }

/// Full-screen dialog that lets the user draw a crop box on the canvas as it
/// looks after [operations]. Pops with a [Rect] in that canvas's pixel
/// coordinates, ready to be passed to `Crop`.
class CropDialog extends StatefulWidget {
  const CropDialog({super.key, required this.loom, required this.operations});

  final ImageLoom loom;
  final List<ImageOperation> operations;

  @override
  State<CropDialog> createState() => _CropDialogState();
}

class _CropDialogState extends State<CropDialog> {
  late final Size _canvas = widget.loom.plan(widget.operations).size;

  late Rect _rect = Rect.fromLTWH(
    _canvas.width * 0.1,
    _canvas.height * 0.1,
    _canvas.width * 0.8,
    _canvas.height * 0.8,
  );

  late final List<_Preset> _presets = [
    const _Preset('Free', null),
    _Preset('Original', _canvas.width / _canvas.height),
    const _Preset('1:1', 1),
    const _Preset('4:3', 4 / 3),
    const _Preset('3:4', 3 / 4),
    const _Preset('16:9', 16 / 9),
    const _Preset('9:16', 9 / 16),
  ];
  int _presetIndex = 0;

  String? _previewPath;
  String? _error;

  // Gesture state
  _Handle? _handle;
  Rect _startRect = Rect.zero;
  Offset _startPos = Offset.zero;

  double get _minSide => math.max(16.0, _canvas.shortestSide * 0.05);

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  void dispose() {
    final p = _previewPath;
    if (p != null) {
      FileImage(File(p)).evict();
      File(p).delete().ignore();
    }
    super.dispose();
  }

  /// Renders the current pipeline once, so the box is drawn over exactly the
  /// pixels that `Crop` will see.
  Future<void> _loadPreview() async {
    try {
      final dir = await getTemporaryDirectory();
      final out =
          '${dir.path}/crop_preview_${DateTime.now().microsecondsSinceEpoch}.jpg';
      final res = await widget.loom.apply(
        widget.operations,
        outputPath: out,
        format: OutputFormat.jpeg,
        quality: 85,
      );
      if (!mounted) {
        if (res != null) File(res).delete().ignore();
        return;
      }
      setState(() => _previewPath = res);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  // ---------------------------------------------------------------- presets

  void _selectPreset(int i) {
    final ratio = _presets[i].ratio;
    setState(() {
      _presetIndex = i;
      if (ratio != null) _rect = _fitRatio(_rect.center, ratio);
    });
  }

  /// Largest box with [ratio] that fits the canvas (90%), centred on [center]
  /// and shifted back inside the canvas if needed.
  Rect _fitRatio(Offset center, double ratio) {
    var w = _canvas.width;
    var h = w / ratio;
    if (h > _canvas.height) {
      h = _canvas.height;
      w = h * ratio;
    }
    w *= 0.9;
    h *= 0.9;
    var r = Rect.fromCenter(center: center, width: w, height: h);
    var dx = 0.0, dy = 0.0;
    if (r.left < 0) dx = -r.left;
    if (r.right > _canvas.width) dx = _canvas.width - r.right;
    if (r.top < 0) dy = -r.top;
    if (r.bottom > _canvas.height) dy = _canvas.height - r.bottom;
    return r.shift(Offset(dx, dy));
  }

  // --------------------------------------------------------------- gestures

  void _onPanStart(DragStartDetails d, double scale) {
    final pos = d.localPosition / scale;
    final corners = <_Handle, Offset>{
      _Handle.topLeft: _rect.topLeft,
      _Handle.topRight: _rect.topRight,
      _Handle.bottomLeft: _rect.bottomLeft,
      _Handle.bottomRight: _rect.bottomRight,
    };

    _Handle? hit;
    var best = 36 / scale; // ~36 logical px touch radius
    for (final e in corners.entries) {
      final dist = (e.value - pos).distance;
      if (dist <= best) {
        best = dist;
        hit = e.key;
      }
    }
    hit ??= _rect.contains(pos) ? _Handle.move : null;

    _handle = hit;
    _startRect = _rect;
    _startPos = pos;
  }

  void _onPanUpdate(DragUpdateDetails d, double scale) {
    final handle = _handle;
    if (handle == null) return;
    final pos = d.localPosition / scale;

    setState(() {
      if (handle == _Handle.move) {
        final delta = pos - _startPos;
        final left = _clamp(
          _startRect.left + delta.dx,
          0,
          _canvas.width - _startRect.width,
        );
        final top = _clamp(
          _startRect.top + delta.dy,
          0,
          _canvas.height - _startRect.height,
        );
        _rect = Rect.fromLTWH(left, top, _startRect.width, _startRect.height);
      } else {
        _rect = _resize(handle, pos);
      }
    });
  }

  double _clamp(double v, double lo, double hi) =>
      math.min(math.max(v, lo), math.max(lo, hi));

  /// Resizes from the corner opposite to [handle], which stays fixed.
  Rect _resize(_Handle handle, Offset pos) {
    final r = _startRect;
    final (anchor, sx, sy) = switch (handle) {
      _Handle.topLeft => (r.bottomRight, -1.0, -1.0),
      _Handle.topRight => (r.bottomLeft, 1.0, -1.0),
      _Handle.bottomLeft => (r.topRight, -1.0, 1.0),
      _Handle.bottomRight => (r.topLeft, 1.0, 1.0),
      _Handle.move => throw StateError('unreachable'),
    };

    // Room available between the anchor and the canvas edge in drag direction.
    final maxW = sx > 0 ? _canvas.width - anchor.dx : anchor.dx;
    final maxH = sy > 0 ? _canvas.height - anchor.dy : anchor.dy;

    var w = math.max(sx * (pos.dx - anchor.dx), _minSide);
    var h = math.max(sy * (pos.dy - anchor.dy), _minSide);

    final ratio = _presets[_presetIndex].ratio;
    if (ratio != null) {
      w = math.max(w, h * ratio);
      h = w / ratio;
      if (w > maxW) {
        w = maxW;
        h = w / ratio;
      }
      if (h > maxH) {
        h = maxH;
        w = h * ratio;
      }
    } else {
      w = math.min(w, maxW);
      h = math.min(h, maxH);
    }

    return Rect.fromPoints(anchor, anchor + Offset(sx * w, sy * h));
  }

  // ----------------------------------------------------------------- result

  /// Whole pixels, and never past the canvas edge, so the planned output size
  /// is exactly what the box shows.
  Rect get _roundedRect {
    final l = _rect.left.roundToDouble();
    final t = _rect.top.roundToDouble();
    var w = _rect.width.roundToDouble();
    var h = _rect.height.roundToDouble();
    if (l + w > _canvas.width) w = (_canvas.width - l).floorToDouble();
    if (t + h > _canvas.height) h = (_canvas.height - t).floorToDouble();
    return Rect.fromLTWH(l, t, math.max(1, w), math.max(1, h));
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final crop = _roundedRect;
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Crop'),
          leading: CloseButton(onPressed: () => Navigator.pop(context)),
          actions: [
            TextButton(
              onPressed: _previewPath == null
                  ? null
                  : () => Navigator.pop(context, _roundedRect),
              child: const Text('Done'),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _canvasArea(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${crop.width.round()} × ${crop.height.round()} px'
                      '   at ${crop.left.round()}, ${crop.top.round()}'
                      '   (canvas ${_canvas.width.round()} × ${_canvas.height.round()})',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: [
                        for (var i = 0; i < _presets.length; i++)
                          ChoiceChip(
                            label: Text(_presets[i].label),
                            selected: i == _presetIndex,
                            onSelected: (_) => _selectPreset(i),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _canvasArea() {
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }
    final path = _previewPath;
    if (path == null) return const Center(child: CircularProgressIndicator());

    final landscape = _canvas.width >= _canvas.height;

    return LayoutBuilder(
      builder: (context, c) {
        final scale = math.min(
          c.maxWidth / _canvas.width,
          c.maxHeight / _canvas.height,
        );
        final display = Size(_canvas.width * scale, _canvas.height * scale);
        final boxOnScreen = Rect.fromLTRB(
          _rect.left * scale,
          _rect.top * scale,
          _rect.right * scale,
          _rect.bottom * scale,
        );

        return Center(
          child: SizedBox.fromSize(
            size: display,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (d) => _onPanStart(d, scale),
              onPanUpdate: (d) => _onPanUpdate(d, scale),
              onPanEnd: (_) => _handle = null,
              onPanCancel: () => _handle = null,
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  Image.file(
                    File(path),
                    fit: BoxFit.fill,
                    cacheWidth: landscape ? 1600 : null,
                    cacheHeight: landscape ? null : 1600,
                  ),
                  CustomPaint(painter: _CropPainter(boxOnScreen)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter(this.rect);

  /// In on-screen coordinates.
  final Rect rect;

  @override
  void paint(Canvas canvas, Size size) {
    // Dim everything outside the box.
    final dim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(rect);
    canvas.drawPath(dim, Paint()..color = Colors.black54);

    // Border
    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Rule-of-thirds grid
    final grid = Paint()
      ..color = Colors.white54
      ..strokeWidth = 0.8;
    for (var i = 1; i < 3; i++) {
      final x = rect.left + rect.width * i / 3;
      final y = rect.top + rect.height * i / 3;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), grid);
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), grid);
    }

    // Corner handles
    final fill = Paint()..color = Colors.white;
    final edge = Paint()
      ..color = Colors.black38
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final c in [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ]) {
      canvas.drawCircle(c, 9, fill);
      canvas.drawCircle(c, 9, edge);
    }
  }

  @override
  bool shouldRepaint(_CropPainter old) => old.rect != rect;
}
