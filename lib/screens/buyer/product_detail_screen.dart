import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/product_model.dart';
import '../../models/product_variant_model.dart';
import '../../models/cart_model.dart';
import '../../services/product_service.dart';
import '../../services/cart_service.dart';
import '../../services/favorite_service.dart';
import '../../services/chat_service.dart';
import '../../services/notification_service.dart';
import '../../utils/image_helper.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/icon_badge.dart';
import 'cart_screen.dart';
import 'checkout_screen.dart';
import 'chat_list_screen.dart';
import 'chat_conversation_screen.dart';
import 'view_shop_screen.dart';
import 'notifications_screen.dart';
import '../auth/login_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;
  final bool isGuestMode;
  final VoidCallback? onCartUpdated;

  const ProductDetailScreen({
    super.key,
    required this.productId,
    this.isGuestMode = false,
    this.onCartUpdated,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final ProductService _productService = ProductService();
  final CartService _cartService = CartService();
  final FavoriteService _favoriteService = FavoriteService();
  final ChatService _chatService = ChatService();
  final NotificationService _notificationService = NotificationService();
  
  late Future<Product> _productFuture;
  bool _isFavorite = false;
  int _selectedImageIndex = 0;
  List<ProductVariant> _variants = [];
  Map<int, List<String>> _variantImagesMap = {};
  late PageController _pageController;
  int _cartCount = 0;
  int _unreadChatCount = 0;
  int _unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    print('ProductDetail - Loading product ID: ${widget.productId}');
    _productFuture = _productService.getProductById(widget.productId).then((product) {
      print('ProductDetail - Product loaded: ${product.productName}');
      print('ProductDetail - Primary image: ${product.primaryImage}');
      print('ProductDetail - Additional images: ${product.additionalImages}');
      return product;
    });
    _checkFavorite();
    _loadVariants();
    _loadCounts();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadVariants() async {
    try {
      final response = await Supabase.instance.client
          .from('product_variants')
          .select('*')
          .eq('product_id', widget.productId);

      final variants = (response as List)
          .map((json) => ProductVariant.fromJson(json))
          .toList();

      // Load images for each variant
      final variantImagesMap = <int, List<String>>{};
      for (var variant in variants) {
        final images = await _loadVariantImages(variant.variantId);
        if (images.isNotEmpty) {
          variantImagesMap[variant.variantId] = images;
        }
      }

      if (mounted) {
        setState(() {
          _variants = variants;
          _variantImagesMap = variantImagesMap;
        });
      }
    } catch (e) {
      print('Error loading variants: $e');
    }
  }

  Future<List<String>> _loadVariantImages(int variantId) async {
    try {
      final response = await Supabase.instance.client
          .from('product_images')
          .select('image_url')
          .eq('variant_id', variantId)
          .order('display_order', ascending: true);

      return (response as List).map((item) => item['image_url'] as String).toList();
    } catch (e) {
      print('Error loading variant images: $e');
      return [];
    }
  }

  Future<void> _checkFavorite() async {
    if (widget.isGuestMode) return;
    
    final buyerId = _favoriteService.getCurrentBuyerId();
    if (buyerId != null) {
      final isFav = await _favoriteService.isFavorite(buyerId, widget.productId);
      if (mounted) {
        setState(() => _isFavorite = isFav);
      }
    }
  }

  Future<void> _loadCounts() async {
    if (widget.isGuestMode) return;
    
    final buyerId = _cartService.getCurrentBuyerId();
    final userId = _cartService.getCurrentUserId();
    
    print('=== ProductDetail _loadCounts ===');
    print('buyerId: $buyerId');
    print('userId: $userId');
    
    if (buyerId != null && userId != null) {
      try {
        // Load all counts in parallel for faster loading
        final results = await Future.wait([
          _cartService.getCartItems(buyerId),
          _chatService.getUnreadCount(buyerId, userId),
          _notificationService.getUnreadCount(userId),
        ]);
        
        final cartCount = (results[0] as List).length;
        final chatCount = results[1] as int;
        final notifCount = results[2] as int;
        
        print('Cart items count: $cartCount');
        print('Unread chat count: $chatCount');
        print('Unread notification count: $notifCount');
        
        if (mounted) {
          setState(() {
            _cartCount = cartCount;
            _unreadChatCount = chatCount;
            _unreadNotificationCount = notifCount;
          });
          print('State updated - cartCount: $_cartCount, chatCount: $_unreadChatCount, notifCount: $_unreadNotificationCount');
        }
      } catch (e) {
        print('Error loading counts: $e');
      }
    }
  }

  void _showLoginPrompt(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Login Required', style: GoogleFonts.goudyBookletter1911(fontWeight: FontWeight.w600)),
        content: Text(
          'You need to login to $feature',
          style: GoogleFonts.goudyBookletter1911(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.goudyBookletter1911(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: Text('Login', style: GoogleFonts.goudyBookletter1911(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    if (widget.isGuestMode) {
      _showLoginPrompt('add to favorites');
      return;
    }

    final buyerId = _favoriteService.getCurrentBuyerId();
    if (buyerId == null) {
      if (mounted) {
        _showLoginPrompt('add to favorites');
      }
      return;
    }

    try {
      if (_isFavorite) {
        // Get the favorite_id and remove it
        final favoriteId = await _favoriteService.getFavoriteId(buyerId, widget.productId);
        if (favoriteId != null) {
          await _favoriteService.removeFromFavorites(favoriteId);
        }
      } else {
        await _favoriteService.addToFavorites(buyerId, widget.productId);
      }
      setState(() => _isFavorite = !_isFavorite);
      if (mounted) {
        if (_isFavorite) {
          SnackBarHelper.showSuccess(context, 'Added to favorites');
        } else {
          SnackBarHelper.showInfo(context, 'Removed from favorites');
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Error: $e');
      }
    }
  }

  Future<void> _addToCart(Product product) async {
    // Wait for variants to load before showing modal
    if (_variants.isEmpty) {
      await _loadVariants();
    }
    _showVariantModal(product, isAddToCart: true);
  }

  Future<void> _buyNow(Product product) async {
    // Wait for variants to load before showing modal
    if (_variants.isEmpty) {
      await _loadVariants();
    }
    _showVariantModal(product, isAddToCart: false);
  }

  void _showVariantModal(Product product, {required bool isAddToCart}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _VariantSelectionModal(
        product: product,
        variants: _variants,
        variantImagesMap: _variantImagesMap,
        isAddToCart: isAddToCart,
        isGuestMode: widget.isGuestMode,
        onConfirm: (variant, quantity) async {
          // Check if guest mode first
          if (widget.isGuestMode) {
            Navigator.pop(context);
            _showLoginPrompt(isAddToCart ? 'add items to cart' : 'buy products');
            return;
          }

          // Get buyer_id from auth service
          final buyerId = _cartService.getCurrentBuyerId();
          if (buyerId == null) {
            Navigator.pop(context);
            _showLoginPrompt(isAddToCart ? 'add items to cart' : 'buy products');
            return;
          }

          try {
            if (isAddToCart) {
              await _cartService.addToCart(
                userId: buyerId,
                productId: product.id,
                sellerId: product.sellerId ?? '',
                quantity: quantity,
                variantId: variant?.variantId,
              );

              if (mounted) {
                Navigator.pop(context); // Close variant modal
                SnackBarHelper.showSuccess(context, 'Added to cart');
                // Reload counts in product detail screen
                _loadCounts();
                // Trigger callback to update parent's cart count
                widget.onCartUpdated?.call();
              }
            } else {
              // Buy now logic - navigate to checkout
              // Create a temporary CartItem for checkout
              final cartItem = CartItem(
                cartId: 0, // Temporary ID for buy now
                productId: product.id,
                productName: product.productName,
                price: product.price,
                quantity: quantity,
                primaryImage: product.primaryImage ?? '',
                color: variant?.color,
                size: variant?.size,
                sellerId: product.sellerId ?? '',
                shopName: product.shopName ?? 'Unknown Shop',
                shopLogo: product.shopLogo,
              );
              
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CheckoutScreen(
                    items: [cartItem],
                    totalAmount: product.price * quantity,
                  ),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              Navigator.pop(context);
              final errorMsg = e.toString().replaceAll('Exception: ', '');
              SnackBarHelper.showError(context, errorMsg);
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<Product>(
        future: _productFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.black));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}', style: GoogleFonts.goudyBookletter1911()),
            );
          }
          if (!snapshot.hasData) {
            return Center(
              child: Text('Product not found', style: GoogleFonts.goudyBookletter1911()),
            );
          }

          final product = snapshot.data!;
          final images = product.additionalImages ?? 
                        (product.primaryImage != null ? [product.primaryImage!] : []);

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  _buildAppBar(),
                  SliverToBoxAdapter(child: _buildImageGallery(images)),
                  SliverToBoxAdapter(child: _buildProductInfo(product)),
  SliverToBoxAdapter(
                    child: _TabSection(
                      product: product,
                      isGuestMode: widget.isGuestMode,
                      onChatWithSeller: () => _chatWithSeller(product),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)), // Space for bottom bar
                ],
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomBar(product),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _chatWithSeller(Product product) async {
    if (widget.isGuestMode) {
      _showLoginPrompt('chat with seller');
      return;
    }

    final buyerId = _cartService.getCurrentBuyerId();
    if (buyerId == null) {
      _showLoginPrompt('chat with seller');
      return;
    }
    
    try {
      final chatService = ChatService();
      final conversation = await chatService.getOrCreateConversation(
        buyerId: buyerId,
        sellerId: product.sellerId!,
      );
      
      if (conversation != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatConversationScreen(
              conversationId: conversation.conversationId,
              recipientName: product.shopName ?? 'Seller',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Error: $e');
      }
    }
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      pinned: true,
      actions: [
        if (!widget.isGuestMode)
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
        if (!widget.isGuestMode)
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
        IconButton(
          icon: Icon(
            _isFavorite ? Icons.favorite : Icons.favorite_border,
            color: _isFavorite ? const Color(0xFFFFD700) : Colors.black,
          ),
          onPressed: _toggleFavorite,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildImageGallery(List<String> images) {
    if (images.isEmpty) {
      return Container(
        height: 400,
        color: Colors.grey[200],
        child: const Icon(Icons.image_not_supported, size: 80, color: Colors.grey),
      );
    }

    String getImageUrl(String image) {
      final url = ImageHelper.getImageUrl(image);
      print('ProductDetail - Image: $image -> URL: $url');
      return url;
    }

    return Stack(
      children: [
        SizedBox(
          height: 400,
          child: PageView.builder(
            controller: _pageController,
            itemCount: null, // Infinite scroll
            onPageChanged: (index) {
              setState(() {
                _selectedImageIndex = index % images.length;
              });
            },
            itemBuilder: (context, index) {
              final imageIndex = index % images.length;
              return CachedNetworkImage(
                imageUrl: getImageUrl(images[imageIndex]),
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.error, size: 80),
                ),
              );
            },
          ),
        ),
        if (images.length > 1)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 120,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Row(
                  children: List.generate(
                    images.length,
                    (index) => Expanded(
                      child: Container(
                        margin: EdgeInsets.only(
                          right: index < images.length - 1 ? 4 : 0,
                        ),
                        decoration: BoxDecoration(
                          color: index <= _selectedImageIndex
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: index <= _selectedImageIndex
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProductInfo(Product product) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.productName,
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (product.materials != null && product.materials!.isNotEmpty) ...[
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Materials: ',
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: product.materials!,
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Center(
            child: Text(
              '₱${product.price.toStringAsFixed(2)}',
              style: GoogleFonts.playfairDisplay(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }





  Widget _buildBottomBar(Product product) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.black),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => _addToCart(product),
              child: Text(
                'Add to Cart',
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => _buyNow(product),
              child: Text(
                'Buy Now',
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _VariantSelectionModal extends StatefulWidget {
  final Product product;
  final List<ProductVariant> variants;
  final Map<int, List<String>> variantImagesMap;
  final bool isAddToCart;
  final bool isGuestMode;
  final Function(ProductVariant?, int) onConfirm;

  const _VariantSelectionModal({
    required this.product,
    required this.variants,
    required this.variantImagesMap,
    required this.isAddToCart,
    required this.isGuestMode,
    required this.onConfirm,
  });

  @override
  State<_VariantSelectionModal> createState() => _VariantSelectionModalState();
}

class _VariantSelectionModalState extends State<_VariantSelectionModal> {
  String? _selectedColor;
  String? _selectedSize;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    if (widget.variants.isNotEmpty) {
      // Get unique colors
      final colors = widget.variants.map((v) => v.color).where((c) => c != null).toSet();
      if (colors.isNotEmpty) {
        _selectedColor = colors.first;
      }
      
      // Get sizes for the first color
      _updateAvailableSizes();
    }
  }

  void _updateAvailableSizes() {
    if (_selectedColor != null) {
      final sizesForColor = widget.variants
          .where((v) => v.color == _selectedColor && v.size != null)
          .map((v) => v.size!)
          .toList();
      
      if (sizesForColor.isNotEmpty) {
        _selectedSize = sizesForColor.first;
      }
    }
  }

  ProductVariant? _getSelectedVariant() {
    if (_selectedColor == null || _selectedSize == null) return null;
    
    try {
      return widget.variants.firstWhere(
        (v) => v.color == _selectedColor && v.size == _selectedSize,
      );
    } catch (e) {
      return null;
    }
  }

  List<String> _getUniqueColors() {
    return widget.variants
        .map((v) => v.color)
        .where((c) => c != null)
        .toSet()
        .cast<String>()
        .toList();
  }

  List<String> _getAvailableSizes() {
    if (_selectedColor == null) return [];
    
    return widget.variants
        .where((v) => v.color == _selectedColor && v.size != null)
        .map((v) => v.size!)
        .toList();
  }

  int _getStockForSize(String size) {
    if (_selectedColor == null) return 0;
    
    try {
      final variant = widget.variants.firstWhere(
        (v) => v.color == _selectedColor && v.size == size,
      );
      return variant.stockQuantity;
    } catch (e) {
      return 0;
    }
  }

  String _getDisplayImage() {
    final selectedVariant = _getSelectedVariant();
    
    // If variant is selected and has images, use the first variant image
    if (selectedVariant != null && widget.variantImagesMap.containsKey(selectedVariant.variantId)) {
      final variantImages = widget.variantImagesMap[selectedVariant.variantId];
      if (variantImages != null && variantImages.isNotEmpty) {
        return variantImages.first;
      }
    }
    
    // Fallback to variant's image_url field
    if (selectedVariant?.imageUrl != null) {
      return selectedVariant!.imageUrl!;
    }
    
    // Fallback to product primary image
    return widget.product.primaryImage ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: ImageHelper.getImageUrl(_getDisplayImage()),
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product.productName,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₱${widget.product.price.toStringAsFixed(2)}',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (widget.variants.isNotEmpty) ...[
                Text(
                  'Select Color',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _getUniqueColors().map((color) {
                    final isSelected = _selectedColor == color;
                    
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedColor = color;
                          _updateAvailableSizes();
                          _quantity = 1;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.black : Colors.white,
                          border: Border.all(
                            color: isSelected ? Colors.black : Colors.grey[300]!,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          color,
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
                const SizedBox(height: 24),
                Text(
                  'Select Size',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _getAvailableSizes().map((size) {
                    final isSelected = _selectedSize == size;
                    final stock = _getStockForSize(size);
                    final isOutOfStock = stock == 0;
                    
                    return GestureDetector(
                      onTap: isOutOfStock ? null : () {
                        setState(() {
                          _selectedSize = size;
                          _quantity = 1;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              size,
                              style: GoogleFonts.goudyBookletter1911(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isOutOfStock
                                    ? Colors.grey[400]
                                    : (isSelected ? Colors.white : Colors.black),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isOutOfStock ? 'Out of stock' : '$stock available',
                              style: GoogleFonts.goudyBookletter1911(
                                fontSize: 12,
                                color: isOutOfStock
                                    ? Colors.grey[400]
                                    : (isSelected ? Colors.white70 : Colors.grey[600]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],
              Text(
                'Quantity',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            '$_quantity',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            final selectedVariant = _getSelectedVariant();
                            final maxStock = selectedVariant?.stockQuantity ?? widget.product.stockQuantity;
                            if (_quantity < maxStock) {
                              setState(() => _quantity++);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Max: ${_getSelectedVariant()?.stockQuantity ?? widget.product.stockQuantity}',
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
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
                    if (widget.variants.isNotEmpty && (_selectedColor == null || _selectedSize == null)) {
                      SnackBarHelper.showError(context, 'Please select color and size');
                      return;
                    }
                    widget.onConfirm(_getSelectedVariant(), _quantity);
                  },
                  child: Text(
                    widget.isAddToCart ? 'Add to Cart' : 'Buy Now',
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
      ),
    );
  }
}


// SDG Section Widget
class _SDGSection extends StatefulWidget {
  final String? sdg;

  const _SDGSection({this.sdg});

  @override
  State<_SDGSection> createState() => _SDGSectionState();
}

class _SDGSectionState extends State<_SDGSection> {
  bool _isExpanded = false;

  List<String> _getSDGImages(String sdgValue) {
    switch (sdgValue.toLowerCase()) {
      case 'handmade':
        return ['SDG5.png', 'SDG8.png'];
      case 'biodegradable':
        return ['SDG5.png', 'SDG12.png', 'SDG13.png'];
      case 'both':
        return ['SDG5.png', 'SDG8.png', 'SDG12.png', 'SDG13.png'];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sdg == null || widget.sdg!.isEmpty) {
      print('SDG Section - No SDG value');
      return const SizedBox.shrink();
    }

    print('SDG Section - SDG value: ${widget.sdg}');
    final sdgImages = _getSDGImages(widget.sdg!);
    print('SDG Section - Images to display: $sdgImages');
    
    if (sdgImages.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sustainable Development Goals',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.black87,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.start,
                children: sdgImages.map((imageName) {
                  final imagePath = 'static/images/$imageName';
                  print('SDG Section - Loading image: $imagePath');
                  return CachedNetworkImage(
                    imageUrl: ImageHelper.getImageUrl(imagePath),
                    width: 60,
                    height: 60,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) {
                      print('SDG Image error: $error for path: $imagePath');
                      return Container(
                        width: 60,
                        height: 60,
                        color: Colors.red[100],
                        child: const Icon(Icons.error, color: Colors.red, size: 20),
                      );
                    },
                  );
                }).toList(),
              ),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }
}

// Reviews Section Widget
class _ReviewsSection extends StatefulWidget {
  final int productId;

  const _ReviewsSection({required this.productId});

  @override
  State<_ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<_ReviewsSection> {
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = true;
  double _averageRating = 0.0;
  int _totalReviews = 0;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final response = await Supabase.instance.client
          .from('product_reviews')
          .select('''
            review_id,
            rating,
            review_text,
            created_at,
            buyers(first_name, last_name, profile_image)
          ''')
          .eq('product_id', widget.productId)
          .order('created_at', ascending: false)
          .limit(5);

      if (mounted) {
        setState(() {
          _reviews = List<Map<String, dynamic>>.from(response as List);
          _totalReviews = _reviews.length;
          if (_reviews.isNotEmpty) {
            _averageRating = _reviews
                    .map((r) => (r['rating'] as num).toDouble())
                    .reduce((a, b) => a + b) /
                _reviews.length;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(color: Colors.black)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall Rating Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                Text(
                  'Overall Rating',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _averageRating.toStringAsFixed(1),
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    5,
                    (index) => Icon(
                      index < _averageRating.floor()
                          ? Icons.star
                          : (index < _averageRating ? Icons.star_half : Icons.star_border),
                      size: 20,
                      color: const Color(0xFFFFD600),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Based on $_totalReviews ${_totalReviews == 1 ? 'review' : 'reviews'}',
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (_reviews.isEmpty) ...[
            const SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No reviews yet. Be the first to review this product!',
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 20),
            ...(_reviews.map((review) => _buildReviewCard(review))),
            if (_reviews.length > 3)
              Center(
                child: TextButton(
                  onPressed: () {
                    // TODO: Navigate to all reviews page
                  },
                  child: Text(
                    'View all reviews',
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final buyerData = review['buyers'] as Map<String, dynamic>?;
    final firstName = buyerData?['first_name'] ?? '';
    final lastName = buyerData?['last_name'] ?? '';
    final profileImage = buyerData?['profile_image'];
    final rating = review['rating'] as int;
    final reviewText = review['review_text'] as String?;
    final createdAt = DateTime.parse(review['created_at']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Image
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey[300]!, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: profileImage != null
                      ? CachedNetworkImage(
                          imageUrl: ImageHelper.getImageUrl(profileImage),
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Container(
                            color: const Color(0xFFD3BD9B),
                            child: Center(
                              child: Text(
                                firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Container(
                          color: const Color(0xFFD3BD9B),
                          child: Center(
                            child: Text(
                              firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$firstName $lastName'.trim().isEmpty
                          ? 'Anonymous'
                          : '$firstName $lastName',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(createdAt),
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Rating on the right
              Row(
                children: [
                  ...List.generate(
                    5,
                    (index) => Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      size: 18,
                      color: const Color(0xFFFFD600),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$rating/5',
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (reviewText != null && reviewText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 62),
              child: Text(
                reviewText,
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.7,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else {
      return '${(difference.inDays / 365).floor()} years ago';
    }
  }
}

// Tab Section Widget (Description and Feedbacks)
class _TabSection extends StatefulWidget {
  final Product product;
  final bool isGuestMode;
  final VoidCallback onChatWithSeller;

  const _TabSection({
    required this.product,
    required this.isGuestMode,
    required this.onChatWithSeller,
  });

  @override
  State<_TabSection> createState() => _TabSectionState();
}

class _TabSectionState extends State<_TabSection> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  double _shopRating = 0.0;
  int _productCount = 0;
  bool _isLoadingShopData = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadShopData();
  }

  Future<void> _loadShopData() async {
    if (widget.product.sellerId == null) return;
    
    try {
      print('Loading shop data for seller_id: ${widget.product.sellerId}');
      
      // Fetch shop rating from sellers table
      final sellerResponse = await Supabase.instance.client
          .from('sellers')
          .select('rating')
          .eq('seller_id', widget.product.sellerId!)
          .maybeSingle();
      
      print('Seller response: $sellerResponse');
      
      // Fetch product count
      final productsResponse = await Supabase.instance.client
          .from('products')
          .select('product_id')
          .eq('seller_id', widget.product.sellerId!);
      
      print('Products count: ${(productsResponse as List).length}');
      
      if (mounted) {
        setState(() {
          _shopRating = sellerResponse != null 
              ? (sellerResponse['rating'] ?? 0.0).toDouble() 
              : 0.0;
          _productCount = (productsResponse as List).length;
          _isLoadingShopData = false;
        });
        print('Shop data loaded - Rating: $_shopRating, Products: $_productCount');
      }
    } catch (e) {
      print('Error loading shop data: $e');
      if (mounted) {
        setState(() {
          _shopRating = 0.0;
          _productCount = 0;
          _isLoadingShopData = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.grey[300]!,
                width: 1.5,
              ),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey[600],
            labelStyle: GoogleFonts.playfairDisplay(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelStyle: GoogleFonts.playfairDisplay(
              fontSize: 16,
              fontWeight: FontWeight.normal,
            ),
            indicatorColor: Colors.black,
            indicatorWeight: 2,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: const [
              Tab(text: 'Description'),
              Tab(text: 'Feedbacks'),
            ],
          ),
        ),
        SizedBox(
          height: 600, // Fixed height for tab content
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildDescriptionTab(),
              _buildFeedbacksTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.product.description != null && widget.product.description!.isNotEmpty)
            Text(
              widget.product.description!,
              style: GoogleFonts.goudyBookletter1911(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.8,
              ),
            ),
          if (widget.product.sdg != null) ...[
            const SizedBox(height: 24),
            Divider(color: Colors.grey[300], thickness: 1.5),
            const SizedBox(height: 16),
            _SDGSection(sdg: widget.product.sdg),
          ],
          // Shop Information Section
          if (widget.product.shopName != null && widget.product.sellerId != null) ...[
            const SizedBox(height: 24),
            Divider(color: Colors.grey[300], thickness: 1.5),
            const SizedBox(height: 16),
            _buildShopInfo(),
          ],
        ],
      ),
    );
  }

  Widget _buildShopInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Shop Information',
            style: GoogleFonts.playfairDisplay(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Shop Logo
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ViewShopScreen(
                        sellerId: widget.product.sellerId!,
                        shopName: widget.product.shopName!,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: widget.product.shopLogo != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: CachedNetworkImage(
                            imageUrl: ImageHelper.getImageUrl(widget.product.shopLogo!),
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Container(
                              color: const Color(0xFFD3BD9B),
                              child: const Center(
                                child: Icon(Icons.store, color: Colors.white, size: 30),
                              ),
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFD3BD9B),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Center(
                            child: Icon(Icons.store, color: Colors.white, size: 30),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ViewShopScreen(
                          sellerId: widget.product.sellerId!,
                          shopName: widget.product.shopName!,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.shopName!,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          decoration: TextDecoration.underline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.star, size: 14, color: Colors.amber[700]),
                          const SizedBox(width: 4),
                          Text(
                            _isLoadingShopData 
                                ? '...' 
                                : (_shopRating > 0 ? _shopRating.toStringAsFixed(1) : 'No rating'),
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 12,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.inventory_2_outlined, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            _isLoadingShopData 
                                ? '...' 
                                : '$_productCount ${_productCount == 1 ? 'Product' : 'Products'}',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Visit Button
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Colors.black, width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ViewShopScreen(
                        sellerId: widget.product.sellerId!,
                        shopName: widget.product.shopName!,
                      ),
                    ),
                  );
                },
                child: Text(
                  'Visit',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbacksTab() {
    return _ReviewsSection(productId: widget.product.id);
  }
}

