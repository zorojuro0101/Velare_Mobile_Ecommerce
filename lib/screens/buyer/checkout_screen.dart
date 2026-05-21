import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/cart_model.dart';
import '../../services/order_service.dart';
import '../../services/auth_service.dart';
import '../../services/shipping_service.dart';
import '../../utils/image_helper.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/address_selector_modal.dart';
import 'order_history_screen.dart';

import '../../utils/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
class CheckoutScreen extends StatefulWidget {
  final List<CartItem> items;
  final double totalAmount;
  final int? preselectedVoucherId;

  const CheckoutScreen({
    super.key,
    required this.items,
    required this.totalAmount,
    this.preselectedVoucherId,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> with SingleTickerProviderStateMixin {
  final OrderService _orderService = OrderService();
  final _supabase = Supabase.instance.client;
  final _authService = AuthService();
  
  List<Map<String, dynamic>> _savedAddresses = [];
  Map<String, dynamic>? _selectedAddress;
  List<Map<String, dynamic>> _availableVouchers = [];
  Map<String, dynamic>? _selectedVoucher;
  bool _isLoading = false;
  bool _isLoadingAddresses = true;
  bool _isLoadingVouchers = true;
  bool _isLoadingShipping = false;
  int _currentImageIndex = 0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Shipping state
  final ShippingService _shippingService = ShippingService();
  List<ShopShippingResult> _shopShippingResults = [];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(_fadeController);
    _startImageCarousel();
    _loadSavedAddresses();
    _loadAvailableVouchers();
  }

  void _startImageCarousel() {
    if (widget.items.length > 1) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _fadeController.forward().then((_) {
            setState(() {
              _currentImageIndex = (_currentImageIndex + 1) % widget.items.length;
            });
            _fadeController.reverse().then((_) {
              _startImageCarousel();
            });
          });
        }
      });
    }
  }

  Future<void> _loadAvailableVouchers() async {
    setState(() => _isLoadingVouchers = true);
    try {
      print('=== LOADING VOUCHERS DEBUG ===');
      await _authService.initialize();
      var buyerId = _authService.currentBuyerId;
      
      if (buyerId == null) {
        final userId = _authService.currentUserId;
        print('User ID: $userId');
        if (userId != null) {
          final buyerData = await _supabase
              .from('buyers')
              .select('buyer_id')
              .eq('user_id', userId)
              .maybeSingle();
          
          if (buyerData != null) {
            buyerId = buyerData['buyer_id'].toString();
          }
        }
      }
      
      print('Buyer ID: $buyerId');
      
      if (buyerId != null) {
        // Get seller IDs from cart items
        final sellerIds = widget.items
            .map((item) => int.tryParse(item.sellerId))
            .whereType<int>()
            .toSet()
            .toList();

        print('Cart items count: ${widget.items.length}');
        print('Cart seller IDs: $sellerIds');

        // Get vouchers that are offered by sellers in the cart
        final sellerVouchersResponse = await _supabase
            .from('seller_vouchers')
            .select('voucher_id, seller_id')
            .inFilter('seller_id', sellerIds);

        print('Seller vouchers response: $sellerVouchersResponse');

        // Create a map of voucher_id to seller_id for later use
        final voucherToSellerMap = <int, int>{};
        for (var sv in sellerVouchersResponse as List) {
          voucherToSellerMap[sv['voucher_id'] as int] = sv['seller_id'] as int;
        }

        final applicableVoucherIds = voucherToSellerMap.keys.toList();

        print('Applicable voucher IDs from seller_vouchers: $applicableVoucherIds');
        print('Voucher to Seller mapping: $voucherToSellerMap');

        if (applicableVoucherIds.isEmpty) {
          print('No applicable vouchers found in seller_vouchers table');
          setState(() {
            _availableVouchers = [];
            _isLoadingVouchers = false;
          });
          return;
        }

        // Get buyer's vouchers that are applicable
        print('Querying buyer_vouchers for buyer_id: $buyerId');
        final today = DateTime.now().toIso8601String().split('T')[0]; // Get date only
        print('Current date for expiry check: $today');
        
        try {
          // First, get all buyer vouchers without filters to debug
          print('Fetching all buyer vouchers...');
          final allBuyerVouchers = await _supabase
              .from('buyer_vouchers')
              .select('buyer_voucher_id, voucher_id, times_remaining')
              .eq('buyer_id', int.parse(buyerId));
          print('All buyer vouchers (no filters): $allBuyerVouchers');
        } catch (e) {
          print('Error fetching all buyer vouchers: $e');
        }
        
        // Now get with filters - using correct column names
        print('Fetching filtered buyer vouchers...');
        final response = await _supabase
            .from('buyer_vouchers')
            .select('''
              *,
              vouchers!inner (
                voucher_id,
                voucher_name,
                voucher_type,
                discount_percent,
                start_date,
                end_date,
                description
              )
            ''')
            .eq('buyer_id', int.parse(buyerId))
            .inFilter('voucher_id', applicableVoucherIds)
            .gt('times_remaining', 0)
            .gte('vouchers.end_date', today);
        
        print('Buyer vouchers response (with filters): $response');
        
        final vouchers = List<Map<String, dynamic>>.from(response);
        
        // Add seller_id to each voucher for filtering
        for (var voucher in vouchers) {
          final voucherId = voucher['vouchers']['voucher_id'] as int;
          voucher['seller_id'] = voucherToSellerMap[voucherId];
        }
        
        print('Available vouchers count: ${vouchers.length}');
        if (vouchers.isNotEmpty) {
          print('Voucher details: ${vouchers.map((v) => '${v['vouchers']['voucher_name']} (Seller: ${v['seller_id']})').toList()}');
        }

        setState(() {
          _availableVouchers = vouchers;
          _isLoadingVouchers = false;
        });

        // Auto-select voucher if preselected
        if (widget.preselectedVoucherId != null && vouchers.isNotEmpty) {
          print('Preselected voucher ID: ${widget.preselectedVoucherId}');
          final preselected = vouchers.firstWhere(
            (v) => v['vouchers']['voucher_id'] == widget.preselectedVoucherId,
            orElse: () => {},
          );
          if (preselected.isNotEmpty) {
            setState(() {
              _selectedVoucher = preselected;
            });
            print('Auto-selected voucher: ${preselected['vouchers']['voucher_name']}');
          } else {
            print('Preselected voucher not found in available vouchers');
          }
        }
      } else {
        print('No buyer ID found');
        setState(() => _isLoadingVouchers = false);
      }
      print('=== END VOUCHERS DEBUG ===');
    } catch (e) {
      print('Error loading vouchers: $e');
      print('Error stack trace: ${StackTrace.current}');
      setState(() => _isLoadingVouchers = false);
    }
  }

  void _selectVoucher(Map<String, dynamic> voucher) {
    setState(() {
      // Toggle: if already selected, deselect it
      if (_selectedVoucher?['buyer_voucher_id'] == voucher['buyer_voucher_id']) {
        _selectedVoucher = null;
      } else {
        _selectedVoucher = voucher;
      }
    });
  }

  double _calculateDiscount() {
    if (_selectedVoucher == null) return 0.0;
    
    final voucherData = _selectedVoucher!['vouchers'];
    final voucherType = voucherData['voucher_type'];
    final discountPercent = (voucherData['discount_percent'] as num?)?.toDouble() ?? 0.0;
    final voucherSellerId = _selectedVoucher!['seller_id'];
    
    // For free shipping vouchers, return 0 (shipping discount handled separately)
    if (voucherType == 'free_shipping') {
      return 0.0;
    }
    
    // Calculate discount only for items from the voucher's seller
    double applicableSubtotal = 0.0;
    for (var item in widget.items) {
      final itemSellerId = int.tryParse(item.sellerId);
      if (itemSellerId == voucherSellerId) {
        applicableSubtotal += item.totalPrice;
      }
    }
    
    // Calculate percentage discount on applicable items only
    double discount = applicableSubtotal * (discountPercent / 100);
    
    return discount;
  }

  /// Raw total of all shops' shipping fees (no voucher applied).
  double _calculateShippingFee() {
    if (_shopShippingResults.isEmpty) {
      // Fallback: ₱49 flat per shop while computing
      final uniqueShops = widget.items.map((item) => item.shopName).toSet();
      return uniqueShops.length * 49.0;
    }
    return _shopShippingResults.fold(0.0, (sum, r) => sum + r.fee);
  }

  /// Total shipping fee after applying a free-shipping voucher (if any).
  double _getTotalShippingFee() {
    if (_selectedVoucher != null) {
      final voucherData = _selectedVoucher!['vouchers'];
      final voucherType = voucherData['voucher_type'];
      final voucherSellerId = _selectedVoucher!['seller_id']?.toString();

      if (voucherType == 'free_shipping') {
        return _shippingService.totalFee(
          _shopShippingResults,
          excludeSellerId: voucherSellerId,
        );
      }
    }
    return _calculateShippingFee();
  }

  Future<void> _loadSavedAddresses() async {
    setState(() => _isLoadingAddresses = true);
    try {
      await _authService.initialize();
      var buyerId = _authService.currentBuyerId;
      
      if (buyerId == null) {
        final userId = _authService.currentUserId;
        if (userId != null) {
          final buyerData = await _supabase
              .from('buyers')
              .select('buyer_id')
              .eq('user_id', userId)
              .maybeSingle();
          
          if (buyerData != null) {
            buyerId = buyerData['buyer_id'].toString();
          }
        }
      }
      
      if (buyerId != null) {
        final response = await _supabase
            .from('addresses')
            .select()
            .eq('user_type', 'buyer')
            .eq('user_ref_id', buyerId)
            .order('is_default', ascending: false);
        
        setState(() {
          _savedAddresses = List<Map<String, dynamic>>.from(response);
          // Auto-select default address if available
          if (_savedAddresses.isNotEmpty) {
            final defaultAddress = _savedAddresses.firstWhere(
              (addr) => addr['is_default'] == true,
              orElse: () => _savedAddresses.first,
            );
            _selectedAddress = defaultAddress;
          }
          _isLoadingAddresses = false;
        });
        // Compute shipping after address is loaded
        if (_selectedAddress != null) {
          _computeShippingFees();
        }
      } else {
        setState(() => _isLoadingAddresses = false);
      }
    } catch (e) {
      setState(() => _isLoadingAddresses = false);
    }
  }

  /// Computes per-shop shipping fees based on the selected buyer address.
  Future<void> _computeShippingFees() async {
    if (_selectedAddress == null) return;

    setState(() => _isLoadingShipping = true);

    final buyerAddress = {
      'city': (_selectedAddress!['city'] ?? '').toString(),
      'province': (_selectedAddress!['province'] ?? '').toString(),
      'region': (_selectedAddress!['region'] ?? '').toString(),
    };

    // Build cart items list for ShippingService
    final cartItems = widget.items
        .map((item) => {
              'seller_id': item.sellerId,
              'shop_name': item.shopName,
            })
        .toList();

    final results = await _shippingService.calculateShippingPerShop(
      buyerAddress: buyerAddress,
      cartItems: cartItems,
    );

    if (mounted) {
      setState(() {
        _shopShippingResults = results;
        _isLoadingShipping = false;
      });
    }
  }

  Future<void> _showAddNewAddressModal() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddAddressModal(),
    );

    if (result == true) {
      _loadSavedAddresses();
    }
  }

  void _selectAddress(Map<String, dynamic> address) {
    setState(() {
      _selectedAddress = address;
    });
    _computeShippingFees();
  }

  String _getFullAddressDisplay(Map<String, dynamic> address) {
    final parts = <String>[];
    if (address['full_address'] != null && address['full_address'].toString().isNotEmpty) {
      parts.add(address['full_address']);
    }
    if (address['barangay'] != null) parts.add(address['barangay']);
    if (address['city'] != null) parts.add(address['city']);
    if (address['province'] != null) parts.add(address['province']);
    if (address['postal_code'] != null && address['postal_code'].toString().isNotEmpty) {
      parts.add(address['postal_code']);
    }
    return parts.join(', ');
  }

  Future<void> _placeOrder() async {
    if (_selectedAddress == null) {
      SnackBarHelper.showError(context, 'Please select delivery address');
      return;
    }

    setState(() => _isLoading = true);

    final discount = _calculateDiscount();
    final shippingFee = _getTotalShippingFee();
    final finalTotal = widget.totalAmount + shippingFee - discount;

    // Prepare order items with all required data
    final orderItems = widget.items.map((item) => {
      'cart_id': item.cartId,
      'product_id': item.productId,
      'product_name': item.productName,
      'materials': item.materials ?? '',
      'price': item.price,
      'quantity': item.quantity,
      'color': item.color,
      'size': item.size,
      'variant_id': item.variantId,
      'seller_id': item.sellerId,
      'primary_image': item.primaryImage,
    }).toList();

    final result = await _orderService.createOrder(
      items: orderItems,
      addressId: _selectedAddress!['address_id'],
      subtotal: widget.totalAmount,
      shippingFee: shippingFee,
      totalAmount: finalTotal,
      discountAmount: discount,
      voucherId: _selectedVoucher != null ? _selectedVoucher!['vouchers']['voucher_id'] : null,
      buyerVoucherId: _selectedVoucher != null ? _selectedVoucher!['buyer_voucher_id'] : null,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
      // Show success modal
      _showOrderSuccessModal(result['order_numbers'] as List<String>);
    } else {
      SnackBarHelper.showError(context, result['message']);
    }
  }

  void _showOrderSuccessModal(List<String> orderNumbers) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.all(32.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated checkmark icon
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          width: 80.w,
                          height: 80.h,
                          decoration: BoxDecoration(
                            color: AppColors.onSurface(context),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check,
                            size: 50.r,
                            color: AppColors.surface(context),
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 24.h),
                  Text(
                    'Order Placed Successfully!',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'Your order has been placed and is being processed.',
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 14.sp,
                      color: AppColors.textMuted(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20.h),
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant(context),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Column(
                      children: [
                        Text(
                          orderNumbers.length > 1 ? 'Order Numbers' : 'Order Number',
                          style: GoogleFonts.goudyBookletter1911(
                            fontSize: 12.sp,
                            color: AppColors.textMuted(context),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        ...orderNumbers.map((orderNum) => Padding(
                          padding: EdgeInsets.only(bottom: 4.h),
                          child: Text(
                            orderNum,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog
                        Navigator.of(context).pop(); // Go back from checkout
                        // Navigate to My Orders page
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const OrderHistoryScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.onSurface(context),
                        foregroundColor: AppColors.surface(context),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      child: Text(
                        'View My Orders',
                        style: GoogleFonts.goudyBookletter1911(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Close button at top right
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Go back from checkout to product detail
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground(context),
      body: Column(
        children: [
          // White status bar area
          Container(
            height: MediaQuery.of(context).padding.top,
            color: AppColors.surface(context),
          ),
          _buildImageCarousel(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildDeliverySection(),
                  _buildVoucherSection(),
                  _buildOrderSummary(),
                ],
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildImageCarousel() {
    final currentItem = widget.items[_currentImageIndex];
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.4,
      width: double.infinity,
      color: AppColors.surfaceVariant2(context),
      child: Stack(
        children: [
          // Product image with fade animation
          FadeTransition(
            opacity: _fadeAnimation,
            child: CachedNetworkImage(
              imageUrl: ImageHelper.getImageUrl(currentItem.primaryImage),
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: AppColors.border(context),
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              errorWidget: (context, url, error) => Container(
                color: AppColors.border(context),
                child: Icon(Icons.image_not_supported, size: 60.r),
              ),
            ),
          ),
          // Gradient overlay at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 100.h,
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
          ),
          // Back button with auto-contrast
          Positioned(
            top: 8,
            left: 8,
            child: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: AppColors.alwaysWhite,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 10,
                  ),
                ],
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          // Carousel indicator (like product_detail_screen)
          if (widget.items.length > 1)
            Positioned(
              bottom: 60,
              left: 16,
              right: 16,
              child: Center(
                child: Container(
                  height: 3.h,
                  constraints: const BoxConstraints(maxWidth: 200),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                  child: Row(
                    children: List.generate(
                      widget.items.length,
                      (index) => Expanded(
                        child: Container(
                          margin: EdgeInsets.only(
                            right: index < widget.items.length - 1 ? 4 : 0,
                          ),
                          decoration: BoxDecoration(
                            color: index <= _currentImageIndex
                                ? AppColors.alwaysWhite
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(2.r),
                            boxShadow: index <= _currentImageIndex
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
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
          // Checkout title at lower left
          Positioned(
            bottom: 20,
            left: 16,
            child: Text(
              'Checkout',
              style: GoogleFonts.playfairDisplay(
                fontSize: 28.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.alwaysWhite,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherSection() {
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 0.h, 16.w, 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_offer, size: 20.r),
              SizedBox(width: 8.w),
              Text(
                'Vouchers',
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          if (_isLoadingVouchers)
            Center(
              child: Padding(
                padding: EdgeInsets.all(20.w),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_availableVouchers.isEmpty)
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant(context),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Center(
                child: Text(
                  'No vouchers available',
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 14.sp,
                    color: AppColors.textMuted(context),
                  ),
                ),
              ),
            )
          else
            Column(
              children: _availableVouchers.map((buyerVoucher) {
                final voucher = buyerVoucher['vouchers'];
                final isSelected = _selectedVoucher?['buyer_voucher_id'] == buyerVoucher['buyer_voucher_id'];
                final voucherType = voucher['voucher_type'];
                final discountPercent = (voucher['discount_percent'] as num?)?.toInt() ?? 0;
                final voucherSellerId = buyerVoucher['seller_id'];
                
                // Find shop name for this voucher
                String? shopName;
                for (var item in widget.items) {
                  final itemSellerId = int.tryParse(item.sellerId);
                  if (itemSellerId == voucherSellerId) {
                    shopName = item.shopName;
                    break;
                  }
                }
                
                return GestureDetector(
                  onTap: () => _selectVoucher(buyerVoucher),
                  child: Container(
                    margin: EdgeInsets.only(bottom: 12.h),
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.black.withValues(alpha: 0.05) : AppColors.surfaceVariant(context),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: isSelected ? AppColors.onSurface(context) : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          size: 20.r,
                          color: isSelected ? AppColors.onSurface(context) : AppColors.textFaint(context),
                        ),
                        SizedBox(width: 12.w),
                        // Voucher icon
                        Container(
                          width: 40.w,
                          height: 40.h,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            voucherType == 'free_shipping' ? Icons.local_shipping : Icons.percent,
                            size: 20,
                            color: const Color(0xFFD4AF37),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                voucher['voucher_name'] ?? '',
                                style: GoogleFonts.goudyBookletter1911(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.sp,
                                  color: AppColors.onSurface(context),
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                voucherType == 'free_shipping'
                                    ? 'Free Shipping'
                                    : '$discountPercent% off',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green[700],
                                ),
                              ),
                              if (shopName != null) ...[
                                SizedBox(height: 2.h),
                                Text(
                                  'For: $shopName',
                                  style: GoogleFonts.goudyBookletter1911(
                                    fontSize: 11.sp,
                                    color: AppColors.textMuted(context),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildDeliverySection() {
    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, size: 20.r),
              SizedBox(width: 8.w),
              Text(
                'Delivery Address',
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          if (_isLoadingAddresses)
            Center(
              child: Padding(
                padding: EdgeInsets.all(20.w),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_savedAddresses.isEmpty)
            Column(
              children: [
                Container(
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant(context),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.location_off, size: 40.r, color: AppColors.textFaint(context)),
                      SizedBox(height: 8.h),
                      Text(
                        'No saved addresses',
                        style: GoogleFonts.goudyBookletter1911(
                          fontSize: 14.sp,
                          color: AppColors.textMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12.h),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _showAddNewAddressModal,
                    icon: Icon(Icons.add, size: 18.r),
                    label: Text(
                      'Add New Address',
                      style: GoogleFonts.goudyBookletter1911(fontSize: 14.sp),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.onSurface(context),
                      side: BorderSide(color: AppColors.onSurface(context)),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                // Display saved addresses
                ..._savedAddresses.map((address) {
                  final isSelected = _selectedAddress?['address_id'] == address['address_id'];
                  final isDefault = address['is_default'] == true;
                  
                  return GestureDetector(
                    onTap: () => _selectAddress(address),
                    child: Container(
                      margin: EdgeInsets.only(bottom: 12.h),
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.black.withValues(alpha: 0.05) : AppColors.surfaceVariant(context),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: isSelected ? AppColors.onSurface(context) : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            size: 20.r,
                            color: isSelected ? AppColors.onSurface(context) : AppColors.textFaint(context),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      address['recipient_name'] ?? '',
                                      style: GoogleFonts.goudyBookletter1911(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14.sp,
                                      ),
                                    ),
                                    if (isDefault) ...[
                                      SizedBox(width: 8.w),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                        decoration: BoxDecoration(
                                          color: AppColors.onSurface(context),
                                          borderRadius: BorderRadius.circular(4.r),
                                        ),
                                        child: Text(
                                          'DEFAULT',
                                          style: GoogleFonts.goudyBookletter1911(
                                            fontSize: 9.sp,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.surface(context),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (address['phone_number'] != null) ...[
                                  SizedBox(height: 2.h),
                                  Text(
                                    address['phone_number'],
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: 12.sp,
                                      color: AppColors.textMuted(context),
                                    ),
                                  ),
                                ],
                                SizedBox(height: 4.h),
                                Text(
                                  _getFullAddressDisplay(address),
                                  style: GoogleFonts.goudyBookletter1911(
                                    fontSize: 12.sp,
                                    color: AppColors.textBody(context),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                // Add new address button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _showAddNewAddressModal,
                    icon: Icon(Icons.add, size: 18.r),
                    label: Text(
                      'Add New Address',
                      style: GoogleFonts.goudyBookletter1911(fontSize: 14.sp),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.onSurface(context),
                      side: BorderSide(color: AppColors.onSurface(context)),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    // Group items by shop
    final Map<String, List<CartItem>> groupedItems = {};
    for (var item in widget.items) {
      if (!groupedItems.containsKey(item.shopName)) {
        groupedItems[item.shopName] = [];
      }
      groupedItems[item.shopName]!.add(item);
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shopping_bag, size: 20.r),
              SizedBox(width: 8.w),
              Text(
                'Order Summary',
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          // Display items grouped by shop
          ...groupedItems.entries.map((entry) {
            final shopName = entry.key;
            final shopItems = entry.value;
            final shopLogo = shopItems.isNotEmpty ? shopItems.first.shopLogo : null;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Shop header
                Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: Row(
                    children: [
                      // Shop logo or first letter
                      Container(
                        width: 28.w,
                        height: 28.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD3BD9B),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: shopLogo != null && shopLogo.isNotEmpty
                            ? Builder(
                                builder: (context) {
                                  final imageUrl = ImageHelper.getImageUrl(shopLogo);
                                  if (imageUrl.isEmpty) {
                                    return Center(
                                      child: Text(
                                        shopName.isNotEmpty ? shopName[0].toUpperCase() : 'S',
                                        style: GoogleFonts.playfairDisplay(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.surface(context),
                                        ),
                                      ),
                                    );
                                  }
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(6.r),
                                    child: CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Center(
                                        child: Text(
                                          shopName.isNotEmpty ? shopName[0].toUpperCase() : 'S',
                                          style: GoogleFonts.playfairDisplay(
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.surface(context),
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Center(
                                        child: Text(
                                          shopName.isNotEmpty ? shopName[0].toUpperCase() : 'S',
                                          style: GoogleFonts.playfairDisplay(
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.surface(context),
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
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.surface(context),
                                  ),
                                ),
                              ),
                      ),
                      SizedBox(width: 10.w),
                      Text(
                        shopName,
                        style: GoogleFonts.goudyBookletter1911(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Shop items
                ...shopItems.map((item) => Padding(
                  padding: EdgeInsets.only(bottom: 12.h, left: 38.w),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6.r),
                        child: CachedNetworkImage(
                          imageUrl: ImageHelper.getImageUrl(item.primaryImage),
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: AppColors.surfaceVariant2(context),
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: AppColors.surfaceVariant2(context),
                            child: Icon(Icons.image_not_supported, size: 20.r),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.productName,
                              style: GoogleFonts.goudyBookletter1911(fontSize: 13.sp),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (item.color != null || item.size != null)
                              Padding(
                                padding: EdgeInsets.only(top: 2.h),
                                child: Text(
                                  [
                                    if (item.color != null) item.color,
                                    if (item.size != null) item.size,
                                  ].join(' • '),
                                  style: GoogleFonts.goudyBookletter1911(
                                    fontSize: 11.sp,
                                    color: AppColors.textMuted(context),
                                  ),
                                ),
                              ),
                            SizedBox(height: 4.h),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '₱${item.price.toStringAsFixed(2)}',
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'x${item.quantity}',
                                  style: GoogleFonts.goudyBookletter1911(
                                    fontSize: 12.sp,
                                    color: AppColors.textMuted(context),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        '₱${item.totalPrice.toStringAsFixed(2)}',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )),
                if (entry.key != groupedItems.keys.last)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    child: Divider(height: 1),
                  ),
              ],
            );
          }),
          const Divider(),
          SizedBox(height: 8.h),
          // Subtotal
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal',
                style: GoogleFonts.goudyBookletter1911(fontSize: 14.sp),
              ),
              Text(
                '₱${widget.totalAmount.toStringAsFixed(2)}',
                style: GoogleFonts.playfairDisplay(fontSize: 14.sp),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          // Shipping Fee section header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Shipping Fee',
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_isLoadingShipping)
                SizedBox(
                  height: 14.h,
                  width: 14.w,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  '₱${_calculateShippingFee().toStringAsFixed(2)}',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    decoration: _selectedVoucher != null &&
                            _selectedVoucher!['vouchers']['voucher_type'] ==
                                'free_shipping'
                        ? TextDecoration.lineThrough
                        : null,
                    color: _selectedVoucher != null &&
                            _selectedVoucher!['vouchers']['voucher_type'] ==
                                'free_shipping'
                        ? AppColors.textFaint(context)
                        : null,
                  ),
                ),
            ],
          ),
          // Per-shop shipping breakdown
          if (!_isLoadingShipping && _shopShippingResults.isNotEmpty) ...[
            SizedBox(height: 6.h),
            ..._shopShippingResults.map((result) {
              final isFreeForThisShop = _selectedVoucher != null &&
                  _selectedVoucher!['vouchers']['voucher_type'] ==
                      'free_shipping' &&
                  _selectedVoucher!['seller_id']?.toString() ==
                      result.sellerId;
              return Padding(
                padding: EdgeInsets.only(left: 12.w, bottom: 4.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.store_outlined,
                          size: 12.r,
                          color: AppColors.textFaint(context),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          result.shopName,
                          style: GoogleFonts.goudyBookletter1911(
                            fontSize: 12.sp,
                            color: AppColors.textMuted(context),
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 5.w, vertical: 1.h),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant(context),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            result.tierLabel,
                            style: GoogleFonts.goudyBookletter1911(
                              fontSize: 9.sp,
                              color: AppColors.textMuted(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    isFreeForThisShop
                        ? Text(
                            'FREE',
                            style: GoogleFonts.goudyBookletter1911(
                              fontSize: 12.sp,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : Text(
                            '₱${result.fee.toStringAsFixed(2)}',
                            style: GoogleFonts.goudyBookletter1911(
                              fontSize: 12.sp,
                              color: AppColors.textMuted(context),
                            ),
                          ),
                  ],
                ),
              );
            }),
          ],
          // Free shipping discount row
          if (_selectedVoucher != null &&
              _selectedVoucher!['vouchers']['voucher_type'] ==
                  'free_shipping') ...[
            SizedBox(height: 4.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Free Shipping Discount',
                  style: GoogleFonts.goudyBookletter1911(
                      fontSize: 13.sp, color: Colors.green[700]),
                ),
                Text(
                  '-₱${(_calculateShippingFee() - _getTotalShippingFee()).toStringAsFixed(2)}',
                  style: GoogleFonts.playfairDisplay(
                      fontSize: 13.sp, color: Colors.green[700]),
                ),
              ],
            ),
          ],
          // Regular discount row
          if (_selectedVoucher != null &&
              _selectedVoucher!['vouchers']['voucher_type'] !=
                  'free_shipping') ...[
            SizedBox(height: 8.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Discount',
                  style: GoogleFonts.goudyBookletter1911(
                      fontSize: 14.sp, color: Colors.green[700]),
                ),
                Text(
                  '-₱${_calculateDiscount().toStringAsFixed(2)}',
                  style: GoogleFonts.playfairDisplay(
                      fontSize: 14.sp, color: Colors.green[700]),
                ),
              ],
            ),
          ],
          const Divider(),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _isLoadingShipping
                  ? Text(
                      'Calculating...',
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 14.sp,
                        color: AppColors.textFaint(context),
                      ),
                    )
                  : Text(
                      '₱${(widget.totalAmount + _getTotalShippingFee() - _calculateDiscount()).toStringAsFixed(2)}',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface(context),
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
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
                    'Total Payment',
                    style: GoogleFonts.goudyBookletter1911(fontSize: 12.sp, color: AppColors.textMuted(context)),
                  ),
                  _isLoadingShipping
                      ? Text(
                          'Calculating...',
                          style: GoogleFonts.goudyBookletter1911(
                            fontSize: 14.sp,
                            color: AppColors.textFaint(context),
                          ),
                        )
                      : Text(
                          '₱${(widget.totalAmount + _getTotalShippingFee() - _calculateDiscount()).toStringAsFixed(2)}',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: (_isLoading || _isLoadingShipping) ? null : _placeOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.onSurface(context),
                foregroundColor: AppColors.surface(context),
                padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 20.h,
                      width: 20.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.surface(context)),
                      ),
                    )
                  : Text(
                      'Place Order',
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }
}

// Add Address Modal Widget
class _AddAddressModal extends StatefulWidget {
  const _AddAddressModal();

  @override
  State<_AddAddressModal> createState() => _AddAddressModalState();
}

class _AddAddressModalState extends State<_AddAddressModal> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  final _authService = AuthService();
  
  final _recipientController = TextEditingController();
  final _phoneController = TextEditingController();
  final _streetController = TextEditingController();
  final _houseNumberController = TextEditingController();
  final _postalCodeController = TextEditingController();
  
  String? _region;
  String? _province;
  String? _city;
  String? _barangay;
  String _addressDisplay = '';
  
  bool _isDefault = false;
  bool _isSaving = false;
  bool _showAddressError = false;

  void _updateAddressDisplay() {
    if (_region != null && _city != null && _barangay != null) {
      _addressDisplay = _province != null
          ? '$_region, $_province, $_city, $_barangay'
          : '$_region, $_city, $_barangay';
    } else {
      _addressDisplay = '';
    }
  }

  Future<void> _selectAddress() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddressSelectorModal(
        initialRegion: _region,
        initialProvince: _province,
        initialCity: _city,
        initialBarangay: _barangay,
      ),
    );

    if (result != null) {
      setState(() {
        _region = result['region'];
        _province = result['province'];
        _city = result['city'];
        _barangay = result['barangay'];
        _showAddressError = false; // Clear error when address is selected
        _updateAddressDisplay();
      });
      
      await _lookupPostalCode();
    }
  }

  Future<void> _lookupPostalCode() async {
    if (_city == null) return;
    
    try {
      final response = await http.get(
        Uri.parse('https://gist.githubusercontent.com/chrisbjr/784565232f10cba6530856dc7fda367a/raw/ph-zip-codes.json'),
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> postalData = json.decode(response.body);
        
        final cityTokens = _normalizeAndTokenize(_city!);
        final provinceTokens = _province != null ? _normalizeAndTokenize(_province!) : <String>[];
        final barangayTokens = _barangay != null ? _normalizeAndTokenize(_barangay!) : <String>[];
        
        String? foundPostalCode;
        int bestScore = 0;
        
        for (var entry in postalData) {
          final area = entry['area'] as String;
          final areaTokens = _normalizeAndTokenize(area);
          
          int score = 0;
          
          if (!cityTokens.every((token) => areaTokens.contains(token))) continue;
          
          score += 5;
          
          if (provinceTokens.isNotEmpty && provinceTokens.every((token) => areaTokens.contains(token))) {
            score += 3;
          }
          
          if (barangayTokens.isNotEmpty && barangayTokens.any((token) => areaTokens.contains(token))) {
            score += 2;
          }
          
          if (score > bestScore) {
            bestScore = score;
            foundPostalCode = entry['zip'] as String;
          }
        }
        
        if (foundPostalCode != null && mounted) {
          setState(() {
            _postalCodeController.text = foundPostalCode!;
          });
        }
      }
    } catch (e) {
      // Silently fail
    }
  }

  Set<String> _normalizeAndTokenize(String text) {
    final stopWords = {'OF', 'THE', 'CITY', 'MUNICIPALITY', 'PROVINCE', 'BARANGAY', 'DISTRICT'};
    
    return text
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty && !stopWords.contains(token))
        .toSet();
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;
    if (_region == null || _city == null || _barangay == null) {
      setState(() => _showAddressError = true);
      SnackBarHelper.showError(context, 'Please select address location');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _authService.initialize();
      var buyerId = _authService.currentBuyerId;
      
      if (buyerId == null) {
        final userId = _authService.currentUserId;
        if (userId != null) {
          final buyerData = await _supabase
              .from('buyers')
              .select('buyer_id')
              .eq('user_id', userId)
              .maybeSingle();
          
          if (buyerData != null) {
            buyerId = buyerData['buyer_id'].toString();
          }
        }
      }
      
      if (buyerId == null) {
        throw Exception('Buyer ID not found');
      }

      // Build full address string - include ALL address parts
      final fullAddressParts = <String>[];
      if (_houseNumberController.text.isNotEmpty) {
        fullAddressParts.add(_houseNumberController.text.trim());
      }
      if (_streetController.text.isNotEmpty) {
        fullAddressParts.add(_streetController.text.trim());
      }
      if (_barangay != null && _barangay!.isNotEmpty) {
        fullAddressParts.add(_barangay!);
      }
      if (_city != null && _city!.isNotEmpty) {
        fullAddressParts.add(_city!);
      }
      if (_province != null && _province!.isNotEmpty) {
        fullAddressParts.add(_province!);
      }
      if (_region != null && _region!.isNotEmpty) {
        fullAddressParts.add(_region!);
      }
      final fullAddress = fullAddressParts.join(', ');

      final addressData = {
        'user_type': 'buyer',
        'user_ref_id': buyerId,
        'recipient_name': _recipientController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'full_address': fullAddress,
        'region': _region,
        'province': _province,
        'city': _city,
        'barangay': _barangay,
        'street_name': _streetController.text.trim(),
        'house_number': _houseNumberController.text.trim(),
        'postal_code': _postalCodeController.text.trim(),
        'is_default': _isDefault,
      };

      if (_isDefault) {
        await _supabase
            .from('addresses')
            .update({'is_default': false})
            .eq('user_type', 'buyer')
            .eq('user_ref_id', buyerId);
      }
      
      await _supabase.from('addresses').insert(addressData);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        SnackBarHelper.showError(context, 'Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.all(24.w),
                children: [
                  _buildTextField(
                    controller: _recipientController,
                    label: 'Recipient Name',
                    hint: 'Enter recipient name',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter recipient name';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16.h),
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    hint: 'Enter phone number',
                    keyboardType: TextInputType.phone,
                    maxLength: 11,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter phone number';
                      }
                      if (value.length != 11) {
                        return 'Phone number must be 11 digits';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16.h),
                  _buildTextField(
                    controller: _houseNumberController,
                    label: 'House/Unit/Floor No.',
                    hint: 'e.g., Unit 123, 5th Floor',
                  ),
                  SizedBox(height: 16.h),
                  _buildTextField(
                    controller: _streetController,
                    label: 'Street Name',
                    hint: 'Enter street name',
                  ),
                  SizedBox(height: 16.h),
                  _buildAddressSelector(),
                  SizedBox(height: 16.h),
                  _buildTextField(
                    controller: _postalCodeController,
                    label: 'Postal Code',
                    hint: 'Auto-filled based on address',
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 16.h),
                  _buildDefaultCheckbox(),
                  SizedBox(height: 24.h),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveAddress,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.onSurface(context),
                      foregroundColor: AppColors.surface(context),
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    child: _isSaving
                        ? SizedBox(
                            height: 20.h,
                            width: 20.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.surface(context)),
                            ),
                          )
                        : Text(
                            'Add Address',
                            style: GoogleFonts.goudyBookletter1911(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
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
              'Add New Address',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20.sp,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.goudyBookletter1911(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          validator: validator,
          decoration: InputDecoration(
            counterText: maxLength != null ? '' : null,
            hintText: hint,
            hintStyle: GoogleFonts.goudyBookletter1911(color: AppColors.textFaint(context)),
            filled: true,
            fillColor: AppColors.surface(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(color: AppColors.border(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(color: AppColors.border(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(color: AppColors.onSurface(context), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: const BorderSide(color: Colors.red),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          ),
          style: keyboardType == TextInputType.phone || keyboardType == TextInputType.number
              ? GoogleFonts.playfairDisplay()
              : GoogleFonts.goudyBookletter1911(),
        ),
      ],
    );
  }

  Widget _buildAddressSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Region, Province, City, Barangay',
          style: GoogleFonts.goudyBookletter1911(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.h),
        GestureDetector(
          onTap: _selectAddress,
          child: Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: _showAddressError && _addressDisplay.isEmpty 
                    ? Colors.red.withValues(alpha: 0.3) 
                    : AppColors.border(context),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _addressDisplay.isEmpty ? 'Select address location' : _addressDisplay,
                    style: GoogleFonts.goudyBookletter1911(
                      color: _addressDisplay.isEmpty ? AppColors.textFaint(context) : AppColors.onSurface(context),
                    ),
                  ),
                ),
                Icon(
                  _addressDisplay.isEmpty ? Icons.add_circle_outline : Icons.edit_outlined,
                  size: 20.r,
                  color: AppColors.textMuted(context),
                ),
              ],
            ),
          ),
        ),
        if (_showAddressError && _addressDisplay.isEmpty)
          Padding(
            padding: EdgeInsets.only(top: 8.h, left: 12.w),
            child: Text(
              'Please select address location',
              style: GoogleFonts.goudyBookletter1911(
                fontSize: 12.sp,
                color: Colors.red,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDefaultCheckbox() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          Checkbox(
            value: _isDefault,
            onChanged: (value) {
              setState(() {
                _isDefault = value ?? false;
              });
            },
            activeColor: AppColors.onSurface(context),
          ),
          Expanded(
            child: Text(
              'Set as default address',
              style: GoogleFonts.goudyBookletter1911(fontSize: 14.sp),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _houseNumberController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }
}
