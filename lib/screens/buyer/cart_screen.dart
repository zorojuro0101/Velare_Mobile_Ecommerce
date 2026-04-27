import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/cart_model.dart';
import '../../services/cart_service.dart';
import '../../services/chat_service.dart';
import '../../services/notification_service.dart';
import '../../utils/image_helper.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/icon_badge.dart';
import 'product_detail_screen.dart';
import 'checkout_screen.dart';
import 'notifications_screen.dart';
import 'chat_list_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartService _cartService = CartService();
  final ChatService _chatService = ChatService();
  final NotificationService _notificationService = NotificationService();
  List<CartItem> _cartItems = [];
  bool _isLoading = true;
  final Set<int> _selectedItems = {};
  bool _selectAll = false;
  
  int _unreadChatCount = 0;
  int _unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCart();
    _loadCounts();
  }
  
  Future<void> _loadCounts() async {
    final buyerId = _cartService.getCurrentBuyerId();
    final userId = _cartService.getCurrentUserId();
    
    if (buyerId != null && userId != null) {
      try {
        // Load all counts in parallel for faster loading
        final results = await Future.wait([
          _chatService.getUnreadCount(buyerId, userId),
          _notificationService.getUnreadCount(userId),
        ]);
        
        if (mounted) {
          setState(() {
            _unreadChatCount = results[0];
            _unreadNotificationCount = results[1];
          });
        }
      } catch (e) {
        print('Error loading counts: $e');
      }
    }
  }

  Future<void> _loadCart() async {
    final buyerId = _cartService.getCurrentBuyerId();
    if (buyerId == null) {
      setState(() {
        _cartItems = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final items = await _cartService.getCartItems(buyerId);
      setState(() {
        _cartItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _cartItems = [];
        _isLoading = false;
      });
      if (mounted) {
        SnackBarHelper.showError(context, 'Error loading cart: $e');
      }
    }
  }

  Map<String, List<CartItem>> _groupByShop(List<CartItem> items) {
    final Map<String, List<CartItem>> grouped = {};
    for (var item in items) {
      if (!grouped.containsKey(item.shopName)) {
        grouped[item.shopName] = [];
      }
      grouped[item.shopName]!.add(item);
    }
    return grouped;
  }

  double _calculateTotal(List<CartItem> items) {
    double total = 0;
    for (var item in items) {
      if (_selectedItems.contains(item.cartId)) {
        total += item.totalPrice;
      }
    }
    return total;
  }

  void _toggleSelectAll(List<CartItem> items) {
    setState(() {
      if (_selectAll) {
        _selectedItems.clear();
      } else {
        _selectedItems.addAll(items.map((item) => item.cartId));
      }
      _selectAll = !_selectAll;
    });
  }

  Future<void> _updateQuantity(int cartId, int newQuantity) async {
    if (!mounted) return;
    
    // Find the item
    final index = _cartItems.indexWhere((item) => item.cartId == cartId);
    if (index == -1) return;
    
    final oldItem = _cartItems[index];
    
    // Update in database FIRST (don't update UI yet)
    try {
      await _cartService.updateQuantity(cartId, newQuantity);
      
      // Only update UI if database update was successful
      if (mounted) {
        setState(() {
          _cartItems[index] = CartItem(
            cartId: oldItem.cartId,
            productId: oldItem.productId,
            productName: oldItem.productName,
            price: oldItem.price,
            quantity: newQuantity,
            primaryImage: oldItem.primaryImage,
            color: oldItem.color,
            size: oldItem.size,
            sellerId: oldItem.sellerId,
            shopName: oldItem.shopName,
            shopLogo: oldItem.shopLogo,
          );
        });
      }
    } catch (e) {
      // Show error without changing UI
      if (mounted) {
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        SnackBarHelper.showError(context, errorMsg);
      }
    }
  }

  Future<void> _removeItem(int cartId) async {
    if (!mounted) return;
    
    // Remove locally first for instant feedback
    setState(() {
      _cartItems.removeWhere((item) => item.cartId == cartId);
      _selectedItems.remove(cartId);
    });

    try {
      await _cartService.removeFromCart(cartId);
      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Item removed');
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        await _loadCart();
        SnackBarHelper.showError(context, 'Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Shopping Cart', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          NotificationDot(
            icon: Icons.notifications_outlined,
            showDot: _unreadNotificationCount > 0,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ).then((_) => _loadCounts());
            },
          ),
          NotificationDot(
            icon: Icons.chat_bubble_outline,
            showDot: _unreadChatCount > 0,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatListScreen()),
              ).then((_) => _loadCounts());
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _cartItems.isEmpty
              ? _buildEmptyCart()
              : Column(
                  children: [
                    _buildSelectAllBar(_cartItems),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _groupByShop(_cartItems).length,
                        itemBuilder: (context, index) {
                          final groupedItems = _groupByShop(_cartItems);
                          final shopName = groupedItems.keys.elementAt(index);
                          final shopItems = groupedItems[shopName]!;
                          return _buildShopGroup(shopName, shopItems);
                        },
                      ),
                    ),
                    _buildBottomBar(_cartItems),
                  ],
                ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 100, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Your cart is empty',
            style: GoogleFonts.goudyBookletter1911(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            child: Text('Start Shopping', style: GoogleFonts.goudyBookletter1911()),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectAllBar(List<CartItem> items) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          Checkbox(
            value: _selectAll,
            onChanged: (_) => _toggleSelectAll(items),
            activeColor: Colors.black,
          ),
          Text('Select All', style: GoogleFonts.goudyBookletter1911(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildShopGroup(String shopName, List<CartItem> items) {
    // Get shop logo from first item in the group
    final shopLogo = items.isNotEmpty ? items.first.shopLogo : null;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Shop logo or first letter
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD3BD9B),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: shopLogo != null && shopLogo.isNotEmpty
                      ? Builder(
                          builder: (context) {
                            final imageUrl = ImageHelper.getImageUrl(shopLogo);
                            if (imageUrl.isEmpty) {
                              // Show first letter if image URL is empty
                              return Center(
                                child: Text(
                                  shopName.isNotEmpty ? shopName[0].toUpperCase() : 'S',
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            }
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Center(
                                  child: Text(
                                    shopName.isNotEmpty ? shopName[0].toUpperCase() : 'S',
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Center(
                                  child: Text(
                                    shopName.isNotEmpty ? shopName[0].toUpperCase() : 'S',
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : Center(
                          child: Text(
                            shopName.isNotEmpty ? shopName[0].toUpperCase() : 'S',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Text(
                  shopName,
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...items.map((item) => _buildCartItem(item)),
        ],
      ),
    );
  }

  Widget _buildCartItem(CartItem item) {
    final isSelected = _selectedItems.contains(item.cartId);
    String imageUrl = ImageHelper.getImageUrl(item.primaryImage);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: isSelected,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selectedItems.add(item.cartId);
                } else {
                  _selectedItems.remove(item.cartId);
                }
              });
            },
            activeColor: Colors.black,
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductDetailScreen(productId: item.productId),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.image_not_supported),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.color != null || item.size != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      [
                        if (item.color != null) 'Color: ${item.color}',
                        if (item.size != null) 'Size: ${item.size}',
                      ].join(' • '),
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  '₱${item.price.toStringAsFixed(2)}',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildQuantityButton(
                      Icons.remove,
                      () => item.quantity > 1
                          ? _updateQuantity(item.cartId, item.quantity - 1)
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '${item.quantity}',
                        style: GoogleFonts.goudyBookletter1911(fontWeight: FontWeight.w600),
                      ),
                    ),
                    _buildQuantityButton(
                      Icons.add,
                      () => _updateQuantity(item.cartId, item.quantity + 1),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _showDeleteDialog(item.cartId),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityButton(IconData icon, VoidCallback? onPressed) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16),
        ),
      ),
    );
  }

  Widget _buildBottomBar(List<CartItem> items) {
    final total = _calculateTotal(items);
    final selectedCount = _selectedItems.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Total ($selectedCount items)',
                    style: GoogleFonts.goudyBookletter1911(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    '₱${total.toStringAsFixed(2)}',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: selectedCount > 0
                  ? () {
                      final selectedCartItems = items.where((item) => _selectedItems.contains(item.cartId)).toList();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CheckoutScreen(
                            items: selectedCartItems,
                            totalAmount: total,
                          ),
                        ),
                      ).then((_) => _loadCart());
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Checkout',
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(int cartId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Item', style: GoogleFonts.goudyBookletter1911(fontWeight: FontWeight.w600)),
        content: Text(
          'Are you sure you want to remove this item from cart?',
          style: GoogleFonts.goudyBookletter1911(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.goudyBookletter1911(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeItem(cartId);
            },
            child: Text('Remove', style: GoogleFonts.goudyBookletter1911(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

