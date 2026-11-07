import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as image;
import 'package:material_color_utilities/quantize/quantizer_celebi.dart';
import 'package:material_color_utilities/score/score.dart';

/// Extracts opaque wallpaper colors without decoding on the UI isolate.
abstract final class ThemeImagePalette {
  static const _maxBytes = 20 * 1024 * 1024;
  static const _maxDimension = 8192;
  static const _maxPixels = 16 * 1024 * 1024;
  static const _sampleDimension = 128;

  /// Supports static PNG, JPEG and WebP, regardless of the file extension.
  ///
  /// Invalid images, files above 20 MiB, dimensions above 8192 or images above
  /// 16 megapixels throw [FormatException]. File access errors propagate as
  /// [FileSystemException].
  static Future<Color> seedFromFile(String path) async {
    final argb = await Isolate.run(
      () async => _seedFromBytes(await _readFileBytes(path)),
    );
    return Color(argb);
  }

  /// Fully transparent pixels are ignored. Other pixels retain their RGB
  /// without compositing against a background, so the seed works in both modes.
  static Future<Color> seedFromBytes(Uint8List bytes) async {
    // Reject oversized input before copying it into another isolate.
    _checkByteLength(bytes.length);
    final argb = await Isolate.run(() => _seedFromBytes(bytes));
    return Color(argb);
  }

  /// Returns 1..[maxColors] distinct, opaque representative wallpaper colors.
  ///
  /// Uses the same file limits and supported formats as [seedFromFile]. Colors
  /// come from the image's quantized RGB values, without light/dark adjustments
  /// or padding with generated colors. The order is deterministic.
  /// [maxColors] must be in 1..64; otherwise throws [RangeError].
  static Future<List<Color>> colorsFromFile(
    String path, {
    int maxColors = 8,
  }) async {
    _checkMaxColors(maxColors);
    final argbs = await Isolate.run(
      () async => _colorsFromBytes(await _readFileBytes(path), maxColors),
    );
    return argbs.map(Color.new).toList(growable: false);
  }

  /// Like [colorsFromFile], but reads encoded image bytes.
  ///
  /// Fully transparent pixels are ignored; a fully transparent image is
  /// rejected. Visible pixels retain their RGB with opaque alpha, including
  /// neutral or monochrome colors that theme-seed scoring normally filters.
  static Future<List<Color>> colorsFromBytes(
    Uint8List bytes, {
    int maxColors = 8,
  }) async {
    _checkMaxColors(maxColors);
    _checkByteLength(bytes.length);
    final argbs = await Isolate.run(() => _colorsFromBytes(bytes, maxColors));
    return argbs.map(Color.new).toList(growable: false);
  }

  static void _checkMaxColors(int maxColors) {
    RangeError.checkValueInInterval(maxColors, 1, 64, 'maxColors');
  }

  static Future<Uint8List> _readFileBytes(String path) async {
    final file = await File(path).open();
    try {
      final length = await file.length();
      _checkByteLength(length);
      // Bound the read even if the file grows after checking its length.
      final bytes = await file.read(length);
      if (bytes.length != length) {
        throw const FormatException('背景图片读取不完整');
      }
      return bytes;
    } finally {
      await file.close();
    }
  }

  static void _checkByteLength(int length) {
    if (length == 0 || length > _maxBytes) {
      throw const FormatException('背景图片不能为空或超过 20 MiB');
    }
  }

  static void _checkDimensions(int width, int height) {
    if (width <= 0 ||
        height <= 0 ||
        width > _maxDimension ||
        height > _maxDimension ||
        width * height > _maxPixels) {
      throw const FormatException('背景图片尺寸超过限制');
    }
  }

  static image.Decoder _decoderFor(Uint8List bytes) {
    final png = image.PngDecoder(maxPixels: _maxPixels);
    if (png.isValidFile(bytes)) return png;
    if (bytes.length >= 2 && bytes[0] == 0xff && bytes[1] == 0xd8) {
      return image.JpegDecoder(maxPixels: _maxPixels);
    }
    final webp = image.WebPDecoder()..maxPixels = _maxPixels;
    if (webp.isValidFile(bytes)) return webp;
    throw const FormatException('背景图片仅支持 PNG、JPEG 或 WebP 静态图片');
  }

