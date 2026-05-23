import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/product_model.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../services/report_service.dart';
import '../../utils/image_helper.dart';
import '../../utils/snackbar_helper.dart';
import 'product_detail_screen.dart';
import 'chat_conversation_screen.dart';

import '../../utils/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
class ViewShopScreen extends StatefulWidget {
  final String sellerId;
  final String shopName;

  const ViewShopScreen({
    super.key,
    required this.sellerId,
    required this.shopName,
  });

  @override
  State<ViewShopScreen> createState() => _ViewShopScreenState();
}

class _ViewShopScreenState extends State<ViewShopScreen> with SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final ReportService _reportService = ReportService();
  List<Product> _products = [];
  bool _isLoading = true;
  String? _shopLogo;
  double _shopRating = 0.0;
  int _reviewCount = 0;
  DateTime? _joinedDate;
  String? _shopDescription;
  late TabController _tabController;
  int _selectedTabIndex = 0;
  String? _selectedCategory;
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedTabIndex = _tabController.index;
          // Reset selected category when switching tabs
          if (_selectedTabIndex != 3) {
            _selectedCategory = null;
          }
        });
      }
    });
    _loadShopData();
    _loadShopProducts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadShopData() async {
    try {
      print('=== Loading shop data for seller_id: ${widget.sellerId} ===');
      
      // Get seller data including user_id
      final sellerResponse = await Supabase.instance.client
          .from('sellers')
          .select('shop_logo, rating, user_id, shop_description')
          .eq('seller_id', widget.sellerId)
          .maybeSingle();

      print('Seller response: $sellerResponse');

      DateTime? joinedDate;
      double rating = 0.0;
      String? shopLogo;
      String? shopDescription;
      
      if (sellerResponse != null) {
        shopLogo = sellerResponse['shop_logo'];
        rating = (sellerResponse['rating'] ?? 0.0).toDouble();
        shopDescription = sellerResponse['shop_description'];
        print('Shop logo: $shopLogo');
        print('Shop rating from sellers table: $rating');
        print('Shop description: $shopDescription');
        
        // Get user joined date using user_id from sellers table
        if (sellerResponse['user_id'] != null) {
          final userResponse = await Supabase.instance.client
              .from('users')
              .select('created_at')
              .eq('user_id', sellerResponse['user_id'])
              .maybeSingle();
          
          print('User response: $userResponse');
          
          if (userResponse != null && userResponse['created_at'] != null) {
            try {
              // Parse the datetime string (format: 2025-10-21 18:31:46 or ISO format)
              final createdAtStr = userResponse['created_at'].toString();
              print('Raw created_at string: $createdAtStr');
              joinedDate = DateTime.parse(createdAtStr);
              print('Successfully parsed joined date: $joinedDate');
            } catch (e) {
              print('Error parsing date: $e');
            }
          } else {
            print('No user found or no created_at field');
          }
        } else {
          print('No user_id in seller response');
        }
      } else {
        print('No seller found with seller_id: ${widget.sellerId}');
      }

      // Get review count - reviews are for products, so count all reviews for this seller's products
      // First get all product IDs for this seller
      final productsResponse = await Supabase.instance.client
          .from('products')
          .select('product_id')
          .eq('seller_id', widget.sellerId);

      print('Products response: $productsResponse');
      
      int reviewCount = 0;
      if (productsResponse.isNotEmpty) {
        final productIds = productsResponse.map((p) => p['product_id']).toList();
        print('Product IDs: $productIds');
        
        // Count reviews for all these products
        final reviewResponse = await Supabase.instance.client
            .from('product_reviews')
            .select('review_id')
            .inFilter('product_id', productIds);
        
        reviewCount = reviewResponse.length;
        print('Review count from product_reviews: $reviewCount');
      } else {
        print('No products found for this seller');
      }
      
      print('=== Shop data loading complete ===');

      if (mounted) {
        setState(() {
          _shopLogo = shopLogo;
          _shopRating = rating;
          _joinedDate = joinedDate;
          _reviewCount = reviewCount;
          _shopDescription = shopDescription;
        });
      }
    } catch (e) {
      print('!!! Error loading shop data: $e');
    }
  }

  Future<void> _loadShopProducts() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('products')
          .select('''
            *,
            product_images(image_id, image_url, is_primary, display_order, variant_id),
            product_variants(variant_id, color, hex_code, size, stock_quantity, image_url)
          ''')
          .eq('seller_id', widget.sellerId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      print('ViewShop - Loaded ${(response as List).length} products');
      
      // Extract unique categories
      final categories = <String>{};
      for (var item in (response as List)) {
        final category = item['category'];
        if (category != null && category.toString().isNotEmpty) {
          categories.add(category.toString());
        }
      }
      
      setState(() {
        _products = (response as List).map((item) => Product.fromJson(item)).toList();
        _categories = categories.toList()..sort();
        _isLoading = false;
      });
    } catch (e) {
      print('ViewShop - Error loading products: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _chatWithSeller() async {
    try {
      // Get buyer_id from AuthService
      final buyerId = _authService.currentBuyerId;
      
      if (buyerId == null) {
        if (mounted) {
          SnackBarHelper.showError(context, 'Please login to chat with seller');
        }
        return;
      }

      print('ViewShop - Starting chat with seller: ${widget.sellerId}, buyer: $buyerId');

      // Create or get conversation
      final conversation = await _chatService.getOrCreateConversation(
        buyerId: buyerId,
        sellerId: widget.sellerId,
      );

      print('ViewShop - Conversation created/retrieved: ${conversation?.conversationId}');

      if (conversation != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatConversationScreen(
              conversationId: conversation.conversationId,
              recipientName: widget.shopName,
              shopLogo: _shopLogo,
              userType: 'seller',
            ),
          ),
        );
      } else {
        if (mounted) {
          SnackBarHelper.showError(context, 'Could not create conversation');
        }
      }
    } catch (e) {
      print('Error starting chat: $e');
      if (mounted) {
        SnackBarHelper.showError(context, 'Error starting chat: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground(context),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildShopHeader()),
          SliverToBoxAdapter(child: _buildTabs()),
          _isLoading
              ? SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: AppColors.onSurface(context))),
                )
              : _buildTabContent(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: AppColors.surface(context),
      foregroundColor: AppColors.onSurface(context),
      elevation: 0,
      pinned: true,
      title: Text(
        'Seller Shop',
        style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
      ),
      actions: [
        IconButton(
          onPressed: _showReportModal,
          icon: Icon(Icons.report_outlined, size: 22.r),
          style: IconButton.styleFrom(
            foregroundColor: AppColors.onSurface(context),
          ),
        ),
        SizedBox(width: 8.w),
      ],
    );
  }

  void _showReportModal() {
    final categories = [
      {'value': 'fraud', 'label': 'Fraud'},
      {'value': 'harassment', 'label': 'Harassment'},
      {'value': 'poor_service', 'label': 'Poor Service'},
      {'value': 'fake_product', 'label': 'Fake Product'},
      {'value': 'rude_behavior', 'label': 'Rude Behavior'},
      {'value': 'other', 'label': 'Other'},
    ];

    String? selectedCategory;
    final reasonController = TextEditingController();
    XFile? selectedImage; // Single image
    bool isSubmitting = false;
    String? errorMessage;
    Timer? errorTimer;

    Future<void> pickImage(StateSetter setState) async {
      try {
        print('=== Starting image picker ===');
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
        
        print('Image picked: ${pickedFile?.path}');
        
        if (pickedFile != null) {
          print('Image selected');
          Future.microtask(() {
            if (context.mounted) {
              setState(() {
                selectedImage = pickedFile;
                errorMessage = null;
                errorTimer?.cancel();
              });
              print('State updated successfully');
            }
          });
        } else {
          print('No image selected');
        }
      } catch (e, stackTrace) {
        print('ERROR picking image: $e');
        print('Stack trace: $stackTrace');
        Future.microtask(() {
          if (context.mounted) {
            setState(() {
              errorMessage = 'Failed to select image: ${e.toString()}';
              errorTimer?.cancel();
              errorTimer = Timer(const Duration(seconds: 3), () {
                if (context.mounted) {
                  setState(() {
                    errorMessage = null;
                  });
                }
              });
            });
          }
        });
      }
    }

    Future<String?> uploadImage(XFile imageFile) async {
      try {
        final buyerId = _authService.currentBuyerId;
        if (buyerId == null) {
          throw Exception('User not logged in');
        }

        print('Reading image bytes...');
        final bytes = await imageFile.readAsBytes();
        print('Image size: ${bytes.length} bytes');
        
        final fileExtension = imageFile.path.split('.').last.toLowerCase();
        final fileName = 'report_${buyerId}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
        final filePath = 'static/uploads/reports/$fileName';
        
        print('Uploading image to: $filePath');
        
        await Supabase.instance.client.storage
            .from('Images')
            .uploadBinary(
              filePath, 
              bytes, 
              fileOptions: FileOptions(
                contentType: 'image/${fileExtension == 'jpg' ? 'jpeg' : fileExtension}',
                upsert: true,
              ),
            ).timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw Exception('Upload timeout');
              },
            );

        print('Image uploaded successfully: $filePath');
        return filePath;
      } catch (e) {
        print('Error uploading image: $e');
        rethrow;
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.r)),
          contentPadding: EdgeInsets.all(24.w),
          insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
          title: Text(
            'Report Seller',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                if (errorMessage != null) ...[
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      border: Border.all(color: Colors.red),
                      borderRadius: BorderRadius.circular(5.r),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 20.r),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: GoogleFonts.goudyBookletter1911(
                              fontSize: 13.sp,
                              color: Colors.red[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                ],
                Text(
                  'Shop: ${widget.shopName}',
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'Category',
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8.h),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  isExpanded: true,
                  menuMaxHeight: 300,
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5.r),
                      borderSide: BorderSide(color: AppColors.onSurface(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5.r),
                      borderSide: BorderSide(color: AppColors.onSurface(context)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5.r),
                      borderSide: BorderSide(color: AppColors.onSurface(context), width: 2),
                    ),
                  ),
                  hint: Text('Select category', style: GoogleFonts.goudyBookletter1911(fontSize: 13.sp)),
                  items: categories.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat['value'],
                      child: Text(cat['label']!, style: GoogleFonts.goudyBookletter1911(fontSize: 13.sp)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedCategory = value;
                      errorMessage = null;
                      errorTimer?.cancel();
                    });
                  },
                ),
                SizedBox(height: 16.h),
                Text(
                  'Reason',
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8.h),
                TextField(
                  controller: reasonController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Describe the issue...',
                    hintStyle: GoogleFonts.goudyBookletter1911(fontSize: 13.sp),
                    contentPadding: EdgeInsets.all(12.w),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5.r),
                      borderSide: BorderSide(color: AppColors.onSurface(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5.r),
                      borderSide: BorderSide(color: AppColors.onSurface(context)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5.r),
                      borderSide: BorderSide(color: AppColors.onSurface(context), width: 2),
                    ),
                  ),
                  style: GoogleFonts.goudyBookletter1911(fontSize: 13.sp),
                  onChanged: (value) {
                    if (errorMessage != null) {
                      setState(() {
                        errorMessage = null;
                        errorTimer?.cancel();
                      });
                    }
                  },
                ),
                SizedBox(height: 16.h),
                Text(
                  'Evidence (Optional)',
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8.h),
                GestureDetector(
                  onTap: () {
                    if (selectedImage != null) {
                      // Remove image
                      setState(() {
                        selectedImage = null;
                      });
                    } else {
                      // Pick image
                      pickImage(setState);
                    }
                  },
                  child: Container(
                    height: 120.h,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant(context),
                      border: Border.all(
                        color: selectedImage != null ? Colors.green : AppColors.border(context),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(5.r),
                    ),
                    child: selectedImage != null
                        ? Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4.r),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: double.infinity,
                                  child: FutureBuilder<Uint8List>(
                                    future: selectedImage!.readAsBytes(),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState == ConnectionState.done) {
                                        if (snapshot.hasData) {
                                          return Image.memory(
                                            snapshot.data!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                color: AppColors.surfaceVariant2(context),
                                                child: const Center(
                                                  child: Icon(Icons.error, color: Colors.red),
                                                ),
                                              );
                                            },
                                          );
                                        } else {
                                          return Container(
                                            color: AppColors.surfaceVariant2(context),
                                            child: const Center(
                                              child: Icon(Icons.error, color: Colors.red),
                                            ),
                                          );
                                        }
                                      }
                                      return Container(
                                        color: AppColors.surfaceVariant2(context),
                                        child: Center(
                                          child: SizedBox(
                                            width: 20.w,
                                            height: 20.h,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: EdgeInsets.all(4.w),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    color: AppColors.surface(context),
                                    size: 16.r,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color: Colors.grey,
                                  size: 40.r,
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  'Upload Evidence',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.r)),
              ),
              child: Text('Cancel', style: GoogleFonts.goudyBookletter1911(color: AppColors.onSurface(context))),
            ),
            ElevatedButton(
              onPressed: isSubmitting ? null : () async {
                if (selectedCategory == null || reasonController.text.trim().isEmpty) {
                  setState(() {
                    errorMessage = 'Please fill all required fields';
                    errorTimer?.cancel();
                    errorTimer = Timer(const Duration(seconds: 3), () {
                      if (context.mounted) {
                        setState(() {
                          errorMessage = null;
                        });
                      }
                    });
                  });
                  return;
                }

                setState(() {
                  isSubmitting = true;
                  errorMessage = null;
                  errorTimer?.cancel();
                });

                try {
                  // Get seller user_id from seller_id
                  final sellerResponse = await Supabase.instance.client
                      .from('sellers')
                      .select('user_id')
                      .eq('seller_id', int.parse(widget.sellerId))
                      .single();

                  final sellerUserId = sellerResponse['user_id'] as int;

                  // Upload image if selected
                  String? uploadedImagePath;
                  
                  if (selectedImage != null) {
                    uploadedImagePath = await uploadImage(selectedImage!);
                  }

                  // Submit report
                  final success = await _reportService.submitReport(
                    reportedUserId: sellerUserId,
                    reportedUserType: 'seller',
                    category: selectedCategory!,
                    reason: reasonController.text.trim(),
                    evidenceImage: uploadedImagePath,
                  );

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    if (success) {
                      SnackBarHelper.showSuccess(context, 'Report submitted successfully');
                    } else {
                      SnackBarHelper.showError(context, 'Failed to submit report');
                    }
                  }
                } catch (e) {
                  print('Error submitting report: $e');
                  setState(() {
                    isSubmitting = false;
                    errorMessage = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
                    errorTimer?.cancel();
                    errorTimer = Timer(const Duration(seconds: 3), () {
                      if (context.mounted) {
                        setState(() {
                          errorMessage = null;
                        });
                      }
                    });
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.onSurface(context),
                foregroundColor: AppColors.surface(context),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.r)),
              ),
              child: isSubmitting
                  ? SizedBox(
                      width: 16.w,
                      height: 16.h,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.surface(context)),
                    )
                  : Text('Submit Report', style: GoogleFonts.goudyBookletter1911()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopHeader() {
    // Format joined date as "Month Year" with abbreviated month if too long
    String joinedText = 'Recently';
    if (_joinedDate != null) {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      joinedText = '${months[_joinedDate!.month - 1]} ${_joinedDate!.year}';
    }
    
    print('Building shop header - Joined date: $_joinedDate, Display text: $joinedText');
    print('Shop rating: $_shopRating, Review count: $_reviewCount');

    return Container(
      padding: EdgeInsets.all(24.w),
      color: AppColors.surface(context),
      child: Column(
        children: [
          Container(
            width: 80.w,
            height: 80.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border(context), width: 2),
            ),
            child: ClipOval(
              child: _shopLogo != null && _shopLogo!.isNotEmpty
                  ? Builder(
                      builder: (context) {
                        final imageUrl = ImageHelper.getImageUrl(_shopLogo!);
                        if (imageUrl.isEmpty) {
                          return Container(
                            color: const Color(0xFFD3BD9B),
                            child: Icon(Icons.store, size: 40.r, color: AppColors.alwaysWhite),
                          );
                        }
                        return CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: AppColors.surfaceVariant2(context),
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) {
                            print('Error loading shop logo: $error');
                            return Container(
                              color: const Color(0xFFD3BD9B),
                              child: Icon(Icons.store, size: 40.r, color: AppColors.alwaysWhite),
                            );
                          },
                        );
                      },
                    )
                  : Container(
                      color: const Color(0xFFD3BD9B),
                      child: Icon(Icons.store, size: 40.r, color: AppColors.alwaysWhite),
                    ),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            widget.shopName,
            style: GoogleFonts.playfairDisplay(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_shopDescription != null && _shopDescription!.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Text(
              _shopDescription!,
              style: GoogleFonts.goudyBookletter1911(
                fontSize: 14.sp,
                color: AppColors.textMuted(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
          SizedBox(height: 16.h),
          // Shop stats with dividers (no outer border)
          IntrinsicHeight(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Products
                _buildStatItem(
                  value: '${_products.length}',
                  label: 'PRODUCTS',
                ),
                Container(
                  width: 1.w,
                  height: 40.h,
                  margin: EdgeInsets.symmetric(horizontal: 16.w),
                  color: AppColors.border(context),
                ),
                // Rating
                _buildStatItem(
                  value: _shopRating > 0 ? _shopRating.toStringAsFixed(1) : '0.0',
                  label: 'RATING',
                  icon: Icons.star,
                  iconColor: _shopRating > 0 ? Colors.amber[700] : AppColors.textFaint(context),
                ),
                Container(
                  width: 1.w,
                  height: 40.h,
                  margin: EdgeInsets.symmetric(horizontal: 16.w),
                  color: AppColors.border(context),
                ),
                // Reviews
                _buildStatItem(
                  value: '$_reviewCount',
                  label: 'REVIEWS',
                ),
                Container(
                  width: 1.w,
                  height: 40.h,
                  margin: EdgeInsets.symmetric(horizontal: 16.w),
                  color: AppColors.border(context),
                ),
                // Joined date
                _buildStatItem(
                  value: joinedText,
                  label: 'JOINED',
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          SizedBox(
            width: 200.w,
            child: OutlinedButton.icon(
              onPressed: _chatWithSeller,
              icon: Icon(Icons.chat_bubble_outline, size: 18.r),
              label: Text('Chat with Seller', style: GoogleFonts.goudyBookletter1911(fontSize: 14.sp)),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                side: BorderSide(color: AppColors.onSurface(context), width: 1.5),
                foregroundColor: AppColors.onSurface(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String value,
    required String label,
    IconData? icon,
    Color? iconColor,
  }) {
    // Use smaller font for longer text values (like dates)
    final isLongText = value.length > 8;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: GoogleFonts.playfairDisplay(
                fontSize: isLongText ? 12 : 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (icon != null) ...[
              SizedBox(width: 4.w),
              Icon(icon, size: 16.r, color: iconColor ?? AppColors.textMuted(context)),
            ],
          ],
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: GoogleFonts.goudyBookletter1911(
            fontSize: 11.sp,
            color: AppColors.textMuted(context),
            letterSpacing: 0.5.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      color: AppColors.surface(context),
      child: Column(
        children: [
          Container(
            height: 1.h,
            color: AppColors.surfaceVariant2(context),
          ),
          Row(
            children: [
              // Back button for category view
              if (_selectedTabIndex == 3 && _selectedCategory != null)
                IconButton(
                  icon: Icon(Icons.arrow_back, size: 20.r),
                  onPressed: () {
                    setState(() {
                      _selectedCategory = null;
                    });
                  },
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                ),
              Expanded(
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.onSurface(context),
                  unselectedLabelColor: AppColors.textMuted(context),
                  labelStyle: GoogleFonts.goudyBookletter1911(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: GoogleFonts.goudyBookletter1911(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.normal,
                  ),
                  indicatorColor: AppColors.onSurface(context),
                  indicatorWeight: 2,
                  tabs: const [
                    Tab(text: 'All'),
                    Tab(text: 'Best Selling'),
                    Tab(text: 'New'),
                    Tab(text: 'Category'),
                  ],
                ),
              ),
            ],
          ),
          // Show selected category name
          if (_selectedTabIndex == 3 && _selectedCategory != null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant(context),
                border: Border(
                  top: BorderSide(color: AppColors.surfaceVariant2(context)),
                ),
              ),
              child: Text(
                _selectedCategory!,
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    // If Category tab is selected and no category is chosen, show category list
    if (_selectedTabIndex == 3 && _selectedCategory == null) {
      return _buildCategoryList();
    }
    
    List<Product> filteredProducts = [];
    
    switch (_selectedTabIndex) {
      case 0: // All
        filteredProducts = _products;
        break;
      case 1: // Best Selling
        filteredProducts = List.from(_products)
          ..sort((a, b) => (b.totalSold ?? 0).compareTo(a.totalSold ?? 0));
        break;
      case 2: // New Arrivals
        filteredProducts = List.from(_products)
          ..sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
        break;
      case 3: // Category - filter by selected category
        if (_selectedCategory != null) {
          filteredProducts = _products.where((p) => p.category == _selectedCategory).toList();
        }
        break;
    }

    if (filteredProducts.isEmpty) {
      return _buildEmptyState();
    }

    return SliverPadding(
      padding: EdgeInsets.all(16.w),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: 2,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 12.h,
        childCount: filteredProducts.length,
        itemBuilder: (context, index) => _buildProductCard(filteredProducts[index]),
      ),
    );
  }

  Widget _buildCategoryList() {
    if (_categories.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.category_outlined, size: 100.r, color: AppColors.textFaint(context)),
              SizedBox(height: 16.h),
              Text(
                'No categories available',
                style: GoogleFonts.goudyBookletter1911(fontSize: 18.sp, color: AppColors.textMuted(context)),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.all(16.w),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final category = _categories[index];
            final productCount = _products.where((p) => p.category == category).length;
            
            return Container(
              margin: EdgeInsets.only(bottom: 12.h),
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
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                title: Text(
                  category,
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '$productCount ${productCount == 1 ? 'product' : 'products'}',
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 13.sp,
                    color: AppColors.textMuted(context),
                  ),
                ),
                trailing: Icon(Icons.arrow_forward_ios, size: 16.r),
                onTap: () {
                  setState(() {
                    _selectedCategory = category;
                  });
                },
              ),
            );
          },
          childCount: _categories.length,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 100.r, color: AppColors.textFaint(context)),
            SizedBox(height: 16.h),
            Text(
              'No products available',
              style: GoogleFonts.goudyBookletter1911(fontSize: 18.sp, color: AppColors.textMuted(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    final imageUrl = product.primaryImage != null && product.primaryImage!.isNotEmpty
        ? ImageHelper.getImageUrl(product.primaryImage!)
        : '';
    
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
          children: [
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
              child: AspectRatio(
                aspectRatio: 1,
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: AppColors.surfaceVariant2(context),
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: AppColors.surfaceVariant2(context),
                          child: Icon(Icons.image_not_supported, size: 40.r, color: Colors.grey),
                        ),
                      )
                    : Container(
                        color: AppColors.surfaceVariant2(context),
                        child: Icon(Icons.image_not_supported, size: 40.r, color: Colors.grey),
                      ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(12.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.productName,
                    style: GoogleFonts.goudyBookletter1911(fontSize: 13.sp, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '₱${product.price.toStringAsFixed(2)}',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurfaceStrong(context),
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
}
