# Helper functions to create notifications when order status changes

import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.supabase_helper import get_supabase
import json
from datetime import datetime

def create_order_notification(order_id, order_number, buyer_id, total_amount, status):
    """
    Create a notification when order status changes to in_transit or delivered
    """
    supabase = get_supabase()
    if not supabase:
        return False
    
    try:
        # Get buyer's user_id
        buyer_response = supabase.table('buyers').select('user_id').eq('buyer_id', buyer_id).execute()
        
        if not buyer_response.data:
            return False
            
        user_id = buyer_response.data[0]['user_id']
        
        # Get product names and images for this order
        items_response = supabase.table('order_items').select('''
            product_name,
            product_id
        ''').eq('order_id', order_id).execute()
        
        if not items_response.data:
            return False
        
        product_names = []
        product_images = []
        
        # Get image for each product
        for item in items_response.data:
            product_names.append(item['product_name'])
            
            # Get primary image for this product
            image_response = supabase.table('product_images').select('image_url').eq('product_id', item['product_id']).order('is_primary', desc=True).order('display_order').limit(1).execute()
            
            if image_response.data:
                product_images.append(image_response.data[0]['image_url'])
        
        # Create notification data
        if status == 'in_transit':
            title = 'Order Shipped'
            message = f'Your order #{order_number} is now on its way! Expected delivery in 2-3 business days.'
        elif status == 'delivered':
            title = 'Order Delivered'
            message = f'Your order #{order_number} has been delivered successfully!'
        else:
            return False
        
        # Format date
        formatted_date = datetime.now().strftime('%B %d, %Y at %I:%M %p')
        
        # Insert notification
        notification_data = {
            'user_id': user_id,
            'title': title,
            'message': message,
            'notification_type': 'delivery',
            'is_read': False,
            'order_id': order_id,
            'product_names': json.dumps(product_names),
            'product_images': json.dumps(product_images),
            'order_total': total_amount,
            'formatted_date': formatted_date
        }
        
        response = supabase.table('notifications').insert(notification_data).execute()
        
        if response.data:
            print(f"✅ Created notification: {title} for order #{order_number}")
            return True
        return False
        
    except Exception as e:
        print(f"❌ Error creating notification: {e}")
        import traceback
        traceback.print_exc()
        return False

def create_shipped_notification(order_id, order_number, buyer_id, total_amount):
    """Helper function for shipped orders"""
    return create_order_notification(order_id, order_number, buyer_id, total_amount, 'in_transit')

def create_delivered_notification(order_id, order_number, buyer_id, total_amount):
    """Helper function for delivered orders"""
    return create_order_notification(order_id, order_number, buyer_id, total_amount, 'delivered')

def create_stock_notification(user_id, product_name, product_id, stock_status, new_stock):
    """
    Create a notification when a product in cart changes stock status
    stock_status: 'low_on_stock' or 'out_of_stock'
    """
    supabase = get_supabase()
    if not supabase:
        return False
    
    try:
        # Get product image
        image_response = supabase.table('product_images').select('image_url').eq('product_id', product_id).order('is_primary', desc=True).order('display_order').limit(1).execute()
        
        product_image = image_response.data[0]['image_url'] if image_response.data else None
        
        # Create notification data
        if stock_status == 'out_of_stock':
            title = '⚠️ Product Out of Stock'
            message = f'"{product_name}" in your cart is now out of stock. Please review your cart.'
        elif stock_status == 'low_on_stock':
            title = '⚠️ Low Stock Alert'
            message = f'"{product_name}" in your cart is running low on stock ({new_stock} items left). Consider completing your purchase soon!'
        else:
            return False
        
        # Format date
        formatted_date = datetime.now().strftime('%B %d, %Y at %I:%M %p')
        
        # Insert notification
        notification_data = {
            'user_id': user_id,
            'title': title,
            'message': message,
            'notification_type': 'product',
            'is_read': False,
            'product_names': json.dumps([product_name]),
            'product_images': json.dumps([product_image] if product_image else []),
            'formatted_date': formatted_date,
            'updated_at': datetime.now().isoformat()
        }
        
        response = supabase.table('notifications').insert(notification_data).execute()
        
        if response.data:
            print(f"✅ Created stock notification: {title} for {product_name}")
            return True
        return False
        
    except Exception as e:
        print(f"❌ Error creating stock notification: {e}")
        import traceback
        traceback.print_exc()
        return False

