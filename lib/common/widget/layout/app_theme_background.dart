import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fzu_assistant/service/theme_visuals.dart';

/// Wallpaper used behind the navigator, within route transitions and previews.
class AppThemeBackground extends StatelessWidget {
  const AppThemeBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final visuals = ThemeVisuals.of(context);
    final surface = Theme.of(context).colorScheme.surface;
    return ColoredBox(
      color: surface,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (visuals.hasBackground)
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: ClipRect(
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(
                        sigmaX: visuals.backgroundBlur,
                        sigmaY: visuals.backgroundBlur,
                        tileMode: TileMode.clamp,
                      ),
                      child: Image.file(
                        File(visuals.backgroundImage!),
                        fit: BoxFit.cover,
                        cacheWidth:
                            (MediaQuery.sizeOf(context).width *
                                    MediaQuery.devicePixelRatioOf(context))
                                .round()
                                .clamp(1, 2048),
                        gaplessPlayback: true,
                        errorBuilder: (_, _, _) => ColoredBox(color: surface),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (visuals.hasBackground)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: visuals.backgroundDim),
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}
