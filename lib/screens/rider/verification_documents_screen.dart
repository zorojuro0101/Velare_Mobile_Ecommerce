import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../utils/snackbar_helper.dart';

import '../../utils/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
class VerificationDocumentsScreen extends StatefulWidget {
  const VerificationDocumentsScreen({super.key});

  @override
  State<VerificationDocumentsScreen> createState() =>
      _VerificationDocumentsScreenState();
}

class _VerificationDocumentsScreenState
    extends State<VerificationDocumentsScreen> {
  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();

  Map<String, dynamic>? _riderData;
  bool _isLoading = true;
  bool _isUploading = false;

  File? _orcrImage;
  File? _licenseImage;

  @override
  void initState() {
    super.initState();
    _loadRiderData();
  }

  Future<void> _loadRiderData() async {
    setState(() => _isLoading = true);
    try {
      final userId = AuthService().currentUserId;
      if (userId == null) throw Exception('User not logged in');

      final response = await _supabase
          .from('riders')
          .select('rider_id, orcr_file_path, driver_license_file_path')
          .eq('user_id', userId)
          .single();

      if (mounted) {
        setState(() {
          _riderData = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading rider data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage(String documentType) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          if (documentType == 'orcr') {
            _orcrImage = File(image.path);
          } else {
            _licenseImage = File(image.path);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to pick image');
      }
    }
  }

  /// Uploads a single document image to Supabase Storage and returns the
  /// public URL. Mirrors the web client's path convention so files from
  /// mobile and web land in the same folders:
  ///   - Driver's License -> static/uploads/rider_dl/user_<userId>/driver_license_<ts>_<orig>
  ///   - OR/CR            -> static/uploads/rider_orcr/user_<userId>/orcr_<ts>_<orig>
  Future<String> _uploadDocumentImage({
    required File file,
    required int userId,
    required String docType, // 'orcr' or 'license'
  }) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('Selected $docType image is empty');
    }

    // Preserve original extension; default to jpg if missing.
    final originalName = file.path.split(RegExp(r'[\\/]+')).last;
    final dotIndex = originalName.lastIndexOf('.');
    final ext = dotIndex >= 0 && dotIndex < originalName.length - 1
        ? originalName.substring(dotIndex + 1).toLowerCase()
        : 'jpg';
    final baseName = dotIndex >= 0
        ? originalName.substring(0, dotIndex)
        : originalName;

    // Sanitize the base name to keep storage paths safe.
    final safeBase = baseName.replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_');

    final contentType = 'image/${ext == 'jpg' ? 'jpeg' : ext}';
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final folder = docType == 'orcr'
        ? 'static/uploads/rider_orcr/user_$userId'
        : 'static/uploads/rider_dl/user_$userId';
    final prefix = docType == 'orcr' ? 'orcr' : 'driver_license';
    final fileName = '${prefix}_${timestamp}_$safeBase.$ext';
    final filePath = '$folder/$fileName';

    await _supabase.storage
        .from('Images')
        .uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        )
        .timeout(const Duration(seconds: 30));

    return _supabase.storage.from('Images').getPublicUrl(filePath);
  }

  Future<void> _uploadDocuments() async {
    if (_orcrImage == null && _licenseImage == null) {
      SnackBarHelper.showError(
        context,
        'Please select at least one document to upload',
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final userIdStr = AuthService().currentUserId;
      if (userIdStr == null) throw Exception('User not logged in');
      final userId = int.parse(userIdStr);

      if (_riderData?['rider_id'] == null) {
        throw Exception('Rider ID not found');
      }

      final updateData = <String, dynamic>{};

      // Upload OR/CR
      if (_orcrImage != null) {
        final orcrUrl = await _uploadDocumentImage(
          file: _orcrImage!,
          userId: userId,
          docType: 'orcr',
        );
        updateData['orcr_file_path'] = orcrUrl;
      }

      // Upload Driver's License
      if (_licenseImage != null) {
        final licenseUrl = await _uploadDocumentImage(
          file: _licenseImage!,
          userId: userId,
          docType: 'license',
        );
        updateData['driver_license_file_path'] = licenseUrl;
      }

      // Update database
      if (updateData.isNotEmpty) {
        await _supabase
            .from('riders')
            .update(updateData)
            .eq('user_id', userId);
      }

      setState(() {
        _isUploading = false;
        _orcrImage = null;
        _licenseImage = null;
      });

      await _loadRiderData();

      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Documents uploaded successfully!');
      }
    } on StorageException catch (e) {
      print('VerificationDocs - Supabase storage error: ${e.message}');
      setState(() => _isUploading = false);
      if (mounted) {
        SnackBarHelper.showError(
          context,
          'Storage upload failed: ${e.message}',
        );
      }
    } catch (e) {
      print('VerificationDocs - upload error: $e');
      setState(() => _isUploading = false);
      if (mounted) {
        SnackBarHelper.showError(
          context,
          'Failed to upload documents: ${e.toString().replaceAll('Exception: ', '')}',
        );
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
          'Verification Documents',
          style: GoogleFonts.goudyBookletter1911(
            color: AppColors.onSurface(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.onSurface(context)))
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(),
                  SizedBox(height: 24.h),
                  _buildDocumentSection(
                    'OR/CR (Official Receipt / Certificate of Registration)',
                    'orcr',
                    _riderData?['orcr_file_path'],
                    _orcrImage,
                  ),
                  SizedBox(height: 24.h),
                  _buildDocumentSection(
                    'Driver\'s License',
                    'license',
                    _riderData?['driver_license_file_path'],
                    _licenseImage,
                  ),
                  SizedBox(height: 32.h),
                  if (_orcrImage != null || _licenseImage != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.onSurface(context),
                          foregroundColor: AppColors.surface(context),
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5.r),
                          ),
                        ),
                        onPressed: _isUploading ? null : _uploadDocuments,
                        child: _isUploading
                            ? SizedBox(
                                height: 20.h,
                                width: 20.w,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.surface(context),
                                ),
                              )
                            : Text(
                                'Upload Documents',
                                style: GoogleFonts.goudyBookletter1911(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(5.r),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue[700], size: 24.r),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              'Upload clear photos of your OR/CR and Driver\'s License for verification purposes.',
              style: GoogleFonts.goudyBookletter1911(
                fontSize: 13.sp,
                color: Colors.blue[900],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentSection(
    String title,
    String documentType,
    String? existingUrl,
    File? newImage,
  ) {
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
            title,
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16.h),
          GestureDetector(
            onTap: () => _pickImage(documentType),
            child: Container(
              height: 200.h,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant(context),
                borderRadius: BorderRadius.circular(5.r),
                border: Border.all(color: AppColors.border(context), width: 2),
              ),
              child: newImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(5.r),
                      child: Image.file(newImage, fit: BoxFit.cover),
                    )
                  : existingUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(5.r),
                      child: Image.network(
                        existingUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildPlaceholder();
                        },
                      ),
                    )
                  : _buildPlaceholder(),
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    side: BorderSide(color: AppColors.onSurface(context)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5.r),
                    ),
                  ),
                  onPressed: () => _pickImage(documentType),
                  icon: Icon(Icons.photo_library, size: 18.r),
                  label: Text(
                    newImage != null || existingUrl != null
                        ? 'Change Photo'
                        : 'Select Photo',
                    style: GoogleFonts.goudyBookletter1911(fontSize: 13.sp),
                  ),
                ),
              ),
              if (newImage != null) ...[
                SizedBox(width: 8.w),
                IconButton(
                  onPressed: () {
                    setState(() {
                      if (documentType == 'orcr') {
                        _orcrImage = null;
                      } else {
                        _licenseImage = null;
                      }
                    });
                  },
                  icon: const Icon(Icons.close, color: Colors.red),
                  style: IconButton.styleFrom(backgroundColor: Colors.red[50]),
                ),
              ],
            ],
          ),
          if (existingUrl != null && newImage == null)
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16.r),
                  SizedBox(width: 4.w),
                  Text(
                    'Document uploaded',
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 12.sp,
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.cloud_upload_outlined, size: 48.r, color: AppColors.textFaint(context)),
        SizedBox(height: 8.h),
        Text(
          'Tap to select image',
          style: GoogleFonts.goudyBookletter1911(
            fontSize: 14.sp,
            color: AppColors.textMuted(context),
          ),
        ),
        Text(
          'JPG or PNG only',
          style: GoogleFonts.goudyBookletter1911(
            fontSize: 12.sp,
            color: AppColors.textFaint(context),
          ),
        ),
      ],
    );
  }
}
