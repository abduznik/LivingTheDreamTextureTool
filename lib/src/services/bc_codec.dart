import 'dart:typed_data';

class BcCodec {
  static (int, int, int) rgb565Decode(int c) {
    int r = (((c >> 11) & 0x1F) * 255 ~/ 31);
    int g = (((c >> 5) & 0x3F) * 255 ~/ 63);
    int b = ((c & 0x1F) * 255 ~/ 31);
    return (r, g, b);
  }

  static int rgb565Encode(int r, int g, int b) {
    int r5 = (r * 31 + 127) ~/ 255;
    int g6 = (g * 63 + 127) ~/ 255;
    int b5 = (b * 31 + 127) ~/ 255;
    return (r5 << 11) | (g6 << 5) | b5;
  }

  static int colorDistSq(int r1, int g1, int b1, int r2, int g2, int b2) {
    int dr = r1 - r2, dg = g1 - g2, db = b1 - b2;
    return dr * dr + dg * dg + db * db;
  }

  static Uint8List bc1Decode(Uint8List blockData, int texWidth, int texHeight) {
    int blocksX = texWidth ~/ 4;
    int blocksY = texHeight ~/ 4;
    Uint8List output = Uint8List(texWidth * texHeight * 4);
    Uint8List palette = Uint8List(16);
    ByteData bd = ByteData.view(blockData.buffer, blockData.offsetInBytes, blockData.length);

    for (int by = 0; by < blocksY; by++) {
      for (int bx = 0; bx < blocksX; bx++) {
        int blockOffset = (by * blocksX + bx) * 8;

        int c0Raw = bd.getUint16(blockOffset, Endian.little);
        int c1Raw = bd.getUint16(blockOffset + 2, Endian.little);
        int indices = bd.getUint32(blockOffset + 4, Endian.little);

        var (r0, g0, b0) = rgb565Decode(c0Raw);
        var (r1, g1, b1) = rgb565Decode(c1Raw);

        palette[0] = r0; palette[1] = g0; palette[2] = b0; palette[3] = 255;
        palette[4] = r1; palette[5] = g1; palette[6] = b1; palette[7] = 255;

        if (c0Raw > c1Raw) {
          palette[8] = ((2 * r0 + r1) ~/ 3);
          palette[9] = ((2 * g0 + g1) ~/ 3);
          palette[10] = ((2 * b0 + b1) ~/ 3);
          palette[11] = 255;
          palette[12] = ((r0 + 2 * r1) ~/ 3);
          palette[13] = ((g0 + 2 * g1) ~/ 3);
          palette[14] = ((b0 + 2 * b1) ~/ 3);
          palette[15] = 255;
        } else {
          palette[8] = ((r0 + r1) ~/ 2);
          palette[9] = ((g0 + g1) ~/ 2);
          palette[10] = ((b0 + b1) ~/ 2);
          palette[11] = 255;
          palette[12] = 0; palette[13] = 0; palette[14] = 0; palette[15] = 0;
        }

        for (int row = 0; row < 4; row++) {
          for (int col = 0; col < 4; col++) {
            int idx = ((indices >> (2 * (row * 4 + col))) & 0x3);
            int px = bx * 4 + col;
            int py = by * 4 + row;
            int dst = (py * texWidth + px) * 4;
            int palOff = idx * 4;
            output[dst] = palette[palOff];
            output[dst + 1] = palette[palOff + 1];
            output[dst + 2] = palette[palOff + 2];
            output[dst + 3] = palette[palOff + 3];
          }
        }
      }
    }
    return output;
  }

