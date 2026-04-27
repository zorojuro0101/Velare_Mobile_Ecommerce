class DeliveryOption {
  final int deliveryId;
  final int orderId;
  final String orderNumber;
  final int buyerId;
  final String buyerName;
  final int sellerId;
  final String sellerName;

  DeliveryOption({
    required this.deliveryId,
    required this.orderId,
    required this.orderNumber,
    required this.buyerId,
    required this.buyerName,
    required this.sellerId,
    required this.sellerName,
  });

  factory DeliveryOption.fromJson(Map<String, dynamic> json) {
    final order = json['orders'] ?? {};
    final buyer = order['buyers'] ?? {};
    final seller = order['sellers'] ?? {};

    return DeliveryOption(
      deliveryId: json['delivery_id'],
      orderId: order['order_id'],
      orderNumber: order['order_number'] ?? '',
      buyerId: order['buyer_id'],
      buyerName: '${buyer['first_name'] ?? ''} ${buyer['last_name'] ?? ''}'
          .trim(),
      sellerId: order['seller_id'],
      sellerName: seller['shop_name'] ?? '',
    );
  }

  String get displayText {
    return 'Delivery #$deliveryId - Order #$orderNumber\n(Buyer: $buyerName, Seller: $sellerName)';
  }
}

enum ReportCategory {
  fraud('fraud', 'Fraud/Scam'),
  harassment('harassment', 'Harassment'),
  rudeBehavior('rude_behavior', 'Rude Behavior'),
  poorService('poor_service', 'Poor Service'),
  fakeProduct('fake_product', 'Fake Product Claim'),
  other('other', 'Other');

  final String value;
  final String label;

  const ReportCategory(this.value, this.label);

  static ReportCategory? fromValue(String value) {
    try {
      return ReportCategory.values.firstWhere((cat) => cat.value == value);
    } catch (e) {
      return null;
    }
  }
}

enum ReportStatus {
  pending('pending', 'Pending'),
  underReview('under_review', 'Under Review'),
  resolved('resolved', 'Resolved'),
  dismissed('dismissed', 'Dismissed');

  final String value;
  final String label;

  const ReportStatus(this.value, this.label);

  static ReportStatus? fromValue(String value) {
    try {
      return ReportStatus.values.firstWhere((status) => status.value == value);
    } catch (e) {
      return null;
    }
  }
}

class Report {
  final int reportId;
  final int reporterId;
  final String reporterType;
  final int reportedUserId;
  final String reportedUserType;
  final String reportCategory;
  final String reportReason;
  final int? orderId;
  final int? deliveryId;
  final String? evidenceImage;
  final String status;
  final String? adminNotes;
  final DateTime createdAt;
  final String reportedUserName;

  Report({
    required this.reportId,
    required this.reporterId,
    required this.reporterType,
    required this.reportedUserId,
    required this.reportedUserType,
    required this.reportCategory,
    required this.reportReason,
    this.orderId,
    this.deliveryId,
    this.evidenceImage,
    required this.status,
    this.adminNotes,
    required this.createdAt,
    required this.reportedUserName,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      reportId: json['report_id'],
      reporterId: json['reporter_id'],
      reporterType: json['reporter_type'],
      reportedUserId: json['reported_user_id'],
      reportedUserType: json['reported_user_type'],
      reportCategory: json['report_category'],
      reportReason: json['report_reason'],
      orderId: json['order_id'],
      deliveryId: json['delivery_id'],
      evidenceImage: json['evidence_image'],
      status: json['status'],
      adminNotes: json['admin_notes'],
      createdAt: DateTime.parse(json['created_at']),
      reportedUserName: json['reported_user_name'] ?? 'Unknown',
    );
  }

  ReportCategory? get categoryEnum => ReportCategory.fromValue(reportCategory);
  ReportStatus? get statusEnum => ReportStatus.fromValue(status);
}
