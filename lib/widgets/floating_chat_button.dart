import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/chat_service.dart';
import '../models/chat_model.dart';
import '../screens/buyer/chat_conversation_screen.dart';

import '../utils/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
class FloatingChatButton extends StatefulWidget {
  const FloatingChatButton({super.key});

  @override
  State<FloatingChatButton> createState() => _FloatingChatButtonState();
}

class _FloatingChatButtonState extends State<FloatingChatButton> {
  final ChatService _chatService = ChatService();
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    final userId = _chatService.getCurrentUserId();
    final buyerId = _chatService.getCurrentBuyerId();
    if (userId != null && buyerId != null) {
      final count = await _chatService.getUnreadCount(buyerId, userId);
      if (mounted) {
        setState(() => _unreadCount = count);
      }
    }
  }

  void _showChatModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ChatModal(),
    ).then((_) => _loadUnreadCount());
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 80,
      child: GestureDetector(
        onTap: _showChatModal,
        child: Container(
          width: 56.w,
          height: 56.h,
          decoration: BoxDecoration(
            color: AppColors.onSurface(context),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: Icon(
                  Icons.chat_bubble,
                  color: AppColors.surface(context),
                  size: 24.r,
                ),
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: EdgeInsets.all(4.w),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      _unreadCount > 9 ? '9+' : '$_unreadCount',
                      style: GoogleFonts.playfairDisplay(
                        color: AppColors.surface(context),
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatModal extends StatefulWidget {
  const ChatModal({super.key});

  @override
  State<ChatModal> createState() => _ChatModalState();
}

class _ChatModalState extends State<ChatModal> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  Future<List<ChatConversation>>? _conversationsFuture;
  List<ChatConversation> _allConversations = [];
  List<ChatConversation> _filteredConversations = [];

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  void _loadConversations() async {
    final userId = _chatService.getCurrentUserId();
    final buyerId = _chatService.getCurrentBuyerId();
    if (userId != null && buyerId != null) {
      final conversations = await _chatService.getConversations(buyerId, userId);
      setState(() {
        _allConversations = conversations;
        _filteredConversations = conversations;
        _conversationsFuture = Future.value(conversations);
      });
    } else {
      setState(() {
        _conversationsFuture = Future.value([]);
      });
    }
  }

  void _filterConversations(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredConversations = _allConversations;
      } else {
        _filteredConversations = _allConversations.where((conv) {
          final shopName = conv.shopName?.toLowerCase() ?? '';
          final lastMessage = conv.lastMessage?.toLowerCase() ?? '';
          final searchQuery = query.toLowerCase();
          return shopName.contains(searchQuery) || lastMessage.contains(searchQuery);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(),
          Expanded(child: _buildConversationList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border(context))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Messages',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: TextField(
        controller: _searchController,
        onChanged: _filterConversations,
        decoration: InputDecoration(
          hintText: 'Search conversations...',
          hintStyle: GoogleFonts.goudyBookletter1911(color: AppColors.textFaint(context)),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          filled: true,
          fillColor: AppColors.surfaceVariant(context),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        ),
      ),
    );
  }

  Widget _buildConversationList() {
    if (_conversationsFuture == null) {
      return Center(child: CircularProgressIndicator(color: AppColors.onSurface(context)));
    }

    return FutureBuilder<List<ChatConversation>>(
      future: _conversationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: AppColors.onSurface(context)));
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}', style: GoogleFonts.goudyBookletter1911()),
          );
        }
        if (_filteredConversations.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          itemCount: _filteredConversations.length,
          itemBuilder: (context, index) {
            return _buildConversationCard(_filteredConversations[index]);
          },
        );
      },
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
            _searchController.text.isEmpty ? 'No conversations yet' : 'No results found',
            style: GoogleFonts.goudyBookletter1911(fontSize: 18.sp, color: AppColors.textMuted(context)),
          ),
          SizedBox(height: 8.h),
          Text(
            _searchController.text.isEmpty 
                ? 'Start chatting with sellers'
                : 'Try a different search term',
            style: GoogleFonts.goudyBookletter1911(fontSize: 14.sp, color: AppColors.textFaint(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationCard(ChatConversation conversation) {
    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: AppColors.surfaceVariant2(context)),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(12.w),
        leading: CircleAvatar(
          radius: 28.r,
          backgroundColor: AppColors.surfaceVariant2(context),
          backgroundImage: conversation.shopLogo != null
              ? CachedNetworkImageProvider(conversation.shopLogo!)
              : null,
          child: conversation.shopLogo == null
              ? Icon(Icons.store, color: AppColors.textMuted(context))
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                conversation.shopName ?? 'Shop',
                style: GoogleFonts.goudyBookletter1911(
                  fontWeight: FontWeight.w600,
                  fontSize: 15.sp,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (conversation.unreadCount > 0)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: AppColors.onSurface(context),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  '${conversation.unreadCount}',
                  style: GoogleFonts.goudyBookletter1911(
                    color: AppColors.surface(context),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4.h),
            Text(
              conversation.lastMessage ?? 'No messages yet',
              style: GoogleFonts.goudyBookletter1911(
                fontSize: 13.sp,
                color: conversation.unreadCount > 0 ? AppColors.onSurfaceStrong(context) : AppColors.textMuted(context),
                fontWeight: conversation.unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4.h),
            Text(
              _formatTime(conversation.lastMessageAt),
              style: GoogleFonts.goudyBookletter1911(
                fontSize: 11.sp,
                color: AppColors.textFaint(context),
              ),
            ),
          ],
        ),
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatConversationScreen(
                conversationId: conversation.conversationId,
                recipientName: conversation.shopName ?? 'Shop',
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
