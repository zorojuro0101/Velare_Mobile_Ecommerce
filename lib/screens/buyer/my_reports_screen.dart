import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/report_model.dart';
import '../../services/report_service.dart';
import '../../utils/image_helper.dart';
import '../../utils/snackbar_helper.dart';

import '../../utils/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  final ReportService _reportService = ReportService();
  late Future<List<Report>> _reportsFuture;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  void _loadReports() {
    setState(() {
      _reportsFuture = _reportService.getMyReports();
    });
  }

  Future<void> _deleteReport(Report report) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.r)),
        title: Text(
          'Delete Report',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete this report? This action cannot be undone.',
          style: GoogleFonts.goudyBookletter1911(fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.r)),
            ),
            child: Text('Cancel', style: GoogleFonts.goudyBookletter1911(color: AppColors.onSurface(context))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: AppColors.surface(context),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.r)),
            ),
            child: Text('Delete', style: GoogleFonts.goudyBookletter1911()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _reportService.deleteReport(report.reportId);
        if (mounted) {
          SnackBarHelper.showSuccess(context, 'Report deleted successfully');
          _loadReports();
        }
      } catch (e) {
        if (mounted) {
          SnackBarHelper.showError(context, 'Error deleting report: $e');
        }
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFFFD700); // Gold
      case 'under_review':
        return const Color(0xFF007BFF); // Blue
      case 'resolved':
        return const Color(0xFF28A745); // Green
      case 'dismissed':
        return const Color(0xFF6C757D); // Gray
      default:
        return Colors.grey;
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.goudyBookletter1911(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted(context),
          ),
        ),
        if (value.isNotEmpty) ...[
          SizedBox(height: 4.h),
          Text(
            value,
            style: GoogleFonts.goudyBookletter1911(fontSize: 14.sp),
          ),
        ],
      ],
    );
  }

  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  ImageHelper.getImageUrl(imageUrl),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      padding: EdgeInsets.all(20.w),
                      color: AppColors.surface(context),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error, size: 48.r, color: Colors.red),
                          SizedBox(height: 8.h),
                          Text('Failed to load image'),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: Icon(Icons.close, color: AppColors.surface(context), size: 30.r),
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground(context),
      appBar: AppBar(
        title: Text('My Reports', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface(context),
        foregroundColor: AppColors.onSurface(context),
        elevation: 0,
      ),
      body: FutureBuilder<List<Report>>(
        future: _reportsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}', style: GoogleFonts.goudyBookletter1911()),
            );
          }

          final reports = snapshot.data ?? [];

          if (reports.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 80.r, color: AppColors.textFaint(context)),
                  SizedBox(height: 16.h),
                  Text(
                    'No reports yet',
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 18.sp,
                      color: AppColors.textMuted(context),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Submit a report if you have issues',
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 14.sp,
                      color: AppColors.textFaint(context),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: const Color(0xFFD4AF37),
            onRefresh: () async {
              _loadReports();
            },
            child: ListView.builder(
              padding: EdgeInsets.all(16.w),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index];
                return _buildReportCard(report);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildReportCard(Report report) {
    return Dismissible(
      key: Key('report_${report.reportId}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        await _deleteReport(report);
        return false;
      },
      background: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(8.r),
        ),
        alignment: Alignment.centerRight,
        child: Icon(
          Icons.delete,
          color: AppColors.surface(context),
          size: 28.r,
        ),
      ),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(8.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: report.evidenceImage != null 
                  ? () => _showImageDialog(report.evidenceImage!)
                  : null,
              child: Container(
                width: 80.w,
                height: 80.h,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant2(context),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: AppColors.border(context), width: 1),
                ),
                child: report.evidenceImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(7.r),
                        child: Image.network(
                          ImageHelper.getImageUrl(report.evidenceImage!),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.image_not_supported, color: AppColors.textFaint(context), size: 24.r),
                                  SizedBox(height: 4.h),
                                  Text(
                                    'Error',
                                    style: GoogleFonts.goudyBookletter1911(
                                      fontSize: 10.sp,
                                      color: AppColors.textFaint(context),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_outlined, color: AppColors.textFaint(context), size: 28.r),
                            SizedBox(height: 4.h),
                            Text(
                              'No image\nuploaded',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.goudyBookletter1911(
                                fontSize: 9.sp,
                                color: AppColors.textFaint(context),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              'Report ID: ',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textBody(context),
                              ),
                            ),
                            Text(
                              '#${report.reportId}',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFD4AF37),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: _getStatusColor(report.status).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          report.statusDisplay,
                          style: GoogleFonts.goudyBookletter1911(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(report.status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          report.reportedUserName ?? 'Unknown',
                          style: GoogleFonts.goudyBookletter1911(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '(${report.reportedUserType == 'seller' ? 'Seller' : 'Rider'})',
                        style: GoogleFonts.goudyBookletter1911(
                          fontSize: 12.sp,
                          color: AppColors.textMuted(context),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant2(context),
                      borderRadius: BorderRadius.circular(3.r),
                    ),
                    child: Text(
                      report.categoryDisplay,
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    report.reportReason,
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 12.sp,
                      color: AppColors.textBody(context),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (report.adminNotes != null && report.adminNotes!.isNotEmpty) ...[
                    SizedBox(height: 6.h),
                    _buildDetailRow('Admin Notes:', report.adminNotes!),
                  ],
                  SizedBox(height: 6.h),
                  Text(
                    _formatDate(report.createdAt),
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 10.sp,
                      color: AppColors.textFaint(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
