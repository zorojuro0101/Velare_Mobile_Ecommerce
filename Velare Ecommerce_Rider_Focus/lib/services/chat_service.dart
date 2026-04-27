import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_model.dart';
import 'auth_service.dart';

class ChatService {
  final _supabase = Supabase.instance.client;
  final _authService = AuthService();

  String? getCurrentUserId() => _authService.currentUserId;

  String? getCurrentBuyerId() =>
      _authService.currentBuyerId; // Add method to get buyer_id

  Future<ChatConversation?> getOrCreateConversation({
    required String buyerId,
    required String sellerId,
  }) async {
    try {
      print('=== ChatService - getOrCreateConversation START ===');
      print('ChatService - buyerId: $buyerId (type: ${buyerId.runtimeType})');
      print(
        'ChatService - sellerId: $sellerId (type: ${sellerId.runtimeType})',
      );

      // Check if conversation exists
      print('ChatService - Checking for existing conversation...');
      final existing = await _supabase
          .from('conversations')
          .select()
          .eq('buyer_id', buyerId)
          .eq('seller_id', sellerId)
          .maybeSingle();

      print('ChatService - Existing conversation: $existing');

      if (existing != null) {
        print('ChatService - Found existing conversation');
        return ChatConversation.fromJson(existing);
      }

      // Create new conversation
      print('ChatService - Creating new conversation...');
      print('ChatService - Using buyer_id from buyers table: $buyerId');
      final response = await _supabase
          .from('conversations')
          .insert({'buyer_id': buyerId, 'seller_id': sellerId})
          .select()
          .single();

      print('ChatService - New conversation created: $response');
      return ChatConversation.fromJson(response);
    } catch (e, stackTrace) {
      print('=== ChatService - ERROR ===');
      print('Error: $e');
      print('Stack: $stackTrace');
      throw Exception('Failed to get/create conversation: $e');
    }
  }

  Future<List<ChatConversation>> getConversations(
    String buyerId,
    String userId,
  ) async {
    try {
      print(
        'ChatService - getConversations called for buyerId: $buyerId, userId: $userId',
      );

      // Join with sellers and users tables to get seller information
      final response = await _supabase
          .from('conversations')
          .select('''
            *,
            sellers!conversations_seller_id_fkey(
              seller_id,
              shop_name,
              users!sellers_user_id_fkey(
                user_id,
                email
              )
            )
          ''')
          .or('buyer_id.eq.$buyerId,seller_id.eq.$buyerId')
          .order('last_message_at', ascending: false);

      print('ChatService - Found ${(response as List).length} conversations');

      final conversations = <ChatConversation>[];

      for (var item in response as List) {
        try {
          print('ChatService - Processing conversation item: $item');

          // Extract seller information from the join
          String? sellerName;
          String? shopName;

          if (item['sellers'] != null) {
            final sellerData = item['sellers'];
            print('ChatService - Seller data: $sellerData');
            shopName = sellerData['shop_name']?.toString();

            if (sellerData['users'] != null) {
              sellerName = sellerData['users']['email']?.toString();
              print(
                'ChatService - Extracted seller name: $sellerName, shop name: $shopName',
              );
            }
          } else {
            print('ChatService - No seller data in join');
          }

          final conversation = ChatConversation.fromJson(item);

          // Calculate actual unread count (messages from others that are unread)
          // Use userId to compare against sender_id in messages table
          final unreadResponse = await _supabase
              .from('messages')
              .select('message_id')
              .eq('conversation_id', conversation.conversationId)
              .eq('is_read', false)
              .neq(
                'sender_id',
                userId,
              ); // Compare against user_id, not buyer_id

          final actualUnreadCount = (unreadResponse as List).length;

          print(
            'ChatService - Conversation ${conversation.conversationId}: $actualUnreadCount unread messages, seller: $sellerName',
          );

          // Create new conversation with correct unread count and seller info
          final updatedConversation = ChatConversation(
            conversationId: conversation.conversationId,
            buyerId: conversation.buyerId,
            sellerId: conversation.sellerId,
            lastMessage: conversation.lastMessage,
            lastMessageAt: conversation.lastMessageAt,
            unreadCount: actualUnreadCount, // Use calculated count
            sellerName: sellerName ?? conversation.sellerName,
            shopName: shopName ?? conversation.shopName,
            shopLogo: conversation.shopLogo,
            buyerName: conversation.buyerName,
          );

          conversations.add(updatedConversation);
        } catch (e) {
          print('ChatService - Error parsing conversation: $e');
        }
      }

      return conversations;
    } catch (e) {
      print('ChatService - Error in getConversations: $e');
      return [];
    }
  }

