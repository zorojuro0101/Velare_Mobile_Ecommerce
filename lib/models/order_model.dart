class Order {
  final int id;
  final String orderNumber;
  final int buyerId;
  final int sellerId;
  final int addressId;
  final String? shopName;
  final String? shopLogo;
  final String? recipientName;
  final String? phoneNumber;
  final String? fullAddress;
  final double subtotal;
  final double shippingFee;
  final double discountAmount;
  final double totalAmount;
  final double commissionAmount;
  final int? voucherId;
  final String orderStatus;
  final bool orderReceived;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<OrderItem>? items;
  final String? deliveryStatus;
  final String? riderName;
  final String? riderContact;
  final bool hasReviews;

  Order({
    required this.id,
    required this.orderNumber,
    required this.buyerId,
    required this.sellerId,
    required this.addressId,
    this.shopName,
    this.shopLogo,
    this.recipientName,
    this.phoneNumber,
    this.fullAddress,
    required this.subtotal,
    required this.shippingFee,
    required this.discountAmount,
    required this.totalAmount,
    required this.commissionAmount,
    this.voucherId,
    required this.orderStatus,
    this.orderReceived = false,
    required this.createdAt,
    this.updatedAt,
    this.items,
    this.deliveryStatus,
    this.riderName,
    this.riderContact,
    this.hasReviews = false,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    String? recipientName;
    String? phoneNumber;
    String? fullAddress;
    
    if (json['addresses'] != null) {
      final address = json['addresses'];
      recipientName = address['recipient_name'];
      phoneNumber = address['phone_number'];
      
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
      fullAddress = parts.join(', ');
    }
    
    String? shopName;
    String? shopLogo;
    if (json['sellers'] != null) {
      shopName = json['sellers']['shop_name'];
      shopLogo = json['sellers']['shop_logo'];
    }
    
    String? deliveryStatus;
    String? riderName;
    String? riderContact;
    if (json['deliveries'] != null) {
      if (json['deliveries'] is List && (json['deliveries'] as List).isNotEmpty) {
        final delivery = (json['deliveries'] as List).first;
        deliveryStatus = delivery['status'];
        if (delivery['riders'] != null) {
          riderName = delivery['riders']['name'];
          riderContact = delivery['riders']['contact_number'];
        }
      } else if (json['deliveries'] is Map) {
        deliveryStatus = json['deliveries']['status'];
        if (json['deliveries']['riders'] != null) {
          riderName = json['deliveries']['riders']['name'];
          riderContact = json['deliveries']['riders']['contact_number'];
        }
      }
    }
    
    return Order(
      id: json['order_id'] ?? 0,
      orderNumber: json['order_number'] ?? '',
      buyerId: json['buyer_id'] ?? 0,
      sellerId: json['seller_id'] ?? 0,
      addressId: json['address_id'] ?? 0,
      shopName: shopName,
      shopLogo: shopLogo,
      recipientName: recipientName,
      phoneNumber: phoneNumber,
      fullAddress: fullAddress,
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      shippingFee: (json['shipping_fee'] ?? 0).toDouble(),
      discountAmount: (json['discount_amount'] ?? 0).toDouble(),
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      commissionAmount: (json['commission_amount'] ?? 0).toDouble(),
      voucherId: json['voucher_id'],
      orderStatus: json['order_status'] ?? 'pending',
      orderReceived: json['order_received'] == 1 || json['order_received'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      items: json['order_items'] != null
          ? (json['order_items'] as List)
              .map((item) => OrderItem.fromJson(item))
              .toList()
          : null,
      deliveryStatus: deliveryStatus,
      riderName: riderName,
      riderContact: riderContact,
      hasReviews: json['has_reviews'] == true || json['has_reviews'] == 1,
    );
  }

  String get statusDisplay {
    switch (orderStatus) {
      case 'pending':
        return 'Pending';
      case 'preparing':
        return 'Preparing for Shipment';
      case 'ready_for_pickup':
        return 'Ready for Pickup';
      case 'in_transit':
        return 'In Transit';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return orderStatus;
    }
  }
}

class OrderItem {
  final int id;
  final int orderId;
  final int productId;
  final String productName;
  final String? materials;
  final String? variantColor;
  final String? variantSize;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final String? primaryImage;

  OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.productName,
    this.materials,
    this.variantColor,
    this.variantSize,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.primaryImage,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    String? primaryImage;
    print('=== Parsing OrderItem ===');
    print('JSON: $json');
    
    if (json['products'] != null && json['products']['primary_image'] != null) {
      primaryImage = json['products']['primary_image'];
      print('Found primary_image: $primaryImage');
    } else {
      print('No products or primary_image found');
    }
    
    return OrderItem(
      id: json['order_item_id'] ?? 0,
      orderId: json['order_id'] ?? 0,
      productId: json['product_id'] ?? 0,
      productName: json['product_name'] ?? '',
      materials: json['materials'],
      variantColor: json['variant_color'],
      variantSize: json['variant_size'],
      quantity: json['quantity'] ?? 1,
      unitPrice: (json['unit_price'] ?? 0).toDouble(),
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      primaryImage: primaryImage,
    );
  }
}
