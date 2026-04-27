import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/favorite_model.dart';
import '../../services/favorite_service.dart';
import '../../services/cart_service.dart';
import '../../services/chat_service.dart';
import '../../services/notification_service.dart';
import '../../utils/image_helper.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/icon_badge.dart';
import 'product_detail_screen.dart';
import 'notifications_screen.dart';
import 'cart_screen.dart';
import 'chat_list_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final FavoriteService _favoriteService = FavoriteService();
  final CartService _cartService = CartService();
  final ChatService _chatService = ChatService();
  final NotificationService _notificationService = NotificationService();
  Future<List<FavoriteItem>>? _favoritesFuture;
  
  // Store selected variants for each product
  final Map<int, Map<String, dynamic>> _selectedVariants = {};
  
  int _cartCount = 0;
  int _unreadChatCount = 0;
  int _unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _loadCounts();
  }
  
  Future<void> _loadCounts() async {
    final buyerId = _cartService.getCurrentBuyerId();
    final userId = _cartService.getCurrentUserId();
    
    if (buyerId != null && userId != null) {
      try {
        // Load all counts in parallel for faster loading
        final results = await Future.wait([
          _cartService.getCartItems(buyerId),
          _chatService.getUnreadCount(buyerId, userId),
          _notificationService.getUnreadCount(userId),
        ]);
        
        if (mounted) {
          setState(() {
            _cartCount = (results[0] as List).length;
            _unreadChatCount = results[1] as int;
            _unreadNotificationCount = results[2] as int;
          });
        }
      } catch (e) {
        print('Error loading counts: $e');
      }
    }
  }

  void _loadFavorites() {
    // Use custom auth service to get buyer ID
    final buyerId = _favoriteService.getCurrentBuyerId();
    if (buyerId != null) {
      setState(() {
        _favoritesFuture = _favoriteService.getFavorites(buyerId).then((favorites) async {
          // Load first variant for each product
          for (var item in favorites) {
            if (!_selectedVariants.containsKey(item.productId)) {
              await _loadFirstVariant(item.productId);
            }
          }
          return favorites;
        });
      });
    } else {
      // Set empty future if no buyer
      setState(() {
        _favoritesFuture = Future.value([]);
      });
    }
  }

  Future<void> _loadFirstVariant(int productId) async {
    try {
      final response = await Supabase.instance.client
          .from('product_variants')
          .select('*')
          .eq('product_id', productId)
          .limit(1)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _selectedVariants[productId] = {
            'variant_id': response['variant_id'],
            'color': response['color'],
            'size': response['size'],
            'stock_quantity': response['stock_quantity'],
          };
        });
      }
    } catch (e) {
      // Silently fail if no variants
    }
  }

  Future<void> _removeFromFavorites(int favoriteId) async {
    try {
      await _favoriteService.removeFromFavorites(favoriteId);
      _loadFavorites();
      if (mounted) {
        SnackBarHelper.showInfo(context, 'Removed from favorites');
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Error: $e');
      }
    }
  }

  Future<void> _addToCart(FavoriteItem item) async {
    final buyerId = _cartService.getCurrentBuyerId();
    if (buyerId == null) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Please login first');
      }
      return;
    }

    // Get selected variant for this product
    final selectedVariant = _selectedVariants[item.productId];
    final variantId = selectedVariant?['variant_id'];

    try {
      await _cartService.addToCart(
        userId: buyerId,
        productId: item.productId,
        sellerId: '', // Will need to fetch from product
        quantity: 1,
        variantId: variantId,
      );

      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Added to cart');
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Error: $e');
      }
    }
  }

  Future<void> _showVariantSelector(FavoriteItem item) async {
    // Fetch variants for this product
    try {
      final response = await Supabase.instance.client
          .from('product_variants')
          .select('*')
          .eq('product_id', item.productId);

      final variants = (response as List).map((json) {
        return {
          'variant_id': json['variant_id'],
          'color': json['color'],
          'size': json['size'],
          'stock_quantity': json['stock_quantity'],
        };
      }).toList();

      if (variants.isEmpty) {
        if (mounted) {
          SnackBarHelper.showError(context, 'No variants available');
        }
        return;
      }

      if (mounted) {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => _buildVariantSelectorModal(item, variants),
        );
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Error loading variants: $e');
      }
    }
  }

  Widget _buildVariantSelectorModal(FavoriteItem item, List<Map<String, dynamic>> variants) {
    // Get unique colors
    final colors = variants.map((v) => v['color'] as String?).where((c) => c != null).toSet().toList();
    
    String? selectedColor = _selectedVariants[item.productId]?['color'] ?? colors.first;
    String? selectedSize = _selectedVariants[item.productId]?['size'];

    return StatefulBuilder(
      builder: (context, setModalState) {
        // Get available sizes for selected color
        final availableSizes = variants
            .where((v) => v['color'] == selectedColor && v['size'] != null)
            .map((v) => v['size'] as String)
            .toList();

        if (selectedSize == null && availableSizes.isNotEmpty) {
          selectedSize = availableSizes.first;
        }

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Variant',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Color',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: colors.map((color) {
                    final isSelected = selectedColor == color;
                    return GestureDetector(
                      onTap: () {
                        setModalState(() {
                          selectedColor = color;
                          selectedSize = null; // Reset size when color changes
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.black : Colors.white,
                          border: Border.all(color: isSelected ? Colors.black : Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          color ?? '',
                          style: GoogleFonts.goudyBookletter1911(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                Text(
                  'Size',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableSizes.map((size) {
                    final isSelected = selectedSize == size;
                    final variant = variants.firstWhere(
                      (v) => v['color'] == selectedColor && v['size'] == size,
                    );
                    final stock = variant['stock_quantity'] as int;
                    final isOutOfStock = stock == 0;

                    return GestureDetector(
                      onTap: isOutOfStock ? null : () {
                        setModalState(() {
                          selectedSize = size;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isOutOfStock
                              ? Colors.grey[100]
                              : (isSelected ? Colors.black : Colors.white),
                          border: Border.all(
                            color: isOutOfStock
                                ? Colors.grey[300]!
                                : (isSelected ? Colors.black : Colors.grey[300]!),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isOutOfStock ? '$size (Out)' : size,
                          style: GoogleFonts.goudyBookletter1911(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isOutOfStock
                                ? Colors.grey[400]
                                : (isSelected ? Colors.white : Colors.black),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      if (selectedColor != null && selectedSize != null) {
                        final variant = variants.firstWhere(
                          (v) => v['color'] == selectedColor && v['size'] == selectedSize,
                        );
                        setState(() {
                          _selectedVariants[item.productId] = variant;
                        });
                        Navigator.pop(context);
                      }
                    },
                    child: Text(
                      'Confirm',
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Favorites',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
        ),
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
          IconBadge(
            icon: Icons.shopping_cart_outlined,
            count: _cartCount,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartScreen()),
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
      body: _favoritesFuture == null
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : FutureBuilder<List<FavoriteItem>>(
              future: _favoritesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.black));
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}', style: GoogleFonts.goudyBookletter1911()),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyFavorites();
                }

                return RefreshIndicator(
                  onRefresh: () async => _loadFavorites(),
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.55,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      return _buildFavoriteCard(snapshot.data![index]);
                    },
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyFavorites() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 100, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No favorites yet',
            style: GoogleFonts.goudyBookletter1911(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Start adding items you love',
            style: GoogleFonts.goudyBookletter1911(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: Text('Browse Products', style: GoogleFonts.goudyBookletter1911()),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteCard(FavoriteItem item) {
    String imageUrl = ImageHelper.getImageUrl(item.primaryImage);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(
              productId: item.productId,
              onCartUpdated: () {
                if (mounted) {
                  _loadCounts();
                }
              },
            ),
          ),
        ).then((_) {
          if (mounted) {
            _loadFavorites();
            _loadCounts();
          }
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.favorite, size: 20, color: Color(0xFFFFD700)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      onPressed: () => _showRemoveDialog(item),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: GoogleFonts.goudyBookletter1911(fontSize: 13, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₱${item.price.toStringAsFixed(2)}',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => _showVariantSelector(item),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selectedVariants[item.productId] != null
                                ? '${_selectedVariants[item.productId]!['color']} / ${_selectedVariants[item.productId]!['size']}'
                                : 'Select variant',
                            style: GoogleFonts.goudyBookletter1911(
                              fontSize: 11,
                              color: Colors.grey[700],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey[600]),
                      ],
                    ),
                  ),
                  if (item.shopName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.shopName!,
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _addToCart(item),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        side: const BorderSide(color: Colors.black),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        'Add to Cart',
                        style: GoogleFonts.goudyBookletter1911(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRemoveDialog(FavoriteItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove from Favorites', style: GoogleFonts.goudyBookletter1911(fontWeight: FontWeight.w600)),
        content: Text(
          'Remove "${item.productName}" from your favorites?',
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
              _removeFromFavorites(item.favoriteId);
            },
            child: Text('Remove', style: GoogleFonts.goudyBookletter1911(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

