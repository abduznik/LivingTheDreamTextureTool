import 'dart:io' as io;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:zstandard/zstandard.dart';
import 'package:file_picker/file_picker.dart';
import 'swizzle_logic.dart';
import 'bc_codec.dart';
import 'color_utils.dart';
import 'log_service.dart';

enum TextureKind { canvas, vrstex, thumb }

enum TextureFormat { bc1, bc3 }

class VrsLayout {
  final int width;
  final int height;
  final int swizzleBlocksWide;
  final int swizzleBlocksTall;
  final int blockHeight;
  final TextureFormat format;

  VrsLayout({
    required this.width,
    required this.height,
    required this.swizzleBlocksWide,
    required this.swizzleBlocksTall,
    required this.blockHeight,
    required this.format,
  });

  int get bytesPerBlock => format == TextureFormat.bc3 ? 16 : 8;
}

class TextureProcessor {
  static const int defaultBlockHeight = 16;
  static const int thumbBlockHeight = 8;
  static const int zstdLevel = 3;

  static final _zstd = Zstandard();

  static TextureKind detectKind(String fileName) {
    final lower = p.basename(fileName).toLowerCase();
    if (lower.contains('thumb')) return TextureKind.thumb;
    if (lower.contains('ugctex')) return TextureKind.vrstex;
    return TextureKind.canvas;
  }

  static VrsLayout detectVrsLayout(int decompressedBytes) {
    switch (decompressedBytes) {
      case 131072:
        return VrsLayout(width: 512, height: 512, swizzleBlocksWide: 128, swizzleBlocksTall: 128, blockHeight: 16, format: TextureFormat.bc1);
      case 98304:
        return VrsLayout(width: 384, height: 384, swizzleBlocksWide: 96, swizzleBlocksTall: 128, blockHeight: 16, format: TextureFormat.bc1);
      case 65536:
        return VrsLayout(width: 256, height: 256, swizzleBlocksWide: 64, swizzleBlocksTall: 64, blockHeight: 8, format: TextureFormat.bc3);
      default:
        throw Exception('Unknown VRS format: $decompressedBytes bytes decompressed.');
    }
  }

  static Future<img.Image> decodeFile(String path, {bool noSrgb = false}) async {
    final kind = detectKind(path);
    final rawData = await zstdDecompress(path);

    switch (kind) {
      case TextureKind.thumb:
        return decodeThumb(rawData, noSrgb: noSrgb);
      case TextureKind.vrstex:
        return decodeVrs(rawData, noSrgb: noSrgb);
      case TextureKind.canvas:
        return decodeCanvas(rawData, noSrgb: noSrgb);
    }
  }

  static Future<Uint8List> zstdDecompress(String path) async {
    LogService.log('Attempting to decompress: $path');
    try {
      final file = io.File(path);
      if (!await file.exists()) {
        LogService.log('File does not exist at $path');
        throw Exception('File not found');
      }
      final compressed = await file.readAsBytes();
      LogService.log('Read ${compressed.length} compressed bytes');
      final decompressed = await _zstd.decompress(compressed);
      if (decompressed == null) {
        LogService.log('Zstd decompression returned null');
        throw Exception('Decompression failed');
      }
      LogService.log('Decompressed successfully to ${decompressed.length} bytes');
      return decompressed;
    } catch (e, stack) {
      LogService.log('Decompression error: $e');
      LogService.log('Stacktrace: $stack');
      rethrow;
    }
  }

  static Future<Uint8List> zstdCompress(Uint8List data, int level) async {
    final compressed = await _zstd.compress(data, level);
    if (compressed == null) throw Exception('Compression failed');
    return compressed;
  }

  static img.Image decodeCanvas(Uint8List rawData, {bool noSrgb = false}) {
    int totalPixels = rawData.length ~/ 4;
    int width = 256;
    int height = totalPixels ~/ width;

    final rgba = SwizzleLogic.deswizzleBlockLinear(rawData, width, height, 4, defaultBlockHeight);
    if (!noSrgb) ColorUtils.convertLinearToSrgb(rgba);

    return img.Image.fromBytes(
      width: width,
      height: height,
      bytes: rgba.buffer,
      numChannels: 4,
    );
  }

  static img.Image decodeVrs(Uint8List rawData, {bool noSrgb = false}) {
    final layout = detectVrsLayout(rawData.length);
    final visibleBlocksWide = layout.width ~/ 4;
    final visibleBlocksTall = layout.height ~/ 4;

    final blocks = SwizzleLogic.deswizzleBlockLinear(
      rawData,
      visibleBlocksWide,
      visibleBlocksTall,
      layout.bytesPerBlock,
      layout.blockHeight,
    );

    final rgba = layout.format == TextureFormat.bc3
        ? BcCodec.bc3Decode(blocks, layout.width, layout.height)
        : BcCodec.bc1Decode(blocks, layout.width, layout.height);
    
    if (!noSrgb) ColorUtils.convertLinearToSrgb(rgba);

    return img.Image.fromBytes(
      width: layout.width,
      height: layout.height,
      bytes: rgba.buffer,
      numChannels: 4,
    );
  }

  static img.Image decodeThumb(Uint8List rawData, {bool noSrgb = false}) {
    int totalBlocks = rawData.length ~/ 16;
    int gridSide = math.sqrt(totalBlocks).toInt();
    int texWidth = gridSide * 4;
    int texHeight = gridSide * 4;

    final blocks = SwizzleLogic.deswizzleBlockLinear(rawData, gridSide, gridSide, 16, thumbBlockHeight);
    final rgba = BcCodec.bc3Decode(blocks, texWidth, texHeight);
    
    if (!noSrgb) ColorUtils.convertLinearToSrgb(rgba);

    return img.Image.fromBytes(
      width: texWidth,
      height: texHeight,
      bytes: rgba.buffer,
      numChannels: 4,
    );
  }

