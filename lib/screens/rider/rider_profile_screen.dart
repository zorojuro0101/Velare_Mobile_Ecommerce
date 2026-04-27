import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../utils/snackbar_helper.dart';
import '../auth/login_screen.dart';
import 'verification_documents_screen.dart';

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
        ? const Center(child: CircularProgressIndicator(color: Colors.black))
        : RefreshIndicator(
            onRefresh: _loadRiderProfile,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  _buildProfileHeader(),
                  const SizedBox(height: 16),
                  _buildStatsSection(),
                  const SizedBox(height: 16),
                  _buildMenuSection(),
                ],
              ),
            ),
          );

    if (widget.hideScaffold) {
      return SafeArea(child: content);
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Profile',
          style: GoogleFonts.goudyBookletter1911(
            color: Colors.black,
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

    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[300],
                ),
                child: profileImage != null
                    ? ClipOval(
                        child: Image.network(
                          profileImage,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Text(
                                initial,
                                style: GoogleFonts.goudyBookletter1911(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[600],
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
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () {
                    // TODO: Implement image picker
                    SnackBarHelper.showInfo(
                      context,
                      'Image upload coming soon!',
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            firstName.isNotEmpty && lastName.isNotEmpty
                ? '$firstName $lastName'
                : email,
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified, color: Colors.green, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Verified Rider',
                  style: GoogleFonts.goudyBookletter1911(
                    color: Colors.green,
                    fontSize: 12,
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
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
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
          Container(width: 1, height: 50, color: Colors.grey[300]),
          _buildStatItem('Rating', rating.toStringAsFixed(1), Icons.star),
          Container(width: 1, height: 50, color: Colors.grey[300]),
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
        Icon(icon, color: Colors.black, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.goudyBookletter1911(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.goudyBookletter1911(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
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
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDestructive
                      ? Colors.red.withValues(alpha: 0.1)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(
                  icon,
                  color: isDestructive ? Colors.red : Colors.black,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isDestructive ? Colors.red : Colors.black,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: Colors.grey[200]),
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
              foregroundColor: Colors.white,
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
                    borderRadius: BorderRadius.circular(5),
                  ),
                  labelStyle: GoogleFonts.goudyBookletter1911(),
                ),
                style: GoogleFonts.goudyBookletter1911(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: lastNameController,
                decoration: InputDecoration(
                  labelText: 'Last Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  labelStyle: GoogleFonts.goudyBookletter1911(),
                ),
                style: GoogleFonts.goudyBookletter1911(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 11,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '09XXXXXXXXX',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
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
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
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
                      borderRadius: BorderRadius.circular(5),
                    ),
                    labelStyle: GoogleFonts.goudyBookletter1911(),
                  ),
                  style: GoogleFonts.goudyBookletter1911(color: Colors.black),
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
                const SizedBox(height: 16),
                TextField(
                  controller: plateNumberController,
                  decoration: InputDecoration(
                    labelText: 'Plate Number',
                    hintText: 'ABC 1234',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
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
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
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
}
