import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../utils/snackbar_helper.dart';
import 'voucher_products_screen.dart';

import '../../utils/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
class VouchersScreen extends StatefulWidget {
  const VouchersScreen({super.key});

  @override
  State<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends State<VouchersScreen> {
  final _authService = AuthService();
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _vouchers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVouchers();
  }

  Future<void> _loadVouchers() async {
    setState(() => _isLoading = true);
    
    try {
      final buyerId = _authService.currentBuyerId;
      if (buyerId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final today = DateTime.now().toIso8601String().split('T')[0]; // Get date only

      // Get buyer vouchers with voucher details
      // Only show vouchers that still have remaining uses and not expired
      final response = await _supabase
          .from('buyer_vouchers')
          .select('''
            buyer_voucher_id,
            times_remaining,
            used_at,
            claimed_at,
            vouchers!inner (
              voucher_id,
              voucher_code,
              voucher_name,
              voucher_type,
              discount_percent,
              start_date,
              end_date
            )
          ''')
          .eq('buyer_id', buyerId)
          .gt('times_remaining', 0)
          .gte('vouchers.end_date', today);

      print('Vouchers response: $response');

      setState(() {
        _vouchers = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading vouchers: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        SnackBarHelper.showError(context, 'Error loading vouchers: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface(context),
      appBar: AppBar(
        title: Text('My Vouchers', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface(context),
        foregroundColor: AppColors.onSurface(context),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : _vouchers.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: const Color(0xFFD4AF37),
                  onRefresh: _loadVouchers,
                  child: ListView.builder(
                    padding: EdgeInsets.all(16.w),
                    itemCount: _vouchers.length,
                    itemBuilder: (context, index) {
                      return _buildVoucherCard(_vouchers[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.confirmation_number_outlined, size: 80.r, color: AppColors.textFaint(context)),
          SizedBox(height: 16.h),
          Text(
            'No vouchers available',
            style: GoogleFonts.goudyBookletter1911(fontSize: 18.sp, color: AppColors.textMuted(context)),
          ),
          SizedBox(height: 8.h),
          Text(
            'Check back later for new vouchers',
            style: GoogleFonts.goudyBookletter1911(fontSize: 14.sp, color: AppColors.textFaint(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherCard(Map<String, dynamic> buyerVoucher) {
    final voucher = buyerVoucher['vouchers'] as Map<String, dynamic>?;
    if (voucher == null) return const SizedBox.shrink();

    final voucherId = voucher['voucher_id'];
    final voucherType = voucher['voucher_type']?.toString() ?? '';
    final voucherName = voucher['voucher_name']?.toString() ?? 'Voucher';
    final discountPercent = voucher['discount_percent'] ?? 0;
    final timesRemaining = buyerVoucher['times_remaining'] ?? 1;
    final endDate = voucher['end_date'] != null 
        ? DateTime.parse(voucher['end_date'].toString())
        : null;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VoucherProductsScreen(voucherId: voucherId),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: const Color(0xFFD4AF37),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50.w,
              height: 50.h,
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                voucherType == 'free_shipping' ? Icons.local_shipping : Icons.percent,
                size: 24,
                color: const Color(0xFFD4AF37),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          voucherName,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurface(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (timesRemaining > 1)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Text(
                            '${timesRemaining}x',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.surface(context),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '$discountPercent% OFF',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFD4AF37),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    voucherType == 'free_shipping'
                        ? 'Get free shipping on your order'
                        : 'Get $discountPercent% off on applicable products',
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 13.sp,
                      color: AppColors.textBody(context),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (endDate != null) ...[
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14.r, color: AppColors.textFaint(context)),
                        SizedBox(width: 4.w),
                        Text(
                          'Valid until ${_formatDate(endDate)}',
                          style: GoogleFonts.goudyBookletter1911(
                            fontSize: 12.sp,
                            color: AppColors.textFaint(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Icon(
              Icons.arrow_forward_ios,
              size: 16.r,
              color: AppColors.textFaint(context),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
