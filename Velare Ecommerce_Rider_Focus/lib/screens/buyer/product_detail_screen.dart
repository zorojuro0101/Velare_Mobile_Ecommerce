import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/product_model.dart';
import '../../services/product_service.dart';
import '../../services/cart_service.dart';
import '../../services/favorite_service.dart';
import '../../services/chat_service.dart';
import '../../utils/image_helper.dart';
import 'cart_screen.dart';
import 'chat_conversation_screen.dart';
import 'view_shop_screen.dart';
import '../auth/login_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;
  final bool isGuestMode;

  const ProductDetailScreen({
    super.key,
    required this.productId,
    this.isGuestMode = false,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final ProductService _productService = ProductService();
  final CartService _cartService = CartService();
  final FavoriteService _favoriteService = FavoriteService();
  final ChatService _chatService = ChatService();
  
  late Future<Product> _productFuture;
  bool _isFavorite = false;
  int _selectedImageIndex = 0;
  String? _selectedColor;
  String? _selectedSize;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    print('ProductDetail - Loading product ID: ${widget.productId}');
    _productFuture = _productService.getProductById(widget.productId).then((product) {
      print('ProductDetail - Product loaded: ${product.productName}');
      print('ProductDetail - Primary image: ${product.primaryImage}');
      print('ProductDetail - Additional images: ${product.additionalImages}');
      return product;
    });
    _checkFavorite();
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
        final favorites = await _favoriteService.getFavorites(buyerId);
        final fav = favorites.firstWhere((f) => f.productId == widget.productId);
        await _favoriteService.removeFromFavorites(fav.favoriteId);
      } else {
        await _favoriteService.addToFavorites(buyerId, widget.productId);
      }
      setState(() => _isFavorite = !_isFavorite);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isFavorite ? 'Added to favorites' : 'Removed from favorites',
              style: GoogleFonts.goudyBookletter1911(),
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e', style: GoogleFonts.goudyBookletter1911())),
        );
      }
    }
  }

  Future<void> _addToCart(Product product) async {
    if (widget.isGuestMode) {
      _showLoginPrompt('add items to cart');
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _showLoginPrompt('add items to cart');
      return;
    }

    try {
      await _cartService.addToCart(
        userId: userId,
        productId: product.id,
        sellerId: product.sellerId ?? '',
        quantity: _quantity,
        color: _selectedColor,
        size: _selectedSize,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added to cart', style: GoogleFonts.goudyBookletter1911()),
            action: SnackBarAction(
              label: 'View Cart',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CartScreen()),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e', style: GoogleFonts.goudyBookletter1911())),
        );
      }
    }
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

          return CustomScrollView(
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(child: _buildImageGallery(images)),
              SliverToBoxAdapter(child: _buildProductInfo(product)),
              SliverToBoxAdapter(child: _buildDescription(product)),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: _buildBottomBar(product),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      pinned: true,
      actions: [
        if (!widget.isGuestMode)
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () async {
              final userId = Supabase.instance.client.auth.currentUser?.id;
              final product = await _productFuture;
              
              if (userId != null && product.sellerId != null) {
                final conversation = await _chatService.getOrCreateConversation(
                  buyerId: userId,
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
              }
            },
          ),
        IconButton(
          icon: Icon(
            _isFavorite ? Icons.favorite : Icons.favorite_border,
            color: _isFavorite ? const Color(0xFFFFD700) : Colors.black,
          ),
          onPressed: _toggleFavorite,
        ),
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: () {},
        ),
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

    return Column(
      children: [
        SizedBox(
          height: 400,
          child: PageView.builder(
            itemCount: images.length,
            onPageChanged: (index) => setState(() => _selectedImageIndex = index),
            itemBuilder: (context, index) {
              return CachedNetworkImage(
                imageUrl: getImageUrl(images[index]),
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _selectedImageIndex == index
                        ? Colors.black
                        : Colors.grey[300],
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
          const SizedBox(height: 8),
          Text(
            '₱${product.price.toStringAsFixed(2)}',
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          if (product.shopName != null)
            GestureDetector(
              onTap: () {
                if (product.sellerId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ViewShopScreen(
                        sellerId: product.sellerId!,
                        shopName: product.shopName!,
                      ),
                    ),
                  );
                }
              },
              child: Row(
                children: [
                  const Icon(Icons.store, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    product.shopName!,
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 14,
                      color: Colors.grey[700],
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey[600]),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                '${product.stockQuantity} in stock',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 14,
                  color: product.stockQuantity > 0 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildQuantitySelector(),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector() {
    return Row(
      children: [
        Text('Quantity:', style: GoogleFonts.goudyBookletter1911(fontSize: 16)),
        const SizedBox(width: 16),
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
                  style: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => setState(() => _quantity++),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescription(Product product) {
    if (product.description == null || product.description!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Description',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            product.description!,
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
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
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (!widget.isGuestMode)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () async {
                final userId = Supabase.instance.client.auth.currentUser?.id;
                if (userId != null && product.sellerId != null) {
                  final conversation = await _chatService.getOrCreateConversation(
                    buyerId: userId,
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
                } else {
                  _showLoginPrompt('chat with seller');
                }
              },
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
        ],
      ),
    );
  }
}
