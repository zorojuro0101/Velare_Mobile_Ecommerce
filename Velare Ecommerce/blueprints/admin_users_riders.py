from flask import Blueprint, render_template, jsonify, request
import sys
import os
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_config import get_db_connection, close_db_connection

admin_users_riders_bp = Blueprint('admin_users_riders', __name__)

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
                            <li>{'Start accepting delivery orders' if user_type == 'rider' else 'Start browsing products'}</li>
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

@admin_users_riders_bp.route('/admin/users/riders')
def admin_users_riders():
    return render_template('admin/admin_users_riders.html')

@admin_users_riders_bp.route('/api/admin/riders', methods=['GET'])
def get_riders():
    """Fetch all riders with filtering"""
    try:
        # Get optional filters from query parameters
        status_filter = request.args.get('status', 'all')
        search_query = request.args.get('search', '')
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            rider_query = """
                SELECT 
                    r.rider_id as account_id,
                    'rider' as user_type,
                    r.first_name,
                    r.last_name,
                    r.id_type,
                    r.id_file_path,
                    r.profile_image,
                    r.vehicle_type,
                    r.plate_number,
                    r.orcr_file_path,
                    r.driver_license_file_path,
                    r.report_count,
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
            if status_filter != 'all':
                rider_query += " AND u.status = %s"
                params.append(status_filter)
            
            if search_query:
                rider_query += " AND (r.first_name LIKE %s OR r.last_name LIKE %s OR u.email LIKE %s)"
                search_param = f"%{search_query}%"
                params.extend([search_param, search_param, search_param])
            
            rider_query += " ORDER BY u.created_at DESC"
            cursor.execute(rider_query, params)
            riders = cursor.fetchall()
            
            # Count by status
            count_query = """
                SELECT 
                    (SELECT COUNT(*) FROM users WHERE user_type = 'rider' AND status = 'pending') as pending_count,
                    (SELECT COUNT(*) FROM users WHERE user_type = 'rider' AND status = 'active') as active_count,
                    (SELECT COUNT(*) FROM users WHERE user_type = 'rider' AND status = 'rejected') as rejected_count,
                    (SELECT COUNT(*) FROM users WHERE user_type = 'rider' AND status = 'suspended') as suspended_count,
                    (SELECT COUNT(*) FROM users WHERE user_type = 'rider' AND status = 'banned') as banned_count
            """
            cursor.execute(count_query)
            counts = cursor.fetchone()
            
            return jsonify({
                'success': True,
                'riders': riders,
                'counts': counts
            }), 200
            
        except Exception as db_error:
            print(f"Database error: {str(db_error)}")
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
        finally:
            close_db_connection(connection, cursor)
        
    except Exception as e:
        print(f"Error fetching riders: {str(e)}")
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@admin_users_riders_bp.route('/api/admin/riders/<int:rider_id>/approve', methods=['POST'])
def approve_rider(rider_id):
    """Approve a rider account"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            # Get rider info with email
            cursor.execute("""
                SELECT r.user_id, r.first_name, r.last_name, u.email 
                FROM riders r 
                JOIN users u ON r.user_id = u.user_id 
                WHERE r.rider_id = %s
            """, (rider_id,))
            rider = cursor.fetchone()
            
            if not rider:
                return jsonify({'success': False, 'message': 'Rider not found'}), 404
            
            # Update user status to active
            cursor.execute("UPDATE users SET status = 'active' WHERE user_id = %s", (rider['user_id'],))
            
            # Clear suspension data when activating
            cursor.execute("""
                UPDATE riders 
                SET account_status = 'active', 
                    suspension_end = NULL, 
                    suspension_reason = NULL
                WHERE rider_id = %s
            """, (rider_id,))
            
            connection.commit()
            
            print(f"Rider {rider_id} approved: {rider['first_name']} {rider['last_name']}")
            
            # Send approval email
            send_account_status_email(
                rider['email'],
                rider['first_name'],
                rider['last_name'],
                'rider',
                'approved'
            )
            
            return jsonify({'success': True, 'message': 'Rider account approved successfully'}), 200
            
        except Exception as db_error:
            connection.rollback()
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
        finally:
            close_db_connection(connection, cursor)
        
    except Exception as e:
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@admin_users_riders_bp.route('/api/admin/riders/<int:rider_id>/reject', methods=['POST'])
def reject_rider(rider_id):
    """Reject a rider account"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            # Get rider info with email
            cursor.execute("""
                SELECT r.user_id, r.first_name, r.last_name, u.email 
                FROM riders r 
                JOIN users u ON r.user_id = u.user_id 
                WHERE r.rider_id = %s
            """, (rider_id,))
            rider = cursor.fetchone()
            
            if not rider:
                return jsonify({'success': False, 'message': 'Rider not found'}), 404
            
            cursor.execute("UPDATE users SET status = 'rejected' WHERE user_id = %s", (rider['user_id'],))
            connection.commit()
            
            print(f"Rider {rider_id} rejected: {rider['first_name']} {rider['last_name']}")
            
            # Send rejection email
            send_account_status_email(
                rider['email'],
                rider['first_name'],
                rider['last_name'],
                'rider',
                'rejected'
            )
            
            return jsonify({'success': True, 'message': 'Rider account rejected'}), 200
            
        except Exception as db_error:
            connection.rollback()
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
        finally:
            close_db_connection(connection, cursor)
        
    except Exception as e:
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@admin_users_riders_bp.route('/api/admin/riders/<int:rider_id>/suspend', methods=['POST'])
def suspend_rider(rider_id):
    """Suspend a rider account"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            cursor.execute("SELECT user_id FROM riders WHERE rider_id = %s", (rider_id,))
            rider = cursor.fetchone()
            
            if not rider:
                return jsonify({'success': False, 'message': 'Rider not found'}), 404
            
            cursor.execute("UPDATE users SET status = 'suspended' WHERE user_id = %s", (rider['user_id'],))
            connection.commit()
            
            return jsonify({'success': True, 'message': 'Rider account suspended'}), 200
            
        except Exception as db_error:
            connection.rollback()
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
        finally:
            close_db_connection(connection, cursor)
        
    except Exception as e:
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@admin_users_riders_bp.route('/api/admin/riders/<int:rider_id>/ban', methods=['POST'])
def ban_rider(rider_id):
    """Ban a rider account"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            cursor.execute("SELECT user_id FROM riders WHERE rider_id = %s", (rider_id,))
            rider = cursor.fetchone()
            
            if not rider:
                return jsonify({'success': False, 'message': 'Rider not found'}), 404
            
            cursor.execute("UPDATE users SET status = 'banned' WHERE user_id = %s", (rider['user_id'],))
            connection.commit()
            
            return jsonify({'success': True, 'message': 'Rider account banned'}), 200
            
        except Exception as db_error:
            connection.rollback()
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
        finally:
            close_db_connection(connection, cursor)
        
    except Exception as e:
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500
