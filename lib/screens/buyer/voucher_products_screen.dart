import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/product_model.dart';
import '../../utils/image_helper.dart';
import 'product_detail_screen.dart';

import '../../utils/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
class VoucherProductsScreen extends StatefulWidget {
  final int voucherId;
  
  const VoucherProductsScreen({super.key, required this.voucherId});

  @override
  State<VoucherProductsScreen> createState() => _VoucherProductsScreenState();
}

class _VoucherProductsScreenState extends State<VoucherProductsScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _voucher;
  List<Product> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      print('=== Loading Voucher Products ===');
      print('Voucher ID: ${widget.voucherId}');
      
      // Get voucher details with shop count
      final voucherResponse = await _supabase
          .from('vouchers')
          .select('''
            voucher_id,
            voucher_code,
            voucher_name,
            voucher_type,
            discount_percent,
            start_date,
            end_date
          ''')
          .eq('voucher_id', widget.voucherId)
          .maybeSingle();

      print('Voucher response: $voucherResponse');

      if (voucherResponse != null) {
        // Count shops offering this voucher
        final shopCountResponse = await _supabase
            .from('seller_vouchers')
            .select('seller_id')
            .eq('voucher_id', widget.voucherId);
        
        final shopCount = (shopCountResponse as List).length;
        print('Shop count: $shopCount');
        
        _voucher = {
          ...voucherResponse,
          'shop_count': shopCount,
        };

        // Get all seller IDs offering this voucher
        final sellerVouchersResponse = await _supabase
            .from('seller_vouchers')
            .select('seller_id')
            .eq('voucher_id', widget.voucherId);

        final sellerIds = (sellerVouchersResponse as List)
            .map((sv) => sv['seller_id'] as int)
            .toList();

        print('Seller IDs: $sellerIds');

        if (sellerIds.isNotEmpty) {
          // Get all products from these sellers
          final productsResponse = await _supabase
              .from('products')
              .select('product_id, product_name, price, materials, seller_id')
              .inFilter('seller_id', sellerIds)
              .eq('is_active', true)
              .order('product_id', ascending: false);

          print('Products response count: ${(productsResponse as List).length}');

          // Get primary images for all products
          final productIds = (productsResponse as List)
              .map((p) => p['product_id'] as int)
              .toList();

          if (productIds.isNotEmpty) {
            final imagesResponse = await _supabase
                .from('product_images')
                .select('product_id, image_url, display_order')
                .inFilter('product_id', productIds)
                .order('display_order', ascending: true);

            print('Images response count: ${(imagesResponse as List).length}');

            // Group images by product_id and get primary image
            final Map<int, String?> productImages = {};
            for (var image in imagesResponse as List) {
              final productId = image['product_id'] as int;
              if (!productImages.containsKey(productId)) {
                productImages[productId] = image['image_url']?.toString();
              }
            }

            // Create products list using fromJson
            for (var product in productsResponse as List) {
              try {
                final productId = product['product_id'] as int;
                
                // Add primary_image to the product data
                final productData = Map<String, dynamic>.from(product);
                productData['primary_image'] = productImages[productId];
                
                _products.add(Product.fromJson(productData));
              } catch (e) {
                print('Error creating product from: $product');
                print('Error: $e');
              }
            }

            print('Products loaded: ${_products.length}');
          }
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e, stackTrace) {
      print('Error loading voucher products: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface(context),
      body: CustomScrollView(
        slivers: [
          _buildHeroSection(),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))),
            )
          else if (_products.isEmpty)
            _buildEmptyState()
          else
            _buildProductsGrid(),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    if (_voucher == null) {
      return SliverAppBar(
        backgroundColor: AppColors.surface(context),
        foregroundColor: AppColors.onSurface(context),
        elevation: 0,
        pinned: true,
      );
    }

    final voucherName = _voucher!['voucher_name'] ?? 'Voucher';
    final discountPercent = _voucher!['discount_percent'] ?? 0;
    final voucherType = _voucher!['voucher_type'] ?? '';
    final shopCount = _voucher!['shop_count'] ?? 0;
    final endDate = _voucher!['end_date'] != null
        ? DateTime.parse(_voucher!['end_date'])
        : null;

    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: const Color(0xFFD4AF37),
      foregroundColor: AppColors.alwaysWhite,
      elevation: 0,
      flexibleSpace: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // Calculate the scroll progress (0.0 = expanded, 1.0 = collapsed)
          final double top = constraints.biggest.height;
          final double expandedHeight = 300.0;
          final double collapsedHeight = kToolbarHeight + MediaQuery.of(context).padding.top;
          final double scrollProgress = ((expandedHeight - top) / (expandedHeight - collapsedHeight)).clamp(0.0, 1.0);
          
          return FlexibleSpaceBar(
            centerTitle: true,
            title: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: scrollProgress,
              child: Text(
                '$discountPercent% OFF',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.alwaysWhite,
                ),
              ),
            ),
            background: Container(
              color: const Color(0xFFD4AF37),
              child: SafeArea(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: 1.0 - scrollProgress,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        voucherType == 'free_shipping' ? Icons.local_shipping : Icons.percent,
                        size: 80,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      SizedBox(height: 20.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: Text(
                          voucherName,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 28.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.alwaysWhite,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        '$discountPercent% OFF${endDate != null ? ' • Valid until ${_formatDate(endDate)}' : ''}',
                        style: GoogleFonts.goudyBookletter1911(
                          fontSize: 16.sp,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.store, color: AppColors.alwaysWhite, size: 18.r),
                            SizedBox(width: 8.w),
                            Text(
                              '$shopCount Shop${shopCount > 1 ? 's' : ''}',
                              style: GoogleFonts.goudyBookletter1911(
                                fontSize: 14.sp,
                                color: AppColors.alwaysWhite,
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
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 80.r, color: AppColors.textFaint(context)),
            SizedBox(height: 16.h),
            Text(
              'No Products Available',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textBody(context),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'There are no products available\nwith this voucher yet.',
              style: GoogleFonts.goudyBookletter1911(
                fontSize: 14.sp,
                color: AppColors.textFaint(context),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: AppColors.surface(context),
                padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: Text(
                'Back to Vouchers',
                style: GoogleFonts.playfairDisplay(
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

  Widget _buildProductsGrid() {
    return SliverPadding(
      padding: EdgeInsets.all(16.w),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: 2,
        crossAxisSpacing: 16.w,
        mainAxisSpacing: 16.h,
        childCount: _products.length,
        itemBuilder: (context, index) => _buildProductCard(_products[index]),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(productId: product.id),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(12.r),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
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
                    '₱${product.price.toStringAsFixed(2)}',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
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

  String _formatDate(DateTime date) {
    final months = ['January', 'February', 'March', 'April', 'May', 'June',
                    'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
