import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_the_dream_toolkit/src/services/swizzle_logic.dart';

void main() {
  group('SwizzleLogic', () {
    test('deswizzleBlockLinear and swizzleBlockLinear should be inverse for simple case', () {
      const width = 16;
      const height = 16;
      const bpe = 4;
      const blockHeight = 8;
      
      final original = Uint8List(width * height * bpe);
      for (var i = 0; i < original.length; i++) {
        original[i] = i % 256;
      }

      final swizzled = SwizzleLogic.swizzleBlockLinear(original, width, height, bpe, blockHeight);
      final deswizzled = SwizzleLogic.deswizzleBlockLinear(swizzled, width, height, bpe, blockHeight);

      expect(deswizzled, equals(original));
    });
   group('ColorUtils', () {
    // Ported from existing logic
  });
  });
}
