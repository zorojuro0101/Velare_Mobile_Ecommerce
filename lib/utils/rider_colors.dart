import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Rider Module Color Palette
/// Matches web implementation exactly
class RiderColors {
  // Prevent instantiation
  RiderColors._();

  // ============================================================================
  // BACKGROUNDS
  // ============================================================================

  /// Page background - Light cream
  static const Color pageBackground = Color(0xFFFAF9F7);

  /// Card/Section background - White
  static const Color cardBackground = Color(0xFFFFFFFF);

  /// Sidebar background - White
  static const Color sidebarBackground = Color(0xFFFFFFFF);

  /// Table header background - Light cream
  static const Color tableHeaderBackground = Color(0xFFFAF9F7);

  /// Hover background - Light cream
  static const Color hoverBackground = Color(0xFFFAF9F7);

  /// Highlighted row - Very light yellow
  static const Color highlightedRow = Color(0xFFFFFBF0);

  // ============================================================================
  // TEXT COLORS
  // ============================================================================

  /// Primary text - Almost black
  static const Color primaryText = Color(0xFF181818);

  /// Secondary text - Brown-gray
  static const Color secondaryText = Color(0xFF6D6552);

  /// Muted text - Gray
  static const Color mutedText = Color(0xFF666666);

  /// Light text - Light gray
  static const Color lightText = Color(0xFF999999);

  /// Disabled text - Gray
  static const Color disabledText = Color(0xFF6C757D);

  // ============================================================================
  // BRAND/GOLD COLORS
  // ============================================================================

  /// Primary gold/brand color
  static const Color primaryGold = Color(0xFFD3BD9B);

  /// Dark gold
  static const Color darkGold = Color(0xFFBFA14A);

  /// Light gold
  static const Color lightGold = Color(0xFFE0D7C6);

  /// Brown gold
  static const Color brownGold = Color(0xFF8B7355);

  // ============================================================================
  // BUTTON COLORS
  // ============================================================================

  /// Accept button - Black
  static const Color buttonBlack = Color(0xFF000000);

  /// Reject button - Red
  static const Color buttonRed = Color(0xFFDC3545);

  /// Success/Delivered button - Green
  static const Color buttonGreen = Color(0xFF28A745);

  /// Pickup/Info button - Blue
  static const Color buttonBlue = Color(0xFF007BFF);

  /// Refresh button border - Gray
  static const Color buttonGray = Color(0xFFBBBBBB);

  // ============================================================================
  // NOTIFICATION COLORS
  // ============================================================================

  // Success (Green)
  static const Color successBackground = Color(0xFFECFDF5);
  static const Color successBorder = Color(0xFF10B981);
  static const Color successText = Color(0xFF059669);

  // Error (Red)
  static const Color errorBackground = Color(0xFFFEF2F2);
  static const Color errorBorder = Color(0xFFF87171);
  static const Color errorText = Color(0xFFDC2626);

  // Info (Blue)
  static const Color infoBackground = Color(0xFFEFF6FF);
  static const Color infoBorder = Color(0xFF60A5FA);
  static const Color infoText = Color(0xFF2563EB);

  // ============================================================================
  // BORDER COLORS
  // ============================================================================

  /// Primary border - Gold
  static const Color primaryBorder = Color(0xFFD3BD9B);

  /// Light border - Light gray
  static const Color lightBorder = Color(0xFFE0E0E0);

  /// Divider - Very light gray
  static const Color divider = Color(0xFFDEE2E6);

  /// Table border - Light gray
  static const Color tableBorder = Color(0xFFE0E0E0);

  // ============================================================================
  // DISABLED COLORS
  // ============================================================================

  /// Disabled background
  static const Color disabledBackground = Color(0xFFF8F9FA);

  /// Disabled border
  static const Color disabledBorder = Color(0xFFDEE2E6);

  // ============================================================================
  // STATUS COLORS
  // ============================================================================

  /// Pending status - Yellow/Amber
  static const Color statusPending = Color(0xFFFFC107);

  /// Accepted status - Blue
  static const Color statusAccepted = Color(0xFF007BFF);

  /// Picked up status - Cyan
  static const Color statusPickedUp = Color(0xFF17A2B8);

