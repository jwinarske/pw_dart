// Copyright 2026 Joel Winarske
// Licensed under the Apache License, Version 2.0

import 'package:flutter/material.dart';

/// Tokyo Night-inspired palette: low-contrast, warm-tinted dark theme.
/// Designed for long editing sessions — no pure white, no pure black,
/// all accents desaturated.
class AppTheme {
  // Backgrounds
  static const background = Color(0xFF1A1B26);
  static const surface = Color(0xFF24283B);
  static const surfaceHigh = Color(0xFF2F334D);
  static const border = Color(0xFF3B4261);

  // Text
  static const fg = Color(0xFFC0CAF5);
  static const fgDim = Color(0xFF787C99);

  // Accents (desaturated)
  static const accent = Color(0xFF7AA2F7); // soft indigo
  static const audioIn = Color(0xFF73DACA); // teal
  static const audioOut = Color(0xFFE0AF68); // amber
  static const midi = Color(0xFFBB9AF7); // lavender
  static const video = Color(0xFFF7768E); // muted rose
  static const linkActive = Color(0xFF9ECE6A); // sage
  static const linkIdle = Color(0xFF565F89);

  static ThemeData build() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: base.colorScheme.copyWith(
        surface: surface,
        primary: accent,
        secondary: audioIn,
        onSurface: fg,
      ),
      textTheme: base.textTheme.apply(bodyColor: fg, displayColor: fg),
      dividerColor: border,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: fg,
        elevation: 0,
      ),
    );
  }

  /// Map a port's media type to its accent color.
  static Color portColor(String mediaType, {required bool isOutput}) {
    if (mediaType.contains('midi')) return midi;
    if (mediaType.contains('video')) return video;
    return isOutput ? audioOut : audioIn;
  }
}
