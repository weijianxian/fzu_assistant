import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/service/theme_image_palette.dart';
import 'package:image/image.dart' as image;

image.Image _solid(int red, int green, int blue, {int alpha = 255}) =>
    image.Image(width: 16, height: 16, numChannels: 4)
      ..clear(image.ColorRgba8(red, green, blue, alpha));

Uint8List _png(image.Image source) => image.encodePng(source);

image.Image _stripes(List<Color> colors) {
  final source = image.Image(
    width: colors.length * 64,
    height: 64,
    numChannels: 4,
  );
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      final argb = colors[x ~/ 64].toARGB32();
      source.setPixelRgba(
        x,
        y,
        (argb >> 16) & 0xff,
        (argb >> 8) & 0xff,
        argb & 0xff,
        (argb >> 24) & 0xff,
      );
    }
  }
  return source;
}

// Change only the dimensions of a real encoded JPEG. This creates a tiny
// oversized-header fixture without allocating the advertised pixel buffer.
Uint8List _oversizedJpeg(int width, int height) {
  final bytes = image.encodeJpg(_solid(255, 0, 0));
  for (var i = 0; i < bytes.length - 8; i++) {
    if (bytes[i] == 0xff && bytes[i + 1] == 0xc0) {
      final data = ByteData.sublistView(bytes);
      data.setUint16(i + 5, height);
      data.setUint16(i + 7, width);
      return bytes;
    }
  }
  throw StateError('JPEG fixture has no baseline frame header');
}

