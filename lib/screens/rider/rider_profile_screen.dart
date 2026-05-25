import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/image_helper.dart';
import '../../utils/app_colors.dart';
import '../auth/login_screen.dart';
import 'verification_documents_screen.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';

class RiderProfileScreen extends StatefulWidget {
  final bool hideScaffold;

  const RiderProfileScreen({super.key, this.hideScaffold = false});

  @override
  State<RiderProfileScreen> createState() => _RiderProfileScreenState();
}

class _RiderProfileScreenState extends State<RiderProfileScreen> {
  final _supabase = Supabase.instance.client;

  Map<String, dynamic>? _riderData;
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRiderProfile();
  }

  Future<void> _loadRiderProfile() async {
    setState(() => _isLoading = true);
    try {
      final userId = AuthService().currentUserId;
      if (userId == null) throw Exception('User not logged in');

      // Get rider data with email from joined users table
      final riderResponse = await _supabase
          .from('riders')
          .select('*, users!inner(email)')
          .eq('user_id', userId)
          .single();

      final riderId = riderResponse['rider_id'];

      // Total deliveries
      final totalDeliveries = await _supabase
          .from('deliveries')
          .select('delivery_id')
          .eq('rider_id', riderId)
          .eq('status', 'delivered');

      // This month deliveries
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final thisMonthDeliveries = await _supabase
          .from('deliveries')
          .select('delivery_id')
          .eq('rider_id', riderId)
          .eq('status', 'delivered')
          .gte('delivered_at', firstDayOfMonth.toIso8601String());

      if (mounted) {
        setState(() {
          _riderData = riderResponse;
          _stats = {
            'total_deliveries': totalDeliveries.length,
            'this_month': thisMonthDeliveries.length,
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading rider profile: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Logout',
          style: GoogleFonts.goudyBookletter1911(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.goudyBookletter1911(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.goudyBookletter1911(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Logout',
              style: GoogleFonts.goudyBookletter1911(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService().logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  void _showProfileModal() {
    if (_riderData == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProfileInfoModal(
        riderData: _riderData!,
        onUpdate: _loadRiderProfile,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _isLoading
        ? Center(
            child: CircularProgressIndicator(color: AppColors.onSurface(context)),
          )
        : RefreshIndicator(
            onRefresh: _loadRiderProfile,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  _buildHeader(),
                  _buildStatsSection(),
                  _buildMenuSection(),
                ],
              ),
            ),
          );

    if (widget.hideScaffold) {
      return SafeArea(child: content);
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground(context),
      appBar: AppBar(
        title: Text(
          'Profile',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.surface(context),
        foregroundColor: AppColors.onSurface(context),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(child: content),
    );
  }

  /// Builds a fallback avatar showing the rider's first initial in gold.
  Widget _buildInitialAvatar(double fontSize) {
    final firstName = _riderData?['first_name']?.toString() ?? '';
    final email = _riderData?['users']?['email']?.toString() ?? '';
    final initial = firstName.isNotEmpty
        ? firstName[0].toUpperCase()
        : email.isNotEmpty
            ? email[0].toUpperCase()
            : 'R';
    return Container(
      color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.playfairDisplay(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFD4AF37),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final firstName = _riderData?['first_name']?.toString() ?? '';
    final lastName = _riderData?['last_name']?.toString() ?? '';
    final email = _riderData?['users']?['email']?.toString() ??
        AuthService().currentUserEmail ??
        '';
    final profileImage = _riderData?['profile_image']?.toString();
    final imageUrl = (profileImage != null && profileImage.isNotEmpty)
        ? ImageHelper.getImageUrl(profileImage)
        : null;

    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Profile picture on the left
          Container(
            width: 80.w,
            height: 80.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFD4AF37),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          _buildInitialAvatar(36.sp),
                      errorWidget: (context, url, error) =>
                          _buildInitialAvatar(36.sp),
                    )
                  : _buildInitialAvatar(36.sp),
            ),
          ),
          SizedBox(width: 16.w),
          // Name and email in the middle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  firstName.isNotEmpty || lastName.isNotEmpty
                      ? '$firstName $lastName'.trim()
                      : email.isNotEmpty
                          ? email
                          : 'Rider',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (email.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  Text(
                    email,
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 13.sp,
                      color: AppColors.textMuted(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                SizedBox(height: 6.h),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, color: Colors.green, size: 12.r),
                      SizedBox(width: 3.w),
                      Text(
                        'Verified Rider',
                        style: GoogleFonts.goudyBookletter1911(
                          color: Colors.green,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          // Button on the right
          OutlinedButton(
            onPressed: _showProfileModal,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.onSurface(context),
              side: BorderSide(color: AppColors.onSurface(context), width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6.r),
              ),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              minimumSize: const Size(0, 36),
            ),
            child: Text(
              'View Details',
              style: GoogleFonts.goudyBookletter1911(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    final totalDeliveries = _stats?['total_deliveries'] ?? 0;
    final thisMonth = _stats?['this_month'] ?? 0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'Total Deliveries',
            totalDeliveries.toString(),
            Icons.local_shipping_outlined,
          ),
          Container(width: 1.w, height: 50.h, color: AppColors.border(context)),
          _buildStatItem(
            'This Month',
            thisMonth.toString(),
            Icons.calendar_today_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.onSurface(context), size: 24.r),
        SizedBox(height: 8.h),
        Text(
          value,
          style: GoogleFonts.playfairDisplay(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.goudyBookletter1911(
            fontSize: 11.sp,
            color: AppColors.textMuted(context),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuSection() {
    return Column(
      children: [
        SizedBox(height: 16.h),
        _buildMenuGroup(
          title: 'Account',
          items: [
            _MenuItem(
              icon: Icons.shield_outlined,
              title: 'Verification Documents',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const VerificationDocumentsScreen(),
                  ),
                ).then((_) => _loadRiderProfile());
              },
            ),
          ],
        ),
        SizedBox(height: 16.h),
        _buildAppearanceGroup(),
        SizedBox(height: 16.h),
        _buildMenuGroup(
          items: [
            _MenuItem(
              icon: Icons.logout,
              title: 'Logout',
              onTap: _logout,
              isDestructive: true,
            ),
          ],
        ),
        SizedBox(height: 24.h),
      ],
    );
  }

  /// Appearance section with the dark mode toggle.
  Widget _buildAppearanceGroup() {
    final themeService = ThemeService();
    return AnimatedBuilder(
      animation: themeService,
      builder: (context, _) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16.w),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
                child: Text(
                  'Appearance',
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted(context),
                  ),
                ),
              ),
              SwitchListTile(
                value: themeService.isDarkMode,
                onChanged: (value) {
                  themeService.setDarkMode(value);
                },
                secondary: Icon(
                  themeService.isDarkMode
                      ? Icons.dark_mode_outlined
                      : Icons.light_mode_outlined,
                  color: AppColors.onSurface(context),
                ),
                title: Text(
                  'Dark Mode',
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurface(context),
                  ),
                ),
                subtitle: Text(
                  themeService.isDarkMode ? 'On' : 'Off',
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 12.sp,
                    color: AppColors.textMuted(context),
                  ),
                ),
                activeThumbColor: const Color(0xFFD4AF37),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuGroup({String? title, required List<_MenuItem> items}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
              child: Text(
                title,
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted(context),
                ),
              ),
            ),
          ],
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Column(
              children: [
                if (index > 0) const Divider(height: 1),
                _buildMenuItem(item),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMenuItem(_MenuItem item) {
    return ListTile(
      leading: Icon(
        item.icon,
        color: item.isDestructive ? Colors.red : AppColors.onSurface(context),
      ),
      title: Text(
        item.title,
        style: GoogleFonts.goudyBookletter1911(
          fontSize: 15.sp,
          fontWeight: FontWeight.w500,
          color: item.isDestructive ? Colors.red : AppColors.onSurface(context),
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16.r,
        color: item.isDestructive ? Colors.red : AppColors.textFaint(context),
      ),
      onTap: item.onTap,
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });
}

class _ProfileInfoModal extends StatefulWidget {
  final Map<String, dynamic> riderData;
  final VoidCallback onUpdate;

  const _ProfileInfoModal({
    required this.riderData,
    required this.onUpdate,
  });

  @override
  State<_ProfileInfoModal> createState() => _ProfileInfoModalState();
}

class _ProfileInfoModalState extends State<_ProfileInfoModal> {
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingImage = false;

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _plateNumberController;
  String? _selectedVehicleType;
  String? _newProfilePicture;

  static const List<String> _vehicleTypes = [
    'Motorcycle',
    'Bicycle',
    'Tricycle',
    'Car',
    'Van',
  ];

  String? get _userEmail => widget.riderData['users']?['email']?.toString();
  String? get _idType => widget.riderData['id_type']?.toString();
  String? get _idFilePath => widget.riderData['id_file_path']?.toString();
  String? get _orcrFilePath =>
      widget.riderData['orcr_file_path']?.toString();
  String? get _licenseFilePath =>
      widget.riderData['driver_license_file_path']?.toString();

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(
      text: widget.riderData['first_name']?.toString() ?? '',
    );
    _lastNameController = TextEditingController(
      text: widget.riderData['last_name']?.toString() ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.riderData['phone_number']?.toString() ?? '',
    );
    _plateNumberController = TextEditingController(
      text: widget.riderData['plate_number']?.toString() ?? '',
    );
    final vehicleType = widget.riderData['vehicle_type']?.toString();
    _selectedVehicleType =
        (vehicleType != null && _vehicleTypes.contains(vehicleType))
            ? vehicleType
            : null;
    _newProfilePicture = widget.riderData['profile_image']?.toString();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _plateNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (pickedFile == null) return;

    setState(() => _isUploadingImage = true);
    try {
      final userId = AuthService().currentUserId;
      if (userId == null) return;

      final riderId = widget.riderData['rider_id'];
      final extension = pickedFile.path.split('.').last;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'rider_${riderId}_$timestamp.$extension';
      final filePath = 'static/uploads/profiles/$fileName';

      final file = File(pickedFile.path);
      await Supabase.instance.client.storage.from('Images').upload(
            filePath,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      if (mounted) {
        setState(() {
          _newProfilePicture = filePath;
          _isUploadingImage = false;
        });
        SnackBarHelper.showSuccess(context, 'Image uploaded successfully');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        SnackBarHelper.showError(context, 'Failed to upload image: $e');
      }
    }
  }

  Future<void> _saveChanges() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phone = _phoneController.text.trim();
    final plate = _plateNumberController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty) {
      SnackBarHelper.showError(
        context,
        'First name and last name are required',
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final userId = AuthService().currentUserId;
      if (userId == null) return;

      await Supabase.instance.client.from('riders').update({
        'first_name': firstName,
        'last_name': lastName,
        'phone_number': phone.isNotEmpty ? phone : null,
        'vehicle_type': _selectedVehicleType,
        'plate_number': plate.isNotEmpty ? plate : null,
        'profile_image': _newProfilePicture,
      }).eq('user_id', userId);

      if (mounted) {
        widget.onUpdate();
        Navigator.pop(context);
        SnackBarHelper.showSuccess(context, 'Profile updated');
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to update profile');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Builds a fallback avatar for the modal showing the user's first initial in gold.
  Widget _buildModalInitialAvatar() {
    final firstName = widget.riderData['first_name']?.toString() ?? '';
    final email = _userEmail ?? '';
    final initial = firstName.isNotEmpty
        ? firstName[0].toUpperCase()
        : email.isNotEmpty
            ? email[0].toUpperCase()
            : 'R';
    return Center(
      child: Text(
        initial,
        style: GoogleFonts.playfairDisplay(
          fontSize: 44.sp,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFD4AF37),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(20.r),
                        child: Padding(
                          padding: EdgeInsets.all(4.w),
                          child: Icon(
                            Icons.arrow_back,
                            size: 22.r,
                            color: AppColors.onSurface(context),
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Profile Information',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (!_isEditing)
                    TextButton(
                      onPressed: () => setState(() => _isEditing = true),
                      child: Text(
                        'Edit',
                        style: GoogleFonts.goudyBookletter1911(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface(context),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 24.h),
              Center(
                child: GestureDetector(
                  onTap: _isEditing && !_isUploadingImage ? _pickImage : null,
                  child: Stack(
                    children: [
                      Container(
                        width: 100.w,
                        height: 100.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: _isUploadingImage
                            ? Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.onSurface(context),
                                  strokeWidth: 2,
                                ),
                              )
                            : (_newProfilePicture != null &&
                                    _newProfilePicture!.isNotEmpty)
                                ? ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: ImageHelper.getImageUrl(
                                          _newProfilePicture!),
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) =>
                                          _buildModalInitialAvatar(),
                                      errorWidget: (context, url, error) =>
                                          _buildModalInitialAvatar(),
                                    ),
                                  )
                                : _buildModalInitialAvatar(),
                      ),
                      if (_isEditing && !_isUploadingImage)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: EdgeInsets.all(6.w),
                            decoration: BoxDecoration(
                              color: AppColors.onSurface(context),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              size: 16.r,
                              color: AppColors.surface(context),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              _buildInfoField('First Name', _firstNameController, _isEditing),
              SizedBox(height: 16.h),
              _buildInfoField('Last Name', _lastNameController, _isEditing),
              SizedBox(height: 16.h),
              _buildInfoField(
                'Email',
                TextEditingController(text: _userEmail ?? 'Not set'),
                false,
              ),
              SizedBox(height: 16.h),
              _buildInfoField('Phone Number', _phoneController, _isEditing),
              SizedBox(height: 16.h),
              _buildVehicleTypeField(),
              SizedBox(height: 16.h),
              _buildInfoField(
                'Plate Number',
                _plateNumberController,
                _isEditing,
              ),
              SizedBox(height: 16.h),
              _buildVerificationIdSection(),
              SizedBox(height: 16.h),
              _buildVehicleDocumentsSection(),
              if (_isEditing) ...[
                SizedBox(height: 24.h),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving
                            ? null
                            : () {
                                setState(() {
                                  _isEditing = false;
                                  _firstNameController.text =
                                      widget.riderData['first_name']
                                              ?.toString() ??
                                          '';
                                  _lastNameController.text =
                                      widget.riderData['last_name']
                                              ?.toString() ??
                                          '';
                                  _phoneController.text =
                                      widget.riderData['phone_number']
                                              ?.toString() ??
                                          '';
                                  _plateNumberController.text =
                                      widget.riderData['plate_number']
                                              ?.toString() ??
                                          '';
                                  final vt = widget.riderData['vehicle_type']
                                      ?.toString();
                                  _selectedVehicleType = (vt != null &&
                                          _vehicleTypes.contains(vt))
                                      ? vt
                                      : null;
                                  _newProfilePicture = widget
                                      .riderData['profile_image']
                                      ?.toString();
                                });
                              },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.grey),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5.r),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.goudyBookletter1911(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textBody(context),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.onSurface(context),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5.r),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                        ),
                        child: _isSaving
                            ? SizedBox(
                                width: 16.w,
                                height: 16.h,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.surface(context),
                                  ),
                                ),
                              )
                            : Text(
                                'Save',
                                style: GoogleFonts.goudyBookletter1911(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.surface(context),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoField(
    String label,
    TextEditingController controller,
    bool enabled,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.goudyBookletter1911(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted(context),
          ),
        ),
        SizedBox(height: 8.h),
        TextField(
          controller: controller,
          enabled: enabled,
          readOnly: !enabled,
          style: GoogleFonts.goudyBookletter1911(fontSize: 14.sp),
          decoration: InputDecoration(
            filled: true,
            fillColor: enabled
                ? AppColors.surfaceVariant(context)
                : AppColors.scaffoldBackground(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(color: AppColors.border(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(color: AppColors.border(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(color: AppColors.onSurface(context)),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide:
                  BorderSide(color: AppColors.surfaceVariant2(context)),
            ),
            contentPadding:
                EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleTypeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vehicle Type',
          style: GoogleFonts.goudyBookletter1911(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted(context),
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: _isEditing
                ? AppColors.surfaceVariant(context)
                : AppColors.scaffoldBackground(context),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: _isEditing
              ? DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedVehicleType,
                    isExpanded: true,
                    isDense: true,
                    hint: Text(
                      'Select vehicle type',
                      style: GoogleFonts.goudyBookletter1911(fontSize: 14.sp),
                    ),
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 14.sp,
                      color: AppColors.onSurface(context),
                    ),
                    items: _vehicleTypes.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                    onChanged: (value) =>
                        setState(() => _selectedVehicleType = value),
                  ),
                )
              : Text(
                  _selectedVehicleType ?? 'Not set',
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 14.sp,
                    color: _selectedVehicleType != null
                        ? AppColors.onSurface(context)
                        : AppColors.textFaint(context),
                  ),
                ),
        ),
      ],
    );
  }

  /// Read-only section that shows the ID type the rider selected during
  /// registration plus a thumbnail of the uploaded ID file. Tapping the
  /// thumbnail opens a fullscreen, pinch-to-zoom viewer.
  Widget _buildVerificationIdSection() {
    final idType = _idType;
    final idPath = _idFilePath;
    final hasId = idPath != null && idPath.isNotEmpty;
    final imageUrl = hasId ? ImageHelper.getImageUrl(idPath) : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Verification ID',
          style: GoogleFonts.goudyBookletter1911(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted(context),
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppColors.scaffoldBackground(context),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.badge_outlined,
                    size: 18.r,
                    color: AppColors.textMuted(context),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      idType != null && idType.isNotEmpty
                          ? idType
                          : 'No ID type on file',
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: idType != null && idType.isNotEmpty
                            ? AppColors.onSurface(context)
                            : AppColors.textFaint(context),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              if (hasId)
                _buildIdThumbnail(imageUrl)
              else
                _buildEmptyIdPlaceholder('No ID image uploaded'),
            ],
          ),
        ),
      ],
    );
  }

  /// Read-only display of OR/CR and Driver's License. Riders can tap a
  /// thumbnail to view fullscreen, or open the dedicated screen via
  /// "Manage Documents" to edit/upload.
  Widget _buildVehicleDocumentsSection() {
    final orcrPath = _orcrFilePath;
    final licensePath = _licenseFilePath;
    final hasOrcr = orcrPath != null && orcrPath.isNotEmpty;
    final hasLicense = licensePath != null && licensePath.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Vehicle Documents',
              style: GoogleFonts.goudyBookletter1911(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted(context),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const VerificationDocumentsScreen(),
                  ),
                ).then((_) => widget.onUpdate());
              },
              child: Text(
                'Manage',
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface(context),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppColors.scaffoldBackground(context),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 18.r,
                    color: AppColors.textMuted(context),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'OR / CR',
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurface(context),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              if (hasOrcr)
                _buildIdThumbnail(ImageHelper.getImageUrl(orcrPath))
              else
                _buildEmptyIdPlaceholder('OR/CR not uploaded'),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Icon(
                    Icons.card_membership_outlined,
                    size: 18.r,
                    color: AppColors.textMuted(context),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    "Driver's License",
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurface(context),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              if (hasLicense)
                _buildIdThumbnail(ImageHelper.getImageUrl(licensePath))
              else
                _buildEmptyIdPlaceholder("Driver's license not uploaded"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIdThumbnail(String imageUrl) {
    return GestureDetector(
      onTap: () => _showIdImageDialog(imageUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.r),
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: AppColors.surfaceVariant2(context),
                  child: Center(
                    child: SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: AppColors.surfaceVariant2(context),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.broken_image_outlined,
                          size: 32.r,
                          color: AppColors.textFaint(context),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'Failed to load image',
                          style: GoogleFonts.goudyBookletter1911(
                            fontSize: 12.sp,
                            color: AppColors.textFaint(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.zoom_in, size: 14.r, color: Colors.white),
                    SizedBox(width: 4.w),
                    Text(
                      'Tap to view',
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 11.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyIdPlaceholder(String message) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 16.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant2(context),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 28.r,
            color: AppColors.textFaint(context),
          ),
          SizedBox(height: 6.h),
          Text(
            message,
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 12.sp,
              color: AppColors.textFaint(context),
            ),
          ),
        ],
      ),
    );
  }

  void _showIdImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(12.w),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => SizedBox(
                    width: 32.w,
                    height: 32.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    padding: EdgeInsets.all(20.w),
                    color: AppColors.surface(context),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48.r,
                          color: Colors.red,
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'Failed to load image',
                          style: GoogleFonts.goudyBookletter1911(
                            fontSize: 14.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 28.r),
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