  static Uint8List bc3Decode(Uint8List blockData, int texWidth, int texHeight) {
    int blocksX = texWidth ~/ 4;
    int blocksY = texHeight ~/ 4;
    Uint8List output = Uint8List(texWidth * texHeight * 4);
    Uint8List alphas = Uint8List(8);
    ByteData bd = ByteData.view(blockData.buffer, blockData.offsetInBytes, blockData.length);

    for (int by = 0; by < blocksY; by++) {
      for (int bx = 0; bx < blocksX; bx++) {
        int blockOffset = (by * blocksX + bx) * 16;

        int a0 = blockData[blockOffset];
        int a1 = blockData[blockOffset + 1];

        int alphaIdxBitsLow = bd.getUint32(blockOffset + 2, Endian.little);
        int alphaIdxBitsHigh = bd.getUint16(blockOffset + 6, Endian.little);
        // We need 48 bits. Let's handle it carefully.

        alphas[0] = a0;
        alphas[1] = a1;
        if (a0 > a1) {
          alphas[2] = ((6 * a0 + 1 * a1) ~/ 7);
          alphas[3] = ((5 * a0 + 2 * a1) ~/ 7);
          alphas[4] = ((4 * a0 + 3 * a1) ~/ 7);
          alphas[5] = ((3 * a0 + 4 * a1) ~/ 7);
          alphas[6] = ((2 * a0 + 5 * a1) ~/ 7);
          alphas[7] = ((1 * a0 + 6 * a1) ~/ 7);
        } else {
          alphas[2] = ((4 * a0 + 1 * a1) ~/ 5);
          alphas[3] = ((3 * a0 + 2 * a1) ~/ 5);
          alphas[4] = ((2 * a0 + 3 * a1) ~/ 5);
          alphas[5] = ((1 * a0 + 4 * a1) ~/ 5);
          alphas[6] = 0;
          alphas[7] = 255;
        }

        int c0Raw = bd.getUint16(blockOffset + 8, Endian.little);
        int c1Raw = bd.getUint16(blockOffset + 10, Endian.little);
        int colorIndices = bd.getUint32(blockOffset + 12, Endian.little);

        var (r0, g0, b0) = rgb565Decode(c0Raw);
        var (r1, g1, b1) = rgb565Decode(c1Raw);

        int pr2 = ((2 * r0 + r1) ~/ 3);
        int pg2 = ((2 * g0 + g1) ~/ 3);
        int pb2 = ((2 * b0 + b1) ~/ 3);
        int pr3 = ((r0 + 2 * r1) ~/ 3);
        int pg3 = ((g0 + 2 * g1) ~/ 3);
        int pb3 = ((b0 + 2 * b1) ~/ 3);

        for (int row = 0; row < 4; row++) {
          for (int col = 0; col < 4; col++) {
            int pixelIndex = row * 4 + col;
            int ci = ((colorIndices >> (2 * pixelIndex)) & 0x3);
            
            // Extracting 3 bits for alpha index from 48-bit pool
            int bitOffset = 3 * pixelIndex;
            int ai;
            if (bitOffset < 32 - 3) {
              ai = (alphaIdxBitsLow >> bitOffset) & 0x7;
            } else if (bitOffset < 32) {
              int partLow = (alphaIdxBitsLow >> bitOffset);
              int partHigh = (alphaIdxBitsHigh << (32 - bitOffset));
              ai = (partLow | partHigh) & 0x7;
            } else {
              ai = (alphaIdxBitsHigh >> (bitOffset - 32)) & 0x7;
            }

            int px = bx * 4 + col;
            int py = by * 4 + row;
            int dst = (py * texWidth + px) * 4;

            int r, g, b;
            switch (ci) {
              case 0: r = r0; g = g0; b = b0; break;
              case 1: r = r1; g = g1; b = b1; break;
              case 2: r = pr2; g = pg2; b = pb2; break;
              default: r = pr3; g = pg3; b = pb3; break;
            }

            output[dst] = r;
            output[dst + 1] = g;
            output[dst + 2] = b;
            output[dst + 3] = alphas[ai];
          }
        }
      }
    }
    return output;
  }

  static Uint8List bc1Encode(Uint8List rgba, int texWidth, int texHeight) {
    int blocksX = texWidth ~/ 4;
    int blocksY = texHeight ~/ 4;
    Uint8List output = Uint8List(blocksX * blocksY * 8);
    Uint8List block = Uint8List(64);

    for (int by = 0; by < blocksY; by++) {
      for (int bx = 0; bx < blocksX; bx++) {
        bool hasAlpha = false;

        for (int row = 0; row < 4; row++) {
          for (int col = 0; col < 4; col++) {
            int px = bx * 4 + col;
            int py = by * 4 + row;
            int src = (py * texWidth + px) * 4;
            int dst = (row * 4 + col) * 4;
            block[dst] = rgba[src];
            block[dst + 1] = rgba[src + 1];
            block[dst + 2] = rgba[src + 2];
            block[dst + 3] = rgba[src + 3];
            if (rgba[src + 3] < 128) hasAlpha = true;
          }
        }
        _bc1EncodeBlock(block, hasAlpha, output, (by * blocksX + bx) * 8);
      }
    }
    return output;
  }

