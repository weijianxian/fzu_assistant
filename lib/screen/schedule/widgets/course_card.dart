import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fzu_assistant/service/course_color_palettes.dart';
import 'package:fzu_assistant/service/custom_course_store.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/service/theme_visuals.dart';

class CourseCard extends StatelessWidget {
  final Course course;
  final String location;
  final String? displayName;
  final VoidCallback? onTap;
  final bool isHorizontal;

  const CourseCard({
    super.key,
    required this.course,
    required this.location,
    this.displayName,
    this.onTap,
    this.isHorizontal = false,
  });

  Color _paletteColor(ThemeVisuals? visuals, {required bool dark}) {
    final diy = visuals?.coursePalette;
    if (diy != null && diy.isNotEmpty) {
      return diy[course.name.hashCode.abs() % diy.length];
    }
    final colors = CourseColorPalettes.colors(
      visuals?.coursePaletteKey ?? CourseColorPalettes.tailwind,
      dark: dark,
    );
    return Color(colors[course.name.hashCode.abs() % colors.length]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visuals = theme.extension<ThemeVisuals>();
    final isWindows = !kIsWeb && theme.platform == TargetPlatform.windows;
    if (isHorizontal) return _buildHorizontal(context);
    final customColor = CustomCourseStore.instance.colorForCourse(course);
    final background = customColor != null
        ? Color(customColor)
        : visuals?.color('courseCard') ??
              _paletteColor(visuals, dark: theme.brightness == Brightness.dark);
    final bg = background.withValues(
      alpha: background.a * (visuals?.courseCardOpacity ?? 1),
    );
    final darkBackground =
        ThemeData.estimateBrightnessForColor(
          Color.alphaBlend(bg, theme.colorScheme.surface),
        ) ==
        Brightness.dark;
    final title = Text(
      displayName ?? course.name,
      style: TextStyle(
        fontSize: isWindows ? 13 : 11,
        fontWeight: FontWeight.w600,
        height: isWindows ? 1.3 : null,
        color:
            visuals?.color('courseCardText') ??
            (darkBackground ? Colors.white : Colors.black87),
      ),
      textAlign: TextAlign.center,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
    final locationText = Text(
      location,
      style: TextStyle(
        fontSize: isWindows ? 11 : 9,
        height: isWindows ? 1.3 : null,
        color:
            visuals?.color('courseCardSecondaryText') ??
            (darkBackground ? Colors.white70 : Colors.black54),
      ),
      textAlign: TextAlign.center,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.hardEdge,
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(visuals?.courseCardRadius ?? 8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 单节课程在窄屏及大字体下同样按可用高度截断。
            Flexible(flex: 3, child: title),
            if (location.isNotEmpty) ...[
              const SizedBox(height: 2),
              Flexible(flex: 2, child: locationText),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontal(BuildContext context) {
    final theme = Theme.of(context);
    final visuals = theme.extension<ThemeVisuals>();
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final useTailwindAccent =
        (visuals?.coursePalette.isEmpty ?? true) &&
        (visuals?.coursePaletteKey ?? CourseColorPalettes.tailwind) ==
            CourseColorPalettes.tailwind;
    final customColor = CustomCourseStore.instance.colorForCourse(course);
    // A course's own color keeps its accent and tint when a theme is selected.
    final accent = customColor != null
        ? Color(customColor)
        : visuals?.color('courseAccent') ??
              _paletteColor(
                visuals,
                dark: useTailwindAccent ? !isDark : isDark,
              );
    final themedBackground = customColor == null
        ? visuals?.color('courseCard')
        : null;
    final background =
        themedBackground ??
        Color.alphaBlend(
          accent.withValues(alpha: accent.a * (isDark ? 0.12 : 0.08)),
          scheme.surfaceContainerLow,
        );
    final bg = background.withValues(
      alpha: background.a * (visuals?.courseCardOpacity ?? 1),
    );
    final darkBackground =
        ThemeData.estimateBrightnessForColor(
          Color.alphaBlend(bg, scheme.surface),
        ) ==
        Brightness.dark;
    final needsContrast = darkBackground != isDark;
    final titleColor =
        visuals?.color('courseCardText') ??
        (needsContrast
            ? (darkBackground ? Colors.white : Colors.black87)
            : scheme.onSurface);
    final locationColor =
        visuals?.color('courseCardSecondaryText') ??
        (needsContrast
            ? (darkBackground ? Colors.white70 : Colors.black54)
            : scheme.onSurfaceVariant);

    return Material(
      color: bg,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(visuals?.courseCardRadius ?? 10),
        side: BorderSide(color: accent.withValues(alpha: accent.a * 0.2)),
      ),
      child: InkWell(
        onTap: onTap,
        hoverColor: accent.withValues(alpha: accent.a * 0.08),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 4, child: ColoredBox(color: accent)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      flex: 3,
                      child: Text(
                        displayName ?? course.name,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Flexible(
                        flex: 2,
                        child: Text(
                          location,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: locationColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
