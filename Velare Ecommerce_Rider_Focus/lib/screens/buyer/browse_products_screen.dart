import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/product_model.dart';
import '../../services/product_service.dart';
import '../../services/cart_service.dart';
import '../../services/favorite_service.dart';
import '../../services/notification_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/product_filter_modal.dart';
import '../../utils/image_helper.dart';
import 'product_detail_screen.dart';
import 'cart_screen.dart';
import 'notifications_screen.dart';
import 'chat_list_screen.dart';
import '../auth/login_screen.dart';

class BrowseProductsScreen extends StatefulWidget {
  final String? category;
  final bool isGuestMode;

  const BrowseProductsScreen({
    super.key,
    this.category,
    this.isGuestMode = false,
  });

  @override
  State<BrowseProductsScreen> createState() => _BrowseProductsScreenState();
}

class _BrowseProductsScreenState extends State<BrowseProductsScreen> {
  final ProductService _productService = ProductService();
  final CartService _cartService = CartService();
  final FavoriteService _favoriteService = FavoriteService();
  final NotificationService _notificationService = NotificationService();
  final TextEditingController _searchController = TextEditingController();

  late Future<List<Product>> _productsFuture;
  Product? _heroProduct;
  String _selectedCategory = 'All';
  int _cartCount = 0;
  int _notificationCount = 0;
  Set<int> _favoriteProductIds = {};
  bool _isLoggedIn = false;

