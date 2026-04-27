class WithdrawalModel {
  final int? withdrawalId;
  final int riderId;
  final double amount;
  final String withdrawalMethod;
  final String status; // 'pending' or 'completed'
  final DateTime requestedAt;
  final DateTime? processedAt;
  final String? notes;

  WithdrawalModel({
    this.withdrawalId,
    required this.riderId,
    required this.amount,
    this.withdrawalMethod = 'Cash',
    this.status = 'pending',
    required this.requestedAt,
    this.processedAt,
    this.notes,
  });

  factory WithdrawalModel.fromJson(Map<String, dynamic> json) {
    return WithdrawalModel(
      withdrawalId: json['withdrawal_id'],
      riderId: json['rider_id'],
      amount: (json['amount'] ?? 0).toDouble(),
      withdrawalMethod: json['withdrawal_method'] ?? 'Cash',
      status: json['status'] ?? 'pending',
      requestedAt: DateTime.parse(json['requested_at']),
      processedAt: json['processed_at'] != null
          ? DateTime.parse(json['processed_at'])
          : null,
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (withdrawalId != null) 'withdrawal_id': withdrawalId,
      'rider_id': riderId,
      'amount': amount,
      'withdrawal_method': withdrawalMethod,
      'status': status,
      'requested_at': requestedAt.toIso8601String(),
      if (processedAt != null) 'processed_at': processedAt!.toIso8601String(),
      if (notes != null) 'notes': notes,
    };
  }
}

class BalanceInfo {
  final double availableBalance;
  final double totalEarnings;
  final double totalWithdrawn;
  final double pendingAmount;
  final bool hasPending;

  BalanceInfo({
    required this.availableBalance,
    required this.totalEarnings,
    required this.totalWithdrawn,
    required this.pendingAmount,
    required this.hasPending,
  });

  factory BalanceInfo.fromJson(Map<String, dynamic> json) {
    return BalanceInfo(
      availableBalance: (json['availableBalance'] ?? 0).toDouble(),
      totalEarnings: (json['totalEarnings'] ?? 0).toDouble(),
      totalWithdrawn: (json['totalWithdrawn'] ?? 0).toDouble(),
      pendingAmount: (json['pendingAmount'] ?? 0).toDouble(),
      hasPending: json['hasPending'] ?? false,
    );
  }
}
