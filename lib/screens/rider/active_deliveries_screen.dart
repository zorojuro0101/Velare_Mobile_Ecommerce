import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../services/rider_service.dart';
import 'delivery_detail_screen.dart';

import '../../utils/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
class ActiveDeliveriesScreen extends StatefulWidget {
  const ActiveDeliveriesScreen({super.key});

  @override
  State<ActiveDeliveriesScreen> createState() => _ActiveDeliveriesScreenState();
}

class _ActiveDeliveriesScreenState extends State<ActiveDeliveriesScreen> {
  final RiderService _riderService = RiderService();
  late Future<List<dynamic>> _deliveriesFuture;

  @override
  void initState() {
    super.initState();
    _loadDeliveries();
  }

  void _loadDeliveries() {
    final riderId = AuthService().currentUserId;
    if (riderId != null) {
      setState(() {
        _deliveriesFuture = _riderService.getMyOrders(riderId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.surface(context),
        elevation: 0,
        title: Text(
          'Active Deliveries',
          style: GoogleFonts.goudyBookletter1911(
            color: AppColors.onSurface(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.onSurface(context)),
            onPressed: _loadDeliveries,
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _deliveriesFuture,
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

          final activeDeliveries = snapshot.data!;

          if (activeDeliveries.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: activeDeliveries.length,
            itemBuilder: (context, index) {
              return _buildDeliveryCard(activeDeliveries[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildDeliveryCard(dynamic delivery) {
    final status = delivery['status'] ?? 'assigned';
    final isAssigned = status == 'assigned';
    final statusColor = isAssigned ? Colors.blue : Colors.purple;
    final statusText = isAssigned ? 'ASSIGNED' : 'IN TRANSIT';

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
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
            ).then((_) => _loadDeliveries());
          },
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order #${delivery['orders']?['order_number'] ?? delivery['order_id']}',
                      style: GoogleFonts.goudyBookletter1911(
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
                        color: statusColor,
                        borderRadius: BorderRadius.circular(5.r),
                      ),
                      child: Text(
                        statusText,
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
                  'Pickup: ${delivery['pickup_address'] ?? 'N/A'}',
                ),
                _buildInfoRow(
                  Icons.location_on_outlined,
                  'Deliver: ${delivery['delivery_address'] ?? 'N/A'}',
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
                          '₱${delivery['orders']?['total_amount'] ?? 0}',
                          style: GoogleFonts.goudyBookletter1911(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (isAssigned)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: AppColors.surface(context),
                          padding: EdgeInsets.symmetric(
                            horizontal: 20.w,
                            vertical: 12.h,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5.r),
                          ),
                        ),
                        onPressed: () => _pickupOrder(delivery),
                        icon: Icon(Icons.shopping_bag, size: 20.r),
                        label: Text(
                          'Pickup',
                          style: GoogleFonts.goudyBookletter1911(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: AppColors.surface(context),
                          padding: EdgeInsets.symmetric(
                            horizontal: 20.w,
                            vertical: 12.h,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5.r),
                          ),
                        ),
                        onPressed: () => _markAsDelivered(delivery),
                        icon: Icon(Icons.check_circle, size: 20.r),
                        label: Text(
                          'Complete',
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
      try {
        final deliveryId = delivery['delivery_id'];
        final orderId = delivery['orders']?['order_id'] ?? delivery['order_id'];

        await _riderService.pickupOrder(deliveryId, orderId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Item picked up! Now delivering to customer.',
                style: GoogleFonts.goudyBookletter1911(),
              ),
              backgroundColor: Colors.blue,
            ),
          );
          _loadDeliveries();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to update pickup status',
                style: GoogleFonts.goudyBookletter1911(),
              ),
              backgroundColor: Colors.red,
            ),
          );
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
      try {
        final riderId = AuthService().currentUserId;
        if (riderId == null) return;

        final deliveryId = delivery['delivery_id'];
        await _riderService.updateOrderStatus(deliveryId, 'delivered', riderId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Order marked as delivered!',
                style: GoogleFonts.goudyBookletter1911(),
              ),
              backgroundColor: Colors.green,
            ),
          );
          _loadDeliveries();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to update order',
                style: GoogleFonts.goudyBookletter1911(),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 80.r,
            color: AppColors.textFaint(context),
          ),
          SizedBox(height: 16.h),
          Text(
            'No active deliveries',
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 18.sp,
              color: AppColors.textMuted(context),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Accept orders to start delivering',
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
            onPressed: _loadDeliveries,
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
}
