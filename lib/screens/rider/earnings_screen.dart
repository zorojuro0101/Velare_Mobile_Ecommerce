import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/withdrawal_service.dart';
import '../../models/withdrawal_model.dart';
import 'withdrawal_history_screen.dart';

import '../../utils/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
class EarningsScreen extends StatefulWidget {
  final bool hideScaffold;

  const EarningsScreen({super.key, this.hideScaffold = false});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  final WithdrawalService _withdrawalService = WithdrawalService();
  late Future<List<dynamic>> _ordersFuture;
  BalanceInfo? _balanceInfo;
  bool _isLoadingBalance = true;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _loadBalance();
  }

  void _loadOrders() {
    final userId = AuthService().currentUserId;
    if (userId != null) {
      setState(() {
        _ordersFuture = _getDeliveredOrders(userId);
      });
    }
  }

  Future<List<dynamic>> _getDeliveredOrders(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      // Get rider_id from user_id
      final riderData = await supabase
          .from('riders')
          .select('rider_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (riderData == null) {
        return [];
      }

      final riderId = riderData['rider_id'];

      // Get all delivered orders with buyer and seller info
      final response = await supabase
          .from('deliveries')
          .select('''
            delivery_id,
            order_id,
            pickup_address,
            delivery_address,
            delivery_fee,
            rider_earnings,
            status,
            delivered_at,
            orders!inner(
              order_id,
              order_number,
              total_amount,
              buyers(first_name, last_name),
              sellers(shop_name, first_name, last_name)
            )
          ''')
          .eq('rider_id', riderId)
          .eq('status', 'delivered')
          .order('delivered_at', ascending: false);

      return response as List<dynamic>;
    } catch (e) {
      print('Error loading delivered orders: $e');
      throw Exception('Failed to load earnings data');
    }
  }

  Future<void> _loadBalance() async {
    setState(() => _isLoadingBalance = true);
    try {
      final userId = AuthService().currentUserId;
      if (userId == null) throw Exception('User not logged in');

      final balance = await _withdrawalService.getAvailableBalance(userId);
      if (mounted) {
        setState(() {
          _balanceInfo = balance;
          _isLoadingBalance = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingBalance = false);
      }
    }
  }

  Future<void> _showWithdrawalDialog() async {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    String selectedMethod = 'Cash';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Request Withdrawal',
            style: GoogleFonts.goudyBookletter1911(fontWeight: FontWeight.w600),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available: ₱${_balanceInfo?.availableBalance.toStringAsFixed(2) ?? '0.00'}',
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 13.sp,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 16.h),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    hintText: 'Minimum ₱100.00',
                    prefixText: '₱ ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5.r),
                    ),
                    labelStyle: GoogleFonts.goudyBookletter1911(),
                  ),
                  style: GoogleFonts.goudyBookletter1911(),
                ),
                SizedBox(height: 16.h),
                DropdownButtonFormField<String>(
                  value: selectedMethod,
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
                        (method) => DropdownMenuItem(
                          value: method,
                          child: Text(method),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedMethod = value);
                    }
                  },
                ),
                SizedBox(height: 16.h),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Notes (Optional)',
                    hintText: 'Add any additional information...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5.r),
                    ),
                    labelStyle: GoogleFonts.goudyBookletter1911(),
                  ),
                  style: GoogleFonts.goudyBookletter1911(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.goudyBookletter1911(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.onSurface(context),
                foregroundColor: AppColors.surface(context),
              ),
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Please enter a valid amount',
                        style: GoogleFonts.goudyBookletter1911(),
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                try {
                  final userId = AuthService().currentUserId;
                  if (userId == null) throw Exception('User not logged in');

                  await _withdrawalService.requestWithdrawal(
                    userId: userId,
                    amount: amount,
                    method: selectedMethod,
                    notes: notesController.text.trim(),
                  );

                  Navigator.pop(context, true);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        e.toString().replaceAll('Exception: ', ''),
                        style: GoogleFonts.goudyBookletter1911(),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text(
                'Submit',
                style: GoogleFonts.goudyBookletter1911(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await _loadBalance();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Withdrawal request submitted successfully!',
              style: GoogleFonts.goudyBookletter1911(),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = FutureBuilder<List<dynamic>>(
      future: _ordersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.onSurface(context)),
          );
        }
        if (snapshot.hasError) {
          return _buildErrorState();
        }
        if (!snapshot.hasData) {
          return _buildEmptyState();
        }

        final deliveredOrders = snapshot.data!;

        // Filter by date range if selected
        final filteredOrders = _filterOrdersByDate(deliveredOrders);

        return RefreshIndicator(
          onRefresh: () async {
            _loadOrders();
            await _loadBalance();
          },
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildWithdrawalSection(),
                _buildDateFilterSection(),
                _buildWithdrawalHistorySection(),
                _buildEarningsBreakdownTable(filteredOrders),
              ],
            ),
          ),
        );
      },
    );

    if (widget.hideScaffold) {
      return SafeArea(child: content);
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.surface(context),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Earnings',
          style: GoogleFonts.goudyBookletter1911(
            color: AppColors.onSurface(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: content,
    );
  }

  Widget _buildWithdrawalSection() {
    return Container(
      margin: EdgeInsets.all(16.w),
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available Balance',
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 14.sp,
                    color: AppColors.textMuted(context),
                  ),
                ),
                SizedBox(height: 8.h),
                _isLoadingBalance
                    ? SizedBox(
                        height: 32.h,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        '₱${_balanceInfo?.availableBalance.toStringAsFixed(2) ?? '0.00'}',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 28.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                SizedBox(height: 4.h),
                Text(
                  'Minimum withdrawal: ₱100.00',
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 11.sp,
                    color: AppColors.textFaint(context),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16.w),
          Column(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.onSurface(context),
                  foregroundColor: AppColors.surface(context),
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 12.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5.r),
                  ),
                ),
                onPressed: (_balanceInfo?.hasPending ?? false)
                    ? null
                    : _showWithdrawalDialog,
                icon: Icon(Icons.account_balance_wallet, size: 18.r),
                label: Text(
                  'Request\nWithdrawal',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WithdrawalHistoryScreen(),
                    ),
                  );
                },
                child: Text(
                  'View History',
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 11.sp,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterSection() {
    return Container(
      padding: EdgeInsets.all(16.w),
      color: AppColors.surface(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter by Date:',
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textBody(context),
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectDate(context, true),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 14.h,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border(context)),
                      borderRadius: BorderRadius.circular(5.r),
                      color: AppColors.surface(context),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16.r,
                          color: AppColors.textMuted(context),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            _startDate != null
                                ? _formatDateShort(_startDate!)
                                : 'Start Date',
                            style: GoogleFonts.goudyBookletter1911(
                              fontSize: 13.sp,
                              color: _startDate != null
                                  ? AppColors.onSurface(context)
                                  : AppColors.textFaint(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                child: Text(
                  'to',
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 13.sp,
                    color: AppColors.textMuted(context),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectDate(context, false),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 14.h,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border(context)),
                      borderRadius: BorderRadius.circular(5.r),
                      color: AppColors.surface(context),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16.r,
                          color: AppColors.textMuted(context),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            _endDate != null
                                ? _formatDateShort(_endDate!)
                                : 'End Date',
                            style: GoogleFonts.goudyBookletter1911(
                              fontSize: 13.sp,
                              color: _endDate != null
                                  ? AppColors.onSurface(context)
                                  : AppColors.textFaint(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              IconButton(
                onPressed: () {
                  setState(() {
                    _startDate = null;
                    _endDate = null;
                  });
                  _loadOrders();
                },
                icon: const Icon(Icons.refresh),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.onSurface(context),
                  foregroundColor: AppColors.surface(context),
                  padding: EdgeInsets.all(12.w),
                ),
                tooltip: 'Refresh',
              ),
            ],
          ),
          if (_startDate != null || _endDate != null) ...[
            SizedBox(height: 8.h),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _startDate = null;
                  _endDate = null;
                });
                _loadOrders();
              },
              icon: Icon(Icons.clear, size: 16.r),
              label: Text(
                'Clear Filter',
                style: GoogleFonts.goudyBookletter1911(fontSize: 12.sp),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.onSurface(context),
              onPrimary: AppColors.surface(context),
              onSurface: AppColors.onSurface(context),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // If end date is before start date, clear it
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
          // If start date is after end date, clear it
          if (_startDate != null && _startDate!.isAfter(_endDate!)) {
            _startDate = null;
          }
        }
      });

      // Reload orders if both dates are selected
      if (_startDate != null && _endDate != null) {
        _loadOrders();
      }
    }
  }

  String _formatDateShort(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  List<dynamic> _filterOrdersByDate(List<dynamic> orders) {
    if (_startDate == null || _endDate == null) {
      return orders;
    }

    return orders.where((order) {
      final deliveredAt = order['delivered_at'];
      if (deliveredAt == null) return false;

      try {
        final orderDate = DateTime.parse(deliveredAt.toString());
        final startOfDay = DateTime(
          _startDate!.year,
          _startDate!.month,
          _startDate!.day,
        );
        final endOfDay = DateTime(
          _endDate!.year,
          _endDate!.month,
          _endDate!.day,
          23,
          59,
          59,
        );

        return orderDate.isAfter(
              startOfDay.subtract(const Duration(seconds: 1)),
            ) &&
            orderDate.isBefore(endOfDay.add(const Duration(seconds: 1)));
      } catch (e) {
        return false;
      }
    }).toList();
  }

  Widget _buildWithdrawalHistorySection() {
    return Container(
      margin: EdgeInsets.all(16.w),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Withdrawal History',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WithdrawalHistoryScreen(),
                    ),
                  );
                },
                child: Text(
                  'View All',
                  style: GoogleFonts.goudyBookletter1911(fontSize: 13.sp),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          FutureBuilder<List<WithdrawalModel>>(
            future: _withdrawalService.getWithdrawalHistory(
              AuthService().currentUserId ?? '',
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.w),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.w),
                    child: Column(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 48.r,
                          color: AppColors.border(context),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'No withdrawal history',
                          style: GoogleFonts.goudyBookletter1911(
                            fontSize: 13.sp,
                            color: AppColors.textMuted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final withdrawals = snapshot.data!.take(3).toList();
              return Column(
                children: withdrawals
                    .map((w) => _buildWithdrawalHistoryItem(w))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawalHistoryItem(WithdrawalModel withdrawal) {
    final statusColor = withdrawal.status == 'completed'
        ? Colors.green
        : Colors.orange;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBackground(context),
        borderRadius: BorderRadius.circular(5.r),
        border: Border.all(color: AppColors.surfaceVariant2(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(withdrawal.requestedAt),
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 12.sp,
                    color: AppColors.textMuted(context),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '₱${withdrawal.amount.toStringAsFixed(2)}',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(5.r),
              border: Border.all(color: statusColor),
            ),
            child: Text(
              withdrawal.status.toUpperCase(),
              style: GoogleFonts.goudyBookletter1911(
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsBreakdownTable(List<dynamic> orders) {
    // Calculate total earnings
    double totalEarnings = 0;
    for (var order in orders) {
      final earnings = order['rider_earnings'] ?? order['delivery_fee'] ?? 0;
      totalEarnings += (earnings is int ? earnings.toDouble() : earnings);
    }

    return Container(
      margin: EdgeInsets.all(16.w),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Delivery History',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (orders.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(5.r),
                  ),
                  child: Text(
                    'Total: ₱${totalEarnings.toStringAsFixed(2)}',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[700],
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 16.h),
          if (orders.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(40.w),
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 64.r,
                      color: AppColors.border(context),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'No delivery history',
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 14.sp,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Complete deliveries to start earning',
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 12.sp,
                        color: AppColors.textFaint(context),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...orders.map((order) => _buildEarningsBreakdownItem(order)),
        ],
      ),
    );
  }

  Widget _buildEarningsBreakdownItem(dynamic order) {
    final orderData = order['orders'] ?? {};
    final buyer = orderData['buyers'] ?? {};
    final seller = orderData['sellers'] ?? {};
    final orderNumber = orderData['order_number'] ?? order['order_id'];
    final totalAmount = (orderData['total_amount'] ?? 0).toDouble();
    final deliveryFee = (order['rider_earnings'] ?? order['delivery_fee'] ?? 0)
        .toDouble();
    final deliveredAt = order['delivered_at'];

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBackground(context),
        borderRadius: BorderRadius.circular(5.r),
        border: Border.all(color: AppColors.surfaceVariant2(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #$orderNumber',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      deliveredAt != null
                          ? _formatDate(DateTime.parse(deliveredAt))
                          : 'N/A',
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 11.sp,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 12.w,
                  vertical: 6.h,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5.r),
                ),
                child: Text(
                  '+₱${deliveryFee.toStringAsFixed(2)}',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _buildInfoRow2('Shop', seller['shop_name'] ?? 'N/A'),
          SizedBox(height: 6.h),
          _buildInfoRow2(
            'Customer',
            '${buyer['first_name'] ?? ''} ${buyer['last_name'] ?? ''}'.trim(),
          ),
          SizedBox(height: 6.h),
          _buildInfoRow2(
            'Delivery Address',
            order['delivery_address'] ?? 'N/A',
          ),
          SizedBox(height: 6.h),
          _buildInfoRow2('Order Amount', '₱${totalAmount.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Widget _buildInfoRow2(String label, String value) {
    // Use Playfair Display for monetary values
    final isMonetary = value.contains('₱');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120.w,
          child: Text(
            '$label:',
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 12.sp,
              color: AppColors.textMuted(context),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: isMonetary
                ? GoogleFonts.playfairDisplay(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )
                : GoogleFonts.goudyBookletter1911(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
          ),
        ),
      ],
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(date.toString());
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 80.r,
            color: AppColors.textFaint(context),
          ),
          SizedBox(height: 16.h),
          Text(
            'No earnings yet',
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 18.sp,
              color: AppColors.textMuted(context),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Complete deliveries to start earning',
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 14.sp,
              color: AppColors.textFaint(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80.r, color: AppColors.textFaint(context)),
          SizedBox(height: 16.h),
          Text(
            'Connection Error',
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 18.sp,
              color: AppColors.textMuted(context),
            ),
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.onSurface(context),
              foregroundColor: AppColors.surface(context),
              padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h),
            ),
            onPressed: _loadOrders,
            child: Text(
              'Retry',
              style: GoogleFonts.goudyBookletter1911(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
