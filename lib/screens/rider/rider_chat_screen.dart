import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../../services/rider_chat_service.dart';
import '../../services/auth_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/snackbar_helper.dart';
import 'delivery_detail_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Rider's chat hub.
///
/// Two big behaviour rules to keep in sync with `chat_conversation_screen.dart`
/// (the buyer side):
///
/// * A conversation is only "open" while the rider has an active delivery
///   for that contact. For buyers, that means a delivery whose status is
///   `assigned`/`in_transit` or `delivered` with `order_received = false`.
///   For sellers, it's the pickup window only — `assigned`/`in_transit`.
///   Past contacts stay in the list but messaging is locked behind a
///   "Chat ended" banner; if the buyer places a new order, the chat
///   reopens automatically.
///
/// * Visuals match the buyer chat (`chat_conversation_screen.dart`): same
///   bubble shapes, swipe-to-reveal timestamps, avatar grouping, gold
///   fallback for missing profile photos.
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
  String? _riderProfileImage;
  int? _revealedMessageId;

  RealtimeChannel? _conversationsSubscription;
  RealtimeChannel? _messagesSubscription;
  int? _activeConversationId;

  /// Brand gold used as the fallback background for avatars without an
  /// uploaded profile image. Keeps the chat list visually consistent with the
  /// rest of the app (icon badges, bottom nav highlight, etc.).
  static const Color _avatarFallbackColor = Color(0xFFD4AF37);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConversations();
      _loadRiderProfile();
      _setupConversationsRealtimeSubscription();
    });
    _searchController.addListener(_filterConversations);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _messageController.dispose();
    _messagesScrollController.dispose();
    _conversationsSubscription?.unsubscribe();
    _messagesSubscription?.unsubscribe();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  Future<void> _loadRiderProfile() async {
    final userId = AuthService().currentUserId;
    if (userId == null) return;
    try {
      final response = await Supabase.instance.client
          .from('riders')
          .select('profile_image')
          .eq('user_id', userId)
          .maybeSingle();
      if (response != null && mounted) {
        setState(() {
          _riderProfileImage = response['profile_image']?.toString();
        });
      }
    } catch (e) {
      debugPrint('RiderChatScreen - Error loading rider profile: $e');
    }
  }

  Future<void> _loadConversations() async {
    try {
      final userId = AuthService().currentUserId;
      if (userId == null) {
        if (mounted) setState(() => _isLoadingConversations = false);
        return;
      }

      final conversations = await _chatService.getRiderConversations(userId);

      if (!mounted) return;
      setState(() {
        _buyerConversations = conversations['buyers'] ?? [];
        _sellerConversations = conversations['sellers'] ?? [];
        _isLoadingConversations = false;
      });
      _filterConversations();

      // Refresh the open conversation's "ended" state if the underlying
      // delivery flipped while we were inside the thread.
      if (_selectedConversation != null) {
        final updated = _findUpdatedSelected();
        if (updated != null && mounted) {
          setState(() {
            _selectedConversation = {
              ..._selectedConversation!,
              ...updated,
            };
          });
        }
      }
    } catch (e) {
      debugPrint('RiderChatScreen - Error loading conversations: $e');
      if (mounted) setState(() => _isLoadingConversations = false);
    }
  }

  Map<String, dynamic>? _findUpdatedSelected() {
    if (_selectedConversation == null) return null;
    final list = _selectedConversation!['contact_type'] == 'buyer'
        ? _buyerConversations
        : _sellerConversations;
    for (final c in list) {
      if (c['contact_id'] == _selectedConversation!['contact_id']) return c;
    }
    return null;
  }

  void _filterConversations() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredBuyerConversations = _buyerConversations;
        _filteredSellerConversations = _sellerConversations;
      } else {
        bool matches(Map<String, dynamic> conv) {
          final name = (conv['contact_name'] ?? '').toString().toLowerCase();
          final ctx = (conv['context_message'] ?? '').toString().toLowerCase();
          return name.contains(query) || ctx.contains(query);
        }

        _filteredBuyerConversations = _buyerConversations.where(matches).toList();
        _filteredSellerConversations = _sellerConversations.where(matches).toList();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Realtime
  // ---------------------------------------------------------------------------

  void _setupConversationsRealtimeSubscription() {
    final userId = AuthService().currentUserId;
    if (userId == null) return;

    _conversationsSubscription?.unsubscribe();
    _conversationsSubscription = Supabase.instance.client
        .channel('rider_conversations_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (_) {
            if (mounted) _loadConversations();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          callback: (_) {
            if (mounted) _loadConversations();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'conversations',
          callback: (_) {
            if (mounted) _loadConversations();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'conversations',
          callback: (_) {
            if (mounted) _loadConversations();
          },
        )
        // Order/delivery state changes affect "is_chat_ended", so refresh
        // the list when they update too. We listen to inserts as well: when
        // a fresh delivery is assigned to this rider, the row appears with
        // status='assigned' and we want the list to flip out of "Chat ended"
        // immediately.
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          callback: (_) {
            if (mounted) _loadConversations();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'orders',
          callback: (_) {
            if (mounted) _loadConversations();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'deliveries',
          callback: (_) {
            if (mounted) _loadConversations();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'deliveries',
          callback: (_) {
            if (mounted) _loadConversations();
          },
        )
        .subscribe();
  }

  void _setupMessagesRealtimeSubscription(int conversationId) {
    if (_activeConversationId == conversationId &&
        _messagesSubscription != null) {
      return;
    }
    _messagesSubscription?.unsubscribe();
    _activeConversationId = conversationId;
    _messagesSubscription = Supabase.instance.client
        .channel('rider_messages_$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (_) {
            if (mounted && _selectedConversation != null) {
              _loadMessages(showLoading: false);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (_) {
            if (mounted && _selectedConversation != null) {
              _loadMessages(showLoading: false);
            }
          },
        )
        .subscribe();
  }

  Future<int?> _resolveConversationId() async {
    if (_selectedConversation == null) return null;

    final cached = _selectedConversation!['conversation_id'];
    if (cached != null) return cached as int;

    final userId = AuthService().currentUserId;
    if (userId == null) return null;

    try {
      final riderData = await Supabase.instance.client
          .from('riders')
          .select('rider_id')
          .eq('user_id', userId)
          .maybeSingle();
      if (riderData == null) return null;

      final riderId = riderData['rider_id'];
      final buyerId = _selectedConversation!['buyer_id'];
      final sellerId = _selectedConversation!['seller_id'];

      var query = Supabase.instance.client
          .from('conversations')
          .select('conversation_id')
          .eq('rider_id', riderId);

      if (buyerId != null) {
        query = query.eq('buyer_id', buyerId).isFilter('seller_id', null);
      } else if (sellerId != null) {
        query = query.eq('seller_id', sellerId).isFilter('buyer_id', null);
      } else {
        return null;
      }

      final result = await query
          .order('last_message_at', ascending: false)
          .limit(1)
          .maybeSingle();

      final convId = result?['conversation_id'] as int?;
      if (convId != null && _selectedConversation != null) {
        _selectedConversation!['conversation_id'] = convId;
      }
      return convId;
    } catch (e) {
      debugPrint('RiderChatScreen - Error resolving conversation id: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Messages
  // ---------------------------------------------------------------------------

  Future<void> _loadMessages({bool showLoading = true}) async {
    if (_selectedConversation == null) return;

    if (showLoading) {
      setState(() => _isLoadingMessages = true);
    }

    try {
      final messages = await _chatService.getMessages(
        buyerId: _selectedConversation!['buyer_id'],
        sellerId: _selectedConversation!['seller_id'],
      );

      if (!mounted) return;
      setState(() {
        _messages = messages;
        _isLoadingMessages = false;
      });

      widget.onMessagesRead?.call();

      final conversationId = await _resolveConversationId();
      if (conversationId != null && mounted) {
        _setupMessagesRealtimeSubscription(conversationId);
      }
    } catch (e) {
      debugPrint('RiderChatScreen - Error loading messages: $e');
      if (mounted) setState(() => _isLoadingMessages = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty ||
        _selectedConversation == null) {
      return;
    }
    if (_isChatEnded(_selectedConversation!)) {
      SnackBarHelper.showError(
        context,
        'Chat is closed for this contact. Wait for a new order to reopen it.',
      );
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
      await _loadMessages(showLoading: false);
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to send message');
      }
    } finally {
      if (mounted) setState(() => _isSendingMessage = false);
    }
  }

  bool _isChatEnded(Map<String, dynamic> conv) {
    final flagged = conv['is_chat_ended'];
    if (flagged is bool) return flagged;
    final hasActive = conv['has_active_orders'];
    if (hasActive is bool) return !hasActive;
    final active = conv['active_deliveries'];
    if (active is List) return active.isEmpty;
    return false;
  }

  // ---------------------------------------------------------------------------
  // Formatting helpers
  // ---------------------------------------------------------------------------

  String _formatListTime(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return DateFormat('MMM d').format(dt);
    } catch (_) {
      return '';
    }
  }

  String _formatBubbleTime(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$hour12:$minute $period';
  }

  void _exitConversation() {
    _messagesSubscription?.unsubscribe();
    _messagesSubscription = null;
    _activeConversationId = null;
    setState(() {
      _selectedConversation = null;
      _messages = [];
      _revealedMessageId = null;
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_selectedConversation != null) {
      return _buildConversationScreen();
    }
    return SafeArea(child: _buildConversationsList());
  }

  // ---------------- Conversations list ----------------

  Widget _buildConversationsList() {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground(context),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0.h),
            color: AppColors.surface(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Messages',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface(context),
                  ),
                ),
                SizedBox(height: 12.h),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search conversations...',
                    hintStyle: GoogleFonts.goudyBookletter1911(
                      color: AppColors.textFaint(context),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: AppColors.textMuted(context),
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceVariant(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
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
          Expanded(
            child: _isLoadingConversations
                ? Center(
                    child: CircularProgressIndicator(
                      color: AppColors.onSurface(context),
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildConversationsTab(_filteredBuyerConversations, 'buyers'),
                      _buildConversationsTab(_filteredSellerConversations, 'sellers'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationsTab(List<Map<String, dynamic>> list, String type) {
    if (list.isEmpty) return _buildEmptyConversations(type);
    return RefreshIndicator(
      onRefresh: _loadConversations,
      color: AppColors.onSurface(context),
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        itemCount: list.length,
        itemBuilder: (context, index) =>
            _buildConversationCard(conversation: list[index]),
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
            Icon(
              Icons.chat_bubble_outline,
              size: 80.r,
              color: AppColors.textFaint(context),
            ),
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

  Widget _buildConversationCard({required Map<String, dynamic> conversation}) {
    final contactName = (conversation['contact_name'] ?? 'Unknown').toString();
    final lastMessage =
        (conversation['last_message'] ?? 'Start conversation').toString();
    final time = _formatListTime(conversation['last_message_time']?.toString());
    final unreadCount = (conversation['unread_count'] ?? 0) as int;
    final contactAvatar = conversation['contact_avatar']?.toString();
    final isEnded = _isChatEnded(conversation);
    final activeDeliveries =
        (conversation['active_deliveries'] as List?) ?? const [];

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12.r),
          onTap: () {
            setState(() => _selectedConversation = conversation);
            _loadMessages();
          },
          child: Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(12.r),
              border: unreadCount > 0
                  ? Border.all(color: AppColors.onSurface(context), width: 1.5)
                  : Border.all(
                      color: AppColors.surfaceVariant2(context),
                      width: 1,
                    ),
            ),
            child: Row(
              children: [
                _buildAvatar(
                  avatarUrl: contactAvatar,
                  name: contactName,
                  size: 50.r,
                  fontSize: 18.sp,
                  dimmed: isEnded,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              contactName,
                              style: GoogleFonts.goudyBookletter1911(
                                fontSize: 15.sp,
                                fontWeight: unreadCount > 0
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: isEnded
                                    ? AppColors.textMuted(context)
                                    : AppColors.onSurface(context),
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
                                color: AppColors.textMuted(context),
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
                                fontSize: 13.sp,
                                color: unreadCount > 0
                                    ? AppColors.onSurfaceStrong(context)
                                    : AppColors.textMuted(context),
                                fontWeight: unreadCount > 0
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (unreadCount > 0)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.onSurface(context),
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: Text(
                                '$unreadCount',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.surface(context),
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      _buildStatusPill(
                        isEnded: isEnded,
                        activeCount: activeDeliveries.length,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill({required bool isEnded, required int activeCount}) {
    if (isEnded) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant2(context),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Text(
          'Chat ended',
          style: GoogleFonts.goudyBookletter1911(
            fontSize: 11.sp,
            color: AppColors.textMuted(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: _avatarFallbackColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Text(
        activeCount > 1 ? '$activeCount ongoing orders' : 'Ongoing order',
        style: GoogleFonts.goudyBookletter1911(
          fontSize: 11.sp,
          color: const Color(0xFF8B7355),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ---------------- Conversation screen (mirrors buyer side) ----------------

  Widget _buildConversationScreen() {
    final conv = _selectedConversation!;
    final contactName = (conv['contact_name'] ?? 'Unknown').toString();
    final ended = _isChatEnded(conv);
    final activeDeliveries =
        (conv['active_deliveries'] as List?)?.cast<Map<String, dynamic>>() ??
            const <Map<String, dynamic>>[];
    final allDeliveries =
        (conv['all_deliveries'] as List?)?.cast<Map<String, dynamic>>() ??
            const <Map<String, dynamic>>[];

    // Surface active deliveries first, then past ones — same order the
    // service produces — so the rider always sees the live ones up front.
    final stripDeliveries = <Map<String, dynamic>>[
      ...activeDeliveries,
      ...allDeliveries.where((d) =>
          !activeDeliveries.any((a) => a['delivery_id'] == d['delivery_id'])),
    ];

    return Scaffold(
      backgroundColor: AppColors.surfaceVariant(context),
      appBar: AppBar(
        backgroundColor: AppColors.surface(context),
        foregroundColor: AppColors.onSurface(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.onSurface(context)),
          onPressed: _exitConversation,
        ),
        title: Row(
          children: [
            _buildAvatar(
              avatarUrl: conv['contact_avatar']?.toString(),
              name: contactName,
              size: 36.r,
              fontSize: 14.sp,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    contactName,
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _buildHeaderSubtitle(ended, activeDeliveries.length),
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 11.sp,
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
      body: Column(
        children: [
          if (stripDeliveries.isNotEmpty)
            _buildDeliveriesStrip(stripDeliveries, activeDeliveries),
          Expanded(child: _buildMessagesList()),
          if (ended) _buildChatEndedBanner() else _buildMessageInput(),
        ],
      ),
    );
  }

  String _buildHeaderSubtitle(bool ended, int activeCount) {
    if (ended) return 'Chat ended';
    if (activeCount == 0) return 'No active deliveries';
    if (activeCount == 1) return '1 ongoing delivery';
    return '$activeCount ongoing deliveries';
  }

  /// Horizontal scroll strip rendered above the message list. Each chip
  /// shows the order number (full, never truncated) and the delivery's
  /// current status, and tapping one opens the full delivery detail page
  /// so the rider can pull up the address, items, and action buttons
  /// without leaving the chat.
  Widget _buildDeliveriesStrip(
    List<Map<String, dynamic>> deliveries,
    List<Map<String, dynamic>> activeDeliveries,
  ) {
    final activeIds =
        activeDeliveries.map((d) => d['delivery_id']).toSet();

    return Container(
      width: double.infinity,
      color: AppColors.surface(context),
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Text(
              'Linked orders',
              style: GoogleFonts.goudyBookletter1911(
                fontSize: 11.sp,
                color: AppColors.textMuted(context),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ),
          SizedBox(height: 6.h),
          SizedBox(
            height: 36.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              itemCount: deliveries.length,
              separatorBuilder: (context, index) => SizedBox(width: 8.w),
              itemBuilder: (context, index) {
                final delivery = deliveries[index];
                final isActive = activeIds.contains(delivery['delivery_id']);
                return _DeliveryChip(
                  delivery: delivery,
                  isActive: isActive,
                  onTap: () => _openDeliveryDetail(delivery),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Loads the full delivery row (with the nested order data the detail
  /// screen expects) and pushes [DeliveryDetailScreen]. We can't reuse the
  /// chip's lightweight map because it only carries delivery_id and order
  /// number — the detail page needs payment, customer, and address fields.
  Future<void> _openDeliveryDetail(Map<String, dynamic> delivery) async {
    final deliveryId = delivery['delivery_id'];
    if (deliveryId == null) return;

    // Show a transient loader while we hydrate the row.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (_) => Center(
        child: CircularProgressIndicator(color: AppColors.onSurface(context)),
      ),
    );

    try {
      final row = await Supabase.instance.client
          .from('deliveries')
          .select(
            '*, orders!inner(order_number, total_amount, order_status, '
            'order_received, buyer_id)',
          )
          .eq('delivery_id', deliveryId)
          .maybeSingle();

      if (!mounted) return;
      Navigator.of(context).pop(); // close loader

      if (row == null) {
        SnackBarHelper.showError(context, 'Delivery not found.');
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DeliveryDetailScreen(order: row),
        ),
      );

      // The status may have flipped (e.g. marked delivered) while we were
      // away — refresh so the strip and chat-ended banner stay accurate.
      if (mounted) _loadConversations();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      SnackBarHelper.showError(context, 'Failed to open delivery: $e');
    }
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
            Icon(
              Icons.chat_bubble_outline,
              size: 80.r,
              color: AppColors.textFaint(context),
            ),
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
              _isChatEnded(_selectedConversation!)
                  ? 'This chat is closed'
                  : 'Start the conversation',
              style: GoogleFonts.goudyBookletter1911(
                fontSize: 14.sp,
                color: AppColors.textFaint(context),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _messagesScrollController,
      reverse: true,
      padding: EdgeInsets.all(16.w),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[_messages.length - 1 - index];
        // Show avatar only on the last message of each consecutive sender
        // group (the "newer" side, since the list is reversed).
        bool showAvatar;
        if (index == 0) {
          showAvatar = true;
        } else {
          final prevIndex = _messages.length - index;
          if (prevIndex < _messages.length) {
            final prev = _messages[prevIndex];
            showAvatar = (message['sender_type'] ?? '') !=
                (prev['sender_type'] ?? '');
          } else {
            showAvatar = false;
          }
        }
        return _buildMessageBubble(message, showAvatar);
      },
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool showAvatar) {
    final isMe = message['sender_type'] == 'rider';
    final messageId = (message['message_id'] ?? message['id']) as int?;
    final isRevealed = messageId != null && _revealedMessageId == messageId;
    final text = (message['message_text'] ?? '').toString();
    final createdAt = message['created_at'] != null
        ? DateTime.tryParse(message['created_at'].toString())?.toLocal()
        : null;
    final timeLabel = createdAt != null ? _formatBubbleTime(createdAt) : '';

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          if ((!isMe && details.delta.dx > 0) ||
              (isMe && details.delta.dx < 0)) {
            if (!isRevealed && messageId != null) {
              setState(() => _revealedMessageId = messageId);
            }
          }
        },
        onHorizontalDragEnd: (_) => setState(() => _revealedMessageId = null),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              if (showAvatar)
                _buildAvatar(
                  avatarUrl: _selectedConversation?['contact_avatar']?.toString(),
                  name: _selectedConversation?['contact_name']?.toString() ?? 'C',
                  size: 32.r,
                  fontSize: 12.sp,
                )
              else
                SizedBox(width: 32.r),
              SizedBox(width: 8.w),
            ],
            if (!isMe && isRevealed)
              Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: Text(
                  timeLabel,
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 11.sp,
                    color: AppColors.textMuted(context),
                  ),
                ),
              ),
            Flexible(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 10.h,
                ),
                decoration: BoxDecoration(
                  color: isMe
                      ? AppColors.onSurface(context)
                      : AppColors.surface(context),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16.r),
                    topRight: Radius.circular(16.r),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                ),
                child: Text(
                  text,
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 14.sp,
                    color: isMe
                        ? AppColors.surface(context)
                        : AppColors.onSurfaceStrong(context),
                  ),
                ),
              ),
            ),
            if (isMe && isRevealed)
              Padding(
                padding: EdgeInsets.only(left: 8.w),
                child: Text(
                  timeLabel,
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 11.sp,
                    color: AppColors.textMuted(context),
                  ),
                ),
              ),
            if (isMe) ...[
              SizedBox(width: 8.w),
              if (showAvatar)
                _buildAvatar(
                  avatarUrl: _riderProfileImage,
                  name: 'R',
                  size: 32.r,
                  fontSize: 12.sp,
                )
              else
                SizedBox(width: 32.r),
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
                  enabled: !_isSendingMessage,
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
                color: _isSendingMessage
                    ? AppColors.textFaint(context)
                    : AppColors.onSurface(context),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: _isSendingMessage
                    ? SizedBox(
                        width: 18.w,
                        height: 18.h,
                        child: CircularProgressIndicator(
                          color: AppColors.surface(context),
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(
                        Icons.send,
                        color: AppColors.surface(context),
                        size: 20.r,
                      ),
                onPressed: _isSendingMessage ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                _selectedConversation?['contact_type'] == 'seller'
                    ? 'Chat ended. It will reopen when you accept a new pickup from this shop.'
                    : 'Chat ended. It will reopen when this buyer places a new order.',
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

  // ---------------- Avatar helper ----------------

  Widget _buildAvatar({
    required String? avatarUrl,
    required String name,
    required double size,
    required double fontSize,
    bool dimmed = false,
  }) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'C';
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: dimmed
            ? _avatarFallbackColor.withValues(alpha: 0.55)
            : _avatarFallbackColor,
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: GoogleFonts.goudyBookletter1911(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: AppColors.alwaysWhite,
        ),
      ),
    );

    if (avatarUrl == null || avatarUrl.isEmpty) return fallback;

    final image = ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: CachedNetworkImage(
          imageUrl: avatarUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => fallback,
          errorWidget: (context, url, error) => fallback,
        ),
      ),
    );

    if (!dimmed) return image;

    // Greyscale matrix to soften the avatar of a contact whose chat has
    // ended, signalling the locked state without losing recognisability.
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0, 0, 0, 1, 0,
      ]),
      child: image,
    );
  }
}


/// Order chip rendered in the conversation header strip. Shows the full
/// order number and a small status dot, and styles itself differently for
/// active vs. completed deliveries so the rider can read the strip at a
/// glance.
class _DeliveryChip extends StatelessWidget {
  const _DeliveryChip({
    required this.delivery,
    required this.isActive,
    required this.onTap,
  });

  final Map<String, dynamic> delivery;
  final bool isActive;
  final VoidCallback onTap;

  static const Color _brandGold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    final orderNumber =
        (delivery['order_number'] ?? delivery['delivery_id'] ?? '').toString();
    final status = (delivery['status'] ?? '').toString();
    final orderReceived = delivery['order_received'] == true;

    final label = orderNumber.startsWith('ORD') || orderNumber.startsWith('#')
        ? orderNumber
        : '#$orderNumber';

    final IconData statusIcon = switch (status) {
      'assigned' => Icons.assignment_outlined,
      'in_transit' => Icons.local_shipping_outlined,
      'delivered' =>
        orderReceived ? Icons.check_circle : Icons.access_time_outlined,
      _ => Icons.receipt_long_outlined,
    };

    final Color accent = isActive
        ? _brandGold
        : AppColors.textMuted(context);

    final Color background = isActive
        ? _brandGold.withValues(alpha: 0.14)
        : AppColors.surfaceVariant(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20.r),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: isActive
                  ? _brandGold.withValues(alpha: 0.4)
                  : AppColors.surfaceVariant2(context),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, size: 14.r, color: accent),
              SizedBox(width: 6.w),
              // The whole label fits on one line by default. We allow
              // wrapping only as a safety net — chips stay narrow for
              // typical order-number lengths.
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 140.w),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? const Color(0xFF8B7355)
                        : AppColors.textMuted(context),
                  ),
                ),
              ),
              SizedBox(width: 4.w),
              Icon(
                Icons.chevron_right,
                size: 14.r,
                color: accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
