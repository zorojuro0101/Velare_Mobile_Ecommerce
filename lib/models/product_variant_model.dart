class ProductVariant {
  final int variantId;
  final int productId;
  final String? color;
  final String? size;
  final int stockQuantity;
  final String? imageUrl;

  ProductVariant({
    required this.variantId,
    required this.productId,
    this.color,
    this.size,
    required this.stockQuantity,
    this.imageUrl,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      variantId: json['variant_id'] ?? 0,
      productId: json['product_id'] ?? 0,
      color: json['color']?.toString(),
      size: json['size']?.toString(),
      stockQuantity: json['stock_quantity'] ?? 0,
      imageUrl: json['image_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'variant_id': variantId,
      'product_id': productId,
      'color': color,
      'size': size,
      'stock_quantity': stockQuantity,
      'image_url': imageUrl,
    };
  }

  String get displayName {
    final parts = <String>[];
    if (color != null && color!.isNotEmpty) parts.add(color!);
    if (size != null && size!.isNotEmpty) parts.add(size!);
    return parts.isEmpty ? 'Default' : parts.join(' - ');
  }
}
