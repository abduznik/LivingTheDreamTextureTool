import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:zstandard/zstandard.dart';
import 'swizzle_logic.dart';
import 'bc_codec.dart';
import 'color_utils.dart';

enum TextureKind { canvas, ugctex, thumb }

enum TextureFormat { bc1, bc3 }

class UgctexLayout {
  final int width;
  final int height;
  final int swizzleBlocksWide;
  final int swizzleBlocksTall;
  final int blockHeight;
  final TextureFormat format;

  UgctexLayout({
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
    if (lower.contains('ugctex')) return TextureKind.ugctex;
    return TextureKind.canvas;
  }

  static UgctexLayout detectUgctexLayout(int decompressedBytes) {
    switch (decompressedBytes) {
      case 131072:
        return UgctexLayout(width: 512, height: 512, swizzleBlocksWide: 128, swizzleBlocksTall: 128, blockHeight: 16, format: TextureFormat.bc1);
      case 98304:
        return UgctexLayout(width: 384, height: 384, swizzleBlocksWide: 96, swizzleBlocksTall: 128, blockHeight: 16, format: TextureFormat.bc1);
      case 65536:
        return UgctexLayout(width: 256, height: 256, swizzleBlocksWide: 64, swizzleBlocksTall: 64, blockHeight: 8, format: TextureFormat.bc3);
      default:
        throw Exception('Unknown ugctex format: $decompressedBytes bytes decompressed.');
    }
  }

  static Future<img.Image> decodeFile(String path, {bool noSrgb = false}) async {
    final kind = detectKind(path);
    final rawData = await zstdDecompress(path);

    switch (kind) {
      case TextureKind.thumb:
        return decodeThumb(rawData, noSrgb: noSrgb);
      case TextureKind.ugctex:
        return decodeUgctex(rawData, noSrgb: noSrgb);
      case TextureKind.canvas:
        return decodeCanvas(rawData, noSrgb: noSrgb);
    }
  }

  static Future<Uint8List> zstdDecompress(String path) async {
    final compressed = await io.File(path).readAsBytes();
    final decompressed = await _zstd.decompress(compressed);
    if (decompressed == null) throw Exception('Decompression failed');
    return decompressed;
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

  static img.Image decodeUgctex(Uint8List rawData, {bool noSrgb = false}) {
    final layout = detectUgctexLayout(rawData.length);
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

  static Future<void> importPng({
    required String pngPath,
    required String destStem,
    required bool writeThumb,
    required bool writeCanvas,
    bool noSrgb = false,
    String? originalUgctexPath,
  }) async {
    final srcFile = await io.File(pngPath).readAsBytes();
    img.Image? srcImage = img.decodeImage(srcFile);
    if (srcImage == null) throw Exception('Failed to decode PNG');

    UgctexLayout layout;
    Uint8List? originalSwizzled;
    if (originalUgctexPath != null && await io.File(originalUgctexPath).exists()) {
      originalSwizzled = await zstdDecompress(originalUgctexPath);
      layout = detectUgctexLayout(originalSwizzled.length);
    } else {
      layout = UgctexLayout(width: 512, height: 512, swizzleBlocksWide: 128, swizzleBlocksTall: 128, blockHeight: 16, format: TextureFormat.bc1);
    }

    if (writeCanvas) {
      const canvasW = 256, canvasH = 256;
      img.Image canvasImage = img.copyResize(srcImage, width: canvasW, height: canvasH);
      Uint8List canvasRgba = canvasImage.toUint8List();
      if (!noSrgb) ColorUtils.convertSrgbToLinear(canvasRgba);
      final swizzled = SwizzleLogic.swizzleBlockLinear(canvasRgba, canvasW, canvasH, 4, defaultBlockHeight);
      final compressed = await zstdCompress(swizzled, zstdLevel);
      await io.File('$destStem.canvas.zs').writeAsBytes(compressed);
    }

    {
      img.Image ugcImage = img.copyResize(srcImage, width: layout.width, height: layout.height);
      Uint8List ugcRgba = ugcImage.toUint8List();
      if (!noSrgb) ColorUtils.convertSrgbToLinear(ugcRgba);

      final encodedBlocks = layout.format == TextureFormat.bc3
          ? BcCodec.bc3Encode(ugcRgba, layout.width, layout.height)
          : BcCodec.bc1Encode(ugcRgba, layout.width, layout.height);

      final swizzled = SwizzleLogic.swizzleBlockLinear(
        encodedBlocks,
        layout.width ~/ 4,
        layout.height ~/ 4,
        layout.bytesPerBlock,
        layout.blockHeight,
        baseBuffer: originalSwizzled,
      );
      final compressed = await zstdCompress(swizzled, zstdLevel);
      await io.File('$destStem.ugctex.zs').writeAsBytes(compressed);
    }

    if (writeThumb) {
      const thumbW = 256, thumbH = 256;
      img.Image thumbImage = img.copyResize(srcImage, width: thumbW, height: thumbH, interpolation: img.Interpolation.cubic);
      Uint8List thumbRgba = thumbImage.toUint8List();
      if (!noSrgb) ColorUtils.convertSrgbToLinear(thumbRgba);
      final bc3Blocks = BcCodec.bc3Encode(thumbRgba, thumbW, thumbH);
      final swizzled = SwizzleLogic.swizzleBlockLinear(bc3Blocks, thumbW ~/ 4, thumbH ~/ 4, 16, thumbBlockHeight);
      final compressed = await zstdCompress(swizzled, zstdLevel);
      await io.File('${destStem}_Thumb_ugctex.zs').writeAsBytes(compressed);
    }
  }
}
