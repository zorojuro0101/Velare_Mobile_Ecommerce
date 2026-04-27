class ChatConversation {
  final int conversationId;
  final String buyerId;
  final String sellerId;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final String? sellerName;
  final String? shopName;
  final String? shopLogo;
  final String? buyerName;
  final String? sellerUserType;

  ChatConversation({
    required this.conversationId,
    required this.buyerId,
    required this.sellerId,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.sellerName,
    this.shopName,
    this.shopLogo,
    this.buyerName,
    this.sellerUserType,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      try {
        // Parse and convert to local time
        final dt = DateTime.parse(value.toString());
        return dt.toLocal();
      } catch (e) {
        print('ChatConversation - Error parsing datetime: $value, error: $e');
        return null;
      }
    }

    return ChatConversation(
      conversationId: json['conversation_id'] ?? json['id'] ?? 0,
      buyerId: json['buyer_id']?.toString() ?? '',
      sellerId: json['seller_id']?.toString() ?? '',
      lastMessage: json['last_message']?.toString(),
      lastMessageAt: parseDateTime(json['last_message_at']),
      unreadCount: json['buyer_unread_count'] ?? json['unread_count'] ?? 0,
      sellerName: json['seller_name']?.toString(),
      shopName: json['shop_name']?.toString() ?? json['seller_shop_name']?.toString(),
      shopLogo: json['shop_logo']?.toString(),
      buyerName: json['buyer_name']?.toString(),
      sellerUserType: json['seller_user_type']?.toString(),
    );
  }
}

class ChatMessage {
  final int messageId;
  final int conversationId;
  final String senderId;
  final String message;
  final bool isRead;
  final DateTime createdAt;
  final bool isSending; // Add sending status

  ChatMessage({
    required this.messageId,
    required this.conversationId,
    required this.senderId,
    required this.message,
    this.isRead = false,
    required this.createdAt,
    this.isSending = false, // Default to false
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      try {
        // Parse and convert to local time
        final dt = DateTime.parse(value.toString());
        return dt.toLocal();
      } catch (e) {
        print('ChatMessage - Error parsing datetime: $value, error: $e');
        return DateTime.now();
      }
    }

    return ChatMessage(
      messageId: json['message_id'] ?? json['id'] ?? 0,
      conversationId: json['conversation_id'] ?? 0,
      senderId: json['sender_id']?.toString() ?? '', // Convert to string
      message: json['message_text'] ?? json['message'] ?? '',
      isRead: json['is_read'] == 1 || json['is_read'] == true, // Handle both int and bool
      createdAt: parseDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conversation_id': conversationId,
      'sender_id': senderId,
      'message_text': message, // Changed to message_text
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
