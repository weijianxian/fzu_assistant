import 'package:flutter/material.dart';
import 'package:fzu_assistant/service/course_color_palettes.dart';

/// Colors outside ColorScheme belong to the timetable, not to a global tint.
class ThemeVisuals extends ThemeExtension<ThemeVisuals> {
  const ThemeVisuals({
    this.colors = const {},
    this.coursePaletteKey = CourseColorPalettes.tailwind,
    this.coursePalette = const [],
    this.backgroundImage,
    this.backgroundDim = 0,
    this.backgroundBlur = 0,
    this.surfaceOpacity = 0.9,
    this.cardRadius = 24,
    this.courseCardRadius = 8,
    this.courseCardOpacity = 1,
    this.dividerWidth = 1,
  });

  final Map<String, Color> colors;
  final String coursePaletteKey;
  final List<Color> coursePalette;
  final String? backgroundImage;
  final double backgroundDim, backgroundBlur, surfaceOpacity;
  final double cardRadius, courseCardRadius, courseCardOpacity, dividerWidth;

  bool get hasBackground => backgroundImage?.isNotEmpty == true;
  Color? color(String key) => colors[key];
  static ThemeVisuals of(BuildContext context) =>
      Theme.of(context).extension<ThemeVisuals>() ?? const ThemeVisuals();

  @override
  ThemeVisuals copyWith({
    Map<String, Color>? colors,
    String? coursePaletteKey,
    List<Color>? coursePalette,
    String? backgroundImage,
    double? backgroundDim,
    double? backgroundBlur,
    double? surfaceOpacity,
    double? cardRadius,
    double? courseCardRadius,
    double? courseCardOpacity,
    double? dividerWidth,
  }) => ThemeVisuals(
    colors: colors ?? this.colors,
    coursePaletteKey: coursePaletteKey ?? this.coursePaletteKey,
    coursePalette: coursePalette ?? this.coursePalette,
    backgroundImage: backgroundImage ?? this.backgroundImage,
    backgroundDim: backgroundDim ?? this.backgroundDim,
    backgroundBlur: backgroundBlur ?? this.backgroundBlur,
    surfaceOpacity: surfaceOpacity ?? this.surfaceOpacity,
    cardRadius: cardRadius ?? this.cardRadius,
    courseCardRadius: courseCardRadius ?? this.courseCardRadius,
    courseCardOpacity: courseCardOpacity ?? this.courseCardOpacity,
    dividerWidth: dividerWidth ?? this.dividerWidth,
  );

  @override
  ThemeVisuals lerp(covariant ThemeVisuals? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

abstract final class ThemeColors {
  static Map<String, Color> fromScheme(ColorScheme s) => {
    'primary': s.primary,
    'onPrimary': s.onPrimary,
    'primaryContainer': s.primaryContainer,
    'onPrimaryContainer': s.onPrimaryContainer,
    'secondary': s.secondary,
    'onSecondary': s.onSecondary,
    'secondaryContainer': s.secondaryContainer,
    'onSecondaryContainer': s.onSecondaryContainer,
    'tertiary': s.tertiary,
    'onTertiary': s.onTertiary,
    'tertiaryContainer': s.tertiaryContainer,
    'onTertiaryContainer': s.onTertiaryContainer,
    'error': s.error,
    'onError': s.onError,
    'errorContainer': s.errorContainer,
    'onErrorContainer': s.onErrorContainer,
    'surface': s.surface,
    'onSurface': s.onSurface,
    'onSurfaceVariant': s.onSurfaceVariant,
    'surfaceDim': s.surfaceDim,
    'surfaceBright': s.surfaceBright,
    'surfaceContainerLowest': s.surfaceContainerLowest,
    'surfaceContainerLow': s.surfaceContainerLow,
    'surfaceContainer': s.surfaceContainer,
    'surfaceContainerHigh': s.surfaceContainerHigh,
    'surfaceContainerHighest': s.surfaceContainerHighest,
    'outline': s.outline,
    'outlineVariant': s.outlineVariant,
    'shadow': s.shadow,
    'scrim': s.scrim,
    'inverseSurface': s.inverseSurface,
    'onInverseSurface': s.onInverseSurface,
    'inversePrimary': s.inversePrimary,
    'surfaceTint': s.surfaceTint,
    'primaryFixed': s.primaryFixed,
    'primaryFixedDim': s.primaryFixedDim,
    'onPrimaryFixed': s.onPrimaryFixed,
    'onPrimaryFixedVariant': s.onPrimaryFixedVariant,
    'secondaryFixed': s.secondaryFixed,
    'secondaryFixedDim': s.secondaryFixedDim,
    'onSecondaryFixed': s.onSecondaryFixed,
    'onSecondaryFixedVariant': s.onSecondaryFixedVariant,
    'tertiaryFixed': s.tertiaryFixed,
    'tertiaryFixedDim': s.tertiaryFixedDim,
    'onTertiaryFixed': s.onTertiaryFixed,
    'onTertiaryFixedVariant': s.onTertiaryFixedVariant,
  };

  static ColorScheme apply(ColorScheme s, Map<String, Color> c) => s.copyWith(
    primary: c['primary'],
    onPrimary: c['onPrimary'],
    primaryContainer: c['primaryContainer'],
    onPrimaryContainer: c['onPrimaryContainer'],
    secondary: c['secondary'],
    onSecondary: c['onSecondary'],
    secondaryContainer: c['secondaryContainer'],
    onSecondaryContainer: c['onSecondaryContainer'],
    tertiary: c['tertiary'],
    onTertiary: c['onTertiary'],
    tertiaryContainer: c['tertiaryContainer'],
    onTertiaryContainer: c['onTertiaryContainer'],
    error: c['error'],
    onError: c['onError'],
    errorContainer: c['errorContainer'],
    onErrorContainer: c['onErrorContainer'],
    surface: c['surface'],
    onSurface: c['onSurface'],
    onSurfaceVariant: c['onSurfaceVariant'],
    surfaceDim: c['surfaceDim'],
    surfaceBright: c['surfaceBright'],
    surfaceContainerLowest: c['surfaceContainerLowest'],
    surfaceContainerLow: c['surfaceContainerLow'],
    surfaceContainer: c['surfaceContainer'],
    surfaceContainerHigh: c['surfaceContainerHigh'],
    surfaceContainerHighest: c['surfaceContainerHighest'],
    outline: c['outline'],
    outlineVariant: c['outlineVariant'],
    shadow: c['shadow'],
    scrim: c['scrim'],
    inverseSurface: c['inverseSurface'],
    onInverseSurface: c['onInverseSurface'],
    inversePrimary: c['inversePrimary'],
    surfaceTint: c['surfaceTint'],
    primaryFixed: c['primaryFixed'],
    primaryFixedDim: c['primaryFixedDim'],
    onPrimaryFixed: c['onPrimaryFixed'],
    onPrimaryFixedVariant: c['onPrimaryFixedVariant'],
    secondaryFixed: c['secondaryFixed'],
    secondaryFixedDim: c['secondaryFixedDim'],
    onSecondaryFixed: c['onSecondaryFixed'],
    onSecondaryFixedVariant: c['onSecondaryFixedVariant'],
    tertiaryFixed: c['tertiaryFixed'],
    tertiaryFixedDim: c['tertiaryFixedDim'],
    onTertiaryFixed: c['onTertiaryFixed'],
    onTertiaryFixedVariant: c['onTertiaryFixedVariant'],
  );
}
