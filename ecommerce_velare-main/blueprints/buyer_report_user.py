from flask import Blueprint, render_template, request, redirect, url_for, flash, session, jsonify
from database.supabase_helper import (
    get_buyer_by_user_id,
    get_buyer_orders_with_sellers_riders,
    get_buyer_reports,
    get_seller_by_id,
    get_rider_by_id,
    insert_user_report,
    get_user_report_count,
    update_seller_report_count,
    update_rider_report_count,
    get_seller_user_details,
    get_rider_user_details
)
from werkzeug.utils import secure_filename
import os
from datetime import datetime
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

buyer_report_user_bp = Blueprint('buyer_report_user', __name__)

UPLOAD_FOLDER = 'static/uploads/reports'
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif'}

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def send_report_notification_email(recipient_email, first_name, last_name, user_type, category, report_count):
    """Send email notification to reported user"""
    try:
        sender_email = 'parokyanigahi21@gmail.com'
        sender_password = 'ahzyzotndedbxeco'
        
        print(f"Sending report notification email to: {recipient_email}")
        
        # Create message
        msg = MIMEMultipart('alternative')
        msg['Subject'] = f'Veláre - Report Notification'
        msg['From'] = sender_email
        msg['To'] = recipient_email
        
        # Category labels
        category_labels = {
            'fraud': 'Fraud/Scam',
            'fake_product': 'Fake/Counterfeit Product',
            'poor_service': 'Poor Service',
            'late_delivery': 'Late Delivery',
            'rude_behavior': 'Rude Behavior',
            'harassment': 'Harassment',
            'other': 'Other'
        }
        category_label = category_labels.get(category, category)
        
        # Warning message based on report count
        warning_message = ""
        if report_count >= 4:
            warning_message = "<p style='color: #8b0000; font-weight: 700; margin-top: 20px; padding: 15px; background: #ffe0e0; border-left: 4px solid #dc3545;'>🚫 <strong>ACCOUNT BANNED:</strong> You have received 4 or more reports. Your account has been automatically banned.</p>"
        elif report_count == 3:
            warning_message = "<p style='color: #dc3545; font-weight: 600; margin-top: 20px; padding: 15px; background: #fff0f0; border-left: 4px solid #dc3545;'>⚠️ <strong>FINAL WARNING - Suspension for 1 Month:</strong> This is your third report. Your account will be suspended for 1 month. One more report will result in permanent ban.</p>"
        elif report_count == 2:
            warning_message = "<p style='color: #ff6b6b; font-weight: 600; margin-top: 20px; padding: 15px; background: #fff5f5; border-left: 4px solid #ff6b6b;'>⚠️ <strong>WARNING - Suspension for 2 Weeks:</strong> This is your second report. Your account will be suspended for 2 weeks. Another report will result in 1-month suspension.</p>"
        elif report_count == 1:
            warning_message = "<p style='color: #ffa500; font-weight: 600; margin-top: 20px; padding: 15px; background: #fff8e1; border-left: 4px solid #ffa500;'>⚠️ <strong>First Warning - Suspension for 1 Week:</strong> This is your first report. Your account will be suspended for 1 week. Please review our community guidelines to avoid future reports.</p>"
        
        # HTML email content
        html = f'''
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body {{ font-family: 'Arial', sans-serif; line-height: 1.6; color: #333; }}
                .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
                .header {{ background: linear-gradient(135deg, #2c2236 0%, #4a3f5c 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }}
                .header h1 {{ margin: 0; font-size: 28px; font-weight: 300; letter-spacing: 2px; }}
                .content {{ background: #ffffff; padding: 30px; border: 1px solid #e0d7c6; border-top: none; border-radius: 0 0 10px 10px; }}
                .info-box {{ background: #f8f6f2; padding: 20px; border-left: 4px solid #bfa14a; margin: 20px 0; }}
                .footer {{ text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #e0d7c6; color: #666; font-size: 12px; }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>VELÁRE</h1>
                </div>
                <div class="content">
                    <h2 style="color: #2c2236; margin-top: 0;">Report Notification</h2>
                    <p>Dear {first_name} {last_name},</p>
                    <p>We are writing to inform you that your account has received a report from another user.</p>
                    
                    <div class="info-box">
                        <p style="margin: 0;"><strong>Report Category:</strong> {category_label}</p>
                        <p style="margin: 10px 0 0 0;"><strong>Total Reports Received:</strong> {report_count}</p>
                    </div>
                    
                    {warning_message}
                    
                    <p style="margin-top: 20px;">We take all reports seriously and review them carefully. Please ensure that you:</p>
                    <ul>
                        <li>Provide excellent service to all users</li>
                        <li>Communicate professionally and respectfully</li>
                        <li>Follow all Veláre community guidelines</li>
                        <li>Deliver products/services as described</li>
                    </ul>
                    
                    <p>If you believe this report was made in error, please contact our support team.</p>
                    
                    <p style="margin-top: 30px;">Best regards,<br><strong>The Veláre Team</strong></p>
                </div>
                <div class="footer">
                    <p>This is an automated message from Veláre. Please do not reply to this email.</p>
                    <p>&copy; 2024 Veláre. All rights reserved.</p>
                </div>
            </div>
        </body>
        </html>
        '''
        
        # Attach HTML
        html_part = MIMEText(html, 'html')
        msg.attach(html_part)
        
        # Send email using SMTP
        server = smtplib.SMTP('smtp.gmail.com', 587, timeout=10)
        server.starttls()
        server.login(sender_email, sender_password)
        server.send_message(msg)
        server.quit()
        
        print(f"✅ Report notification email sent successfully to {recipient_email}")
        return True
        
    except smtplib.SMTPException as e:
        print(f"❌ SMTP Error sending report notification email: {str(e)}")
        return False
    except Exception as e:
        print(f"❌ Error sending report notification email: {str(e)}")
        return False

