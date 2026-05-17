import 'package:flutter/material.dart';
import 'package:fzu_assistant/model/course.dart';

class CourseCard extends StatelessWidget {
  final Course course;
  final String location;

  // Tailwind CSS 300 级浅色
  static const _lightColors = [
    Color(0xFF7DD3FC), // sky
    Color(0xFF93C5FD), // blue
    Color(0xFFA5B4FC), // indigo
    Color(0xFFC4B5FD), // violet
    Color(0xFFD8B4FE), // purple
    Color(0xFFF0ABFC), // fuchsia
    Color(0xFFF9A8D4), // pink
    Color(0xFFFDA4AF), // rose
    Color(0xFFFDBA74), // orange
    Color(0xFFFCD34D), // amber
    Color(0xFFFDE047), // yellow
    Color(0xFFBEF264), // lime
    Color(0xFF86EFAC), // green
    Color(0xFF6EE7B7), // emerald
    Color(0xFF5EEAD4), // teal
    Color(0xFF67E8F9), // cyan
    Color(0xFFCBD5E1), // slate
    Color(0xFFD1D5DB), // gray
    Color(0xFFD6D3D1), // stone
    Color(0xFFFCA5A5), // red
  ];

  // Tailwind CSS 800 级深色
  static const _darkColors = [
    Color(0xFF075985), // sky
    Color(0xFF1E40AF), // blue
    Color(0xFF3730A3), // indigo
    Color(0xFF5B21B6), // violet
    Color(0xFF6B21A8), // purple
    Color(0xFF86198F), // fuchsia
    Color(0xFF9D174D), // pink
    Color(0xFF9F1239), // rose
    Color(0xFF9A3412), // orange
    Color(0xFF92400E), // amber
    Color(0xFF854D0E), // yellow
    Color(0xFF3F6212), // lime
    Color(0xFF166534), // green
    Color(0xFF065F46), // emerald
    Color(0xFF115E59), // teal
    Color(0xFF155E75), // cyan
    Color(0xFF1E293B), // slate
    Color(0xFF1F2937), // gray
    Color(0xFF292524), // stone
    Color(0xFF991B1B), // red
  ];

  const CourseCard({super.key, required this.course, required this.location});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark ? _darkColors : _lightColors;
    final bg = colors[course.name.hashCode.abs() % colors.length];

    return Container(
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            course.name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              location,
              style: TextStyle(
                fontSize: 9,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
