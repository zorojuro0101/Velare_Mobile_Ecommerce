import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import '../utils/image_helper.dart';

class RiderChatService {
  final _supabase = Supabase.instance.client;
  final _authService = AuthService();

  /// Get all conversations for a rider (grouped by buyer AND seller, matching web)
  Future<Map<String, List<Map<String, dynamic>>>> getRiderConversations(
    String userId,
  ) async {
    try {
      print('RiderChatService - getRiderConversations for userId: $userId');

      // Get rider_id from user_id
      final riderData = await _supabase
          .from('riders')
          .select('rider_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (riderData == null) {
        print('RiderChatService - No rider found for user_id: $userId');
        return {'buyers': [], 'sellers': []};
      }

      final riderId = riderData['rider_id'];
      print('RiderChatService - Rider ID: $riderId');

      // Get deliveries for this rider. We pull `order_received` so we can
      // tell the difference between a delivered order that the buyer has
      // already confirmed (chat ends) and one that's still awaiting
      // confirmation (chat stays open).
      final deliveries = await _supabase
          .from('deliveries')
          .select('''
            delivery_id,
            order_id,
            status,
            delivery_address,
            assigned_at,
            delivered_at,
            orders!inner(
              order_number,
              buyer_id,
              seller_id,
              created_at,
              order_received,
              sellers(
                seller_id,
                shop_name,
                first_name,
                last_name,
                shop_logo,
                phone_number
              )
            )
          ''')
          .eq('rider_id', riderId)
          .inFilter('status', ['assigned', 'in_transit', 'delivered'])
          .order('assigned_at', ascending: false);

      print(
        'RiderChatService - Found ${(deliveries as List).length} deliveries',
      );

      // Group deliveries by buyer_id AND seller_id
      final Map<int, Map<String, dynamic>> buyersMap = {};
      final Map<int, Map<String, dynamic>> sellersMap = {};

      for (var delivery in deliveries as List) {
        final order = delivery['orders'];
        if (order == null) continue;

        final buyerId = order['buyer_id'];
        final sellerId = order['seller_id'];
        final status = delivery['status'];
        final orderReceived = order['order_received'] == true;

        // A buyer's chat is "ongoing" while the rider still owes them
        // something — either still in transit, or delivered but the buyer
        // hasn't confirmed receipt yet. Once `order_received` flips to true,
        // the conversation for that order is over.
        final isOngoingForBuyer =
            status == 'assigned' ||
            status == 'in_transit' ||
            (status == 'delivered' && !orderReceived);

        // Seller chat is open during the pickup phase only.
        final isOngoingForSeller =
            status == 'assigned' || status == 'in_transit';

        // Group by buyer
        if (buyerId != null) {
          if (!buyersMap.containsKey(buyerId)) {
            buyersMap[buyerId] = {
              'buyer_id': buyerId,
              'deliveries': <Map<String, dynamic>>[],
              'active_deliveries': <Map<String, dynamic>>[],
              'last_activity': delivery['assigned_at'],
            };
          }

          final deliveryInfo = {
            'delivery_id': delivery['delivery_id'],
            'order_number': order['order_number'],
            'shop_name': order['sellers']?['shop_name'],
            'status': status,
            'order_received': orderReceived,
            'address': delivery['delivery_address'],
            'delivered_at': delivery['delivered_at'],
          };

          (buyersMap[buyerId]!['deliveries'] as List).add(deliveryInfo);

          if (isOngoingForBuyer) {
            (buyersMap[buyerId]!['active_deliveries'] as List).add(
              deliveryInfo,
            );
          }
        }

        // Group by seller
        if (sellerId != null) {
          if (!sellersMap.containsKey(sellerId)) {
            sellersMap[sellerId] = {
              'seller_id': sellerId,
              'seller_info': order['sellers'],
              'deliveries': <Map<String, dynamic>>[],
              'active_deliveries': <Map<String, dynamic>>[],
              'last_activity': delivery['assigned_at'],
            };
          }

          final deliveryInfo = {
            'delivery_id': delivery['delivery_id'],
            'order_number': order['order_number'],
            'status': status,
            'order_received': orderReceived,
            'address': delivery['delivery_address'],
            'delivered_at': delivery['delivered_at'],
          };

          (sellersMap[sellerId]!['deliveries'] as List).add(deliveryInfo);

          if (isOngoingForSeller) {
            (sellersMap[sellerId]!['active_deliveries'] as List).add(
              deliveryInfo,
            );
          }
        }
      }

      print(
        'RiderChatService - Found ${buyersMap.length} unique buyers, ${sellersMap.length} unique sellers',
      );

      // Get buyer conversations
      final List<Map<String, dynamic>> buyerConversations = [];
      for (var entry in buyersMap.entries) {
        final buyerId = entry.key;
        final buyerData = entry.value;

        try {
          print('🔍 Fetching buyer info for buyer_id: $buyerId');
          // Get buyer info
          final buyerResponse = await _supabase
              .from('buyers')
              .select(
                'buyer_id, first_name, last_name, profile_image, phone_number',
              )
              .eq('buyer_id', buyerId)
              .single(); // Changed from .maybeSingle() to .single()

          print(
            '✅ Got buyer: ${buyerResponse['first_name']} ${buyerResponse['last_name']}',
          );

          // Check if conversation exists (get the most recent one if multiple exist)
          final convResponse = await _supabase
              .from('conversations')
              .select(
                'conversation_id, last_message, last_message_at, rider_unread_count',
              )
              .eq('rider_id', riderId)
              .eq('buyer_id', buyerId)
              .isFilter('seller_id', null)
              .order('last_message_at', ascending: false)
              .limit(1)
              .maybeSingle();

          String lastMessage = 'Start conversation';
          String? lastMessageTime = buyerData['last_activity'];
          int unreadCount = 0;

          if (convResponse != null) {
            lastMessage = convResponse['last_message'] ?? 'Start conversation';
            lastMessageTime =
                convResponse['last_message_at'] ?? buyerData['last_activity'];
            unreadCount = convResponse['rider_unread_count'] ?? 0;
          }

          // Create context message
          String contextMessage;
          final activeDeliveries =
              buyerData['active_deliveries'] as List<Map<String, dynamic>>;
          final allDeliveries =
              buyerData['deliveries'] as List<Map<String, dynamic>>;

          if (activeDeliveries.isNotEmpty) {
            final orderDetails = activeDeliveries
                .map((d) {
                  final emoji = d['status'] == 'assigned' ? '📦' : '🚚';
                  return '$emoji ${d['order_number']}';
                })
                .join(' • ');

            final deliveredCount = allDeliveries
                .where((d) => d['status'] == 'delivered')
                .length;
            contextMessage = deliveredCount > 0
                ? '$orderDetails • ✅ $deliveredCount delivered'
                : orderDetails;
          } else {
            final deliveredDeliveries = allDeliveries
                .where((d) => d['status'] == 'delivered')
                .toList();
            contextMessage = deliveredDeliveries.isNotEmpty
                ? '✅ ${deliveredDeliveries.length} order(s) delivered'
                : 'No active deliveries';
          }

          buyerConversations.add({
            'conversation_id': convResponse?['conversation_id'],
            'contact_id': buyerId,
            'buyer_id': buyerId,
            'contact_name':
                '${buyerResponse['first_name']} ${buyerResponse['last_name']}',
            'contact_avatar': buyerResponse['profile_image'] != null
                ? ImageHelper.getImageUrl(buyerResponse['profile_image'])
                : null,
            'contact_phone': buyerResponse['phone_number'],
            'active_deliveries': activeDeliveries,
            'all_deliveries': allDeliveries,
            // True while the buyer still has at least one delivery that
            // isn't fully `order_received`. Drives both the "Chat ended"
            // pill in the list and the lock on the message input.
            'has_active_orders': activeDeliveries.isNotEmpty,
            'is_chat_ended': activeDeliveries.isEmpty,
            'context_message': contextMessage,
            'last_message': lastMessage,
            'last_message_time': lastMessageTime,
            'unread_count': unreadCount,
            'contact_type': 'buyer',
          });

          // Debug: Print avatar conversion
          if (buyerResponse['profile_image'] != null) {
            final rawAvatar = buyerResponse['profile_image'];
            final convertedAvatar = ImageHelper.getImageUrl(rawAvatar);
            print('🖼️ Avatar conversion for ${buyerResponse['first_name']}:');
            print('   Raw: $rawAvatar');
            print('   Converted: $convertedAvatar');
          }

          print(
            '✅ Added buyer conversation for: ${buyerResponse['first_name']}',
          );
        } catch (e) {
          print('❌ Error processing buyer $buyerId: $e');
          continue;
        }
      }

      // Get seller conversations
      final List<Map<String, dynamic>> sellerConversations = [];
      for (var entry in sellersMap.entries) {
        final sellerId = entry.key;
        final sellerData = entry.value;
        final seller = sellerData['seller_info'];

        try {
          print('🔍 Processing seller_id: $sellerId');

          // Check if conversation exists (get the most recent one if multiple exist)
          final convResponse = await _supabase
              .from('conversations')
              .select(
                'conversation_id, last_message, last_message_at, rider_unread_count',
              )
              .eq('rider_id', riderId)
              .eq('seller_id', sellerId)
              .isFilter('buyer_id', null)
              .order('last_message_at', ascending: false)
              .limit(1)
              .maybeSingle();

          String lastMessage = 'Start conversation';
          String? lastMessageTime = sellerData['last_activity'];
          int unreadCount = 0;

          if (convResponse != null) {
            lastMessage = convResponse['last_message'] ?? 'Start conversation';
            lastMessageTime =
                convResponse['last_message_at'] ?? sellerData['last_activity'];
            unreadCount = convResponse['rider_unread_count'] ?? 0;
          }

          // Create context message
          String contextMessage;
          final activeDeliveries =
              sellerData['active_deliveries'] as List<Map<String, dynamic>>;
          final allDeliveries =
              sellerData['deliveries'] as List<Map<String, dynamic>>;

          if (activeDeliveries.isNotEmpty) {
            final orderDetails = activeDeliveries
                .map((d) {
                  final emoji = d['status'] == 'assigned' ? '📦' : '🚚';
                  return '$emoji ${d['order_number']}';
                })
                .join(' • ');

            final deliveredCount = allDeliveries
                .where((d) => d['status'] == 'delivered')
                .length;
            contextMessage = deliveredCount > 0
                ? '$orderDetails • ✅ $deliveredCount delivered'
                : orderDetails;
          } else {
            final deliveredDeliveries = allDeliveries
                .where((d) => d['status'] == 'delivered')
                .toList();
            contextMessage = deliveredDeliveries.isNotEmpty
                ? '✅ ${deliveredDeliveries.length} order(s) delivered'
                : 'No active deliveries';
          }

          sellerConversations.add({
            'conversation_id': convResponse?['conversation_id'],
            'contact_id': sellerId,
            'seller_id': sellerId,
            'contact_name':
                seller['shop_name'] ??
                '${seller['first_name']} ${seller['last_name']}',
            'contact_avatar': seller['shop_logo'] != null
                ? ImageHelper.getImageUrl(seller['shop_logo'])
                : null,
            'contact_phone': seller['phone_number'],
            'active_deliveries': activeDeliveries,
            'all_deliveries': allDeliveries,
            'has_active_orders': activeDeliveries.isNotEmpty,
            'is_chat_ended': activeDeliveries.isEmpty,
            'context_message': contextMessage,
            'last_message': lastMessage,
            'last_message_time': lastMessageTime,
            'unread_count': unreadCount,
            'contact_type': 'seller',
          });

          // Debug: Print avatar conversion
          if (seller['shop_logo'] != null) {
            final rawAvatar = seller['shop_logo'];
            final convertedAvatar = ImageHelper.getImageUrl(rawAvatar);
            print('🖼️ Avatar conversion for ${seller['shop_name']}:');
            print('   Raw: $rawAvatar');
            print('   Converted: $convertedAvatar');
          }

          print('✅ Added seller conversation for: ${seller['shop_name']}');
        } catch (e) {
          print('❌ Error processing seller $sellerId: $e');
          continue;
        }
      }

      // Sort both by last activity
      buyerConversations.sort(
        (a, b) => (b['last_message_time'] ?? '').toString().compareTo(
          (a['last_message_time'] ?? '').toString(),
        ),
      );
      sellerConversations.sort(
        (a, b) => (b['last_message_time'] ?? '').toString().compareTo(
          (a['last_message_time'] ?? '').toString(),
        ),
      );

      print(
        'RiderChatService - Returning ${buyerConversations.length} buyer conversations, ${sellerConversations.length} seller conversations',
      );

      // Debug: Print first conversation from each type
      if (buyerConversations.isNotEmpty) {
        print('📦 Sample buyer conversation: ${buyerConversations.first}');
      }
      if (sellerConversations.isNotEmpty) {
        print('🏪 Sample seller conversation: ${sellerConversations.first}');
      }

      return {'buyers': buyerConversations, 'sellers': sellerConversations};
    } catch (e, stackTrace) {
      print('RiderChatService - Error in getRiderConversations: $e');
      print('Stack trace: $stackTrace');
      return {'buyers': [], 'sellers': []};
    }
  }

