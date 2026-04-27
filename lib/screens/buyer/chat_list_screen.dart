import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/chat_model.dart';
import '../../services/chat_service.dart';
import '../../utils/image_helper.dart';
import '../../utils/snackbar_helper.dart';
import 'chat_conversation_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  Future<List<ChatConversation>>? _conversationsFuture;
  List<ChatConversation> _allConversations = [];
  List<ChatConversation> _filteredConversations = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  RealtimeChannel? _messagesSubscription;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    final userId = _chatService.getCurrentUserId();
    if (userId == null) return;

    // Subscribe to messages table for real-time updates
    _messagesSubscription = Supabase.instance.client
        .channel('chat_messages_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            print('ChatList - New message received: ${payload.newRecord}');
            // Reload conversations when new message arrives
            _loadConversations();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            print('ChatList - Message updated: ${payload.newRecord}');
            // Reload conversations when message is updated (e.g., marked as read)
            _loadConversations();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _messagesSubscription?.unsubscribe();
    _searchController.dispose();
    super.dispose();
  }

  void _loadConversations() async {
    try {
      print('ChatList - Loading conversations...');
      final userId = _chatService.getCurrentUserId();
      final buyerId = _chatService.getCurrentBuyerId();
      print('ChatList - User ID: $userId');
      print('ChatList - Buyer ID: $buyerId');
      
      if (userId == null || buyerId == null) {
        print('ChatList - No user/buyer ID, setting empty list');
        setState(() {
          _allConversations = [];
          _filteredConversations = [];
          _conversationsFuture = Future.value([]);
        });
        return;
      }
      
      print('ChatList - Fetching conversations from database using buyer_id: $buyerId');
      final conversations = await _chatService.getConversations(buyerId, userId); // Pass both buyer_id and user_id
      print('ChatList - Loaded ${conversations.length} conversations');
      
      if (mounted) {
        setState(() {
          _allConversations = conversations;
          _filteredConversations = conversations;
          _conversationsFuture = Future.value(conversations);
        });
      }
    } catch (e) {
      print('ChatList - Error loading conversations: $e');
      if (mounted) {
        setState(() {
          _allConversations = [];
          _filteredConversations = [];
          _conversationsFuture = Future.value([]);
        });
        SnackBarHelper.showError(context, 'Error loading conversations: $e');
      }
    }
  }

  void _filterConversations(String query) async {
    print('ChatList - Filter called with query: "$query"');
    
    if (query.isEmpty) {
      setState(() {
        _filteredConversations = _allConversations;
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      // Filter existing conversations
      _filteredConversations = _allConversations.where((conv) {
        final shopName = conv.shopName?.toLowerCase() ?? '';
        final lastMessage = conv.lastMessage?.toLowerCase() ?? '';
        final searchQuery = query.toLowerCase();
        return shopName.contains(searchQuery) || lastMessage.contains(searchQuery);
      }).toList();
    });

    // Search for sellers in database
    try {
      print('ChatList - Searching sellers...');
      final sellers = await _chatService.searchSellers(query);
      print('ChatList - Found ${sellers.length} sellers');
      setState(() {
        _searchResults = sellers;
        _isSearching = false;
      });
    } catch (e) {
      print('ChatList - Search error: $e');
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Messages', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildConversationList()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        onChanged: _filterConversations,
        decoration: InputDecoration(
          hintText: 'Search conversations...',
          hintStyle: GoogleFonts.goudyBookletter1911(color: Colors.grey[400]),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildConversationList() {
    if (_conversationsFuture == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.black));
    }

    return FutureBuilder<List<ChatConversation>>(
      future: _conversationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.black));
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}', style: GoogleFonts.goudyBookletter1911()),
          );
        }

        final hasConversations = _filteredConversations.isNotEmpty;
        final hasSearchResults = _searchResults.isNotEmpty;
        final isSearchActive = _searchController.text.isNotEmpty;

        if (!hasConversations && !hasSearchResults && !_isSearching) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: () async => _loadConversations(),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // Show existing conversations
              if (hasConversations) ...[
                if (isSearchActive)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Conversations',
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ..._filteredConversations.map((conv) => _buildConversationCard(conv)),
              ],
              
              // Show search results for sellers
              if (isSearchActive && hasSearchResults) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 12),
                  child: Text(
                    'Sellers',
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                ..._searchResults.map((seller) => _buildSellerCard(seller)),
              ],

              // Show loading indicator
              if (_isSearching)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator(color: Colors.black)),
                ),
            ],
          ),
        );
      },
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
            _searchController.text.isEmpty ? 'No conversations yet' : 'No results found',
            style: GoogleFonts.goudyBookletter1911(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isEmpty 
                ? 'Start chatting with sellers'
                : 'Try a different search term',
            style: GoogleFonts.goudyBookletter1911(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationCard(ChatConversation conversation) {
    final buyerId = _chatService.getCurrentBuyerId();
    final isBuyer = buyerId == conversation.buyerId;
    
    print('=== Building Conversation Card ===');
    print('Conversation ID: ${conversation.conversationId}');
    print('Seller Name: ${conversation.sellerName}');
    print('Shop Name: ${conversation.shopName}');
    print('Seller User Type: ${conversation.sellerUserType}');
    print('Is Buyer: $isBuyer');
    
    // Build display name with rider indicator
    String displayName;
    if (isBuyer) {
      if (conversation.sellerUserType == 'rider') {
        displayName = '${conversation.sellerName ?? 'Rider'} (Rider)';
        print('Display name set to: $displayName (RIDER)');
      } else {
        displayName = conversation.shopName ?? conversation.sellerName ?? 'Seller';
        print('Display name set to: $displayName (SELLER)');
      }
    } else {
      displayName = conversation.buyerName ?? 'Buyer';
      print('Display name set to: $displayName (BUYER)');
    }
    print('Final display name: $displayName');
    print('================================');

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatConversationScreen(
              conversationId: conversation.conversationId,
              recipientName: displayName,
              shopLogo: conversation.shopLogo,
              userType: conversation.sellerUserType,
            ),
          ),
        ).then((_) => _loadConversations());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: conversation.unreadCount > 0
              ? Border.all(color: Colors.black, width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: conversation.shopLogo != null && conversation.shopLogo!.isNotEmpty
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: ImageHelper.getImageUrl(conversation.shopLogo!),
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Icon(Icons.store, color: Colors.grey[600]),
                        errorWidget: (context, url, error) => Icon(
                          conversation.sellerUserType == 'rider' ? Icons.delivery_dining : Icons.store,
                          color: Colors.grey[600],
                        ),
                      ),
                    )
                  : Icon(
                      conversation.sellerUserType == 'rider' ? Icons.delivery_dining : Icons.store,
                      color: Colors.grey[600],
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: GoogleFonts.goudyBookletter1911(
                            fontSize: 15,
                            fontWeight: conversation.unreadCount > 0
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatTime(conversation.lastMessageAt),
                        style: GoogleFonts.goudyBookletter1911(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessage ?? 'No messages yet',
                          style: GoogleFonts.goudyBookletter1911(
                            fontSize: 13,
                            color: conversation.unreadCount > 0
                                ? Colors.black87
                                : Colors.grey[600],
                            fontWeight: conversation.unreadCount > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conversation.unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${conversation.unreadCount}',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSellerCard(Map<String, dynamic> seller) {
    final email = seller['email'] ?? 'Unknown';
    final shopName = email.split('@')[0]; // Use email username as display name
    final sellerUserId = seller['user_id']?.toString(); // This is user_id, not seller_id

    print('Building seller card: $seller');
    print('Seller user_id: $sellerUserId');

    return GestureDetector(
      onTap: () async {
        print('Seller card tapped!');
        final userId = _chatService.getCurrentUserId();
        final buyerId = _chatService.getCurrentBuyerId();
        print('=== ChatList - Seller Card Tapped ===');
        print('ChatList - Current user_id: $userId');
        print('ChatList - Current buyer_id: $buyerId');
        print('ChatList - Seller user_id: $sellerUserId');
        
        if (userId == null) {
          print('No user ID found');
          if (mounted) {
            SnackBarHelper.showError(context, 'Please login first');
          }
          return;
        }
        
        if (buyerId == null) {
          print('No buyer ID found');
          if (mounted) {
            SnackBarHelper.showError(context, 'Buyer ID not found. Please log out and log in again.');
          }
          return;
        }
        
        if (sellerUserId == null) {
          print('No seller user_id found');
          if (mounted) {
            SnackBarHelper.showError(context, 'Invalid seller');
          }
          return;
        }

        // Show loading indicator
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        try {
          // First, get the seller_id from sellers table using user_id
          print('ChatList - Fetching seller_id for user_id: $sellerUserId');
          final sellerData = await Supabase.instance.client
              .from('sellers')
              .select('seller_id')
              .eq('user_id', sellerUserId)
              .maybeSingle();
          
          print('ChatList - Seller data response: $sellerData');
          
          if (sellerData == null) {
            throw Exception('Seller not found in sellers table');
          }
          
          final sellerId = sellerData['seller_id'].toString();
          print('ChatList - Found seller_id: $sellerId');
          
          print('ChatList - Calling getOrCreateConversation with buyer_id: $buyerId, seller_id: $sellerId');
          final conversation = await _chatService.getOrCreateConversation(
            buyerId: buyerId,
            sellerId: sellerId, // Use seller_id from sellers table
          );

          print('Conversation result: $conversation');
          print('Conversation ID: ${conversation?.conversationId}');

          // Close loading dialog
          if (mounted) {
            Navigator.pop(context);
          }

          if (conversation != null && mounted) {
            print('Navigating to chat screen...');
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatConversationScreen(
                  conversationId: conversation.conversationId,
                  recipientName: shopName,
                ),
              ),
            ).then((_) {
              print('Returned from chat screen, reloading conversations');
              _loadConversations();
            });
          } else {
            print('Conversation is null or context not mounted');
            if (mounted) {
              SnackBarHelper.showError(context, 'Failed to create conversation');
            }
          }
        } catch (e) {
          print('Error creating conversation: $e');
          // Close loading dialog
          if (mounted) {
            Navigator.pop(context);
            SnackBarHelper.showError(context, 'Error: $e');
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.store,
                size: 24,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shopName,
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
