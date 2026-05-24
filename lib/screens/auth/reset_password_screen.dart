import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/auth_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/snackbar_helper.dart';
import 'login_screen.dart';

/// A single password requirement (label + matcher).
class _PwReq {
  final String label;
  final bool Function(String) matches;
  const _PwReq(this.label, this.matches);
}

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _isResending = false;
  bool _showPassword = false;
  bool _showConfirm = false;

  /// When true, unmet requirements are shown in red (after a failed submit).
  /// Resets back to muted automatically when the user satisfies them all.
  bool _highlightMissing = false;

  late final List<_PwReq> _requirements = const [
    _PwReq('At least 6 characters', _hasMinLength),
    _PwReq('1 uppercase letter', _hasUpper),
    _PwReq('1 lowercase letter', _hasLower),
    _PwReq('1 number', _hasDigit),
  ];

  /// Per-requirement shake controllers so each row animates independently.
  late final List<AnimationController> _shakeControllers = List.generate(
    _requirements.length,
    (_) => AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    ),
  );

  static bool _hasMinLength(String s) => s.length >= 6;
  static bool _hasUpper(String s) => RegExp(r'[A-Z]').hasMatch(s);
  static bool _hasLower(String s) => RegExp(r'[a-z]').hasMatch(s);
  static bool _hasDigit(String s) => RegExp(r'[0-9]').hasMatch(s);

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    final pw = _passwordController.text;
    final allMet = _requirements.every((r) => r.matches(pw));

    if (_highlightMissing && allMet) {
      // User fixed everything: drop the red highlight.
      setState(() => _highlightMissing = false);
    } else {
      // Just rebuild so satisfied rows turn green in real time.
      setState(() {});
    }
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    final pw = _passwordController.text;
    final confirm = _confirmController.text;

    // 1) Code field
    if (code.length != 6) {
      SnackBarHelper.showError(context, 'Please enter the 6-digit code.');
      return;
    }

    // 2) Password requirements
    final unmet = <int>[];
    for (var i = 0; i < _requirements.length; i++) {
      if (!_requirements[i].matches(pw)) unmet.add(i);
    }
    if (unmet.isNotEmpty) {
      setState(() => _highlightMissing = true);
      for (final i in unmet) {
        _shakeControllers[i].forward(from: 0);
      }
      SnackBarHelper.showError(
        context,
        'Your new password does not meet all the requirements.',
      );
      return;
    }

    // 3) Confirm password
    if (confirm.isEmpty) {
      SnackBarHelper.showError(context, 'Please confirm your new password.');
      return;
    }
    if (pw != confirm) {
      SnackBarHelper.showError(context, 'Passwords do not match.');
      return;
    }

    setState(() => _isLoading = true);

    final result = await _authService.resetPasswordWithCode(
      widget.email,
      code,
      pw,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      SnackBarHelper.showSuccess(context, result['message']);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } else {
      SnackBarHelper.showError(context, result['message']);
    }
  }

  Future<void> _resendCode() async {
    setState(() => _isResending = true);
    final result = await _authService.requestPasswordReset(widget.email);
    if (!mounted) return;
    setState(() => _isResending = false);

    if (result['code_sent'] == true) {
      SnackBarHelper.showSuccess(context, 'A new code has been sent.');
    } else {
      SnackBarHelper.showError(context, result['message']);
    }
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    for (final c in _shakeControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface(context),
      appBar: AppBar(
        backgroundColor: AppColors.surface(context),
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.onSurface(context)),
        title: Text(
          'Reset Password',
          style: GoogleFonts.goudyBookletter1911(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface(context),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 8.h),
              Text(
                'Enter the 6-digit code',
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8.h),
              Text.rich(
                TextSpan(
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 14.sp,
                    color: AppColors.textMuted(context),
                  ),
                  children: [
                    const TextSpan(text: 'We sent a code to '),
                    TextSpan(
                      text: widget.email,
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface(context),
                      ),
                    ),
                    const TextSpan(text: '. The code expires in 15 minutes.'),
                  ],
                ),
              ),
              SizedBox(height: 24.h),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 22.sp,
                  letterSpacing: 8.w,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  counterText: '',
                  labelText: 'Reset Code',
                  labelStyle: GoogleFonts.goudyBookletter1911(),
                  filled: true,
                  fillColor: AppColors.surfaceVariant(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              TextField(
                controller: _passwordController,
                obscureText: !_showPassword,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  labelStyle: GoogleFonts.goudyBookletter1911(),
                  filled: true,
                  fillColor: AppColors.surfaceVariant(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility : Icons.visibility_off,
                      color: AppColors.textMuted(context),
                    ),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              TextField(
                controller: _confirmController,
                obscureText: !_showConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  labelStyle: GoogleFonts.goudyBookletter1911(),
                  filled: true,
                  fillColor: AppColors.surfaceVariant(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showConfirm ? Icons.visibility : Icons.visibility_off,
                      color: AppColors.textMuted(context),
                    ),
                    onPressed: () =>
                        setState(() => _showConfirm = !_showConfirm),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              _buildPasswordGuidelines(),
              SizedBox(height: 24.h),
              SizedBox(
                height: 48.h,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.onSurface(context),
                    foregroundColor: AppColors.surface(context),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20.h,
                          width: 20.w,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.surface(context),
                            ),
                          ),
                        )
                      : Text(
                          'Reset Password',
                          style: GoogleFonts.goudyBookletter1911(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't get the code? ",
                    style: GoogleFonts.goudyBookletter1911(
                      color: AppColors.textMuted(context),
                    ),
                  ),
                  GestureDetector(
                    onTap: _isResending ? null : _resendCode,
                    child: Text(
                      _isResending ? 'Sending...' : 'Resend',
                      style: GoogleFonts.goudyBookletter1911(
                        color: AppColors.onSurface(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordGuidelines() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBackground(context),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password must contain:',
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textBody(context),
            ),
          ),
          SizedBox(height: 6.h),
          for (var i = 0; i < _requirements.length; i++)
            _buildGuidelineRow(i, _requirements[i]),
        ],
      ),
    );
  }

  Widget _buildGuidelineRow(int index, _PwReq req) {
    final pw = _passwordController.text;
    final met = req.matches(pw);
    final isMissingHighlight = _highlightMissing && !met;

    final color = met
        ? Colors.green.shade600
        : isMissingHighlight
            ? Colors.red.shade600
            : AppColors.textMuted(context);

    final icon = met
        ? Icons.check_circle
        : isMissingHighlight
            ? Icons.cancel
            : Icons.check_circle_outline;

    return AnimatedBuilder(
      animation: _shakeControllers[index],
      builder: (context, child) {
        // Damped sine: 4 oscillations across the duration, amplitude 6dp.
        final t = _shakeControllers[index].value;
        final dx = t == 0 ? 0.0 : 6 * (1 - t) * math.sin(t * 8 * math.pi);
        return Transform.translate(
          offset: Offset(dx, 0),
          child: child,
        );
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 2.h),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: GoogleFonts.goudyBookletter1911(
            fontSize: 11.sp,
            color: color,
            fontWeight: met || isMissingHighlight
                ? FontWeight.w600
                : FontWeight.w400,
          ),
          child: Row(
            children: [
              Icon(icon, size: 14.r, color: color),
              SizedBox(width: 6.w),
              Text(req.label),
            ],
          ),
        ),
      ),
    );
  }
}
