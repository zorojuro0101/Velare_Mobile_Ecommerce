import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/withdrawal_service.dart';
import '../../services/auth_service.dart';
import '../../models/withdrawal_model.dart';
import '../../utils/snackbar_helper.dart';
import 'withdrawal_history_screen.dart';

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
        SnackBarHelper.showError(context, 'Failed to submit withdrawal request');
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Withdraw Earnings',
          style: GoogleFonts.poppins(
            color: Colors.black,
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
            icon: const Icon(Icons.history, size: 20),
            label: Text('History', style: GoogleFonts.poppins(fontSize: 14)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBalance,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBalanceCard(),
                    const SizedBox(height: 24),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
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
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            '₱${balance.availableBalance.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
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
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pending, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pending: ₱${balance.pendingAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 13,
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
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            enabled: !hasPending && !_isSubmitting,
            decoration: InputDecoration(
              labelText: 'Amount',
              hintText: 'Minimum ₱100.00',
              prefixText: '₱ ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              labelStyle: GoogleFonts.poppins(),
              hintStyle: GoogleFonts.poppins(fontSize: 13),
            ),
            style: GoogleFonts.poppins(),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedMethod,
            decoration: InputDecoration(
              labelText: 'Withdrawal Method',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              labelStyle: GoogleFonts.poppins(),
            ),
            style: GoogleFonts.poppins(color: Colors.black),
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
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            maxLines: 3,
            enabled: !hasPending && !_isSubmitting,
            decoration: InputDecoration(
              labelText: 'Notes (Optional)',
              hintText: 'Add any additional information...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              labelStyle: GoogleFonts.poppins(),
              hintStyle: GoogleFonts.poppins(fontSize: 13),
            ),
            style: GoogleFonts.poppins(),
          ),
          const SizedBox(height: 24),
          if (hasPending)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You have a pending withdrawal. Please wait for it to be processed.',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
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
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isSubmitting ? null : _submitWithdrawal,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        'Submit Request',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            '• Minimum withdrawal: ₱100.00\n'
            '• Only one pending request at a time\n'
            '• Processing time: 1-3 business days',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
