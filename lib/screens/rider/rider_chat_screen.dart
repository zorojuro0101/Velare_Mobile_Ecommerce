import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../../services/rider_chat_service.dart';
import '../../services/auth_service.dart';
import '../../utils/snackbar_helper.dart';
import 'package:intl/intl.dart';

import '../../utils/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
class RiderChatScreen extends StatefulWidget {
  final VoidCallback? onMessagesRead;

  const RiderChatScreen({super.key, this.onMessagesRead});

  @override
  State<RiderChatScreen> createState() => _RiderChatScreenState();
}

class _RiderChatScreenState extends State<RiderChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final RiderChatService _chatService = RiderChatService();
  final ScrollController _messagesScrollController = ScrollController();

  late TabController _tabController;
  List<Map<String, dynamic>> _buyerConversations = [];
  List<Map<String, dynamic>> _sellerConversations = [];
  List<Map<String, dynamic>> _filteredBuyerConversations = [];
  List<Map<String, dynamic>> _filteredSellerConversations = [];
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _selectedConversation;
  bool _isLoadingConversations = true;
  bool _isLoadingMessages = false;
  bool _isSendingMessage = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConversations();
    });
    _searchController.addListener(_filterConversations);
    // Refresh conversations every 10 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadConversations();
      if (_selectedConversation != null) {
        _loadMessages();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _messageController.dispose();
    _messagesScrollController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    try {
      final userId = AuthService().currentUserId;

      if (userId == null) {
        print('❌ RiderChatScreen - User ID is null');
        if (mounted) {
          setState(() => _isLoadingConversations = false);
        }
        return;
      }

      print('🔍 RiderChatScreen - Loading conversations for userId: $userId');
      final conversations = await _chatService.getRiderConversations(userId);
      print(
        '📊 RiderChatScreen - Received: buyers=${conversations['buyers']?.length ?? 0}, sellers=${conversations['sellers']?.length ?? 0}',
      );

      if (mounted) {
        setState(() {
          _buyerConversations = conversations['buyers'] ?? [];
          _sellerConversations = conversations['sellers'] ?? [];
          _filteredBuyerConversations = _buyerConversations;
          _filteredSellerConversations = _sellerConversations;
          _isLoadingConversations = false;
        });
        print('✅ RiderChatScreen - State updated successfully');
      }
    } catch (e, stackTrace) {
      print('❌ RiderChatScreen - Error loading conversations: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _isLoadingConversations = false);
      }
    }
  }

  void _filterConversations() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredBuyerConversations = _buyerConversations;
        _filteredSellerConversations = _sellerConversations;
      } else {
        _filteredBuyerConversations = _buyerConversations.where((conv) {
          final name = (conv['contact_name'] ?? '').toLowerCase();
          final context = (conv['context_message'] ?? '').toLowerCase();
          return name.contains(query) || context.contains(query);
        }).toList();
        _filteredSellerConversations = _sellerConversations.where((conv) {
          final name = (conv['contact_name'] ?? '').toLowerCase();
          final context = (conv['context_message'] ?? '').toLowerCase();
          return name.contains(query) || context.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadMessages() async {
    if (_selectedConversation == null) return;

    setState(() => _isLoadingMessages = true);

    try {
      final messages = await _chatService.getMessages(
        buyerId: _selectedConversation!['buyer_id'],
        sellerId: _selectedConversation!['seller_id'],
      );

      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoadingMessages = false;
        });

        // Notify parent to update badge
        widget.onMessagesRead?.call();

        // Scroll to bottom
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_messagesScrollController.hasClients) {
            _messagesScrollController.animateTo(
              _messagesScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      print('❌ Error loading messages: $e');
      if (mounted) {
        setState(() => _isLoadingMessages = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty ||
        _selectedConversation == null) {
      return;
    }

    final message = _messageController.text.trim();
    _messageController.clear();

    setState(() => _isSendingMessage = true);

    try {
      await _chatService.sendMessage(
        buyerId: _selectedConversation!['buyer_id'],
        sellerId: _selectedConversation!['seller_id'],
        message: message,
      );

      // Reload messages
      await _loadMessages();
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to send message');
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingMessage = false);
      }
    }
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';

    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inSeconds < 60) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d';
      } else {
        return DateFormat('MMM d').format(dateTime);
      }
    } catch (e) {
      return '';
    }
  }

  String _formatMessageTime(String? timestamp) {
    if (timestamp == null) return '';

    try {
      final dateTime = DateTime.parse(timestamp);
      return DateFormat('h:mm a').format(dateTime);
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    // If conversation is selected, show full chat screen
    if (_selectedConversation != null) {
      return _buildFullChatScreen();
    }

    // Otherwise show conversations list with tabs
    return SafeArea(child: _buildConversationsList());
  }

  Widget _buildFullChatScreen() {
    return Scaffold(
      backgroundColor: AppColors.surface(context),
      appBar: AppBar(
        backgroundColor: AppColors.surface(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.onSurface(context)),
          onPressed: () {
            setState(() {
              _selectedConversation = null;
              _messages = [];
            });
          },
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18.r,
              backgroundColor: AppColors.border(context),
              child:
                  _selectedConversation!['contact_avatar'] != null &&
                      _selectedConversation!['contact_avatar']
                          .toString()
                          .isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        _selectedConversation!['contact_avatar'],
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback to initial on error
                          return Center(
                            child: Text(
                              (_selectedConversation!['contact_name'] ?? 'C')[0]
                                  .toUpperCase(),
                              style: GoogleFonts.goudyBookletter1911(
                                color: AppColors.textBody(context),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  : Text(
                      (_selectedConversation!['contact_name'] ?? 'C')[0]
                          .toUpperCase(),
                      style: GoogleFonts.goudyBookletter1911(
                        color: AppColors.textBody(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedConversation!['contact_name'] ?? 'Unknown',
                    style: GoogleFonts.goudyBookletter1911(
                      color: AppColors.onSurface(context),
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _selectedConversation!['context_message'] ?? '',
                    style: GoogleFonts.goudyBookletter1911(
                      color: AppColors.textMuted(context),
                      fontSize: 12.sp,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages
          Expanded(child: _buildMessagesList()),
          // Input
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildConversationsList() {
    return Scaffold(
      backgroundColor: AppColors.surface(context),
      body: Column(
        children: [
          // Header with search
          Container(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0.h),
            color: AppColors.surface(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chats',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface(context),
                  ),
                ),
                SizedBox(height: 12.h),
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant(context),
                    borderRadius: BorderRadius.circular(5.r),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.goudyBookletter1911(color: AppColors.onSurface(context)),
                    decoration: InputDecoration(
                      hintText: 'Search',
                      hintStyle: GoogleFonts.goudyBookletter1911(
                        color: AppColors.textFaint(context),
                      ),
                      prefixIcon: Icon(Icons.search, color: AppColors.textMuted(context)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                // Tabs
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.onSurface(context),
                  unselectedLabelColor: AppColors.textMuted(context),
                  indicatorColor: AppColors.onSurface(context),
                  labelStyle: GoogleFonts.playfairDisplay(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: GoogleFonts.playfairDisplay(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.normal,
                  ),
                  tabs: const [
                    Tab(text: 'Buyers'),
                    Tab(text: 'Sellers'),
                  ],
                ),
              ],
            ),
          ),

          // Conversations List
          Expanded(
            child: Container(
              color: AppColors.surface(context),
              child: _isLoadingConversations
                  ? Center(
                      child: CircularProgressIndicator(color: AppColors.onSurface(context)),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        // Buyers Tab
                        _filteredBuyerConversations.isEmpty
                            ? _buildEmptyConversations('buyers')
                            : RefreshIndicator(
                                onRefresh: _loadConversations,
                                color: AppColors.onSurface(context),
                                child: ListView.builder(
                                  itemCount: _filteredBuyerConversations.length,
                                  itemBuilder: (context, index) {
                                    return _buildConversationItem(
                                      conversation:
                                          _filteredBuyerConversations[index],
                                    );
                                  },
                                ),
                              ),
                        // Sellers Tab
                        _filteredSellerConversations.isEmpty
                            ? _buildEmptyConversations('sellers')
                            : RefreshIndicator(
                                onRefresh: _loadConversations,
                                color: AppColors.onSurface(context),
                                child: ListView.builder(
                                  itemCount:
                                      _filteredSellerConversations.length,
                                  itemBuilder: (context, index) {
                                    return _buildConversationItem(
                                      conversation:
                                          _filteredSellerConversations[index],
                                    );
                                  },
                                ),
                              ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyConversations(String type) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64.r, color: AppColors.textFaint(context)),
            SizedBox(height: 16.h),
            Text(
              'No $type yet',
              style: GoogleFonts.goudyBookletter1911(
                fontSize: 18.sp,
                color: AppColors.textMuted(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Accept deliveries to start chatting',
              style: GoogleFonts.goudyBookletter1911(
                fontSize: 14.sp,
                color: AppColors.textFaint(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationItem({required Map<String, dynamic> conversation}) {
    final contactName = conversation['contact_name'] ?? 'Unknown';
    final contextMessage = conversation['context_message'] ?? '';
    final lastMessage = conversation['last_message'] ?? '';
    final time = _formatTime(conversation['last_message_time']);
    final unreadCount = conversation['unread_count'] ?? 0;
    final contactAvatar = conversation['contact_avatar'];

    return Material(
      color: AppColors.surface(context),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedConversation = conversation;
          });
          _loadMessages();
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            border: Border(
              bottom: BorderSide(color: AppColors.surfaceVariant2(context), width: 0.5),
            ),
          ),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 28.r,
                backgroundColor: AppColors.border(context),
                child:
                    contactAvatar != null && contactAvatar.toString().isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          contactAvatar,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback to initial on error
                            return Center(
                              child: Text(
                                contactName.isNotEmpty
                                    ? contactName[0].toUpperCase()
                                    : 'C',
                                style: GoogleFonts.goudyBookletter1911(
                                  fontSize: 20.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textBody(context),
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    : Text(
                        contactName.isNotEmpty
                            ? contactName[0].toUpperCase()
                            : 'C',
                        style: GoogleFonts.goudyBookletter1911(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textBody(context),
                        ),
                      ),
              ),

              SizedBox(width: 12.w),

              // Conversation Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            contactName,
                            style: GoogleFonts.goudyBookletter1911(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurface(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (time.isNotEmpty)
                          Text(
                            time,
                            style: GoogleFonts.goudyBookletter1911(
                              fontSize: 12.sp,
                              color: unreadCount > 0
                                  ? AppColors.onSurface(context)
                                  : AppColors.textMuted(context),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lastMessage,
                            style: GoogleFonts.goudyBookletter1911(
                              fontSize: 14.sp,
                              color: unreadCount > 0
                                  ? AppColors.onSurface(context)
                                  : AppColors.textMuted(context),
                              fontWeight: unreadCount > 0
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unreadCount > 0) ...[
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 2.h,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xFF0084FF),
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            child: Center(
                              child: Text(
                                unreadCount.toString(),
                                style: GoogleFonts.goudyBookletter1911(
                                  fontSize: 11.sp,
                                  color: AppColors.surface(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      contextMessage,
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 12.sp,
                        color: AppColors.textMuted(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_isLoadingMessages) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.onSurface(context)),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_outlined, size: 64.r, color: AppColors.textFaint(context)),
            SizedBox(height: 16.h),
            Text(
              'No messages yet',
              style: GoogleFonts.goudyBookletter1911(
                fontSize: 16.sp,
                color: AppColors.textMuted(context),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Start the conversation',
              style: GoogleFonts.goudyBookletter1911(
                fontSize: 14.sp,
                color: AppColors.textFaint(context),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      color: AppColors.surface(context),
      child: ListView.builder(
        controller: _messagesScrollController,
        padding: EdgeInsets.all(16.w),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];
          final isSent = message['sender_type'] == 'rider';
          return _buildMessageBubble(
            message: message['message_text'] ?? '',
            isSent: isSent,
            time: _formatMessageTime(message['created_at']),
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble({
    required String message,
    required bool isSent,
    required String time,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        mainAxisAlignment: isSent
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isSent) ...[
            CircleAvatar(
              radius: 12.r,
              backgroundColor: AppColors.border(context),
              child: Icon(Icons.person, size: 14.r, color: AppColors.textMuted(context)),
            ),
            SizedBox(width: 8.w),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isSent
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    color: isSent ? const Color(0xFF0084FF) : AppColors.surfaceVariant2(context),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(5.r),
                      topRight: Radius.circular(5.r),
                      bottomLeft: Radius.circular(isSent ? 5 : 2),
                      bottomRight: Radius.circular(isSent ? 2 : 5),
                    ),
                  ),
                  child: Text(
                    message,
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 15.sp,
                      color: isSent ? AppColors.surface(context) : AppColors.onSurfaceStrong(context),
                      height: 1.3,
                    ),
                  ),
                ),
                SizedBox(height: 4.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: Text(
                    time,
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 11.sp,
                      color: AppColors.textMuted(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isSent) SizedBox(width: 12.w),
          if (!isSent) SizedBox(width: 40.w),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        border: Border(top: BorderSide(color: AppColors.surfaceVariant2(context))),
      ),
      child: Row(
        children: [
          // Message input
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant(context),
                borderRadius: BorderRadius.circular(5.r),
              ),
              child: TextField(
                controller: _messageController,
                enabled: !_isSendingMessage,
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 15.sp,
                  color: AppColors.onSurface(context),
                ),
                decoration: InputDecoration(
                  hintText: 'Message',
                  hintStyle: GoogleFonts.goudyBookletter1911(
                    color: AppColors.textFaint(context),
                    fontSize: 15.sp,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 10.h,
                  ),
                ),
                maxLines: null,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          // Send button
          Container(
            width: 36.w,
            height: 36.h,
            decoration: BoxDecoration(
              color: _isSendingMessage
                  ? AppColors.textFaint(context)
                  : const Color(0xFF0084FF),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: _isSendingMessage
                  ? SizedBox(
                      width: 18.w,
                      height: 18.h,
                      child: CircularProgressIndicator(
                        color: AppColors.surface(context),
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(Icons.send, color: AppColors.surface(context), size: 18.r),
              onPressed: _isSendingMessage ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
