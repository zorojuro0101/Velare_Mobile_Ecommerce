from flask import Blueprint, render_template, jsonify, request, session
from .profile_helper import get_user_profile_data
import sys
import os
import json

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.supabase_helper import *

myAccount_notification_bp = Blueprint('myAccount_notification', __name__)

@myAccount_notification_bp.route('/myAccount_notification')
def myAccount_notification():
    """🔔 Render notification page with optimized data loading"""
    print("=" * 80)
    print("🔔 [NOTIFICATION PAGE] Loading notification page...")
    print("=" * 80)
    
    profile = get_user_profile_data()
    user_id = session.get('user_id', 1)
    notifications = get_user_notifications(user_id)
    
    print(f"✅ Loaded {len(notifications)} notifications for user_id={user_id}")
    
    return render_template('accounts/myAccount_notification.html', 
                         user_profile=profile, 
                         notifications=notifications)

def get_user_notifications(user_id):
    """Fetch notifications from Supabase (optimized - limited to 100 most recent)"""
    supabase = get_supabase()
    if not supabase:
        return []
    
    try:
        # Fetch notifications - LIMITED TO 100 MOST RECENT
        notifications_response = supabase.table('notifications').select('''
            notification_id,
            user_id,
            title,
            message,
            notification_type,
            is_read,
            created_at,
            updated_at,
            order_id,
            product_names,
            product_images,
            order_total,
            formatted_date
        ''').eq('user_id', user_id).order('created_at', desc=True).limit(100).execute()
        
        if not notifications_response.data:
            return []
        
        # Get all unique order_ids to fetch delivery statuses in ONE query
        order_ids = [n['order_id'] for n in notifications_response.data if n.get('order_id')]
        
        # Fetch ALL delivery statuses at once (NO N+1 QUERY)
        delivery_statuses = {}
        if order_ids:
            delivery_response = supabase.table('deliveries').select('order_id, status').in_('order_id', order_ids).execute()
            if delivery_response.data:
                delivery_statuses = {d['order_id']: d['status'] for d in delivery_response.data}
        
        formatted_notifications = []
        for notification in notifications_response.data:
            # Get delivery status from pre-fetched data
            delivery_status = delivery_statuses.get(notification.get('order_id'))
            
            # Parse product_names and product_images
            product_names = []
            product_images = []
            
            if notification['product_names']:
                try:
                    product_names = json.loads(notification['product_names']) if isinstance(notification['product_names'], str) else notification['product_names']
                except:
                    product_names = [notification['product_names']]
                    
            if notification['product_images']:
                try:
                    product_images = json.loads(notification['product_images']) if isinstance(notification['product_images'], str) else notification['product_images']
                except:
                    product_images = [notification['product_images']]
            
            formatted_notifications.append({
                'notification_id': notification['notification_id'],
                'title': notification['title'],
                'message': notification['message'],
                'notification_type': notification['notification_type'],
                'is_read': notification['is_read'],
                'created_at': notification['created_at'],
                'formatted_date': notification.get('formatted_date') or notification['created_at'],
                'order_total': f"₱{notification['order_total']:,.2f}" if notification.get('order_total') else None,
                'product_names': product_names,
                'product_images': product_images,
                'delivery_status': delivery_status,
                'order_id': notification.get('order_id')
            })
        
        return formatted_notifications
        
    except Exception as e:
        print(f"❌ Error fetching notifications: {e}")
        import traceback
        traceback.print_exc()
        return []

@myAccount_notification_bp.route('/api/notifications/mark-read/<int:notification_id>', methods=['POST'])
def mark_notification_read(notification_id):
    """Mark notification as read"""
    user_id = session.get('user_id', 1)
    
    supabase = get_supabase()
    if not supabase:
        return jsonify({'success': False, 'message': 'Database connection failed'}), 500
    
    try:
        from datetime import datetime
        response = supabase.table('notifications').update({
            'is_read': True,
            'updated_at': datetime.now().isoformat()
        }).eq('notification_id', notification_id).eq('user_id', user_id).execute()
        
        if not response.data:
            return jsonify({'success': False, 'message': 'Notification not found'}), 404
        
        return jsonify({'success': True, 'message': 'Notification marked as read'})
        
    except Exception as e:
        print(f"Error: {e}")
        return jsonify({'success': False, 'message': str(e)}), 500

@myAccount_notification_bp.route('/api/notifications/mark-all-read', methods=['POST'])
def mark_all_notifications_read():
    """Mark all notifications as read"""
    user_id = session.get('user_id', 1)
    
    supabase = get_supabase()
    if not supabase:
        return jsonify({'success': False, 'message': 'Database connection failed'}), 500
    
    try:
        from datetime import datetime
        supabase.table('notifications').update({
            'is_read': True,
            'updated_at': datetime.now().isoformat()
        }).eq('user_id', user_id).eq('is_read', False).execute()
        
        return jsonify({'success': True, 'message': 'All notifications marked as read'})
        
    except Exception as e:
        print(f"Error: {e}")
        return jsonify({'success': False, 'message': str(e)}), 500

@myAccount_notification_bp.route('/api/notifications/delete/<int:notification_id>', methods=['DELETE'])
def delete_notification(notification_id):
    """Delete notification"""
    user_id = session.get('user_id', 1)
    
    supabase = get_supabase()
    if not supabase:
        return jsonify({'success': False, 'message': 'Database connection failed'}), 500
    
    try:
        response = supabase.table('notifications').delete().eq('notification_id', notification_id).eq('user_id', user_id).execute()
        
        if not response.data:
            return jsonify({'success': False, 'message': 'Notification not found'}), 404
        
        return jsonify({'success': True, 'message': 'Notification deleted'})
        
    except Exception as e:
        print(f"Error: {e}")
        return jsonify({'success': False, 'message': str(e)}), 500

@myAccount_notification_bp.route('/api/notifications/count', methods=['GET'])
def get_notification_count():
    """Get unread notification count"""
    user_id = session.get('user_id', 1)
    
    supabase = get_supabase()
    if not supabase:
        return jsonify({'success': False, 'count': 0}), 500
    
    try:
        response = supabase.table('notifications').select('notification_id', count='exact').eq('user_id', user_id).eq('is_read', False).execute()
        count = response.count if response.count else 0
        
        return jsonify({'success': True, 'count': count})
    except Exception as e:
        print(f"Error: {e}")
        return jsonify({'success': False, 'count': 0}), 500
