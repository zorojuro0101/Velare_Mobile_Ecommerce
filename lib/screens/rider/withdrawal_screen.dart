import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/withdrawal_service.dart';
import '../../services/auth_service.dart';
import '../../models/withdrawal_model.dart';
import '../../utils/snackbar_helper.dart';
import 'withdrawal_history_screen.dart';

import '../../utils/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
class WithdrawalScreen extends StatefulWidget {
  const WithdrawalScreen({super.key});

  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  final WithdrawalService _withdrawalService = WithdrawalService();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  BalanceInfo? _balanceInfo;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String _selectedMethod = 'Cash';

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    setState(() => _isLoading = true);
    try {
      final userId = AuthService().currentUserId;
      if (userId == null) throw Exception('User not logged in');

      final balance = await _withdrawalService.getAvailableBalance(userId);
      if (mounted) {
        setState(() {
          _balanceInfo = balance;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        SnackBarHelper.showError(context, 'Failed to load balance');
      }
    }
  }

  Future<void> _submitWithdrawal() async {
    final amount = double.tryParse(_amountController.text);

    if (amount == null || amount <= 0) {
      SnackBarHelper.showError(context, 'Please enter a valid amount');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userId = AuthService().currentUserId;
      if (userId == null) throw Exception('User not logged in');

      await _withdrawalService.requestWithdrawal(
        userId: userId,
        amount: amount,
        method: _selectedMethod,
        notes: _notesController.text.trim(),
      );

      if (mounted) {
        _amountController.clear();
        _notesController.clear();
        await _loadBalance();

        SnackBarHelper.showSuccess(
          context,
          'Withdrawal request submitted successfully!',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          'Failed to submit withdrawal request',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.surface(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.onSurface(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Withdraw Earnings',
          style: GoogleFonts.goudyBookletter1911(
            color: AppColors.onSurface(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WithdrawalHistoryScreen(),
                ),
              );
            },
            icon: Icon(Icons.history, size: 20.r),
            label: Text(
              'History',
              style: GoogleFonts.goudyBookletter1911(fontSize: 14.sp),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBalance,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBalanceCard(),
                    SizedBox(height: 24.h),
                    _buildWithdrawalForm(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBalanceCard() {
    final balance = _balanceInfo;
    if (balance == null) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(5.r),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Balance',
            style: GoogleFonts.goudyBookletter1911(
              color: Colors.white70,
              fontSize: 14.sp,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '₱${balance.availableBalance.toStringAsFixed(2)}',
            style: GoogleFonts.goudyBookletter1911(
              color: AppColors.surface(context),
              fontSize: 36.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 24.h),
          Row(
            children: [
              Expanded(
                child: _buildBalanceItem(
                  'Total Earnings',
                  '₱${balance.totalEarnings.toStringAsFixed(2)}',
                ),
              ),
              Expanded(
                child: _buildBalanceItem(
                  'Withdrawn',
                  '₱${balance.totalWithdrawn.toStringAsFixed(2)}',
                ),
              ),
            ],
          ),
          if (balance.hasPending) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(5.r),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.pending, color: Colors.orange, size: 20.r),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Pending: ₱${balance.pendingAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.goudyBookletter1911(
                        color: AppColors.surface(context),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBalanceItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.goudyBookletter1911(
            color: Colors.white70,
            fontSize: 12.sp,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: GoogleFonts.goudyBookletter1911(
            color: AppColors.surface(context),
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildWithdrawalForm() {
    final balance = _balanceInfo;
    final hasPending = balance?.hasPending ?? false;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(5.r),
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
          Text(
            'Request Withdrawal',
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 20.h),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            enabled: !hasPending && !_isSubmitting,
            decoration: InputDecoration(
              labelText: 'Amount',
              hintText: 'Minimum ₱100.00',
              prefixText: '₱ ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5.r),
              ),
              labelStyle: GoogleFonts.goudyBookletter1911(),
              hintStyle: GoogleFonts.goudyBookletter1911(fontSize: 13.sp),
            ),
            style: GoogleFonts.goudyBookletter1911(),
          ),
          SizedBox(height: 16.h),
          DropdownButtonFormField<String>(
            value: _selectedMethod,
            decoration: InputDecoration(
              labelText: 'Withdrawal Method',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5.r),
              ),
              labelStyle: GoogleFonts.goudyBookletter1911(),
            ),
            style: GoogleFonts.goudyBookletter1911(color: AppColors.onSurface(context)),
            items: ['Cash', 'Bank Transfer', 'GCash']
                .map(
                  (method) =>
                      DropdownMenuItem(value: method, child: Text(method)),
                )
                .toList(),
            onChanged: hasPending || _isSubmitting
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _selectedMethod = value);
                    }
                  },
          ),
          SizedBox(height: 16.h),
          TextField(
            controller: _notesController,
            maxLines: 3,
            enabled: !hasPending && !_isSubmitting,
            decoration: InputDecoration(
              labelText: 'Notes (Optional)',
              hintText: 'Add any additional information...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5.r),
              ),
              labelStyle: GoogleFonts.goudyBookletter1911(),
              hintStyle: GoogleFonts.goudyBookletter1911(fontSize: 13.sp),
            ),
            style: GoogleFonts.goudyBookletter1911(),
          ),
          SizedBox(height: 24.h),
          if (hasPending)
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(5.r),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'You have a pending withdrawal. Please wait for it to be processed.',
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 13.sp,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: AppColors.surface(context),
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5.r),
                  ),
                ),
                onPressed: _isSubmitting ? null : _submitWithdrawal,
                child: _isSubmitting
                    ? SizedBox(
                        height: 20.h,
                        width: 20.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.surface(context),
                          ),
                        ),
                      )
                    : Text(
                        'Submit Request',
                        style: GoogleFonts.goudyBookletter1911(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          SizedBox(height: 12.h),
          Text(
            '• Minimum withdrawal: ₱100.00\n'
            '• Only one pending request at a time\n'
            '• Processing time: 1-3 business days',
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 12.sp,
              color: AppColors.textMuted(context),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
