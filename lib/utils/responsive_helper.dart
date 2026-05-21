import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Responsive helper utilities para sa consistent UI sa iba't ibang screen sizes.
///
/// Built on top of `flutter_screenutil`. Yung base design size ay nakaset sa
/// `main.dart` (390 x 844 — iPhone 13/14 reference).
///
/// Common usage:
/// ```dart
///   // Sa halip na hardcoded:
///   Padding(padding: EdgeInsets.all(16))
///
///   // Use:
///   Padding(padding: EdgeInsets.all(16.w))   // width-scaled
///   Text('Hello', style: TextStyle(fontSize: 14.sp)) // font-scaled
///   SizedBox(height: 24.h)                    // height-scaled
///   BorderRadius.circular(8.r)                // radius-scaled
/// ```
class Responsive {
  Responsive._();

  // ---------------------------------------------------------------------------
  // Breakpoints
  // ---------------------------------------------------------------------------
  /// Devices na <600 logical pixels yung width = phone.
  static const double mobileBreakpoint = 600;

  /// 600–1024 = tablet.
  static const double tabletBreakpoint = 1024;

  /// >1024 = desktop / large tablet.

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreakpoint;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint;

  /// True kapag landscape orientation yung device.
  static bool isLandscape(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  // ---------------------------------------------------------------------------
  // Responsive value picker
  // ---------------------------------------------------------------------------
  /// Pumili ng value depende sa screen size.
  ///
  /// Example:
  /// ```dart
  /// final crossAxisCount = Responsive.value(
  ///   context,
  ///   mobile: 2,
  ///   tablet: 3,
  ///   desktop: 4,
  /// );
  /// ```
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context)) return desktop ?? tablet ?? mobile;
    if (isTablet(context)) return tablet ?? mobile;
    return mobile;
  }

  // ---------------------------------------------------------------------------
  // Convenience getters (raw MediaQuery)
  // ---------------------------------------------------------------------------
  static double width(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double height(BuildContext context) =>
      MediaQuery.of(context).size.height;

  /// Screen width as a fraction (0.0 – 1.0). E.g. `wp(context, 0.5)` = half ng screen width.
  static double wp(BuildContext context, double fraction) =>
      MediaQuery.of(context).size.width * fraction;

  /// Screen height as a fraction (0.0 – 1.0).
  static double hp(BuildContext context, double fraction) =>
      MediaQuery.of(context).size.height * fraction;

  // ---------------------------------------------------------------------------
  // ScreenUtil shortcuts (use these din directly via .w / .h / .sp / .r)
  // ---------------------------------------------------------------------------
  /// Scale a width-related value (padding, margin, container width).
  static double w(double value) => value.w;

  /// Scale a height-related value.
  static double h(double value) => value.h;

  /// Scale a font size — automatically respects user text scale settings.
  static double sp(double value) => value.sp;

  /// Scale a border radius.
  static double r(double value) => value.r;
}

/// Simple grid count helper — common case sa product grids.
int responsiveGridCount(
  BuildContext context, {
  int mobile = 2,
  int tablet = 3,
  int desktop = 4,
}) {
  return Responsive.value(
    context,
    mobile: mobile,
    tablet: tablet,
    desktop: desktop,
  );
}
