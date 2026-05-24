# Helper functions to create notifications when order status changes

import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_config import get_supabase_client
import json
from datetime import datetime, timedelta

def create_order_notification(order_id, order_number, buyer_id, total_amount, status):
    """
    Create a notification when order status changes to in_transit or delivered
    """
    print(f"🔔 Creating order notification for order #{order_number}, status={status}")
    supabase = get_supabase_client()
    
    try:
        # Get buyer's user_id
        buyer_response = supabase.table('buyers').select('user_id').eq('buyer_id', buyer_id).execute()
        
        if not buyer_response.data:
            print(f"❌ Buyer not found")
            return False
            
        user_id = buyer_response.data[0]['user_id']
        
        # Get product names and images for this order
        items_response = supabase.table('order_items').select('product_name, product_id').eq('order_id', order_id).execute()
        
        product_names = []
        product_images = []
        
        for item in items_response.data:
            product_names.append(item['product_name'])
            
            # Get product image
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
        
        # Get current Philippine time for created_at
        ph_time = (datetime.utcnow() + timedelta(hours=8)).strftime('%Y-%m-%d %H:%M:%S')
        
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
            'formatted_date': formatted_date,
            'created_at': ph_time
        }
        
        supabase.table('notifications').insert(notification_data).execute()
        
        print(f"✅ Created notification: {title} for order #{order_number}")
        return True
        
    except Exception as e:
        print(f"❌ Error creating notification: {e}")
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
    print(f"🔔 Creating stock notification for product_id={product_id}, status={stock_status}")
    supabase = get_supabase_client()
    
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
        
        # Get current Philippine time for created_at
        ph_time = (datetime.utcnow() + timedelta(hours=8)).strftime('%Y-%m-%d %H:%M:%S')
        
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
            'created_at': ph_time,
            'updated_at': ph_time
        }
        
        supabase.table('notifications').insert(notification_data).execute()
        
        print(f"✅ Created stock notification: {title} for {product_name}")
        return True
        
    except Exception as e:
        print(f"❌ Error creating stock notification: {e}")
        return False

def create_report_notification(reported_user_id, reported_user_type, report_category):
    """
    Create a notification when a user is reported
    reported_user_type: 'buyer', 'seller', or 'rider'
    report_category: category of the report
    """
    print(f"🔔 Creating report notification for user_id={reported_user_id}, type={reported_user_type}")
    supabase = get_supabase_client()
    
    try:
        # Count total reports for this user
        report_response = supabase.table('user_reports').select('report_id', count='exact').eq('reported_user_id', reported_user_id).eq('reported_user_type', reported_user_type).execute()
        
        report_count = report_response.count
        
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
        
        # Get current Philippine time for created_at
        ph_time = (datetime.utcnow() + timedelta(hours=8)).strftime('%Y-%m-%d %H:%M:%S')
        
        # Insert notification
        notification_data = {
            'user_id': reported_user_id,
            'title': title,
            'message': message,
            'notification_type': 'warning',
            'is_read': False,
            'formatted_date': formatted_date,
            'created_at': ph_time
        }
        
        supabase.table('notifications').insert(notification_data).execute()
        
        print(f"✅ Created report notification for user {reported_user_id} ({reported_user_type})")
        return True
        
    except Exception as e:
        print(f"❌ Error creating report notification: {e}")
        return False

def create_suspension_notification(user_id, action, duration_text, reason):
    """
    Create a notification when a user is suspended or banned
    action: 'suspend' or 'ban'
    duration_text: e.g., '2 weeks', '1 month', 'permanently'
    reason: reason for suspension/ban
    """
    print(f"🔔 Creating suspension notification for user_id={user_id}, action={action}")
    supabase = get_supabase_client()
    
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
        
        # Get current Philippine time for created_at
        ph_time = (datetime.utcnow() + timedelta(hours=8)).strftime('%Y-%m-%d %H:%M:%S')
        
        # Insert notification
        notification_data = {
            'user_id': user_id,
            'title': title,
            'message': message,
            'notification_type': 'warning',
            'is_read': False,
            'formatted_date': formatted_date,
            'created_at': ph_time
        }
        
        supabase.table('notifications').insert(notification_data).execute()
        
        print(f"✅ Created suspension notification for user {user_id} ({action}ed for {duration_text})")
        return True
        
    except Exception as e:
        print(f"❌ Error creating suspension notification: {e}")
        return False

