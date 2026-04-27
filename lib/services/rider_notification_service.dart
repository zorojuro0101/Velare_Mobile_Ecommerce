import 'package:supabase_flutter/supabase_flutter.dart';

class RiderNotificationService {
  final _supabase = Supabase.instance.client;

  /// Create "Order Shipped" notification when rider picks up item
  Future<void> createShippedNotification({
    required int orderId,
    required String orderNumber,
    required int buyerId,
    required double totalAmount,
  }) async {
    try {
      print('📧 Creating shipped notification for order #$orderNumber');

      // Get buyer's user_id
      final buyerData = await _supabase
          .from('buyers')
          .select('user_id')
          .eq('buyer_id', buyerId)
          .single();

      final userId = buyerData['user_id'];

      // Get product names from order items
      final orderItems = await _supabase
          .from('order_items')
          .select('product_name')
          .eq('order_id', orderId);

      final productNames = orderItems
          .map((item) => item['product_name'] as String)
          .toList();

      // Create notification
      final now = DateTime.now();
      final formattedDate =
          '${_getMonthName(now.month)} ${now.day}, ${now.year} at ${_formatTime(now)}';

      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': 'Order Shipped',
        'message':
            'Your order #$orderNumber is now on its way! Expected delivery in 2-3 business days.',
        'notification_type': 'delivery',
        'is_read': false,
        'order_id': orderId,
        'product_names': productNames,
        'order_total': totalAmount,
        'formatted_date': formattedDate,
        'created_at': now.toIso8601String(),
      });

      print('✅ Shipped notification created for order #$orderNumber');
    } catch (e) {
      // Non-blocking - don't throw error if notification fails
      print('⚠️ Failed to create shipped notification: $e');
    }
  }

  /// Create "Order Delivered" notification when rider completes delivery
  Future<void> createDeliveredNotification({
    required int orderId,
    required String orderNumber,
    required int buyerId,
    required double totalAmount,
  }) async {
    try {
      print('📧 Creating delivered notification for order #$orderNumber');

      // Get buyer's user_id
      final buyerData = await _supabase
          .from('buyers')
          .select('user_id')
          .eq('buyer_id', buyerId)
          .single();

      final userId = buyerData['user_id'];

      // Get product names from order items
      final orderItems = await _supabase
          .from('order_items')
          .select('product_name')
          .eq('order_id', orderId);

      final productNames = orderItems
          .map((item) => item['product_name'] as String)
          .toList();

      // Create notification
      final now = DateTime.now();
      final formattedDate =
          '${_getMonthName(now.month)} ${now.day}, ${now.year} at ${_formatTime(now)}';

      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': 'Order Delivered',
        'message': 'Your order #$orderNumber has been delivered successfully!',
        'notification_type': 'delivery',
        'is_read': false,
        'order_id': orderId,
        'product_names': productNames,
        'order_total': totalAmount,
        'formatted_date': formattedDate,
        'created_at': now.toIso8601String(),
      });

      print('✅ Delivered notification created for order #$orderNumber');
    } catch (e) {
      // Non-blocking - don't throw error if notification fails
      print('⚠️ Failed to create delivered notification: $e');
    }
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12
        ? time.hour - 12
        : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
