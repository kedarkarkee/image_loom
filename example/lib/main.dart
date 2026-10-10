import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_loom/image_loom.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _picker = ImagePicker();

  ImageLoom? _loom;
  final List<ImageOperation> _ops = [];

  double _angle = 30;
  OutputFormat _format = OutputFormat.jpeg;
  double _quality = 92;

  bool _busy = false;
  String? _outputPath;
  Duration? _elapsed;
  String? _error;

  List<OutputFormat> get _formats => [
    OutputFormat.jpeg,
    OutputFormat.png,
    if (Platform.isAndroid) OutputFormat.webp,
    if (Platform.isIOS || Platform.isMacOS) OutputFormat.heic,
  ];

  Future<void> _pick() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    try {
      final loom = await ImageLoom.open(file.path);
      setState(() {
        _loom = loom;
        _ops.clear();
        _outputPath = null;
        _elapsed = null;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Could not open image: $e');
    }
  }

  void _add(ImageOperation op) => setState(() {
    _ops.add(op);
    _outputPath = null;
  });

  void _undo() {
    if (_ops.isEmpty) return;
    setState(() {
      _ops.removeLast();
      _outputPath = null;
    });
  }

  void _clear() => setState(() {
    _ops.clear();
    _outputPath = null;
  });

  /// Crops the centre 50% of the canvas as it is at this point in the pipeline.
  void _addCenterCrop() {
    final size = _loom!.plan(_ops).size;
    final w = size.width / 2, h = size.height / 2;
    _add(Crop(Rect.fromLTWH(size.width / 4, size.height / 4, w, h)));
  }

  Future<void> _render() async {
    final loom = _loom;
    if (loom == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final dir = await getTemporaryDirectory();
      final ext = _format == OutputFormat.jpeg ? 'jpg' : _format.name;
      final out =
          '${dir.path}/loom_${DateTime.now().microsecondsSinceEpoch}.$ext';

      final sw = Stopwatch()..start();
      final res = await loom.apply(
        _ops,
        outputPath: out,
        format: _format,
        quality: _quality.round(),
      );
      sw.stop();

      setState(() {
        _outputPath = res;
        _elapsed = sw.elapsed;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _busy = false);
    }
  }

  String _label(ImageOperation op) {
    if (op is Rotate) {
      return 'Rotate ${op.degrees.toStringAsFixed(op.degrees % 1 == 0 ? 0 : 1)}°';
    }
    if (op is Flip) {
      return [
        if (op.horizontal) 'Flip H',
        if (op.vertical) 'Flip V',
      ].join(' + ');
    }
    if (op is Crop) {
      final r = op.rect;
      return 'Crop ${r.width.round()}×${r.height.round()} @ ${r.left.round()},${r.top.round()}';
    }
    return op.runtimeType.toString();
  }

  @override
  Widget build(BuildContext context) {
    final loom = _loom;
    final planned = loom?.plan(_ops).size;

    return Scaffold(
      appBar: AppBar(title: const Text('image_loom example')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pick,
        icon: const Icon(Icons.photo_library),
        label: const Text('Pick image'),
      ),
      body: loom == null
          ? const Center(child: Text('Pick an image to start'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                Text(
                  'Source: ${loom.size.width.round()} × ${loom.size.height.round()} (upright)',
                ),
                Text(
                  'Planned output: ${planned!.width.round()} × ${planned.height.round()}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _preview('Original', loom.path),
                const SizedBox(height: 16),
                _operationButtons(),
                const SizedBox(height: 8),
                _operationList(),
                const Divider(height: 32),
                _outputSettings(),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _render,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(_busy ? 'Rendering…' : 'Apply'),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (_outputPath != null) ...[
                  const SizedBox(height: 16),
                  Text('Done in ${_elapsed!.inMilliseconds} ms'),
                  const SizedBox(height: 8),
                  _preview('Result', _outputPath!),
                ],
              ],
            ),
    );
  }

  Widget _preview(String title, String path) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Container(
          constraints: const BoxConstraints(maxHeight: 280),
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(File(path), fit: BoxFit.contain),
          ),
        ),
      ],
    );
  }

  Widget _operationButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => _add(const Rotate(90)),
              child: const Text('Rotate 90°'),
            ),
            OutlinedButton(
              onPressed: () => _add(const Flip(horizontal: true)),
              child: const Text('Flip H'),
            ),
            OutlinedButton(
              onPressed: () => _add(const Flip(vertical: true)),
              child: const Text('Flip V'),
            ),
            OutlinedButton(
              onPressed: _addCenterCrop,
              child: const Text('Crop centre 50%'),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _angle,
                min: -180,
                max: 180,
                divisions: 360,
                label: '${_angle.round()}°',
                onChanged: (v) => setState(() => _angle = v),
              ),
            ),
            OutlinedButton(
              onPressed: () => _add(Rotate(_angle)),
              child: Text('Rotate ${_angle.round()}°'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _operationList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Operations (applied in order)',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const Spacer(),
            TextButton(
              onPressed: _ops.isEmpty ? null : _undo,
              child: const Text('Undo'),
            ),
            TextButton(
              onPressed: _ops.isEmpty ? null : _clear,
              child: const Text('Clear'),
            ),
          ],
        ),
        if (_ops.isEmpty)
          const Text('None yet. The image will be re-encoded unchanged.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (var i = 0; i < _ops.length; i++)
                Chip(label: Text('${i + 1}. ${_label(_ops[i])}')),
            ],
          ),
      ],
    );
  }

  Widget _outputSettings() {
    final lossy = _format != OutputFormat.png;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Format'),
            const SizedBox(width: 12),
            DropdownButton<OutputFormat>(
              value: _formats.contains(_format) ? _format : OutputFormat.jpeg,
              items: [
                for (final f in _formats)
                  DropdownMenuItem(value: f, child: Text(f.name.toUpperCase())),
              ],
              onChanged: (f) => setState(() => _format = f!),
            ),
          ],
        ),
        Row(
          children: [
            Text('Quality ${_quality.round()}'),
            Expanded(
              child: Slider(
                value: _quality,
                min: 1,
                max: 100,
                divisions: 99,
                onChanged: lossy ? (v) => setState(() => _quality = v) : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