  static Future<int> _seedFromBytes(Uint8List bytes) async {
    final colors = await _quantizedColorsFromBytes(bytes);
    final dominant = colors.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );
    return Score.score(
      colors,
      desired: 1,
      // Neutral images should keep a color from the image, rather than
      // Score's default Google Blue when every color is filtered out.
      fallbackColorARGB: dominant.key,
    ).first;
  }

  static Future<List<int>> _colorsFromBytes(
    Uint8List bytes,
    int maxColors,
  ) async {
    final colors = await _quantizedColorsFromBytes(bytes);
    // Canonicalize input order so score ties do not depend on quantizer map
    // iteration. Population ties use ARGB as the deterministic tiebreaker.
    final entries = colors.entries.toList()
      ..sort((a, b) {
        final population = b.value.compareTo(a.value);
        return population != 0 ? population : a.key.compareTo(b.key);
      });
    return Score.score(
      Map.fromEntries(entries),
      desired: maxColors,
      filter: false,
      fallbackColorARGB: entries.first.key,
    ).toSet().take(maxColors).toList(growable: false);
  }

  static Future<Map<int, int>> _quantizedColorsFromBytes(
    Uint8List bytes,
  ) async {
    try {
      _checkByteLength(bytes.length);
      final decoder = _decoderFor(bytes);
      // Read dimensions before allocating decoded pixels. Each decoder also
      // enforces its own pixel budget when parsing the actual pixel data.
      final info = decoder.startDecode(bytes);
      if (info == null) throw const FormatException('背景图片已损坏');
      _checkDimensions(info.width, info.height);
      if (info.numFrames > 1 ||
          (info is image.PngInfo && info.isAnimated) ||
          (info is image.WebPInfo && info.hasAnimation)) {
        throw const FormatException('背景图片仅支持静态图片');
      }

      final image.Image? decoded;
      if (decoder is image.JpegDecoder) {
        var scale = 1;
        final dimension = math.max(info.width, info.height);
        while (scale < 8 && dimension ~/ (scale * 2) >= _sampleDimension) {
          scale *= 2;
        }
        decoded = image.JpegDecoder(
          maxPixels: _maxPixels,
          scale: scale,
        ).decode(bytes, frame: 0);
      } else {
        decoded = decoder.decodeFrame(0);
      }
      if (decoded == null) throw const FormatException('背景图片已损坏');
      _checkDimensions(decoded.width, decoded.height);

      final factor = math.min(
        1.0,
        _sampleDimension / math.max(decoded.width, decoded.height),
      );
      final width = math.max(1, (decoded.width * factor).round());
      final height = math.max(1, (decoded.height * factor).round());
      final pixels = <int>[];
      for (var y = 0; y < height; y++) {
        final sourceY = ((y + 0.5) * decoded.height / height).floor();
        for (var x = 0; x < width; x++) {
          final sourceX = ((x + 0.5) * decoded.width / width).floor();
          final argb = _opaqueArgb(decoded.getPixel(sourceX, sourceY));
          if (argb != null) pixels.add(argb);
        }
      }
      // A sparse transparent image may have no visible pixel on the sample
      // grid. Only reject it if the original decoded image is also transparent.
      if (pixels.isEmpty) {
        for (final pixel in decoded) {
          final argb = _opaqueArgb(pixel);
          if (argb != null) {
            pixels.add(argb);
            break;
          }
        }
      }
      if (pixels.isEmpty) throw const FormatException('背景图片中没有可用颜色');

      final result = await QuantizerCelebi().quantize(pixels, 128);
      final colors = result.colorToCount;
      if (colors.isEmpty) throw const FormatException('背景图片中没有可用颜色');
      return colors;
    } on image.ImageException {
      throw const FormatException('背景图片已损坏或尺寸超过限制');
    }
  }

  static int? _opaqueArgb(image.Pixel pixel) {
    if (pixel.aNormalized <= 0) return null;
    final red = (pixel.rNormalized * 255).round().clamp(0, 255);
    final green = (pixel.gNormalized * 255).round().clamp(0, 255);
    final blue = (pixel.bNormalized * 255).round().clamp(0, 255);
    return 0xff000000 | (red << 16) | (green << 8) | blue;
  }
}
