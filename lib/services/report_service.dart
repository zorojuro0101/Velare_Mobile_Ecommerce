import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/report_model.dart';
import 'auth_service.dart';

class ReportService {
  final _supabase = Supabase.instance.client;
  final _authService = AuthService();

  static const String _storageBucket = 'Images';
  static const String _evidenceFolder = 'static/uploads/reports';

  Future<List<Report>> getMyReports() async {
    try {
      await _authService.initialize();
      final userId = _authService.currentUserId;

      if (userId == null) {
        throw Exception('User not logged in');
      }

      final response = await _supabase
          .from('user_reports')
          .select('''
            *,
            reported_user:reported_user_id (
              user_id,
              email
            )
          ''')
          .eq('reporter_id', int.parse(userId))
          .order('created_at', ascending: false);

      final reports = <Report>[];
      for (var item in response as List) {
        // Get reported user name based on type
        String? reportedUserName;
        final reportedUserId = item['reported_user_id'];
        final reportedUserType = item['reported_user_type'];

        try {
          if (reportedUserType == 'seller') {
            final sellerResponse = await _supabase
                .from('sellers')
                .select('shop_name')
                .eq('user_id', reportedUserId)
                .maybeSingle();
            reportedUserName = sellerResponse?['shop_name'];
          } else if (reportedUserType == 'rider') {
            final riderResponse = await _supabase
                .from('riders')
                .select('first_name, last_name')
                .eq('user_id', reportedUserId)
                .maybeSingle();
            if (riderResponse != null) {
              reportedUserName =
                  '${riderResponse['first_name']} ${riderResponse['last_name']}';
            }
          }
        } catch (e) {
          print('Error fetching reported user name: $e');
        }

        item['reported_user_name'] = reportedUserName ?? 'Unknown';
        reports.add(Report.fromJson(item));
      }

      return reports;
    } catch (e) {
      print('Error loading reports: $e');
      throw Exception('Failed to load reports: $e');
    }
  }

  /// Uploads an evidence image to Supabase Storage and returns the
  /// fully-qualified public URL. Throws on failure so the caller can show
  /// a clear error to the user instead of silently saving a local path.
  Future<String> uploadEvidence(XFile imageFile) async {
    final buyerId = _authService.currentBuyerId;
    if (buyerId == null) {
      throw Exception('User not logged in');
    }

    final bytes = await imageFile.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('Selected image is empty');
    }

    final rawExt = imageFile.path.split('.').last.toLowerCase();
    final ext = rawExt.isEmpty ? 'jpg' : rawExt;
    final contentType = 'image/${ext == 'jpg' ? 'jpeg' : ext}';

    final fileName =
        'report_${buyerId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final filePath = '$_evidenceFolder/$fileName';

    print('ReportService - uploading evidence to Supabase: $filePath');

    try {
      await _supabase.storage
          .from(_storageBucket)
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true,
            ),
          )
          .timeout(const Duration(seconds: 30));
    } on StorageException catch (e) {
      print('ReportService - Supabase storage error: ${e.message}');
      throw Exception('Storage upload failed: ${e.message}');
    } catch (e) {
      print('ReportService - upload error: $e');
      throw Exception('Failed to upload evidence: $e');
    }

    final publicUrl =
        _supabase.storage.from(_storageBucket).getPublicUrl(filePath);
    print('ReportService - evidence uploaded. Public URL: $publicUrl');
    return publicUrl;
  }

  Future<bool> submitReport({
    required int reportedUserId,
    required String reportedUserType,
    required String category,
    required String reason,
    int? orderId,
    int? deliveryId,
    String? evidenceImage,
  }) async {
    try {
      await _authService.initialize();
      final userId = _authService.currentUserId;

      if (userId == null) {
        throw Exception('User not logged in');
      }

      await _supabase.from('user_reports').insert({
        'reporter_id': int.parse(userId),
        'reporter_type': 'buyer',
        'reported_user_id': reportedUserId,
        'reported_user_type': reportedUserType,
        'report_category': category,
        'report_reason': reason,
        'order_id': orderId,
        'delivery_id': deliveryId,
        'evidence_image': evidenceImage,
        'status': 'pending',
      });

      return true;
    } catch (e) {
      print('Error submitting report: $e');
      return false;
    }
  }

  Future<void> deleteReport(int reportId) async {
    try {
      await _authService.initialize();
      final userId = _authService.currentUserId;

      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Delete the report (only if it belongs to the current user)
      await _supabase
          .from('user_reports')
          .delete()
          .eq('report_id', reportId)
          .eq('reporter_id', int.parse(userId));
    } catch (e) {
      print('Error deleting report: $e');
      throw Exception('Failed to delete report');
    }
  }
}
