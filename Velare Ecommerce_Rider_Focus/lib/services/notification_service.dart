import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  final _supabase = Supabase.instance.client;

  /// Get unread notification count for a user
  Future<int> getUnreadCount(String userId) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select('notification_id')
          .eq('user_id', userId)
          .eq('is_read', false);

      return (response as List).length;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  /// Send a notification to a user
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String message,
    String type = 'order',
    int? orderId,
  }) async {
    try {
      final now = DateTime.now();
      final formattedDate =
          '${_getMonthName(now.month)} ${now.day}, ${now.year} at ${_formatTime(now)}';

      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'message': message,
        'notification_type': type,
        'is_read': false,
        if (orderId != null) 'order_id': orderId,
        'formatted_date': formattedDate,
        'created_at': now.toIso8601String(),
      });

      print('✅ Notification sent: $title');
    } catch (e) {
      print('⚠️ Failed to send notification: $e');
    }
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12
        ? time.hour - 12
        : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
