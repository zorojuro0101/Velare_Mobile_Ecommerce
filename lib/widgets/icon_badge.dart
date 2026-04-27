import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class IconBadge extends StatelessWidget {
  final IconData icon;
  final int count;
  final VoidCallback onPressed;
  final Color? badgeColor;
  final Color? iconColor;

  const IconBadge({
    super.key,
    required this.icon,
    required this.count,
    required this.onPressed,
    this.badgeColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(icon, color: iconColor),
          onPressed: onPressed,
        ),
        if (count > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: badgeColor ?? const Color(0xFFD4AF37),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Center(
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: GoogleFonts.playfairDisplay(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class NotificationDot extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool showDot;
  final Color? iconColor;

  const NotificationDot({
    super.key,
    required this.icon,
    required this.onPressed,
    this.showDot = false,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(icon, color: iconColor),
          onPressed: onPressed,
        ),
        if (showDot)
          Positioned(
            right: 12,
            top: 12,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