  static void _bc1EncodeBlock(Uint8List block, bool hasAlpha, Uint8List output, int outOffset) {
    int minR = 255, minG = 255, minB = 255;
    int maxR = 0, maxG = 0, maxB = 0;
    int opaqueCount = 0;

    for (int i = 0; i < 16; i++) {
      int off = i * 4;
      if (block[off + 3] < 128) {
        continue;
      }
      opaqueCount++;
      int r = block[off], g = block[off + 1], b = block[off + 2];
      if (r < minR) {
        minR = r;
      }
      if (g < minG) {
        minG = g;
      }
      if (b < minB) {
        minB = b;
      }
      if (r > maxR) {
        maxR = r;
      }
      if (g > maxG) {
        maxG = g;
      }
      if (b > maxB) {
        maxB = b;
      }
    }

    if (opaqueCount == 0) {
      output[outOffset] = 0; output[outOffset + 1] = 0;
      output[outOffset + 2] = 0; output[outOffset + 3] = 0;
      output[outOffset + 4] = 0xFF; output[outOffset + 5] = 0xFF;
      output[outOffset + 6] = 0xFF; output[outOffset + 7] = 0xFF;
      return;
    }

    int c0 = rgb565Encode(maxR, maxG, maxB);
    int c1 = rgb565Encode(minR, minG, minB);

    if (hasAlpha) {
      if (c0 > c1) {
        var t = c0;
        c0 = c1;
        c1 = t;
      }
    } else {
      if (c0 < c1) {
        var t = c0;
        c0 = c1;
        c1 = t;
      }
      if (c0 == c1) {
        if (c0 < 0xFFFF) {
          c0++;
        } else {
          c1--;
        }
      }
    }

    var (r0, g0, b0) = rgb565Decode(c0);
    var (r1, g1, b1) = rgb565Decode(c1);

    int pr2, pg2, pb2, pr3, pg3, pb3;
    bool idx3IsTransparent;

    if (c0 > c1) {
      pr2 = (2 * r0 + r1) ~/ 3; pg2 = (2 * g0 + g1) ~/ 3; pb2 = (2 * b0 + b1) ~/ 3;
      pr3 = (r0 + 2 * r1) ~/ 3; pg3 = (g0 + 2 * g1) ~/ 3; pb3 = (b0 + 2 * b1) ~/ 3;
      idx3IsTransparent = false;
    } else {
      pr2 = (r0 + r1) ~/ 2; pg2 = (g0 + g1) ~/ 2; pb2 = (b0 + b1) ~/ 2;
      pr3 = 0; pg3 = 0; pb3 = 0;
      idx3IsTransparent = true;
    }

    int indices = 0;
    for (int i = 0; i < 16; i++) {
      int off = i * 4;
      int r = block[off], g = block[off + 1], b = block[off + 2], a = block[off + 3];
      int bestIdx;
      if (a < 128 && idx3IsTransparent) {
        bestIdx = 3;
      } else {
        int d0 = colorDistSq(r, g, b, r0, g0, b0);
        int d1 = colorDistSq(r, g, b, r1, g1, b1);
        int d2 = colorDistSq(r, g, b, pr2, pg2, pb2);
        bestIdx = 0;
        int bestDist = d0;
        if (d1 < bestDist) { bestDist = d1; bestIdx = 1; }
        if (d2 < bestDist) { bestDist = d2; bestIdx = 2; }
        if (!idx3IsTransparent) {
          int d3 = colorDistSq(r, g, b, pr3, pg3, pb3);
          if (d3 < bestDist) { bestIdx = 3; }
        }
      }
      indices |= (bestIdx << (2 * i));
    }

    ByteData bd = ByteData.view(output.buffer, output.offsetInBytes, output.length);
    bd.setUint16(outOffset, c0, Endian.little);
    bd.setUint16(outOffset + 2, c1, Endian.little);
    bd.setUint32(outOffset + 4, indices, Endian.little);
  }

  static Uint8List bc3Encode(Uint8List rgba, int texWidth, int texHeight) {
    int blocksX = texWidth ~/ 4;
    int blocksY = texHeight ~/ 4;
    Uint8List output = Uint8List(blocksX * blocksY * 16);
    Uint8List block = Uint8List(64);

    for (int by = 0; by < blocksY; by++) {
      for (int bx = 0; bx < blocksX; bx++) {
        for (int row = 0; row < 4; row++) {
          for (int col = 0; col < 4; col++) {
            int px = bx * 4 + col;
            int py = by * 4 + row;
            int src = (py * texWidth + px) * 4;
            int dst = (row * 4 + col) * 4;
            block[dst] = rgba[src];
            block[dst + 1] = rgba[src + 1];
            block[dst + 2] = rgba[src + 2];
            block[dst + 3] = rgba[src + 3];
          }
        }
        _bc3EncodeBlock(block, output, (by * blocksX + bx) * 16);
      }
    }
    return output;
  }

