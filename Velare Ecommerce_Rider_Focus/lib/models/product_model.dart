class Product {
  final int id;
  final String productName;
  final String? description;
  final double price;
  final String? category;
  final String? primaryImage;
  final List<String>? additionalImages;
  final bool isFeatured;
  final int stockQuantity;
  final String? sellerId;
  final String? shopName;
  final String? shopLogo;
  final String? badgeType;
  final DateTime? createdAt;

  Product({
    required this.id,
    required this.productName,
    this.description,
    required this.price,
    this.category,
    this.primaryImage,
    this.additionalImages,
    this.isFeatured = false,
    this.stockQuantity = 0,
    this.sellerId,
    this.shopName,
    this.shopLogo,
    this.badgeType,
    this.createdAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    print('Product.fromJson - Input: $json');
    
    // Handle primary_image from product_images array
    String? primaryImage;
    List<String>? additionalImages;
    
    if (json['product_images'] != null) {
      final images = json['product_images'];
      if (images is List && images.isNotEmpty) {
        // Sort by display_order if available, or use is_primary
        final sortedImages = List<Map<String, dynamic>>.from(images);
        sortedImages.sort((a, b) {
          // Primary image first
          if (a['is_primary'] == true) return -1;
          if (b['is_primary'] == true) return 1;
          // Then by display_order
          final orderA = a['display_order'] ?? 999;
          final orderB = b['display_order'] ?? 999;
          return orderA.compareTo(orderB);
        });
        
        // Get all image URLs
        final allImageUrls = sortedImages.map((img) => img['image_url'] as String).toList();
        
        // Primary image is the first one
        primaryImage = allImageUrls.first;
        
        // Additional images are all images (for gallery view)
        additionalImages = allImageUrls;
        
        print('Product.fromJson - Got ${allImageUrls.length} images from product_images');
        print('Product.fromJson - Primary image: $primaryImage');
      }
    }
    
    // Fallback to direct primary_image field if exists
    if (primaryImage == null && json['primary_image'] != null) {
      primaryImage = json['primary_image'];
    }
    
    // Handle additional_images from JSON field if exists
    if (additionalImages == null && json['additional_images'] != null) {
      additionalImages = List<String>.from(json['additional_images']);
    }
    
    // Calculate total stock from product_variants
    int totalStock = 0;
    if (json['product_variants'] != null) {
      final variants = json['product_variants'];
      if (variants is List) {
        for (var variant in variants) {
          totalStock += (variant['stock_quantity'] ?? 0) as int;
        }
        print('Product.fromJson - Calculated total stock from ${variants.length} variants: $totalStock');
      }
    }
    
    // Fallback to stock_quantity field if exists and no variants
    if (totalStock == 0 && json['stock_quantity'] != null) {
      totalStock = json['stock_quantity'] as int;
    }
    
    print('Product.fromJson - Final primary_image: $primaryImage');
    print('Product.fromJson - Total images: ${additionalImages?.length ?? 0}');
    print('Product.fromJson - Total stock: $totalStock');
    
    return Product(
      id: json['product_id'] ?? json['id'] ?? 0,
      productName: json['product_name'] ?? '',
      description: json['description'],
      price: (json['price'] ?? 0).toDouble(),
      category: json['category'],
      primaryImage: primaryImage,
      additionalImages: additionalImages,
      isFeatured: json['is_featured'] ?? false,
      stockQuantity: totalStock,
      sellerId: json['seller_id']?.toString(),
      shopName: json['shop_name'],
      shopLogo: json['shop_logo'],
      badgeType: json['badge_type'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_name': productName,
      'description': description,
      'price': price,
      'category': category,
      'primary_image': primaryImage,
      'additional_images': additionalImages,
      'is_featured': isFeatured,
      'stock_quantity': stockQuantity,
      'seller_id': sellerId,
      'shop_name': shopName,
      'shop_logo': shopLogo,
      'badge_type': badgeType,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
