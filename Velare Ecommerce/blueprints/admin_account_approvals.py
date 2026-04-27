from flask import Blueprint, render_template, jsonify, request
import sys
import os
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_config import get_db_connection, close_db_connection

admin_account_approvals_bp = Blueprint('admin_account_approvals', __name__)

def send_account_status_email(recipient_email, first_name, last_name, user_type, status):
    """Send account approval or rejection email using Gmail SMTP"""
    try:
        sender_email = 'parokyanigahi21@gmail.com'
        sender_password = 'ahzyzotndedbxeco'
        
        print(f"Sending {status} email to: {recipient_email}")
        
        # Create message
        msg = MIMEMultipart('alternative')
        
        if status == 'approved':
            msg['Subject'] = 'Welcome to Velare - Your Account Has Been Approved!'
            
            html_content = f'''
            <html>
                <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
                    <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                        <div style="text-align: center; margin-bottom: 30px;">
                            <h1 style="color: #10B981; margin: 0;">🎉 Welcome to Velare!</h1>
                        </div>
                        
                        <p>Dear {first_name} {last_name},</p>
                        
                        <p>Great news! Your <strong>{user_type}</strong> account has been <strong style="color: #10B981;">approved</strong> by our team.</p>
                        
                        <div style="background-color: #D1FAE5; padding: 20px; border-left: 4px solid #10B981; margin: 20px 0; border-radius: 5px;">
                            <p style="margin: 0; color: #065F46;"><strong>Your account is now active!</strong></p>
                            <p style="margin: 10px 0 0 0; color: #065F46;">You can now log in and start using all the features available to you.</p>
                        </div>
                        
                        <p>What's next?</p>
                        <ul style="line-height: 1.8;">
                            <li>Log in to your account at <a href="#" style="color: #10B981;">Velare Ecommerce</a></li>
                            <li>Complete your profile information</li>
                            <li>{'Start listing your products' if user_type == 'seller' else 'Start browsing products' if user_type == 'buyer' else 'Start accepting delivery orders'}</li>
                        </ul>
                        
                        <p>If you have any questions, feel free to reach out to our support team.</p>
                        
                        <p>Thank you for choosing Velare!</p>
                        
                        <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 20px 0;">
                        <p style="color: #718096; font-size: 12px;">This is an automated message from Velare Ecommerce.</p>
                    </div>
                </body>
            </html>
            '''
            
            text_content = f'''
            Welcome to Velare!
            
            Dear {first_name} {last_name},
            
            Great news! Your {user_type} account has been approved by our team.
            
            Your account is now active! You can now log in and start using all the features available to you.
            
            Thank you for choosing Velare!
            '''
            
        else:  # rejected
            msg['Subject'] = 'Velare - Account Application Update'
            
            html_content = f'''
            <html>
                <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
                    <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                        <h2 style="color: #4A5568;">Account Application Update</h2>
                        
                        <p>Dear {first_name} {last_name},</p>
                        
                        <p>Thank you for your interest in joining Velare as a <strong>{user_type}</strong>.</p>
                        
                        <div style="background-color: #FEF2F2; padding: 20px; border-left: 4px solid #EF4444; margin: 20px 0; border-radius: 5px;">
                            <p style="margin: 0; color: #991B1B;">Unfortunately, we are unable to approve your account application at this time.</p>
                        </div>
                        
                        <p>This may be due to:</p>
                        <ul style="line-height: 1.8;">
                            <li>Incomplete or unclear identification documents</li>
                            <li>Information that doesn't meet our verification requirements</li>
                            <li>Other verification issues</li>
                        </ul>
                        
                        <p>If you believe this was a mistake or would like to reapply with updated information, please contact our support team.</p>
                        
                        <p>Thank you for your understanding.</p>
                        
                        <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 20px 0;">
                        <p style="color: #718096; font-size: 12px;">This is an automated message from Velare Ecommerce.</p>
                    </div>
                </body>
            </html>
            '''
            
            text_content = f'''
            Account Application Update
            
            Dear {first_name} {last_name},
            
            Thank you for your interest in joining Velare as a {user_type}.
            
            Unfortunately, we are unable to approve your account application at this time.
            
            If you believe this was a mistake or would like to reapply with updated information, please contact our support team.
            
            Thank you for your understanding.
            '''
        
        msg['From'] = sender_email
        msg['To'] = recipient_email
        
        # Attach both plain text and HTML
        text_part = MIMEText(text_content, 'plain')
        html_part = MIMEText(html_content, 'html')
        msg.attach(text_part)
        msg.attach(html_part)
        
        # Send email using SMTP
        server = smtplib.SMTP('smtp.gmail.com', 587, timeout=10)
        server.starttls()
        server.login(sender_email, sender_password)
        server.send_message(msg)
        server.quit()
        
        print(f"✅ {status.capitalize()} email sent successfully to {recipient_email}")
        return True
        
    except smtplib.SMTPException as e:
        print(f"❌ SMTP Error sending {status} email: {str(e)}")
        return False
    except Exception as e:
        print(f"❌ Error sending {status} email: {str(e)}")
        return False

