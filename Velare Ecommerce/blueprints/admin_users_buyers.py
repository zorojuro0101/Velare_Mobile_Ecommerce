from flask import Blueprint, render_template, jsonify, request
import sys
import os
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_config import get_db_connection, close_db_connection

admin_users_buyers_bp = Blueprint('admin_users_buyers', __name__)

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
                            <li>Start browsing and shopping for products</li>
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

@admin_users_buyers_bp.route('/admin/users/buyers')
def admin_users_buyers():
    return render_template('admin/admin_users_buyers.html')

@admin_users_buyers_bp.route('/api/admin/buyers', methods=['GET'])
def get_buyers():
    """Fetch all buyers with filtering"""
    try:
        # Get optional filters from query parameters
        status_filter = request.args.get('status', 'all')  # 'pending', 'active', 'rejected', 'suspended', 'banned', 'all'
        search_query = request.args.get('search', '')
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            buyer_query = """
                SELECT 
                    b.buyer_id as account_id,
                    b.user_id,
                    'buyer' as user_type,
                    b.first_name,
                    b.last_name,
                    b.id_type,
                    b.id_file_path,
                    b.profile_image,
                    b.report_count,
                    u.email,
                    u.status,
                    u.created_at
                FROM buyers b
                JOIN users u ON b.user_id = u.user_id
                WHERE 1=1
            """
            params = []
            
            # Add status filter
            if status_filter != 'all':
                buyer_query += " AND u.status = %s"
                params.append(status_filter)
            
            if search_query:
                buyer_query += " AND (b.first_name LIKE %s OR b.last_name LIKE %s OR u.email LIKE %s)"
                search_param = f"%{search_query}%"
                params.extend([search_param, search_param, search_param])
            
            buyer_query += " ORDER BY u.created_at DESC"
            cursor.execute(buyer_query, params)
            buyers = cursor.fetchall()
            
            # Fetch addresses for each buyer
            for buyer in buyers:
                address_query = """
                    SELECT 
                        address_id,
                        phone_number,
                        full_address,
                        region,
                        province,
                        city,
                        barangay,
                        street_name,
                        house_number,
                        postal_code,
                        is_default
                    FROM addresses
                    WHERE user_type = 'buyer' AND user_ref_id = %s
                    ORDER BY is_default DESC, address_id ASC
                """
                cursor.execute(address_query, (buyer['account_id'],))
                addresses = cursor.fetchall()
                buyer['addresses'] = addresses if addresses else []
            
            # Count by status
            count_query = """
                SELECT 
                    (SELECT COUNT(*) FROM users WHERE user_type = 'buyer' AND status = 'pending') as pending_count,
                    (SELECT COUNT(*) FROM users WHERE user_type = 'buyer' AND status = 'active') as active_count,
                    (SELECT COUNT(*) FROM users WHERE user_type = 'buyer' AND status = 'rejected') as rejected_count,
                    (SELECT COUNT(*) FROM users WHERE user_type = 'buyer' AND status = 'suspended') as suspended_count,
                    (SELECT COUNT(*) FROM users WHERE user_type = 'buyer' AND status = 'banned') as banned_count
            """
            cursor.execute(count_query)
            counts = cursor.fetchone()
            
            return jsonify({
                'success': True,
                'buyers': buyers,
                'counts': counts
            }), 200
            
        except Exception as db_error:
            print(f"Database error: {str(db_error)}")
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
        finally:
            close_db_connection(connection, cursor)
        
    except Exception as e:
        print(f"Error fetching buyers: {str(e)}")
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@admin_users_buyers_bp.route('/api/admin/buyers/<int:buyer_id>/approve', methods=['POST'])
def approve_buyer(buyer_id):
    """Approve a buyer account"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            # Get buyer info with email
            cursor.execute("""
                SELECT b.user_id, b.first_name, b.last_name, u.email 
                FROM buyers b 
                JOIN users u ON b.user_id = u.user_id 
                WHERE b.buyer_id = %s
            """, (buyer_id,))
            buyer = cursor.fetchone()
            
            if not buyer:
                return jsonify({'success': False, 'message': 'Buyer not found'}), 404
            
            # Update user status to active
            cursor.execute("UPDATE users SET status = 'active' WHERE user_id = %s", (buyer['user_id'],))
            
            # Clear suspension data when activating
            cursor.execute("""
                UPDATE buyers 
                SET account_status = 'active', 
                    suspension_end = NULL, 
                    suspension_reason = NULL
                WHERE buyer_id = %s
            """, (buyer_id,))
            
            # Assign welcome vouchers to newly approved buyer
            cursor.execute("""
                INSERT IGNORE INTO buyer_vouchers (buyer_id, voucher_id, is_used)
                SELECT %s, voucher_id, FALSE
                FROM vouchers
                WHERE voucher_code IN ('FREESHIP', 'DISCOUNT20')
            """, (buyer_id,))
            
            connection.commit()
            
            print(f"Buyer {buyer_id} approved: {buyer['first_name']} {buyer['last_name']}")
            
            # Send approval email
            send_account_status_email(
                buyer['email'],
                buyer['first_name'],
                buyer['last_name'],
                'buyer',
                'approved'
            )
            
            return jsonify({
                'success': True,
                'message': 'Buyer account approved successfully'
            }), 200
            
        except Exception as db_error:
            connection.rollback()
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
        finally:
            close_db_connection(connection, cursor)
        
    except Exception as e:
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@admin_users_buyers_bp.route('/api/admin/buyers/<int:buyer_id>/reject', methods=['POST'])
def reject_buyer(buyer_id):
    """Reject a buyer account"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            # Get buyer info with email
            cursor.execute("""
                SELECT b.user_id, b.first_name, b.last_name, u.email 
                FROM buyers b 
                JOIN users u ON b.user_id = u.user_id 
                WHERE b.buyer_id = %s
            """, (buyer_id,))
            buyer = cursor.fetchone()
            
            if not buyer:
                return jsonify({'success': False, 'message': 'Buyer not found'}), 404
            
            cursor.execute("UPDATE users SET status = 'rejected' WHERE user_id = %s", (buyer['user_id'],))
            connection.commit()
            
            print(f"Buyer {buyer_id} rejected: {buyer['first_name']} {buyer['last_name']}")
            
            # Send rejection email
            send_account_status_email(
                buyer['email'],
                buyer['first_name'],
                buyer['last_name'],
                'buyer',
                'rejected'
            )
            
            return jsonify({
                'success': True,
                'message': 'Buyer account rejected'
            }), 200
            
        except Exception as db_error:
            connection.rollback()
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
        finally:
            close_db_connection(connection, cursor)
        
    except Exception as e:
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@admin_users_buyers_bp.route('/api/admin/buyers/<int:buyer_id>/suspend', methods=['POST'])
def suspend_buyer(buyer_id):
    """Suspend a buyer account"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            cursor.execute("SELECT user_id FROM buyers WHERE buyer_id = %s", (buyer_id,))
            buyer = cursor.fetchone()
            
            if not buyer:
                return jsonify({'success': False, 'message': 'Buyer not found'}), 404
            
            cursor.execute("UPDATE users SET status = 'suspended' WHERE user_id = %s", (buyer['user_id'],))
            connection.commit()
            
            return jsonify({'success': True, 'message': 'Buyer account suspended'}), 200
            
        except Exception as db_error:
            connection.rollback()
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
        finally:
            close_db_connection(connection, cursor)
        
    except Exception as e:
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@admin_users_buyers_bp.route('/api/admin/buyers/<int:buyer_id>/ban', methods=['POST'])
def ban_buyer(buyer_id):
    """Ban a buyer account"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            cursor.execute("SELECT user_id FROM buyers WHERE buyer_id = %s", (buyer_id,))
            buyer = cursor.fetchone()
            
            if not buyer:
                return jsonify({'success': False, 'message': 'Buyer not found'}), 404
            
            cursor.execute("UPDATE users SET status = 'banned' WHERE user_id = %s", (buyer['user_id'],))
            connection.commit()
            
            return jsonify({'success': True, 'message': 'Buyer account banned'}), 200
            
        except Exception as db_error:
            connection.rollback()
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
        finally:
            close_db_connection(connection, cursor)
        
    except Exception as e:
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500
