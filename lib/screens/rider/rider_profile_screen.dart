import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/image_helper.dart';
import '../auth/login_screen.dart';
import 'verification_documents_screen.dart';

import '../../utils/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
class RiderProfileScreen extends StatefulWidget {
  final bool hideScaffold;

  const RiderProfileScreen({super.key, this.hideScaffold = false});

  @override
  State<RiderProfileScreen> createState() => _RiderProfileScreenState();
}

class _RiderProfileScreenState extends State<RiderProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();
  Map<String, dynamic>? _riderData;
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  bool _isUploadingImage = false;

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

      // Get rider data
      final riderResponse = await _supabase
          .from('riders')
          .select('*, users!inner(email)')
          .eq('user_id', userId)
          .single();

      // Get stats
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
            'rating': 4.8, // Placeholder for now
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading rider profile: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _isLoading
        ? Center(child: CircularProgressIndicator(color: AppColors.onSurface(context)))
        : RefreshIndicator(
            onRefresh: _loadRiderProfile,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  _buildProfileHeader(),
                  SizedBox(height: 16.h),
                  _buildStatsSection(),
                  SizedBox(height: 16.h),
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
        backgroundColor: AppColors.surface(context),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Profile',
          style: GoogleFonts.goudyBookletter1911(
            color: AppColors.onSurface(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: content,
    );
  }

  Widget _buildProfileHeader() {
    final firstName = _riderData?['first_name'] ?? '';
    final lastName = _riderData?['last_name'] ?? '';
    final email =
        _riderData?['users']?['email'] ?? AuthService().currentUserEmail ?? '';
    final profileImage = _riderData?['profile_image'];
    final initial = firstName.isNotEmpty ? firstName[0].toUpperCase() : 'R';

    // Get full image URL if profile_image exists
    final imageUrl = profileImage != null && profileImage.isNotEmpty
        ? ImageHelper.getImageUrl(profileImage)
        : null;

    return Container(
      padding: EdgeInsets.all(24.w),
      color: AppColors.surface(context),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 100.w,
                height: 100.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.border(context),
                ),
                child: _isUploadingImage
                    ? Center(
                        child: CircularProgressIndicator(
                          color: AppColors.onSurface(context),
                          strokeWidth: 2,
                        ),
                      )
                    : imageUrl != null
                    ? ClipOval(
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Text(
                                initial,
                                style: GoogleFonts.goudyBookletter1911(
                                  fontSize: 40.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textMuted(context),
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    : Center(
                        child: Text(
                          initial,
                          style: GoogleFonts.goudyBookletter1911(
                            fontSize: 40.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMuted(context),
                          ),
                        ),
                      ),
              ),
              if (!_isUploadingImage)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _showImageSourceDialog,
                    child: Container(
                      padding: EdgeInsets.all(6.w),
                      decoration: BoxDecoration(
                        color: AppColors.onSurface(context),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        color: AppColors.surface(context),
                        size: 18.r,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 16.h),
          Text(
            firstName.isNotEmpty && lastName.isNotEmpty
                ? '$firstName $lastName'
                : email,
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            email,
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 13.sp,
              color: AppColors.textMuted(context),
            ),
          ),
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(5.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, color: Colors.green, size: 16.r),
                SizedBox(width: 4.w),
                Text(
                  'Verified Rider',
                  style: GoogleFonts.goudyBookletter1911(
                    color: Colors.green,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    final totalDeliveries = _stats?['total_deliveries'] ?? 0;
    final rating = _stats?['rating'] ?? 0.0;
    final thisMonth = _stats?['this_month'] ?? 0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(5.r),
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
            Icons.local_shipping,
          ),
          Container(width: 1.w, height: 50.h, color: AppColors.border(context)),
          _buildStatItem('Rating', rating.toStringAsFixed(1), Icons.star),
          Container(width: 1.w, height: 50.h, color: AppColors.border(context)),
          _buildStatItem(
            'This Month',
            thisMonth.toString(),
            Icons.calendar_today,
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
          style: GoogleFonts.goudyBookletter1911(
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
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(5.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMenuItem(
            Icons.person_outline,
            'Personal Information',
            'Update your profile details',
            () => _showPersonalInfoDialog(),
          ),
          _buildDivider(),
          _buildMenuItem(
            Icons.motorcycle,
            'Vehicle Information',
            'Manage your vehicle details',
            () => _showVehicleInfoDialog(),
          ),
          _buildDivider(),
          _buildMenuItem(
            Icons.shield_outlined,
            'Verification Documents',
            'Upload OR/CR and Driver\'s License',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const VerificationDocumentsScreen(),
                ),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            Icons.logout,
            'Logout',
            'Sign out of your account',
            _showLogoutDialog,
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: isDestructive
                      ? Colors.red.withValues(alpha: 0.1)
                      : AppColors.surfaceVariant(context),
                  borderRadius: BorderRadius.circular(5.r),
                ),
                child: Icon(
                  icon,
                  color: isDestructive ? Colors.red : AppColors.onSurface(context),
                  size: 22.r,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w500,
                        color: isDestructive ? Colors.red : AppColors.onSurface(context),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 12.sp,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textFaint(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Divider(height: 1, color: AppColors.surfaceVariant2(context)),
    );
  }

  void _showLogoutDialog() {
    showDialog(
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
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.goudyBookletter1911(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: AppColors.surface(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5.r),
              ),
            ),
            onPressed: () async {
              await AuthService().logout();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: Text(
              'Logout',
              style: GoogleFonts.goudyBookletter1911(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPersonalInfoDialog() {
    final firstNameController = TextEditingController(
      text: _riderData?['first_name'] ?? '',
    );
    final lastNameController = TextEditingController(
      text: _riderData?['last_name'] ?? '',
    );
    final phoneController = TextEditingController(
      text: _riderData?['phone_number'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Personal Information',
          style: GoogleFonts.goudyBookletter1911(fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstNameController,
                decoration: InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5.r),
                  ),
                  labelStyle: GoogleFonts.goudyBookletter1911(),
                ),
                style: GoogleFonts.goudyBookletter1911(),
              ),
              SizedBox(height: 16.h),
              TextField(
                controller: lastNameController,
                decoration: InputDecoration(
                  labelText: 'Last Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5.r),
                  ),
                  labelStyle: GoogleFonts.goudyBookletter1911(),
                ),
                style: GoogleFonts.goudyBookletter1911(),
              ),
              SizedBox(height: 16.h),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 11,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '09XXXXXXXXX',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5.r),
                  ),
                  labelStyle: GoogleFonts.goudyBookletter1911(),
                  counterText: '',
                ),
                style: GoogleFonts.goudyBookletter1911(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.goudyBookletter1911(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.onSurface(context),
              foregroundColor: AppColors.surface(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5.r),
              ),
            ),
            onPressed: () async {
              final firstName = firstNameController.text.trim();
              final lastName = lastNameController.text.trim();
              final phone = phoneController.text.trim();

              if (firstName.isEmpty || lastName.isEmpty) {
                SnackBarHelper.showError(
                  context,
                  'First name and last name are required',
                );
                return;
              }

              try {
                final userId = AuthService().currentUserId;
                await _supabase
                    .from('riders')
                    .update({
                      'first_name': firstName,
                      'last_name': lastName,
                      'phone_number': phone.isNotEmpty ? phone : null,
                    })
                    .eq('user_id', userId!);

                Navigator.pop(context);
                await _loadRiderProfile();

                if (mounted) {
                  SnackBarHelper.showSuccess(
                    context,
                    'Profile updated successfully!',
                  );
                }
              } catch (e) {
                if (mounted) {
                  SnackBarHelper.showError(context, 'Failed to update profile');
                }
              }
            },
            child: Text(
              'Save',
              style: GoogleFonts.goudyBookletter1911(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showVehicleInfoDialog() {
    final plateNumberController = TextEditingController(
      text: _riderData?['plate_number'] ?? '',
    );

    String selectedVehicleType = _riderData?['vehicle_type'] ?? 'Motorcycle';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Vehicle Information',
            style: GoogleFonts.goudyBookletter1911(fontWeight: FontWeight.w600),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedVehicleType,
                  decoration: InputDecoration(
                    labelText: 'Vehicle Type',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5.r),
                    ),
                    labelStyle: GoogleFonts.goudyBookletter1911(),
                  ),
                  style: GoogleFonts.goudyBookletter1911(color: AppColors.onSurface(context)),
                  items: ['Motorcycle', 'Bicycle', 'Tricycle', 'Car', 'Van']
                      .map(
                        (type) =>
                            DropdownMenuItem(value: type, child: Text(type)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedVehicleType = value);
                    }
                  },
                ),
                SizedBox(height: 16.h),
                TextField(
                  controller: plateNumberController,
                  decoration: InputDecoration(
                    labelText: 'Plate Number',
                    hintText: 'ABC 1234',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5.r),
                    ),
                    labelStyle: GoogleFonts.goudyBookletter1911(),
                  ),
                  style: GoogleFonts.goudyBookletter1911(),
                  textCapitalization: TextCapitalization.characters,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.goudyBookletter1911(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.onSurface(context),
                foregroundColor: AppColors.surface(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5.r),
                ),
              ),
              onPressed: () async {
                final plateNumber = plateNumberController.text.trim();

                try {
                  final userId = AuthService().currentUserId;
                  await _supabase
                      .from('riders')
                      .update({
                        'vehicle_type': selectedVehicleType,
                        'plate_number': plateNumber.isNotEmpty
                            ? plateNumber
                            : null,
                      })
                      .eq('user_id', userId!);

                  Navigator.pop(context);
                  await _loadRiderProfile();

                  if (mounted) {
                    SnackBarHelper.showSuccess(
                      context,
                      'Vehicle information updated successfully!',
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    SnackBarHelper.showError(
                      context,
                      'Failed to update vehicle info',
                    );
                  }
                }
              },
              child: Text(
                'Save',
                style: GoogleFonts.goudyBookletter1911(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Choose Image Source',
          style: GoogleFonts.goudyBookletter1911(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: AppColors.onSurface(context)),
              title: Text('Camera', style: GoogleFonts.goudyBookletter1911()),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: AppColors.onSurface(context)),
              title: Text('Gallery', style: GoogleFonts.goudyBookletter1911()),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      // Pick image
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() => _isUploadingImage = true);

      final userId = AuthService().currentUserId;
      if (userId == null) throw Exception('User not logged in');

      // Get rider_id
      final riderData = await _supabase
          .from('riders')
          .select('rider_id')
          .eq('user_id', userId)
          .single();

      final riderId = riderData['rider_id'];

      // Create unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = pickedFile.path.split('.').last;
      final fileName = 'rider_${riderId}_$timestamp.$extension';
      final filePath = 'static/uploads/profiles/$fileName';

      // Upload to Supabase Storage (bucket: Images)
      final file = File(pickedFile.path);
      await _supabase.storage
          .from('Images')
          .upload(
            filePath,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      // Update database with new image path
      await _supabase
          .from('riders')
          .update({'profile_image': filePath})
          .eq('user_id', userId);

      // Reload profile
      await _loadRiderProfile();

      if (mounted) {
        setState(() => _isUploadingImage = false);
        SnackBarHelper.showSuccess(
          context,
          'Profile image updated successfully!',
        );
      }
    } catch (e) {
      print('Error uploading image: $e');
      if (mounted) {
        setState(() => _isUploadingImage = false);
        SnackBarHelper.showError(
          context,
          'Failed to upload image: ${e.toString()}',
        );
      }
    }
  }
}
