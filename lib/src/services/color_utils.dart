import 'dart:math' as math;
import 'dart:typed_data';

class ColorUtils {
  static final Uint8List srgbToLinearLut = _buildSrgbToLinearLut();
  static final Uint8List linearToSrgbLut = _buildLinearToSrgbLut();

  static Uint8List _buildSrgbToLinearLut() {
    final lut = Uint8List(256);
    for (int i = 0; i < 256; i++) {
      double s = i / 255.0;
      double lin = s <= 0.04045 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
      lut[i] = (lin * 255.0).round().clamp(0, 255);
    }
    return lut;
  }

  static Uint8List _buildLinearToSrgbLut() {
    final lut = Uint8List(256);
    for (int i = 0; i < 256; i++) {
      double lin = i / 255.0;
      double s = lin <= 0.0031308 ? lin * 12.92 : 1.055 * math.pow(lin, 1.0 / 2.4).toDouble() - 0.055;
      lut[i] = (s * 255.0).round().clamp(0, 255);
    }
    return lut;
  }

  static void convertSrgbToLinear(Uint8List rgba) {
    for (int i = 0; i < rgba.length; i += 4) {
      rgba[i] = srgbToLinearLut[rgba[i]];
      rgba[i + 1] = srgbToLinearLut[rgba[i + 1]];
      rgba[i + 2] = srgbToLinearLut[rgba[i + 2]];
    }
  }

  static void convertLinearToSrgb(Uint8List rgba) {
    for (int i = 0; i < rgba.length; i += 4) {
      rgba[i] = linearToSrgbLut[rgba[i]];
      rgba[i + 1] = linearToSrgbLut[rgba[i + 1]];
      rgba[i + 2] = linearToSrgbLut[rgba[i + 2]];
    }
  }
}
