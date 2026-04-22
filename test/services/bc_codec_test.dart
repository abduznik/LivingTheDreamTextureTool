import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_the_dream_toolkit/src/services/bc_codec.dart';

void main() {
  group('BcCodec', () {
    test('rgb565Encode and rgb565Decode should be consistent', () {
      const r = 255, g = 128, b = 64;
      final encoded = BcCodec.rgb565Encode(r, g, b);
      final (dr, dg, db) = BcCodec.rgb565Decode(encoded);
      
      // RGB565 is lossy, so we check if it's within a small range
      expect((dr - r).abs(), lessThan(10));
      expect((dg - g).abs(), lessThan(10));
      expect((db - b).abs(), lessThan(10));
    });

    test('bc1Decode should return correct size buffer', () {
      final data = Uint8List(8); // One BC1 block
      final decoded = BcCodec.bc1Decode(data, 4, 4);
      expect(decoded.length, equals(4 * 4 * 4));
    });

    test('bc3Decode should return correct size buffer', () {
      final data = Uint8List(16); // One BC3 block
      final decoded = BcCodec.bc3Decode(data, 4, 4);
      expect(decoded.length, equals(4 * 4 * 4));
    });
  });
}
