from flask import Blueprint, render_template, jsonify, request
import sys
import os
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_config import get_supabase_client

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

def send_suspension_email(recipient_email, first_name, last_name, user_type, action='suspend', reason='Violation of terms of service'):
    """Send account suspension or ban email using Gmail SMTP"""
    try:
        sender_email = 'parokyanigahi21@gmail.com'
        sender_password = 'ahzyzotndedbxeco'
        
        print(f"📧 Sending {action} email to: {recipient_email}")
        
        # Create message
        msg = MIMEMultipart('alternative')
        
        if action == 'ban':
            msg['Subject'] = '🚫 Velare - Account Permanently Banned'
            
            html_content = f'''
            <html>
                <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
                    <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                        <div style="text-align: center; margin-bottom: 30px;">
                            <h1 style="color: #DC2626; margin: 0;">🚫 Account Permanently Banned</h1>
                        </div>
                        
                        <p>Dear {first_name} {last_name},</p>
                        
                        <div style="background-color: #FEE2E2; padding: 20px; border-left: 4px solid #DC2626; margin: 20px 0; border-radius: 5px;">
                            <p style="margin: 0; color: #991B1B;"><strong>Your {user_type} account has been permanently banned.</strong></p>
                            <p style="margin: 10px 0 0 0; color: #991B1B;">Reason: {reason}</p>
                        </div>
                        
                        <p>You will no longer be able to access your account or use Velare services.</p>
                        
                        <p>This action was taken due to serious violations of our Terms of Service and Community Guidelines.</p>
                        
                        <p>If you believe this decision was made in error, please contact our support team at <a href="mailto:support@velare.com">support@velare.com</a> with your account details.</p>
                        
                        <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 20px 0;">
                        <p style="color: #718096; font-size: 12px;">This is an automated message from Velare Ecommerce.</p>
                    </div>
                </body>
            </html>
            '''
            
            text_content = f'''
            Account Permanently Banned
            
            Dear {first_name} {last_name},
            
            Your {user_type} account has been permanently banned.
            Reason: {reason}
            
            You will no longer be able to access your account or use Velare services.
            
            If you believe this decision was made in error, please contact our support team.
            '''
            
        else:  # suspend
            msg['Subject'] = '⛔ Velare - Account Suspended'
            
            html_content = f'''
            <html>
                <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
                    <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                        <div style="text-align: center; margin-bottom: 30px;">
                            <h1 style="color: #F59E0B; margin: 0;">⛔ Account Suspended</h1>
                        </div>
                        
                        <p>Dear {first_name} {last_name},</p>
                        
                        <div style="background-color: #FEF3C7; padding: 20px; border-left: 4px solid #F59E0B; margin: 20px 0; border-radius: 5px;">
                            <p style="margin: 0; color: #92400E;"><strong>Your {user_type} account has been suspended.</strong></p>
                            <p style="margin: 10px 0 0 0; color: #92400E;">Reason: {reason}</p>
                        </div>
                        
                        <p>During the suspension period, you will not be able to access your account or use Velare services.</p>
                        
                        <p><strong>What you should do:</strong></p>
                        <ul style="line-height: 1.8;">
                            <li>Review our Terms of Service and Community Guidelines</li>
                            <li>Ensure you understand the violation that led to this suspension</li>
                            <li>Contact support if you have questions or believe this was an error</li>
                        </ul>
                        
                        <p>Please note that repeated violations may result in permanent account termination.</p>
                        
                        <p>If you have any questions, please contact our support team at <a href="mailto:support@velare.com">support@velare.com</a>.</p>
                        
                        <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 20px 0;">
                        <p style="color: #718096; font-size: 12px;">This is an automated message from Velare Ecommerce.</p>
                    </div>
                </body>
            </html>
            '''
            
            text_content = f'''
            Account Suspended
            
            Dear {first_name} {last_name},
            
            Your {user_type} account has been suspended.
            Reason: {reason}
            
            During the suspension period, you will not be able to access your account or use Velare services.
            
            Please review our Terms of Service and Community Guidelines.
            
            If you have any questions, please contact our support team.
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
        
        print(f"✅ {action.capitalize()} email sent successfully to {recipient_email}")
        return True
        
    except smtplib.SMTPException as e:
        print(f"❌ SMTP Error sending {action} email: {str(e)}")
        return False
    except Exception as e:
        print(f"❌ Error sending {action} email: {str(e)}")
        return False

@admin_users_buyers_bp.route('/admin/users/buyers')
def admin_users_buyers():
    return render_template('admin/admin_users_buyers.html')

@admin_users_buyers_bp.route('/api/admin/buyers', methods=['GET'])
def get_buyers():
    """Fetch all buyers with filtering using Supabase"""
    try:
        print("\n" + "="*80)
        print("👥 [ADMIN BUYERS] Fetching buyers list...")
        print("="*80 + "\n")
        
        # Get optional filters from query parameters
        status_filter = request.args.get('status', 'all')
        search_query = request.args.get('search', '')
        
        print(f"🔍 Filters: status={status_filter}, search={search_query}")
        
        supabase = get_supabase_client()
        if not supabase:
            print("❌ Supabase connection failed")
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Build query for buyers with user info
            buyer_query = supabase.table('buyers').select('''
                buyer_id,
                user_id,
                first_name,
                last_name,
                id_type,
                id_file_path,
                profile_image,
                report_count,
                users!inner(email, status, created_at)
            ''')
            
            # Add status filter
            if status_filter != 'all':
                buyer_query = buyer_query.eq('users.status', status_filter)
            
            # Add search filter
            if search_query:
                # Supabase doesn't support OR in a simple way, so we'll filter in Python
                pass
            
            # Order by buyer_id instead of users.created_at (can't order by foreign table columns directly)
            buyer_query = buyer_query.order('buyer_id', desc=True)
            buyers_response = buyer_query.execute()
            
            buyers = buyers_response.data if buyers_response.data else []
            print(f"✅ Found {len(buyers)} buyers")
            
            # Flatten nested user data and apply search filter
            filtered_buyers = []
            for buyer in buyers:
                user = buyer.get('users', {})
                
                # Flatten data
                buyer_data = {
                    'account_id': buyer['buyer_id'],
                    'user_id': buyer['user_id'],
                    'user_type': 'buyer',
                    'first_name': buyer['first_name'],
                    'last_name': buyer['last_name'],
                    'id_type': buyer.get('id_type'),
                    'id_file_path': buyer.get('id_file_path'),
                    'profile_image': buyer.get('profile_image'),
                    'report_count': buyer.get('report_count', 0),
                    'email': user.get('email') if isinstance(user, dict) else None,
                    'status': user.get('status') if isinstance(user, dict) else None,
                    'created_at': user.get('created_at') if isinstance(user, dict) else None
                }
                
                # Apply search filter in Python
                if search_query:
                    search_lower = search_query.lower()
                    if (search_lower in buyer_data['first_name'].lower() or
                        search_lower in buyer_data['last_name'].lower() or
                        search_lower in (buyer_data['email'] or '').lower()):
                        filtered_buyers.append(buyer_data)
                else:
                    filtered_buyers.append(buyer_data)
            
            # Fetch addresses for each buyer
            buyer_ids = [b['account_id'] for b in filtered_buyers]
            if buyer_ids:
                addresses_response = supabase.table('addresses').select('*').eq('user_type', 'buyer').in_('user_ref_id', buyer_ids).order('is_default', desc=True).order('address_id').execute()
                
                addresses_by_buyer = {}
                if addresses_response.data:
                    for addr in addresses_response.data:
                        buyer_id = addr['user_ref_id']
                        if buyer_id not in addresses_by_buyer:
                            addresses_by_buyer[buyer_id] = []
                        addresses_by_buyer[buyer_id].append(addr)
                
                # Add addresses to buyers
                for buyer in filtered_buyers:
                    buyer['addresses'] = addresses_by_buyer.get(buyer['account_id'], [])
            else:
                for buyer in filtered_buyers:
                    buyer['addresses'] = []
            
            # Count by status - optimize by counting from the fetched data instead of making 5 separate queries
            print("🔍 Counting buyers by status...")
            
            # Get all buyers with their status
            all_buyers_response = supabase.table('users').select('user_id, status').eq('user_type', 'buyer').execute()
            all_buyers_data = all_buyers_response.data if all_buyers_response.data else []
            
            # Count by status in Python instead of making multiple DB queries
            pending_count = sum(1 for b in all_buyers_data if b.get('status') == 'pending')
            active_count = sum(1 for b in all_buyers_data if b.get('status') == 'active')
            rejected_count = sum(1 for b in all_buyers_data if b.get('status') == 'rejected')
            suspended_count = sum(1 for b in all_buyers_data if b.get('status') == 'suspended')
            banned_count = sum(1 for b in all_buyers_data if b.get('status') == 'banned')
            
            counts = {
                'pending_count': pending_count,
                'active_count': active_count,
                'rejected_count': rejected_count,
                'suspended_count': suspended_count,
                'banned_count': banned_count
            }
            
            print(f"✅ Counts: {counts}")
            print("="*80 + "\n")
            
            return jsonify({
                'success': True,
                'buyers': filtered_buyers,
                'counts': counts
            }), 200
            
        except Exception as db_error:
            print(f"❌ Database error: {str(db_error)}")
            import traceback
            traceback.print_exc()
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
    except Exception as e:
        print(f"❌ Error fetching buyers: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@admin_users_buyers_bp.route('/api/admin/buyers/<int:buyer_id>/approve', methods=['POST'])
def approve_buyer(buyer_id):
    """Approve a buyer account using Supabase"""
    try:
        print(f"\n✅ [APPROVE BUYER] Processing buyer_id: {buyer_id}")
        
        supabase = get_supabase_client()
        if not supabase:
            print("❌ Supabase connection failed")
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            from datetime import datetime
            
            # Get buyer info with email
            buyer_response = supabase.table('buyers').select('''
                user_id,
                first_name,
                last_name,
                users(email)
            ''').eq('buyer_id', buyer_id).execute()
            
            if not buyer_response.data:
                print(f"❌ Buyer not found")
                return jsonify({'success': False, 'message': 'Buyer not found'}), 404
            
            buyer = buyer_response.data[0]
            user = buyer.get('users', {})
            email = user.get('email') if isinstance(user, dict) else None
            
            # Update user status to active
            supabase.table('users').update({'status': 'active'}).eq('user_id', buyer['user_id']).execute()
            
            # Clear suspension data when activating
            supabase.table('buyers').update({
                'account_status': 'active',
                'suspension_end': None,
                'suspension_reason': None
            }).eq('buyer_id', buyer_id).execute()
            
            # Assign welcome vouchers to newly approved buyer
            print("🎁 Assigning welcome vouchers...")
            vouchers_response = supabase.table('vouchers').select('voucher_id').in_('voucher_code', ['FREESHIP', 'DISCOUNT20']).execute()
            
            if vouchers_response.data:
                for voucher in vouchers_response.data:
                    # Check if already exists
                    existing = supabase.table('buyer_vouchers').select('buyer_voucher_id').eq('buyer_id', buyer_id).eq('voucher_id', voucher['voucher_id']).execute()
                    
                    if not existing.data:
                        supabase.table('buyer_vouchers').insert({
                            'buyer_id': buyer_id,
                            'voucher_id': voucher['voucher_id'],
                            'is_used': False,
                            'claimed_at': datetime.now().isoformat()
                        }).execute()
            
            print(f"✅ Buyer {buyer_id} approved: {buyer['first_name']} {buyer['last_name']}")
            
            # Send approval email
            if email:
                send_account_status_email(
                    email,
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
            print(f"❌ Database error: {str(db_error)}")
            import traceback
            traceback.print_exc()
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
    except Exception as e:
        print(f"❌ Server error: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@admin_users_buyers_bp.route('/api/admin/buyers/<int:buyer_id>/reject', methods=['POST'])
def reject_buyer(buyer_id):
    """Reject a buyer account using Supabase"""
    try:
        print(f"\n❌ [REJECT BUYER] Processing buyer_id: {buyer_id}")
        
        supabase = get_supabase_client()
        if not supabase:
            print("❌ Supabase connection failed")
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Get buyer info with email
            buyer_response = supabase.table('buyers').select('''
                user_id,
                first_name,
                last_name,
                users(email)
            ''').eq('buyer_id', buyer_id).execute()
            
            if not buyer_response.data:
                print(f"❌ Buyer not found")
                return jsonify({'success': False, 'message': 'Buyer not found'}), 404
            
            buyer = buyer_response.data[0]
            user = buyer.get('users', {})
            email = user.get('email') if isinstance(user, dict) else None
            
            # Update user status to rejected
            supabase.table('users').update({'status': 'rejected'}).eq('user_id', buyer['user_id']).execute()
            
            print(f"✅ Buyer {buyer_id} rejected: {buyer['first_name']} {buyer['last_name']}")
            
            # Send rejection email
            if email:
                send_account_status_email(
                    email,
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
            print(f"❌ Database error: {str(db_error)}")
            import traceback
            traceback.print_exc()
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
    except Exception as e:
        print(f"❌ Server error: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500


@admin_users_buyers_bp.route('/api/admin/buyers/<int:buyer_id>/suspend', methods=['POST'])
def suspend_buyer(buyer_id):
    """Suspend a buyer account using Supabase"""
    try:
        print(f"\n⏸️ [SUSPEND BUYER] Processing buyer_id: {buyer_id}")
        
        supabase = get_supabase_client()
        if not supabase:
            print("❌ Supabase connection failed")
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Get buyer's user_id and details
            buyer_response = supabase.table('buyers').select('user_id, first_name, last_name, users(email)').eq('buyer_id', buyer_id).execute()
            
            if not buyer_response.data:
                print(f"❌ Buyer not found")
                return jsonify({'success': False, 'message': 'Buyer not found'}), 404
            
            buyer = buyer_response.data[0]
            user_email = buyer.get('users', {}).get('email') if buyer.get('users') else None
            
            # Update user status to suspended
            supabase.table('users').update({'status': 'suspended'}).eq('user_id', buyer['user_id']).execute()
            
            print(f"✅ Buyer {buyer_id} suspended")
            
            # Send suspension email
            if user_email:
                send_suspension_email(
                    user_email,
                    buyer['first_name'],
                    buyer['last_name'],
                    'buyer',
                    action='suspend',
                    reason='Account suspended by administrator'
                )
            
            return jsonify({'success': True, 'message': 'Buyer account suspended'}), 200
            
        except Exception as db_error:
            print(f"❌ Database error: {str(db_error)}")
            import traceback
            traceback.print_exc()
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
    except Exception as e:
        print(f"❌ Server error: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500


@admin_users_buyers_bp.route('/api/admin/buyers/<int:buyer_id>/ban', methods=['POST'])
def ban_buyer(buyer_id):
    """Ban a buyer account using Supabase"""
    try:
        print(f"\n🚫 [BAN BUYER] Processing buyer_id: {buyer_id}")
        
        supabase = get_supabase_client()
        if not supabase:
            print("❌ Supabase connection failed")
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Get buyer's user_id and details
            buyer_response = supabase.table('buyers').select('user_id, first_name, last_name, users(email)').eq('buyer_id', buyer_id).execute()
            
            if not buyer_response.data:
                print(f"❌ Buyer not found")
                return jsonify({'success': False, 'message': 'Buyer not found'}), 404
            
            buyer = buyer_response.data[0]
            user_email = buyer.get('users', {}).get('email') if buyer.get('users') else None
            
            # Update user status to banned
            supabase.table('users').update({'status': 'banned'}).eq('user_id', buyer['user_id']).execute()
            
            print(f"✅ Buyer {buyer_id} banned")
            
            # Send ban email
            if user_email:
                send_suspension_email(
                    user_email,
                    buyer['first_name'],
                    buyer['last_name'],
                    'buyer',
                    action='ban',
                    reason='Account permanently banned by administrator'
                )
            
            return jsonify({'success': True, 'message': 'Buyer account banned'}), 200
            
        except Exception as db_error:
            print(f"❌ Database error: {str(db_error)}")
            import traceback
            traceback.print_exc()
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
    except Exception as e:
        print(f"❌ Server error: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500
