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
    required List<Map<String, dynamic>> items,
    required int addressId,
    required double subtotal,
    required double shippingFee,
    required double totalAmount,
    double discountAmount = 0.0,
    int? voucherId,
    int? buyerVoucherId,
  }) async {
    try {
      // Get buyer_id
      await _authService.initialize();
      var buyerId = _authService.currentBuyerId;
      
      if (buyerId == null) {
        final userId = _authService.currentUserId;
        if (userId != null) {
          final buyerData = await _supabase
              .from('buyers')
              .select('buyer_id')
              .eq('user_id', userId)
              .maybeSingle();
          
          if (buyerData != null) {
            buyerId = buyerData['buyer_id'].toString();
          }
        }
      }
      
      if (buyerId == null) {
        return {'success': false, 'message': 'Buyer ID not found'};
      }

      // Group items by seller
      final Map<String, List<Map<String, dynamic>>> sellerItems = {};
      for (var item in items) {
        final sellerId = item['seller_id'].toString();
        if (!sellerItems.containsKey(sellerId)) {
          sellerItems[sellerId] = [];
        }
        sellerItems[sellerId]!.add(item);
      }

      // Get starting order number
      final currentYear = DateTime.now().year;
      final lastOrderResponse = await _supabase
          .from('orders')
          .select('order_number')
          .like('order_number', 'VEL-$currentYear-%')
          .order('order_id', ascending: false)
          .limit(1);

      int nextNum = 1;
      if (lastOrderResponse.isNotEmpty) {
        try {
          final lastNum = int.parse(lastOrderResponse[0]['order_number'].toString().split('-').last);
          nextNum = lastNum + 1;
        } catch (e) {
          nextNum = 1;
        }
      }

      final List<String> orderNumbers = [];
      final numSellers = sellerItems.length;

      // Create orders for each seller
      for (var entry in sellerItems.entries) {
        final sellerId = entry.key;
        final sellerItemsList = entry.value;

        // Calculate seller totals
        double sellerSubtotal = 0;
        for (var item in sellerItemsList) {
          sellerSubtotal += (item['price'] as num).toDouble() * (item['quantity'] as int);
        }

        final sellerShipping = shippingFee / numSellers;
        final commissionAmount = sellerSubtotal * 0.05;
        final sellerTotal = sellerSubtotal + sellerShipping;

        final orderNumber = 'VEL-$currentYear-${nextNum.toString().padLeft(4, '0')}';
        nextNum++;

        // Insert order
        final orderData = {
          'order_number': orderNumber,
          'buyer_id': int.parse(buyerId),
          'seller_id': int.parse(sellerId),
          'address_id': addressId,
          'subtotal': sellerSubtotal,
          'shipping_fee': sellerShipping,
          'discount_amount': discountAmount / numSellers, // Split discount across sellers
          'total_amount': sellerTotal - (discountAmount / numSellers),
          'commission_amount': commissionAmount,
          'voucher_id': voucherId,
          'order_status': 'pending',
        };

        final orderResponse = await _supabase
            .from('orders')
            .insert(orderData)
            .select()
            .single();

        final orderId = orderResponse['order_id'];
        orderNumbers.add(orderNumber);

        // Get seller shop name for pickup address
        final sellerResponse = await _supabase
            .from('sellers')
            .select('shop_name')
            .eq('seller_id', int.parse(sellerId))
            .maybeSingle();

        final pickupAddress = sellerResponse?['shop_name'] ?? 'N/A';

        // Get buyer address for delivery
        final addressResponse = await _supabase
            .from('addresses')
            .select('full_address, barangay, city, province, postal_code')
            .eq('address_id', addressId)
            .maybeSingle();

        String deliveryAddress = 'N/A';
        if (addressResponse != null) {
          final parts = <String>[];
          if (addressResponse['full_address'] != null && addressResponse['full_address'].toString().isNotEmpty) {
            parts.add(addressResponse['full_address']);
          }
          if (addressResponse['barangay'] != null) parts.add(addressResponse['barangay']);
          if (addressResponse['city'] != null) parts.add(addressResponse['city']);
          if (addressResponse['province'] != null) parts.add(addressResponse['province']);
          if (addressResponse['postal_code'] != null && addressResponse['postal_code'].toString().isNotEmpty) {
            parts.add(addressResponse['postal_code']);
          }
          deliveryAddress = parts.join(', ');
        }

        // Create delivery record
        final deliveryData = {
          'order_id': orderId,
          'pickup_address': pickupAddress,
          'delivery_address': deliveryAddress,
          'delivery_fee': sellerShipping,
          'paid_by_platform': false,
          'status': null,
        };
        await _supabase.from('deliveries').insert(deliveryData);

        // Insert order items and update stock
        for (var item in sellerItemsList) {
          final itemSubtotal = (item['price'] as num).toDouble() * (item['quantity'] as int);

          final orderItemData = {
            'order_id': orderId,
            'product_id': item['product_id'],
            'product_name': item['product_name'],
            'materials': item['materials'],
            'variant_color': item['color'],
            'variant_size': item['size'],
            'quantity': item['quantity'],
            'unit_price': (item['price'] as num).toDouble(),
            'subtotal': itemSubtotal,
          };
          await _supabase.from('order_items').insert(orderItemData);

          // Update variant stock_quantity immediately when order is placed
          try {
            print('=== Stock Update Debug ===');
            print('Item data: ${item}');
            
            int? variantIdToUpdate;
            
            // First try: Use variant_id if provided
            if (item['variant_id'] != null) {
              variantIdToUpdate = item['variant_id'] as int;
              print('Using variant_id from cart: $variantIdToUpdate');
            } else {
              // Second try: Query by product_id, color, and size
              print('No variant_id, querying by product_id, color, size');
              print('Product ID: ${item['product_id']}');
              print('Color: ${item['color']}');
              print('Size: ${item['size']}');
              
              var query = _supabase
                  .from('product_variants')
                  .select('variant_id, stock_quantity, color, size')
                  .eq('product_id', item['product_id']);
              
              if (item['color'] != null && item['color'].toString().isNotEmpty) {
                query = query.eq('color', item['color']);
              }
              
              if (item['size'] != null && item['size'].toString().isNotEmpty) {
                query = query.eq('size', item['size']);
              }
              
              final variantResponse = await query.maybeSingle();
              print('Variant query result: $variantResponse');
              
              if (variantResponse != null) {
                variantIdToUpdate = variantResponse['variant_id'] as int;
                print('Found variant_id: $variantIdToUpdate');
              }
            }
            
            if (variantIdToUpdate != null) {
              // Get current stock
              final stockResponse = await _supabase
                  .from('product_variants')
                  .select('stock_quantity')
                  .eq('variant_id', variantIdToUpdate)
                  .single();
              
              final currentStock = (stockResponse['stock_quantity'] as num?)?.toInt() ?? 0;
              final quantityOrdered = item['quantity'] as int;
              final newStock = currentStock - quantityOrdered;
              
              print('Variant ID: $variantIdToUpdate');
              print('Current stock: $currentStock');
              print('Quantity ordered: $quantityOrdered');
              print('New stock will be: $newStock');
              
              // Update the stock
              await _supabase
                  .from('product_variants')
                  .update({'stock_quantity': newStock >= 0 ? newStock : 0})
                  .eq('variant_id', variantIdToUpdate);
              
              print('✓ Stock updated successfully!');
              
              // Verify the update
              final verifyResponse = await _supabase
                  .from('product_variants')
                  .select('stock_quantity')
                  .eq('variant_id', variantIdToUpdate)
                  .single();
              
              print('Verified new stock: ${verifyResponse['stock_quantity']}');
            } else {
              print('ERROR: Could not find variant_id!');
            }
            
            print('=========================');
          } catch (e, stackTrace) {
            print('ERROR updating variant stock: $e');
            print('Stack trace: $stackTrace');
          }
          
          // NOTE: total_sold is NOT updated here
          // It will be updated when the order status changes to 'delivered'
          // This should be handled by the seller/admin when they mark order as delivered
        }
      }

      // Clear cart items
      final cartIds = items.map((item) => item['cart_id']).toList();
      for (var cartId in cartIds) {
        await _supabase.from('cart').delete().eq('cart_id', cartId);
      }

      // Update voucher usage if one was used
      if (buyerVoucherId != null) {
        try {
          // Get current times_remaining
          final voucherResponse = await _supabase
              .from('buyer_vouchers')
              .select('times_remaining')
              .eq('buyer_voucher_id', buyerVoucherId)
              .single();
          
          final currentRemaining = (voucherResponse['times_remaining'] as int);
          final newRemaining = currentRemaining - 1;
          
          // Update times_remaining
          await _supabase
              .from('buyer_vouchers')
              .update({'times_remaining': newRemaining})
              .eq('buyer_voucher_id', buyerVoucherId);
          
          print('Voucher updated: buyer_voucher_id=$buyerVoucherId, remaining: $currentRemaining -> $newRemaining');
        } catch (e) {
          print('Error updating voucher: $e');
        }
      }

      // Send notification using user_id (not buyer_id)
      final userId = _authService.currentUserId;
      if (userId != null) {
        await _notificationService.sendNotification(
          userId: userId,
          title: 'Order Placed',
          message: 'Your order has been placed successfully!',
          type: 'order',
        );
      }

      return {
        'success': true,
        'order_numbers': orderNumbers,
        'message': 'Order placed successfully'
      };
    } catch (e) {
      print('Order creation error: $e');
      return {'success': false, 'message': 'Failed to create order: $e'};
    }
  }

  Future<List<Order>> getMyOrders(String buyerId) async {
    try {
      // First get orders with basic info
      final response = await _supabase
          .from('orders')
          .select('''
            *,
            addresses!inner(full_address, barangay, city, province, postal_code, recipient_name, phone_number),
            sellers!inner(shop_name, shop_logo),
            deliveries(status),
            order_items(order_item_id, order_id, product_id, product_name, materials, variant_color, variant_size, quantity, unit_price, subtotal)
          ''')
          .eq('buyer_id', int.parse(buyerId))
          .order('created_at', ascending: false);

      final orders = response as List;
      
      // Collect all unique product IDs
      final Set<int> productIds = {};
      for (var orderData in orders) {
        if (orderData['order_items'] != null) {
          final items = orderData['order_items'] as List;
          for (var item in items) {
            if (item['product_id'] != null) {
              productIds.add(item['product_id'] as int);
            }
          }
        }
      }
      
      // Fetch all product images in one query
      Map<int, String> productImages = {};
      if (productIds.isNotEmpty) {
        try {
          final imagesResponse = await _supabase
              .from('product_images')
              .select('product_id, image_url')
              .inFilter('product_id', productIds.toList());
          
          // Create a map of product_id to image_url (use first image for each product)
          for (var imageData in imagesResponse as List) {
            final productId = imageData['product_id'] as int;
            if (!productImages.containsKey(productId)) {
              productImages[productId] = imageData['image_url'];
            }
          }
        } catch (e) {
          print('Could not fetch product images: $e');
        }
      }
      
      // Add images to order items
      for (var orderData in orders) {
        if (orderData['order_items'] != null) {
          final items = orderData['order_items'] as List;
          for (var item in items) {
            final productId = item['product_id'];
            if (productId != null && productImages.containsKey(productId)) {
              item['products'] = {'primary_image': productImages[productId]};
            }
          }
        }
      }

      // Check for reviews for each order
      final orderIds = orders.map((o) => o['order_id'] as int).toList();
      Map<int, bool> hasReviewsMap = {};
      
      if (orderIds.isNotEmpty) {
        try {
          final reviewsResponse = await _supabase
              .from('product_reviews')
              .select('order_id')
              .inFilter('order_id', orderIds);
          
          for (var review in reviewsResponse as List) {
            hasReviewsMap[review['order_id'] as int] = true;
          }
        } catch (e) {
          print('Could not fetch reviews: $e');
        }
      }

      // Add has_reviews to each order
      for (var orderData in orders) {
        final orderId = orderData['order_id'] as int;
        orderData['has_reviews'] = hasReviewsMap[orderId] ?? false;
      }

      return orders.map((order) => Order.fromJson(order)).toList();
    } catch (e) {
      print('Failed to load orders: $e');
      throw Exception('Failed to load orders: $e');
    }
  }

  Future<Order> getOrderDetails(int orderId) async {
    print('=== FETCHING ORDER DETAILS ===');
    print('Order ID: $orderId');
    try {
      print('Executing query...');
      final response = await _supabase
          .from('orders')
          .select('''
            *,
            order_items(order_item_id, order_id, product_id, product_name, materials, variant_color, variant_size, quantity, unit_price, subtotal),
            addresses(full_address, barangay, city, province, postal_code, recipient_name, phone_number),
            sellers(shop_name, shop_logo),
            deliveries(status, rider_id)
          ''')
          .eq('order_id', orderId)
          .single();

      print('Query completed!');
      print('=== ORDER DETAILS RESPONSE ===');
      print('order_id: ${response['order_id']}');
      print('order_number: ${response['order_number']}');
      print('order_status: ${response['order_status']}');
      print('order_received: ${response['order_received']}');
      print('voucher_id: ${response['voucher_id']}');
      print('deliveries: ${response['deliveries']}');
      if (response['deliveries'] != null) {
        final deliveries = response['deliveries'];
        if (deliveries is List && deliveries.isNotEmpty) {
          print('delivery status: ${deliveries[0]['status']}');
        } else if (deliveries is Map) {
          print('delivery status: ${deliveries['status']}');
        }
      }
      print('==============================');

      // Collect all product IDs from order items
      final Set<int> productIds = {};
      if (response['order_items'] != null) {
        final items = response['order_items'] as List;
        for (var item in items) {
          if (item['product_id'] != null) {
            productIds.add(item['product_id'] as int);
          }
        }
      }
      
      // Fetch all product images in one query
      Map<int, String> productImages = {};
      if (productIds.isNotEmpty) {
        try {
          final imagesResponse = await _supabase
              .from('product_images')
              .select('product_id, image_url')
              .inFilter('product_id', productIds.toList());
          
          // Create a map of product_id to image_url
          for (var imageData in imagesResponse as List) {
            final productId = imageData['product_id'] as int;
            if (!productImages.containsKey(productId)) {
              productImages[productId] = imageData['image_url'];
            }
          }
        } catch (e) {
          print('Could not fetch product images: $e');
        }
      }
      
      // Add images to order items
      if (response['order_items'] != null) {
        final items = response['order_items'] as List;
        for (var item in items) {
          final productId = item['product_id'];
          if (productId != null && productImages.containsKey(productId)) {
            item['products'] = {'primary_image': productImages[productId]};
          }
        }
      }

      // Fetch rider info if rider_id exists
      if (response['deliveries'] != null) {
        print('=== Checking Rider Info ===');
        print('Deliveries data: ${response['deliveries']}');
        
        final deliveries = response['deliveries'];
        final riderId = deliveries is List && deliveries.isNotEmpty 
            ? deliveries[0]['rider_id'] 
            : (deliveries is Map ? deliveries['rider_id'] : null);
        
        print('Rider ID: $riderId');
        
        if (riderId != null) {
          try {
            final riderResponse = await _supabase
                .from('riders')
                .select('first_name, last_name, phone_number')
                .eq('rider_id', riderId)
                .maybeSingle();
            
            print('Rider response: $riderResponse');
            
            if (riderResponse != null) {
              // Combine first_name and last_name
              final firstName = riderResponse['first_name'] ?? '';
              final lastName = riderResponse['last_name'] ?? '';
              final fullName = '$firstName $lastName'.trim();
              final phoneNumber = riderResponse['phone_number'];
              
              print('Rider full name: $fullName, phone: $phoneNumber');
              
              // Add rider info to response with normalized structure
              final riderInfo = {
                'name': fullName.isNotEmpty ? fullName : 'N/A',
                'contact_number': phoneNumber,
              };
              
              if (response['deliveries'] is List) {
                response['deliveries'][0]['riders'] = riderInfo;
              } else if (response['deliveries'] is Map) {
                response['deliveries']['riders'] = riderInfo;
              }
              print('Rider info added successfully');
            }
          } catch (e) {
            print('Could not fetch rider info: $e');
          }
        } else {
          print('No rider_id found');
        }
      } else {
        print('No deliveries data');
      }

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
