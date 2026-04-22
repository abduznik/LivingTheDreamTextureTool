import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
import 'package:image/image.dart' as img;

/// A full-screen page for cropping and transforming an image.
class CropEditorPage extends StatefulWidget {
  final Uint8List imageBytes;

  const CropEditorPage({super.key, required this.imageBytes});

  @override
  State<CropEditorPage> createState() => _CropEditorPageState();
}

class _CropEditorPageState extends State<CropEditorPage> {
  final GlobalKey<ExtendedImageEditorState> _editorKey =
      GlobalKey<ExtendedImageEditorState>();
  bool _isProcessing = false;

  /// Crops the image using the current editor state.
  Future<void> _cropImage() async {
    setState(() => _isProcessing = true);
    try {
      final state = _editorKey.currentState;
      if (state == null) {
        if (mounted) Navigator.pop(context, null);
        return;
      }
      // Use the helper function to perform the crop operation.
      final data = await cropImageDataWithDartLibrary(state: state);
      if (mounted) Navigator.pop(context, data);
    } catch (e) {
      debugPrint('Crop error: $e');
      if (mounted) Navigator.pop(context, null);
    } finally {
      // The widget might be unmounted here if the pop was successful.
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop Image'),
        backgroundColor: Colors.black.withAlpha(128),
        automaticallyImplyLeading: false, // We have our own cancel button
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: ExtendedImage.memory(
              widget.imageBytes,
              fit: BoxFit.contain,
              mode: ExtendedImageMode.editor,
              extendedImageEditorKey: _editorKey,
              initEditorConfigHandler: (state) => EditorConfig(
                maxScale: 8.0,
                cropRectPadding: const EdgeInsets.all(20.0),
                hitTestSize: 20.0,
                initCropRectType: InitCropRectType.imageRect,
                cropAspectRatio: CropAspectRatios.ratio1_1,
                cornerColor: Colors.white,
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black.withAlpha(128),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Processing...', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.black.withAlpha(179),
        padding: const EdgeInsets.all(8.0),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.pop(context, null),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isProcessing ? null : _cropImage,
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper function to crop image using Dart 'image' library in a compute isolate.
Future<Uint8List?> cropImageDataWithDartLibrary({
  required ExtendedImageEditorState state,
}) async {
  final Rect cropRect = state.getCropRect()!;
  final Uint8List data = state.rawImageData;
  return await compute(_doCrop, {
    'data': data,
    'rect': cropRect,
    'editAction': state.editAction,
  });
}

/// The actual crop and transform logic to be run in a separate isolate.
Uint8List? _doCrop(Map<String, dynamic> args) {
  final Uint8List data = args['data'];
  final Rect rect = args['rect'];
  final EditActionDetails editAction = args['editAction'];

  img.Image? src = img.decodeImage(data);
  if (src == null) return null;

  src = img.bakeOrientation(src);

  if (editAction.hasRotateDegrees) {
    src = img.copyRotate(src, angle: editAction.rotateDegrees);
  }

  if (editAction.flipY) {
    src = img.flip(src, direction: img.FlipDirection.horizontal);
  }

  // Step 4: crop
  img.Image cropped = img.copyCrop(
    src,
    x: rect.left.toInt(),
    y: rect.top.toInt(),
    width: rect.width.toInt(),
    height: rect.height.toInt(),
  );

  // --- Start of Post-Processing ---

  // 1. Pick target size
  final int targetSize = (cropped.width > 384 || cropped.height > 384) ? 512 : 384;

  // 2. Resize with high-quality interpolation
  img.Image resized = img.copyResize(
    cropped,
    width: targetSize,
    height: targetSize,
    interpolation: img.Interpolation.linear,
    maintainAspect: true,
    backgroundColor: img.ColorRgba8(0, 0, 0, 0),
  );

  // 3. Composite onto a transparent square canvas
  img.Image canvas = img.Image(
    width: targetSize,
    height: targetSize,
    numChannels: 4,
  );
  img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));
  img.compositeImage(
    canvas,
    resized,
    dstX: (targetSize - resized.width) ~/ 2,
    dstY: (targetSize - resized.height) ~/ 2,
  );

  // Step 5: light gaussian blur to smooth compression artifacts on edges
  final img.Image blurred = img.gaussianBlur(canvas, radius: 1);

  // 4. Encode and return as PNG
  return Uint8List.fromList(img.encodePng(blurred));
}
