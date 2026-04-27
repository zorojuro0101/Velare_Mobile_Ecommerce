import 'package:supabase_flutter/supabase_flutter.dart';
import 'rider_notification_service.dart';

class RiderService {
  final _supabase = Supabase.instance.client;
  final _notificationService = RiderNotificationService();

  Future<List<dynamic>> getAvailableOrders() async {
    try {
      final response = await _supabase
          .from('deliveries')
          .select(
            '*, orders!inner(order_number, total_amount, order_status, buyer_id)',
          )
          .filter('rider_id', 'is', null)
          .order('created_at', ascending: false);

      return response as List<dynamic>;
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  Future<List<dynamic>> getMyOrders(String userId) async {
    try {
      // Get the actual rider_id from riders table using user_id
      final riderData = await _supabase
          .from('riders')
          .select('rider_id')
          .eq('user_id', userId)
          .single();

      final riderId = riderData['rider_id'];

      final response = await _supabase
          .from('deliveries')
          .select(
            '*, orders!inner(order_number, total_amount, order_status, buyer_id)',
          )
          .eq('rider_id', riderId)
          .inFilter('status', ['assigned', 'in_transit'])
          .order('created_at', ascending: false);

      return response as List<dynamic>;
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  Future<void> acceptOrder(int deliveryId, String userId) async {
    try {
      print('🚀 Accepting order: delivery_id=$deliveryId, user_id=$userId');

      // Step 1: Get the actual rider_id from riders table using user_id
      final riderData = await _supabase
          .from('riders')
          .select('rider_id')
          .eq('user_id', userId)
          .single();

      final riderId = riderData['rider_id'];
      print('✅ Found rider_id: $riderId for user_id: $userId');

      // Step 2: Update delivery to assigned status with actual rider_id
      // NOTE: assigned_at is set here, picked_up_at will be set during pickup
      await _supabase
          .from('deliveries')
          .update({
            'rider_id': riderId,
            'status': 'assigned',
            'assigned_at': DateTime.now().toIso8601String(),
          })
          .eq('delivery_id', deliveryId);

      print('✅ Delivery updated to assigned');

      // Step 3: Update rider status to busy using rider_id
      await _supabase
          .from('riders')
          .update({'status': 'busy'})
          .eq('rider_id', riderId);

      print('✅ Rider status updated to busy');
    } catch (e) {
      print('❌ Error accepting order: $e');
      throw Exception('Failed to accept order: $e');
    }
  }

  Future<void> pickupOrder(int deliveryId, int orderId) async {
    try {
      // Step 1: Get order details for notification
      final delivery = await _supabase
          .from('deliveries')
          .select('*, orders!inner(order_number, total_amount, buyer_id)')
          .eq('delivery_id', deliveryId)
          .single();

      // Step 2: Update delivery to in_transit status
      await _supabase
          .from('deliveries')
          .update({
            'status': 'in_transit',
            'picked_up_at': DateTime.now().toIso8601String(),
          })
          .eq('delivery_id', deliveryId);

      // Step 3: Update order status to in_transit
      await _supabase
          .from('orders')
          .update({'order_status': 'in_transit'})
          .eq('order_id', orderId);

      // Step 4: Create shipped notification (non-blocking)
      try {
        final orderData = delivery['orders'];
        await _notificationService.createShippedNotification(
          orderId: orderId,
          orderNumber: orderData['order_number'] ?? orderId.toString(),
          buyerId: orderData['buyer_id'],
          totalAmount: (orderData['total_amount'] ?? 0).toDouble(),
        );
      } catch (e) {
        print('⚠️ Notification failed but pickup succeeded: $e');
      }
    } catch (e) {
      throw Exception('Failed to pickup order: $e');
    }
  }

  Future<void> updateOrderStatus(
    int deliveryId,
    String status,
    String userId,
  ) async {
    try {
      print('🚚 updateOrderStatus called');
      print('  delivery_id: $deliveryId');
      print('  status: $status');
      print('  user_id: $userId');

      // Get the actual rider_id from riders table using user_id
      final riderData = await _supabase
          .from('riders')
          .select('rider_id, total_earnings')
          .eq('user_id', userId)
          .single();

      final riderId = riderData['rider_id'];
      print('  rider_id: $riderId');

      if (status == 'delivered') {
        print('📦 Fetching delivery details...');
        // Get delivery details FIRST
        final delivery = await _supabase
            .from('deliveries')
            .select(
              'delivery_fee, order_id, orders!inner(order_number, total_amount, buyer_id)',
            )
            .eq('delivery_id', deliveryId)
            .single();

        print('📦 Delivery data: $delivery');

        final deliveryFee = (delivery['delivery_fee'] ?? 0).toDouble();
        final orderId = delivery['order_id'];
        final orderData = delivery['orders'];

        print('💰 Delivery fee: ₱$deliveryFee');

        // Step 1: Update delivery status (EXACTLY like web - only status and delivered_at)
        print('📝 Step 1: Updating delivery status...');
        await _supabase
            .from('deliveries')
            .update({
              'status': 'delivered',
              'delivered_at': DateTime.now().toIso8601String(),
            })
            .eq('delivery_id', deliveryId);

        // Step 2: Update rider earnings in delivery
        print('📝 Step 2: Updating rider earnings...');
        await _supabase
            .from('deliveries')
            .update({'rider_earnings': deliveryFee})
            .eq('delivery_id', deliveryId);

        // Step 3: Update order status to delivered
        print('📝 Step 3: Updating order status...');
        await _supabase
            .from('orders')
            .update({'order_status': 'delivered'})
            .eq('order_id', orderId);

        // Step 4: Update rider status and total earnings
        print('📝 Step 4: Updating rider status and earnings...');
        final currentEarnings = (riderData['total_earnings'] ?? 0).toDouble();
        final newTotalEarnings = currentEarnings + deliveryFee;

        await _supabase
            .from('riders')
            .update({'status': 'available', 'total_earnings': newTotalEarnings})
            .eq('rider_id', riderId);

        print('✅ Delivery completed successfully!');
        print('   Rider earnings: ₱$deliveryFee');
        print('   New total: ₱$newTotalEarnings');

        // Create delivered notification (non-blocking)
        try {
          await _notificationService.createDeliveredNotification(
            orderId: orderId,
            orderNumber: orderData['order_number'] ?? orderId.toString(),
            buyerId: orderData['buyer_id'],
            totalAmount: (orderData['total_amount'] ?? 0).toDouble(),
          );
        } catch (e) {
          print('⚠️ Notification failed but delivery succeeded: $e');
        }
      } else {
        await _supabase
            .from('deliveries')
            .update({'status': status})
            .eq('delivery_id', deliveryId);
      }
    } catch (e, stackTrace) {
      print('❌ Error in updateOrderStatus: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to update order: $e');
    }
  }
}
