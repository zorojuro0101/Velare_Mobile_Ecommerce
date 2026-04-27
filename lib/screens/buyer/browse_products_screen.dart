import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../../models/product_model.dart';
import '../../services/product_service.dart';
import '../../services/cart_service.dart';
import '../../services/favorite_service.dart';
import '../../services/notification_service.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/icon_badge.dart';
import '../../utils/image_helper.dart';
import '../../utils/snackbar_helper.dart';
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
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _carouselController = ScrollController();
  
  late Future<List<Product>> _productsFuture;
  Product? _bestSellerProduct;
  Product? _topRatedProduct;
  Product? _newArrivalProduct;
  String _selectedCategory = 'All';
  int _cartCount = 0;
  int _notificationCount = 0;
  int _unreadChatCount = 0;
  Set<int> _favoriteProductIds = {};
  bool _isLoggedIn = false;
  int? _longPressedProductId;
  bool _isAutoScrolling = true;
  Timer? _autoScrollTimer;
  Timer? _bannerTimer;
  int _currentBannerIndex = 0; // 0=Best Seller, 1=Top Rated, 2=New Arrival

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.category ?? 'All';
    _checkLoginStatus();
    _loadProducts();
    _loadHeroProducts();
    if (_isLoggedIn) {
      _loadCounts();
      _loadFavorites();
    }
    // Start continuous smooth auto-scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startContinuousScroll();
      _startBannerRotation();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _carouselController.dispose();
    _autoScrollTimer?.cancel();
    _bannerTimer?.cancel();
    super.dispose();
  }

  void _startBannerRotation() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _currentBannerIndex = (_currentBannerIndex + 1) % 3;
        });
      }
    });
  }

  void _startContinuousScroll() {
    if (!mounted) return;
    _autoScrollTimer?.cancel();
    
    // Continuous smooth scrolling
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted && _isAutoScrolling && _carouselController.hasClients) {
        final maxScroll = _carouselController.position.maxScrollExtent;
        final currentScroll = _carouselController.offset;
        final delta = 0.5; // pixels per frame (slow continuous movement)
        
        if (currentScroll >= maxScroll) {
          // Reset to beginning for infinite loop
          _carouselController.jumpTo(0);
        } else {
          _carouselController.jumpTo(currentScroll + delta);
        }
      }
    });
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
        _productsFuture = _productService.getProductsByCategory(_selectedCategory);
      }
    });
  }

  Future<void> _loadHeroProducts() async {
    try {
      if (_selectedCategory == 'All') {
        // Load overall best products
        _bestSellerProduct = await _productService.getBestSellerProduct();
        _topRatedProduct = await _productService.getTopRatedProduct();
        _newArrivalProduct = await _productService.getNewestProduct();
      } else {
        // Load category-specific best products
        _bestSellerProduct = await _productService.getBestSellerProductByCategory(_selectedCategory);
        _topRatedProduct = await _productService.getTopRatedProductByCategory(_selectedCategory);
        _newArrivalProduct = await _productService.getNewestProductByCategory(_selectedCategory);
      }
      if (mounted) setState(() {});
    } catch (e) {
      print('Error loading hero products: $e');
    }
  }

  Future<void> _loadCounts() async {
    if (!_isLoggedIn) return;
    
    final userId = AuthService().currentUserId;
    final buyerId = _cartService.getCurrentBuyerId();
    
    if (userId != null && buyerId != null) {
      try {
        // Load all counts in parallel for faster loading
        final results = await Future.wait([
          _cartService.getCartItems(buyerId),
          _notificationService.getUnreadCount(userId),
          _chatService.getUnreadCount(buyerId, userId),
        ]);
        
        if (mounted) {
          setState(() {
            _cartCount = (results[0] as List).length;
            _notificationCount = results[1] as int;
            _unreadChatCount = results[2] as int;
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Always prevent default back behavior
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return; // Already popped, do nothing
        
        if (widget.isGuestMode) {
          // Show confirmation dialog before quitting in guest mode
          final shouldQuit = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              title: Text(
                'Quit App',
                style: GoogleFonts.playfairDisplay(
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                'Are you sure you want to quit?',
                style: GoogleFonts.goudyBookletter1911(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.goudyBookletter1911(
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    'Quit',
                    style: GoogleFonts.goudyBookletter1911(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
          
          if (shouldQuit == true) {
            SystemNavigator.pop();
          }
        }
        // If not guest mode, do nothing (handled by BuyerHome)
      },
      child: Scaffold(
        backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  _loadProducts();
                  _loadHeroProducts();
                  if (_isLoggedIn) {
                    await _loadCounts();
                    await _loadFavorites();
                  }
                },
                child: CustomScrollView(
                  slivers: [
                    // 1. Single Hero Banner (rotates every 5 seconds)
                    _buildRotatingHeroBanner(),
                    // 2. Category Carousel
                    SliverToBoxAdapter(child: _buildCategoryCarousel()),
                    // 3. Category Title
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          _selectedCategory == 'All' ? 'All Products' : _selectedCategory,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // 4. Products Grid
                    _buildProductGrid(),
                  ],
                ),
              ),
            ),
          ],
        ),
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.person_outline, color: Colors.black, size: 16),
                    label: Text(
                      'Login',
                      style: GoogleFonts.goudyBookletter1911(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              if (!widget.isGuestMode) ...[
                NotificationDot(
                  icon: Icons.notifications_outlined,
                  showDot: _notificationCount > 0,
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                    );
                    _loadCounts();
                  },
                ),
                const SizedBox(width: 8),
                IconBadge(
                  icon: Icons.shopping_cart_outlined,
                  count: _cartCount,
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CartScreen()),
                    );
                    _loadCounts();
                  },
                ),
                const SizedBox(width: 8),
                NotificationDot(
                  icon: Icons.chat_bubble_outline,
                  showDot: _unreadChatCount > 0,
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChatListScreen()),
                    );
                    _loadCounts();
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    );
  }

  Widget _buildCategoryCarousel() {
    final categories = [
      {'name': 'Dresses', 'value': 'Dresses', 'image': 'https://via.placeholder.com/600x400/D3BD9B/FFFFFF?text=Dresses'},
      {'name': 'Skirts', 'value': 'Skirts', 'image': 'https://via.placeholder.com/600x400/C4A77D/FFFFFF?text=Skirts'},
      {'name': 'Tops', 'value': 'Tops', 'image': 'https://via.placeholder.com/600x400/B8956A/FFFFFF?text=Tops'},
      {'name': 'Blouses', 'value': 'Blouses', 'image': 'https://via.placeholder.com/600x400/A88558/FFFFFF?text=Blouses'},
      {'name': 'Activewear', 'value': 'Activewear', 'image': 'https://via.placeholder.com/600x400/9A7547/FFFFFF?text=Activewear'},
      {'name': 'Yoga Pants', 'value': 'Yoga Pants', 'image': 'https://via.placeholder.com/600x400/8B6536/FFFFFF?text=Yoga+Pants'},
      {'name': 'Lingerie', 'value': 'Lingerie', 'image': 'https://via.placeholder.com/600x400/7D5626/FFFFFF?text=Lingerie'},
      {'name': 'Sleepwear', 'value': 'Sleepwear', 'image': 'https://via.placeholder.com/600x400/6F4716/FFFFFF?text=Sleepwear'},
      {'name': 'Jackets', 'value': 'Jackets', 'image': 'https://via.placeholder.com/600x400/613808/FFFFFF?text=Jackets'},
      {'name': 'Coats', 'value': 'Coats', 'image': 'https://via.placeholder.com/600x400/532A00/FFFFFF?text=Coats'},
      {'name': 'Shoes', 'value': 'Shoes', 'image': 'https://via.placeholder.com/600x400/D3BD9B/FFFFFF?text=Shoes'},
      {'name': 'Accessories', 'value': 'Accessories', 'image': 'https://via.placeholder.com/600x400/C4A77D/FFFFFF?text=Accessories'},
    ];

    // Triple the categories for infinite scroll
    final infiniteCategories = [...categories, ...categories, ...categories];

    return Container(
      height: 240,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification) {
            if (notification.dragDetails != null) {
              setState(() => _isAutoScrolling = false);
              _autoScrollTimer?.cancel();
            }
          } else if (notification is ScrollEndNotification) {
            if (notification.dragDetails != null) {
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  setState(() => _isAutoScrolling = true);
                  _startContinuousScroll();
                }
              });
            }
          }
          return false;
        },
        child: ListView.builder(
          controller: _carouselController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: infiniteCategories.length,
          itemBuilder: (context, index) {
            final category = infiniteCategories[index];
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = category['value']!;
                  _loadProducts();
                  _loadHeroProducts(); // Reload hero products for new category
                });
              },
              child: Container(
                width: 200,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: category['image']!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: const Color(0xFFD3BD9B),
                          child: Center(
                            child: Icon(
                              Icons.category,
                              size: 40,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.6),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: Text(
                          category['name']!,
                          style: GoogleFonts.playfairDisplay(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRotatingHeroBanner() {
    Product? currentProduct;
    String badgeText;
    Color badgeColor;
    IconData badgeIcon;

    switch (_currentBannerIndex) {
      case 0:
        currentProduct = _bestSellerProduct;
        badgeText = 'BEST SELLER';
        badgeColor = const Color(0xFFFFD700); // Gold
        badgeIcon = Icons.star;
        break;
      case 1:
        currentProduct = _topRatedProduct;
        badgeText = 'TOP RATED';
        badgeColor = const Color(0xFFB8860B); // Dark Gold
        badgeIcon = Icons.thumb_up;
        break;
      case 2:
        currentProduct = _newArrivalProduct;
        badgeText = 'NEW ARRIVAL';
        badgeColor = const Color(0xFF8B4513); // Brown
        badgeIcon = Icons.fiber_new;
        break;
      default:
        currentProduct = _bestSellerProduct;
        badgeText = 'BEST SELLER';
        badgeColor = const Color(0xFFFFD700);
        badgeIcon = Icons.star;
    }

    if (currentProduct == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(
                productId: currentProduct!.id,
                isGuestMode: widget.isGuestMode,
                onCartUpdated: () {
                  if (_isLoggedIn) {
                    _loadCounts();
                  }
                },
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
          margin: const EdgeInsets.all(16),
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: ImageHelper.getImageUrl(currentProduct.primaryImage ?? ''),
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
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
                // Badge - Upper Right Corner
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(badgeIcon, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          badgeText,
                          style: GoogleFonts.playfairDisplay(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                offset: const Offset(1, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
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
                        currentProduct.productName,
                        style: GoogleFonts.playfairDisplay(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.7),
                              offset: const Offset(2, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₱${currentProduct.price.toStringAsFixed(2)}',
                        style: GoogleFonts.playfairDisplay(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.7),
                              offset: const Offset(2, 2),
                              blurRadius: 4,
                            ),
                          ],
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
            child: Center(child: CircularProgressIndicator(color: Colors.black)),
          );
        }
        if (snapshot.hasError) {
          return SliverFillRemaining(
            child: Center(
              child: Text('Error: ${snapshot.error}', style: GoogleFonts.goudyBookletter1911()),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Text('No products found', style: GoogleFonts.goudyBookletter1911()),
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
              onCartUpdated: () {
                if (_isLoggedIn) {
                  _loadCounts();
                }
              },
            ),
          ),
        ).then((_) {
          if (_isLoggedIn) {
            _loadFavorites();
            _loadCounts();
          }
        });
      },
      onLongPressStart: (_) {
        setState(() {
          _longPressedProductId = product.id;
        });
      },
      onLongPressEnd: (_) {
        setState(() {
          _longPressedProductId = null;
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
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: product.primaryImage != null && product.primaryImage!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: ImageHelper.getImageUrl(product.primaryImage!),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[200],
                              child: const Center(child: CircularProgressIndicator()),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[100],
                              child: Center(
                                child: Icon(Icons.image_outlined, size: 50, color: Colors.grey[400]),
                              ),
                            ),
                          )
                        : Container(
                            width: double.infinity,
                            height: double.infinity,
                            color: Colors.grey[100],
                            child: Center(
                              child: Icon(Icons.image_outlined, size: 50, color: Colors.grey[400]),
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
                            color: isFavorite ? const Color(0xFFFFD700) : Colors.grey,
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
                      _longPressedProductId == product.id && product.materials != null
                          ? product.materials!
                          : '₱${product.price.toStringAsFixed(2)}',
                      style: _longPressedProductId == product.id && product.materials != null
                          ? GoogleFonts.goudyBookletter1911(
                              fontSize: 13,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            )
                          : GoogleFonts.playfairDisplay(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
        SnackBarHelper.showError(context, 'Error: $e');
      }
    }
  }
}
