import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/rider_service.dart';
import '../../utils/snackbar_helper.dart';
import 'delivery_detail_screen.dart';

import '../../utils/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
class DeliveryManagementScreen extends StatefulWidget {
  final int initialTab;
  final bool hideScaffold;

  const DeliveryManagementScreen({
    super.key,
    this.initialTab = 0,
    this.hideScaffold = false,
  });

  @override
  State<DeliveryManagementScreen> createState() =>
      _DeliveryManagementScreenState();
}

class _DeliveryManagementScreenState extends State<DeliveryManagementScreen>
    with SingleTickerProviderStateMixin {
  final RiderService _riderService = RiderService();
  final _supabase = Supabase.instance.client;

  late TabController _tabController;

  List<dynamic> _pendingPickups = [];
  List<dynamic> _activeDeliveries = [];
  bool _isLoadingPending = true;
  bool _isLoadingActive = true;

  // Track which delivery is being processed
  int? _processingDeliveryId;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadPendingPickups(), _loadActiveDeliveries()]);
  }

  Future<void> _loadPendingPickups() async {
    setState(() => _isLoadingPending = true);

    try {
      final userId = AuthService().currentUserId;
      if (userId == null) {
        setState(() => _isLoadingPending = false);
        return;
      }

      // Get pending pickups (deliveries with status='pending', ready for rider to accept)
      final response = await _supabase
          .from('deliveries')
          .select('''
            delivery_id,
            order_id,
            pickup_address,
            delivery_address,
            delivery_fee,
            status,
            orders!inner(
              order_id,
              order_number,
              total_amount,
              buyers(first_name, last_name, phone_number),
              sellers(shop_name, phone_number)
            )
          ''')
          .eq('status', 'pending')
          .isFilter('rider_id', null)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _pendingPickups = response as List<dynamic>;
          _isLoadingPending = false;
        });
      }
    } catch (e) {
      print('Error loading pending pickups: $e');
      if (mounted) {
        setState(() => _isLoadingPending = false);
      }
    }
  }

  Future<void> _loadActiveDeliveries() async {
    setState(() => _isLoadingActive = true);

    try {
      final userId = AuthService().currentUserId;
      if (userId == null) {
        setState(() => _isLoadingActive = false);
        return;
      }

      // Get rider_id from user_id
      final riderData = await _supabase
          .from('riders')
          .select('rider_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (riderData == null) {
        setState(() => _isLoadingActive = false);
        return;
      }

      final riderId = riderData['rider_id'];

      // Get active deliveries (assigned, in_transit, and delivered awaiting confirmation)
      // Split into two queries because Supabase .or() doesn't work well with nested fields

      // Query 1: Get assigned and in_transit deliveries
      final response1 = await _supabase
          .from('deliveries')
          .select('''
            delivery_id,
            order_id,
            pickup_address,
            delivery_address,
            delivery_fee,
            status,
            assigned_at,
            orders!inner(
              order_id,
              order_number,
              total_amount,
              order_received,
              order_status,
              buyers(first_name, last_name),
              sellers(shop_name, first_name, last_name)
            )
          ''')
          .eq('rider_id', riderId)
          .inFilter('status', ['assigned', 'in_transit'])
          .neq('orders.order_status', 'cancelled');

      // Query 2: Get delivered orders awaiting confirmation (order_received = FALSE)
      final response2 = await _supabase
          .from('deliveries')
          .select('''
            delivery_id,
            order_id,
            pickup_address,
            delivery_address,
            delivery_fee,
            status,
            assigned_at,
            orders!inner(
              order_id,
              order_number,
              total_amount,
              order_received,
              order_status,
              buyers(first_name, last_name),
              sellers(shop_name, first_name, last_name)
            )
          ''')
          .eq('rider_id', riderId)
          .eq('status', 'delivered')
          .eq('orders.order_received', false) // ⭐ BOOLEAN false, not 0
          .neq(
            'orders.order_status',
            'cancelled',
          ); // ⭐ Exclude cancelled orders

      // Combine both results
      final List<dynamic> allDeliveries = [
        ...(response1 as List<dynamic>),
        ...(response2 as List<dynamic>),
      ];

      // Sort by assigned_at
      allDeliveries.sort((a, b) {
        final aTime = a['assigned_at'] ?? '';
        final bTime = b['assigned_at'] ?? '';
        return bTime.compareTo(aTime); // Descending order
      });

      if (mounted) {
        setState(() {
          _activeDeliveries = allDeliveries;
          _isLoadingActive = false;
        });
      }
    } catch (e) {
      print('Error loading active deliveries: $e');
      if (mounted) {
        setState(() => _isLoadingActive = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabBar = TabBar(
      controller: _tabController,
      labelColor: AppColors.onSurface(context),
      unselectedLabelColor: Colors.grey,
      indicatorColor: AppColors.onSurface(context),
      labelStyle: GoogleFonts.goudyBookletter1911(
        fontSize: 14.sp,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: GoogleFonts.goudyBookletter1911(fontSize: 14.sp),
      tabs: [
        Tab(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.pending_actions, size: 18.r),
              SizedBox(width: 6.w),
              const Text('Pending Pickups'),
              if (_pendingPickups.isNotEmpty) ...[
                SizedBox(width: 6.w),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 6.w,
                    vertical: 2.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(5.r),
                  ),
                  child: Text(
                    '${_pendingPickups.length}',
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 11.sp,
                      color: AppColors.surface(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Tab(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.local_shipping, size: 18.r),
              SizedBox(width: 6.w),
              const Text('Active'),
              if (_activeDeliveries.isNotEmpty) ...[
                SizedBox(width: 6.w),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 6.w,
                    vertical: 2.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(5.r),
                  ),
                  child: Text(
                    '${_activeDeliveries.length}',
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 11.sp,
                      color: AppColors.surface(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    final body = TabBarView(
      controller: _tabController,
      children: [_buildPendingPickupsTab(), _buildActiveDeliveriesTab()],
    );

    if (widget.hideScaffold) {
      return SafeArea(
        child: Column(
          children: [
            Container(
              color: AppColors.surface(context),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Delivery Management',
                          style: GoogleFonts.playfairDisplay(
                            color: AppColors.onSurface(context),
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.refresh, color: AppColors.onSurface(context)),
                          onPressed: _loadData,
                        ),
                      ],
                    ),
                  ),
                  tabBar,
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.surface(context),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Delivery Management',
          style: GoogleFonts.goudyBookletter1911(
            color: AppColors.onSurface(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.onSurface(context)),
            onPressed: _loadData,
          ),
        ],
        bottom: tabBar,
      ),
      body: body,
    );
  }

  Widget _buildPendingPickupsTab() {
    if (_isLoadingPending) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.onSurface(context)),
      );
    }

    if (_pendingPickups.isEmpty) {
      return _buildEmptyState(
        Icons.pending_actions,
        'No pending pickups',
        'New delivery requests will appear here',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPendingPickups,
      color: AppColors.onSurface(context),
      child: ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: _pendingPickups.length,
        itemBuilder: (context, index) {
          return _buildPendingPickupCard(_pendingPickups[index]);
        },
      ),
    );
  }

  Widget _buildActiveDeliveriesTab() {
    if (_isLoadingActive) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.onSurface(context)),
      );
    }

    if (_activeDeliveries.isEmpty) {
      return _buildEmptyState(
        Icons.local_shipping_outlined,
        'No active deliveries',
        'Accept orders to start delivering',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadActiveDeliveries,
      color: AppColors.onSurface(context),
      child: ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: _activeDeliveries.length,
        itemBuilder: (context, index) {
          return _buildActiveDeliveryCard(_activeDeliveries[index]);
        },
      ),
    );
  }

  Widget _buildPendingPickupCard(dynamic pickup) {
    final order = pickup['orders'] ?? {};
    final buyer = order['buyers'] ?? {};
    final seller = order['sellers'] ?? {};
    final orderNumber = order['order_number'] ?? pickup['order_id'];
    final totalAmount = order['total_amount'] ?? 0;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
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
      child: Padding(
        padding: EdgeInsets.all(16.w),
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
                    fontSize: 16.sp,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(5.r),
                  ),
                  child: Text(
                    'PENDING',
                    style: GoogleFonts.goudyBookletter1911(
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
              Icons.store_outlined,
              'Store: ${seller['shop_name'] ?? 'N/A'}',
            ),
            if (seller['phone_number'] != null)
              _buildInfoRow(
                Icons.phone_outlined,
                'Seller Phone: ${seller['phone_number']}',
              ),
            _buildInfoRow(
              Icons.location_on_outlined,
              'Pickup: ${pickup['pickup_address'] ?? 'N/A'}',
            ),
            const Divider(height: 16),
            _buildInfoRow(
              Icons.person_outline,
              'Customer: ${buyer['first_name'] ?? ''} ${buyer['last_name'] ?? ''}',
            ),
            _buildInfoRow(
              Icons.location_on_outlined,
              'Deliver to: ${pickup['delivery_address'] ?? 'N/A'}',
            ),
            _buildInfoRow(
              Icons.attach_money,
              'Delivery Fee: ₱${pickup['delivery_fee'] ?? 0}',
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Amount',
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 12.sp,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                    Text(
                      '₱${totalAmount.toString()}',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5.r),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 12.h,
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
                    SizedBox(width: 8.w),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.onSurface(context),
                        foregroundColor: AppColors.surface(context),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5.r),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 12.h,
                        ),
                      ),
                      onPressed: () => _acceptOrder(pickup),
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
          ],
        ),
      ),
    );
  }

  Widget _buildActiveDeliveryCard(dynamic delivery) {
    final status = delivery['status'] ?? 'assigned';
    final order = delivery['orders'] ?? {};
    final orderReceived = order['order_received'] ?? false; // Boolean

    final isAssigned = status == 'assigned';
    final isInTransit = status == 'in_transit';
    final isDelivered =
        status == 'delivered' &&
        orderReceived == false; // Awaiting confirmation

    // Determine status color and text
    Color statusColor;
    String statusText;
    if (isAssigned) {
      statusColor = Colors.blue;
      statusText = 'ASSIGNED';
    } else if (isInTransit) {
      statusColor = Colors.purple;
      statusText = 'IN TRANSIT';
    } else if (isDelivered) {
      statusColor = const Color(0xFF6C757D); // Gray
      statusText = 'AWAITING CONFIRMATION';
    } else {
      statusColor = Colors.grey;
      statusText = status.toUpperCase();
    }

    final buyer = order['buyers'] ?? {};
    final seller = order['sellers'] ?? {};
    final orderNumber = order['order_number'] ?? delivery['order_id'];
    final totalAmount = order['total_amount'] ?? 0;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(5.r),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DeliveryDetailScreen(order: delivery),
              ),
            ).then((_) => _loadActiveDeliveries());
          },
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Order #$orderNumber',
                        style: GoogleFonts.playfairDisplay(
                          fontWeight: FontWeight.w600,
                          fontSize: 16.sp,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Flexible(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(5.r),
                        ),
                        child: Text(
                          statusText,
                          style: GoogleFonts.goudyBookletter1911(
                            color: AppColors.surface(context),
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                _buildInfoRow(
                  Icons.store_outlined,
                  'From: ${seller['shop_name'] ?? 'N/A'}',
                ),
                _buildInfoRow(
                  Icons.location_on_outlined,
                  'Deliver to: ${delivery['delivery_address'] ?? 'N/A'}',
                ),
                _buildInfoRow(
                  Icons.person_outline,
                  'Customer: ${buyer['first_name'] ?? ''} ${buyer['last_name'] ?? ''}',
                ),
                _buildInfoRow(
                  Icons.attach_money,
                  'Delivery Fee: ₱${delivery['delivery_fee'] ?? 0}',
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Amount',
                          style: GoogleFonts.goudyBookletter1911(
                            fontSize: 12.sp,
                            color: AppColors.textMuted(context),
                          ),
                        ),
                        Text(
                          '₱${totalAmount.toString()}',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    if (isAssigned)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _isProcessing &&
                                  _processingDeliveryId ==
                                      delivery['delivery_id']
                              ? Colors.grey
                              : Colors.blue,
                          foregroundColor: AppColors.surface(context),
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 12.h,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        onPressed:
                            _isProcessing &&
                                _processingDeliveryId == delivery['delivery_id']
                            ? null
                            : () => _pickupOrder(delivery),
                        icon:
                            _isProcessing &&
                                _processingDeliveryId == delivery['delivery_id']
                            ? SizedBox(
                                width: 18.w,
                                height: 18.h,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.surface(context),
                                  ),
                                ),
                              )
                            : Icon(Icons.shopping_bag, size: 18.r),
                        label: Text(
                          _isProcessing &&
                                  _processingDeliveryId ==
                                      delivery['delivery_id']
                              ? 'Processing...'
                              : 'Mark as Picked Up',
                          style: GoogleFonts.goudyBookletter1911(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.sp,
                          ),
                        ),
                      )
                    else if (isInTransit)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _isProcessing &&
                                  _processingDeliveryId ==
                                      delivery['delivery_id']
                              ? Colors.grey
                              : Colors.green,
                          foregroundColor: AppColors.surface(context),
                          padding: EdgeInsets.symmetric(
                            horizontal: 20.w,
                            vertical: 12.h,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        onPressed:
                            _isProcessing &&
                                _processingDeliveryId == delivery['delivery_id']
                            ? null
                            : () => _markAsDelivered(delivery),
                        icon:
                            _isProcessing &&
                                _processingDeliveryId == delivery['delivery_id']
                            ? SizedBox(
                                width: 20.w,
                                height: 20.h,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.surface(context),
                                  ),
                                ),
                              )
                            : Icon(Icons.check_circle_outline, size: 20.r),
                        label: Text(
                          _isProcessing &&
                                  _processingDeliveryId ==
                                      delivery['delivery_id']
                              ? 'Processing...'
                              : 'Item Delivered',
                          style: GoogleFonts.goudyBookletter1911(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else if (isDelivered)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF8F9FA),
                          foregroundColor: const Color(0xFF6C757D),
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 12.h,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          elevation: 0,
                        ),
                        onPressed: null, // Disabled
                        icon: Icon(Icons.hourglass_empty, size: 18.r),
                        label: Text(
                          'Awaiting Confirmation',
                          style: GoogleFonts.goudyBookletter1911(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.sp,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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

  Future<void> _acceptOrder(dynamic order) async {
    final userId = AuthService().currentUserId;
    if (userId == null) {
      print('❌ User ID is null');
      return;
    }

    print('📦 Attempting to accept order: ${order['delivery_id']}');
    print('👤 User ID: $userId');

    try {
      await _riderService.acceptOrder(order['delivery_id'], userId);
      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Delivery accepted successfully!');
        _loadData();
        // Switch to Active tab
        _tabController.animateTo(1);
      }
    } catch (e) {
      print('❌ Error in _acceptOrder: $e');
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to accept delivery');
      }
    }
  }

  Future<void> _pickupOrder(dynamic delivery) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Confirm Pickup',
          style: GoogleFonts.goudyBookletter1911(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Have you picked up the item from the seller?',
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: AppColors.surface(context),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Confirm',
              style: GoogleFonts.goudyBookletter1911(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _processingDeliveryId = delivery['delivery_id'];
        _isProcessing = true;
      });

      try {
        final deliveryId = delivery['delivery_id'];
        final orderId = delivery['orders']?['order_id'] ?? delivery['order_id'];

        await _riderService.pickupOrder(deliveryId, orderId);

        if (mounted) {
          setState(() {
            _processingDeliveryId = null;
            _isProcessing = false;
          });

          SnackBarHelper.showSuccess(context, 'Item marked as picked up!');
          _loadActiveDeliveries();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _processingDeliveryId = null;
            _isProcessing = false;
          });

          SnackBarHelper.showError(context, 'Failed to mark as picked up');
        }
      }
    }
  }

  Future<void> _markAsDelivered(dynamic delivery) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Confirm Delivery',
          style: GoogleFonts.goudyBookletter1911(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Mark this order as delivered?',
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: AppColors.surface(context),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Confirm',
              style: GoogleFonts.goudyBookletter1911(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _processingDeliveryId = delivery['delivery_id'];
        _isProcessing = true;
      });

      try {
        final userId = AuthService().currentUserId;
        if (userId == null) {
          setState(() {
            _processingDeliveryId = null;
            _isProcessing = false;
          });
          return;
        }

        final deliveryId = delivery['delivery_id'];
        await _riderService.updateOrderStatus(deliveryId, 'delivered', userId);

        if (mounted) {
          setState(() {
            _processingDeliveryId = null;
            _isProcessing = false;
          });

          SnackBarHelper.showSuccess(context, 'Waiting for buyer confirmation');
          // Reload to remove from Active Deliveries (order is now delivered)
          _loadActiveDeliveries();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _processingDeliveryId = null;
            _isProcessing = false;
          });

          SnackBarHelper.showError(context, 'Failed to mark as delivered');
        }
      }
    }
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80.r, color: AppColors.textFaint(context)),
          SizedBox(height: 16.h),
          Text(
            title,
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 18.sp,
              color: AppColors.textMuted(context),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            subtitle,
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 14.sp,
              color: AppColors.textFaint(context),
            ),
          ),
        ],
      ),
    );
  }
}
