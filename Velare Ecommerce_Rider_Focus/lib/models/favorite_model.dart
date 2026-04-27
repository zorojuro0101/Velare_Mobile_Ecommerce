class FavoriteItem {
  final int favoriteId;
  final int productId;
  final String productName;
  final double price;
  final String? primaryImage;
  final String? shopName;
  final DateTime? addedAt;

  FavoriteItem({
    required this.favoriteId,
    required this.productId,
    required this.productName,
    required this.price,
    this.primaryImage,
    this.shopName,
    this.addedAt,
  });

  factory FavoriteItem.fromJson(Map<String, dynamic> json) {
    // Extract product data from nested products object
    final productData = json['products'];
    
    // Extract primary image from product_images array
    String? primaryImage;
    if (productData != null && productData['product_images'] != null) {
      final images = productData['product_images'] as List;
      if (images.isNotEmpty) {
        // Sort by is_primary and display_order
        images.sort((a, b) {
          final aPrimary = a['is_primary'] == true ? 0 : 1;
          final bPrimary = b['is_primary'] == true ? 0 : 1;
          if (aPrimary != bPrimary) return aPrimary.compareTo(bPrimary);
          final aOrder = a['display_order'] ?? 999;
          final bOrder = b['display_order'] ?? 999;
          return aOrder.compareTo(bOrder);
        });
        primaryImage = images.first['image_url'];
      }
    }
    
    return FavoriteItem(
      favoriteId: json['favorite_id'] ?? json['id'] ?? 0,
      productId: json['product_id'] ?? 0,
      productName: productData?['product_name'] ?? '',
      price: (productData?['price'] ?? 0).toDouble(),
      primaryImage: primaryImage,
      shopName: productData?['shop_name'],
      addedAt: json['added_at'] != null
          ? DateTime.parse(json['added_at'])
          : null,
    );
  }
}