  static void _bc3EncodeBlock(Uint8List block, Uint8List output, int outOffset) {
    int minA = 255, maxA = 0;
    for (int i = 0; i < 16; i++) {
      int a = block[i * 4 + 3];
      if (a < minA) minA = a;
      if (a > maxA) maxA = a;
    }

    int a0 = maxA, a1 = minA;
    if (minA == maxA) { a0 = maxA; a1 = maxA; }
    output[outOffset] = a0;
    output[outOffset + 1] = a1;

    List<int> alphaPal = List.filled(8, 0);
    alphaPal[0] = a0; alphaPal[1] = a1;
    if (a0 > a1) {
      alphaPal[2] = (6 * a0 + 1 * a1) ~/ 7;
      alphaPal[3] = (5 * a0 + 2 * a1) ~/ 7;
      alphaPal[4] = (4 * a0 + 3 * a1) ~/ 7;
      alphaPal[5] = (3 * a0 + 4 * a1) ~/ 7;
      alphaPal[6] = (2 * a0 + 5 * a1) ~/ 7;
      alphaPal[7] = (1 * a0 + 6 * a1) ~/ 7;
    } else {
      alphaPal[2] = a0; alphaPal[3] = a0; alphaPal[4] = a0; alphaPal[5] = a0;
      alphaPal[6] = 0; alphaPal[7] = 255;
    }

    int alphaIdxBitsLow = 0;
    int alphaIdxBitsHigh = 0;
    for (int i = 0; i < 16; i++) {
      int a = block[i * 4 + 3];
      int bestIdx = 0, bestDist = (a - alphaPal[0]).abs();
      for (int p = 1; p < 8; p++) {
        int d = (a - alphaPal[p]).abs();
        if (d < bestDist) { bestDist = d; bestIdx = p; }
      }
      
      int bitOffset = 3 * i;
      if (bitOffset < 32 - 3) {
        alphaIdxBitsLow |= (bestIdx << bitOffset);
      } else if (bitOffset < 32) {
        alphaIdxBitsLow |= (bestIdx << bitOffset);
        alphaIdxBitsHigh |= (bestIdx >> (32 - bitOffset));
      } else {
        alphaIdxBitsHigh |= (bestIdx << (bitOffset - 32));
      }
    }

    ByteData bd = ByteData.view(output.buffer, output.offsetInBytes, output.length);
    bd.setUint32(outOffset + 2, alphaIdxBitsLow, Endian.little);
    bd.setUint16(outOffset + 6, alphaIdxBitsHigh, Endian.little);

    int minR = 255, minG = 255, minB = 255;
    int maxR = 0, maxG = 0, maxB = 0;
    for (int i = 0; i < 16; i++) {
      int off = i * 4;
      int r = block[off], g = block[off + 1], b = block[off + 2];
      if (r < minR) minR = r;
      if (g < minG) minG = g;
      if (b < minB) minB = b;
      if (r > maxR) maxR = r;
      if (g > maxG) maxG = g;
      if (b > maxB) maxB = b;
    }

    int c0 = rgb565Encode(maxR, maxG, maxB);
    int c1 = rgb565Encode(minR, minG, minB);
    if (c0 < c1) {
      var t = c0;
      c0 = c1;
      c1 = t;
    }
    if (c0 == c1) {
      if (c0 < 0xFFFF) {
        c0++;
      } else {
        c1--;
      }
    }

    var (r0, g0, b0) = rgb565Decode(c0);
    var (r1, g1, b1) = rgb565Decode(c1);
    int pr2 = (2 * r0 + r1) ~/ 3, pg2 = (2 * g0 + g1) ~/ 3, pb2 = (2 * b0 + b1) ~/ 3;
    int pr3 = (r0 + 2 * r1) ~/ 3, pg3 = (g0 + 2 * g1) ~/ 3, pb3 = (b0 + 2 * b1) ~/ 3;

    int colorIndices = 0;
    for (int i = 0; i < 16; i++) {
      int off = i * 4;
      int r = block[off], g = block[off + 1], b = block[off + 2];
      int d0 = colorDistSq(r, g, b, r0, g0, b0);
      int d1 = colorDistSq(r, g, b, r1, g1, b1);
      int d2 = colorDistSq(r, g, b, pr2, pg2, pb2);
      int d3 = colorDistSq(r, g, b, pr3, pg3, pb3);
      int bestIdx = 0, bestDist = d0;
      if (d1 < bestDist) { bestDist = d1; bestIdx = 1; }
      if (d2 < bestDist) { bestDist = d2; bestIdx = 2; }
      if (d3 < bestDist) { bestIdx = 3; }
      colorIndices |= (bestIdx << (2 * i));
    }

    bd.setUint16(outOffset + 8, c0, Endian.little);
    bd.setUint16(outOffset + 10, c1, Endian.little);
    bd.setUint32(outOffset + 12, colorIndices, Endian.little);
  }
}

