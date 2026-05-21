import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/rider_service.dart';
import '../../services/auth_service.dart';

import '../../utils/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
class DeliveryDetailScreen extends StatefulWidget {
  final dynamic order;

  const DeliveryDetailScreen({super.key, required this.order});

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen> {
  final RiderService _riderService = RiderService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.surface(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.onSurface(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Delivery Details',
          style: GoogleFonts.goudyBookletter1911(
            color: AppColors.onSurface(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderInfo(),
            _buildCustomerInfo(),
            _buildDeliveryAddress(),
            _buildPaymentInfo(),
          ],
        ),
      ),
      bottomNavigationBar: _buildActionButtons(),
    );
  }

  Widget _buildOrderInfo() {
    final status = widget.order['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
    final orderData = widget.order['orders'] ?? {};
    final orderNumber = orderData['order_number'] ?? widget.order['order_id'];

    return Container(
      margin: EdgeInsets.all(16.w),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order #$orderNumber',
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 12.w,
                  vertical: 6.h,
                ),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  status.toUpperCase().replaceAll('_', ' '),
                  style: GoogleFonts.goudyBookletter1911(
                    color: AppColors.surface(context),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            'Delivery ID: ${widget.order['delivery_id']}',
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 14.sp,
              color: AppColors.textMuted(context),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Created: ${_formatDate(widget.order['created_at'])}',
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 14.sp,
              color: AppColors.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfo() {
    final orderData = widget.order['orders'] ?? {};
    final buyerId = orderData['buyer_id'] ?? 'N/A';

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Information',
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16.h),
          _buildInfoRow(Icons.person, 'Buyer ID', buyerId.toString()),
          SizedBox(height: 12.h),
          _buildInfoRow(
            Icons.shopping_bag,
            'Order Number',
            orderData['order_number'] ?? 'N/A',
          ),
          SizedBox(height: 12.h),
          _buildInfoRow(
            Icons.info_outline,
            'Order Status',
            orderData['order_status'] ?? 'N/A',
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryAddress() {
    final pickupAddress = widget.order['pickup_address'] ?? 'N/A';
    final deliveryAddress = widget.order['delivery_address'] ?? 'N/A';

    return Container(
      margin: EdgeInsets.all(16.w),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pickup Location',
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.store, color: Colors.blue[400], size: 24.r),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  pickupAddress,
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 14.sp,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Delivery Address',
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton.icon(
                onPressed: () => _openMaps(deliveryAddress),
                icon: Icon(Icons.navigation, size: 18.r),
                label: Text(
                  'Navigate',
                  style: GoogleFonts.goudyBookletter1911(fontSize: 13.sp),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on, color: Colors.red[400], size: 24.r),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  deliveryAddress,
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 14.sp,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInfo() {
    final orderData = widget.order['orders'] ?? {};
    final totalAmount = orderData['total_amount'] ?? 0;
    final deliveryFee = widget.order['delivery_fee'] ?? 0;
    final riderEarnings = widget.order['rider_earnings'] ?? 0;

    return Container(
      margin: EdgeInsets.all(16.w),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Information',
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order Total',
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 14.sp,
                  color: AppColors.textMuted(context),
                ),
              ),
              Text(
                '₱$totalAmount',
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Delivery Fee',
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 14.sp,
                  color: AppColors.textMuted(context),
                ),
              ),
              Text(
                '₱$deliveryFee',
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Earnings',
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[700],
                ),
              ),
              Text(
                '₱$riderEarnings',
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment Method',
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 14.sp,
                  color: AppColors.textMuted(context),
                ),
              ),
              Text(
                'Cash on Delivery',
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20.r, color: AppColors.textBody(context)),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 12.sp,
                  color: AppColors.textMuted(context),
                ),
              ),
              Text(
                value,
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final status = widget.order['status'] ?? 'pending';

    if (status == 'delivered' || status == 'cancelled') {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (status == 'assigned') ...[
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: AppColors.surface(context),
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  onPressed: _pickupItem,
                  icon: const Icon(Icons.shopping_bag),
                  label: Text(
                    'Pickup from Seller',
                    style: GoogleFonts.goudyBookletter1911(
                      fontWeight: FontWeight.w600,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
              ),
            ] else if (status == 'in_transit') ...[
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: AppColors.surface(context),
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  onPressed: _markAsDelivered,
                  icon: const Icon(Icons.check_circle),
                  label: Text(
                    'Mark as Delivered',
                    style: GoogleFonts.goudyBookletter1911(
                      fontWeight: FontWeight.w600,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickupItem() async {
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
        final deliveryId = widget.order['delivery_id'];
        final orderId =
            widget.order['orders']?['order_id'] ?? widget.order['order_id'];

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
          Navigator.pop(context);
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

  Future<void> _markAsDelivered() async {
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
        // Get rider ID from auth service
        final riderId = AuthService().currentUserId;
        if (riderId == null) {
          throw Exception('Rider ID not found');
        }

        await _riderService.updateOrderStatus(
          widget.order['delivery_id'],
          'delivered',
          riderId,
        );
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
          Navigator.pop(context);
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

  Future<void> _openMaps(String? address) async {
    if (address == null || address.isEmpty || address == 'N/A') return;
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'in_transit':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(date.toString());
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }
}
