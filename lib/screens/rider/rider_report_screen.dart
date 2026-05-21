import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/report_model.dart';
import '../../services/rider_report_service.dart';
import '../../services/auth_service.dart';
import '../../utils/image_helper.dart';
import '../../utils/snackbar_helper.dart';

import '../../utils/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
class RiderReportScreen extends StatefulWidget {
  const RiderReportScreen({super.key});

  @override
  State<RiderReportScreen> createState() => _RiderReportScreenState();
}

class _RiderReportScreenState extends State<RiderReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final RiderReportService _reportService = RiderReportService();
  final TextEditingController _reasonController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  // Form state
  String? _selectedUserType;
  DeliveryOption? _selectedDelivery;
  ReportCategory? _selectedCategory;
  File? _evidenceImage;

  // Data
  List<DeliveryOption> _deliveries = [];
  List<Report> _reports = [];
  int? _riderId;

  // Loading states
  bool _isLoadingDeliveries = false;
  bool _isLoadingReports = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final userId = AuthService().currentUserId;
    if (userId == null) {
      print('❌ User ID is null');
      return;
    }

    // Get rider_id from user_id
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('riders')
          .select('rider_id')
          .eq('user_id', userId)
          .single();

      _riderId = response['rider_id'];
      await _loadDeliveries();
      await _loadReports();
    } catch (e) {
      print('❌ Error loading rider data: $e');
    }
  }

  Future<void> _loadDeliveries() async {
    if (_riderId == null) return;

    setState(() => _isLoadingDeliveries = true);

    try {
      final deliveries = await _reportService.getRiderDeliveries(_riderId!);
      setState(() {
        _deliveries = deliveries;
        _isLoadingDeliveries = false;
      });
    } catch (e) {
      print('❌ Error loading deliveries: $e');
      setState(() => _isLoadingDeliveries = false);
    }
  }

  Future<void> _loadReports() async {
    final userId = AuthService().currentUserId;
    if (userId == null) return;

    setState(() => _isLoadingReports = true);

    try {
      final reports = await _reportService.getRiderReports(userId);
      setState(() {
        _reports = reports;
        _isLoadingReports = false;
      });
    } catch (e) {
      print('❌ Error loading reports: $e');
      setState(() => _isLoadingReports = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _evidenceImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      print('❌ Error picking image: $e');
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to pick image');
      }
    }
  }

  Future<void> _submitReport() async {
    // Validate form
    if (_selectedUserType == null) {
      SnackBarHelper.showError(context, 'Please select user type');
      return;
    }

    if (_selectedDelivery == null) {
      SnackBarHelper.showError(context, 'Please select a delivery');
      return;
    }

    if (_selectedCategory == null) {
      SnackBarHelper.showError(context, 'Please select report category');
      return;
    }

    if (_reasonController.text.trim().isEmpty) {
      SnackBarHelper.showError(context, 'Please enter reason');
      return;
    }

    if (_reasonController.text.trim().length < 10) {
      SnackBarHelper.showError(
        context,
        'Reason must be at least 10 characters',
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    setState(() => _isSubmitting = true);

    try {
      final userId = AuthService().currentUserId;
      if (userId == null) {
        SnackBarHelper.showError(context, 'User not authenticated');
        return;
      }

      // Determine reported_id based on user type
      final reportedId = _selectedUserType == 'buyer'
          ? _selectedDelivery!.buyerId
          : _selectedDelivery!.sellerId;

      final success = await _reportService.submitReport(
        reporterId: userId,
        reportedUserType: _selectedUserType!,
        reportedId: reportedId,
        category: _selectedCategory!.value,
        reason: _reasonController.text.trim(),
        orderId: _selectedDelivery?.orderId,
        deliveryId: _selectedDelivery?.deliveryId,
        evidenceFile: _evidenceImage,
      );

      if (success) {
        if (mounted) {
          SnackBarHelper.showSuccess(context, 'Report submitted successfully!');

          // Reset form
          setState(() {
            _selectedUserType = null;
            _selectedDelivery = null;
            _selectedCategory = null;
            _reasonController.clear();
            _evidenceImage = null;
          });

          // Switch to My Reports tab
          _tabController.animateTo(1);

          // Reload reports
          await _loadReports();
        }
      } else {
        SnackBarHelper.showError(context, 'Failed to submit report');
      }
    } catch (e) {
      print('❌ Error submitting report: $e');
      SnackBarHelper.showError(
        context,
        'An error occurred while submitting report',
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<bool> _showConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Submit Report?',
              style: GoogleFonts.goudyBookletter1911(
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              'Are you sure you want to submit this report?',
              style: GoogleFonts.goudyBookletter1911(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: GoogleFonts.goudyBookletter1911()),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text(
                  'Submit',
                  style: GoogleFonts.goudyBookletter1911(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface(context),
      appBar: AppBar(
        backgroundColor: AppColors.surface(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.onSurface(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Report User',
          style: GoogleFonts.goudyBookletter1911(
            color: AppColors.onSurface(context),
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.onSurface(context),
          unselectedLabelColor: AppColors.textMuted(context),
          indicatorColor: AppColors.onSurface(context),
          labelStyle: GoogleFonts.goudyBookletter1911(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.goudyBookletter1911(
            fontSize: 16.sp,
            fontWeight: FontWeight.normal,
          ),
          tabs: const [
            Tab(text: 'Submit Report'),
            Tab(text: 'My Reports'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildSubmitReportTab(), _buildMyReportsTab()],
      ),
    );
  }

  Widget _buildSubmitReportTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Type Selection
          _buildSectionTitle('Report User Type'),
          SizedBox(height: 8.h),
          DropdownButtonFormField<String>(
            value: _selectedUserType,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5.r),
              ),
              hintText: 'Select user type',
              hintStyle: GoogleFonts.goudyBookletter1911(
                color: AppColors.textFaint(context),
              ),
            ),
            style: GoogleFonts.goudyBookletter1911(color: AppColors.onSurface(context)),
            items: [
              DropdownMenuItem(
                value: 'buyer',
                child: Text('Buyer', style: GoogleFonts.goudyBookletter1911()),
              ),
              DropdownMenuItem(
                value: 'seller',
                child: Text('Seller', style: GoogleFonts.goudyBookletter1911()),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _selectedUserType = value;
                _selectedDelivery = null; // Reset delivery selection
              });
            },
          ),
          SizedBox(height: 24.h),

          // Delivery Selection (shown after user type selected)
          if (_selectedUserType != null) ...[
            _buildSectionTitle('Related Delivery (Optional)'),
            SizedBox(height: 8.h),
            _isLoadingDeliveries
                ? const Center(child: CircularProgressIndicator())
                : DropdownButtonFormField<DeliveryOption>(
                    value: _selectedDelivery,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(5.r),
                      ),
                      hintText: 'No specific delivery',
                      hintStyle: GoogleFonts.goudyBookletter1911(
                        color: AppColors.textFaint(context),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 12.h,
                      ),
                    ),
                    isExpanded: true,
                    style: GoogleFonts.goudyBookletter1911(
                      color: AppColors.onSurface(context),
                      fontSize: 13.sp,
                    ),
                    items: _deliveries.map((delivery) {
                      return DropdownMenuItem(
                        value: delivery,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Delivery #${delivery.deliveryId} - ${delivery.orderNumber}',
                              style: GoogleFonts.goudyBookletter1911(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'Buyer: ${delivery.buyerName}',
                              style: GoogleFonts.goudyBookletter1911(
                                fontSize: 11.sp,
                                color: AppColors.textMuted(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Seller: ${delivery.sellerName}',
                              style: GoogleFonts.goudyBookletter1911(
                                fontSize: 11.sp,
                                color: AppColors.textMuted(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    selectedItemBuilder: (context) {
                      return _deliveries.map((delivery) {
                        return Text(
                          'Delivery #${delivery.deliveryId} - ${delivery.orderNumber}',
                          style: GoogleFonts.goudyBookletter1911(
                            fontSize: 13.sp,
                            color: AppColors.onSurface(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      }).toList();
                    },
                    onChanged: (value) {
                      setState(() => _selectedDelivery = value);
                    },
                  ),
            SizedBox(height: 4.h),
            Text(
              'Piliin kung may kaugnayan sa specific delivery',
              style: GoogleFonts.goudyBookletter1911(
                fontSize: 12.sp,
                color: AppColors.textMuted(context),
              ),
            ),
            SizedBox(height: 24.h),
          ],

          // Category Selection
          _buildSectionTitle('Report Category'),
          SizedBox(height: 8.h),
          DropdownButtonFormField<ReportCategory>(
            value: _selectedCategory,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5.r),
              ),
              hintText: 'Select category',
              hintStyle: GoogleFonts.goudyBookletter1911(
                color: AppColors.textFaint(context),
              ),
            ),
            style: GoogleFonts.goudyBookletter1911(color: AppColors.onSurface(context)),
            items: ReportCategory.values.map((category) {
              return DropdownMenuItem(
                value: category,
                child: Text(
                  category.label,
                  style: GoogleFonts.goudyBookletter1911(),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedCategory = value);
            },
          ),
          SizedBox(height: 24.h),

          // Reason Text Area
          _buildSectionTitle('Report Reason'),
          SizedBox(height: 8.h),
          TextField(
            controller: _reasonController,
            maxLines: 5,
            style: GoogleFonts.goudyBookletter1911(color: AppColors.onSurface(context)),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5.r),
              ),
              hintText: 'Describe the issue in detail...',
              hintStyle: GoogleFonts.goudyBookletter1911(
                color: AppColors.textFaint(context),
              ),
            ),
          ),
          SizedBox(height: 24.h),

          // Evidence Upload
          _buildSectionTitle('Evidence (optional):'),
          SizedBox(height: 8.h),
          if (_evidenceImage != null) ...[
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(5.r),
                  child: Image.file(
                    _evidenceImage!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: Icon(Icons.close, color: AppColors.surface(context)),
                    onPressed: () {
                      setState(() => _evidenceImage = null);
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.onSurfaceMedium(context),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
          ],
          ElevatedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.image),
            label: Text(
              _evidenceImage == null ? 'Upload Evidence' : 'Change Evidence',
              style: GoogleFonts.goudyBookletter1911(),
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              backgroundColor: AppColors.surfaceVariant2(context),
              foregroundColor: AppColors.onSurface(context),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Upload screenshot or image as evidence (JPG or PNG only)',
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 12.sp,
              color: AppColors.textMuted(context),
            ),
          ),
          SizedBox(height: 24.h),

          // Warning
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              border: Border.all(color: Colors.orange),
              borderRadius: BorderRadius.circular(5.r),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 12.w),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 13.sp,
                        color: AppColors.onSurface(context),
                      ),
                      children: const [
                        TextSpan(
                          text: 'Notice: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text:
                              'False reporting may result in account suspension.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),

          // Submit Button
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submitReport,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5.r),
              ),
            ),
            child: _isSubmitting
                ? SizedBox(
                    height: 24.h,
                    width: 24.w,
                    child: CircularProgressIndicator(
                      color: AppColors.surface(context),
                      strokeWidth: 2,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.send),
                      SizedBox(width: 8.w),
                      Text(
                        'Submit Report',
                        style: GoogleFonts.goudyBookletter1911(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyReportsTab() {
    if (_isLoadingReports) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64.r, color: AppColors.textFaint(context)),
            SizedBox(height: 16.h),
            Text(
              'No reports submitted yet',
              style: GoogleFonts.goudyBookletter1911(
                fontSize: 16.sp,
                color: AppColors.textMuted(context),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReports,
      child: ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: _reports.length,
        itemBuilder: (context, index) {
          return _buildReportCard(_reports[index]);
        },
      ),
    );
  }

  Widget _buildReportCard(Report report) {
    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.r)),
      child: InkWell(
        onTap: () => _showReportDetails(report),
        borderRadius: BorderRadius.circular(5.r),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Report #${report.reportId}',
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  _buildStatusBadge(report.statusEnum ?? ReportStatus.pending),
                ],
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  _buildUserTypeBadge(report.reportedUserType),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      report.reportedUserName ?? 'Unknown User',
                      style: GoogleFonts.goudyBookletter1911(fontSize: 14.sp),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                report.categoryEnum?.label ?? report.reportCategory,
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 13.sp,
                  color: AppColors.textBody(context),
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                _formatDate(report.createdAt),
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 12.sp,
                  color: AppColors.textMuted(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ReportStatus status) {
    Color color;
    switch (status) {
      case ReportStatus.pending:
        color = Colors.orange;
        break;
      case ReportStatus.underReview:
        color = Colors.blue;
        break;
      case ReportStatus.resolved:
        color = Colors.green;
        break;
      case ReportStatus.dismissed:
        color = Colors.grey;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5.r),
      ),
      child: Text(
        status.label,
        style: GoogleFonts.goudyBookletter1911(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildUserTypeBadge(String userType) {
    Color color;
    switch (userType) {
      case 'buyer':
        color = Colors.blue;
        break;
      case 'seller':
        color = Colors.orange;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5.r),
      ),
      child: Text(
        userType.toUpperCase(),
        style: GoogleFonts.goudyBookletter1911(
          fontSize: 10.sp,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  void _showReportDetails(Report report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Report Details',
          style: GoogleFonts.goudyBookletter1911(fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Report ID', '#${report.reportId}'),
              _buildDetailRow(
                'Status',
                report.statusEnum?.label ?? report.status,
              ),
              _buildDetailRow('Reported User Type', report.reportedUserType),
              _buildDetailRow('Reported User', report.reportedUserName),
              _buildDetailRow(
                'Category',
                report.categoryEnum?.label ?? report.reportCategory,
              ),
              SizedBox(height: 12.h),
              Text(
                'Reason:',
                style: GoogleFonts.goudyBookletter1911(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant(context),
                  borderRadius: BorderRadius.circular(5.r),
                ),
                child: Text(
                  report.reportReason,
                  style: GoogleFonts.goudyBookletter1911(fontSize: 14.sp),
                ),
              ),
              if (report.evidenceImage != null &&
                  report.evidenceImage!.isNotEmpty) ...[
                SizedBox(height: 12.h),
                Text(
                  'Evidence:',
                  style: GoogleFonts.goudyBookletter1911(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5.r),
                  child: Image.network(
                    _getImageUrl(report.evidenceImage!),
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 200.h,
                        color: AppColors.surfaceVariant2(context),
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      final imageUrl = _getImageUrl(report.evidenceImage!);
                      print('❌ Error loading evidence image: $error');
                      print('Original path: ${report.evidenceImage}');
                      print('Converted URL: $imageUrl');
                      return Container(
                        height: 100.h,
                        padding: EdgeInsets.all(16.w),
                        color: AppColors.surfaceVariant2(context),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                              size: 32.r,
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              'Failed to load image',
                              style: GoogleFonts.goudyBookletter1911(
                                fontSize: 12.sp,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (report.adminNotes != null &&
                  report.adminNotes!.isNotEmpty) ...[
                SizedBox(height: 12.h),
                Text(
                  'Admin Notes:',
                  style: GoogleFonts.goudyBookletter1911(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(5.r),
                  ),
                  child: Text(
                    report.adminNotes!,
                    style: GoogleFonts.goudyBookletter1911(fontSize: 14.sp),
                  ),
                ),
              ],
              SizedBox(height: 12.h),
              _buildDetailRow('Submitted', _formatDate(report.createdAt)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.goudyBookletter1911()),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120.w,
            child: Text(
              '$label:',
              style: GoogleFonts.goudyBookletter1911(
                fontWeight: FontWeight.w600,
                fontSize: 13.sp,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: GoogleFonts.goudyBookletter1911(fontSize: 13.sp),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.goudyBookletter1911(
        fontSize: 16.sp,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface(context),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getImageUrl(String imagePath) {
    // Use ImageHelper to get Supabase Storage URL
    // This handles both full URLs and local paths
    final url = ImageHelper.getImageUrl(imagePath);
    print('🖼️ Evidence image URL: $imagePath -> $url');
    return url;
  }
}
