import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
class SnackBarHelper {
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            border: Border.all(color: Colors.green, width: 2),
            borderRadius: BorderRadius.circular(5.r),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green, size: 20.r),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.goudyBookletter1911(
                    color: Colors.green,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            border: Border.all(color: Colors.red, width: 2),
            borderRadius: BorderRadius.circular(5.r),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 20.r),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.goudyBookletter1911(
                    color: Colors.red,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void showInfo(BuildContext context, String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            border: Border.all(color: AppColors.onSurface(context), width: 2),
            borderRadius: BorderRadius.circular(5.r),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.onSurface(context), size: 20.r),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.goudyBookletter1911(
                    color: AppColors.onSurface(context),
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: action,
      ),
    );
  }
}
