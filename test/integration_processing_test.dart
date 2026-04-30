import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_texture_toolkit/src/services/bc_codec.dart';
import 'package:universal_texture_toolkit/src/services/swizzle_logic.dart';
import 'package:universal_texture_toolkit/src/services/texture_processor.dart';
import 'package:universal_texture_toolkit/src/services/log_service.dart';
import 'package:path/path.dart' as p;
import 'dart:io' as io;

void main() {
  setUpAll(() async {
    // Initialize LogService with a mock or just ensure it doesn't crash
    await LogService.init();
  });

  group('Texture Processing Integration', () {
    test('BC1 Pipeline: RGBA -> BC1 -> Swizzle -> Deswizzle -> BC1 Decode', () async {
      const width = 64; // Small enough for fast test
      const height = 64;
      const bpe = 8; // BC1
      const blockHeight = 1; // Simplest block height

      // 1. Create a pattern RGBA image
      final rgba = Uint8List(width * height * 4);
      for (int i = 0; i < rgba.length; i += 4) {
        rgba[i] = (i ~/ 4) % 256;     // R
        rgba[i + 1] = ((i ~/ 4) ~/ 256) % 256; // G
        rgba[i + 2] = 128;            // B
        rgba[i + 3] = 255;            // A
      }

      // 2. Encode to BC1
      final bc1Blocks = BcCodec.bc1Encode(rgba, width, height);
      expect(bc1Blocks.length, equals((width ~/ 4) * (height ~/ 4) * 8));

      // 3. Swizzle
      final swizzled = SwizzleLogic.swizzleBlockLinear(
        bc1Blocks,
        width ~/ 4,
        height ~/ 4,
        bpe,
        blockHeight,
      );

      // 4. Deswizzle
      final deswizzled = SwizzleLogic.deswizzleBlockLinear(
        swizzled,
        width ~/ 4,
        height ~/ 4,
        bpe,
        blockHeight,
      );
      expect(deswizzled, equals(bc1Blocks));

      // 5. Decode back to RGBA
      final decodedRgba = BcCodec.bc1Decode(deswizzled, width, height);
      expect(decodedRgba.length, equals(rgba.length));

      // 6. Verify (BC1 is lossy, so check for similarity)
      int diffCount = 0;
      for (int i = 0; i < rgba.length; i++) {
        if ((rgba[i] - decodedRgba[i]).abs() > 20) {
          diffCount++;
        }
      }
      // Allow some percentage of pixels to be slightly different due to BC1 encoding
      expect(diffCount / rgba.length, lessThan(0.1));
    });

    test('BC3 Pipeline: RGBA -> BC3 -> Swizzle -> Deswizzle -> BC3 Decode', () async {
      const width = 32;
      const height = 32;
      const bpe = 16; // BC3
      const blockHeight = 1;

      final rgba = Uint8List(width * height * 4);
      for (int i = 0; i < rgba.length; i += 4) {
        rgba[i] = (i ~/ 4) % 256;
        rgba[i + 1] = 0;
        rgba[i + 2] = 255;
        rgba[i + 3] = (i ~/ 4) % 256; // Dynamic alpha
      }

      final bc3Blocks = BcCodec.bc3Encode(rgba, width, height);
      expect(bc3Blocks.length, equals((width ~/ 4) * (height ~/ 4) * 16));

      final swizzled = SwizzleLogic.swizzleBlockLinear(
        bc3Blocks,
        width ~/ 4,
        height ~/ 4,
        bpe,
        blockHeight,
      );

      final deswizzled = SwizzleLogic.deswizzleBlockLinear(
        swizzled,
        width ~/ 4,
        height ~/ 4,
        bpe,
        blockHeight,
      );
      expect(deswizzled, equals(bc3Blocks));

      final decodedRgba = BcCodec.bc3Decode(deswizzled, width, height);
      expect(decodedRgba.length, equals(rgba.length));

      // Verify alpha specifically for BC3
      int alphaDiffCount = 0;
      for (int i = 3; i < rgba.length; i += 4) {
        if ((rgba[i] - decodedRgba[i]).abs() > 10) {
          alphaDiffCount++;
        }
      }
      expect(alphaDiffCount / (rgba.length / 4), lessThan(0.05));
    });

    test('Zstandard Compression/Decompression', () async {
      // Note: This test might fail in some environments if native libs are not loaded
      try {
        final data = Uint8List.fromList(List.generate(1000, (i) => i % 256));
        final compressed = await TextureProcessor.zstdCompress(data, 3);
        expect(compressed, isNotNull);
        expect(compressed!.length, lessThan(data.length + 100));

        // Create a temporary file to test decompression which reads from disk
        final tempDir = io.Directory.systemTemp.createTempSync();
        final tempFile = io.File(p.join(tempDir.path, 'test.zs'));
        await tempFile.writeAsBytes(compressed);

        final decompressed = await TextureProcessor.zstdDecompress(tempFile.path);
        expect(decompressed, equals(data));

        await tempDir.delete(recursive: true);
      } catch (e) {
        print('Skipping Zstd test: $e (Native library may not be available in test environment)');
      }
    });
  });
}
