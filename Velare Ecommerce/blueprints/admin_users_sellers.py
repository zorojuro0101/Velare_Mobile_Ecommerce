from flask import Blueprint, render_template, jsonify, request
import sys
import os
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_config import get_db_connection, close_db_connection

admin_users_sellers_bp = Blueprint('admin_users_sellers', __name__)

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

@admin_users_sellers_bp.route('/admin/users/sellers')
def admin_users_sellers():
    return render_template('admin/admin_users_sellers.html')

@admin_users_sellers_bp.route('/api/admin/sellers', methods=['GET'])
def get_sellers():
    """Fetch all sellers with filtering"""
    try:
        # Get optional filters from query parameters
        status_filter = request.args.get('status', 'all')
        search_query = request.args.get('search', '')
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            seller_query = """
                SELECT 
                    s.seller_id as account_id,
                    s.user_id,
                    'seller' as user_type,
                    s.first_name,
                    s.last_name,
                    s.shop_name,
                    s.id_type,
                    s.id_file_path,
                    s.business_permit_file_path,
                    s.shop_logo,
                    s.report_count,
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
            if status_filter != 'all':
                seller_query += " AND u.status = %s"
                params.append(status_filter)
            
            if search_query:
                seller_query += " AND (s.first_name LIKE %s OR s.last_name LIKE %s OR s.shop_name LIKE %s OR u.email LIKE %s)"
                search_param = f"%{search_query}%"
                params.extend([search_param, search_param, search_param, search_param])
            
            seller_query += " ORDER BY u.created_at DESC"
            cursor.execute(seller_query, params)
            sellers = cursor.fetchall()
            
            # Count by status
            count_query = """
                SELECT 
                    (SELECT COUNT(*) FROM users WHERE user_type = 'seller' AND status = 'pending') as pending_count,
                    (SELECT COUNT(*) FROM users WHERE user_type = 'seller' AND status = 'active') as active_count,
                    (SELECT COUNT(*) FROM users WHERE user_type = 'seller' AND status = 'rejected') as rejected_count,
                    (SELECT COUNT(*) FROM users WHERE user_type = 'seller' AND status = 'suspended') as suspended_count,
                    (SELECT COUNT(*) FROM users WHERE user_type = 'seller' AND status = 'banned') as banned_count
            """
            cursor.execute(count_query)
            counts = cursor.fetchone()
            
            return jsonify({
                'success': True,
                'sellers': sellers,
                'counts': counts
            }), 200
            
        except Exception as db_error:
            print(f"Database error: {str(db_error)}")
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
        finally:
            close_db_connection(connection, cursor)
        
    except Exception as e:
        print(f"Error fetching sellers: {str(e)}")
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@admin_users_sellers_bp.route('/api/admin/sellers/<int:seller_id>/approve', methods=['POST'])
def approve_seller(seller_id):
    """Approve a seller account"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            # Get seller info with email
            cursor.execute("""
                SELECT s.user_id, s.first_name, s.last_name, u.email 
                FROM sellers s 
                JOIN users u ON s.user_id = u.user_id 
                WHERE s.seller_id = %s
            """, (seller_id,))
            seller = cursor.fetchone()
            
            if not seller:
                return jsonify({'success': False, 'message': 'Seller not found'}), 404
            
            # Update user status to active
            cursor.execute("UPDATE users SET status = 'active' WHERE user_id = %s", (seller['user_id'],))
            
            # Clear suspension data when activating
            cursor.execute("""
                UPDATE sellers 
                SET account_status = 'active', 
                    suspension_end = NULL, 
                    suspension_reason = NULL
                WHERE seller_id = %s
            """, (seller_id,))
            
            connection.commit()
            
            print(f"Seller {seller_id} approved: {seller['first_name']} {seller['last_name']}")
            
            # Send approval email
            send_account_status_email(
                seller['email'],
                seller['first_name'],
                seller['last_name'],
                'seller',
                'approved'
            )
            
            return jsonify({'success': True, 'message': 'Seller account approved successfully'}), 200
            
        except Exception as db_error:
            connection.rollback()
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
        finally:
            close_db_connection(connection, cursor)
        
    except Exception as e:
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@admin_users_sellers_bp.route('/api/admin/sellers/<int:seller_id>/reject', methods=['POST'])
def reject_seller(seller_id):
    """Reject a seller account"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            # Get seller info with email
            cursor.execute("""
                SELECT s.user_id, s.first_name, s.last_name, u.email 
                FROM sellers s 
                JOIN users u ON s.user_id = u.user_id 
                WHERE s.seller_id = %s
            """, (seller_id,))
            seller = cursor.fetchone()
            
            if not seller:
                return jsonify({'success': False, 'message': 'Seller not found'}), 404
            
            print(f"Attempting to reject seller {seller_id}: {seller['first_name']} {seller['last_name']}")
            print(f"User ID: {seller['user_id']}")
            
            cursor.execute("UPDATE users SET status = 'rejected' WHERE user_id = %s", (seller['user_id'],))
            affected_rows = cursor.rowcount
            connection.commit()
            
            print(f"✅ Seller {seller_id} rejected - {affected_rows} row(s) updated")
            print(f"Status should now be 'rejected' for user_id: {seller['user_id']}")
            
            # Send rejection email
            send_account_status_email(
                seller['email'],
                seller['first_name'],
                seller['last_name'],
                'seller',
                'rejected'
            )
            
            return jsonify({'success': True, 'message': 'Seller account rejected'}), 200
            
        except Exception as db_error:
            connection.rollback()
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
        finally:
            close_db_connection(connection, cursor)
        
    except Exception as e:
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@admin_users_sellers_bp.route('/api/admin/sellers/<int:seller_id>/suspend', methods=['POST'])
def suspend_seller(seller_id):
    """Suspend a seller account"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            cursor.execute("SELECT user_id FROM sellers WHERE seller_id = %s", (seller_id,))
            seller = cursor.fetchone()
            
            if not seller:
                return jsonify({'success': False, 'message': 'Seller not found'}), 404
            
            cursor.execute("UPDATE users SET status = 'suspended' WHERE user_id = %s", (seller['user_id'],))
            connection.commit()
            
            return jsonify({'success': True, 'message': 'Seller account suspended'}), 200
            
        except Exception as db_error:
            connection.rollback()
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
        finally:
            close_db_connection(connection, cursor)
        
    except Exception as e:
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@admin_users_sellers_bp.route('/api/admin/sellers/<int:seller_id>/ban', methods=['POST'])
def ban_seller(seller_id):
    """Ban a seller account"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            cursor.execute("SELECT user_id FROM sellers WHERE seller_id = %s", (seller_id,))
            seller = cursor.fetchone()
            
            if not seller:
                return jsonify({'success': False, 'message': 'Seller not found'}), 404
            
            cursor.execute("UPDATE users SET status = 'banned' WHERE user_id = %s", (seller['user_id'],))
            connection.commit()
            
            return jsonify({'success': True, 'message': 'Seller account banned'}), 200
            
        except Exception as db_error:
            connection.rollback()
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
        finally:
            close_db_connection(connection, cursor)
        
    except Exception as e:
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500
