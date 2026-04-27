import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order_model.dart';
import 'notification_service.dart';
import 'auth_service.dart';

class OrderService {
  final _supabase = Supabase.instance.client;
  final _notificationService = NotificationService();
  final _authService = AuthService();

  String? getCurrentUserId() => _authService.currentUserId;

  Future<Map<String, dynamic>> createOrder({
    required String buyerId,
    required String recipient,
    required String phone,
    required String address,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      // Generate order ID
      final orderId = 'ORD${DateTime.now().millisecondsSinceEpoch}';

      // Create order
      final orderResponse = await _supabase
          .from('orders')
          .insert({
            'order_id': orderId,
            'buyer_id': buyerId,
            'recipient': recipient,
            'phone': phone,
            'address': address,
            'total_amount': totalAmount,
            'status': 'pending',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final orderDbId = orderResponse['id'];

      // Create order items
      final orderItems = items
          .map(
            (item) => {
              'order_id': orderDbId,
              'product_id': item['product_id'],
              'product_name': item['product_name'],
              'price': item['price'],
              'quantity': item['quantity'],
              'primary_image': item['primary_image'],
            },
          )
          .toList();

      await _supabase.from('order_items').insert(orderItems);

      // Clear cart items
      final cartIds = items.map((item) => item['cart_id']).toList();
      await _supabase.from('cart').delete().inFilter('id', cartIds);

      // Send notification
      await _notificationService.sendNotification(
        userId: buyerId,
        title: 'Order Placed',
        message: 'Your order $orderId has been placed successfully!',
        type: 'order',
      );

      return {'success': true, 'order_id': orderId};
    } catch (e) {
      return {'success': false, 'message': 'Failed to create order: $e'};
    }
  }

  Future<List<Order>> getMyOrders(String buyerId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select('*')
          .eq('buyer_id', buyerId)
          .order('created_at', ascending: false);

      return (response as List).map((order) => Order.fromJson(order)).toList();
    } catch (e) {
      throw Exception('Failed to load orders: $e');
    }
  }

  Future<Order> getOrderDetails(int orderId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select('''
            *,
            order_items(*)
          ''')
          .eq('id', orderId)
          .single();

      return Order.fromJson(response);
    } catch (e) {
      throw Exception('Failed to load order details: $e');
    }
  }

  Future<void> cancelOrder(int orderId) async {
    try {
      await _supabase
          .from('orders')
          .update({
            'status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);
    } catch (e) {
      throw Exception('Failed to cancel order: $e');
    }
  }
}
