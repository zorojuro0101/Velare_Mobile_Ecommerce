import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../services/rider_service.dart';
import 'delivery_detail_screen.dart';

import '../../utils/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
class DeliveryHistoryScreen extends StatefulWidget {
  const DeliveryHistoryScreen({super.key});

  @override
  State<DeliveryHistoryScreen> createState() => _DeliveryHistoryScreenState();
}

class _DeliveryHistoryScreenState extends State<DeliveryHistoryScreen> {
  final RiderService _riderService = RiderService();
  late Future<List<dynamic>> _historyFuture;
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    final riderId = AuthService().currentUserId;
    if (riderId != null) {
      setState(() {
        _historyFuture = _riderService.getMyOrders(riderId);
      });
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
          'Delivery History',
          style: GoogleFonts.goudyBookletter1911(
            color: AppColors.onSurface(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _historyFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: AppColors.onSurface(context)));
                }
                if (snapshot.hasError) {
                  return _buildErrorState();
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState();
                }

                final filteredOrders = _filterOrders(snapshot.data!);

                if (filteredOrders.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: EdgeInsets.all(16.w),
                  itemCount: filteredOrders.length,
                  itemBuilder: (context, index) {
                    return _buildHistoryCard(filteredOrders[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: EdgeInsets.all(16.w),
      color: AppColors.surface(context),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('All', 'all'),
            _buildFilterChip('Delivered', 'delivered'),
            _buildFilterChip('Cancelled', 'cancelled'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return Padding(
      padding: EdgeInsets.only(right: 8.w),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _filterStatus = value;
          });
        },
        labelStyle: GoogleFonts.goudyBookletter1911(
          color: isSelected ? AppColors.surface(context) : AppColors.onSurface(context),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
        backgroundColor: AppColors.surface(context),
        selectedColor: AppColors.onSurface(context),
        checkmarkColor: AppColors.surface(context),
        side: BorderSide(color: AppColors.border(context)),
      ),
    );
  }

  List<dynamic> _filterOrders(List<dynamic> orders) {
    if (_filterStatus == 'all') {
      return orders.where((order) => 
        order['status'] == 'delivered' || order['status'] == 'cancelled'
      ).toList();
    }
    return orders.where((order) => order['status'] == _filterStatus).toList();
  }

  Widget _buildHistoryCard(dynamic order) {
    final status = order['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12.r),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DeliveryDetailScreen(order: order),
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order #${order['order_id'] ?? order['id']}',
                      style: GoogleFonts.goudyBookletter1911(
                        fontWeight: FontWeight.w600,
                        fontSize: 16.sp,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: GoogleFonts.goudyBookletter1911(
                          color: AppColors.surface(context),
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                _buildInfoRow(Icons.person_outline, order['recipient'] ?? 'N/A'),
                _buildInfoRow(Icons.location_on_outlined, order['address'] ?? 'N/A'),
                _buildInfoRow(Icons.calendar_today, _formatDate(order['created_at'])),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Amount',
                          style: GoogleFonts.goudyBookletter1911(
                            fontSize: 12.sp,
                            color: AppColors.textMuted(context),
                          ),
                        ),
                        Text(
                          '₱${order['total_amount'] ?? 0}',
                          style: GoogleFonts.goudyBookletter1911(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (status == 'delivered')
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 16.r),
                            SizedBox(width: 4.w),
                            Text(
                              'Completed',
                              style: GoogleFonts.goudyBookletter1911(
                                color: Colors.green,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          Icon(icon, size: 16.r, color: AppColors.textMuted(context)),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.goudyBookletter1911(fontSize: 13.sp, color: AppColors.textBody(context)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
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
          Icon(Icons.history, size: 80.r, color: AppColors.textFaint(context)),
          SizedBox(height: 16.h),
          Text(
            'No delivery history',
            style: GoogleFonts.goudyBookletter1911(fontSize: 18.sp, color: AppColors.textMuted(context)),
          ),
          SizedBox(height: 8.h),
          Text(
            'Your completed deliveries will appear here',
            style: GoogleFonts.goudyBookletter1911(fontSize: 14.sp, color: AppColors.textFaint(context)),
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
            style: GoogleFonts.goudyBookletter1911(fontSize: 18.sp, color: AppColors.textMuted(context)),
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.onSurface(context),
              foregroundColor: AppColors.surface(context),
              padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h),
            ),
            onPressed: _loadHistory,
            child: Text('Retry', style: GoogleFonts.goudyBookletter1911(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