void main() {
  group('colorsFromBytes', () {
    const primaryColors = [
      Color(0xffff0000),
      Color(0xff00ff00),
      Color(0xff0000ff),
    ];

    test('returns distinct image colors in deterministic order', () async {
      final bytes = _png(_stripes(primaryColors));
      final colors = await ThemeImagePalette.colorsFromBytes(bytes);

      expect(colors, unorderedEquals(primaryColors));
      expect(colors.toSet(), hasLength(colors.length));
      expect(colors.every((color) => color.a == 1), isTrue);
      for (var i = 0; i < 3; i++) {
        expect(await ThemeImagePalette.colorsFromBytes(bytes), colors);
      }
    });

    for (final maxColors in [1, 2, 3, 8, 64]) {
      test('respects the requested limit of $maxColors colors', () async {
        final colors = await ThemeImagePalette.colorsFromBytes(
          _png(_stripes(primaryColors)),
          maxColors: maxColors,
        );
        expect(colors.length, inInclusiveRange(1, maxColors));
        expect(colors.toSet(), hasLength(colors.length));
        expect(colors.every(primaryColors.contains), isTrue);
        if (maxColors <= primaryColors.length) {
          expect(colors, hasLength(maxColors));
        } else {
          expect(colors, hasLength(primaryColors.length));
        }
      });
    }

    for (final channel in [0, 128, 255]) {
      test('keeps a solid neutral image at gray level $channel', () async {
        final colors = await ThemeImagePalette.colorsFromBytes(
          _png(_solid(channel, channel, channel)),
          maxColors: 64,
        );
        expect(colors, [Color.fromARGB(255, channel, channel, channel)]);
      });
    }

    test('keeps grayscale representatives without default blue', () async {
      const grays = [Color(0xff000000), Color(0xff808080), Color(0xffffffff)];
      final colors = await ThemeImagePalette.colorsFromBytes(
        _png(_stripes(grays)),
      );
      expect(colors, isNotEmpty);
      expect(colors.every(grays.contains), isTrue);
      expect(colors.toSet(), hasLength(colors.length));
    });

    for (final alpha in [1, 128, 255]) {
      test('returns one opaque solid color for alpha $alpha', () async {
        final colors = await ThemeImagePalette.colorsFromBytes(
          _png(_solid(0, 255, 0, alpha: alpha)),
        );
        expect(colors, [const Color(0xff00ff00)]);
      });
    }

    test('ignores hidden RGB and finds sparse visible pixels', () async {
      final source = image.Image(width: 256, height: 256, numChannels: 4)
        ..clear(image.ColorRgba8(255, 0, 0, 0))
        ..setPixelRgba(0, 0, 0, 255, 0, 128);
      final colors = await ThemeImagePalette.colorsFromBytes(_png(source));
      expect(colors, [const Color(0xff00ff00)]);
    });

    test('rejects a fully transparent image', () async {
      await expectLater(
        ThemeImagePalette.colorsFromBytes(_png(_solid(255, 0, 0, alpha: 0))),
        throwsFormatException,
      );
    });

    for (final maxColors in [-1, 0, 65]) {
      test('rejects an invalid color limit of $maxColors', () async {
        await expectLater(
          ThemeImagePalette.colorsFromBytes(
            _png(_solid(255, 0, 0)),
            maxColors: maxColors,
          ),
          throwsRangeError,
        );
      });
    }

    test('accepts static JPEG and WebP using the shared decoder', () async {
      final jpeg = await ThemeImagePalette.colorsFromBytes(
        image.encodeJpg(_solid(255, 0, 0), quality: 100),
      );
      expect(jpeg, hasLength(1));
      expect(jpeg.single.r, greaterThan(0.95));
      expect(jpeg.single.g, lessThan(0.03));
      expect(jpeg.single.b, lessThan(0.03));
      expect(jpeg.single.a, 1);
      expect(
        await ThemeImagePalette.colorsFromBytes(
          image.encodeWebP(_solid(0, 255, 0)),
        ),
        [const Color(0xff00ff00)],
      );
    });

    test('retains format, animation, dimension and byte limits', () async {
      final valid = _png(_solid(255, 0, 0));
      final animated = _solid(255, 0, 0)..addFrame(_solid(0, 0, 255));
      final wide = image.Image(width: 8193, height: 1)
        ..clear(image.ColorRgb8(255, 0, 0));
      for (final bytes in [
        Uint8List(0),
        Uint8List.fromList([0, 1, 2, 3]),
        Uint8List.sublistView(valid, 0, valid.length ~/ 2),
        _png(animated),
        _png(wide),
        _oversizedJpeg(5000, 4000),
        Uint8List(20 * 1024 * 1024 + 1),
      ]) {
        await expectLater(
          ThemeImagePalette.colorsFromBytes(bytes),
          throwsFormatException,
        );
      }
    });
  });

  group('seedFromBytes', () {
    test('extracts the seed from a real solid PNG', () async {
      final seed = await ThemeImagePalette.seedFromBytes(
        _png(_solid(255, 0, 0)),
      );
      expect(seed, const Color(0xffff0000));
    });

    test('preserves the dominant hue when sampling a two-color PNG', () async {
      final source = image.Image(width: 384, height: 192, numChannels: 4)
        ..clear(image.ColorRgba8(0, 0, 255, 255));
      for (var y = 0; y < source.height; y++) {
        for (var x = 0; x < source.width ~/ 4; x++) {
          source.setPixelRgba(x, y, 255, 0, 0, 255);
        }
      }

      final seed = await ThemeImagePalette.seedFromBytes(_png(source));
      expect(seed, const Color(0xff0000ff));
    });

    for (final alpha in [1, 128, 255]) {
      test('keeps visible RGB opaque with source alpha $alpha', () async {
        final seed = await ThemeImagePalette.seedFromBytes(
          _png(_solid(0, 255, 0, alpha: alpha)),
        );
        expect(seed, const Color(0xff00ff00));
      });
    }

    test('ignores hidden RGB in fully transparent pixels', () async {
      final source = _solid(255, 0, 0, alpha: 0);
      for (var y = 0; y < source.height; y++) {
        for (var x = 0; x < 4; x++) {
          source.setPixelRgba(x, y, 0, 0, 255, 255);
        }
      }

      final seed = await ThemeImagePalette.seedFromBytes(_png(source));
      expect(seed, const Color(0xff0000ff));
    });

    test(
      'finds sparse visible pixels outside the thumbnail sample grid',
      () async {
        final source = image.Image(width: 256, height: 256, numChannels: 4)
          ..clear(image.ColorRgba8(255, 0, 0, 0))
          ..setPixelRgba(0, 0, 0, 255, 0, 255);

        final seed = await ThemeImagePalette.seedFromBytes(_png(source));
        expect(seed, const Color(0xff00ff00));
      },
    );

    test(
      'rejects an entirely transparent PNG with a FormatException',
      () async {
        await expectLater(
          ThemeImagePalette.seedFromBytes(_png(_solid(255, 0, 0, alpha: 0))),
          throwsFormatException,
        );
      },
    );

    test(
      'keeps neutral image colors instead of an unrelated fallback',
      () async {
        final seed = await ThemeImagePalette.seedFromBytes(
          _png(_solid(128, 128, 128)),
        );
        expect(seed, const Color(0xff808080));
      },
    );

    test('accepts real static JPEG data', () async {
      final seed = await ThemeImagePalette.seedFromBytes(
        image.encodeJpg(_solid(255, 0, 0), quality: 100),
      );
      expect(seed.r, greaterThan(0.95));
      expect(seed.g, lessThan(0.03));
      expect(seed.b, lessThan(0.03));
      expect(seed.a, 1);
    });

    test('accepts real static WebP data', () async {
      final seed = await ThemeImagePalette.seedFromBytes(
        image.encodeWebP(_solid(0, 255, 0)),
      );
      expect(seed, const Color(0xff00ff00));
    });

    test('rejects animated PNG instead of decoding all frames', () async {
      final source = _solid(255, 0, 0)..addFrame(_solid(0, 0, 255));
      await expectLater(
        ThemeImagePalette.seedFromBytes(_png(source)),
        throwsFormatException,
      );
    });

    test('rejects empty, unrecognized and truncated image bytes', () async {
      final valid = _png(_solid(255, 0, 0));
      for (final bytes in [
        Uint8List(0),
        Uint8List.fromList([0, 1, 2, 3]),
        Uint8List.sublistView(valid, 0, valid.length ~/ 2),
      ]) {
        await expectLater(
          ThemeImagePalette.seedFromBytes(bytes),
          throwsFormatException,
        );
      }
    });

    test('rejects a valid PNG whose edge exceeds 8192 pixels', () async {
      final source = image.Image(width: 8193, height: 1)
        ..clear(image.ColorRgb8(255, 0, 0));
      await expectLater(
        ThemeImagePalette.seedFromBytes(_png(source)),
        throwsFormatException,
      );
    });

    test('rejects oversized JPEG metadata before pixel decoding', () async {
      final bytes = _oversizedJpeg(5000, 4000);
      final info = image.JpegDecoder().startDecode(bytes);
      expect(info?.width, 5000);
      expect(info?.height, 4000);

      await expectLater(
        ThemeImagePalette.seedFromBytes(bytes),
        throwsFormatException,
      );
    });

    test('rejects encoded bytes larger than 20 MiB', () async {
      await expectLater(
        ThemeImagePalette.seedFromBytes(Uint8List(20 * 1024 * 1024 + 1)),
        throwsFormatException,
      );
    });
  });

  group('seedFromFile', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('fzu-theme-palette-');
    });

    tearDown(() async {
      await directory.delete(recursive: true);
    });

    test('reads and decodes by content rather than extension', () async {
      final file = File('${directory.path}/背景.data');
      await file.writeAsBytes(_png(_solid(0, 0, 255)));

      final seed = await ThemeImagePalette.seedFromFile(file.path);
      expect(seed, const Color(0xff0000ff));
    });

    test('rejects a damaged file with a FormatException', () async {
      final file = File('${directory.path}/broken.png');
      await file.writeAsString('not an image');
      await expectLater(
        ThemeImagePalette.seedFromFile(file.path),
        throwsFormatException,
      );
    });

    test('checks file length before reading oversized data', () async {
      final file = File('${directory.path}/oversized.png');
      final handle = await file.open(mode: FileMode.write);
      try {
        await handle.truncate(20 * 1024 * 1024 + 1);
      } finally {
        await handle.close();
      }

      await expectLater(
        ThemeImagePalette.seedFromFile(file.path),
        throwsFormatException,
      );
    });

    test('preserves file access errors for a missing file', () async {
      await expectLater(
        ThemeImagePalette.seedFromFile('${directory.path}/missing.png'),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('colorsFromFile', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('fzu-theme-colors-');
    });

    tearDown(() async {
      await directory.delete(recursive: true);
    });

    test(
      'reads by content and matches the bytes API with the same limit',
      () async {
        final file = File('${directory.path}/壁纸.data');
        final bytes = _png(
          _stripes(const [
            Color(0xffff0000),
            Color(0xff00ff00),
            Color(0xff0000ff),
          ]),
        );
        await file.writeAsBytes(bytes);
        final colors = await ThemeImagePalette.colorsFromFile(
          file.path,
          maxColors: 2,
        );
        expect(colors, hasLength(2));
        expect(
          colors,
          await ThemeImagePalette.colorsFromBytes(bytes, maxColors: 2),
        );
      },
    );

    test('rejects damaged and fully transparent files', () async {
      final file = File('${directory.path}/invalid.png');
      for (final bytes in [
        Uint8List.fromList([0, 1, 2, 3]),
        _png(_solid(255, 0, 0, alpha: 0)),
      ]) {
        await file.writeAsBytes(bytes);
        await expectLater(
          ThemeImagePalette.colorsFromFile(file.path),
          throwsFormatException,
        );
      }
    });

    test('checks file length before reading oversized data', () async {
      final file = File('${directory.path}/oversized.png');
      final handle = await file.open(mode: FileMode.write);
      try {
        await handle.truncate(20 * 1024 * 1024 + 1);
      } finally {
        await handle.close();
      }
      await expectLater(
        ThemeImagePalette.colorsFromFile(file.path),
        throwsFormatException,
      );
    });

    test('preserves missing-file errors', () async {
      await expectLater(
        ThemeImagePalette.colorsFromFile('${directory.path}/missing.png'),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('validates color limits before attempting file access', () async {
      for (final maxColors in [-1, 0, 65]) {
        await expectLater(
          ThemeImagePalette.colorsFromFile(
            '${directory.path}/missing.png',
            maxColors: maxColors,
          ),
          throwsRangeError,
        );
      }
    });
  });
}
