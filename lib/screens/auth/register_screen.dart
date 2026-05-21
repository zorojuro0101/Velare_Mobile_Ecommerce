import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/address_selector_modal.dart';
import '../buyer/guest_home.dart';
import 'login_screen.dart';

import '../../utils/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
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
  
  bool _buyerPasswordVisible = false;
  bool _riderPasswordVisible = false;
  bool _isLoading = false;
  
  // Address data
  Map<String, String>? _buyerAddress;
  Map<String, String>? _riderAddress;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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

  String _getAddressDisplay(Map<String, String>? address) {
    if (address == null) return 'Select Region, Province, City, Barangay';
    
    final parts = <String>[];
    if (address['barangay'] != null) parts.add(address['barangay']!);
    if (address['city'] != null) parts.add(address['city']!);
    if (address['province'] != null) parts.add(address['province']!);
    if (address['region'] != null) parts.add(address['region']!);
    if (address['postal_code'] != null) parts.add('(${address['postal_code']})');
    
    return parts.join(', ');
  }

  Future<void> _registerBuyer() async {
    // Validate first name
    if (_buyerFirstNameController.text.trim().isEmpty) {
      SnackBarHelper.showError(context, 'Please enter your first name');
      return;
    }
    
    // Validate last name
    if (_buyerLastNameController.text.trim().isEmpty) {
      SnackBarHelper.showError(context, 'Please enter your last name');
      return;
    }
    
    // Validate email
    if (_buyerEmailController.text.trim().isEmpty) {
      SnackBarHelper.showError(context, 'Please enter your email');
      return;
    }
    
    // Validate email format
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(_buyerEmailController.text.trim())) {
      SnackBarHelper.showError(context, 'Please enter a valid email address');
      return;
    }
    
    // Validate address
    if (_buyerAddress == null) {
      SnackBarHelper.showError(context, 'Please select your address');
      return;
    }
    
    // Validate password
    if (_buyerPasswordController.text.isEmpty) {
      SnackBarHelper.showError(context, 'Please enter your password');
      return;
    }
    
    // Validate password requirements
    if (_buyerPasswordController.text.length < 6) {
      SnackBarHelper.showError(context, 'Password must be at least 6 characters');
      return;
    }
    
    if (!RegExp(r'[A-Z]').hasMatch(_buyerPasswordController.text)) {
      SnackBarHelper.showError(context, 'Password must contain at least 1 uppercase letter');
      return;
    }
    
    if (!RegExp(r'[a-z]').hasMatch(_buyerPasswordController.text)) {
      SnackBarHelper.showError(context, 'Password must contain at least 1 lowercase letter');
      return;
    }
    
    if (!RegExp(r'[0-9]').hasMatch(_buyerPasswordController.text)) {
      SnackBarHelper.showError(context, 'Password must contain at least 1 number');
      return;
    }

    setState(() => _isLoading = true);

    final result = await _authService.signUp(
      _buyerEmailController.text.trim(),
      _buyerPasswordController.text,
      'buyer',
      firstName: _buyerFirstNameController.text.trim(),
      lastName: _buyerLastNameController.text.trim(),
      addressData: _buyerAddress,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
      SnackBarHelper.showSuccess(context, 'Registration successful! Wait for the admin to approve it.');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      SnackBarHelper.showError(context, result['message']);
    }
  }

  Future<void> _registerRider() async {
    // Validate first name
    if (_riderFirstNameController.text.trim().isEmpty) {
      SnackBarHelper.showError(context, 'Please enter your first name');
      return;
    }
    
    // Validate last name
    if (_riderLastNameController.text.trim().isEmpty) {
      SnackBarHelper.showError(context, 'Please enter your last name');
      return;
    }
    
    // Validate email
    if (_riderEmailController.text.trim().isEmpty) {
      SnackBarHelper.showError(context, 'Please enter your email');
      return;
    }
    
    // Validate email format
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(_riderEmailController.text.trim())) {
      SnackBarHelper.showError(context, 'Please enter a valid email address');
      return;
    }
    
    // Validate address
    if (_riderAddress == null) {
      SnackBarHelper.showError(context, 'Please select your address');
      return;
    }
    
    // Validate password
    if (_riderPasswordController.text.isEmpty) {
      SnackBarHelper.showError(context, 'Please enter your password');
      return;
    }
    
    // Validate password requirements
    if (_riderPasswordController.text.length < 6) {
      SnackBarHelper.showError(context, 'Password must be at least 6 characters');
      return;
    }
    
    if (!RegExp(r'[A-Z]').hasMatch(_riderPasswordController.text)) {
      SnackBarHelper.showError(context, 'Password must contain at least 1 uppercase letter');
      return;
    }
    
    if (!RegExp(r'[a-z]').hasMatch(_riderPasswordController.text)) {
      SnackBarHelper.showError(context, 'Password must contain at least 1 lowercase letter');
      return;
    }
    
    if (!RegExp(r'[0-9]').hasMatch(_riderPasswordController.text)) {
      SnackBarHelper.showError(context, 'Password must contain at least 1 number');
      return;
    }

    setState(() => _isLoading = true);

    final result = await _authService.signUp(
      _riderEmailController.text.trim(),
      _riderPasswordController.text,
      'rider',
      firstName: _riderFirstNameController.text.trim(),
      lastName: _riderLastNameController.text.trim(),
      addressData: _riderAddress,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
      SnackBarHelper.showSuccess(context, 'Registration successful! Wait for the admin to approve it.');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      SnackBarHelper.showError(context, result['message']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // Navigate back to guest view
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const GuestHome(),
            ),
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
        labelStyle: GoogleFonts.goudyBookletter1911(fontSize: 16.sp, fontWeight: FontWeight.w600),
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
                  decoration: InputDecoration(
                    labelText: 'First Name',
                    labelStyle: GoogleFonts.goudyBookletter1911(),
                    filled: true,
                    fillColor: AppColors.surfaceVariant(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: TextField(
                  controller: _buyerLastNameController,
                  decoration: InputDecoration(
                    labelText: 'Last Name',
                    labelStyle: GoogleFonts.goudyBookletter1911(),
                    filled: true,
                    fillColor: AppColors.surfaceVariant(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          TextField(
            controller: _buyerEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
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
          GestureDetector(
            onTap: () => _showAddressModal(true),
            child: Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant(context),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _getAddressDisplay(_buyerAddress),
                      style: GoogleFonts.goudyBookletter1911(
                        color: _buyerAddress == null ? AppColors.textMuted(context) : AppColors.onSurface(context),
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16.r),
                ],
              ),
            ),
          ),
          SizedBox(height: 16.h),
          TextField(
            controller: _buyerPasswordController,
            obscureText: !_buyerPasswordVisible,
            decoration: InputDecoration(
              labelText: 'Password',
              labelStyle: GoogleFonts.goudyBookletter1911(),
              filled: true,
              fillColor: AppColors.surfaceVariant(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _buyerPasswordVisible ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () => setState(() => _buyerPasswordVisible = !_buyerPasswordVisible),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          _buildPasswordGuidelines(),
          SizedBox(height: 24.h),
          ElevatedButton(
            onPressed: _isLoading ? null : _registerBuyer,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.onSurface(context),
              foregroundColor: AppColors.surface(context),
              padding: EdgeInsets.symmetric(vertical: 16.h),
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
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.surface(context)),
                    ),
                  )
                : Text(
                    'Register as Buyer',
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Already have an account? ',
                style: GoogleFonts.goudyBookletter1911(color: AppColors.textMuted(context)),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: Text(
                  'Login',
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
    );
  }

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
                  decoration: InputDecoration(
                    labelText: 'First Name',
                    labelStyle: GoogleFonts.goudyBookletter1911(),
                    filled: true,
                    fillColor: AppColors.surfaceVariant(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: TextField(
                  controller: _riderLastNameController,
                  decoration: InputDecoration(
                    labelText: 'Last Name',
                    labelStyle: GoogleFonts.goudyBookletter1911(),
                    filled: true,
                    fillColor: AppColors.surfaceVariant(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          TextField(
            controller: _riderEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
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
          GestureDetector(
            onTap: () => _showAddressModal(false),
            child: Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant(context),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _getAddressDisplay(_riderAddress),
                      style: GoogleFonts.goudyBookletter1911(
                        color: _riderAddress == null ? AppColors.textMuted(context) : AppColors.onSurface(context),
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16.r),
                ],
              ),
            ),
          ),
          SizedBox(height: 16.h),
          TextField(
            controller: _riderPasswordController,
            obscureText: !_riderPasswordVisible,
            decoration: InputDecoration(
              labelText: 'Password',
              labelStyle: GoogleFonts.goudyBookletter1911(),
              filled: true,
              fillColor: AppColors.surfaceVariant(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _riderPasswordVisible ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () => setState(() => _riderPasswordVisible = !_riderPasswordVisible),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          _buildPasswordGuidelines(),
          SizedBox(height: 24.h),
          ElevatedButton(
            onPressed: _isLoading ? null : _registerRider,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.onSurface(context),
              foregroundColor: AppColors.surface(context),
              padding: EdgeInsets.symmetric(vertical: 16.h),
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
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.surface(context)),
                    ),
                  )
                : Text(
                    'Register as Rider',
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Already have an account? ',
                style: GoogleFonts.goudyBookletter1911(color: AppColors.textMuted(context)),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: Text(
                  'Login',
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
          SizedBox(height: 4.h),
          _buildGuidelineItem('6+ characters'),
          _buildGuidelineItem('1 uppercase letter'),
          _buildGuidelineItem('1 lowercase letter'),
          _buildGuidelineItem('1 number'),
        ],
      ),
    );
  }

  Widget _buildGuidelineItem(String text) {
    return Padding(
      padding: EdgeInsets.only(top: 2.h),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, size: 14.r, color: AppColors.textMuted(context)),
          SizedBox(width: 6.w),
          Text(
            text,
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 11.sp,
              color: AppColors.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
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
