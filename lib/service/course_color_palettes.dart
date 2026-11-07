/// Built-in timetable palettes, shared by theme editing and course cards.
abstract final class CourseColorPalettes {
  static const tailwind = 'tailwind';
  static const fuu = 'fuu';
  static const keys = {tailwind, fuu};
  static const maxColors = 64;

  static List<int> colors(String key, {required bool dark}) => switch (key) {
    fuu => dark ? _fuuDark : _fuu,
    _ => dark ? _tailwindDark : _tailwindLight,
  };

  // The application's original Tailwind 300 / 800 course colors.
  static const _tailwindLight = [
    0xFF7DD3FC,
    0xFF93C5FD,
    0xFFA5B4FC,
    0xFFC4B5FD,
    0xFFD8B4FE,
    0xFFF0ABFC,
    0xFFF9A8D4,
    0xFFFDA4AF,
    0xFFFDBA74,
    0xFFFCD34D,
    0xFFFDE047,
    0xFFBEF264,
    0xFF86EFAC,
    0xFF6EE7B7,
    0xFF5EEAD4,
    0xFF67E8F9,
    0xFFCBD5E1,
    0xFFD1D5DB,
    0xFFD6D3D1,
    0xFFFCA5A5,
  ];
  static const _tailwindDark = [
    0xFF075985,
    0xFF1E40AF,
    0xFF3730A3,
    0xFF5B21B6,
    0xFF6B21A8,
    0xFF86198F,
    0xFF9D174D,
    0xFF9F1239,
    0xFF9A3412,
    0xFF92400E,
    0xFF854D0E,
    0xFF3F6212,
    0xFF166534,
    0xFF065F46,
    0xFF115E59,
    0xFF155E75,
    0xFF1E293B,
    0xFF1F2937,
    0xFF292524,
    0xFF991B1B,
  ];

  // FUU: west2-online/fzuhelper-app, utils/random-color.ts, courseColors.
  // Its dark mode keeps the same RGB values with C0 alpha.
  static const _fuu = [
    0xFF7A6068,
    0xFF8D5270,
    0xFF5A9DBD,
    0xFF307D81,
    0xFFB99799,
    0xFFAA9CC6,
    0xFFA2CAE7,
    0xFF619AA0,
    0xFFD8B4BB,
    0xFFE5B9D3,
    0xFF5BB3DD,
    0xFF94C096,
    0xFFD07A88,
    0xFFF0C4A9,
    0xFF92BAC5,
    0xFF9AD1CD,
    0xFFF39E9D,
    0xFFE0B092,
    0xFF7D89AB,
    0xFFBBD5B4,
    0xFFC6A5B6,
    0xFF87B9C1,
    0xFFE3A8A1,
    0xFFA5C7A6,
    0xFFD4B8CE,
  ];
  static final _fuuDark = List<int>.unmodifiable(
    _fuu.map((color) => (color & 0x00FFFFFF) | 0xC0000000),
  );
}
