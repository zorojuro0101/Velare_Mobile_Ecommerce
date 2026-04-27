import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../utils/snackbar_helper.dart';

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
      final userId = AuthService().currentUserId;
      if (userId == null) throw Exception('User not logged in');

      final riderId = _riderData?['rider_id'];
      if (riderId == null) throw Exception('Rider ID not found');

      final updateData = <String, dynamic>{};

      // Upload OR/CR
      if (_orcrImage != null) {
        final orcrFileName =
            'rider_${riderId}_orcr_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final orcrPath = 'rider_documents/$riderId/$orcrFileName';

        await _supabase.storage
            .from('documents')
            .upload(
              orcrPath,
              _orcrImage!,
              fileOptions: const FileOptions(upsert: true),
            );

        final orcrUrl = _supabase.storage
            .from('documents')
            .getPublicUrl(orcrPath);
        updateData['orcr_file_path'] = orcrUrl;
      }

      // Upload Driver's License
      if (_licenseImage != null) {
        final licenseFileName =
            'rider_${riderId}_license_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final licensePath = 'rider_documents/$riderId/$licenseFileName';

        await _supabase.storage
            .from('documents')
            .upload(
              licensePath,
              _licenseImage!,
              fileOptions: const FileOptions(upsert: true),
            );

        final licenseUrl = _supabase.storage
            .from('documents')
            .getPublicUrl(licensePath);
        updateData['driver_license_file_path'] = licenseUrl;
      }

      // Update database
      if (updateData.isNotEmpty) {
        await _supabase.from('riders').update(updateData).eq('user_id', userId);
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
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to upload documents');
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
          'Verification Documents',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(),
                  const SizedBox(height: 24),
                  _buildDocumentSection(
                    'OR/CR (Official Receipt / Certificate of Registration)',
                    'orcr',
                    _riderData?['orcr_file_path'],
                    _orcrImage,
                  ),
                  const SizedBox(height: 24),
                  _buildDocumentSection(
                    'Driver\'s License',
                    'license',
                    _riderData?['driver_license_file_path'],
                    _licenseImage,
                  ),
                  const SizedBox(height: 32),
                  if (_orcrImage != null || _licenseImage != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _isUploading ? null : _uploadDocuments,
                        child: _isUploading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Upload Documents',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Upload clear photos of your OR/CR and Driver\'s License for verification purposes.',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.blue[900]),
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
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _pickImage(documentType),
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!, width: 2),
              ),
              child: newImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(newImage, fit: BoxFit.cover),
                    )
                  : existingUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Colors.black),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _pickImage(documentType),
                  icon: const Icon(Icons.photo_library, size: 18),
                  label: Text(
                    newImage != null || existingUrl != null
                        ? 'Change Photo'
                        : 'Select Photo',
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                ),
              ),
              if (newImage != null) ...[
                const SizedBox(width: 8),
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
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Document uploaded',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
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
        Icon(Icons.cloud_upload_outlined, size: 48, color: Colors.grey[400]),
        const SizedBox(height: 8),
        Text(
          'Tap to select image',
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
        ),
        Text(
          'JPG or PNG only',
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
        ),
      ],
    );
  }
}