  final List<Map<String, String>> _categories = [
    {'name': 'All', 'value': 'All'},
    {'name': 'Dresses & Skirts', 'value': 'Dresses & Skirts'},
    {'name': 'Tops & Blouses', 'value': 'Tops & Blouses'},
    {'name': 'Activewear & Yoga Pants', 'value': 'Activewear & Yoga Pants'},
    {'name': 'Lingerie & Sleepwear', 'value': 'Lingerie & Sleepwear'},
    {'name': 'Jackets & Coats', 'value': 'Jackets & Coats'},
    {'name': 'Shoes & Accessories', 'value': 'Shoes & Accessories'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.category ?? 'All';
    _checkLoginStatus();
    _loadProducts();
    _loadHeroProduct();
    if (_isLoggedIn) {
      _loadCounts();
      _loadFavorites();
    }
  }

  void _checkLoginStatus() {
    _isLoggedIn = !widget.isGuestMode && AuthService().currentUserId != null;
  }

  Future<void> _loadFavorites() async {
    if (!_isLoggedIn) return;

    final buyerId = _favoriteService.getCurrentBuyerId();
    if (buyerId != null) {
      try {
        final favorites = await _favoriteService.getFavorites(buyerId);
        if (mounted) {
          setState(() {
            _favoriteProductIds = favorites.map((f) => f.productId).toSet();
          });
        }
      } catch (e) {
        // Silently fail
      }
    }
  }

  void _loadProducts() {
    setState(() {
      if (_selectedCategory == 'All') {
        _productsFuture = _productService.getAllProducts();
      } else {
        _productsFuture = _productService.getProductsByCategory(
          _selectedCategory,
        );
      }
    });
  }

  Future<void> _loadHeroProduct() async {
    try {
      final products = await _productService.getAllProducts();
      if (products.isNotEmpty && mounted) {
        setState(() => _heroProduct = products.first);
      }
    } catch (e) {
      print('Error loading hero product: $e');
    }
  }

  Future<void> _loadCounts() async {
    if (!_isLoggedIn) return;

    final userId = AuthService().currentUserId;
    if (userId != null) {
      try {
        final cartItems = await _cartService.getCartItems(userId);
        final unreadCount = await _notificationService.getUnreadCount(userId);
        if (mounted) {
          setState(() {
            _cartCount = cartItems.length;
            _notificationCount = unreadCount;
          });
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
        title: Text(
          'Login Required',
          style: GoogleFonts.goudyBookletter1911(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'You need to login to $feature',
          style: GoogleFonts.goudyBookletter1911(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.goudyBookletter1911(color: Colors.grey),
            ),
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
            child: Text(
              'Login',
              style: GoogleFonts.goudyBookletter1911(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildCategoryTabs(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  _loadProducts();
                  _loadHeroProduct();
                  if (_isLoggedIn) {
                    await _loadCounts();
                    await _loadFavorites();
                  }
                },
                child: CustomScrollView(
                  slivers: [
                    if (_heroProduct != null) _buildHeroSection(),
                    _buildProductGrid(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Velare',
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              if (widget.isGuestMode)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                    ),
                    child: Text(
                      'Login',
                      style: GoogleFonts.goudyBookletter1911(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              if (!widget.isGuestMode) ...[
                _buildIconButton(
                  Icons.notifications_outlined,
                  _notificationCount,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildIconButton(
                  Icons.shopping_cart_outlined,
                  _cartCount,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CartScreen()),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChatListScreen()),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, int count, VoidCallback onPressed) {
    return Stack(
      children: [
        IconButton(icon: Icon(icon), onPressed: onPressed),
        if (count > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '$count',
                style: GoogleFonts.playfairDisplay(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products...',
                hintStyle: GoogleFonts.goudyBookletter1911(color: Colors.grey),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              style: GoogleFonts.goudyBookletter1911(),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  setState(() {
                    _productsFuture = _productService.searchProducts(value);
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () async {
              final filters = await showModalBottomSheet<Map<String, dynamic>>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const ProductFilterModal(),
              );
              if (filters != null) {
                // Apply filters
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category['value'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = category['value']!;
                  _loadProducts();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? Colors.black : Colors.grey[300]!,
                  ),
                ),
                child: Text(
                  category['name']!,
                  style: GoogleFonts.goudyBookletter1911(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroSection() {
    if (_heroProduct == null)
      return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(
                productId: _heroProduct!.id,
                isGuestMode: widget.isGuestMode,
              ),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.all(16),
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: ImageHelper.getImageUrl(
                    _heroProduct!.primaryImage ?? '',
                  ),
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.error, size: 50),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _heroProduct!.productName,
                        style: GoogleFonts.playfairDisplay(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₱${_heroProduct!.price.toStringAsFixed(2)}',
                        style: GoogleFonts.playfairDisplay(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _buildProductGrid() {
    return FutureBuilder<List<Product>>(
      future: _productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(color: Colors.black),
            ),
          );
        }
        if (snapshot.hasError) {
          return SliverFillRemaining(
            child: Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: GoogleFonts.goudyBookletter1911(),
              ),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Text(
                'No products found',
                style: GoogleFonts.goudyBookletter1911(),
              ),
            ),
          );
        }

        final products = snapshot.data!;
        return SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildProductCard(products[index]),
              childCount: products.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductCard(Product product) {
    final isFavorite = _favoriteProductIds.contains(product.id);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(
              productId: product.id,
              isGuestMode: widget.isGuestMode,
            ),
          ),
        ).then((_) {
          if (_isLoggedIn) {
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
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child:
                        product.primaryImage != null &&
                            product.primaryImage!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: ImageHelper.getImageUrl(
                              product.primaryImage!,
                            ),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[100],
                              child: Center(
                                child: Icon(
                                  Icons.image_outlined,
                                  size: 50,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ),
                          )
                        : Container(
                            width: double.infinity,
                            height: double.infinity,
                            color: Colors.grey[100],
                            child: Center(
                              child: Icon(
                                Icons.image_outlined,
                                size: 50,
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                  ),
                  if (!widget.isGuestMode)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => _toggleFavorite(product.id),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite
                                ? const Color(0xFFFFD700)
                                : Colors.grey,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      product.productName,
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₱${product.price.toStringAsFixed(2)}',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(int productId) async {
    if (widget.isGuestMode) {
      _showLoginPrompt('add to favorites');
      return;
    }

    final buyerId = _favoriteService.getCurrentBuyerId();
    if (buyerId == null) {
      _showLoginPrompt('add to favorites');
      return;
    }

    try {
      if (_favoriteProductIds.contains(productId)) {
        final favorites = await _favoriteService.getFavorites(buyerId);
        final fav = favorites.firstWhere((f) => f.productId == productId);
        await _favoriteService.removeFromFavorites(fav.favoriteId);
        setState(() => _favoriteProductIds.remove(productId));
      } else {
        await _favoriteService.addToFavorites(buyerId, productId);
        setState(() => _favoriteProductIds.add(productId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e',
              style: GoogleFonts.goudyBookletter1911(),
            ),
          ),
        );
      }
    }
  }
}
