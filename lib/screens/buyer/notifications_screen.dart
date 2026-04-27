import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../utils/snackbar_helper.dart';
import 'order_history_screen.dart';
import 'order_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    print('=== Loading Notifications ===');
    setState(() => _isLoading = true);
    try {
      final userId = AuthService().currentUserId;
      print('User ID: $userId');
      
      if (userId != null) {
        print('Fetching notifications from database...');
        final response = await _supabase
            .from('notifications')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false);

        print('Response received: ${response.length} notifications');
        
        if (mounted) {
          setState(() {
            _notifications = List<Map<String, dynamic>>.from(response);
            _isLoading = false;
          });
          print('State updated - isLoading: false, notifications count: ${_notifications.length}');
        }
      } else {
        print('No user ID found');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print('Error loading notifications: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markAsRead(int notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('notification_id', notificationId);
      _loadNotifications();
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final userId = AuthService().currentUserId;
      if (userId != null) {
        await _supabase
            .from('notifications')
            .update({'is_read': true})
            .eq('user_id', userId);
        _loadNotifications();
        if (mounted) {
          SnackBarHelper.showSuccess(context, 'All notifications marked as read');
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Error: $e');
      }
    }
  }

  Future<void> _deleteNotification(int notificationId) async {
    try {
      await _supabase.from('notifications').delete().eq('notification_id', notificationId);
      _loadNotifications();
      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Notification deleted');
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Error: $e');
      }
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'order':
        return Icons.shopping_bag;
      case 'delivery':
        return Icons.local_shipping;
      case 'promotion':
        return Icons.local_offer;
      case 'system':
        return Icons.info;
      case 'security':
        return Icons.security;
      case 'warning':
        return Icons.warning;
      case 'message':
        return Icons.message;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'order':
        return const Color(0xFFD4AF37); // Gold
      case 'delivery':
        return const Color(0xFFDAA520); // Goldenrod
      case 'promotion':
        return const Color(0xFFCD853F); // Peru
      case 'system':
        return const Color(0xFF8B4513); // Saddle Brown
      case 'security':
        return const Color(0xFFDC143C); // Crimson Red
      case 'warning':
        return const Color(0xFFFF8C00); // Dark Orange
      case 'message':
        return const Color(0xFFB8860B); // Dark Goldenrod
      default:
        return Colors.black;
    }
  }

  String _formatTime(String timestamp) {
    final dateTime = DateTime.parse(timestamp);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => n['is_read'] != true).length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Notifications', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(
                'Mark all read',
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 14,
                  color: const Color(0xFFD4AF37), // Gold
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : _notifications.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: const Color(0xFFD4AF37),
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      return _buildNotificationCard(_notifications[index]);
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
          Icon(Icons.notifications_none, size: 100, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No notifications',
            style: GoogleFonts.goudyBookletter1911(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'re all caught up!',
            style: GoogleFonts.goudyBookletter1911(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final isRead = notification['is_read'] == true;
    final type = notification['notification_type'] ?? notification['type'] ?? 'system';
    final isSecurityOrWarning = type == 'security' || type == 'warning' || type == 'system';

    return Dismissible(
      key: Key(notification['notification_id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteNotification(notification['notification_id']),
      child: GestureDetector(
        onTap: isSecurityOrWarning ? null : () {
          if (!isRead) {
            _markAsRead(notification['notification_id']);
          }
          _handleNotificationTap(notification);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRead ? Colors.grey[300]! : const Color(0xFFD4AF37),
              width: isRead ? 1 : 2,
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getNotificationColor(type).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getNotificationIcon(type),
                  size: 20,
                  color: _getNotificationColor(type),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification['title'] ?? 'Notification',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 15,
                        fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification['message'] ?? '',
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                      // Show full text for security/warning, limit for others
                      maxLines: isSecurityOrWarning ? null : 3,
                      overflow: isSecurityOrWarning ? TextOverflow.visible : TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatTime(notification['created_at']),
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isRead)
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD4AF37), // Gold dot for unread
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    final type = notification['notification_type'] ?? notification['type'] ?? 'system';
    final orderId = notification['order_id'];
    final title = notification['title'] ?? '';

    // Handle order/delivery notifications
    if (type == 'order' || type == 'delivery') {
      if (orderId != null) {
        // Navigate to order detail screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(orderId: orderId),
          ),
        );
      } else {
        // Navigate to order history with appropriate tab
        String tab = 'pending';
        if (title.toLowerCase().contains('shipped') || title.toLowerCase().contains('transit')) {
          tab = 'in_transit';
        } else if (title.toLowerCase().contains('delivered')) {
          tab = 'delivered';
        } else if (title.toLowerCase().contains('cancelled')) {
          tab = 'cancelled';
        }
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderHistoryScreen(initialTab: tab),
          ),
        );
      }
    }
    // For other notification types, you can add more handlers here
  }
}