  Future<List<ChatMessage>> getMessages(int conversationId) async {
    try {
      final response = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((item) => ChatMessage.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Failed to load messages: $e');
    }
  }

  Future<void> sendMessage({
    required int conversationId,
    required String senderId,
    required String message,
    String senderType = 'buyer', // Add sender_type parameter with default
  }) async {
    try {
      print('ChatService - sendMessage called');
      print('ChatService - conversationId: $conversationId');
      print('ChatService - senderId: $senderId');
      print('ChatService - senderType: $senderType');
      print('ChatService - message: $message');

      // Insert message - use message_text and include sender_type
      print('ChatService - Inserting message...');
      await _supabase.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': senderId,
        'sender_type': senderType, // Add sender_type field
        'message_text': message,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(), // Use local time
      });
      print('ChatService - Message inserted successfully');

      // Update conversation last message
      print('ChatService - Updating conversation...');
      await _supabase
          .from('conversations')
          .update({
            'last_message': message,
            'last_message_at': DateTime.now()
                .toIso8601String(), // Use local time
          })
          .eq('conversation_id', conversationId);
      print('ChatService - Conversation updated successfully');
    } catch (e) {
      print('ChatService - Error in sendMessage: $e');
      throw Exception('Failed to send message: $e');
    }
  }

  Future<void> markMessagesAsRead(int conversationId, String userId) async {
    try {
      await _supabase
          .from('messages')
          .update({'is_read': true})
          .eq('conversation_id', conversationId)
          .neq('sender_id', userId);
    } catch (e) {
      // Handle error silently
    }
  }

  Future<int> getUnreadCount(String buyerId, String userId) async {
    try {
      final conversations = await _supabase
          .from('conversations')
          .select('conversation_id')
          .or('buyer_id.eq.$buyerId,seller_id.eq.$buyerId');

      int totalUnread = 0;
      for (var conv in conversations as List) {
        final unread = await _supabase
            .from('messages')
            .select('message_id')
            .eq('conversation_id', conv['conversation_id'])
            .eq('is_read', false)
            .neq(
              'sender_id',
              userId,
            ); // Use userId to compare against sender_id

        totalUnread += (unread as List).length;
      }

      return totalUnread;
    } catch (e) {
      return 0;
    }
  }

  Stream<List<ChatMessage>> subscribeToMessages(int conversationId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['message_id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map((data) => data.map((item) => ChatMessage.fromJson(item)).toList());
  }

  Future<List<Map<String, dynamic>>> searchSellers(String query) async {
    try {
      print('ChatService - Searching sellers with query: $query');

      // First, try to get all sellers to see what data we have
      final response = await _supabase
          .from('users')
          .select('user_id, email, user_type')
          .eq('user_type', 'seller')
          .ilike('email', '%$query%')
          .limit(20);

      print('ChatService - Search results: ${response.length} sellers found');
      print('ChatService - Results: $response');

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('ChatService - Search error: $e');
      throw Exception('Failed to search sellers: $e');
    }
  }

  // ============================================
  // ============================================
  // RIDER CHAT METHODS (Delivery-based - ONE conversation per delivery)
  // ============================================

  /// Get all conversations for a rider (one per delivery, matching web)
  Future<List<Map<String, dynamic>>> getRiderConversations(
    String userId,
  ) async {
    try {
      print('ChatService - getRiderConversations for userId: $userId');

      // Get rider_id from user_id
      final riderData = await _supabase
          .from('riders')
          .select('rider_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (riderData == null) {
        print('ChatService - No rider found for user_id: $userId');
        return [];
      }

      final riderId = riderData['rider_id'];
      print('ChatService - Rider ID: $riderId');

      // Get deliveries for this rider (matching web query)
      final deliveries = await _supabase
          .from('deliveries')
          .select('''
            order_id,
            delivery_id,
            status,
            delivery_address,
            assigned_at,
            orders!inner(
              order_number,
              created_at,
              buyer_id,
              seller_id,
              buyers(
                buyer_id,
                first_name,
                last_name,
                profile_image,
                phone_number
              ),
              sellers(
                shop_name
              )
            )
          ''')
          .eq('rider_id', riderId)
          .inFilter('status', ['assigned', 'in_transit', 'delivered'])
          .order('assigned_at', ascending: false)
          .limit(50);

      print('ChatService - Found ${(deliveries as List).length} deliveries');

      // Create ONE conversation per delivery (matching web)
      final List<Map<String, dynamic>> conversations = [];

      for (var delivery in deliveries as List) {
        final order = delivery['orders'];
        if (order == null) continue;

        final buyer = order['buyers'];
        final seller = order['sellers'];
        final buyerId = order['buyer_id'];
        final deliveryId = delivery['delivery_id'];

        // Get conversation for this delivery
        final convResponse = await _supabase
            .from('conversations')
            .select('conversation_id, last_message, last_message_at')
            .eq('delivery_id', deliveryId)
            .eq('rider_id', riderId)
            .eq('buyer_id', buyerId)
            .maybeSingle();

        String lastMessage = 'Delivery for Order #${order['order_number']}';
        String? lastMessageTime = order['created_at'];
        int unreadCount = 0;

        if (convResponse != null) {
          lastMessage = convResponse['last_message'] ?? lastMessage;
          lastMessageTime = convResponse['last_message_at'] ?? lastMessageTime;

          // Get unread count
          final unreadData = await _supabase
              .from('messages')
              .select('message_id')
              .eq('conversation_id', convResponse['conversation_id'])
              .eq('sender_type', 'buyer')
              .eq('is_read', false);

          unreadCount = (unreadData as List).length;
        }

        conversations.add({
          'conversation_id': convResponse?['conversation_id'],
          'delivery_id': deliveryId,
          'order_id': delivery['order_id'],
          'order_number': order['order_number'],
          'buyer_id': buyerId,
          'buyer_name': '${buyer['first_name']} ${buyer['last_name']}',
          'buyer_avatar': buyer['profile_image'],
          'buyer_phone': buyer['phone_number'],
          'seller_shop': seller['shop_name'],
          'status': delivery['status'],
          'delivery_address': delivery['delivery_address'],
          'last_message': lastMessage,
          'last_message_time': lastMessageTime,
          'unread_count': unreadCount,
        });
      }

      print(
        'ChatService - Returning ${conversations.length} conversations (delivery-based)',
      );
      return conversations;
    } catch (e, stackTrace) {
      print('ChatService - Error in getRiderConversations: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Get messages for a delivery (delivery-based, matching web)
  Future<List<Map<String, dynamic>>> getRiderMessages(int deliveryId) async {
    try {
      print('ChatService - getRiderMessages for delivery: $deliveryId');

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

      // Get delivery info
      final deliveryResponse = await _supabase
          .from('deliveries')
          .select('''
            delivery_id,
            rider_id,
            orders!inner(
              order_id,
              buyer_id,
              order_number,
              sellers(
                shop_name
              )
            )
          ''')
          .eq('delivery_id', deliveryId)
          .eq('rider_id', riderId)
          .maybeSingle();

      if (deliveryResponse == null) {
        print('ChatService - Delivery not found');
        return [];
      }

      final order = deliveryResponse['orders'];
      final buyerId = order['buyer_id'];

      // Get or create conversation (delivery-based)
      var convResponse = await _supabase
          .from('conversations')
          .select('conversation_id')
          .eq('delivery_id', deliveryId)
          .eq('rider_id', riderId)
          .eq('buyer_id', buyerId)
          .maybeSingle();

      int? conversationId = convResponse?['conversation_id'];

      if (conversationId == null) {
        // Create new conversation with initial message
        print('ChatService - Creating new delivery-based conversation...');

        final seller = order['sellers'];
        final initialMessage =
            "Hi! I'm your rider for Order #${order['order_number']} from ${seller['shop_name']}. I'll keep you updated on your delivery.";

        final newConv = await _supabase
            .from('conversations')
            .insert({
              'buyer_id': buyerId,
              'rider_id': riderId,
              'delivery_id': deliveryId, // ✅ Include delivery_id
              'last_message': initialMessage,
              'last_message_at': DateTime.now().toIso8601String(),
            })
            .select('conversation_id')
            .single();

        conversationId = newConv['conversation_id'];

        // Insert initial message
        await _supabase.from('messages').insert({
          'conversation_id': conversationId,
          'sender_id': userId,
          'sender_type': 'rider',
          'message_text': initialMessage,
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // Get all messages
      final messages = await _supabase
          .from('messages')
          .select('*')
          .eq('conversation_id', conversationId!)
          .order('created_at', ascending: true);

      print('ChatService - Found ${(messages as List).length} messages');
      return (messages as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('ChatService - Error in getRiderMessages: $e');
      return [];
    }
  }

  /// Send a message to buyer (delivery-based, matching web)
  Future<Map<String, dynamic>?> sendRiderMessage({
    required int deliveryId,
    required String riderId,
    required String message,
  }) async {
    try {
      print('ChatService - sendRiderMessage');
      print('  delivery_id: $deliveryId');
      print('  rider_id: $riderId');
      print('  message: $message');

      final userId = _authService.currentUserId;
      if (userId == null) return null;

      // Get delivery info
      final deliveryResponse = await _supabase
          .from('deliveries')
          .select('''
            delivery_id,
            orders!inner(
              buyer_id
            )
          ''')
          .eq('delivery_id', deliveryId)
          .eq('rider_id', riderId)
          .maybeSingle();

      if (deliveryResponse == null) return null;

      final buyerId = deliveryResponse['orders']['buyer_id'];

      // Get or create conversation (delivery-based)
      var convResponse = await _supabase
          .from('conversations')
          .select('conversation_id')
          .eq('delivery_id', deliveryId)
          .eq('rider_id', riderId)
          .eq('buyer_id', buyerId)
          .maybeSingle();

      int conversationId;

      if (convResponse == null) {
        // Create new conversation
        final newConv = await _supabase
            .from('conversations')
            .insert({
              'buyer_id': buyerId,
              'rider_id': riderId,
              'delivery_id': deliveryId, // ✅ Include delivery_id
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

      print('ChatService - Message sent successfully');
      return response;
    } catch (e) {
      print('ChatService - Error in sendRiderMessage: $e');
      return null;
    }
  }

  /// Mark messages as read for a delivery (delivery-based, matching web)
  Future<void> markRiderMessagesAsRead(int deliveryId, String userId) async {
    try {
      // Get rider_id
      final riderData = await _supabase
          .from('riders')
          .select('rider_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (riderData == null) return;

      final riderId = riderData['rider_id'];

      // Get conversation_id (delivery-based)
      final convResponse = await _supabase
          .from('conversations')
          .select('conversation_id')
          .eq('delivery_id', deliveryId)
          .eq('rider_id', riderId)
          .maybeSingle();

      if (convResponse == null) return;

      final conversationId = convResponse['conversation_id'];

      await _supabase
          .from('messages')
          .update({'is_read': true})
          .eq('conversation_id', conversationId)
          .eq('sender_type', 'buyer')
          .eq('is_read', false);

      print('ChatService - Marked messages as read');
    } catch (e) {
      print('ChatService - Error marking messages as read: $e');
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
          .select('conversation_id')
          .eq('rider_id', riderId);

      int totalUnread = 0;
      for (var conv in conversations as List) {
        final unread = await _supabase
            .from('messages')
            .select('message_id')
            .eq('conversation_id', conv['conversation_id'])
            .eq('sender_type', 'buyer')
            .eq('is_read', false);

        totalUnread += (unread as List).length;
      }

      return totalUnread;
    } catch (e) {
      print('ChatService - Error getting unread count: $e');
      return 0;
    }
  }
}
