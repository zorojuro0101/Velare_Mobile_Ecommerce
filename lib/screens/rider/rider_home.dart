import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/rider_service.dart';
import '../../services/rider_chat_service.dart';
import '../../utils/image_helper.dart';
import 'delivery_management_screen.dart';
import 'earnings_screen.dart';
import 'rider_profile_screen.dart';
import 'rider_chat_screen.dart';
import 'rider_report_screen.dart';

class RiderHome extends StatefulWidget {
  const RiderHome({super.key});

  @override
  State<RiderHome> createState() => _RiderHomeState();
}

class _RiderHomeState extends State<RiderHome> {
  final RiderService _riderService = RiderService();
  final RiderChatService _chatService = RiderChatService();
  final _supabase = Supabase.instance.client;

  int _currentIndex = 0;
  int _deliveryManagementInitialTab = 0; // Track which subtab to show

  // Stats data
  int _activeDeliveries = 0;
  int _completedDeliveries = 0;
  int _pendingPickups = 0;
  double _todayEarnings = 0.0;
  bool _isLoadingStats = true;

  // Summary sections data
  List<dynamic> _pendingPickupList = [];
  List<dynamic> _activeDeliveriesList = [];
  List<dynamic> _earningsList = [];
  bool _isLoadingSummary = true;

  // Chat unread count
  int _chatUnreadCount = 0;

  // Rider profile
  String? _riderProfileImage;

  @override
  void initState() {
    super.initState();
    // Wait for the widget to be fully built before loading data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  Future<void> _loadDashboardData() async {
    await Future.wait([
      _loadDashboardStats(),
      _loadSummarySections(),
      _loadChatUnreadCount(),
    ]);
  }

