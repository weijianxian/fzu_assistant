import 'package:flutter/material.dart';
import 'package:fzu_assistant/common/widget/layout/app_theme_background.dart';
import 'package:fzu_assistant/service/theme_visuals.dart';

/// Keeps the wallpaper inside the page animated by the platform transition.
class ThemeBackgroundPageTransitionsBuilder extends PageTransitionsBuilder {
  const ThemeBackgroundPageTransitionsBuilder({required this.delegate});

  final PageTransitionsBuilder delegate;

  @override
  Duration get transitionDuration => delegate.transitionDuration;

  @override
  Duration get reverseTransitionDuration => delegate.reverseTransitionDuration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      delegate.delegatedTransition;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => delegate.buildTransitions(
    route,
    context,
    animation,
    secondaryAnimation,
    ThemeVisuals.of(context).hasBackground
        ? AppThemeBackground(child: child)
        : child,
  );
}