@buyer_report_user_bp.route('/myAccount/reports', methods=['GET'])
def report_user_page():
    """📝 Display report user form and my reports (optimized)"""
    print("=" * 80)
    print("📝 [REPORT USER PAGE] Loading report user page...")
    print("=" * 80)
    
    if 'user_id' not in session or session.get('user_type') != 'buyer':
        flash('Please login as buyer to access this page', 'error')
        return redirect(url_for('auth.login'))
    
    # Get buyer info
    buyer = get_buyer_by_user_id(session['user_id'])
    
    if not buyer:
        flash('Buyer profile not found', 'error')
        return redirect(url_for('auth.login'))
    
    print(f"🔍 Fetching data for buyer_id={buyer['buyer_id']}")
    
    # Get recent orders with sellers and riders (limited to 50)
    orders = get_buyer_orders_with_sellers_riders(buyer['buyer_id'])
    print(f"📦 Found {len(orders)} orders")
    
    # Get buyer's reports (limited to 50)
    reports = get_buyer_reports(session['user_id'])
    print(f"📋 Found {len(reports)} reports")
    
    # Get seller_id from query parameter if provided (from view_item report button)
    seller_id = request.args.get('seller_id', type=int)
    
    print(f"✅ Report page loaded successfully")
    
    return render_template('accounts/myAccount_reports.html', 
                         buyer=buyer,
                         user_profile=buyer,
                         orders=orders,
                         reports=reports,
                         preselected_seller_id=seller_id)

@buyer_report_user_bp.route('/myAccount/submit-report', methods=['POST'])
def submit_report():
    """Submit a report"""
    if 'user_id' not in session or session.get('user_type') != 'buyer':
        return jsonify({'success': False, 'message': 'Unauthorized'}), 401
    
    try:
        # Get buyer_id
        buyer = get_buyer_by_user_id(session['user_id'])
        if not buyer:
            return jsonify({'success': False, 'message': 'Buyer profile not found'}), 404
        
        reported_type = request.form.get('reported_type')
        reported_id = request.form.get('reported_id')
        category = request.form.get('category')
        reason = request.form.get('reason')
        order_id = request.form.get('order_id') or None
        delivery_id = request.form.get('delivery_id') or None
        
        # Get reported user_id
        if reported_type == 'seller':
            reported_user = get_seller_by_id(reported_id)
        elif reported_type == 'rider':
            reported_user = get_rider_by_id(reported_id)
        else:
            return jsonify({'success': False, 'message': 'Invalid user type'}), 400
        
        if not reported_user:
            return jsonify({'success': False, 'message': 'User not found'}), 404
        
        # Handle file upload
        evidence_path = None
        if 'evidence' in request.files:
            file = request.files['evidence']
            if file and file.filename and allowed_file(file.filename):
                filename = secure_filename(f"report_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{file.filename}")
                os.makedirs(UPLOAD_FOLDER, exist_ok=True)
                file_path = os.path.join(UPLOAD_FOLDER, filename)
                file.save(file_path)
                evidence_path = file_path.replace('\\', '/')
        
        # Insert report
        insert_user_report(
            reporter_id=session['user_id'],
            reporter_type='buyer',
            reported_user_id=reported_user['user_id'],
            reported_user_type=reported_type,
            report_category=category,
            report_reason=reason,
            order_id=order_id,
            delivery_id=delivery_id,
            evidence_image=evidence_path
        )
        
        # Get report count for this user
        report_count = get_user_report_count(reported_user['user_id'])
        
        # Update report_count in the respective table
        if reported_type == 'seller':
            update_seller_report_count(reported_id, report_count)
        else:  # rider
            update_rider_report_count(reported_id, report_count)
        
        # Get reported user details and email
        if reported_type == 'seller':
            reported_user_details = get_seller_user_details(reported_id)
        else:  # rider
            reported_user_details = get_rider_user_details(reported_id)
        
        # Send notification to the reported user
        from blueprints.notification_helper import create_report_notification
        create_report_notification(reported_user['user_id'], reported_type, category)
        
        # Send email notification
        if reported_user_details:
            send_report_notification_email(
                reported_user_details['email'],
                reported_user_details['first_name'],
                reported_user_details['last_name'],
                reported_type,
                category,
                report_count
            )
        
        return jsonify({'success': True, 'message': 'Report submitted successfully'})
    
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500


