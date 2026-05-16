import 'dart:typed_data';
import 'package:image/image.dart' as img;

class CaptchaSolver {
  // 四个数字区域的坐标 (x, y, w=6, h=10)
  static const _regions = [
    (x: 2, y: 0),
    (x: 12, y: 0),
    (x: 32, y: 0),
    (x: 42, y: 0),
  ];
  static const _w = 6;
  static const _h = 10;

  /// 识别验证码图片，返回计算结果（如 "12+34" 返回 46）
  static int? solve(Uint8List imageBytes) {
    final image = img.decodeImage(imageBytes);
    if (image == null) return null;

    final rgba = image.convert(format: img.Format.uint8, numChannels: 4);

    final matrices = _regions
        .map((r) => _processRegion(rgba, r.x, r.y, _w, _h))
        .toList();

    final results = matrices.map((m) => _recognizeDigit(m)).toList();

    final val1 = results[0] * 10 + results[1];
    final val2 = results[2] * 10 + results[3];
    return val1 + val2;
  }

  /// 提取区域并二值化
  static List<List<int>> _processRegion(
    img.Image image,
    int x,
    int y,
    int w,
    int h,
  ) {
    final matrix = <List<int>>[];
    for (int r = 0; r < h; r++) {
      final row = <int>[];
      for (int c = 0; c < w; c++) {
        final pixel = image.getPixel(x + c, y + r);
        final gray = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b)
            .round();
        row.add(gray < 140 ? 0 : 255);
      }
      matrix.add(row);
    }
    return matrix;
  }

  /// 模板匹配识别单个数字
  static int _recognizeDigit(List<List<int>> matrix) {
    double maxScore = -1;
    int bestNum = 0;

    for (final entry in _templates.entries) {
      final score = _matchWithJitter(matrix, entry.value);
      if (score > maxScore) {
        maxScore = score;
        bestNum = entry.key;
      }
    }

    return bestNum;
  }

  /// 抖动匹配：在 X/Y 方向偏移 -1, 0, 1 像素，取最大重合度
  static double _matchWithJitter(
    List<List<int>> target,
    List<List<int>> template,
  ) {
    final rows = target.length;
    final cols = target[0].length;
    double maxOverlap = 0;

    const offsets = [
      [0, 0],
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1],
    ];

    for (final offset in offsets) {
      final dx = offset[0];
      final dy = offset[1];
      int sameCount = 0;

      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          final tr = r + dy;
          final tc = c + dx;

          if (tr >= 0 && tr < rows && tc >= 0 && tc < cols) {
            if (target[r][c] == template[tr][tc]) {
              sameCount++;
            }
          } else {
            // 边界外默认为背景色(255)
            if (target[r][c] == 255) {
              sameCount++;
            }
          }
        }
      }

      final score = sameCount / (rows * cols);
      if (score > maxOverlap) maxOverlap = score;
    }

    return maxOverlap;
  }

  // 数字模板 (0-8)
  static final _templates = <int, List<List<int>>>{
    0: [
      [255, 0, 0, 0, 0, 255],
      [0, 255, 255, 255, 255, 0],
      [0, 255, 255, 255, 255, 0],
      [0, 255, 0, 0, 255, 0],
      [0, 255, 0, 0, 255, 0],
      [0, 255, 0, 0, 255, 0],
      [0, 255, 0, 0, 255, 0],
      [0, 255, 255, 255, 255, 0],
      [0, 255, 255, 255, 255, 0],
      [255, 0, 0, 0, 0, 255],
    ],
    1: [
      [255, 255, 0, 255, 255, 255],
      [0, 0, 0, 255, 255, 255],
      [255, 255, 0, 255, 255, 255],
      [255, 255, 0, 255, 255, 255],
      [255, 255, 0, 255, 255, 255],
      [255, 255, 0, 255, 255, 255],
      [255, 255, 0, 255, 255, 255],
      [255, 255, 0, 255, 255, 255],
      [255, 255, 0, 255, 255, 255],
      [0, 0, 0, 0, 0, 255],
    ],
    2: [
      [255, 0, 0, 0, 0, 255],
      [0, 255, 255, 255, 255, 0],
      [0, 255, 255, 255, 255, 0],
      [255, 255, 255, 255, 255, 0],
      [255, 255, 255, 255, 0, 255],
      [255, 255, 255, 0, 255, 255],
      [255, 255, 0, 255, 255, 255],
      [255, 0, 255, 255, 255, 255],
      [0, 255, 255, 255, 255, 0],
      [0, 0, 0, 0, 0, 0],
    ],
    3: [
      [255, 0, 0, 0, 0, 255],
      [0, 255, 255, 255, 255, 0],
      [0, 255, 255, 255, 255, 0],
      [255, 255, 255, 255, 0, 255],
      [255, 255, 0, 0, 255, 255],
      [255, 255, 255, 255, 0, 255],
      [255, 255, 255, 255, 255, 0],
      [0, 255, 255, 255, 255, 0],
      [0, 255, 255, 255, 255, 0],
      [255, 0, 0, 0, 0, 255],
    ],
    4: [
      [255, 255, 255, 0, 255, 255],
      [255, 255, 255, 0, 255, 255],
      [255, 255, 0, 0, 255, 255],
      [255, 0, 255, 0, 255, 255],
      [0, 255, 255, 0, 255, 255],
      [0, 255, 255, 0, 255, 255],
      [0, 0, 0, 0, 0, 0],
      [255, 255, 255, 0, 255, 255],
      [255, 255, 255, 0, 255, 255],
      [255, 255, 0, 0, 0, 0],
    ],
    5: [
      [0, 0, 0, 0, 0, 0],
      [0, 255, 255, 255, 255, 255],
      [0, 255, 255, 255, 255, 255],
      [0, 255, 0, 0, 0, 255],
      [0, 0, 255, 255, 255, 0],
      [255, 255, 255, 255, 255, 0],
      [255, 255, 255, 255, 255, 0],
      [0, 255, 255, 255, 255, 0],
      [0, 255, 255, 255, 255, 0],
      [255, 0, 0, 0, 0, 255],
    ],
    6: [
      [255, 255, 0, 0, 0, 255],
      [255, 0, 255, 255, 255, 0],
      [0, 255, 255, 255, 255, 255],
      [0, 255, 255, 255, 255, 255],
      [0, 255, 0, 0, 0, 255],
      [0, 0, 255, 255, 255, 0],
      [0, 255, 255, 255, 255, 0],
      [0, 255, 255, 255, 255, 0],
      [0, 255, 255, 255, 255, 0],
      [255, 0, 0, 0, 0, 255],
    ],
    7: [
      [0, 0, 0, 0, 0, 0],
      [0, 255, 255, 255, 0, 255],
      [0, 255, 255, 255, 0, 255],
      [255, 255, 255, 0, 255, 255],
      [255, 255, 255, 0, 255, 255],
      [255, 255, 0, 255, 255, 255],
      [255, 255, 0, 255, 255, 255],
      [255, 255, 0, 255, 255, 255],
      [255, 255, 0, 255, 255, 255],
      [255, 255, 0, 255, 255, 255],
    ],
    8: [
      [255, 0, 0, 0, 0, 255],
      [0, 255, 255, 255, 255, 0],
      [0, 255, 255, 255, 255, 0],
      [0, 255, 255, 255, 255, 0],
      [255, 0, 0, 0, 0, 255],
      [255, 0, 255, 255, 0, 255],
      [0, 255, 255, 255, 255, 0],
      [0, 255, 255, 255, 255, 0],
      [0, 255, 255, 255, 255, 0],
      [255, 0, 0, 0, 0, 255],
    ],
  };
}
