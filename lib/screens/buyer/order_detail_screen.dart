import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../utils/image_helper.dart';
import '../../utils/snackbar_helper.dart';
import 'product_detail_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final OrderService _orderService = OrderService();
  late Future<Order> _orderFuture;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  void _loadOrder() {
    setState(() {
      _orderFuture = _orderService.getOrderDetails(widget.orderId);
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFFFD700); // Bright Gold
      case 'preparing':
        return const Color(0xFFDAA520); // Goldenrod
      case 'assigned':
        return const Color(0xFFCD853F); // Peru (darker gold-brown)
      case 'picked_up':
        return const Color(0xFF8B4513); // Saddle Brown
      case 'in_transit':
        return const Color(0xFF8B4513); // Saddle Brown
      case 'delivered':
        return const Color(0xFF28A745); // Green
      case 'cancelled':
        return const Color(0xFFDC3545); // Red
      default:
        return Colors.grey;
    }
  }

  Future<void> _cancelOrder(Order order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Order', style: GoogleFonts.goudyBookletter1911(fontWeight: FontWeight.w600)),
        content: Text(
          'Are you sure you want to cancel this order?',
          style: GoogleFonts.goudyBookletter1911(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No', style: GoogleFonts.goudyBookletter1911(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Yes, Cancel', style: GoogleFonts.goudyBookletter1911(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _orderService.cancelOrder(order.id);
        _loadOrder();
        if (mounted) {
          SnackBarHelper.showSuccess(context, 'Order cancelled');
        }
      } catch (e) {
        if (mounted) {
          SnackBarHelper.showError(context, 'Error: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Order Details', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: FutureBuilder<Order>(
        future: _orderFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.black));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}', style: GoogleFonts.goudyBookletter1911()),
            );
          }
          if (!snapshot.hasData) {
            return Center(
              child: Text('Order not found', style: GoogleFonts.goudyBookletter1911()),
            );
          }

          final order = snapshot.data!;
          return SingleChildScrollView(
            child: Column(
              children: [
                _buildOrderStatus(order),
                if (order.riderName != null) _buildRiderInfo(order),
                _buildDeliveryInfo(order),
                _buildOrderItems(order),
                _buildPriceSummary(order),
                if (order.orderStatus == 'pending') _buildCancelButton(order),
                // Show Order Received button when delivery status is delivered but order not yet confirmed
                if (order.deliveryStatus == 'delivered' && 
                    order.orderStatus == 'in_transit' && 
                    !order.orderReceived) 
                  _buildOrderReceivedButton(order),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderStatus(Order order) {
    final isCancelled = order.orderStatus == 'cancelled';
    final isDelivered = order.orderStatus == 'delivered'; // Only true when buyer confirms
    final isDeliveredByRider = order.deliveryStatus == 'delivered' && order.orderStatus == 'in_transit';
    
    // Debug logging
    print('=== ORDER STATUS DEBUG ===');
    print('Order ID: ${order.id}');
    print('Order Number: ${order.orderNumber}');
    print('order.orderStatus: ${order.orderStatus}');
    print('order.deliveryStatus: ${order.deliveryStatus}');
    print('order.orderReceived: ${order.orderReceived}');
    print('isCancelled: $isCancelled');
    print('isDelivered: $isDelivered');
    print('isDeliveredByRider: $isDeliveredByRider');
    print('Should show Order Received button: ${order.deliveryStatus == 'delivered' && order.orderStatus == 'in_transit' && !order.orderReceived}');
    print('========================');
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            order.orderNumber,
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Placed order at: ${_formatDate(order.createdAt)}',
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          if (isCancelled)
            // Show cancelled status instead of progress bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFDC3545).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.cancel,
                    color: Color(0xFFDC3545),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Order Cancelled',
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFDC3545),
                    ),
                  ),
                ],
              ),
            )
          else if (isDelivered)
            // Show delivered status when buyer confirmed
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF28A745).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF28A745),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Order Delivered',
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF28A745),
                    ),
                  ),
                ],
              ),
            )
          else if (isDeliveredByRider)
            // Show waiting for confirmation when rider delivered but buyer hasn't confirmed
            Column(
              children: [
                _buildStatusTimeline(order.deliveryStatus),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Color(0xFFD4AF37),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Waiting for your confirmation',
                        style: GoogleFonts.goudyBookletter1911(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFD4AF37),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            _buildStatusTimeline(order.deliveryStatus),
        ],
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildStatusTimeline(String? deliveryStatus) {
    // Use delivery status if available, otherwise show pending
    final statuses = ['pending', 'preparing', 'assigned', 'in_transit', 'delivered'];
    final currentStatus = deliveryStatus ?? 'pending';
    final currentIndex = statuses.indexOf(currentStatus);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          // Row for circles and lines
          Row(
            children: List.generate(statuses.length, (index) {
              final isActive = index <= currentIndex;
              final isLast = index == statuses.length - 1;

              return Expanded(
                child: Row(
                  children: [
                    // Left line (or invisible spacer for first item)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: index > 0 && index <= currentIndex 
                            ? _getStatusColor(statuses[index - 1])
                            : Colors.transparent,
                      ),
                    ),
                    // Circle
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isActive ? _getStatusColor(statuses[index]) : Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        size: 18,
                        color: isActive ? Colors.white : Colors.grey[500],
                      ),
                    ),
                    // Right line (or invisible spacer for last item)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: !isLast && index < currentIndex 
                            ? _getStatusColor(statuses[index])
                            : Colors.transparent,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          // Row for labels - perfectly aligned below circles
          Row(
            children: List.generate(statuses.length, (index) {
              final isActive = index <= currentIndex;

              return Expanded(
                child: Text(
                  _getStatusLabel(statuses[index]),
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 7,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive ? _getStatusColor(statuses[index]) : Colors.grey[500],
                    height: 1.1,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
  
  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'PENDING';
      case 'preparing':
        return 'PREPARING';
      case 'assigned':
        return 'READY';
      case 'in_transit':
        return 'IN TRANSIT';
      case 'delivered':
        return 'DELIVERED';
      default:
        return status.toUpperCase();
    }
  }
  
  Widget _buildRiderInfo(Order order) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rider Information',
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.riderName ?? 'N/A',
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (order.riderContact != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        order.riderContact!,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (order.riderContact != null)
                SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    onPressed: () => _contactRider(order.riderContact!),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      side: const BorderSide(color: Colors.black, width: 1),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      'Contact',
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
  
  Future<void> _contactRider(String phoneNumber) async {
    try {
      // Clean the phone number (remove spaces, dashes, etc.)
      final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      print('Attempting to call: $cleanNumber');
      
      final Uri phoneUri = Uri(scheme: 'tel', path: cleanNumber);
      print('Phone URI: $phoneUri');
      
      // Try to launch without checking canLaunchUrl first
      await launchUrl(phoneUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      print('Error launching phone: $e');
      if (mounted) {
        SnackBarHelper.showError(context, 'Could not launch phone app: $e');
      }
    }
  }

  Widget _buildDeliveryInfo(Order order) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delivery Information',
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (order.recipientName != null)
            _buildInfoRow(Icons.person, 'Recipient', order.recipientName!),
          if (order.phoneNumber != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(Icons.phone, 'Phone', order.phoneNumber!),
          ],
          if (order.fullAddress != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(Icons.location_on, 'Address', order.fullAddress!),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderItems(Order order) {
    if (order.items == null || order.items!.isEmpty) {
      return const SizedBox.shrink();
    }

    final isCancelled = order.orderStatus == 'cancelled';
    final isDelivered = order.deliveryStatus == 'delivered';
    final showBuyAgain = isCancelled || isDelivered;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Items',
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...order.items!.map((item) => _buildOrderItem(item, isCancelled: showBuyAgain)),
        ],
      ),
    );
  }

  Widget _buildOrderItem(OrderItem item, {bool isCancelled = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFD3BD9B),
              borderRadius: BorderRadius.circular(8),
            ),
            child: item.primaryImage != null && item.primaryImage!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: ImageHelper.getImageUrl(item.primaryImage!),
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: Icon(Icons.shopping_bag, color: Colors.white),
                      ),
                      errorWidget: (context, url, error) => const Center(
                        child: Icon(Icons.shopping_bag, color: Colors.white),
                      ),
                    ),
                  )
                : const Center(
                    child: Icon(Icons.shopping_bag, color: Colors.white),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (item.variantColor != null || item.variantSize != null)
                  Text(
                    [
                      if (item.variantColor != null) item.variantColor,
                      if (item.variantSize != null) item.variantSize,
                    ].join(' • '),
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  'x${item.quantity}',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                if (isCancelled) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 32,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProductDetailScreen(productId: item.productId),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        side: const BorderSide(color: Colors.black, width: 1),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        'Buy Again',
                        style: GoogleFonts.goudyBookletter1911(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '₱${item.subtotal.toStringAsFixed(2)}',
            style: GoogleFonts.playfairDisplay(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSummary(Order order) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal', style: GoogleFonts.goudyBookletter1911(fontSize: 14)),
              Text(
                '₱${order.subtotal.toStringAsFixed(2)}',
                style: GoogleFonts.playfairDisplay(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Shipping Fee', style: GoogleFonts.goudyBookletter1911(fontSize: 14)),
              Text(
                '₱${order.shippingFee.toStringAsFixed(2)}',
                style: GoogleFonts.playfairDisplay(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (order.discountAmount > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Discount', style: GoogleFonts.goudyBookletter1911(fontSize: 14, color: Colors.green[700])),
                Text(
                  '-₱${order.discountAmount.toStringAsFixed(2)}',
                  style: GoogleFonts.playfairDisplay(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.green[700]),
                ),
              ],
            ),
          ],
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '₱${order.totalAmount.toStringAsFixed(2)}',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCancelButton(Order order) {
    return Container(
      margin: const EdgeInsets.all(16),
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => _cancelOrder(order),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: Colors.red),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          'Cancel Order',
          style: GoogleFonts.goudyBookletter1911(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.red,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderReceivedButton(Order order) {
    return Container(
      margin: const EdgeInsets.all(16),
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _markOrderReceived(order),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: const Color(0xFFD4AF37),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          'Order Received',
          style: GoogleFonts.goudyBookletter1911(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _markOrderReceived(Order order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        title: Text('Confirm Order Received', style: GoogleFonts.goudyBookletter1911(fontWeight: FontWeight.w600)),
        content: Text(
          'Have you received your order in good condition?',
          style: GoogleFonts.goudyBookletter1911(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            ),
            child: Text('Not Yet', style: GoogleFonts.goudyBookletter1911()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            ),
            child: Text('Yes, Received', style: GoogleFonts.goudyBookletter1911()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final supabase = Supabase.instance.client;
        
        // Update order_received to true and order_status to delivered
        await supabase
            .from('orders')
            .update({
              'order_received': true,
              'order_status': 'delivered',
            })
            .eq('order_id', order.id);
        
        _loadOrder();
        if (mounted) {
          SnackBarHelper.showSuccess(context, 'Order marked as received');
        }
      } catch (e) {
        if (mounted) {
          SnackBarHelper.showError(context, 'Error: $e');
        }
      }
    }
  }
}