  /// Delivered status - Green
  static const Color statusDelivered = Color(0xFF28A745);

  /// Cancelled status - Red
  static const Color statusCancelled = Color(0xFFDC3545);

  // ============================================================================
  // SHADOW COLORS
  // ============================================================================

  /// Card shadow
  static Color cardShadow = const Color(0xFF2C2236).withValues(alpha: 0.10);

  /// Button shadow (Black)
  static Color buttonShadowBlack = Colors.black.withValues(alpha: 0.2);

  /// Button shadow (Red)
  static Color buttonShadowRed = const Color(0xFFDC3545).withValues(alpha: 0.3);

  /// Button shadow (Green)
  static Color buttonShadowGreen = const Color(
    0xFF28A745,
  ).withValues(alpha: 0.3);

  /// Button shadow (Blue)
  static Color buttonShadowBlue = const Color(
    0xFF007BFF,
  ).withValues(alpha: 0.3);

  /// Profile image shadow
  static Color profileShadow = const Color(0xFF2C2236).withValues(alpha: 0.08);

  /// Notification shadow
  static Color notificationShadow = Colors.black.withValues(alpha: 0.15);

  // ============================================================================
  // GRADIENT COLORS
  // ============================================================================

  /// Profile initial gradient
  static const LinearGradient profileGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x59D3BD9B), // rgba(211,189,155,0.35)
      Color(0x59695B44), // rgba(105,91,68,0.35)
    ],
  );

  /// Gold hover overlay
  static Color goldHoverOverlay = const Color(
    0xFFD3BD9B,
  ).withValues(alpha: 0.1);

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Get button style for outlined buttons (web pattern)
  static ButtonStyle getOutlinedButtonStyle({
    required Color color,
    Color? hoverColor,
    double borderWidth = 1.5,
    double borderRadius = 2.0,
    EdgeInsets? padding,
  }) {
    return OutlinedButton.styleFrom(
      foregroundColor: color,
      backgroundColor: Colors.white,
      side: BorderSide(color: color, width: borderWidth),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      padding:
          padding ?? EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
    ).copyWith(
      backgroundColor: WidgetStateProperty.resolveWith<Color>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.pressed) ||
            states.contains(WidgetState.hovered)) {
          return hoverColor ?? color;
        }
        if (states.contains(WidgetState.disabled)) {
          return disabledBackground;
        }
        return Colors.white;
      }),
      foregroundColor: WidgetStateProperty.resolveWith<Color>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.pressed) ||
            states.contains(WidgetState.hovered)) {
          return Colors.white;
        }
        if (states.contains(WidgetState.disabled)) {
          return disabledText;
        }
        return color;
      }),
      side: WidgetStateProperty.resolveWith<BorderSide>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.disabled)) {
          return BorderSide(color: disabledBorder, width: borderWidth);
        }
        return BorderSide(color: color, width: borderWidth);
      }),
    );
  }

  /// Get accept button style (Black)
  static ButtonStyle get acceptButtonStyle =>
      getOutlinedButtonStyle(color: buttonBlack);

  /// Get reject button style (Red)
  static ButtonStyle get rejectButtonStyle =>
      getOutlinedButtonStyle(color: buttonRed);

  /// Get success button style (Green)
  static ButtonStyle get successButtonStyle =>
      getOutlinedButtonStyle(color: buttonGreen);

  /// Get pickup button style (Blue)
  static ButtonStyle get pickupButtonStyle =>
      getOutlinedButtonStyle(color: buttonBlue);

  /// Get refresh button style (Gray)
  static ButtonStyle get refreshButtonStyle =>
      getOutlinedButtonStyle(color: buttonGray, hoverColor: buttonBlack);

  /// Get card decoration
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: cardBackground,
    borderRadius: BorderRadius.circular(2.r),
    border: Border.all(color: lightBorder, width: 1),
    boxShadow: [
      BoxShadow(color: cardShadow, blurRadius: 32, offset: const Offset(0, 8)),
    ],
  );

  /// Get table header decoration
  static BoxDecoration get tableHeaderDecoration => BoxDecoration(
    color: tableHeaderBackground,
    border: Border(bottom: BorderSide(color: primaryBorder, width: 2)),
  );
}