  Future<void> _loadDashboardStats() async {
    setState(() {
      _isLoadingStats = true;
    });

    try {
      final userId = AuthService().currentUserId;
      print('🔍 Loading stats for user: $userId');

      if (userId == null) {
        print('❌ User ID is null');
        if (mounted) {
          setState(() => _isLoadingStats = false);
        }
        return;
      }

      // Get rider_id and profile from riders table
      print('📊 Fetching rider data...');
      final riderData = await _supabase
          .from('riders')
          .select('rider_id, first_name, last_name, profile_image')
          .eq('user_id', userId)
          .maybeSingle();

      if (riderData == null) {
        print('❌ No rider found for user_id: $userId');
        if (mounted) {
          setState(() => _isLoadingStats = false);
        }
        return;
      }

      final riderId = riderData['rider_id'];
      print('✅ Rider ID: $riderId');

      // Store profile data
      if (mounted) {
        setState(() {
          _riderProfileImage = riderData['profile_image'] != null
              ? ImageHelper.getImageUrl(riderData['profile_image'])
              : null;
        });
      }

      // Fetch all stats in parallel
      print('📊 Fetching stats from database...');
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

      print('✅ Stats fetched successfully');

      // Calculate stats
      final activeList = results[0] as List;
      final completedList = results[1] as List;
      final pendingList = results[2] as List;
      final earningsList = results[3] as List;

      print('📈 Active: ${activeList.length}');
      print('📈 Completed: ${completedList.length}');
      print('📈 Pending: ${pendingList.length}');
      print('📈 Earnings records: ${earningsList.length}');

      double totalEarnings = 0.0;
      for (var delivery in earningsList) {
        final earnings = delivery['rider_earnings'];
        if (earnings != null) {
          totalEarnings += (earnings is int) ? earnings.toDouble() : earnings;
        }
      }

      print('💰 Total earnings: ₱$totalEarnings');

      if (mounted) {
        setState(() {
          _activeDeliveries = activeList.length;
          _completedDeliveries = completedList.length;
          _pendingPickups = pendingList.length;
          _todayEarnings = totalEarnings;
          _isLoadingStats = false;
        });
      }

      print('✅ Stats updated successfully');
    } catch (e) {
      print('❌ Error loading dashboard stats: $e');
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  Future<void> _loadSummarySections() async {
    if (mounted) {
      setState(() => _isLoadingSummary = true);
    }

    try {
      final userId = AuthService().currentUserId;
      print('📊 Loading summary sections for user: $userId');

      if (userId == null) {
        print('❌ User ID is null in _loadSummarySections');
        if (mounted) setState(() => _isLoadingSummary = false);
        return;
      }

      print('🔍 Fetching rider data for user_id: $userId');
      final riderData = await _supabase
          .from('riders')
          .select('rider_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (riderData == null) {
        print('❌ No rider found for user_id: $userId');
        if (mounted) setState(() => _isLoadingSummary = false);
        return;
      }

      final riderId = riderData['rider_id'];
      print('✅ Rider ID: $riderId');
      print('📦 Fetching summary data...');

      // Fetch all summary sections in parallel
      final results = await Future.wait([
        // Pending pickups (top 3) - deliveries with status='pending' ready for pickup
        _supabase
            .from('deliveries')
            .select('''
              delivery_id,
              pickup_address,
              delivery_address,
              delivery_fee,
              status,
              rider_id,
              orders!inner(
                order_id,
                order_number,
                buyers(first_name, last_name, phone_number),
                sellers(shop_name, phone_number)
              )
            ''')
            .eq('status', 'pending')
            .isFilter('rider_id', null)
            .order('created_at', ascending: true)
            .limit(3),

        // Active deliveries (top 3)
        _supabase
            .from('deliveries')
            .select('''
              delivery_id,
              delivery_address,
              delivery_fee,
              status,
              orders!inner(
                order_id,
                order_number,
                total_amount,
                buyers(first_name, last_name),
                sellers(shop_name)
              )
            ''')
            .eq('rider_id', riderId)
            .inFilter('status', ['assigned', 'in_transit'])
            .order('assigned_at', ascending: false)
            .limit(3),

        // Recent earnings (top 3)
        _supabase
            .from('deliveries')
            .select('''
              delivery_id,
              rider_earnings,
              delivered_at,
              status,
              orders!inner(
                order_id,
                order_number,
                buyers(first_name, last_name),
                sellers(shop_name, first_name, last_name)
              )
            ''')
            .eq('rider_id', riderId)
            .eq('status', 'delivered')
            .order('delivered_at', ascending: false)
            .limit(3),
      ]);

      print('📊 Query results received');
      print('📦 Pending pickups raw: ${results[0]}');
      print('🚚 Active deliveries raw: ${results[1]}');
      print('💰 Earnings raw: ${results[2]}');

      if (mounted) {
        setState(() {
          _pendingPickupList = results[0] as List;
          _activeDeliveriesList = results[1] as List;
          _earningsList = results[2] as List;
          _isLoadingSummary = false;
        });
      }

      print('📦 Loaded ${_pendingPickupList.length} pending pickups');
      print('🚚 Loaded ${_activeDeliveriesList.length} active deliveries');
      print('💰 Loaded ${_earningsList.length} earnings');
      print('✅ Summary sections loaded successfully');
    } catch (e, stackTrace) {
      print('❌ Error loading summary sections: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _isLoadingSummary = false);
      }
    }
  }

  Future<void> _loadChatUnreadCount() async {
    try {
      final userId = AuthService().currentUserId;
      if (userId == null) return;

      final unreadCount = await _chatService.getRiderUnreadCount(userId);

      if (mounted) {
        setState(() {
          _chatUnreadCount = unreadCount;
        });
      }
    } catch (e) {
      print('❌ Error loading chat unread count: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
        } else {
          final shouldExit = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                'Exit App',
                style: GoogleFonts.goudyBookletter1911(
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                'Do you want to exit the app?',
                style: GoogleFonts.goudyBookletter1911(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.goudyBookletter1911(),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    'Exit',
                    style: GoogleFonts.goudyBookletter1911(color: Colors.red),
                  ),
                ),
              ],
            ),
          );

          if (shouldExit == true && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildHomeScreen(),
            DeliveryManagementScreen(
              initialTab: _deliveryManagementInitialTab,
              hideScaffold: true,
            ),
            RiderChatScreen(onMessagesRead: _loadChatUnreadCount),
            const EarningsScreen(hideScaffold: true),
            const RiderProfileScreen(hideScaffold: true),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildHomeScreen() {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: Colors.black,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildHeader(),
              _buildStatsCards(),
              if (_isLoadingSummary)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: Colors.black),
                )
              else ...[
                _buildPendingPickupSection(),
                _buildActiveDeliveriesSection(),
                _buildEarningsSection(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // Profile Picture
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[300],
                    backgroundImage:
                        _riderProfileImage != null &&
                            _riderProfileImage!.isNotEmpty
                        ? NetworkImage(_riderProfileImage!)
                        : null,
                    child:
                        _riderProfileImage == null ||
                            _riderProfileImage!.isEmpty
                        ? Icon(Icons.person, color: Colors.grey[600], size: 24)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Rider Dashboard',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              // Report User Button
              IconButton(
                icon: const Icon(Icons.flag, color: Colors.red),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RiderReportScreen(),
                    ),
                  );
                },
                tooltip: 'Report User',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    if (_isLoadingStats) {
      return Container(
        padding: const EdgeInsets.all(16),
        height: 200,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.black),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.5,
        children: [
          _buildStatCard(
            'Active Deliveries',
            _activeDeliveries.toString(),
            Icons.local_shipping,
            Colors.blue,
          ),
          _buildStatCard(
            'Completed',
            _completedDeliveries.toString(),
            Icons.check_circle,
            Colors.green,
          ),
          _buildStatCard(
            'Pending Pickups',
            _pendingPickups.toString(),
            Icons.pending_actions,
            Colors.orange,
          ),
          _buildStatCard(
            'Today\'s Earnings',
            '₱${_todayEarnings.toStringAsFixed(2)}',
            Icons.attach_money,
            Colors.black,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          Text(
            value,
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptOrder(dynamic order) async {
    final riderId = AuthService().currentUserId;
    if (riderId == null) {
      print('❌ Rider ID is null');
      return;
    }

    print('📦 Attempting to accept order: ${order['delivery_id']}');
    print('👤 Rider ID: $riderId');

    try {
      await _riderService.acceptOrder(order['delivery_id'], riderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order accepted! Check Active Deliveries',
              style: GoogleFonts.goudyBookletter1911(),
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadDashboardData();
      }
    } catch (e) {
      print('❌ Error in _acceptOrder: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to accept order: ${e.toString()}',
              style: GoogleFonts.goudyBookletter1911(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper method for info rows
  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.goudyBookletter1911(
                fontSize: 13,
                color: Colors.grey[700],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Summary Section Widgets
  Widget _buildPendingPickupSection() {
    return Container(
      margin: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.pending_actions, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Pending Pickup',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _loadSummarySections,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_pendingPickupList.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No pending pickups',
                  style: GoogleFonts.goudyBookletter1911(
                    color: Colors.grey[600],
                  ),
                ),
              ),
            )
          else
            ..._pendingPickupList.map((pickup) => _buildPickupCard(pickup)),
          if (_pendingPickupList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _deliveryManagementInitialTab = 0; // Pending Pickups tab
                    _currentIndex = 1; // Go to Deliveries tab
                  });
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'See More',
                      style: GoogleFonts.goudyBookletter1911(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: Colors.black,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPickupCard(dynamic pickup) {
    final order = pickup['orders'] ?? {};
    final buyer = order['buyers'] ?? {};
    final seller = order['sellers'] ?? {};
    final orderNumber = order['order_number'] ?? pickup['order_id'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order #$orderNumber',
                style: GoogleFonts.playfairDisplay(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  'PENDING',
                  style: GoogleFonts.goudyBookletter1911(
                    color: Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.store, '${seller['shop_name'] ?? 'N/A'}'),
          _buildInfoRow(
            Icons.location_on_outlined,
            pickup['pickup_address'] ?? 'N/A',
          ),
          _buildInfoRow(
            Icons.person_outline,
            '${buyer['first_name'] ?? ''} ${buyer['last_name'] ?? ''}',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  onPressed: () {
                    // TODO: Reject delivery
                  },
                  child: Text(
                    'Reject',
                    style: GoogleFonts.goudyBookletter1911(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  onPressed: () => _acceptOrder(pickup),
                  child: Text(
                    'Accept',
                    style: GoogleFonts.goudyBookletter1911(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveDeliveriesSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_shipping, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Active Deliveries',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _loadSummarySections,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_activeDeliveriesList.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Text(
                      'No active deliveries',
                      style: GoogleFonts.goudyBookletter1911(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Accept orders to start delivering',
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._activeDeliveriesList.map(
              (delivery) => _buildActiveDeliveryCard(delivery),
            ),
          if (_activeDeliveriesList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _deliveryManagementInitialTab = 1; // Active Deliveries tab
                    _currentIndex = 1; // Go to Deliveries tab
                  });
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'See More',
                      style: GoogleFonts.goudyBookletter1911(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: Colors.black,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveDeliveryCard(dynamic delivery) {
    final order = delivery['orders'] ?? {};
    final buyer = order['buyers'] ?? {};
    final seller = order['sellers'] ?? {};
    final orderNumber = order['order_number'] ?? delivery['order_id'];
    final totalAmount = order['total_amount'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order #$orderNumber',
                style: GoogleFonts.playfairDisplay(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  'IN PROGRESS',
                  style: GoogleFonts.goudyBookletter1911(
                    color: Colors.blue,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.store, seller['shop_name'] ?? 'N/A'),
          _buildInfoRow(
            Icons.person_outline,
            '${buyer['first_name'] ?? ''} ${buyer['last_name'] ?? ''}',
          ),
          _buildInfoRow(
            Icons.location_on_outlined,
            delivery['delivery_address'] ?? 'N/A',
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Amount to Collect',
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                '₱${totalAmount.toString()}',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.attach_money, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Recent Earnings',
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _loadSummarySections,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_earningsList.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No earnings data available',
                  style: GoogleFonts.goudyBookletter1911(
                    color: Colors.grey[600],
                  ),
                ),
              ),
            )
          else
            ..._earningsList.map((earning) => _buildEarningCard(earning)),
          if (_earningsList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton(
                onPressed: () {
                  setState(() => _currentIndex = 2);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'See More',
                      style: GoogleFonts.goudyBookletter1911(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: Colors.black,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEarningCard(dynamic earning) {
    final order = earning['orders'] ?? {};
    final buyer = order['buyers'] ?? {};
    final seller = order['sellers'] ?? {};
    final orderNumber = order['order_number'] ?? earning['order_id'];
    final riderEarnings = earning['rider_earnings'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order #$orderNumber',
                style: GoogleFonts.playfairDisplay(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  'DELIVERED',
                  style: GoogleFonts.goudyBookletter1911(
                    color: Colors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.store, seller['shop_name'] ?? 'N/A'),
          _buildInfoRow(
            Icons.person_outline,
            '${buyer['first_name'] ?? ''} ${buyer['last_name'] ?? ''}',
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Earnings',
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                '+ ₱${(riderEarnings is int ? riderEarnings.toDouble() : riderEarnings).toStringAsFixed(2)}',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            // Reset to first subtab when clicking Deliveries tab directly
            if (index == 1) {
              _deliveryManagementInitialTab = 0;
            }
            // Reload chat unread count when switching to chat
            if (index == 2) {
              _loadChatUnreadCount();
            }
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: GoogleFonts.goudyBookletter1911(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.goudyBookletter1911(fontSize: 12),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: 'Deliveries',
          ),
          BottomNavigationBarItem(
            icon: _chatUnreadCount > 0
                ? Badge(
                    label: Text(_chatUnreadCount.toString()),
                    backgroundColor: Colors.orange,
                    child: const Icon(Icons.chat_bubble_outline),
                  )
                : const Icon(Icons.chat_bubble_outline),
            activeIcon: _chatUnreadCount > 0
                ? Badge(
                    label: Text(_chatUnreadCount.toString()),
                    backgroundColor: Colors.orange,
                    child: const Icon(Icons.chat_bubble),
                  )
                : const Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Earnings',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
