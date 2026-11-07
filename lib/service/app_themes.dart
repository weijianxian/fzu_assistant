import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fzu_assistant/common/widget/layout/theme_page_transitions.dart';
import 'package:fzu_assistant/service/theme_visuals.dart';

enum InterfaceStyle {
  classic,
  cards,
  continuousCards;

  bool get isCard => this != classic;

  static InterfaceStyle parse(String? value) =>
      values.where((style) => style.name == value).firstOrNull ?? cards;
}

/// Layout preference shared by seeded and system colors, independent of mode.
class InterfaceTheme extends ThemeExtension<InterfaceTheme> {
  const InterfaceTheme({this.style = InterfaceStyle.cards});

  final InterfaceStyle style;

  static InterfaceTheme of(BuildContext context) =>
      Theme.of(context).extension<InterfaceTheme>() ?? const InterfaceTheme();

  @override
  InterfaceTheme copyWith({InterfaceStyle? style}) =>
      InterfaceTheme(style: style ?? this.style);

  @override
  InterfaceTheme lerp(covariant InterfaceTheme? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

class ThemeConfig {
  final String key;
  final String name;
  final Color color;
  const ThemeConfig(this.key, this.name, this.color);
}

const appThemes = [
  ThemeConfig('deep_purple', '深紫', Color(0xFF673AB7)),
  ThemeConfig('blue', '蓝色', Color(0xFF2196F3)),
  ThemeConfig('teal', '青色', Color(0xFF009688)),
  ThemeConfig('green', '绿色', Color(0xFF4CAF50)),
  ThemeConfig('orange', '橙色', Color(0xFFFF9800)),
  ThemeConfig('red', '红色', Color(0xFFF44336)),
  ThemeConfig('pink', '粉色', Color(0xFFE91E63)),
  ThemeConfig('indigo', '靛蓝', Color(0xFF3F51B5)),
  ThemeConfig('brown', '棕色', Color(0xFF795548)),
];

ThemeData buildTheme(
  Color seedColor, {
  Brightness brightness = Brightness.light,
  InterfaceStyle interfaceStyle = InterfaceStyle.cards,
  ThemeVisuals? visuals,
}) {
  return buildThemeFromScheme(
    ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness),
    interfaceStyle: interfaceStyle,
    visuals: visuals,
  );
}

/// 所有配色共用主题入口，保证系统配色也使用相同的桌面排版。
ThemeData buildThemeFromScheme(
  ColorScheme colorScheme, {
  InterfaceStyle interfaceStyle = InterfaceStyle.cards,
  ThemeVisuals? visuals,
}) {
  colorScheme = ThemeColors.apply(colorScheme, visuals?.colors ?? const {});
  final isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
  final textTheme = isWindows ? _windowsTextTheme : null;
  final hasBackground = visuals?.hasBackground == true;
  final cardSurface = colorScheme.brightness == Brightness.dark
      ? colorScheme.surfaceContainerHigh
      : colorScheme.surfaceContainerLow;
  return ThemeData(
    useMaterial3: true,
    brightness: colorScheme.brightness,
    colorScheme: colorScheme,
    highlightColor: visuals?.color('highlight'),
    extensions: [
      InterfaceTheme(style: interfaceStyle),
      ?visuals,
    ],
    scaffoldBackgroundColor: hasBackground
        ? Colors.transparent
        : colorScheme.surface,
    inputDecorationTheme: InputDecorationThemeData(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: hasBackground,
      fillColor: colorScheme.surface,
    ),
    pageTransitionsTheme: hasBackground ? _wallpaperPageTransitions : null,
    navigationBarTheme: hasBackground
        ? NavigationBarThemeData(
            backgroundColor: colorScheme.surfaceContainer.withValues(
              alpha: visuals!.surfaceOpacity,
            ),
            elevation: 0,
            surfaceTintColor: Colors.transparent,
          )
        : null,
    navigationRailTheme: hasBackground
        ? NavigationRailThemeData(
            backgroundColor: colorScheme.surface.withValues(
              alpha: visuals!.surfaceOpacity,
            ),
            elevation: 0,
          )
        : null,
    dividerTheme: visuals == null
        ? null
        : DividerThemeData(
            color: visuals.dividerWidth == 0
                ? Colors.transparent
                : visuals.color('divider') ?? colorScheme.outlineVariant,
            thickness: visuals.dividerWidth,
          ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: hasBackground
          ? cardSurface.withValues(alpha: visuals!.surfaceOpacity)
          : cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          interfaceStyle.isCard ? visuals?.cardRadius ?? 24 : 0,
        ),
      ),
    ),
    switchTheme: interfaceStyle.isCard
        ? SwitchThemeData(
            thumbIcon: WidgetStateProperty.resolveWith(
              (states) => Icon(
                states.contains(WidgetState.selected)
                    ? Icons.check
                    : Icons.close,
              ),
            ),
          )
        : null,
    // 拉丁字形使用 Segoe UI；中文明确回退到微软雅黑 UI。
    fontFamily: isWindows ? 'Segoe UI' : null,
    fontFamilyFallback: isWindows
        ? const ['Microsoft YaHei UI', 'Microsoft YaHei', 'Segoe UI Emoji']
        : null,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    splashFactory: NoSplash.splashFactory,
    appBarTheme: AppBarTheme(
      scrolledUnderElevation: 0,
      backgroundColor: hasBackground
          ? colorScheme.surface.withValues(alpha: visuals!.surfaceOpacity)
          : null,
    ),
  );
}

