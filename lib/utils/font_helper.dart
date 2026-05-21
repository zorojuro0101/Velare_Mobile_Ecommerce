import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized text styles para sa app.
///
/// Lahat ng `fontSize` defaults dito ay automatically responsive via `.sp`
/// (scalable pixels mula sa `flutter_screenutil`). Yung base design size ay
/// nakaset sa `main.dart` (390 x 844). Sa ibang devices, mag-aadjust na ang
/// font sizes para maintindihan parin yung layout.
///
/// Pwede mo paring i-override yung `fontSize` per call kung kailangan, e.g.:
/// ```dart
/// FontHelper.playfairDisplay(fontSize: 22.sp, fontWeight: FontWeight.bold)
/// ```
class FontHelper {
  // Playfair Display for titles/headings
  static TextStyle playfairDisplay({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    TextDecoration? decoration,
  }) {
    return GoogleFonts.playfairDisplay(
      // Auto-scale kung hindi pre-scaled yung passed value.
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      decoration: decoration,
    );
  }

  // Goudy Bookletter 1911 for body text
  static TextStyle goudyBookletter({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    TextDecoration? decoration,
  }) {
    return GoogleFonts.goudyBookletter1911(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      decoration: decoration,
    );
  }

  // ---------------------------------------------------------------------------
  // Common text styles for consistency (responsive na agad).
  // ---------------------------------------------------------------------------

  // Titles (Playfair Display)
  static TextStyle get title1 => playfairDisplay(
        fontSize: 32.sp,
        fontWeight: FontWeight.bold,
      );

  static TextStyle get title2 => playfairDisplay(
        fontSize: 28.sp,
        fontWeight: FontWeight.bold,
      );

  static TextStyle get title3 => playfairDisplay(
        fontSize: 24.sp,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get title4 => playfairDisplay(
        fontSize: 20.sp,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get title5 => playfairDisplay(
        fontSize: 18.sp,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get title6 => playfairDisplay(
        fontSize: 16.sp,
        fontWeight: FontWeight.w600,
      );

  // Body text (Goudy Bookletter)
  static TextStyle get bodyLarge => goudyBookletter(
        fontSize: 16.sp,
        fontWeight: FontWeight.normal,
      );

  static TextStyle get bodyMedium => goudyBookletter(
        fontSize: 14.sp,
        fontWeight: FontWeight.normal,
      );

  static TextStyle get bodySmall => goudyBookletter(
        fontSize: 12.sp,
        fontWeight: FontWeight.normal,
      );

  // Button text (Goudy Bookletter)
  static TextStyle get button => goudyBookletter(
        fontSize: 16.sp,
        fontWeight: FontWeight.w600,
      );

  // Caption/Label text (Goudy Bookletter)
  static TextStyle get caption => goudyBookletter(
        fontSize: 12.sp,
        fontWeight: FontWeight.normal,
      );

  static TextStyle get label => goudyBookletter(
        fontSize: 14.sp,
        fontWeight: FontWeight.w500,
      );
}