  static Future<void> exportToPng(img.Image image, String originalPath) async {
    // Use file_picker to select save location
    String? outputPath = await FilePicker.saveFile(
      dialogTitle: 'Export Texture as PNG',
      fileName: '${p.basenameWithoutExtension(p.basenameWithoutExtension(originalPath))}.png',
      type: FileType.custom,
      allowedExtensions: ['png'],
    );

    if (outputPath != null) {
      if (!outputPath.endsWith('.png')) outputPath += '.png';
      final pngBytes = img.encodePng(image);
      await io.File(outputPath).writeAsBytes(Uint8List.fromList(pngBytes));
    }
  }

  static Future<bool> checkDirectoryWritable(String directoryPath) async {
    try {
      final absolutePath = p.absolute(directoryPath);
      final testFile = io.File(p.join(absolutePath, '.utt_permission_test'));
      await testFile.writeAsString('test');
      await testFile.delete();
      return true;
    } catch (e) {
      LogService.log('Directory $directoryPath is not writable: $e');
      return false;
    }
  }

  static Future<void> _safeWrite(String path, Uint8List bytes) async {
    final file = io.File(path);
    try {
      // Direct write attempt
      await file.writeAsBytes(bytes);
    } catch (e) {
      LogService.log('Direct write failed for $path, trying temp file strategy: $e');
      // Temp file strategy
      final tempDir = io.Directory.systemTemp;
      final tempFile = io.File(p.join(tempDir.path, 'utt_temp_${DateTime.now().microsecondsSinceEpoch}'));
      await tempFile.writeAsBytes(bytes);
      if (await file.exists()) {
        await file.delete();
      }
      await tempFile.copy(path);
      await tempFile.delete();
    }
  }

  static Future<void> importPng({
    required String pngPath,
    required String destStem,
    required bool writeThumb,
    required bool writeCanvas,
    bool noSrgb = false,
    String? originalVrsPath,
  }) async {
    final absolutePngPath = p.absolute(pngPath);
    final srcFile = await io.File(absolutePngPath).readAsBytes();
    img.Image? srcImage = img.decodeImage(srcFile);
    if (srcImage == null) throw Exception('Failed to decode PNG');

    VrsLayout layout;
    Uint8List? originalSwizzled;
    if (originalVrsPath != null) {
      final absoluteOriginalPath = p.absolute(originalVrsPath);
      if (await io.File(absoluteOriginalPath).exists()) {
        originalSwizzled = await zstdDecompress(absoluteOriginalPath);
        layout = detectVrsLayout(originalSwizzled.length);
      } else {
        layout = VrsLayout(width: 512, height: 512, swizzleBlocksWide: 128, swizzleBlocksTall: 128, blockHeight: 16, format: TextureFormat.bc1);
      }
    } else {
      layout = VrsLayout(width: 512, height: 512, swizzleBlocksWide: 128, swizzleBlocksTall: 128, blockHeight: 16, format: TextureFormat.bc1);
    }

    if (writeCanvas) {
      const canvasW = 256, canvasH = 256;
      img.Image canvasImage = img.copyResize(srcImage, width: canvasW, height: canvasH);
      Uint8List canvasRgba = canvasImage.toUint8List();
      if (!noSrgb) ColorUtils.convertSrgbToLinear(canvasRgba);
      final swizzled = SwizzleLogic.swizzleBlockLinear(canvasRgba, canvasW, canvasH, 4, defaultBlockHeight);
      final compressed = await zstdCompress(swizzled, zstdLevel);
      await _safeWrite('$destStem.canvas.zs', compressed);
    }

    {
      img.Image vrsImage = img.copyResize(srcImage, width: layout.width, height: layout.height);
      Uint8List vrsRgba = vrsImage.toUint8List();
      if (!noSrgb) ColorUtils.convertSrgbToLinear(vrsRgba);

      final encodedBlocks = layout.format == TextureFormat.bc3
          ? BcCodec.bc3Encode(vrsRgba, layout.width, layout.height)
          : BcCodec.bc1Encode(vrsRgba, layout.width, layout.height);

      final swizzled = SwizzleLogic.swizzleBlockLinear(
        encodedBlocks,
        layout.width ~/ 4,
        layout.height ~/ 4,
        layout.bytesPerBlock,
        layout.blockHeight,
        baseBuffer: originalSwizzled,
      );
      final compressed = await zstdCompress(swizzled, zstdLevel);
      await _safeWrite('$destStem.ugctex.zs', compressed);
    }

    if (writeThumb) {
      const thumbW = 256, thumbH = 256;
      img.Image thumbImage = img.copyResize(srcImage, width: thumbW, height: thumbH, interpolation: img.Interpolation.cubic);
      Uint8List thumbRgba = thumbImage.toUint8List();
      if (!noSrgb) ColorUtils.convertSrgbToLinear(thumbRgba);
      final bc3Blocks = BcCodec.bc3Encode(thumbRgba, thumbW, thumbH);
      final swizzled = SwizzleLogic.swizzleBlockLinear(bc3Blocks, thumbW ~/ 4, thumbH ~/ 4, 16, thumbBlockHeight);
      final compressed = await zstdCompress(swizzled, zstdLevel);
      await _safeWrite('${destStem}_Thumb_ugctex.zs', compressed);
    }
  }
}
