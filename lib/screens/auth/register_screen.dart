import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/address_selector_modal.dart';
import '../buyer/guest_home.dart';
import 'login_screen.dart';

import '../../utils/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Available government ID types (mirrors the web register form).
const List<Map<String, String>> _kIdTypes = [
  {'value': 'passport', 'label': 'Passport'},
  {'value': 'driver_license', 'label': "Driver's License"},
  {'value': 'national_id', 'label': 'National ID'},
  {'value': 'sss', 'label': 'SSS'},
  {'value': 'umid', 'label': 'UMID'},
  {'value': 'other', 'label': 'Other'},
];

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _authService = AuthService();

  // Buyer form controllers
  final _buyerFirstNameController = TextEditingController();
  final _buyerLastNameController = TextEditingController();
  final _buyerEmailController = TextEditingController();
  final _buyerPasswordController = TextEditingController();

  // Rider form controllers
  final _riderFirstNameController = TextEditingController();
  final _riderLastNameController = TextEditingController();
  final _riderEmailController = TextEditingController();
  final _riderPasswordController = TextEditingController();

  // Focus nodes so we can detect when the user leaves the email field
  final _buyerEmailFocus = FocusNode();
  final _riderEmailFocus = FocusNode();

  bool _buyerPasswordVisible = false;
  bool _riderPasswordVisible = false;
  bool _isLoading = false;

  // Inline email error messages (null = no error shown)
  String? _buyerEmailError;
  String? _riderEmailError;

  // Track whether an async email check is running
  bool _buyerEmailChecking = false;
  bool _riderEmailChecking = false;

  // Last email each field has actually been checked against. Used to ignore
  // stale async results (race condition) when the user keeps typing while
  // a check is in flight.
  String? _buyerLastCheckedEmail;
  String? _riderLastCheckedEmail;

  // Address data
  Map<String, String>? _buyerAddress;
  Map<String, String>? _riderAddress;

  // ID type + uploaded file (camera/gallery)
  String? _buyerIdType;
  String? _riderIdType;
  File? _buyerIdFile;
  File? _riderIdFile;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Check email when the user leaves the buyer email field
    _buyerEmailFocus.addListener(() {
      if (!_buyerEmailFocus.hasFocus) {
        _checkEmailExists(
          _buyerEmailController.text.trim(),
          isBuyer: true,
        );
      }
    });

    // Check email when the user leaves the rider email field
    _riderEmailFocus.addListener(() {
      if (!_riderEmailFocus.hasFocus) {
        _checkEmailExists(
          _riderEmailController.text.trim(),
          isBuyer: false,
        );
      }
    });

    // Clear the inline error as soon as the user starts editing again
    _buyerEmailController.addListener(() {
      // Invalidate any cached check result so the next blur re-checks.
      if (_buyerLastCheckedEmail != null) {
        _buyerLastCheckedEmail = null;
      }
      if (_buyerEmailError != null) {
        setState(() => _buyerEmailError = null);
      }
    });
    _riderEmailController.addListener(() {
      if (_riderLastCheckedEmail != null) {
        _riderLastCheckedEmail = null;
      }
      if (_riderEmailError != null) {
        setState(() => _riderEmailError = null);
      }
    });

    // Rebuild the password guideline checklist live as the user types so
    // each rule turns green the moment it's satisfied and red while it's
    // still missing.
    _buyerPasswordController.addListener(() => setState(() {}));
    _riderPasswordController.addListener(() => setState(() {}));
  }

  /// Checks the DB for an existing email and sets the inline error if found.
  Future<void> _checkEmailExists(String email, {required bool isBuyer}) async {
    if (email.isEmpty) return;

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) return; // format error handled on submit

    // Skip if we already have a result for this exact email and the field
    // hasn't changed since.
    final lastChecked =
        isBuyer ? _buyerLastCheckedEmail : _riderLastCheckedEmail;
    if (lastChecked == email) return;

    if (isBuyer) {
      setState(() => _buyerEmailChecking = true);
    } else {
      setState(() => _riderEmailChecking = true);
    }

    final exists = await _authService.checkEmailExists(email);

    if (!mounted) return;

    // Race-condition guard: only apply the result if the field still has
    // the email we actually queried for. Otherwise the user already moved on
    // to a different email and our answer is stale.
    final currentText = (isBuyer
            ? _buyerEmailController.text
            : _riderEmailController.text)
        .trim()
        .toLowerCase();
    if (currentText != email.toLowerCase()) {
      // Drop the stale result entirely.
      if (isBuyer) {
        setState(() => _buyerEmailChecking = false);
      } else {
        setState(() => _riderEmailChecking = false);
      }
      return;
    }

    if (isBuyer) {
      setState(() {
        _buyerEmailChecking = false;
        _buyerLastCheckedEmail = email;
        _buyerEmailError =
            exists ? 'This email is already registered.' : null;
      });
    } else {
      setState(() {
        _riderEmailChecking = false;
        _riderLastCheckedEmail = email;
        _riderEmailError =
            exists ? 'This email is already registered.' : null;
      });
    }
  }

  Future<void> _showAddressModal(bool isBuyer) async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddressSelectorModal(),
    );

    if (result != null) {
      setState(() {
        if (isBuyer) {
          _buyerAddress = result;
        } else {
          _riderAddress = result;
        }
      });
    }
  }

  /// Lets the user pick the ID photo from camera or storage. The file is kept
  /// locally in state and only uploaded to Supabase Storage on submit.
  Future<void> _pickIdImage(bool isBuyer) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 8.h),
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.border(ctx),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 12.h),
            ListTile(
              leading: Icon(Icons.photo_camera, color: AppColors.onSurface(ctx)),
              title: Text(
                'Take a photo',
                style: GoogleFonts.goudyBookletter1911(fontSize: 15.sp),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: AppColors.onSurface(ctx)),
              title: Text(
                'Upload from gallery',
                style: GoogleFonts.goudyBookletter1911(fontSize: 15.sp),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() {
        if (isBuyer) {
          _buyerIdFile = File(picked.path);
        } else {
          _riderIdFile = File(picked.path);
        }
      });
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(context, 'Failed to pick image. Please try again.');
    }
  }

  String _getAddressDisplay(Map<String, String>? address) {
    if (address == null) return 'Select Region, Province, City, Barangay';

    final parts = <String>[];
    if (address['barangay'] != null) parts.add(address['barangay']!);
    if (address['city'] != null) parts.add(address['city']!);
    if (address['province'] != null) parts.add(address['province']!);
    if (address['region'] != null) parts.add(address['region']!);
    if (address['postal_code'] != null) {
      parts.add('(${address['postal_code']})');
    }

    return parts.join(', ');
  }

  Future<void> _registerBuyer() async {
    if (_buyerFirstNameController.text.trim().isEmpty) {
      SnackBarHelper.showError(context, 'Please enter your first name.');
      return;
    }
    if (_buyerLastNameController.text.trim().isEmpty) {
      SnackBarHelper.showError(context, 'Please enter your last name.');
      return;
    }

    final email = _buyerEmailController.text.trim();
    if (email.isEmpty) {
      SnackBarHelper.showError(context, 'Please enter your email.');
      return;
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      SnackBarHelper.showError(context, 'Please enter a valid email address.');
      return;
    }
    // Block submit if inline error is already showing
    if (_buyerEmailError != null) {
      SnackBarHelper.showError(context, _buyerEmailError!);
      return;
    }

    if (_buyerAddress == null) {
      SnackBarHelper.showError(context, 'Please select your address.');
      return;
    }

    if (_buyerIdType == null || _buyerIdType!.isEmpty) {
      SnackBarHelper.showError(context, 'Please select your ID type.');
      return;
    }
    if (_buyerIdFile == null) {
      SnackBarHelper.showError(context, 'Please upload a photo of your ID.');
      return;
    }

    final pw = _buyerPasswordController.text;
    if (pw.isEmpty) {
      SnackBarHelper.showError(context, 'Please enter your password.');
      return;
    }
    if (pw.length < 6) {
      SnackBarHelper.showError(
          context, 'Password must be at least 6 characters.');
      return;
    }
    if (!RegExp(r'[A-Z]').hasMatch(pw)) {
      SnackBarHelper.showError(
          context, 'Password must contain at least 1 uppercase letter.');
      return;
    }
    if (!RegExp(r'[a-z]').hasMatch(pw)) {
      SnackBarHelper.showError(
          context, 'Password must contain at least 1 lowercase letter.');
      return;
    }
    if (!RegExp(r'[0-9]').hasMatch(pw)) {
      SnackBarHelper.showError(
          context, 'Password must contain at least 1 number.');
      return;
    }

    setState(() => _isLoading = true);

    final result = await _authService.signUp(
      email,
      pw,
      'buyer',
      firstName: _buyerFirstNameController.text.trim(),
      lastName: _buyerLastNameController.text.trim(),
      addressData: _buyerAddress,
      idType: _buyerIdType,
      idFile: _buyerIdFile,
    );

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (result['success'] == true) {
      SnackBarHelper.showSuccess(
        context,
        'Registration successful! Please wait for admin approval.',
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      // If the service still returns a duplicate error (race condition),
      // show it as an inline error on the field too.
      if (result['message']
              ?.toString()
              .toLowerCase()
              .contains('already registered') ==
          true) {
        setState(() => _buyerEmailError = result['message']);
      }
      SnackBarHelper.showError(context, result['message']);
    }
  }

  Future<void> _registerRider() async {
    if (_riderFirstNameController.text.trim().isEmpty) {
      SnackBarHelper.showError(context, 'Please enter your first name.');
      return;
    }
    if (_riderLastNameController.text.trim().isEmpty) {
      SnackBarHelper.showError(context, 'Please enter your last name.');
      return;
    }

    final email = _riderEmailController.text.trim();
    if (email.isEmpty) {
      SnackBarHelper.showError(context, 'Please enter your email.');
      return;
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      SnackBarHelper.showError(context, 'Please enter a valid email address.');
      return;
    }
    if (_riderEmailError != null) {
      SnackBarHelper.showError(context, _riderEmailError!);
      return;
    }

    if (_riderAddress == null) {
      SnackBarHelper.showError(context, 'Please select your address.');
      return;
    }

    if (_riderIdType == null || _riderIdType!.isEmpty) {
      SnackBarHelper.showError(context, 'Please select your ID type.');
      return;
    }
    if (_riderIdFile == null) {
      SnackBarHelper.showError(context, 'Please upload a photo of your ID.');
      return;
    }

    final pw = _riderPasswordController.text;
    if (pw.isEmpty) {
      SnackBarHelper.showError(context, 'Please enter your password.');
      return;
    }
    if (pw.length < 6) {
      SnackBarHelper.showError(
          context, 'Password must be at least 6 characters.');
      return;
    }
    if (!RegExp(r'[A-Z]').hasMatch(pw)) {
      SnackBarHelper.showError(
          context, 'Password must contain at least 1 uppercase letter.');
      return;
    }
    if (!RegExp(r'[a-z]').hasMatch(pw)) {
      SnackBarHelper.showError(
          context, 'Password must contain at least 1 lowercase letter.');
      return;
    }
    if (!RegExp(r'[0-9]').hasMatch(pw)) {
      SnackBarHelper.showError(
          context, 'Password must contain at least 1 number.');
      return;
    }

    setState(() => _isLoading = true);

    final result = await _authService.signUp(
      email,
      pw,
      'rider',
      firstName: _riderFirstNameController.text.trim(),
      lastName: _riderLastNameController.text.trim(),
      addressData: _riderAddress,
      idType: _riderIdType,
      idFile: _riderIdFile,
    );

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (result['success'] == true) {
      SnackBarHelper.showSuccess(
        context,
        'Registration successful! Please wait for admin approval.',
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      if (result['message']
              ?.toString()
              .toLowerCase()
              .contains('already registered') ==
          true) {
        setState(() => _riderEmailError = result['message']);
      }
      SnackBarHelper.showError(context, result['message']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const GuestHome()),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.surface(context),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBuyerForm(),
                    _buildRiderForm(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.all(24.w),
      child: Column(
        children: [
          Text(
            'Velare',
            style: GoogleFonts.playfairDisplay(
              fontSize: 32.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Register',
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 24.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Shop your favorite products with ease',
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 14.sp,
              color: AppColors.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24.w),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border(context))),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.onSurface(context),
        unselectedLabelColor: Colors.grey,
        labelStyle: GoogleFonts.goudyBookletter1911(
            fontSize: 16.sp, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.goudyBookletter1911(fontSize: 16.sp),
        indicatorColor: AppColors.onSurface(context),
        indicatorWeight: 3,
        tabs: const [
          Tab(text: 'Buyer'),
          Tab(text: 'Rider'),
        ],
      ),
    );
  }

  // ─── Buyer form ────────────────────────────────────────────────────────────

  Widget _buildBuyerForm() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _buyerFirstNameController,
                  decoration: _inputDecoration('First Name'),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: TextField(
                  controller: _buyerLastNameController,
                  decoration: _inputDecoration('Last Name'),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          // Email field with inline error + loading indicator
          _buildEmailField(
            controller: _buyerEmailController,
            focusNode: _buyerEmailFocus,
            errorText: _buyerEmailError,
            isChecking: _buyerEmailChecking,
          ),
          SizedBox(height: 16.h),
          GestureDetector(
            onTap: () => _showAddressModal(true),
            child: _buildAddressTile(_buyerAddress),
          ),
          SizedBox(height: 16.h),
          _buildIdTypeDropdown(
            value: _buyerIdType,
            onChanged: (v) => setState(() => _buyerIdType = v),
          ),
          SizedBox(height: 12.h),
          _buildIdUploadTile(
            file: _buyerIdFile,
            onTap: () => _pickIdImage(true),
            onClear: () => setState(() => _buyerIdFile = null),
          ),
          SizedBox(height: 16.h),
          TextField(
            controller: _buyerPasswordController,
            obscureText: !_buyerPasswordVisible,
            decoration: _inputDecoration('Password').copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _buyerPasswordVisible
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
                onPressed: () => setState(
                    () => _buyerPasswordVisible = !_buyerPasswordVisible),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          _buildPasswordGuidelines(_buyerPasswordController.text),
          SizedBox(height: 24.h),
          ElevatedButton(
            onPressed: _isLoading ? null : _registerBuyer,
            style: _buttonStyle(),
            child: _isLoading
                ? _loadingIndicator()
                : Text(
                    'Register as Buyer',
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          SizedBox(height: 16.h),
          _buildLoginLink(),
        ],
      ),
    );
  }

  // ─── Rider form ────────────────────────────────────────────────────────────

  Widget _buildRiderForm() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _riderFirstNameController,
                  decoration: _inputDecoration('First Name'),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: TextField(
                  controller: _riderLastNameController,
                  decoration: _inputDecoration('Last Name'),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _buildEmailField(
            controller: _riderEmailController,
            focusNode: _riderEmailFocus,
            errorText: _riderEmailError,
            isChecking: _riderEmailChecking,
          ),
          SizedBox(height: 16.h),
          GestureDetector(
            onTap: () => _showAddressModal(false),
            child: _buildAddressTile(_riderAddress),
          ),
          SizedBox(height: 16.h),
          _buildIdTypeDropdown(
            value: _riderIdType,
            onChanged: (v) => setState(() => _riderIdType = v),
          ),
          SizedBox(height: 12.h),
          _buildIdUploadTile(
            file: _riderIdFile,
            onTap: () => _pickIdImage(false),
            onClear: () => setState(() => _riderIdFile = null),
          ),
          SizedBox(height: 16.h),
          TextField(
            controller: _riderPasswordController,
            obscureText: !_riderPasswordVisible,
            decoration: _inputDecoration('Password').copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _riderPasswordVisible
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
                onPressed: () => setState(
                    () => _riderPasswordVisible = !_riderPasswordVisible),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          _buildPasswordGuidelines(_riderPasswordController.text),
          SizedBox(height: 24.h),
          ElevatedButton(
            onPressed: _isLoading ? null : _registerRider,
            style: _buttonStyle(),
            child: _isLoading
                ? _loadingIndicator()
                : Text(
                    'Register as Rider',
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          SizedBox(height: 16.h),
          _buildLoginLink(),
        ],
      ),
    );
  }

  // ─── Shared helpers ────────────────────────────────────────────────────────

  /// Email field with a spinner while checking and a red error below.
  Widget _buildEmailField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String? errorText,
    required bool isChecking,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.emailAddress,
          decoration: _inputDecoration('Email').copyWith(
            // Show a small spinner inside the field while checking
            suffixIcon: isChecking
                ? Padding(
                    padding: EdgeInsets.all(12.w),
                    child: SizedBox(
                      width: 16.w,
                      height: 16.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                  )
                : errorText != null
                    ? Icon(Icons.error_outline,
                        color: Colors.red.shade600, size: 20.r)
                    : null,
            // Red border when there's an error
            enabledBorder: errorText != null
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide:
                        BorderSide(color: Colors.red.shade400, width: 1.5),
                  )
                : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide.none,
                  ),
          ),
        ),
        if (errorText != null) ...[
          SizedBox(height: 4.h),
          Padding(
            padding: EdgeInsets.only(left: 4.w),
            child: Text(
              errorText,
              style: GoogleFonts.goudyBookletter1911(
                fontSize: 11.sp,
                color: Colors.red.shade600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAddressTile(Map<String, String>? address) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant(context),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _getAddressDisplay(address),
              style: GoogleFonts.goudyBookletter1911(
                color: address == null
                    ? AppColors.textMuted(context)
                    : AppColors.onSurface(context),
              ),
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 16.r),
        ],
      ),
    );
  }

  /// Government ID type selector. Mirrors the web register form's options.
  Widget _buildIdTypeDropdown({
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant(context),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          hint: Text(
            'Select ID Type',
            style: GoogleFonts.goudyBookletter1911(
              color: AppColors.textMuted(context),
            ),
          ),
          icon: Icon(Icons.keyboard_arrow_down,
              color: AppColors.textMuted(context)),
          dropdownColor: AppColors.surface(context),
          style: GoogleFonts.goudyBookletter1911(
            color: AppColors.onSurface(context),
            fontSize: 14.sp,
          ),
          items: _kIdTypes
              .map(
                (e) => DropdownMenuItem<String>(
                  value: e['value'],
                  child: Text(e['label']!),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  /// ID photo tile. Tapping opens a sheet to take a photo or pick from gallery.
  /// Once a file is selected we show a small preview and a "Change / Remove"
  /// row.
  Widget _buildIdUploadTile({
    required File? file,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    if (file == null) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant(context),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: AppColors.border(context),
              style: BorderStyle.solid,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.badge_outlined,
                  size: 22.r, color: AppColors.textMuted(context)),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  'Upload ID photo (camera or gallery)',
                  style: GoogleFonts.goudyBookletter1911(
                    color: AppColors.textMuted(context),
                  ),
                ),
              ),
              Icon(Icons.cloud_upload_outlined,
                  size: 18.r, color: AppColors.textMuted(context)),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant(context),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6.r),
            child: Image.file(
              file,
              width: 56.w,
              height: 56.w,
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ID photo selected',
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface(context),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  file.path.split(Platform.pathSeparator).last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 11.sp,
                    color: AppColors.textMuted(context),
                  ),
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onTap,
                      child: Text(
                        'Change',
                        style: GoogleFonts.goudyBookletter1911(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface(context),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    GestureDetector(
                      onTap: onClear,
                      child: Text(
                        'Remove',
                        style: GoogleFonts.goudyBookletter1911(
                          fontSize: 12.sp,
                          color: Colors.red.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordGuidelines(String password) {
    final hasLength = password.length >= 6;
    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasLower = RegExp(r'[a-z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);

    // Before the user starts typing, show the rules in neutral grey so the
    // form doesn't look like it's already in an error state. As soon as
    // they type a character, we switch to live red/green feedback.
    final hasInput = password.isNotEmpty;

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
          SizedBox(height: 4.h),
          _buildGuidelineItem('6+ characters', hasLength, hasInput),
          _buildGuidelineItem('1 uppercase letter', hasUpper, hasInput),
          _buildGuidelineItem('1 lowercase letter', hasLower, hasInput),
          _buildGuidelineItem('1 number', hasNumber, hasInput),
        ],
      ),
    );
  }

  /// One row of the password checklist. Turns green when [satisfied] is true
  /// and red while the user is still typing but hasn't met it yet. Stays
  /// neutral grey when the field is empty.
  Widget _buildGuidelineItem(String text, bool satisfied, bool hasInput) {
    final Color color;
    final IconData icon;
    if (!hasInput) {
      color = AppColors.textMuted(context);
      icon = Icons.check_circle_outline;
    } else if (satisfied) {
      color = Colors.green.shade600;
      icon = Icons.check_circle;
    } else {
      color = Colors.red.shade600;
      icon = Icons.cancel_outlined;
    }

    return Padding(
      padding: EdgeInsets.only(top: 2.h),
      child: Row(
        children: [
          Icon(icon, size: 14.r, color: color),
          SizedBox(width: 6.w),
          Text(
            text,
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 11.sp,
              color: color,
              fontWeight: satisfied && hasInput
                  ? FontWeight.w600
                  : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style:
              GoogleFonts.goudyBookletter1911(color: AppColors.textMuted(context)),
        ),
        GestureDetector(
          onTap: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          ),
          child: Text(
            'Login',
            style: GoogleFonts.goudyBookletter1911(
              color: AppColors.onSurface(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.goudyBookletter1911(),
      filled: true,
      fillColor: AppColors.surfaceVariant(context),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.r),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.r),
        borderSide: BorderSide.none,
      ),
    );
  }

  ButtonStyle _buttonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.onSurface(context),
      foregroundColor: AppColors.surface(context),
      padding: EdgeInsets.symmetric(vertical: 16.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.r),
      ),
    );
  }

  Widget _loadingIndicator() {
    return SizedBox(
      height: 20.h,
      width: 20.w,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor:
            AlwaysStoppedAnimation<Color>(AppColors.surface(context)),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _buyerEmailFocus.dispose();
    _riderEmailFocus.dispose();
    _buyerFirstNameController.dispose();
    _buyerLastNameController.dispose();
    _buyerEmailController.dispose();
    _buyerPasswordController.dispose();
    _riderFirstNameController.dispose();
    _riderLastNameController.dispose();
    _riderEmailController.dispose();
    _riderPasswordController.dispose();
    super.dispose();
  }
}