def create_sample_notifications(user_id):
    """Create sample notifications for testing"""
    print(f"🔔 Creating sample notifications for user_id={user_id}")
    supabase = get_supabase_client()
    
    try:
        formatted_date = datetime.now().strftime('%B %d, %Y at %I:%M %p')
        ph_time = (datetime.utcnow() + timedelta(hours=8)).strftime('%Y-%m-%d %H:%M:%S')
        
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
                'formatted_date': formatted_date,
                'created_at': ph_time
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
                'formatted_date': formatted_date,
                'created_at': ph_time
            },
            {
                'user_id': user_id,
                'title': 'New Product Alert',
                'message': 'Check out our new collection of winter dresses!',
                'notification_type': 'product',
                'is_read': False,
                'formatted_date': formatted_date,
                'created_at': ph_time
            },
            {
                'user_id': user_id,
                'title': 'Message from Seller',
                'message': 'Thank you for your purchase! We hope you love your items.',
                'notification_type': 'message',
                'is_read': False,
                'formatted_date': formatted_date,
                'created_at': ph_time
            }
        ]
        
        for notification in notifications:
            supabase.table('notifications').insert(notification).execute()
        
        print(f"✅ Created {len(notifications)} sample notifications for user {user_id}")
        return True
        
    except Exception as e:
        print(f"❌ Error creating sample notifications: {e}")
        return False


def create_device_login_notification(user_id, device_info, login_time):
    """
    Create a notification when user logs in from a new device
    For sellers & riders: Send email notification only
    For buyers: Send both in-app notification AND email notification
    device_info: e.g., "Chrome on Windows"
    login_time: datetime object
    """
    print(f"🔔 Creating device login notification for user_id={user_id}, device={device_info}")
    supabase = get_supabase_client()
    
    try:
        # Get user details to check user type
        user_response = supabase.table('users').select('user_type, email').eq('user_id', user_id).execute()
        
        if not user_response.data:
            print(f"❌ User not found")
            return False
        
        user_type = user_response.data[0]['user_type']
        user_email = user_response.data[0]['email']
        
        # Format login time
        formatted_time = login_time.strftime('%B %d, %Y at %I:%M %p')
        
        # Create notification message
        title = '🔐 New Device Login Detected'
        message = f'Your account was accessed from a new device: {device_info} at {formatted_time}. If this wasn\'t you, please change your password immediately.'
        
        # For sellers and riders, send email notification only
        if user_type in ['seller', 'rider']:
            print(f"📧 Sending email notification to {user_type}: {user_email}")
            send_device_login_email(user_email, device_info, formatted_time, user_type)
            return True
        
        # For buyers, create BOTH in-app notification AND email notification
        if user_type == 'buyer':
            # Create in-app notification
            notification_data = {
                'user_id': user_id,
                'title': title,
                'message': message,
                'notification_type': 'security',
                'is_read': False,
                'formatted_date': formatted_time,
                'created_at': (datetime.utcnow() + timedelta(hours=8)).strftime('%Y-%m-%d %H:%M:%S')
            }
            
            supabase.table('notifications').insert(notification_data).execute()
            print(f"✅ Created in-app notification for buyer {user_id}")
            
            # Also send email notification
            print(f"📧 Sending email notification to buyer: {user_email}")
            send_device_login_email(user_email, device_info, formatted_time, user_type)
            
            return True
        
        return False
        
    except Exception as e:
        print(f"❌ Error creating device login notification: {e}")
        return False


