import 'dart:typed_data';

class SwizzleLogic {
  static int _divRoundUp(int n, int d) => (n + d - 1) ~/ d;

  static int gobAddress(int x, int y, int widthInGobs, int bytesPerElement, int blockHeight) {
    final int xBytes = x * bytesPerElement;

    final int gobAddress =
          (y ~/ (8 * blockHeight)) * 512 * blockHeight * widthInGobs
        + (xBytes ~/ 64) * 512 * blockHeight
        + ((y % (8 * blockHeight)) ~/ 8) * 512;

    final int xInGob = xBytes % 64;
    final int yInGob = y % 8;

    return gobAddress
        + ((xInGob % 64) ~/ 32) * 256
        + ((yInGob % 8) ~/ 2) * 64
        + ((xInGob % 32) ~/ 16) * 32
        + (yInGob % 2) * 16
        + (xInGob % 16);
  }

  static Uint8List deswizzleBlockLinear(Uint8List data, int width, int height, int bpe, int blockHeight) {
    final int widthInGobs = _divRoundUp(width * bpe, 64);
    final int paddedHeight = _divRoundUp(height, 8 * blockHeight) * (8 * blockHeight);
    final int paddedSize = widthInGobs * paddedHeight * 64;
    
    final Uint8List source;
    if (data.length >= paddedSize) {
      source = data;
    } else {
      source = Uint8List(paddedSize);
      source.setRange(0, data.length, data);
    }

    final Uint8List output = Uint8List(width * height * bpe);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int swizzled = gobAddress(x, y, widthInGobs, bpe, blockHeight);
        final int linear = (y * width + x) * bpe;
        
        for (int i = 0; i < bpe; i++) {
          output[linear + i] = source[swizzled + i];
        }
      }
    }

    return output;
  }

  static Uint8List swizzleBlockLinear(Uint8List data, int width, int height, int bpe, int blockHeight, {Uint8List? baseBuffer}) {
    final int widthInGobs = _divRoundUp(width * bpe, 64);
    final int paddedHeight = _divRoundUp(height, 8 * blockHeight) * (8 * blockHeight);
    final int paddedSize = widthInGobs * paddedHeight * 64;

    final Uint8List output;
    if (baseBuffer != null && baseBuffer.length == paddedSize) {
      output = Uint8List.fromList(baseBuffer);
    } else {
      output = Uint8List(paddedSize);
    }

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int linear = (y * width + x) * bpe;
        final int swizzled = gobAddress(x, y, widthInGobs, bpe, blockHeight);
        
        for (int i = 0; i < bpe; i++) {
          output[swizzled + i] = data[linear + i];
        }
      }
    }

    return output;
  }
}