  /// Get messages for a buyer or seller (profile-based)
  Future<List<Map<String, dynamic>>> getMessages({
    int? buyerId,
    int? sellerId,
  }) async {
    try {
      if (buyerId == null && sellerId == null) return [];

      final userId = _authService.currentUserId;
      if (userId == null) return [];

      // Get rider_id
      final riderData = await _supabase
          .from('riders')
          .select('rider_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (riderData == null) return [];

      final riderId = riderData['rider_id'];

      // Get conversation (get the most recent one if multiple exist)
      var query = _supabase
          .from('conversations')
          .select('conversation_id')
          .eq('rider_id', riderId);

      if (buyerId != null) {
        query = query.eq('buyer_id', buyerId).isFilter('seller_id', null);
      } else {
        query = query.eq('seller_id', sellerId!).isFilter('buyer_id', null);
      }

      final convResponse = await query
          .order('last_message_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (convResponse == null) {
        // No conversation yet
        return [];
      }

      final conversationId = convResponse['conversation_id'];

      // Get messages
      final messages = await _supabase
          .from('messages')
          .select('*')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true)
          .limit(100);

      // Mark messages as read
      await _supabase
          .from('messages')
          .update({'is_read': true})
          .eq('conversation_id', conversationId)
          .eq('is_read', false)
          .neq('sender_type', 'rider');

      return (messages as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('RiderChatService - Error in getMessages: $e');
      return [];
    }
  }

  /// Send a message to buyer or seller (profile-based).
  ///
  /// Throws a [StateError] if the rider has no active delivery for the given
  /// contact — this enforces the "chat ends when the order is received" rule
  /// at the service layer so the UI can't accidentally bypass it.
  Future<Map<String, dynamic>?> sendMessage({
    int? buyerId,
    int? sellerId,
    required String message,
  }) async {
    try {
      if (buyerId == null && sellerId == null) return null;

      final userId = _authService.currentUserId;
      if (userId == null) return null;

      // Get rider_id
      final riderData = await _supabase
          .from('riders')
          .select('rider_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (riderData == null) return null;

      final riderId = riderData['rider_id'];

      // Guard: only allow sending while there is an ongoing delivery for
      // this contact. Buyers stay reachable until they confirm receipt;
      // sellers only during pickup/in-transit.
      final hasActive = await _hasActiveDelivery(
        riderId: riderId,
        buyerId: buyerId,
        sellerId: sellerId,
      );
      if (!hasActive) {
        throw StateError(
          'Cannot send message: no active delivery for this contact.',
        );
      }

      // Get or create conversation (get the most recent one if multiple exist)
      var query = _supabase
          .from('conversations')
          .select('conversation_id')
          .eq('rider_id', riderId);

      if (buyerId != null) {
        query = query.eq('buyer_id', buyerId).isFilter('seller_id', null);
      } else {
        query = query.eq('seller_id', sellerId!).isFilter('buyer_id', null);
      }

      var convResponse = await query
          .order('last_message_at', ascending: false)
          .limit(1)
          .maybeSingle();

      int conversationId;

      if (convResponse == null) {
        // Create new conversation
        final newConv = await _supabase
            .from('conversations')
            .insert({
              if (buyerId != null) 'buyer_id': buyerId,
              if (sellerId != null) 'seller_id': sellerId,
              'rider_id': riderId,
              'last_message': message,
              'last_message_at': DateTime.now().toIso8601String(),
            })
            .select('conversation_id')
            .single();

        conversationId = newConv['conversation_id'];
      } else {
        conversationId = convResponse['conversation_id'];

        // Update last message
        await _supabase
            .from('conversations')
            .update({
              'last_message': message,
              'last_message_at': DateTime.now().toIso8601String(),
            })
            .eq('conversation_id', conversationId);
      }

      // Insert message
      final response = await _supabase
          .from('messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': userId,
            'sender_type': 'rider',
            'message_text': message,
            'is_read': false,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return response;
    } catch (e) {
      print('RiderChatService - Error in sendMessage: $e');
      return null;
    }
  }

  /// Returns true if the rider has at least one delivery for the given
  /// contact that is still considered "ongoing":
  /// - Buyer: status assigned/in_transit, or delivered + order_received=false.
  /// - Seller: status assigned/in_transit only (pickup window).
  Future<bool> _hasActiveDelivery({
    required dynamic riderId,
    int? buyerId,
    int? sellerId,
  }) async {
    try {
      var query = _supabase
          .from('deliveries')
          .select('status, orders!inner(buyer_id, seller_id, order_received)')
          .eq('rider_id', riderId);

      final rows = await query;
      for (final row in (rows as List)) {
        final status = row['status'];
        final order = row['orders'];
        if (order == null) continue;

        final orderBuyerId = order['buyer_id'];
        final orderSellerId = order['seller_id'];
        final orderReceived = order['order_received'] == true;

        if (buyerId != null && orderBuyerId != buyerId) continue;
        if (sellerId != null && orderSellerId != sellerId) continue;

        if (status == 'assigned' || status == 'in_transit') return true;
        if (buyerId != null && status == 'delivered' && !orderReceived) {
          return true;
        }
      }
      return false;
    } catch (e) {
      print('RiderChatService - _hasActiveDelivery error: $e');
      // Fail closed — if we can't verify, refuse to send.
      return false;
    }
  }

  /// Get unread count for rider
  Future<int> getRiderUnreadCount(String userId) async {
    try {
      // Get rider_id from user_id
      final riderData = await _supabase
          .from('riders')
          .select('rider_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (riderData == null) return 0;

      final riderId = riderData['rider_id'];

      // Get all conversations for this rider
      final conversations = await _supabase
          .from('conversations')
          .select('rider_unread_count')
          .eq('rider_id', riderId);

      int totalUnread = 0;
      for (var conv in conversations as List) {
        totalUnread += (conv['rider_unread_count'] ?? 0) as int;
      }

      return totalUnread;
    } catch (e) {
      print('RiderChatService - Error getting unread count: $e');
      return 0;
    }
  }
}
