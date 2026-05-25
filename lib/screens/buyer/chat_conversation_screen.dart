import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/chat_model.dart';
import '../../services/chat_service.dart';
import '../../utils/image_helper.dart';
import '../../utils/snackbar_helper.dart';

import '../../utils/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
class ChatConversationScreen extends StatefulWidget {
  final int conversationId;
  final String recipientName;
  final String? shopLogo;
  final String? userType;
  final String? riderId;

  const ChatConversationScreen({
    super.key,
    required this.conversationId,
    required this.recipientName,
    this.shopLogo,
    this.userType,
    this.riderId,
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
  RealtimeChannel? _deliveriesSubscription;
  String? _buyerProfilePicture;

  /// Resolved rider_id for this conversation (either provided by the caller
  /// or fetched on init). Null for seller conversations.
  String? _riderId;

  /// Cached active state for rider chats. Re-checked whenever messages or
  /// delivery rows change so the input locks the moment the buyer marks
  /// the order as received.
  bool _isChatActive = true;

  @override
  void initState() {
    super.initState();
    _riderId = widget.riderId;
    _loadBuyerProfile();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Resolve rider_id if the caller didn't pass one (e.g. legacy entry
    // points). Seller conversations keep _riderId null.
    if (_riderId == null && widget.userType == 'rider') {
      _riderId = await _chatService.getRiderIdForConversation(
        widget.conversationId,
      );
    }
    await _refreshChatActiveState();
    _loadMessages();
    _markAsRead();
    _setupRealtimeSubscription();
  }

  /// For rider conversations, asks the service whether the rider still has
  /// an ongoing delivery for this buyer. Seller conversations are always
  /// considered active.
  Future<void> _refreshChatActiveState() async {
    if (widget.userType != 'rider' || _riderId == null) {
      if (_isChatActive != true && mounted) {
        setState(() => _isChatActive = true);
      }
      return;
    }
    final buyerId = _chatService.getCurrentBuyerId();
    if (buyerId == null) return;
    try {
      final active = await _chatService.isRiderChatActive(
        buyerId: buyerId,
        riderId: _riderId!,
      );
      if (mounted && _isChatActive != active) {
        setState(() => _isChatActive = active);
      }
    } catch (e) {
      print('ChatConversation - active-state check failed: $e');
    }
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

    // For rider chats, also listen on orders/deliveries so the input locks
    // the moment the buyer (or anyone else) flips order_received to true
    // or the delivery moves out of an ongoing state.
    if (widget.userType == 'rider') {
      _deliveriesSubscription = Supabase.instance.client
          .channel('rider_chat_state_${widget.conversationId}')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'orders',
            callback: (_) => _refreshChatActiveState(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'deliveries',
            callback: (_) => _refreshChatActiveState(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'deliveries',
            callback: (_) => _refreshChatActiveState(),
          )
          .subscribe();
    }
  }

  @override
  void dispose() {
    _messagesSubscription?.unsubscribe();
    _deliveriesSubscription?.unsubscribe();
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
        // Re-check whether the chat is still active after a message refresh
        // (e.g. delivery was just delivered or marked received).
        _refreshChatActiveState();
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

    // Front-line gate: if the rider chat has ended, refuse without even
    // creating an optimistic bubble. The service-level check still runs as
    // a backstop in case the state went stale.
    if (widget.userType == 'rider' && !_isChatActive) {
      SnackBarHelper.showError(
        context,
        'Chat is closed. It will reopen when this rider is assigned to your next order.',
      );
      return;
    }

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

      // The service throws StateError when the rider chat has ended. Show
      // a clearer message and lock the UI immediately.
      if (e is StateError) {
        if (mounted) {
          setState(() => _isChatActive = false);
          SnackBarHelper.showError(
            context,
            'Chat is closed. It will reopen when this rider is assigned to your next order.',
          );
        }
        return;
      }

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
      backgroundColor: AppColors.surfaceVariant(context),
      appBar: AppBar(
        backgroundColor: AppColors.surface(context),
        foregroundColor: AppColors.onSurface(context),
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 36.w,
              height: 36.h,
              decoration: BoxDecoration(
                color: AppColors.border(context),
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
                            color: AppColors.textMuted(context),
                          );
                        }
                        return ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Icon(Icons.store, size: 20.r, color: AppColors.textMuted(context)),
                            errorWidget: (context, url, error) => Icon(
                              widget.userType == 'rider' ? Icons.delivery_dining : Icons.store,
                              size: 20,
                              color: AppColors.textMuted(context),
                            ),
                          ),
                        );
                      },
                    )
                  : Icon(
                      widget.userType == 'rider' ? Icons.delivery_dining : Icons.store,
                      size: 20,
                      color: AppColors.textMuted(context),
                    ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                widget.recipientName,
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 16.sp,
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
                ? Center(child: CircularProgressIndicator(color: AppColors.onSurface(context)))
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true, // Show recent messages at bottom
                        padding: EdgeInsets.all(16.w),
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
          if (widget.userType == 'rider' && !_isChatActive)
            _buildChatEndedBanner()
          else
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
          Icon(Icons.chat_bubble_outline, size: 80.r, color: AppColors.textFaint(context)),
          SizedBox(height: 16.h),
          Text(
            'No messages yet',
            style: GoogleFonts.goudyBookletter1911(fontSize: 16.sp, color: AppColors.textMuted(context)),
          ),
          SizedBox(height: 8.h),
          Text(
            'Start the conversation',
            style: GoogleFonts.goudyBookletter1911(fontSize: 14.sp, color: AppColors.textFaint(context)),
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
      padding: EdgeInsets.only(bottom: 12.h),
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
                  width: 32.w,
                  height: 32.h,
                  decoration: BoxDecoration(
                    color: AppColors.border(context),
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
                                color: AppColors.textMuted(context),
                              );
                            }
                            return ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Icon(Icons.store, size: 16.r, color: AppColors.textMuted(context)),
                                errorWidget: (context, url, error) => Icon(
                                  widget.userType == 'rider' ? Icons.delivery_dining : Icons.store,
                                  size: 16,
                                  color: AppColors.textMuted(context),
                                ),
                              ),
                            );
                          },
                        )
                      : Icon(
                          widget.userType == 'rider' ? Icons.delivery_dining : Icons.store,
                          size: 16,
                          color: AppColors.textMuted(context),
                        ),
                )
              else
                SizedBox(width: 32.w),
              SizedBox(width: 8.w),
            ],
            // Timestamp for received messages (shown on left when swiping right)
            if (!isMe && isRevealed)
              Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: Text(
                  _formatTime(message.createdAt),
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 11.sp,
                    color: AppColors.textMuted(context),
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            Flexible(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: isMe ? AppColors.onSurface(context) : AppColors.surface(context),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16.r),
                    topRight: Radius.circular(16.r),
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
                        fontSize: 14.sp,
                        color: isMe ? AppColors.surface(context) : AppColors.onSurfaceStrong(context),
                      ),
                    ),
                    if (message.isSending) ...[
                      SizedBox(height: 4.h),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 10.w,
                            height: 10.h,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isMe ? Colors.white70 : AppColors.textMuted(context),
                              ),
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            'Sending...',
                            style: GoogleFonts.goudyBookletter1911(
                              fontSize: 11.sp,
                              color: isMe ? Colors.white70 : AppColors.textMuted(context),
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
                padding: EdgeInsets.only(left: 8.w),
                child: Text(
                  message.isSending ? 'Sending...' : _formatTime(message.createdAt),
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 11.sp,
                    color: AppColors.textMuted(context),
                    fontStyle: message.isSending ? FontStyle.italic : FontStyle.normal,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
            if (isMe) ...[
              SizedBox(width: 8.w),
              // Show avatar only for the most recent message from you
              if (showAvatar)
                Container(
                  width: 32.w,
                  height: 32.h,
                  decoration: BoxDecoration(
                    color: AppColors.border(context),
                    shape: BoxShape.circle,
                  ),
                  child: _buyerProfilePicture != null && _buyerProfilePicture!.isNotEmpty
                      ? Builder(
                          builder: (context) {
                            final imageUrl = ImageHelper.getImageUrl(_buyerProfilePicture!);
                            if (imageUrl.isEmpty) {
                              return Icon(Icons.person, size: 16.r, color: AppColors.textMuted(context));
                            }
                            return ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Icon(Icons.person, size: 16.r, color: AppColors.textMuted(context)),
                                errorWidget: (context, url, error) => Icon(Icons.person, size: 16.r, color: AppColors.textMuted(context)),
                              ),
                            );
                          },
                        )
                      : Icon(Icons.person, size: 16.r, color: AppColors.textMuted(context)),
                )
              else
                SizedBox(width: 32.w),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
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
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant(context),
                  borderRadius: BorderRadius.circular(24.r),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: GoogleFonts.goudyBookletter1911(
                      fontSize: 14.sp,
                      color: AppColors.textMuted(context),
                    ),
                    border: InputBorder.none,
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Container(
              decoration: BoxDecoration(
                color: AppColors.onSurface(context),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.send, color: AppColors.surface(context), size: 20.r),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Footer that replaces the message input when a rider chat has ended.
  /// Stays visually consistent with the rider-side banner so both halves of
  /// the conversation read the same closure copy.
  Widget _buildChatEndedBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        border: Border(
          top: BorderSide(color: AppColors.surfaceVariant2(context)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Icon(
              Icons.lock_outline,
              size: 18.r,
              color: AppColors.textMuted(context),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                'Chat ended. It will reopen when this rider is assigned to your next order.',
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 12.sp,
                  color: AppColors.textMuted(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
