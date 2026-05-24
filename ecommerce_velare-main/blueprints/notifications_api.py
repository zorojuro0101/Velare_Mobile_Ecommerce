from flask import Blueprint, jsonify, session
import sys
import os

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_config import get_supabase_client

notifications_api_bp = Blueprint('notifications_api', __name__)

@notifications_api_bp.route('/api/notifications')
def get_notifications():
    """Get notifications for the logged-in user"""
    try:
        user_id = session.get('user_id')
        
        if not user_id:
            return jsonify({'success': False, 'message': 'Not logged in'}), 401
        
        print(f"🔔 Getting notifications for user_id={user_id}")
        supabase = get_supabase_client()
        
        # Get unread count
        unread_response = supabase.table('notifications').select('notification_id', count='exact').eq('user_id', user_id).eq('is_read', False).execute()
        unread_count = unread_response.count
        
        # Get recent notifications (last 20)
        notifications_response = supabase.table('notifications').select('notification_id, title, message, notification_type, is_read, created_at').eq('user_id', user_id).order('created_at', desc=True).limit(20).execute()
        
        notifications = notifications_response.data
        
        print(f"✅ Loaded {len(notifications)} notifications ({unread_count} unread)")
        
        return jsonify({
            'success': True,
            'unread_count': unread_count,
            'notifications': notifications
        })
        
    except Exception as e:
        print(f"❌ Error fetching notifications: {e}")
        return jsonify({'success': False, 'message': str(e)}), 500

@notifications_api_bp.route('/api/notifications/<int:notification_id>/read', methods=['POST'])
def mark_notification_read(notification_id):
    """Mark a notification as read"""
    try:
        user_id = session.get('user_id')
        
        if not user_id:
            return jsonify({'success': False, 'message': 'Not logged in'}), 401
        
        print(f"🔔 Marking notification {notification_id} as read")
        supabase = get_supabase_client()
        
        # Mark as read (only if it belongs to the user)
        supabase.table('notifications').update({'is_read': True}).eq('notification_id', notification_id).eq('user_id', user_id).execute()
        
        print(f"✅ Notification marked as read")
        
        return jsonify({'success': True})
        
    except Exception as e:
        print(f"❌ Error marking notification as read: {e}")
        return jsonify({'success': False, 'message': str(e)}), 500
