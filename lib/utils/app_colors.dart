import 'package:flutter/material.dart';

/// Context-aware color helpers that adapt to light/dark theme.
///
/// Usage:
///   color: AppColors.surface(context)  // was Colors.white
///   color: AppColors.onSurface(context) // was Colors.black
///
/// Design rules (per spec):
///   - White surfaces → dark gray in dark mode
///   - Black text/icons → white in dark mode
///   - Gradual contrast swap; existing brand colors (gold, red, green, etc.) preserved
class AppColors {
  AppColors._();

  // Dark mode palette
  static const Color _darkSurface = Color(0xFF1E1E1E);          // replaces Colors.white
  static const Color _darkBackground = Color(0xFF121212);       // replaces grey[50]/grey[100] page bg
  static const Color _darkSurfaceVariant = Color(0xFF2A2A2A);   // replaces grey[100]/grey[200] cards
  static const Color _darkSurfaceVariant2 = Color(0xFF333333);  // replaces grey[200]/grey[300]
  static const Color _darkBorder = Color(0xFF3A3A3A);           // replaces grey[300]
  static const Color _darkDivider = Color(0xFF2A2A2A);

  // Text shades on dark background. Tuned so that grey[700]/[800] (which are
  // dark, meant to be readable on white) become legible (light) on dark.
  static const Color _darkTextHigh = Color(0xFFEDEDED);   // replaces grey[800]/grey[900] strong body text
  static const Color _darkTextMid = Color(0xFFD0D0D0);    // replaces grey[700] body text
  static const Color _darkTextLow = Color(0xFFB0B0B0);    // replaces grey[600] muted text
  static const Color _darkTextFaint = Color(0xFF8A8A8A); // replaces grey[400]/[500] faint text/icons

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Replaces Colors.white (cards, app bars, modals).
  static Color surface(BuildContext context) =>
      isDark(context) ? _darkSurface : Colors.white;

  /// Replaces Colors.black (primary text, primary icons, primary buttons).
  static Color onSurface(BuildContext context) =>
      isDark(context) ? Colors.white : Colors.black;

  /// Replaces Colors.black87 (slightly muted text).
  static Color onSurfaceStrong(BuildContext context) =>
      isDark(context) ? Colors.white : Colors.black87;

  /// Replaces Colors.black54 (secondary text on white).
  static Color onSurfaceMedium(BuildContext context) =>
      isDark(context) ? const Color(0xFFCCCCCC) : Colors.black54;

  /// Replaces Colors.grey[50] / Colors.grey[100] used as page/scaffold background.
  static Color scaffoldBackground(BuildContext context) =>
      isDark(context) ? _darkBackground : Colors.grey[50]!;

  /// Replaces Colors.grey[100] used inside surfaces (e.g., text field fills).
  static Color surfaceVariant(BuildContext context) =>
      isDark(context) ? _darkSurfaceVariant : Colors.grey[100]!;

  /// Replaces Colors.grey[200] used as slightly darker variant.
  static Color surfaceVariant2(BuildContext context) =>
      isDark(context) ? _darkSurfaceVariant2 : Colors.grey[200]!;

  /// Replaces Colors.grey[300] as border color.
  static Color border(BuildContext context) =>
      isDark(context) ? _darkBorder : Colors.grey[300]!;

  /// Replaces dividers.
  static Color divider(BuildContext context) =>
      isDark(context) ? _darkDivider : Colors.grey[200]!;

  /// Replaces Colors.grey[600] (secondary muted text).
  static Color textMuted(BuildContext context) =>
      isDark(context) ? _darkTextLow : Colors.grey[600]!;

  /// Replaces Colors.grey[400] / Colors.grey[500] (faint text/icons).
  static Color textFaint(BuildContext context) =>
      isDark(context) ? _darkTextFaint : Colors.grey[500]!;

  /// Replaces Colors.grey[700] (mid-emphasis body text).
  static Color textBody(BuildContext context) =>
      isDark(context) ? _darkTextMid : Colors.grey[700]!;

  /// Replaces Colors.grey[800] / Colors.grey[900] (high-emphasis body text).
  static Color textBodyStrong(BuildContext context) =>
      isDark(context) ? _darkTextHigh : Colors.grey[800]!;

  /// Shadow color appropriate for theme.
  static Color shadow(BuildContext context, {double opacity = 0.1}) =>
      isDark(context)
          ? Colors.black.withValues(alpha: opacity * 2)
          : Colors.black.withValues(alpha: opacity);

  /// Inverse of onSurface - useful for text on a dark/black filled button background.
  /// Always returns white in light mode, dark color in dark mode (when button stays "dark").
  /// Use only when you want explicit "always-white-on-black" text on a primary button
  /// whose background also flipped to white in dark mode.
  static Color onPrimary(BuildContext context) =>
      isDark(context) ? Colors.black : Colors.white;

  /// ALWAYS white regardless of theme. Use for text/icons sitting on top of
  /// images, dark gradient overlays, colored badges, etc., where the
  /// background is fixed (not theme-dependent).
  static const Color alwaysWhite = Colors.white;

  /// ALWAYS black regardless of theme. Use for text/icons on fixed light
  /// backgrounds (e.g., yellow status badges) that don't follow the theme.
  static const Color alwaysBlack = Colors.black;
}