const _wallpaperPageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: ThemeBackgroundPageTransitionsBuilder(
      delegate: PredictiveBackPageTransitionsBuilder(
        fallbackColor: Colors.transparent,
      ),
    ),
    TargetPlatform.iOS: ThemeBackgroundPageTransitionsBuilder(
      delegate: CupertinoPageTransitionsBuilder(),
    ),
    TargetPlatform.macOS: ThemeBackgroundPageTransitionsBuilder(
      delegate: CupertinoPageTransitionsBuilder(),
    ),
    TargetPlatform.windows: ThemeBackgroundPageTransitionsBuilder(
      delegate: ZoomPageTransitionsBuilder(backgroundColor: Colors.transparent),
    ),
    TargetPlatform.linux: ThemeBackgroundPageTransitionsBuilder(
      delegate: ZoomPageTransitionsBuilder(backgroundColor: Colors.transparent),
    ),
    TargetPlatform.fuchsia: ThemeBackgroundPageTransitionsBuilder(
      delegate: ZoomPageTransitionsBuilder(backgroundColor: Colors.transparent),
    ),
  },
);

TextStyle _windowsTextStyle(
  double size, {
  FontWeight weight = FontWeight.w400,
  double height = 1.4,
}) => TextStyle(
  fontSize: size,
  fontWeight: weight,
  height: height,
  letterSpacing: 0,
);

// 中文无需 Material 默认的拉丁字间距，标题以中等字重建立层级。
final _windowsTextTheme = TextTheme(
  displayLarge: _windowsTextStyle(48, height: 1.2),
  displayMedium: _windowsTextStyle(40, height: 1.2),
  displaySmall: _windowsTextStyle(32, height: 1.25),
  headlineLarge: _windowsTextStyle(28, weight: FontWeight.w600, height: 1.3),
  headlineMedium: _windowsTextStyle(24, weight: FontWeight.w600, height: 1.3),
  headlineSmall: _windowsTextStyle(22, weight: FontWeight.w600, height: 1.3),
  titleLarge: _windowsTextStyle(20, weight: FontWeight.w600, height: 1.3),
  titleMedium: _windowsTextStyle(16, weight: FontWeight.w600),
  titleSmall: _windowsTextStyle(14, weight: FontWeight.w600),
  bodyLarge: _windowsTextStyle(15, height: 1.5),
  bodyMedium: _windowsTextStyle(14, height: 1.5),
  bodySmall: _windowsTextStyle(12, height: 1.5),
  labelLarge: _windowsTextStyle(14, weight: FontWeight.w500),
  labelMedium: _windowsTextStyle(13, weight: FontWeight.w500),
  labelSmall: _windowsTextStyle(12, weight: FontWeight.w500),
);
