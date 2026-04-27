class CartItem {
  final int cartId;
  final int productId;
  final String productName;
  final double price;
  final int quantity;
  final String? primaryImage;
  final String? color;
  final String? size;
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
    required this.sellerId,
    required this.shopName,
    this.shopLogo,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      cartId: json['cart_id'] ?? json['id'] ?? 0,
      productId: json['product_id'] ?? 0,
      productName: json['product_name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 1,
      primaryImage: json['primary_image'],
      color: json['color'],
      size: json['size'],
      sellerId: json['seller_id'] ?? '',
      shopName: json['shop_name'] ?? '',
      shopLogo: json['shop_logo'],
    );
  }

  double get totalPrice => price * quantity;
}
