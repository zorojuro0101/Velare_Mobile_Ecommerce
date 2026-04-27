import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import '../models/report_model.dart';

class RiderReportService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get rider's deliveries with buyer and seller information
  Future<List<DeliveryOption>> getRiderDeliveries(int riderId) async {
    try {
      print(
        '🔍 RiderReportService - Getting deliveries for rider_id: $riderId',
      );

      final response = await _supabase
          .from('deliveries')
          .select('''
            delivery_id,
            order_id,
            orders!inner(
              order_id,
              order_number,
              buyer_id,
              seller_id,
              buyers!inner(
                buyer_id,
                first_name,
                last_name,
                user_id
              ),
              sellers!inner(
                seller_id,
                shop_name,
                user_id
              )
            )
          ''')
          .eq('rider_id', riderId)
          .order('created_at', ascending: false)
          .limit(50);

      print('✅ Got ${response.length} deliveries');

      return (response as List)
          .map((json) => DeliveryOption.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error getting deliveries: $e');
      rethrow;
    }
  }

  /// Get rider's submitted reports
  Future<List<Report>> getRiderReports(String userId) async {
    try {
      print('🔍 RiderReportService - Getting reports for user_id: $userId');

      final response = await _supabase
          .from('user_reports')
          .select('*')
          .eq('reporter_id', int.parse(userId))
          .eq('reporter_type', 'rider')
          .order('created_at', ascending: false);

      print('✅ Got ${response.length} reports');

      // Fetch reported user names
      final reports = <Report>[];
      for (final reportData in response) {
        String reportedUserName = 'Unknown';

        try {
          if (reportData['reported_user_type'] == 'buyer') {
            final buyerResponse = await _supabase
                .from('buyers')
                .select('first_name, last_name')
                .eq('user_id', reportData['reported_user_id'])
                .single();

            reportedUserName =
                '${buyerResponse['first_name']} ${buyerResponse['last_name']}';
          } else if (reportData['reported_user_type'] == 'seller') {
            final sellerResponse = await _supabase
                .from('sellers')
                .select('shop_name')
                .eq('user_id', reportData['reported_user_id'])
                .single();

            reportedUserName = sellerResponse['shop_name'];
          }
        } catch (e) {
          print('⚠️ Error fetching reported user name: $e');
        }

        reports.add(
          Report.fromJson({
            ...reportData,
            'reported_user_name': reportedUserName,
          }),
        );
      }

      return reports;
    } catch (e) {
      print('❌ Error getting reports: $e');
      rethrow;
    }
  }

  /// Upload evidence image to Supabase Storage
  Future<String?> uploadEvidence(File imageFile) async {
    try {
      print('📸 Uploading evidence image...');

      final fileName =
          'report_${DateTime.now().millisecondsSinceEpoch}_${path.basename(imageFile.path)}';

      await _supabase.storage
          .from('reports')
          .upload(
            fileName,
            imageFile,
            fileOptions: const FileOptions(upsert: false),
          );

      final publicUrl = _supabase.storage
          .from('reports')
          .getPublicUrl(fileName);

      print('✅ Evidence uploaded: $fileName');
      return publicUrl;
    } catch (e) {
      print('❌ Error uploading evidence: $e');
      return null;
    }
  }

  /// Submit a new report
  Future<bool> submitReport({
    required String reporterId,
    required String reportedUserType,
    required int reportedId,
    required String category,
    required String reason,
    int? orderId,
    int? deliveryId,
    File? evidenceFile,
  }) async {
    try {
      print('=' * 60);
      print('📝 SUBMIT REPORT - Processing');
      print('=' * 60);
      print('🔍 Reporting $reportedUserType ID: $reportedId');
      print('📋 Category: $category');

      // 1. Get reported_user_id
      int reportedUserId;
      if (reportedUserType == 'buyer') {
        final response = await _supabase
            .from('buyers')
            .select('user_id')
            .eq('buyer_id', reportedId)
            .single();
        reportedUserId = response['user_id'];
      } else if (reportedUserType == 'seller') {
        final response = await _supabase
            .from('sellers')
            .select('user_id')
            .eq('seller_id', reportedId)
            .single();
        reportedUserId = response['user_id'];
      } else {
        print('❌ Invalid user type: $reportedUserType');
        return false;
      }

      print('👤 Reported user_id: $reportedUserId');

      // 2. Upload evidence if provided
      String? evidencePath;
      if (evidenceFile != null) {
        evidencePath = await uploadEvidence(evidenceFile);
        if (evidencePath == null) {
          print('⚠️ Failed to upload evidence, continuing without it');
        }
      }

      // 3. Insert report
      final reportData = {
        'reporter_id': int.parse(reporterId),
        'reporter_type': 'rider',
        'reported_user_id': reportedUserId,
        'reported_user_type': reportedUserType,
        'report_category': category,
        'report_reason': reason,
        'status': 'pending',
      };

      if (orderId != null) reportData['order_id'] = orderId;
      if (deliveryId != null) reportData['delivery_id'] = deliveryId;
      if (evidencePath != null) reportData['evidence_image'] = evidencePath;

      await _supabase.from('user_reports').insert(reportData);

      print('✅ Report inserted');

      // 4. Update report count
      final countResponse = await _supabase
          .from('user_reports')
          .select('report_id')
          .eq('reported_user_id', reportedUserId);

      final reportCount = countResponse.length;
      print('📊 Report count for user: $reportCount');

      if (reportedUserType == 'buyer') {
        await _supabase
            .from('buyers')
            .update({'report_count': reportCount})
            .eq('user_id', reportedUserId);
        print('✅ Updated buyer report count');
      } else if (reportedUserType == 'seller') {
        await _supabase
            .from('sellers')
            .update({'report_count': reportCount})
            .eq('user_id', reportedUserId);
        print('✅ Updated seller report count');
      }

      print('✅ Report submitted successfully');
      print('=' * 60);

      return true;
    } catch (e) {
      print('❌ Error submitting report: $e');
      return false;
    }
  }
}
