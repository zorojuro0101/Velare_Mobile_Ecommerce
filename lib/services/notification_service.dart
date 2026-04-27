import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  final _supabase = Supabase.instance.client;

  Future<void> sendNotification({
    required String userId,
    required String title,
    required String message,
    String type = 'system',
    String? formattedDate,
  }) async {
    try {
      final now = DateTime.now();
      final formatted = formattedDate ?? _formatDate(now);
      
      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'message': message,
        'notification_type': type,
        'is_read': false,
        'created_at': now.toIso8601String(),
        'formatted_date': formatted,
      });
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  String _formatDate(DateTime dateTime) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    final month = months[dateTime.month - 1];
    final day = dateTime.day.toString().padLeft(2, '0');
    final year = dateTime.year;
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    
    return '$month $day, $year at ${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  Future<int> getUnreadCount(String userId) async {
    try {
      print('=== NotificationService getUnreadCount ===');
      print('userId: $userId');
      
      final response = await _supabase
          .from('notifications')
          .select('notification_id')
          .eq('user_id', userId)
          .eq('is_read', false);

      final count = (response as List).length;
      print('Unread notifications: $count');
      return count;
    } catch (e) {
      print('Error in getUnreadCount: $e');
      return 0;
    }
  }

  Future<void> markAsRead(int notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('notification_id', notificationId);
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId);
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> deleteNotification(int notificationId) async {
    try {
      await _supabase.from('notifications').delete().eq('notification_id', notificationId);
    } catch (e) {
      // Handle error silently
    }
  }
}
