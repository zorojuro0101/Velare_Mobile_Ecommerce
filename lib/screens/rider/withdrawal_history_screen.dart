import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/withdrawal_service.dart';
import '../../services/auth_service.dart';
import '../../models/withdrawal_model.dart';

import '../../utils/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
class WithdrawalHistoryScreen extends StatefulWidget {
  const WithdrawalHistoryScreen({super.key});

  @override
  State<WithdrawalHistoryScreen> createState() =>
      _WithdrawalHistoryScreenState();
}

class _WithdrawalHistoryScreenState extends State<WithdrawalHistoryScreen> {
  final WithdrawalService _withdrawalService = WithdrawalService();
  List<WithdrawalModel> _withdrawals = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final userId = AuthService().currentUserId;
      if (userId == null) throw Exception('User not logged in');

      final withdrawals = await _withdrawalService.getWithdrawalHistory(userId);
      if (mounted) {
        setState(() {
          _withdrawals = withdrawals;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load history',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<WithdrawalModel> get _filteredWithdrawals {
    if (_selectedFilter == 'All') return _withdrawals;
    return _withdrawals
        .where((w) => w.status.toLowerCase() == _selectedFilter.toLowerCase())
        .toList();
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
          'Withdrawal History',
          style: GoogleFonts.poppins(
            color: AppColors.onSurface(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredWithdrawals.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadHistory,
                    child: ListView.builder(
                      padding: EdgeInsets.all(16.w),
                      itemCount: _filteredWithdrawals.length,
                      itemBuilder: (context, index) {
                        return _buildWithdrawalCard(
                          _filteredWithdrawals[index],
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      color: AppColors.surface(context),
      child: Row(
        children: [
          _buildFilterChip('All'),
          SizedBox(width: 8.w),
          _buildFilterChip('Pending'),
          SizedBox(width: 8.w),
          _buildFilterChip('Completed'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return FilterChip(
      label: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 13.sp,
          color: isSelected ? AppColors.surface(context) : AppColors.textBody(context),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedFilter = label);
      },
      backgroundColor: AppColors.surfaceVariant2(context),
      selectedColor: Colors.green,
      checkmarkColor: AppColors.surface(context),
    );
  }

  Widget _buildWithdrawalCard(WithdrawalModel withdrawal) {
    final statusColor = withdrawal.status == 'completed'
        ? Colors.green
        : Colors.orange;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(12.r),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₱${withdrawal.amount.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 12.w,
                  vertical: 6.h,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6.r),
                  border: Border.all(color: statusColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      withdrawal.status == 'completed'
                          ? Icons.check_circle
                          : Icons.pending,
                      size: 16,
                      color: statusColor,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      withdrawal.status.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _buildInfoRow(Icons.payment, 'Method', withdrawal.withdrawalMethod),
          SizedBox(height: 8.h),
          _buildInfoRow(
            Icons.calendar_today,
            'Requested',
            _formatDate(withdrawal.requestedAt),
          ),
          if (withdrawal.processedAt != null) ...[
            SizedBox(height: 8.h),
            _buildInfoRow(
              Icons.check_circle_outline,
              'Processed',
              _formatDate(withdrawal.processedAt!),
            ),
          ],
          if (withdrawal.notes != null && withdrawal.notes!.isNotEmpty) ...[
            const Divider(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.note, size: 16.r, color: AppColors.textMuted(context)),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    withdrawal.notes!,
                    style: GoogleFonts.poppins(
                      fontSize: 13.sp,
                      color: AppColors.textBody(context),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16.r, color: AppColors.textMuted(context)),
        SizedBox(width: 8.w),
        Text(
          '$label: ',
          style: GoogleFonts.poppins(fontSize: 13.sp, color: AppColors.textMuted(context)),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(fontSize: 13.sp, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 80.r,
            color: AppColors.border(context),
          ),
          SizedBox(height: 16.h),
          Text(
            'No withdrawal history',
            style: GoogleFonts.poppins(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted(context),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            _selectedFilter == 'All'
                ? 'You haven\'t made any withdrawals yet'
                : 'No $_selectedFilter withdrawals found',
            style: GoogleFonts.poppins(fontSize: 14.sp, color: AppColors.textFaint(context)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
