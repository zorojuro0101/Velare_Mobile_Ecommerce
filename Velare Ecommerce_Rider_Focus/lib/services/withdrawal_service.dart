import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/withdrawal_model.dart';

class WithdrawalService {
  final _supabase = Supabase.instance.client;

  /// Get rider's available balance and earnings info
  Future<BalanceInfo> getAvailableBalance(String userId) async {
    try {
      print('🔍 Getting balance for user_id: $userId');

      // Get rider_id from user_id
      final riderData = await _supabase
          .from('riders')
          .select('rider_id')
          .eq('user_id', userId)
          .single();

      final riderId = riderData['rider_id'];
      print('✅ Found rider_id: $riderId');

      // Get pending withdrawals
      final pendingResponse = await _supabase
          .from('rider_withdrawals')
          .select('amount')
          .eq('rider_id', riderId)
          .eq('status', 'pending');

      final hasPending = pendingResponse.isNotEmpty;
      final pendingAmount = pendingResponse.fold<double>(
        0.0,
        (sum, item) => sum + ((item['amount'] ?? 0) as num).toDouble(),
      );

      // Get total earnings from delivered orders
      final earningsResponse = await _supabase
          .from('deliveries')
          .select('rider_earnings')
          .eq('rider_id', riderId)
          .eq('status', 'delivered');

      final totalEarnings = earningsResponse.fold<double>(
        0.0,
        (sum, item) => sum + ((item['rider_earnings'] ?? 0) as num).toDouble(),
      );

      // Get completed withdrawals
      final withdrawnResponse = await _supabase
          .from('rider_withdrawals')
          .select('amount')
          .eq('rider_id', riderId)
          .eq('status', 'completed');

      final totalWithdrawn = withdrawnResponse.fold<double>(
        0.0,
        (sum, item) => sum + ((item['amount'] ?? 0) as num).toDouble(),
      );

      // Calculate available balance
      final availableBalance = totalEarnings - totalWithdrawn - pendingAmount;

      print('💰 Total Earnings: ₱$totalEarnings');
      print('💸 Total Withdrawn: ₱$totalWithdrawn');
      print('⏳ Pending Amount: ₱$pendingAmount');
      print('✅ Available Balance: ₱$availableBalance');

      return BalanceInfo(
        availableBalance: availableBalance,
        totalEarnings: totalEarnings,
        totalWithdrawn: totalWithdrawn,
        pendingAmount: pendingAmount,
        hasPending: hasPending,
      );
    } catch (e) {
      print('❌ Error getting balance: $e');
      throw Exception('Failed to get balance: $e');
    }
  }

  /// Request a withdrawal
  Future<void> requestWithdrawal({
    required String userId,
    required double amount,
    String method = 'Cash',
    String? notes,
  }) async {
    try {
      // Validate minimum amount
      if (amount < 100) {
        throw Exception('Minimum withdrawal amount is ₱100.00');
      }

      // Get rider_id
      final riderData = await _supabase
          .from('riders')
          .select('rider_id')
          .eq('user_id', userId)
          .single();

      final riderId = riderData['rider_id'];

      // Check for existing pending withdrawal
      final pendingResponse = await _supabase
          .from('rider_withdrawals')
          .select('withdrawal_id')
          .eq('rider_id', riderId)
          .eq('status', 'pending');

      if (pendingResponse.isNotEmpty) {
        throw Exception(
          'You already have a pending withdrawal request. Please wait for it to be processed.',
        );
      }

      // Get balance info
      final balanceInfo = await getAvailableBalance(userId);

      // Check sufficient balance
      if (amount > balanceInfo.availableBalance) {
        throw Exception(
          'Insufficient balance. Available: ₱${balanceInfo.availableBalance.toStringAsFixed(2)}',
        );
      }

      // Additional safety check
      if (balanceInfo.availableBalance - amount < 0) {
        throw Exception('This withdrawal would result in a negative balance.');
      }

      // Insert withdrawal request
      await _supabase.from('rider_withdrawals').insert({
        'rider_id': riderId,
        'amount': amount,
        'withdrawal_method': method,
        'status': 'pending',
        'requested_at': DateTime.now().toIso8601String(),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });
    } catch (e) {
      throw Exception('Failed to request withdrawal: $e');
    }
  }

  /// Get withdrawal history
  Future<List<WithdrawalModel>> getWithdrawalHistory(String userId) async {
    try {
      // Get rider_id
      final riderData = await _supabase
          .from('riders')
          .select('rider_id')
          .eq('user_id', userId)
          .single();

      final riderId = riderData['rider_id'];

      // Fetch withdrawal history
      final response = await _supabase
          .from('rider_withdrawals')
          .select('*')
          .eq('rider_id', riderId)
          .order('requested_at', ascending: false);

      return (response as List)
          .map((json) => WithdrawalModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to get withdrawal history: $e');
    }
  }
}
