import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'notification_service.dart';

class SessionService {
  final _supabase = Supabase.instance.client;
  final _notificationService = NotificationService();
  final _deviceInfo = DeviceInfoPlugin();

  Future<Map<String, String>> _getDeviceInfo() async {
    String deviceInfo = 'Unknown Device';
    String os = 'Unknown OS';
    String browser = 'Mobile App';

    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        deviceInfo = '${androidInfo.brand} ${androidInfo.model}';
        os = 'Android ${androidInfo.version.release}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        deviceInfo = '${iosInfo.name} ${iosInfo.model}';
        os = 'iOS ${iosInfo.systemVersion}';
      }
    } catch (e) {
      print('Error getting device info: $e');
    }

    return {
      'device_info': deviceInfo,
      'os': os,
      'browser': browser,
    };
  }

  String _generateSessionToken(String userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final data = '$userId-$timestamp';
    return sha256.convert(utf8.encode(data)).toString();
  }

  Future<String?> createSession(String userId) async {
    try {
      print('=== Creating Session ===');
      print('User ID: $userId');

      final deviceData = await _getDeviceInfo();
      final sessionToken = _generateSessionToken(userId);
      final ipAddress = '127.0.0.1'; // Mobile apps don't have direct IP access
      final now = DateTime.now().toIso8601String();

      print('Device Info: ${deviceData['device_info']}');
      print('OS: ${deviceData['os']}');

      // Check if this is a new device by comparing device_info and os
      final existingSessions = await _supabase
          .from('user_sessions')
          .select('session_id, device_info, os')
          .eq('user_id', userId)
          .eq('device_info', deviceData['device_info']!)
          .eq('os', deviceData['os']!);

      final isNewDevice = (existingSessions as List).isEmpty;
      print('Is new device: $isNewDevice');

      // Insert new session
      final response = await _supabase.from('user_sessions').insert({
        'user_id': userId,
        'session_token': sessionToken,
        'device_info': deviceData['device_info'],
        'browser': deviceData['browser'],
        'os': deviceData['os'],
        'ip_address': ipAddress,
        'login_time': now,
        'last_activity': now,
        'is_active': true,
        'created_at': now,
      }).select().single();

      print('Session created: ${response['session_id']}');

      // Send notification if this is a new device
      if (isNewDevice) {
        print('Sending new device notification...');
        
        // Format the login time
        final loginTime = DateTime.now();
        const months = [
          'January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December'
        ];
        final month = months[loginTime.month - 1];
        final day = loginTime.day.toString().padLeft(2, '0');
        final year = loginTime.year;
        final hour = loginTime.hour > 12 ? loginTime.hour - 12 : (loginTime.hour == 0 ? 12 : loginTime.hour);
        final minute = loginTime.minute.toString().padLeft(2, '0');
        final period = loginTime.hour >= 12 ? 'PM' : 'AM';
        final formattedTime = '$month $day, $year at ${hour.toString().padLeft(2, '0')}:$minute $period';
        
        await _notificationService.sendNotification(
          userId: userId,
          title: 'New Device Login Detected',
          message: 'Your account was accessed from a new device: ${deviceData['device_info']} on ${deviceData['os']} at $formattedTime. If this wasn\'t you, please change your password immediately.',
          type: 'system',
          formattedDate: formattedTime,
        );
        print('New device notification sent');
      }

      return response['session_id'].toString();
    } catch (e) {
      print('Error creating session: $e');
      return null;
    }
  }

  Future<void> updateSessionActivity(String sessionId) async {
    try {
      await _supabase.from('user_sessions').update({
        'last_activity': DateTime.now().toIso8601String(),
      }).eq('session_id', sessionId);
    } catch (e) {
      print('Error updating session activity: $e');
    }
  }

  Future<void> endSession(String sessionId) async {
    try {
      await _supabase.from('user_sessions').update({
        'is_active': false,
      }).eq('session_id', sessionId);
      print('Session ended: $sessionId');
    } catch (e) {
      print('Error ending session: $e');
    }
  }

  Future<void> endAllUserSessions(String userId) async {
    try {
      await _supabase.from('user_sessions').update({
        'is_active': false,
      }).eq('user_id', userId);
      print('All sessions ended for user: $userId');
    } catch (e) {
      print('Error ending all sessions: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getActiveSessions(String userId) async {
    try {
      final response = await _supabase
          .from('user_sessions')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('login_time', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting active sessions: $e');
      return [];
    }
  }
}