def create_report_notification(reported_user_id, reported_user_type, report_category):
    """
    Create a notification when a user is reported
    reported_user_type: 'buyer', 'seller', or 'rider'
    report_category: category of the report
    """
    supabase = get_supabase()
    if not supabase:
        return False
    
    try:
        # Count total reports for this user
        report_response = supabase.table('user_reports').select('report_id', count='exact').eq('reported_user_id', reported_user_id).eq('reported_user_type', reported_user_type).execute()
        
        report_count = report_response.count if report_response.count else 0
        
        # Determine warning level based on report count
        if report_count >= 5:
            warning_level = 'severe'
            suspension_warning = 'Your account may be suspended for 4 weeks or permanently banned if violations continue.'
        elif report_count >= 3:
            warning_level = 'high'
            suspension_warning = 'Your account may be suspended for 2 weeks if you receive more reports.'
        else:
            warning_level = 'moderate'
            suspension_warning = 'Please review our community guidelines to avoid further reports.'
        
        # Create notification message
        title = '⚠️ You Have Been Reported'
        message = f'You have been reported for "{report_category}". {suspension_warning} Total reports: {report_count}. Please review our terms of service and ensure you follow community guidelines.'
        
        # Format date
        formatted_date = datetime.now().strftime('%B %d, %Y at %I:%M %p')
        
        # Insert notification
        notification_data = {
            'user_id': reported_user_id,
            'title': title,
            'message': message,
            'notification_type': 'warning',
            'is_read': False,
            'formatted_date': formatted_date
        }
        
        response = supabase.table('notifications').insert(notification_data).execute()
        
        if response.data:
            print(f"✅ Created report notification for user {reported_user_id} ({reported_user_type})")
            return True
        return False
        
    except Exception as e:
        print(f"❌ Error creating report notification: {e}")
        import traceback
        traceback.print_exc()
        return False

def create_suspension_notification(user_id, action, duration_text, reason):
    """
    Create a notification when a user is suspended or banned
    action: 'suspend' or 'ban'
    duration_text: e.g., '2 weeks', '1 month', 'permanently'
    reason: reason for suspension/ban
    """
    supabase = get_supabase()
    if not supabase:
        return False
    
    try:
        # Create notification message based on action
        if action == 'ban':
            title = '🚫 Account Permanently Banned'
            message = f'Your account has been permanently banned. Reason: {reason}. You will no longer be able to access this platform. If you believe this is a mistake, please contact support.'
        else:  # suspend
            title = '⛔ Account Suspended'
            message = f'Your account has been suspended for {duration_text}. Reason: {reason}. You will not be able to access your account during this period. Please review our terms of service and community guidelines.'
        
        # Format date
        formatted_date = datetime.now().strftime('%B %d, %Y at %I:%M %p')
        
        # Insert notification
        notification_data = {
            'user_id': user_id,
            'title': title,
            'message': message,
            'notification_type': 'warning',
            'is_read': False,
            'formatted_date': formatted_date
        }
        
        response = supabase.table('notifications').insert(notification_data).execute()
        
        if response.data:
            print(f"✅ Created suspension notification for user {user_id} ({action}ed for {duration_text})")
            return True
        return False
        
    except Exception as e:
        print(f"❌ Error creating suspension notification: {e}")
        import traceback
        traceback.print_exc()
        return False

def create_sample_notifications(user_id):
    """Create sample notifications for testing"""
    supabase = get_supabase()
    if not supabase:
        return False
    
    try:
        formatted_date = datetime.now().strftime('%B %d, %Y at %I:%M %p')
        
        notifications = [
            {
                'user_id': user_id,
                'title': 'Order Shipped',
                'message': 'Your order #ORD001 is now on its way! Expected delivery in 2-3 business days.',
                'notification_type': 'delivery',
                'is_read': False,
                'order_id': 1,
                'product_names': json.dumps(['Elegant Dress', 'Silk Blouse']),
                'order_total': 2500.00,
                'formatted_date': formatted_date
            },
            {
                'user_id': user_id,
                'title': 'Order Delivered',
                'message': 'Your order #ORD002 has been delivered successfully!',
                'notification_type': 'delivery',
                'is_read': False,
                'order_id': 2,
                'product_names': json.dumps(['Leather Handbag']),
                'order_total': 1800.00,
                'formatted_date': formatted_date
            },
            {
                'user_id': user_id,
                'title': 'New Product Alert',
                'message': 'Check out our new collection of winter dresses!',
                'notification_type': 'product',
                'is_read': False,
                'formatted_date': formatted_date
            },
            {
                'user_id': user_id,
                'title': 'Message from Seller',
                'message': 'Thank you for your purchase! We hope you love your items.',
                'notification_type': 'message',
                'is_read': False,
                'formatted_date': formatted_date
            }
        ]
        
        response = supabase.table('notifications').insert(notifications).execute()
        
        if response.data:
            print(f"✅ Created {len(notifications)} sample notifications for user {user_id}")
            return True
        return False
        
    except Exception as e:
        print(f"❌ Error creating sample notifications: {e}")
        import traceback
        traceback.print_exc()
        return False