@admin_account_approvals_bp.route('/admin/account-approvals')
def admin_account_approvals():
    return render_template('admin/admin_account_approvals.html')

@admin_account_approvals_bp.route('/api/admin/accounts/pending', methods=['GET'])
def get_pending_accounts():
    """Fetch all accounts pending approval (buyers, sellers and riders)"""
    try:
        # Get optional filters from query parameters
        user_type = request.args.get('user_type', 'all')  # 'all', 'buyer', 'seller', 'rider'
        status_filter = request.args.get('status', 'pending')  # 'pending', 'rejected', 'suspended', 'banned', 'all'
        search_query = request.args.get('search', '')
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            accounts = []
            
            # Fetch pending buyers
            if user_type in ['all', 'buyer']:
                buyer_query = """
                    SELECT 
                        b.buyer_id as account_id,
                        'buyer' as user_type,
                        b.first_name,
                        b.last_name,
                        NULL as shop_name,
                        b.id_type,
                        b.id_file_path,
                        b.profile_image as shop_logo,
                        u.email,
                        u.status,
                        u.created_at,
                        a.phone_number,
                        a.full_address,
                        a.region,
                        a.province,
                        a.city,
                        a.barangay,
                        a.street_name,
                        a.house_number,
                        a.postal_code
                    FROM buyers b
                    JOIN users u ON b.user_id = u.user_id
                    LEFT JOIN addresses a ON a.user_type = 'buyer' AND a.user_ref_id = b.buyer_id
                    WHERE 1=1
                """
                params = []
                
                # Add status filter
                if status_filter == 'pending':
                    buyer_query += " AND u.status = 'pending'"
                elif status_filter == 'rejected':
                    buyer_query += " AND u.status = 'rejected'"
                elif status_filter == 'suspended':
                    buyer_query += " AND u.status = 'suspended'"
                elif status_filter == 'banned':
                    buyer_query += " AND u.status = 'banned'"
                # 'all' shows all statuses except active
                elif status_filter == 'all':
                    buyer_query += " AND u.status IN ('pending', 'rejected', 'suspended', 'banned')"
                
                if search_query:
                    buyer_query += " AND (b.first_name LIKE %s OR b.last_name LIKE %s OR u.email LIKE %s)"
                    search_param = f"%{search_query}%"
                    params.extend([search_param, search_param, search_param])
                
                buyer_query += " ORDER BY u.created_at DESC"
                cursor.execute(buyer_query, params)
                buyers = cursor.fetchall()
                accounts.extend(buyers)
            
            # Fetch pending sellers
            if user_type in ['all', 'seller']:
                seller_query = """
                    SELECT 
                        s.seller_id as account_id,
                        'seller' as user_type,
                        s.first_name,
                        s.last_name,
                        s.shop_name,
                        s.id_type,
                        s.id_file_path,
                        s.shop_logo,
                        u.email,
                        u.status,
                        u.created_at,
                        a.phone_number,
                        a.full_address,
                        a.region,
                        a.province,
                        a.city,
                        a.barangay,
                        a.street_name,
                        a.house_number,
                        a.postal_code
                    FROM sellers s
                    JOIN users u ON s.user_id = u.user_id
                    LEFT JOIN addresses a ON a.user_type = 'seller' AND a.user_ref_id = s.seller_id
                    WHERE 1=1
                """
                params = []
                
                # Add status filter
                if status_filter == 'pending':
                    seller_query += " AND u.status = 'pending'"
                elif status_filter == 'rejected':
                    seller_query += " AND u.status = 'rejected'"
                elif status_filter == 'suspended':
                    seller_query += " AND u.status = 'suspended'"
                elif status_filter == 'banned':
                    seller_query += " AND u.status = 'banned'"
                elif status_filter == 'all':
                    seller_query += " AND u.status IN ('pending', 'rejected', 'suspended', 'banned')"
                
                if search_query:
                    seller_query += " AND (s.first_name LIKE %s OR s.last_name LIKE %s OR s.shop_name LIKE %s OR u.email LIKE %s)"
                    search_param = f"%{search_query}%"
                    params.extend([search_param, search_param, search_param, search_param])
                
                seller_query += " ORDER BY u.created_at DESC"
                cursor.execute(seller_query, params)
                sellers = cursor.fetchall()
                accounts.extend(sellers)
            
            # Fetch pending riders
            if user_type in ['all', 'rider']:
                rider_query = """
                    SELECT 
                        r.rider_id as account_id,
                        'rider' as user_type,
                        r.first_name,
                        r.last_name,
                        NULL as shop_name,
                        r.id_type,
                        r.id_file_path,
                        r.profile_image as shop_logo,
                        u.email,
                        u.status,
                        u.created_at,
                        a.phone_number,
                        a.full_address,
                        a.region,
                        a.province,
                        a.city,
                        a.barangay,
                        a.street_name,
                        a.house_number,
                        a.postal_code
                    FROM riders r
                    JOIN users u ON r.user_id = u.user_id
                    LEFT JOIN addresses a ON a.user_type = 'rider' AND a.user_ref_id = r.rider_id
                    WHERE 1=1
                """
                params = []
                
                # Add status filter
                if status_filter == 'pending':
                    rider_query += " AND u.status = 'pending'"
                elif status_filter == 'rejected':
                    rider_query += " AND u.status = 'rejected'"
                elif status_filter == 'suspended':
                    rider_query += " AND u.status = 'suspended'"
                elif status_filter == 'banned':
                    rider_query += " AND u.status = 'banned'"
                elif status_filter == 'all':
                    rider_query += " AND u.status IN ('pending', 'rejected', 'suspended', 'banned')"
                
                if search_query:
                    rider_query += " AND (r.first_name LIKE %s OR r.last_name LIKE %s OR u.email LIKE %s)"
                    search_param = f"%{search_query}%"
                    params.extend([search_param, search_param, search_param])
                
                rider_query += " ORDER BY u.created_at DESC"
                cursor.execute(rider_query, params)
                riders = cursor.fetchall()
                accounts.extend(riders)
            
            # Count accounts by status
            count_query = """
                SELECT 
                    (SELECT COUNT(*) FROM users WHERE user_type = 'buyer' AND status = 'pending') as buyer_pending,
                    (SELECT COUNT(*) FROM users WHERE user_type = 'seller' AND status = 'pending') as seller_pending,
                    (SELECT COUNT(*) FROM users WHERE user_type = 'rider' AND status = 'pending') as rider_pending,
                    (SELECT COUNT(*) FROM users WHERE user_type = 'buyer' AND status = 'rejected') as buyer_rejected,
                    (SELECT COUNT(*) FROM users WHERE user_type = 'seller' AND status = 'rejected') as seller_rejected,
                    (SELECT COUNT(*) FROM users WHERE user_type = 'rider' AND status = 'rejected') as rider_rejected,
                    (SELECT COUNT(*) FROM users WHERE user_type = 'buyer' AND status = 'suspended') as buyer_suspended,
                    (SELECT COUNT(*) FROM users WHERE user_type = 'seller' AND status = 'suspended') as seller_suspended,
                    (SELECT COUNT(*) FROM users WHERE user_type = 'rider' AND status = 'suspended') as rider_suspended,
                    (SELECT COUNT(*) FROM users WHERE user_type = 'buyer' AND status = 'banned') as buyer_banned,
                    (SELECT COUNT(*) FROM users WHERE user_type = 'seller' AND status = 'banned') as seller_banned,
                    (SELECT COUNT(*) FROM users WHERE user_type = 'rider' AND status = 'banned') as rider_banned
            """
            cursor.execute(count_query)
            counts = cursor.fetchone()
            
            return jsonify({
                'success': True,
                'accounts': accounts,
                'pending_buyer_count': counts['buyer_pending'],
                'pending_seller_count': counts['seller_pending'],
                'pending_rider_count': counts['rider_pending'],
                'rejected_buyer_count': counts['buyer_rejected'],
                'rejected_seller_count': counts['seller_rejected'],
                'rejected_rider_count': counts['rider_rejected'],
                'suspended_buyer_count': counts['buyer_suspended'],
                'suspended_seller_count': counts['seller_suspended'],
                'suspended_rider_count': counts['rider_suspended'],
                'banned_buyer_count': counts['buyer_banned'],
                'banned_seller_count': counts['seller_banned'],
                'banned_rider_count': counts['rider_banned'],
                'total_pending': counts['buyer_pending'] + counts['seller_pending'] + counts['rider_pending'],
                'total_rejected': counts['buyer_rejected'] + counts['seller_rejected'] + counts['rider_rejected'],
                'total_suspended': counts['buyer_suspended'] + counts['seller_suspended'] + counts['rider_suspended'],
                'total_banned': counts['buyer_banned'] + counts['seller_banned'] + counts['rider_banned']
            }), 200
            
        except Exception as db_error:
            print(f"Database error: {str(db_error)}")
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
        finally:
            close_db_connection(connection, cursor)
        
    except Exception as e:
        print(f"Error fetching pending accounts: {str(e)}")
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@admin_account_approvals_bp.route('/api/admin/accounts/<user_type>/<int:account_id>/approve', methods=['POST'])
def approve_account(user_type, account_id):
    """Approve a buyer, seller or rider account"""
    try:
        if user_type not in ['buyer', 'seller', 'rider']:
            return jsonify({'success': False, 'message': 'Invalid user type'}), 400
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            # Get user_id and email based on account type
            if user_type == 'buyer':
                cursor.execute("""
                    SELECT b.user_id, b.first_name, b.last_name, u.email 
                    FROM buyers b 
                    JOIN users u ON b.user_id = u.user_id 
                    WHERE b.buyer_id = %s
                """, (account_id,))
            elif user_type == 'seller':
                cursor.execute("""
                    SELECT s.user_id, s.first_name, s.last_name, u.email 
                    FROM sellers s 
                    JOIN users u ON s.user_id = u.user_id 
                    WHERE s.seller_id = %s
                """, (account_id,))
            else:
                cursor.execute("""
                    SELECT r.user_id, r.first_name, r.last_name, u.email 
                    FROM riders r 
                    JOIN users u ON r.user_id = u.user_id 
                    WHERE r.rider_id = %s
                """, (account_id,))
            
            account = cursor.fetchone()
            
            if not account:
                return jsonify({'success': False, 'message': f'{user_type.capitalize()} not found'}), 404
            
            # Update user status to active
            update_query = "UPDATE users SET status = 'active' WHERE user_id = %s"
            cursor.execute(update_query, (account['user_id'],))
            connection.commit()
            
            print(f"{user_type.capitalize()} {account_id} approved: {account['first_name']} {account['last_name']}")
            
            # Send approval email
            send_account_status_email(
                account['email'],
                account['first_name'],
                account['last_name'],
                user_type,
                'approved'
            )
            
            return jsonify({
                'success': True,
                'message': f'{user_type.capitalize()} account approved successfully',
                'account_id': account_id
            }), 200
            
        except Exception as db_error:
            connection.rollback()
            print(f"Database error: {str(db_error)}")
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
        finally:
            close_db_connection(connection, cursor)
        
    except Exception as e:
        print(f"Error approving account: {str(e)}")
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@admin_account_approvals_bp.route('/api/admin/accounts/<user_type>/<int:account_id>/reject', methods=['POST'])
def reject_account(user_type, account_id):
    """Reject a buyer, seller or rider account"""
    try:
        if user_type not in ['buyer', 'seller', 'rider']:
            return jsonify({'success': False, 'message': 'Invalid user type'}), 400
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            # Get user_id and email based on account type
            if user_type == 'buyer':
                cursor.execute("""
                    SELECT b.user_id, b.first_name, b.last_name, u.email 
                    FROM buyers b 
                    JOIN users u ON b.user_id = u.user_id 
                    WHERE b.buyer_id = %s
                """, (account_id,))
            elif user_type == 'seller':
                cursor.execute("""
                    SELECT s.user_id, s.first_name, s.last_name, u.email 
                    FROM sellers s 
                    JOIN users u ON s.user_id = u.user_id 
                    WHERE s.seller_id = %s
                """, (account_id,))
            else:
                cursor.execute("""
                    SELECT r.user_id, r.first_name, r.last_name, u.email 
                    FROM riders r 
                    JOIN users u ON r.user_id = u.user_id 
                    WHERE r.rider_id = %s
                """, (account_id,))
            
            account = cursor.fetchone()
            
            if not account:
                return jsonify({'success': False, 'message': f'{user_type.capitalize()} not found'}), 404
            
            # Update user status to rejected
            update_query = "UPDATE users SET status = 'rejected' WHERE user_id = %s"
            cursor.execute(update_query, (account['user_id'],))
            connection.commit()
            
            print(f"{user_type.capitalize()} {account_id} rejected: {account['first_name']} {account['last_name']}")
            
            # Send rejection email
            send_account_status_email(
                account['email'],
                account['first_name'],
                account['last_name'],
                user_type,
                'rejected'
            )
            
            return jsonify({
                'success': True,
                'message': f'{user_type.capitalize()} account rejected',
                'account_id': account_id
            }), 200
            
        except Exception as db_error:
            connection.rollback()
            print(f"Database error: {str(db_error)}")
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
        finally:
            close_db_connection(connection, cursor)
        
    except Exception as e:
        print(f"Error rejecting account: {str(e)}")
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500
