import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/rider_service.dart';
import '../auth/login_screen.dart';

import '../../utils/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
class RiderDashboard extends StatefulWidget {
  const RiderDashboard({super.key});

  @override
  State<RiderDashboard> createState() => _RiderDashboardState();
}

class _RiderDashboardState extends State<RiderDashboard> {
  final RiderService _riderService = RiderService();
  final _supabase = Supabase.instance.client;

  late Future<List<dynamic>> _ordersFuture;

  // Stats data
  int _activeDeliveries = 0;
  int _completedDeliveries = 0;
  int _pendingPickups = 0;
  double _todayEarnings = 0.0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    await Future.wait([_loadDashboardStats(), _refreshOrders()]);
  }

  Future<void> _loadDashboardStats() async {
    setState(() {
      _isLoadingStats = true;
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Get rider_id from riders table
      final riderData = await _supabase
          .from('riders')
          .select('rider_id')
          .eq('user_id', userId)
          .single();

      final riderId = riderData['rider_id'];

      // Fetch all stats in parallel
      final results = await Future.wait([
        // Active deliveries count
        _supabase
            .from('deliveries')
            .select('delivery_id')
            .eq('rider_id', riderId)
            .inFilter('status', ['assigned', 'in_transit']),

        // Completed deliveries count
        _supabase
            .from('deliveries')
            .select('delivery_id')
            .eq('rider_id', riderId)
            .eq('status', 'delivered'),

        // Pending pickups count
        _supabase
            .from('deliveries')
            .select('delivery_id')
            .isFilter('rider_id', null)
            .eq('status', 'pending'),

        // Today's earnings
        _supabase
            .from('deliveries')
            .select('rider_earnings')
            .eq('rider_id', riderId)
            .eq('status', 'delivered')
            .gte(
              'delivered_at',
              DateTime.now().toIso8601String().split('T')[0],
            ),
      ]);

      // Calculate stats
      final activeList = results[0] as List;
      final completedList = results[1] as List;
      final pendingList = results[2] as List;
      final earningsList = results[3] as List;

      double totalEarnings = 0.0;
      for (var delivery in earningsList) {
        final earnings = delivery['rider_earnings'];
        if (earnings != null) {
          totalEarnings += (earnings is int) ? earnings.toDouble() : earnings;
        }
      }

      setState(() {
        _activeDeliveries = activeList.length;
        _completedDeliveries = completedList.length;
        _pendingPickups = pendingList.length;
        _todayEarnings = totalEarnings;
        _isLoadingStats = false;
      });
    } catch (e) {
      print('Error loading dashboard stats: $e');
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  Future<void> _refreshOrders() async {
    setState(() {
      _ordersFuture = _riderService.getAvailableOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceVariant(context),
      appBar: AppBar(
        backgroundColor: AppColors.onSurface(context),
        elevation: 0,
        title: Text(
          'Rider Console',
          style: GoogleFonts.goudyBookletter1911(
            color: AppColors.surface(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.person_outline, color: AppColors.surface(context)),
            onPressed: _showLogoutDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: AppColors.onSurface(context),
        child: Column(
          children: [
            _buildStatsCards(),
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: _ordersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(color: AppColors.onSurface(context)),
                    );
                  }
                  if (snapshot.hasError) {
                    return _buildErrorState();
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildEmptyState();
                  }
                  return _buildOrderList(snapshot.data!);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    if (_isLoadingStats) {
      return Container(
        margin: EdgeInsets.all(16.w),
        height: 200.h,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.onSurface(context)),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.all(16.w),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.5,
        children: [
          _buildStatCard(
            title: 'Active Deliveries',
            value: _activeDeliveries.toString(),
            icon: Icons.local_shipping,
            color: Colors.blue,
          ),
          _buildStatCard(
            title: 'Completed',
            value: _completedDeliveries.toString(),
            icon: Icons.check_circle,
            color: Colors.green,
          ),
          _buildStatCard(
            title: 'Pending Pickups',
            value: _pendingPickups.toString(),
            icon: Icons.pending_actions,
            color: Colors.orange,
          ),
          _buildStatCard(
            title: 'Today\'s Earnings',
            value: '₱${_todayEarnings.toStringAsFixed(2)}',
            icon: Icons.attach_money,
            color: AppColors.onSurface(context),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 12.sp,
                    color: AppColors.textBody(context),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(icon, color: color, size: 20.r),
              ),
            ],
          ),
          Text(
            value,
            style: GoogleFonts.playfairDisplay(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface(context),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(List<dynamic> orders) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return Container(
          margin: EdgeInsets.only(bottom: 12.h),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order #${order['order_id']}',
                      style: GoogleFonts.playfairDisplay(
                        fontWeight: FontWeight.w600,
                        fontSize: 16.sp,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.onSurface(context),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        (order['status'] ?? '').toString().toUpperCase(),
                        style: GoogleFonts.playfairDisplay(
                          color: AppColors.surface(context),
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                _buildInfoRow(
                  Icons.person_outline,
                  order['recipient'] ?? 'N/A',
                ),
                _buildInfoRow(Icons.phone_outlined, order['phone'] ?? 'N/A'),
                _buildInfoRow(
                  Icons.location_on_outlined,
                  order['address'] ?? 'N/A',
                ),
                SizedBox(height: 12.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₱${order['total_amount'] ?? 0}',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.onSurface(context),
                        foregroundColor: AppColors.surface(context),
                        padding: EdgeInsets.symmetric(
                          horizontal: 24.w,
                          vertical: 12.h,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Order #${order['order_id']} accepted!',
                              style: GoogleFonts.goudyBookletter1911(),
                            ),
                            backgroundColor: AppColors.onSurface(context),
                          ),
                        );
                      },
                      child: Text(
                        'Accept',
                        style: GoogleFonts.goudyBookletter1911(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          Icon(icon, size: 18.r, color: AppColors.textBody(context)),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.goudyBookletter1911(
                fontSize: 14.sp,
                color: AppColors.textBodyStrong(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 80.r, color: AppColors.textFaint(context)),
          SizedBox(height: 16.h),
          Text(
            'No orders available',
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 18.sp,
              color: AppColors.textMuted(context),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Pull down to refresh',
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 14.sp,
              color: AppColors.textFaint(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80.r, color: AppColors.textFaint(context)),
          SizedBox(height: 16.h),
          Text(
            'Connection Error',
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 18.sp,
              color: AppColors.textMuted(context),
            ),
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.onSurface(context),
              foregroundColor: AppColors.surface(context),
              padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h),
            ),
            onPressed: _refreshOrders,
            child: Text(
              'Retry',
              style: GoogleFonts.goudyBookletter1911(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
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
          TextButton(
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
                color: AppColors.onSurface(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
