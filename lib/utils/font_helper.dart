import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

  // Common text styles for consistency

  // Titles (Playfair Display)
  static TextStyle get title1 => playfairDisplay(
        fontSize: 32,
        fontWeight: FontWeight.bold,
      );

  static TextStyle get title2 => playfairDisplay(
        fontSize: 28,
        fontWeight: FontWeight.bold,
      );

  static TextStyle get title3 => playfairDisplay(
        fontSize: 24,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get title4 => playfairDisplay(
        fontSize: 20,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get title5 => playfairDisplay(
        fontSize: 18,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get title6 => playfairDisplay(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      );

  // Body text (Goudy Bookletter)
  static TextStyle get bodyLarge => goudyBookletter(
        fontSize: 16,
        fontWeight: FontWeight.normal,
      );

  static TextStyle get bodyMedium => goudyBookletter(
        fontSize: 14,
        fontWeight: FontWeight.normal,
      );

  static TextStyle get bodySmall => goudyBookletter(
        fontSize: 12,
        fontWeight: FontWeight.normal,
      );

  // Button text (Goudy Bookletter)
  static TextStyle get button => goudyBookletter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      );

  // Caption/Label text (Goudy Bookletter)
  static TextStyle get caption => goudyBookletter(
        fontSize: 12,
        fontWeight: FontWeight.normal,
      );

  static TextStyle get label => goudyBookletter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      );
}
