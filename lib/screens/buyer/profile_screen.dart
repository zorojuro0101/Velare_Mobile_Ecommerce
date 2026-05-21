import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../services/cart_service.dart';
import '../../services/chat_service.dart';
import '../../services/notification_service.dart';
import '../../services/theme_service.dart';
import '../../utils/image_helper.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/icon_badge.dart';
import '../auth/login_screen.dart';
import 'order_history_screen.dart';
import 'address_management_screen.dart';
import 'notifications_screen.dart';
import 'vouchers_screen.dart';
import 'my_reports_screen.dart';
import 'cart_screen.dart';
import 'chat_list_screen.dart';
import 'about_us_screen.dart';

import '../../utils/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _cartService = CartService();
  final _chatService = ChatService();
  final _notificationService = NotificationService();
  String? _firstName;
  String? _lastName;
  String? _userEmail;
  String? _profilePicture;
  String? _gender;
  String? _phoneNumber;
  
  int _cartCount = 0;
  int _unreadChatCount = 0;
  int _unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadCounts();
  }
  
  Future<void> _loadCounts() async {
    final buyerId = _cartService.getCurrentBuyerId();
    final userId = _cartService.getCurrentUserId();
    
    if (buyerId != null && userId != null) {
      try {
        // Load all counts in parallel for faster loading
        final results = await Future.wait([
          _cartService.getCartItems(buyerId),
          _chatService.getUnreadCount(buyerId, userId),
          _notificationService.getUnreadCount(userId),
        ]);
        
        if (mounted) {
          setState(() {
            _cartCount = (results[0] as List).length;
            _unreadChatCount = results[1] as int;
            _unreadNotificationCount = results[2] as int;
          });
        }
      } catch (e) {
        print('Error loading counts: $e');
      }
    }
  }

  void _loadUserInfo() async {
    final buyerId = _authService.currentBuyerId;
    final userId = _authService.currentUserId;
    
    if (buyerId == null || userId == null) {
      return;
    }

    try {
      // Get buyer info from buyers table
      final buyerResponse = await Supabase.instance.client
          .from('buyers')
          .select('first_name, last_name, profile_image, gender, phone_number')
          .eq('buyer_id', buyerId)
          .maybeSingle();

      // Get email from users table
      final userResponse = await Supabase.instance.client
          .from('users')
          .select('email')
          .eq('user_id', userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _firstName = buyerResponse?['first_name']?.toString();
          _lastName = buyerResponse?['last_name']?.toString();
          _userEmail = userResponse?['email']?.toString();
          _profilePicture = buyerResponse?['profile_image']?.toString();
          _gender = buyerResponse?['gender']?.toString();
          _phoneNumber = buyerResponse?['phone_number']?.toString();
        });
      }
    } catch (e) {
      print('Error loading buyer info: $e');
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout', style: GoogleFonts.goudyBookletter1911(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to logout?', style: GoogleFonts.goudyBookletter1911()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.goudyBookletter1911(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Logout', style: GoogleFonts.goudyBookletter1911(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.logout();
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProfileInfoModal(
        firstName: _firstName,
        lastName: _lastName,
        userEmail: _userEmail,
        profilePicture: _profilePicture,
        gender: _gender,
        phoneNumber: _phoneNumber,
        onUpdate: _loadUserInfo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground(context),
      appBar: AppBar(
        title: Text('Profile', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface(context),
        foregroundColor: AppColors.onSurface(context),
        elevation: 0,
        actions: [
          NotificationDot(
            icon: Icons.notifications_outlined,
            showDot: _unreadNotificationCount > 0,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ).then((_) => _loadCounts());
            },
          ),
          IconBadge(
            icon: Icons.shopping_cart_outlined,
            count: _cartCount,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartScreen()),
              ).then((_) => _loadCounts());
            },
          ),
          NotificationDot(
            icon: Icons.chat_bubble_outline,
            showDot: _unreadChatCount > 0,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatListScreen()),
              ).then((_) => _loadCounts());
            },
          ),
          SizedBox(width: 8.w),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              _buildMenuSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
              child: _profilePicture != null && _profilePicture!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: ImageHelper.getImageUrl(_profilePicture!),
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: AppColors.surfaceVariant2(context),
                        child: Icon(Icons.person, size: 40.r, color: AppColors.textFaint(context)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.surfaceVariant2(context),
                        child: Icon(Icons.person, size: 40.r, color: AppColors.textFaint(context)),
                      ),
                    )
                  : Container(
                      color: AppColors.surfaceVariant2(context),
                      child: Icon(Icons.person, size: 40.r, color: AppColors.textFaint(context)),
                    ),
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
                  _firstName != null || _lastName != null
                      ? '${_firstName ?? ''} ${_lastName ?? ''}'.trim()
                      : _userEmail ?? 'User',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_userEmail != null) ...[
                  SizedBox(height: 4.h),
                  Text(
                    _userEmail!,
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 13.sp,
                      color: AppColors.textMuted(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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

  Widget _buildMenuSection() {
    return Column(
      children: [
        SizedBox(height: 16.h),
        _buildMenuGroup(
          title: 'Orders',
          items: [
            _MenuItem(
              icon: Icons.shopping_bag_outlined,
              title: 'My Orders',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
                );
              },
            ),
          ],
        ),
        SizedBox(height: 16.h),
        _buildMenuGroup(
          title: 'Account',
          items: [
            _MenuItem(
              icon: Icons.location_on_outlined,
              title: 'Addresses',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddressManagementScreen()),
                );
              },
            ),
            _MenuItem(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                );
              },
            ),
            _MenuItem(
              icon: Icons.confirmation_number_outlined,
              title: 'My Vouchers',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VouchersScreen()),
                );
              },
            ),
            _MenuItem(
              icon: Icons.report_outlined,
              title: 'My Reports',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyReportsScreen()),
                );
              },
            ),
            _MenuItem(
              icon: Icons.info_outline,
              title: 'About Us',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutUsScreen()),
                );
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
  final String? firstName;
  final String? lastName;
  final String? userEmail;
  final String? profilePicture;
  final String? gender;
  final String? phoneNumber;
  final VoidCallback onUpdate;

  const _ProfileInfoModal({
    this.firstName,
    this.lastName,
    this.userEmail,
    this.profilePicture,
    this.gender,
    this.phoneNumber,
    required this.onUpdate,
  });

  @override
  State<_ProfileInfoModal> createState() => _ProfileInfoModalState();
}

