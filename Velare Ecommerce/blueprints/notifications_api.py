from flask import Blueprint, jsonify, session
import sys
import os

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.supabase_helper import (
    get_user_unread_notification_count,
    get_user_recent_notifications,
    mark_notification_as_read
)

notifications_api_bp = Blueprint('notifications_api', __name__)

@notifications_api_bp.route('/api/notifications')
def get_notifications():
    """Get notifications for the logged-in user"""
    try:
        user_id = session.get('user_id')
        
        if not user_id:
            return jsonify({'success': False, 'message': 'Not logged in'}), 401
        
        # Get unread count
        unread_count = get_user_unread_notification_count(user_id)
        
        # Get recent notifications (last 20)
        notifications = get_user_recent_notifications(user_id)
        
        return jsonify({
            'success': True,
            'unread_count': unread_count,
            'notifications': notifications
        })
        
    except Exception as e:
        print(f"Error fetching notifications: {e}")
        return jsonify({'success': False, 'message': str(e)}), 500

@notifications_api_bp.route('/api/notifications/<int:notification_id>/read', methods=['POST'])
def mark_notification_read_route(notification_id):
    """Mark a notification as read"""
    try:
        user_id = session.get('user_id')
        
        if not user_id:
            return jsonify({'success': False, 'message': 'Not logged in'}), 401
        
        # Mark as read (only if it belongs to the user)
        mark_notification_as_read(notification_id, user_id)
        
        return jsonify({'success': True})
        
    except Exception as e:
        print(f"Error marking notification as read: {e}")
        return jsonify({'success': False, 'message': str(e)}), 500
