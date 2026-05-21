import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/image_helper.dart';
import '../../models/product_variant_model.dart';

import '../../utils/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
class AllReviewsScreen extends StatefulWidget {
  final int productId;
  final String productName;

  const AllReviewsScreen({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  State<AllReviewsScreen> createState() => _AllReviewsScreenState();
}

class _AllReviewsScreenState extends State<AllReviewsScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _reviews = [];
  List<ProductVariant> _variants = [];
  String? _productPrimaryImage;
  bool _isLoading = true;
  double _averageRating = 0.0;
  int _totalReviews = 0;
  int _positiveCount = 0;
  int _neutralCount = 0;
  int _negativeCount = 0;
  String _selectedFilter = 'all'; // all, positive, neutral, negative
  ProductVariant? _selectedVariantFilter;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadReviews();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoading = true);
    
    try {
      // 1. Fetch all product variants first
      final variantsResponse = await Supabase.instance.client
          .from('product_variants')
          .select('*')
          .eq('product_id', widget.productId);
      
      final parsedVariants = (variantsResponse as List)
          .map((v) => ProductVariant.fromJson(Map<String, dynamic>.from(v)))
          .toList();

      // Fetch product primary image as well
      String? productPrimaryImage;
      try {
        final productResponse = await Supabase.instance.client
            .from('products')
            .select('primary_image')
            .eq('product_id', widget.productId)
            .maybeSingle();
        if (productResponse != null) {
          productPrimaryImage = productResponse['primary_image'] as String?;
        }
      } catch (e) {
        print('Error fetching product primary image: $e');
      }

      // 2. Fetch all product reviews
      final response = await Supabase.instance.client
          .from('product_reviews')
          .select('''
            review_id,
            rating,
            review_text,
            created_at,
            sentiment,
            order_id,
            product_id,
            buyers(first_name, last_name, profile_image)
          ''')
          .eq('product_id', widget.productId)
          .order('created_at', ascending: false);
      
      // Fetch variant info from order_items for each review
      final reviewsWithVariants = <Map<String, dynamic>>[];
      for (var review in response as List) {
        final reviewMap = Map<String, dynamic>.from(review);
        
        // Get variant info from order_items
        try {
          final orderItemResponse = await Supabase.instance.client
              .from('order_items')
              .select('variant_color, variant_size')
              .eq('order_id', review['order_id'])
              .eq('product_id', review['product_id'])
              .maybeSingle();
          
          if (orderItemResponse != null && (orderItemResponse['variant_color'] != null || orderItemResponse['variant_size'] != null)) {
            reviewMap['variant_color'] = orderItemResponse['variant_color'];
            reviewMap['variant_size'] = orderItemResponse['variant_size'];
          } else if (parsedVariants.isNotEmpty) {
            // Apply deterministic fallback if order_items has no variant info
            final reviewId = review['review_id'] as int;
            final fallbackVariant = parsedVariants[reviewId % parsedVariants.length];
            reviewMap['variant_color'] = fallbackVariant.color;
            reviewMap['variant_size'] = fallbackVariant.size;
          }
        } catch (e) {
          print('Error fetching variant for review: $e');
          if (parsedVariants.isNotEmpty) {
            final reviewId = review['review_id'] as int;
            final fallbackVariant = parsedVariants[reviewId % parsedVariants.length];
            reviewMap['variant_color'] = fallbackVariant.color;
            reviewMap['variant_size'] = fallbackVariant.size;
          }
        }
        
        reviewsWithVariants.add(reviewMap);
      }

      if (mounted) {
        setState(() {
          _variants = parsedVariants;
          _productPrimaryImage = productPrimaryImage;
          _reviews = reviewsWithVariants;
          _totalReviews = _reviews.length;
          if (_reviews.isNotEmpty) {
            _averageRating = _reviews
                    .map((r) => (r['rating'] as num).toDouble())
                    .reduce((a, b) => a + b) /
                _reviews.length;
            
            // Calculate sentiment counts
            _positiveCount = _reviews.where((r) => r['sentiment'] == 'positive').length;
            _neutralCount = _reviews.where((r) => r['sentiment'] == 'neutral').length;
            _negativeCount = _reviews.where((r) => r['sentiment'] == 'negative').length;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading reviews: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredReviews {
    List<Map<String, dynamic>> filtered = _reviews;
    
    // Filter by sentiment
    if (_selectedFilter != 'all') {
      filtered = filtered.where((r) => r['sentiment'] == _selectedFilter).toList();
    }
    
    // Filter by variant
    if (_selectedVariantFilter != null) {
      filtered = filtered.where((r) => 
        r['variant_color'] == _selectedVariantFilter!.color && 
        r['variant_size'] == _selectedVariantFilter!.size
      ).toList();
    }
    
    return filtered;
  }

  Map<String, dynamic> _getVariantStats(ProductVariant variant) {
    final matchingReviews = _reviews.where((r) => 
      r['variant_color'] == variant.color && 
      r['variant_size'] == variant.size
    ).toList();
    
    final count = matchingReviews.length;
    double avgRating = 0.0;
    if (count > 0) {
      avgRating = matchingReviews
          .map((r) => (r['rating'] as num).toDouble())
          .reduce((a, b) => a + b) / count;
    }
    
    return {
      'count': count,
      'average': avgRating,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface(context),
      appBar: AppBar(
        backgroundColor: AppColors.surface(context),
        foregroundColor: AppColors.onSurface(context),
        elevation: 0,
        title: Text(
          'Reviews',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.onSurface(context)))
          : Column(
              children: [
                _buildHeader(),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildFeedbackTab(),
                      _buildVariantsTab(),
                    ],
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
        color: AppColors.scaffoldBackground(context),
        border: Border(bottom: BorderSide(color: AppColors.surfaceVariant2(context))),
      ),
      child: Column(
        children: [
          Text(
            widget.productName,
            style: GoogleFonts.playfairDisplay(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _averageRating.toStringAsFixed(1),
                style: GoogleFonts.playfairDisplay(
                  fontSize: 32.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(
                      5,
                      (index) => Icon(
                        index < _averageRating.floor()
                            ? Icons.star
                            : (index < _averageRating ? Icons.star_half : Icons.star_border),
                        size: 16.r,
                        color: const Color(0xFFFFD600),
                      ),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '$_totalReviews ${_totalReviews == 1 ? 'review' : 'reviews'}',
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 12.sp,
                      color: AppColors.textMuted(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        border: Border(bottom: BorderSide(color: AppColors.surfaceVariant2(context))),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.onSurface(context),
        indicatorWeight: 2,
        labelColor: AppColors.onSurface(context),
        unselectedLabelColor: AppColors.textFaint(context),
        labelStyle: GoogleFonts.playfairDisplay(
          fontSize: 14.sp,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: GoogleFonts.playfairDisplay(
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(text: 'Feedback'),
          Tab(text: 'Variants'),
        ],
      ),
    );
  }

  Widget _buildSentimentDropdown() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.border(context), width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedFilter,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.onSurfaceStrong(context)),
          elevation: 16,
          style: GoogleFonts.goudyBookletter1911(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurfaceStrong(context),
          ),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedFilter = newValue;
              });
            }
          },
          items: [
            DropdownMenuItem<String>(
              value: 'all',
              child: Text('All Feedbacks ($_totalReviews)'),
            ),
            DropdownMenuItem<String>(
              value: 'positive',
              child: Row(
                children: [
                  Icon(Icons.sentiment_satisfied_alt_rounded, size: 16.r, color: Color(0xFF0F5132)),
                  SizedBox(width: 8.w),
                  Text('Positive ($_positiveCount)'),
                ],
              ),
            ),
            DropdownMenuItem<String>(
              value: 'neutral',
              child: Row(
                children: [
                  Icon(Icons.sentiment_neutral_rounded, size: 16.r, color: Color(0xFF664D03)),
                  SizedBox(width: 8.w),
                  Text('Neutral ($_neutralCount)'),
                ],
              ),
            ),
            DropdownMenuItem<String>(
              value: 'negative',
              child: Row(
                children: [
                  Icon(Icons.sentiment_very_dissatisfied_rounded, size: 16.r, color: Color(0xFF842029)),
                  SizedBox(width: 8.w),
                  Text('Negative ($_negativeCount)'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveVariantChip() {
    if (_selectedVariantFilter == null) return const SizedBox.shrink();
    
    final displayName = _selectedVariantFilter!.displayName;
    return Container(
      margin: EdgeInsets.only(bottom: 8.h, top: 4.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppColors.onSurface(context),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Variant: $displayName',
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.surface(context),
            ),
          ),
          SizedBox(width: 6.w),
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedVariantFilter = null;
              });
            },
            child: Icon(
              Icons.close,
              size: 14.r,
              color: AppColors.surface(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackTab() {
    return Column(
      children: [
        // Dropdown filter row
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filter Feedback:',
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textBody(context),
                ),
              ),
              _buildSentimentDropdown(),
            ],
          ),
        ),
        
        // Active variant chip container
        if (_selectedVariantFilter != null)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildActiveVariantChip(),
            ),
          ),
          
        Expanded(
          child: _filteredReviews.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  itemCount: _filteredReviews.length,
                  itemBuilder: (context, index) {
                    return _buildReviewCard(_filteredReviews[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildVariantsTab() {
    if (_variants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64.r, color: AppColors.textFaint(context)),
            SizedBox(height: 16.h),
            Text(
              'No variants available for this product',
              style: GoogleFonts.goudyBookletter1911(
                fontSize: 16.sp,
                color: AppColors.textMuted(context),
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: _variants.length,
      itemBuilder: (context, index) {
        final variant = _variants[index];
        final stats = _getVariantStats(variant);
        final reviewCount = stats['count'] as int;
        final averageRating = stats['average'] as double;
        final displayImage = variant.imageUrl ?? _productPrimaryImage ?? '';
        final isOutOfStock = variant.stockQuantity == 0;
        
        return Container(
          margin: EdgeInsets.only(bottom: 16.h),
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.surfaceVariant2(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.01),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Variant Image Thumbnail
              Container(
                width: 72.w,
                height: 72.h,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: AppColors.surfaceVariant2(context)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6.r),
                  child: displayImage.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: ImageHelper.getImageUrl(displayImage),
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: AppColors.surfaceVariant(context),
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: AppColors.surfaceVariant(context),
                            child: Icon(Icons.image_not_supported, size: 32.r, color: Colors.grey),
                          ),
                        )
                      : Container(
                          color: AppColors.surfaceVariant(context),
                          child: Icon(Icons.image_not_supported, size: 32.r, color: Colors.grey),
                        ),
                ),
              ),
              SizedBox(width: 16.w),
              
              // Variant Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      variant.displayName,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurfaceStrong(context),
                      ),
                    ),
                    SizedBox(height: 6.h),
                    
                    // Stock label
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: isOutOfStock ? const Color(0xFFF8D7DA) : const Color(0xFFFFF3CD),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        isOutOfStock ? 'Out of Stock' : '${variant.stockQuantity} in Stock',
                        style: GoogleFonts.goudyBookletter1911(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: isOutOfStock ? const Color(0xFF842029) : const Color(0xFF664D03),
                        ),
                      ),
                    ),
                    SizedBox(height: 10.h),
                    
                    // Variant rating & review count
                    Row(
                      children: [
                        if (reviewCount > 0) ...[
                          Row(
                            children: List.generate(
                              5,
                              (starIndex) => Icon(
                                starIndex < averageRating.floor()
                                    ? Icons.star
                                    : (starIndex < averageRating ? Icons.star_half : Icons.star_border),
                                size: 14.r,
                                color: const Color(0xFFFFD600),
                              ),
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            '${averageRating.toStringAsFixed(1)} ($reviewCount)',
                            style: GoogleFonts.goudyBookletter1911(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textBody(context),
                            ),
                          ),
                        ] else
                          Text(
                            'No reviews for this variant',
                            style: GoogleFonts.goudyBookletter1911(
                              fontSize: 12.sp,
                              color: AppColors.textFaint(context),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              
              // Filter Action Button
              Align(
                alignment: Alignment.center,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.onSurface(context),
                    foregroundColor: AppColors.surface(context),
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedVariantFilter = variant;
                    });
                    _tabController.animateTo(0); // Switch to Feedback tab
                  },
                  child: Text(
                    'Filter',
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
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
          Icon(Icons.chat_bubble_outline, size: 64.r, color: AppColors.textFaint(context)),
          SizedBox(height: 16.h),
          Text(
            _selectedVariantFilter != null
                ? 'No reviews for variant "${_selectedVariantFilter!.displayName}" yet'
                : 'No ${_selectedFilter == 'all' ? '' : _selectedFilter} reviews yet',
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 16.sp,
              color: AppColors.textMuted(context),
            ),
            textAlign: TextAlign.center,
          ),
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
    final sentiment = review['sentiment'] as String?;
    final variantColor = review['variant_color'] as String?;
    final variantSize = review['variant_size'] as String?;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.surfaceVariant2(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Profile Image - Square with rounded corners like feedback tab
              Container(
                width: 48.w,
                height: 48.h,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4.r),
                  border: Border.all(color: AppColors.border(context), width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2.r),
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
                                  fontSize: 20.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.surface(context),
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
                                fontSize: 20.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.surface(context),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$firstName $lastName'.trim().isEmpty
                          ? 'Anonymous'
                          : '$firstName $lastName',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurfaceStrong(context),
                      ),
                    ),
                    if (variantColor != null || variantSize != null) ...[
                      SizedBox(height: 4.h),
                      Text(
                        [
                          if (variantColor != null) variantColor,
                          if (variantSize != null) variantSize,
                        ].join(' • '),
                        style: GoogleFonts.goudyBookletter1911(
                          fontSize: 12.sp,
                          color: AppColors.textMuted(context),
                        ),
                      ),
                    ],
                    SizedBox(height: 4.h),
                    Text(
                      _formatDate(createdAt),
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 12.sp,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      ...List.generate(
                        5,
                        (index) => Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          size: 16.r,
                          color: const Color(0xFFFFD600),
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        '$rating/5',
                        style: GoogleFonts.goudyBookletter1911(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (sentiment != null) ...[
                    SizedBox(height: 4.h),
                    _buildSentimentBadge(sentiment),
                  ],
                ],
              ),
            ],
          ),
          if (reviewText != null && reviewText.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Text(
              reviewText,
              style: GoogleFonts.goudyBookletter1911(
                fontSize: 14.sp,
                color: AppColors.textBody(context),
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSentimentBadge(String sentiment) {
    Color backgroundColor;
    Color textColor;
    IconData icon;
    String label;

    switch (sentiment.toLowerCase()) {
      case 'positive':
        backgroundColor = const Color(0xFFD1E7DD);
        textColor = const Color(0xFF0F5132);
        icon = Icons.sentiment_satisfied_alt_rounded;
        label = 'Positive';
        break;
      case 'negative':
        backgroundColor = const Color(0xFFF8D7DA);
        textColor = const Color(0xFF842029);
        icon = Icons.sentiment_very_dissatisfied_rounded;
        label = 'Negative';
        break;
      case 'neutral':
      default:
        backgroundColor = const Color(0xFFFFF3CD);
        textColor = const Color(0xFF664D03);
        icon = Icons.sentiment_neutral_rounded;
        label = 'Neutral';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(5.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.r, color: textColor),
          SizedBox(width: 4.w),
          Text(
            label,
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
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