class _ProfileInfoModalState extends State<_ProfileInfoModal> {
  bool _isEditing = false;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  String? _selectedGender;
  String? _newProfilePicture;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.firstName);
    _lastNameController = TextEditingController(text: widget.lastName);
    _phoneController = TextEditingController(text: widget.phoneNumber);
    _selectedGender = widget.gender;
    _newProfilePicture = widget.profilePicture;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      // Upload to Supabase storage
      try {
        final buyerId = AuthService().currentBuyerId;
        if (buyerId == null) return;

        final bytes = await pickedFile.readAsBytes();
        final fileExtension = pickedFile.path.split('.').last;
        final fileName = 'buyer_${buyerId}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
        final filePath = 'static/uploads/profiles/$fileName';
        
        // Upload to Images bucket
        await Supabase.instance.client.storage
            .from('Images')
            .uploadBinary(filePath, bytes, fileOptions: const FileOptions(upsert: true));

        if (mounted) {
          setState(() {
            _newProfilePicture = filePath;
          });
          SnackBarHelper.showSuccess(context, 'Image uploaded successfully');
        }
      } catch (e) {
        print('Error uploading image: $e');
        if (mounted) {
          SnackBarHelper.showError(context, 'Failed to upload image: $e');
        }
      }
    }
  }

  Future<void> _saveChanges() async {
    final buyerId = AuthService().currentBuyerId;
    if (buyerId == null) return;

    setState(() => _isSaving = true);

    try {
      await Supabase.instance.client
          .from('buyers')
          .update({
            'first_name': _firstNameController.text.trim(),
            'last_name': _lastNameController.text.trim(),
            'phone_number': _phoneController.text.trim(),
            'gender': _selectedGender,
            'profile_image': _newProfilePicture,
          })
          .eq('buyer_id', buyerId);

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
                  Text(
                    'Profile Information',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                    ),
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
                  onTap: _isEditing ? _pickImage : null,
                  child: Stack(
                    children: [
                      Container(
                        width: 100.w,
                        height: 100.h,
                        decoration: BoxDecoration(
                          color: AppColors.border(context),
                          shape: BoxShape.circle,
                        ),
                        child: _newProfilePicture != null && _newProfilePicture!.isNotEmpty
                            ? ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: ImageHelper.getImageUrl(_newProfilePicture!),
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Icon(Icons.person, size: 50.r, color: AppColors.textMuted(context)),
                                  errorWidget: (context, url, error) => Icon(Icons.person, size: 50.r, color: AppColors.textMuted(context)),
                                ),
                              )
                            : Icon(Icons.person, size: 50.r, color: AppColors.textMuted(context)),
                      ),
                      if (_isEditing)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: EdgeInsets.all(6.w),
                            decoration: BoxDecoration(
                              color: AppColors.onSurface(context),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.camera_alt, size: 16.r, color: AppColors.surface(context)),
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
              _buildInfoField('Email', TextEditingController(text: widget.userEmail ?? 'Not set'), false),
              SizedBox(height: 16.h),
              _buildInfoField('Phone Number', _phoneController, _isEditing),
              SizedBox(height: 16.h),
              _buildGenderField(),
              if (_isEditing) ...[
                SizedBox(height: 24.h),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _isEditing = false;
                            _firstNameController.text = widget.firstName ?? '';
                            _lastNameController.text = widget.lastName ?? '';
                            _phoneController.text = widget.phoneNumber ?? '';
                            _selectedGender = widget.gender;
                            _newProfilePicture = widget.profilePicture;
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
                                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.surface(context)),
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

  Widget _buildInfoField(String label, TextEditingController controller, bool enabled) {
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
            fillColor: enabled ? AppColors.surfaceVariant(context) : AppColors.scaffoldBackground(context),
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
              borderSide: BorderSide(color: AppColors.surfaceVariant2(context)),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender',
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
            color: _isEditing ? AppColors.surfaceVariant(context) : AppColors.scaffoldBackground(context),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: _isEditing
              ? DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedGender,
                    isExpanded: true,
                    isDense: true,
                    hint: Text('Select gender', style: GoogleFonts.goudyBookletter1911(fontSize: 14.sp)),
                    style: GoogleFonts.goudyBookletter1911(fontSize: 14.sp, color: AppColors.onSurface(context)),
                    items: ['Male', 'Female', 'Other'].map((gender) {
                      return DropdownMenuItem(
                        value: gender,
                        child: Text(gender),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedGender = value),
                  ),
                )
              : Text(
                  _selectedGender ?? 'Not set',
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 14.sp,
                    color: _selectedGender != null ? AppColors.onSurface(context) : AppColors.textFaint(context),
                  ),
                ),
        ),
      ],
    );
  }
}
