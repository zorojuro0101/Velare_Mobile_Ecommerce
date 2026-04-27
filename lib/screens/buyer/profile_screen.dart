import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../services/cart_service.dart';
import '../../services/chat_service.dart';
import '../../services/notification_service.dart';
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Profile', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
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
          const SizedBox(width: 8),
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
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            width: 80,
            height: 80,
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
                        color: Colors.grey[200],
                        child: Icon(Icons.person, size: 40, color: Colors.grey[400]),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: Icon(Icons.person, size: 40, color: Colors.grey[400]),
                      ),
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: Icon(Icons.person, size: 40, color: Colors.grey[400]),
                    ),
            ),
          ),
          const SizedBox(width: 16),
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_userEmail != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _userEmail!,
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Button on the right
          OutlinedButton(
            onPressed: _showProfileModal,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black,
              side: const BorderSide(color: Colors.black, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              minimumSize: const Size(0, 36),
            ),
            child: Text(
              'View Details',
              style: GoogleFonts.goudyBookletter1911(
                fontSize: 11,
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
        const SizedBox(height: 16),
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
        const SizedBox(height: 16),
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
          ],
        ),
        const SizedBox(height: 16),
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
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildMenuGroup({String? title, required List<_MenuItem> items}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                title,
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
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
        color: item.isDestructive ? Colors.red : Colors.black,
      ),
      title: Text(
        item.title,
        style: GoogleFonts.goudyBookletter1911(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: item.isDestructive ? Colors.red : Colors.black,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: item.isDestructive ? Colors.red : Colors.grey[400],
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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
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
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!_isEditing)
                    TextButton(
                      onPressed: () => setState(() => _isEditing = true),
                      child: Text(
                        'Edit',
                        style: GoogleFonts.goudyBookletter1911(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Center(
                child: GestureDetector(
                  onTap: _isEditing ? _pickImage : null,
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          shape: BoxShape.circle,
                        ),
                        child: _newProfilePicture != null && _newProfilePicture!.isNotEmpty
                            ? ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: ImageHelper.getImageUrl(_newProfilePicture!),
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Icon(Icons.person, size: 50, color: Colors.grey[600]),
                                  errorWidget: (context, url, error) => Icon(Icons.person, size: 50, color: Colors.grey[600]),
                                ),
                              )
                            : Icon(Icons.person, size: 50, color: Colors.grey[600]),
                      ),
                      if (_isEditing)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildInfoField('First Name', _firstNameController, _isEditing),
              const SizedBox(height: 16),
              _buildInfoField('Last Name', _lastNameController, _isEditing),
              const SizedBox(height: 16),
              _buildInfoField('Email', TextEditingController(text: widget.userEmail ?? 'Not set'), false),
              const SizedBox(height: 16),
              _buildInfoField('Phone Number', _phoneController, _isEditing),
              const SizedBox(height: 16),
              _buildGenderField(),
              if (_isEditing) ...[
                const SizedBox(height: 24),
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
                            borderRadius: BorderRadius.circular(5),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.goudyBookletter1911(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                'Save',
                                style: GoogleFonts.goudyBookletter1911(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
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
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          readOnly: !enabled,
          style: GoogleFonts.goudyBookletter1911(fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: enabled ? Colors.grey[100] : Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.black),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _isEditing ? Colors.grey[100] : Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: _isEditing
              ? DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedGender,
                    isExpanded: true,
                    isDense: true,
                    hint: Text('Select gender', style: GoogleFonts.goudyBookletter1911(fontSize: 14)),
                    style: GoogleFonts.goudyBookletter1911(fontSize: 14, color: Colors.black),
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
                    fontSize: 14,
                    color: _selectedGender != null ? Colors.black : Colors.grey[500],
                  ),
                ),
        ),
      ],
    );
  }
}
