import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/chat_model.dart';
import '../../services/chat_service.dart';
import '../../utils/image_helper.dart';
import '../../utils/snackbar_helper.dart';

class ChatConversationScreen extends StatefulWidget {
  final int conversationId;
  final String recipientName;
  final String? shopLogo;
  final String? userType;

  const ChatConversationScreen({
    super.key,
    required this.conversationId,
    required this.recipientName,
    this.shopLogo,
    this.userType,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  int? _revealedMessageId;
  RealtimeChannel? _messagesSubscription;
  String? _buyerProfilePicture;

  @override
  void initState() {
    super.initState();
    _loadBuyerProfile();
    _loadMessages();
    _markAsRead();
    _setupRealtimeSubscription();
  }

  void _loadBuyerProfile() async {
    final buyerId = _chatService.getCurrentBuyerId();
    if (buyerId == null) return;

    try {
      final response = await Supabase.instance.client
          .from('buyers')
          .select('profile_image')
          .eq('buyer_id', buyerId)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _buyerProfilePicture = response['profile_image']?.toString();
        });
      }
    } catch (e) {
      print('Error loading buyer profile: $e');
    }
  }

  void _setupRealtimeSubscription() {
    // Subscribe to messages for this conversation
    _messagesSubscription = Supabase.instance.client
        .channel('messages_${widget.conversationId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: widget.conversationId,
          ),
          callback: (payload) {
            print('ChatConversation - New message received: ${payload.newRecord}');
            // Reload messages when new message arrives
            _loadMessages();
            _markAsRead();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _messagesSubscription?.unsubscribe();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadMessages() async {
    try {
      print('ChatConversation - Loading messages for conversation: ${widget.conversationId}');
      final messages = await _chatService.getMessages(widget.conversationId);
      print('ChatConversation - Loaded ${messages.length} messages');
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        print('ChatConversation - State updated with ${_messages.length} messages');
        _scrollToBottom();
      }
    } catch (e) {
      print('ChatConversation - Error loading messages: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _markAsRead() async {
    final userId = _chatService.getCurrentUserId();
    if (userId != null) {
      await _chatService.markMessagesAsRead(widget.conversationId, userId);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0, // Scroll to 0 because reverse: true
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userId = _chatService.getCurrentUserId();
    if (userId == null) {
      print('ChatConversation - No user ID, cannot send message');
      return;
    }

    final messageText = _messageController.text.trim();
    _messageController.clear();

    // Create temporary message for optimistic UI
    final tempMessage = ChatMessage(
      messageId: -DateTime.now().millisecondsSinceEpoch, // Temporary negative ID
      conversationId: widget.conversationId,
      senderId: userId,
      message: messageText,
      isRead: false,
      createdAt: DateTime.now(),
      isSending: true, // Mark as sending
    );

    // Add temporary message to list immediately
    setState(() {
      _messages.add(tempMessage);
    });
    _scrollToBottom();

    try {
      print('ChatConversation - Sending message: $messageText');
      await _chatService.sendMessage(
        conversationId: widget.conversationId,
        senderId: userId,
        message: messageText,
        senderType: 'buyer',
      );
      print('ChatConversation - Message sent successfully, reloading messages...');
      
      // Keep "Sending..." visible for a moment
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Mark own message as read immediately
      await _chatService.markMessagesAsRead(widget.conversationId, userId);
      
      // Reload all messages from database (this will replace temp message with real one)
      _loadMessages();
    } catch (e) {
      print('ChatConversation - Error sending message: $e');
      
      // Remove temporary message on error
      setState(() {
        _messages.removeWhere((m) => m.messageId == tempMessage.messageId);
      });
      
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to send message');
      }
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$hour12:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: widget.shopLogo != null && widget.shopLogo!.isNotEmpty
                  ? Builder(
                      builder: (context) {
                        final imageUrl = ImageHelper.getImageUrl(widget.shopLogo!);
                        if (imageUrl.isEmpty) {
                          return Icon(
                            widget.userType == 'rider' ? Icons.delivery_dining : Icons.store,
                            size: 20,
                            color: Colors.grey[600],
                          );
                        }
                        return ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Icon(Icons.store, size: 20, color: Colors.grey[600]),
                            errorWidget: (context, url, error) => Icon(
                              widget.userType == 'rider' ? Icons.delivery_dining : Icons.store,
                              size: 20,
                              color: Colors.grey[600],
                            ),
                          ),
                        );
                      },
                    )
                  : Icon(
                      widget.userType == 'rider' ? Icons.delivery_dining : Icons.store,
                      size: 20,
                      color: Colors.grey[600],
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.recipientName,
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.black))
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true, // Show recent messages at bottom
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          // Since reverse: true, index 0 is the newest message at bottom
                          final message = _messages[_messages.length - 1 - index];
                          
                          // Show avatar only on the LAST message from each sender in consecutive group
                          // Check if the PREVIOUS message (newer, lower index) is from different sender
                          bool showAvatar = false;
                          
                          if (index == 0) {
                            // This is the newest message (at bottom), always show avatar
                            showAvatar = true;
                          } else {
                            // Check if previous message (newer, shown below this one) is from different sender
                            final prevMessageIndex = _messages.length - index; // Previous in original array (newer)
                            if (prevMessageIndex < _messages.length) {
                              final prevMessage = _messages[prevMessageIndex];
                              // Show avatar if next message is from different sender (this is last in group)
                              showAvatar = message.senderId != prevMessage.senderId;
                            }
                          }
                          
                          return _buildMessageBubble(message, showAvatar);
                        },
                      ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: GoogleFonts.goudyBookletter1911(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Start the conversation',
            style: GoogleFonts.goudyBookletter1911(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool showAvatar) {
    final userId = _chatService.getCurrentUserId();
    final isMe = message.senderId == userId;
    final isRevealed = _revealedMessageId == message.messageId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          // Swipe right for received messages (not mine)
          // Swipe left for sent messages (mine)
          if ((!isMe && details.delta.dx > 0) || (isMe && details.delta.dx < 0)) {
            if (!isRevealed) {
              setState(() {
                _revealedMessageId = message.messageId;
              });
            }
          }
        },
        onHorizontalDragEnd: (details) {
          // Hide timestamp when released
          setState(() {
            _revealedMessageId = null;
          });
        },
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              // Show avatar only for the most recent message from sender
              if (showAvatar)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: widget.shopLogo != null && widget.shopLogo!.isNotEmpty
                      ? Builder(
                          builder: (context) {
                            final imageUrl = ImageHelper.getImageUrl(widget.shopLogo!);
                            if (imageUrl.isEmpty) {
                              return Icon(
                                widget.userType == 'rider' ? Icons.delivery_dining : Icons.store,
                                size: 16,
                                color: Colors.grey[600],
                              );
                            }
                            return ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Icon(Icons.store, size: 16, color: Colors.grey[600]),
                                errorWidget: (context, url, error) => Icon(
                                  widget.userType == 'rider' ? Icons.delivery_dining : Icons.store,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            );
                          },
                        )
                      : Icon(
                          widget.userType == 'rider' ? Icons.delivery_dining : Icons.store,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                )
              else
                const SizedBox(width: 32),
              const SizedBox(width: 8),
            ],
            // Timestamp for received messages (shown on left when swiping right)
            if (!isMe && isRevealed)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  _formatTime(message.createdAt),
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.message,
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 14,
                        color: isMe ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (message.isSending) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isMe ? Colors.white70 : Colors.grey[600]!,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Sending...',
                            style: GoogleFonts.goudyBookletter1911(
                              fontSize: 11,
                              color: isMe ? Colors.white70 : Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Timestamp for sent messages (shown on right when swiping left)
            if (isMe && isRevealed)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  message.isSending ? 'Sending...' : _formatTime(message.createdAt),
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontStyle: message.isSending ? FontStyle.italic : FontStyle.normal,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
            if (isMe) ...[
              const SizedBox(width: 8),
              // Show avatar only for the most recent message from you
              if (showAvatar)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: _buyerProfilePicture != null && _buyerProfilePicture!.isNotEmpty
                      ? Builder(
                          builder: (context) {
                            final imageUrl = ImageHelper.getImageUrl(_buyerProfilePicture!);
                            if (imageUrl.isEmpty) {
                              return Icon(Icons.person, size: 16, color: Colors.grey[600]);
                            }
                            return ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Icon(Icons.person, size: 16, color: Colors.grey[600]),
                                errorWidget: (context, url, error) => Icon(Icons.person, size: 16, color: Colors.grey[600]),
                              ),
                            );
                          },
                        )
                      : Icon(Icons.person, size: 16, color: Colors.grey[600]),
                )
              else
                const SizedBox(width: 32),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: GoogleFonts.goudyBookletter1911(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    border: InputBorder.none,
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
