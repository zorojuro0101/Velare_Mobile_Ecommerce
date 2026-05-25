import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_model.dart';
import 'auth_service.dart';

class ChatService {
  final _supabase = Supabase.instance.client;
  final _authService = AuthService();

  String? getCurrentUserId() => _authService.currentUserId;
  
  String? getCurrentBuyerId() => _authService.currentBuyerId; // Add method to get buyer_id

  Future<ChatConversation?> getOrCreateConversation({
    required String buyerId,
    required String sellerId,
  }) async {
    try {
      print('=== ChatService - getOrCreateConversation START ===');
      print('ChatService - buyerId: $buyerId (type: ${buyerId.runtimeType})');
      print('ChatService - sellerId: $sellerId (type: ${sellerId.runtimeType})');
      
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
          .insert({
            'buyer_id': buyerId,
            'seller_id': sellerId,
          })
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

  Future<List<ChatConversation>> getConversations(String buyerId, String userId) async {
    try {
      print('ChatService - getConversations called for buyerId: $buyerId, userId: $userId');
      
      // Get all conversations with related data in ONE query using joins
      final response = await _supabase
          .from('conversations')
          .select('''
            *,
            sellers(seller_id, shop_name, shop_logo, user_id, users(email, user_type)),
            riders(rider_id, first_name, last_name, profile_image, user_id)
          ''')
          .or('buyer_id.eq.$buyerId,seller_id.eq.$buyerId')
          .order('last_message_at', ascending: false);

      print('ChatService - Found ${(response as List).length} conversations');

      // Collect all conversation IDs to batch fetch unread counts
      final conversationIds = (response as List).map((item) => item['conversation_id'] as int).toList();
      
      // Batch fetch all unread messages in ONE query
      final unreadMessages = await _supabase
          .from('messages')
          .select('conversation_id, message_id')
          .inFilter('conversation_id', conversationIds)
          .eq('is_read', false)
          .neq('sender_id', userId);
      
      // Create a map of conversation_id -> unread count
      final Map<int, int> unreadCountMap = {};
      for (var msg in unreadMessages as List) {
        final convId = msg['conversation_id'] as int;
        unreadCountMap[convId] = (unreadCountMap[convId] ?? 0) + 1;
      }

      // Batch the rider-active check: collect all rider_ids appearing in
      // this buyer's conversations, then resolve their active state in one
      // query so we don't fan out per row.
      final riderIds = <String>{};
      for (final item in response as List) {
        final r = item['rider_id']?.toString();
        if (r != null && r.isNotEmpty) riderIds.add(r);
      }
      final activeRiderIds = await _activeRiderIdsForBuyer(
        buyerId: buyerId,
        riderIds: riderIds,
      );

      final conversations = <ChatConversation>[];

      for (var item in response as List) {
        try {
          final conversationId = item['conversation_id'] as int;
          final riderId = item['rider_id']?.toString();
          final sellerId = item['seller_id']?.toString();
          
          String? sellerName;
          String? shopName;
          String? shopLogo;
          String? sellerUserType;
          
          // Check if this is a rider conversation
          if (riderId != null && item['riders'] != null) {
            final riderData = item['riders'];
            final firstName = riderData['first_name']?.toString() ?? '';
            final lastName = riderData['last_name']?.toString() ?? '';
            sellerName = '$firstName $lastName'.trim();
            sellerUserType = 'rider';
            shopLogo = riderData['profile_image']?.toString();
          }
          // Check if this is a seller conversation
          else if (sellerId != null && item['sellers'] != null) {
            final sellerData = item['sellers'];
            shopName = sellerData['shop_name']?.toString();
            shopLogo = sellerData['shop_logo']?.toString();
            
            if (sellerData['users'] != null) {
              final userData = sellerData['users'];
              sellerUserType = userData['user_type']?.toString();
              sellerName = userData['email']?.toString();
            }
          }
          
          final conversation = ChatConversation.fromJson(item);
          
          // Get unread count from map (already fetched in batch)
          final actualUnreadCount = unreadCountMap[conversationId] ?? 0;

          // Rider conversations are only "active" while the rider has an
          // ongoing delivery for this buyer. Seller conversations stay open.
          final bool isChatActive = sellerUserType == 'rider'
              ? (riderId != null && activeRiderIds.contains(riderId))
              : true;

          // Create new conversation with correct data
          final updatedConversation = ChatConversation(
            conversationId: conversation.conversationId,
            buyerId: conversation.buyerId,
            sellerId: conversation.sellerId,
            lastMessage: conversation.lastMessage,
            lastMessageAt: conversation.lastMessageAt,
            unreadCount: actualUnreadCount,
            sellerName: sellerName,
            shopName: shopName,
            shopLogo: shopLogo,
            buyerName: conversation.buyerName,
            sellerUserType: sellerUserType,
            isChatActive: isChatActive,
            riderId: riderId,
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

  /// Returns the subset of [riderIds] that still have an ongoing delivery
  /// for [buyerId]. Used to mark rider conversations as active vs. ended.
  Future<Set<String>> _activeRiderIdsForBuyer({
    required String buyerId,
    required Set<String> riderIds,
  }) async {
    if (riderIds.isEmpty) return <String>{};
    try {
      final rows = await _supabase
          .from('deliveries')
          .select(
            'rider_id, status, orders!inner(buyer_id, order_received)',
          )
          .inFilter('rider_id', riderIds.toList())
          .inFilter('status', ['assigned', 'in_transit', 'delivered']);

      final active = <String>{};
      for (final row in (rows as List)) {
        final rid = row['rider_id']?.toString();
        if (rid == null) continue;
        final status = row['status'];
        final order = row['orders'];
        if (order == null) continue;
        if (order['buyer_id']?.toString() != buyerId) continue;

        final orderReceived = order['order_received'] == true;
        final isActive = status == 'assigned' ||
            status == 'in_transit' ||
            (status == 'delivered' && !orderReceived);
        if (isActive) active.add(rid);
      }
      return active;
    } catch (e) {
      print('ChatService - _activeRiderIdsForBuyer error: $e');
      return <String>{};
    }
  }

  /// Returns true if the given rider currently has an ongoing delivery for
  /// [buyerId]. The conversation screen calls this on open and on every
  /// realtime tick so the input locks instantly when the buyer marks the
  /// order as received.
  Future<bool> isRiderChatActive({
    required String buyerId,
    required String riderId,
  }) async {
    final active = await _activeRiderIdsForBuyer(
      buyerId: buyerId,
      riderIds: {riderId},
    );
    return active.contains(riderId);
  }

  /// Resolves the rider_id linked to a given conversation, if any.
  Future<String?> getRiderIdForConversation(int conversationId) async {
    try {
      final row = await _supabase
          .from('conversations')
          .select('rider_id')
          .eq('conversation_id', conversationId)
          .maybeSingle();
      return row?['rider_id']?.toString();
    } catch (e) {
      print('ChatService - getRiderIdForConversation error: $e');
      return null;
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

      // Defence in depth: if this conversation is linked to a rider,
      // refuse to send unless that rider currently has an ongoing
      // delivery for the buyer side of the conversation. Mirrors the
      // gate on the rider screen and keeps the chat closed once the
      // buyer has marked the order as received.
      final convRow = await _supabase
          .from('conversations')
          .select('buyer_id, rider_id')
          .eq('conversation_id', conversationId)
          .maybeSingle();
      final buyerOnConv = convRow?['buyer_id']?.toString();
      final riderOnConv = convRow?['rider_id']?.toString();
      if (riderOnConv != null && buyerOnConv != null) {
        final canChat = await isRiderChatActive(
          buyerId: buyerOnConv,
          riderId: riderOnConv,
        );
        if (!canChat) {
          throw StateError(
            'Chat is closed. The rider has no active delivery for this order.',
          );
        }
      }

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
      await _supabase.from('conversations').update({
        'last_message': message,
        'last_message_at': DateTime.now().toIso8601String(), // Use local time
      }).eq('conversation_id', conversationId);
      print('ChatService - Conversation updated successfully');
    } catch (e) {
      print('ChatService - Error in sendMessage: $e');
      rethrow;
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
      print('=== ChatService getUnreadCount ===');
      print('buyerId: $buyerId, userId: $userId');
      
      final conversations = await _supabase
          .from('conversations')
          .select('conversation_id')
          .or('buyer_id.eq.$buyerId,seller_id.eq.$buyerId');

      print('Found ${(conversations as List).length} conversations');

      int totalUnread = 0;
      for (var conv in conversations as List) {
        final convId = conv['conversation_id'];
        final unread = await _supabase
            .from('messages')
            .select('message_id')
            .eq('conversation_id', convId)
            .eq('is_read', false)
            .neq('sender_id', userId);

        final unreadCount = (unread as List).length;
        print('Conversation $convId: $unreadCount unread messages');
        totalUnread += unreadCount;
      }

      print('Total unread: $totalUnread');
      return totalUnread;
    } catch (e) {
      print('Error in getUnreadCount: $e');
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
}
