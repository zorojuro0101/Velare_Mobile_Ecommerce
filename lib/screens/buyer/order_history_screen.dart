import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../services/auth_service.dart';
import '../../utils/image_helper.dart';
import '../../utils/snackbar_helper.dart';
import 'order_detail_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  final String? initialTab;
  
  const OrderHistoryScreen({super.key, this.initialTab});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> with TickerProviderStateMixin {
  final OrderService _orderService = OrderService();
  final AuthService _authService = AuthService();
  Future<List<Order>>? _ordersFuture;
  String _selectedFilter = 'pending';
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialTab ?? 'pending';
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Reset to start and wait 1 second before next animation
        _pulseController.reset();
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _pulseController.forward();
          }
        });
      }
    });
    _pulseController.forward();
    _loadOrders();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    await _authService.initialize();
    var buyerId = _authService.currentBuyerId;
    
    if (buyerId == null) {
      final userId = _authService.currentUserId;
      if (userId != null) {
        final supabase = Supabase.instance.client;
        final buyerData = await supabase
            .from('buyers')
            .select('buyer_id')
            .eq('user_id', userId)
            .maybeSingle();
        
        if (buyerData != null) {
          buyerId = buyerData['buyer_id'].toString();
        }
      }
    }
    
    if (buyerId != null) {
      setState(() {
        _ordersFuture = _orderService.getMyOrders(buyerId!);
      });
    } else {
      setState(() {
        _ordersFuture = Future.value([]);
      });
    }
  }

  List<Order> _filterOrders(List<Order> orders) {
    return orders.where((order) {
      // For cancelled orders, check order_status
      if (_selectedFilter == 'cancelled') {
        return order.orderStatus == 'cancelled';
      }
      
      // For pending, show orders with status 'pending' or 'preparing'
      if (_selectedFilter == 'pending') {
        return order.orderStatus == 'pending' || order.orderStatus == 'preparing';
      }
      
      // For other filters, check delivery status
      return order.deliveryStatus == _selectedFilter;
    }).toList();
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

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'preparing':
        return Icons.inventory_2_outlined;
      case 'assigned':
        return Icons.check_circle_outline;
      case 'picked_up':
        return Icons.local_shipping;
      case 'in_transit':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }
  
  String _getDisplayStatus(Order order) {
    // Use delivery status if available, otherwise use order status
    final status = order.deliveryStatus ?? order.orderStatus;
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'preparing':
        return 'Preparing';
      case 'assigned':
        return 'Ready for Shipment';
      case 'picked_up':
        return 'Picked Up';
      case 'in_transit':
        return 'In Transit';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('My Orders', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: _buildTopTabs(),
        ),
      ),
      body: _ordersFuture == null
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : FutureBuilder<List<Order>>(
              future: _ordersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.black));
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}', style: GoogleFonts.goudyBookletter1911()),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState();
                }

                final filteredOrders = _filterOrders(snapshot.data!);
                if (filteredOrders.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  onRefresh: () async => _loadOrders(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredOrders.length,
                    itemBuilder: (context, index) {
                      return _buildOrderCard(filteredOrders[index]);
                    },
                  ),
                );
              },
            ),
    );
  }

  Widget _buildTopTabs() {
    final tabs = [
      {'label': 'Pending', 'value': 'pending', 'icon': Icons.schedule},
      {'label': 'In Transit', 'value': 'in_transit', 'icon': Icons.local_shipping},
      {'label': 'Delivered', 'value': 'delivered', 'icon': Icons.check_circle},
      {'label': 'Cancelled', 'value': 'cancelled', 'icon': Icons.cancel},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: tabs.map((tab) {
            final isSelected = _selectedFilter == tab['value'];
            return Expanded(
              child: InkWell(
                onTap: () {
                  setState(() => _selectedFilter = tab['value'] as String);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tab['icon'] as IconData,
                      size: 24,
                      color: isSelected ? const Color(0xFFD4AF37) : Colors.grey[600],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tab['label'] as String,
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? const Color(0xFFD4AF37) : Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 2,
                      width: 40,
                      color: isSelected ? const Color(0xFFD4AF37) : Colors.transparent,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 100, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No orders yet',
            style: GoogleFonts.goudyBookletter1911(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Start shopping to see your orders here',
            style: GoogleFonts.goudyBookletter1911(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    final status = order.deliveryStatus ?? order.orderStatus;
    final isDelivered = status == 'delivered';
    final isCancelled = order.orderStatus == 'cancelled';
    final canCancel = status == 'pending' || status == 'preparing';
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(orderId: order.id),
          ),
        ).then((_) => _loadOrders());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Shop logo
                if (order.shopLogo != null && order.shopLogo!.isNotEmpty) ...[
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD3BD9B),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Builder(
                      builder: (context) {
                        final imageUrl = ImageHelper.getImageUrl(order.shopLogo!);
                        if (imageUrl.isEmpty) {
                          return Center(
                            child: Text(
                              order.shopName?.isNotEmpty == true ? order.shopName![0].toUpperCase() : 'S',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          );
                        }
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Center(
                              child: Text(
                                order.shopName?.isNotEmpty == true ? order.shopName![0].toUpperCase() : 'S',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Center(
                              child: Text(
                                order.shopName?.isNotEmpty == true ? order.shopName![0].toUpperCase() : 'S',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (order.shopName != null)
                        Text(
                          order.shopName!,
                          style: GoogleFonts.goudyBookletter1911(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      Text(
                        order.orderNumber,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge in upper right corner
                (isDelivered || isCancelled)
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getStatusIcon(status),
                              size: 12,
                              color: _getStatusColor(status),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _getDisplayStatus(order),
                              style: GoogleFonts.goudyBookletter1911(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _getStatusColor(status),
                              ),
                            ),
                          ],
                        ),
                      )
                    : AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Stack(
                              children: [
                                // Animated wave overlay - moves across transparent background
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(5),
                                    child: Opacity(
                                      opacity: _pulseController.value,
                                      child: FractionallySizedBox(
                                        alignment: Alignment(
                                          -1.0 + (2.0 * _pulseController.value),
                                          0.0,
                                        ),
                                        widthFactor: 0.3,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                              colors: [
                                                Colors.transparent,
                                                _getStatusColor(status).withValues(alpha: 0.2),
                                                Colors.transparent,
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Status content - full color text and icon
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getStatusIcon(status),
                                      size: 12,
                                      color: _getStatusColor(status),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _getDisplayStatus(order),
                                      style: GoogleFonts.goudyBookletter1911(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: _getStatusColor(status),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ],
            ),
            const SizedBox(height: 12),
            // Display order items (products) - no border
            if (order.items != null && order.items!.isNotEmpty) ...[
              ...order.items!.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    // Product image
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD3BD9B),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: item.primaryImage != null && item.primaryImage!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: CachedNetworkImage(
                                imageUrl: ImageHelper.getImageUrl(item.primaryImage!),
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Center(
                                  child: Icon(Icons.shopping_bag, color: Colors.white, size: 20),
                                ),
                                errorWidget: (context, url, error) => const Center(
                                  child: Icon(Icons.shopping_bag, color: Colors.white, size: 20),
                                ),
                              ),
                            )
                          : const Center(
                              child: Icon(Icons.shopping_bag, color: Colors.white, size: 20),
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
                          if (item.variantColor != null || item.variantSize != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              [
                                if (item.variantColor != null) item.variantColor,
                                if (item.variantSize != null) item.variantSize,
                              ].join(' • '),
                              style: GoogleFonts.goudyBookletter1911(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'x${item.quantity}',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 12),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 14,
                    color: Colors.grey[600],
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
            // Cancel button below total price on lower right
            if (canCancel) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  height: 28,
                  child: OutlinedButton(
                    onPressed: () => _cancelOrder(order),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      side: const BorderSide(color: Colors.black, width: 1),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      minimumSize: const Size(0, 28),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            // Order Received button when order status is delivered but not yet received
            if (order.orderStatus == 'delivered' && 
                !order.orderReceived) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  height: 28,
                  child: OutlinedButton(
                    onPressed: () => _markOrderReceived(order),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFD4AF37),
                      side: const BorderSide(color: Color(0xFFD4AF37), width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      minimumSize: const Size(0, 28),
                      elevation: 0,
                    ),
                    child: Text(
                      'Order Received',
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            // Write a Review button when order is received but not yet reviewed
            if (order.orderReceived && !order.hasReviews) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  height: 28,
                  child: OutlinedButton(
                    onPressed: () => _showReviewDialog(order),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black, width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      minimumSize: const Size(0, 28),
                      elevation: 0,
                    ),
                    child: Text(
                      'Write a Review',
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
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
  
  Future<void> _cancelOrder(Order order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Order', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
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
        final supabase = Supabase.instance.client;
        
        print('=== Cancelling Order ===');
        print('Order ID: ${order.id}');
        
        // Get all order items with their details
        final orderItemsResponse = await supabase
            .from('order_items')
            .select('product_id, quantity, variant_color, variant_size')
            .eq('order_id', order.id);
        
        print('Order items to restore: $orderItemsResponse');
        
        // Return stock for each item
        for (var orderItem in orderItemsResponse as List) {
          final productId = orderItem['product_id'];
          final quantity = orderItem['quantity'] as int;
          final color = orderItem['variant_color'];
          final size = orderItem['variant_size'];
          
          print('Restoring stock for product $productId, color: $color, size: $size, quantity: $quantity');
          
          // Find the variant
          var variantQuery = supabase
              .from('product_variants')
              .select('variant_id, stock_quantity')
              .eq('product_id', productId);
          
          if (color != null && color.toString().isNotEmpty) {
            variantQuery = variantQuery.eq('color', color);
          }
          
          if (size != null && size.toString().isNotEmpty) {
            variantQuery = variantQuery.eq('size', size);
          }
          
          final variantResponse = await variantQuery.maybeSingle();
          
          print('Variant found: $variantResponse');
          
          if (variantResponse != null) {
            final variantId = variantResponse['variant_id'];
            final currentStock = (variantResponse['stock_quantity'] as num?)?.toInt() ?? 0;
            final newStock = currentStock + quantity;
            
            print('Current stock: $currentStock, Adding back: $quantity, New stock: $newStock');
            
            await supabase
                .from('product_variants')
                .update({'stock_quantity': newStock})
                .eq('variant_id', variantId);
            
            print('✓ Stock restored for variant $variantId');
          } else {
            print('WARNING: Variant not found for product $productId');
          }
        }
        
        // Update order status to cancelled
        await supabase
            .from('orders')
            .update({'order_status': 'cancelled'})
            .eq('order_id', order.id);
        
        // Restore voucher if one was used
        if (order.voucherId != null) {
          try {
            print('Restoring voucher: voucher_id=${order.voucherId}');
            
            // Find the buyer_voucher record
            final buyerVoucherResponse = await supabase
                .from('buyer_vouchers')
                .select('buyer_voucher_id, times_remaining')
                .eq('buyer_id', order.buyerId)
                .eq('voucher_id', order.voucherId!)
                .maybeSingle();
            
            if (buyerVoucherResponse != null) {
              final buyerVoucherId = buyerVoucherResponse['buyer_voucher_id'];
              final currentRemaining = (buyerVoucherResponse['times_remaining'] as int);
              final newRemaining = currentRemaining + 1;
              
              // Increment times_remaining
              await supabase
                  .from('buyer_vouchers')
                  .update({'times_remaining': newRemaining})
                  .eq('buyer_voucher_id', buyerVoucherId);
              
              print('✓ Voucher restored: buyer_voucher_id=$buyerVoucherId, remaining: $currentRemaining -> $newRemaining');
            } else {
              print('No buyer_voucher found for buyer_id=${order.buyerId}, voucher_id=${order.voucherId}');
            }
          } catch (e) {
            print('ERROR restoring voucher: $e');
          }
        }
        
        print('✓ Order cancelled successfully');
        print('========================');
        
        _loadOrders();
        if (mounted) {
          SnackBarHelper.showSuccess(context, 'Order cancelled and stock restored');
        }
      } catch (e, stackTrace) {
        print('ERROR cancelling order: $e');
        print('Stack trace: $stackTrace');
        if (mounted) {
          SnackBarHelper.showError(context, 'Error cancelling order: $e');
        }
      }
    }
  }

  OverlayEntry? _currentNotification;

  void _showCustomNotification(String message, {Color backgroundColor = Colors.red}) {
    // Remove existing notification if any
    _currentNotification?.remove();
    
    _currentNotification = OverlayEntry(
      builder: (context) => Positioned(
        top: 100,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(350 * (1 - value), 0), // Slide in from right
                child: child,
              );
            },
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    backgroundColor == Colors.green ? Icons.check_circle : Icons.error,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: GoogleFonts.goudyBookletter1911(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      _currentNotification?.remove();
                      _currentNotification = null;
                    },
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    
    Overlay.of(context).insert(_currentNotification!);
    
    // Auto remove after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      _currentNotification?.remove();
      _currentNotification = null;
    });
  }

  void _showReviewDialog(Order order) {
    if (order.items == null || order.items!.isEmpty) {
      _showCustomNotification('No items to review');
      return;
    }

    // Create state for ratings and reviews
    Map<int, int> ratings = {};
    Map<int, TextEditingController> reviewControllers = {};
    bool isSubmitting = false;
    String? errorMessage;
    Timer? errorTimer;
    
    for (var item in order.items!) {
      ratings[item.productId] = 0;
      reviewControllers[item.productId] = TextEditingController();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          contentPadding: const EdgeInsets.all(24),
          title: Text(
            'Write a Review',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        border: Border.all(color: Colors.red),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: GoogleFonts.goudyBookletter1911(
                                fontSize: 13,
                                color: Colors.red[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  ...List.generate(order.items!.length, (index) {
                    final item = order.items![index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Product info
                          Row(
                            children: [
                              Container(
                            width: 80,
                            height: 80,
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
                                      errorWidget: (context, url, error) => const Icon(Icons.shopping_bag, color: Colors.white, size: 32),
                                    ),
                                  )
                                : const Icon(Icons.shopping_bag, color: Colors.white, size: 32),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName,
                                  style: GoogleFonts.goudyBookletter1911(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (item.variantColor != null || item.variantSize != null)
                                  Text(
                                    [
                                      if (item.variantColor != null) item.variantColor,
                                      if (item.variantSize != null) item.variantSize,
                                    ].join(' • '),
                                    style: GoogleFonts.goudyBookletter1911(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Star rating
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (starIndex) {
                          return IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              starIndex < ratings[item.productId]!
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.amber,
                              size: 36,
                            ),
                            onPressed: () {
                              setState(() {
                                ratings[item.productId] = starIndex + 1;
                                errorMessage = null;
                                errorTimer?.cancel();
                              });
                            },
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      // Review text
                      TextField(
                        controller: reviewControllers[item.productId],
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Share your experience with this product...',
                          hintStyle: GoogleFonts.goudyBookletter1911(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(5),
                            borderSide: const BorderSide(color: Colors.black),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(5),
                            borderSide: const BorderSide(color: Colors.black),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(5),
                            borderSide: const BorderSide(color: Colors.black, width: 2),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        style: GoogleFonts.goudyBookletter1911(fontSize: 13),
                        onChanged: (value) {
                          if (errorMessage != null) {
                            setState(() {
                              errorMessage = null;
                              errorTimer?.cancel();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              ),
              child: Text('Cancel', style: GoogleFonts.goudyBookletter1911(color: Colors.black)),
            ),
            ElevatedButton(
              onPressed: isSubmitting ? null : () async {
                // Validate all ratings
                final unratedProducts = ratings.entries.where((e) => e.value == 0).toList();
                if (unratedProducts.isNotEmpty) {
                  setState(() {
                    errorMessage = 'Please rate all products';
                    errorTimer?.cancel();
                    errorTimer = Timer(const Duration(seconds: 3), () {
                      if (context.mounted) {
                        setState(() {
                          errorMessage = null;
                        });
                      }
                    });
                  });
                  return;
                }

                // Set submitting state
                setState(() {
                  isSubmitting = true;
                  errorMessage = null;
                  errorTimer?.cancel();
                });

                // Submit reviews
                try {
                  final supabase = Supabase.instance.client;
                  final buyerId = _authService.currentBuyerId;
                  
                  if (buyerId == null) {
                    throw Exception('Not logged in');
                  }

                  for (var item in order.items!) {
                    await supabase.from('product_reviews').insert({
                      'product_id': item.productId,
                      'buyer_id': int.parse(buyerId),
                      'order_id': order.id,
                      'rating': ratings[item.productId]!,
                      'review_text': reviewControllers[item.productId]!.text.trim(),
                    });

                    // Update product rating
                    final reviewsResponse = await supabase
                        .from('product_reviews')
                        .select('rating')
                        .eq('product_id', item.productId);
                    
                    if (reviewsResponse.isNotEmpty) {
                      final totalReviews = reviewsResponse.length;
                      final avgRating = reviewsResponse
                          .map((r) => r['rating'] as num)
                          .reduce((a, b) => a + b) / totalReviews;
                      
                      await supabase
                          .from('products')
                          .update({
                            'total_reviews': totalReviews,
                            'rating': avgRating,
                          })
                          .eq('product_id', item.productId);
                    }
                  }

                  if (mounted) {
                    Navigator.pop(dialogContext);
                    SnackBarHelper.showSuccess(context, 'Review submitted successfully!');
                    _loadOrders();
                  }
                } catch (e) {
                  print('Error submitting review: $e');
                  setState(() {
                    isSubmitting = false;
                    errorMessage = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
                    errorTimer?.cancel();
                    errorTimer = Timer(const Duration(seconds: 3), () {
                      if (context.mounted) {
                        setState(() {
                          errorMessage = null;
                        });
                      }
                    });
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text('Submit', style: GoogleFonts.goudyBookletter1911()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markOrderReceived(Order order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        title: Text('Confirm Order Received', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        content: Text(
          'Have you received your order in good condition?',
          style: GoogleFonts.goudyBookletter1911(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            ),
            child: Text('Not Yet', style: GoogleFonts.goudyBookletter1911()),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, true),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFD4AF37),
              side: const BorderSide(color: Color(0xFFD4AF37), width: 1),
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
        
        _loadOrders();
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
