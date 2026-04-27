class CartItem {
  final int cartId;
  final int productId;
  final String productName;
  final double price;
  final int quantity;
  final String? primaryImage;
  final String? color;
  final String? size;
  final int? variantId;
  final String? materials;
  final String sellerId;
  final String shopName;
  final String? shopLogo;

  CartItem({
    required this.cartId,
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    this.primaryImage,
    this.color,
    this.size,
    this.variantId,
    this.materials,
    required this.sellerId,
    required this.shopName,
    this.shopLogo,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    // Handle nested products data
    final productData = json['products'] is Map ? json['products'] as Map<String, dynamic> : null;
    final variantData = json['product_variants'] is Map ? json['product_variants'] as Map<String, dynamic> : null;
    final sellerData = productData != null && productData['sellers'] is Map 
        ? productData['sellers'] as Map<String, dynamic> 
        : null;
    
    return CartItem(
      cartId: json['cart_id'] ?? json['id'] ?? 0,
      productId: json['product_id'] ?? 0,
      productName: productData?['product_name'] ?? json['product_name'] ?? '',
      price: (productData?['price'] ?? json['price'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 1,
      primaryImage: json['primary_image'],
      color: variantData?['color'],
      size: variantData?['size'],
      variantId: json['variant_id'],
      materials: productData?['materials'],
      sellerId: productData?['seller_id']?.toString() ?? json['seller_id']?.toString() ?? '',
      shopName: sellerData?['shop_name'] ?? json['shop_name'] ?? 'Unknown Shop',
      shopLogo: sellerData?['shop_logo'],
    );
  }

  double get totalPrice => price * quantity;
}
