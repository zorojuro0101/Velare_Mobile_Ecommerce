import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
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

import '../../utils/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
class BrowseProductsScreen extends StatefulWidget {
  final String? category;
  final bool isGuestMode;
  final Function(VoidCallback)? onResetCallback;

  const BrowseProductsScreen({
    super.key,
    this.category,
    this.isGuestMode = false,
    this.onResetCallback,
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
    // Register reset callback
    widget.onResetCallback?.call(resetToAllProducts);
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

  // Method to reset to "All Products" view
  void resetToAllProducts() {
    if (_selectedCategory != 'All') {
      setState(() {
        _selectedCategory = 'All';
        _searchController.clear();
        _loadProducts();
        _loadHeroProducts();
      });
    }
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
              backgroundColor: AppColors.onSurface(context),
              foregroundColor: AppColors.surface(context),
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
                borderRadius: BorderRadius.circular(5.r),
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
                      color: AppColors.textBody(context),
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
        backgroundColor: AppColors.surface(context),
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
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                        child: Text(
                          _selectedCategory == 'All' ? 'All Products' : _selectedCategory,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 24.sp,
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
      padding: EdgeInsets.all(16.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Velare',
            style: GoogleFonts.playfairDisplay(
              fontSize: 28.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              if (widget.isGuestMode)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(5.r),
                    border: Border.all(color: AppColors.onSurface(context), width: 1.5),
                  ),
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: Icon(Icons.person_outline, color: AppColors.onSurface(context), size: 16.r),
                    label: Text(
                      'Login',
                      style: GoogleFonts.goudyBookletter1911(
                        color: AppColors.onSurface(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 13.sp,
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
                SizedBox(width: 8.w),
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
                SizedBox(width: 8.w),
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
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search products...',
          hintStyle: GoogleFonts.goudyBookletter1911(color: Colors.grey),
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide(color: AppColors.border(context)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide(color: AppColors.border(context)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide(color: AppColors.onSurface(context)),
          ),
          filled: true,
          fillColor: AppColors.scaffoldBackground(context),
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
      {'name': 'Dresses', 'value': 'Dresses', 'image': 'assets/images/categories/dresses.jpeg'},
      {'name': 'Skirts', 'value': 'Skirts', 'image': 'assets/images/categories/skirts.jpeg'},
      {'name': 'Tops', 'value': 'Tops', 'image': 'assets/images/categories/tops.jpeg'},
      {'name': 'Blouses', 'value': 'Blouses', 'image': 'assets/images/categories/blouses.jpeg'},
      {'name': 'Activewear', 'value': 'Activewear', 'image': 'assets/images/categories/activewear.jpeg'},
      {'name': 'Yoga Pants', 'value': 'Yoga Pants', 'image': 'assets/images/categories/yogapants.jpeg'},
      {'name': 'Lingerie', 'value': 'Lingerie', 'image': 'assets/images/categories/lingerie.jpeg'},
      {'name': 'Sleepwear', 'value': 'Sleepwear', 'image': 'assets/images/categories/sleepwear.jpeg'},
      {'name': 'Jackets', 'value': 'Jackets', 'image': 'assets/images/categories/jackets.jpeg'},
      {'name': 'Coats', 'value': 'Coats', 'image': 'assets/images/categories/coats.jpeg'},
      {'name': 'Shoes', 'value': 'Shoes', 'image': 'assets/images/categories/shoes.jpeg'},
      {'name': 'Accessories', 'value': 'Accessories', 'image': 'assets/images/categories/accessories.jpeg'},
    ];

    // Triple the categories for infinite scroll
    final infiniteCategories = [...categories, ...categories, ...categories];

    return Container(
      height: 300.h, // Increased carousel container height
      margin: EdgeInsets.symmetric(vertical: 16.h),
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
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h), // Added vertical padding
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
                width: 165.w, // Increased card width
                margin: EdgeInsets.only(right: 12.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.r),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        category['image']!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: const Color(0xFFD3BD9B),
                          child: Center(
                            child: Icon(
                              Icons.category,
                              size: 40.r,
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
                        bottom: 8,
                        left: 8,
                        right: 8,
                        child: Text(
                          category['name']!,
                          style: GoogleFonts.playfairDisplay(
                            color: AppColors.alwaysWhite,
                            fontSize: 14.sp,
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
          margin: EdgeInsets.all(16.w),
          height: 200.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5.r),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: ImageHelper.getImageUrl(currentProduct.primaryImage ?? ''),
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: AppColors.surfaceVariant2(context),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: AppColors.surfaceVariant2(context),
                    child: Icon(Icons.error, size: 50.r),
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
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(5.r),
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
                        Icon(badgeIcon, color: AppColors.alwaysWhite, size: 16.r),
                        SizedBox(width: 4.w),
                        Text(
                          badgeText,
                          style: GoogleFonts.playfairDisplay(
                            color: AppColors.alwaysWhite,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5.sp,
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
                          color: AppColors.alwaysWhite,
                          fontSize: 24.sp,
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
                      SizedBox(height: 4.h),
                      Text(
                        '₱${currentProduct.price.toStringAsFixed(2)}',
                        style: GoogleFonts.playfairDisplay(
                          color: AppColors.alwaysWhite,
                          fontSize: 20.sp,
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
          return SliverFillRemaining(
            child: Center(child: CircularProgressIndicator(color: AppColors.onSurface(context))),
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
          padding: EdgeInsets.all(16.w),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: 2,
            crossAxisSpacing: 16.w,
            mainAxisSpacing: 16.h,
            childCount: products.length,
            itemBuilder: (context, index) => _buildProductCard(products[index]),
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
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(12.r),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
                    child: product.primaryImage != null && product.primaryImage!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: ImageHelper.getImageUrl(product.primaryImage!),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: AppColors.surfaceVariant2(context),
                              child: const Center(child: CircularProgressIndicator()),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: AppColors.surfaceVariant(context),
                              child: Center(
                                child: Icon(Icons.image_outlined, size: 50.r, color: AppColors.textFaint(context)),
                              ),
                            ),
                          )
                        : Container(
                            width: double.infinity,
                            height: double.infinity,
                            color: AppColors.surfaceVariant(context),
                            child: Center(
                              child: Icon(Icons.image_outlined, size: 50.r, color: AppColors.textFaint(context)),
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
                          padding: EdgeInsets.all(6.w),
                          decoration: BoxDecoration(
                            color: AppColors.surface(context),
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
                            size: 20.r,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.productName,
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    _longPressedProductId == product.id && product.materials != null
                        ? product.materials!
                        : '₱${product.price.toStringAsFixed(2)}',
                    style: _longPressedProductId == product.id && product.materials != null
                        ? GoogleFonts.goudyBookletter1911(
                            fontSize: 13.sp,
                            color: AppColors.textMuted(context),
                            fontStyle: FontStyle.italic,
                          )
                        : GoogleFonts.playfairDisplay(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
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