def send_device_login_email(recipient_email, device_info, login_time, user_type='seller'):
    """Send new device login notification email to seller or rider"""
    import smtplib
    from email.mime.text import MIMEText
    from email.mime.multipart import MIMEMultipart
    
    try:
        sender_email = 'parokyanigahi21@gmail.com'
        sender_password = 'ahzyzotndedbxeco'
        
        print(f"📧 Sending device login email to: {recipient_email}")
        
        # Customize message based on user type
        account_type = "seller" if user_type == "seller" else "rider"
        account_label = "Seller" if user_type == "seller" else "Rider"
        
        # Create message
        msg = MIMEMultipart('alternative')
        msg['Subject'] = '🔐 New Device Login Detected - Velare'
        msg['From'] = sender_email
        msg['To'] = recipient_email
        
        # Plain text version
        text_content = f'''
New Device Login Detected

Hello,

Your Velare {account_type} account was accessed from a new device:

Device: {device_info}
Time: {login_time}

If this was you, you can safely ignore this email.

If this wasn't you, please:
1. Change your password immediately
2. Review your account security settings
3. Contact support if you notice any suspicious activity

Stay safe,
Velare Team
        '''
        
        # HTML version
        html_content = f'''
<!DOCTYPE html>
<html>
<head>
    <style>
        body {{
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }}
        .header {{
            background: linear-gradient(135deg, #D3BD9B 0%, #695B44 100%);
            color: white;
            padding: 30px;
            text-align: center;
            border-radius: 10px 10px 0 0;
        }}
        .content {{
            background: #f9f9f9;
            padding: 30px;
            border: 1px solid #ddd;
            border-top: none;
        }}
        .alert-box {{
            background: #fff3cd;
            border-left: 4px solid #ffc107;
            padding: 15px;
            margin: 20px 0;
        }}
        .device-info {{
            background: white;
            padding: 15px;
            border-radius: 5px;
            margin: 15px 0;
        }}
        .action-steps {{
            background: white;
            padding: 20px;
            border-radius: 5px;
            margin: 15px 0;
        }}
        .action-steps ol {{
            margin: 10px 0;
            padding-left: 20px;
        }}
        .action-steps li {{
            margin: 8px 0;
        }}
        .footer {{
            text-align: center;
            padding: 20px;
            color: #666;
            font-size: 12px;
        }}
    </style>
</head>
<body>
    <div class="header">
        <h1>🔐 New Device Login Detected</h1>
    </div>
    <div class="content">
        <div class="alert-box">
            <strong>⚠️ Security Alert</strong><br>
            Your Velare {account_type} account was accessed from a new device.
        </div>
        
        <div class="device-info">
            <strong>Login Details:</strong><br>
            <strong>Device:</strong> {device_info}<br>
            <strong>Time:</strong> {login_time}
        </div>
        
        <p><strong>Was this you?</strong></p>
        <p>If you just logged in from this device, you can safely ignore this email.</p>
        
        <div class="action-steps">
            <p><strong>If this wasn't you, please take action immediately:</strong></p>
            <ol>
                <li>Change your password right away</li>
                <li>Review your account security settings</li>
                <li>Check your recent account activity</li>
                <li>Contact our support team if you notice anything suspicious</li>
            </ol>
        </div>
        
        <p style="margin-top: 20px;">
            <strong>Stay safe and secure!</strong><br>
            The Velare Team
        </p>
    </div>
    <div class="footer">
        <p>This is an automated security notification from Velare.</p>
        <p>© 2024 Velare. All rights reserved.</p>
    </div>
</body>
</html>
        '''
        
        # Attach both versions
        text_part = MIMEText(text_content, 'plain')
        html_part = MIMEText(html_content, 'html')
        msg.attach(text_part)
        msg.attach(html_part)
        
        # Send email
        server = smtplib.SMTP('smtp.gmail.com', 587, timeout=10)
        server.starttls()
        server.login(sender_email, sender_password)
        server.send_message(msg)
        server.quit()
        
        print(f"✅ Device login email sent successfully to {recipient_email}")
        return True
        
    except Exception as e:
        print(f"❌ Error sending device login email: {e}")
        return False

