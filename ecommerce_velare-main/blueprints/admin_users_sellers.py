from flask import Blueprint, render_template, jsonify, request
import sys
import os
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_config import get_supabase_client

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

@admin_users_sellers_bp.route('/admin/users/sellers')
def admin_users_sellers():
    return render_template('admin/admin_users_sellers.html')

@admin_users_sellers_bp.route('/api/admin/sellers', methods=['GET'])
def get_sellers():
    """Fetch all sellers with filtering using Supabase"""
    try:
        print("\n" + "="*80)
        print("🏪 [ADMIN SELLERS] Fetching sellers list...")
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
            # Build query for sellers with user info
            seller_query = supabase.table('sellers').select('''
                seller_id,
                user_id,
                first_name,
                last_name,
                shop_name,
                id_type,
                id_file_path,
                business_permit_file_path,
                shop_logo,
                report_count,
                users!inner(email, status, created_at)
            ''')
            
            # Add status filter
            if status_filter != 'all':
                seller_query = seller_query.eq('users.status', status_filter)
            
            # Order by seller_id instead of users.created_at (can't order by foreign table columns directly)
            seller_query = seller_query.order('seller_id', desc=True)
            sellers_response = seller_query.execute()
            
            sellers = sellers_response.data if sellers_response.data else []
            print(f"✅ Found {len(sellers)} sellers")
            
            # Get seller IDs for address lookup
            seller_ids = [s['seller_id'] for s in sellers]
            
            # Fetch addresses for all sellers
            addresses_dict = {}
            if seller_ids:
                addresses_response = supabase.table('addresses').select('*').eq('user_type', 'seller').in_('user_ref_id', seller_ids).execute()
                
                if addresses_response.data:
                    for addr in addresses_response.data:
                        addresses_dict[addr['user_ref_id']] = addr
            
            # Flatten nested user data and add addresses, apply search filter
            filtered_sellers = []
            for seller in sellers:
                user = seller.get('users', {})
                address = addresses_dict.get(seller['seller_id'], {})
                
                # Flatten data
                seller_data = {
                    'account_id': seller['seller_id'],
                    'user_id': seller['user_id'],
                    'user_type': 'seller',
                    'first_name': seller['first_name'],
                    'last_name': seller['last_name'],
                    'shop_name': seller.get('shop_name'),
                    'id_type': seller.get('id_type'),
                    'id_file_path': seller.get('id_file_path'),
                    'business_permit_file_path': seller.get('business_permit_file_path'),
                    'shop_logo': seller.get('shop_logo'),
                    'report_count': seller.get('report_count', 0),
                    'email': user.get('email') if isinstance(user, dict) else None,
                    'status': user.get('status') if isinstance(user, dict) else None,
                    'created_at': user.get('created_at') if isinstance(user, dict) else None,
                    'phone_number': address.get('phone_number'),
                    'full_address': address.get('full_address'),
                    'region': address.get('region'),
                    'province': address.get('province'),
                    'city': address.get('city'),
                    'barangay': address.get('barangay'),
                    'street_name': address.get('street_name'),
                    'house_number': address.get('house_number'),
                    'postal_code': address.get('postal_code')
                }
                
                # Apply search filter in Python
                if search_query:
                    search_lower = search_query.lower()
                    if (search_lower in (seller_data['first_name'] or '').lower() or
                        search_lower in (seller_data['last_name'] or '').lower() or
                        search_lower in (seller_data['shop_name'] or '').lower() or
                        search_lower in (seller_data['email'] or '').lower()):
                        filtered_sellers.append(seller_data)
                else:
                    filtered_sellers.append(seller_data)
            
            # Count by status - optimize by counting from the fetched data instead of making 5 separate queries
            print("🔍 Counting sellers by status...")
            
            # Get all sellers with their status
            all_sellers_response = supabase.table('users').select('user_id, status').eq('user_type', 'seller').execute()
            all_sellers_data = all_sellers_response.data if all_sellers_response.data else []
            
            # Count by status in Python instead of making multiple DB queries
            pending_count = sum(1 for s in all_sellers_data if s.get('status') == 'pending')
            active_count = sum(1 for s in all_sellers_data if s.get('status') == 'active')
            rejected_count = sum(1 for s in all_sellers_data if s.get('status') == 'rejected')
            suspended_count = sum(1 for s in all_sellers_data if s.get('status') == 'suspended')
            banned_count = sum(1 for s in all_sellers_data if s.get('status') == 'banned')
            
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
                'sellers': filtered_sellers,
                'counts': counts
            }), 200
            
        except Exception as db_error:
            print(f"❌ Database error: {str(db_error)}")
            import traceback
            traceback.print_exc()
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
    except Exception as e:
        print(f"❌ Error fetching sellers: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@admin_users_sellers_bp.route('/api/admin/sellers/<int:seller_id>/approve', methods=['POST'])
def approve_seller(seller_id):
    """Approve a seller account using Supabase"""
    try:
        print(f"\n✅ [APPROVE SELLER] Processing seller_id: {seller_id}")
        
        supabase = get_supabase_client()
        if not supabase:
            print("❌ Supabase connection failed")
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Get seller info with email
            seller_response = supabase.table('sellers').select('''
                user_id,
                first_name,
                last_name,
                users(email)
            ''').eq('seller_id', seller_id).execute()
            
            if not seller_response.data:
                print(f"❌ Seller not found")
                return jsonify({'success': False, 'message': 'Seller not found'}), 404
            
            seller = seller_response.data[0]
            user = seller.get('users', {})
            email = user.get('email') if isinstance(user, dict) else None
            
            # Update user status to active
            supabase.table('users').update({'status': 'active'}).eq('user_id', seller['user_id']).execute()
            
            # Clear suspension data when activating
            supabase.table('sellers').update({
                'account_status': 'active',
                'suspension_end': None,
                'suspension_reason': None
            }).eq('seller_id', seller_id).execute()
            
            print(f"✅ Seller {seller_id} approved: {seller['first_name']} {seller['last_name']}")
            
            # Send approval email
            if email:
                send_account_status_email(
                    email,
                    seller['first_name'],
                    seller['last_name'],
                    'seller',
                    'approved'
                )
            
            return jsonify({'success': True, 'message': 'Seller account approved successfully'}), 200
            
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


@admin_users_sellers_bp.route('/api/admin/sellers/<int:seller_id>/reject', methods=['POST'])
def reject_seller(seller_id):
    """Reject a seller account using Supabase"""
    try:
        print(f"\n❌ [REJECT SELLER] Processing seller_id: {seller_id}")
        
        supabase = get_supabase_client()
        if not supabase:
            print("❌ Supabase connection failed")
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Get seller info with email
            seller_response = supabase.table('sellers').select('''
                user_id,
                first_name,
                last_name,
                users(email)
            ''').eq('seller_id', seller_id).execute()
            
            if not seller_response.data:
                print(f"❌ Seller not found")
                return jsonify({'success': False, 'message': 'Seller not found'}), 404
            
            seller = seller_response.data[0]
            user = seller.get('users', {})
            email = user.get('email') if isinstance(user, dict) else None
            
            print(f"Attempting to reject seller {seller_id}: {seller['first_name']} {seller['last_name']}")
            print(f"User ID: {seller['user_id']}")
            
            # Update user status to rejected
            update_response = supabase.table('users').update({'status': 'rejected'}).eq('user_id', seller['user_id']).execute()
            
            print(f"✅ Seller {seller_id} rejected - Status updated")
            print(f"Status should now be 'rejected' for user_id: {seller['user_id']}")
            
            # Send rejection email
            if email:
                send_account_status_email(
                    email,
                    seller['first_name'],
                    seller['last_name'],
                    'seller',
                    'rejected'
                )
            
            return jsonify({'success': True, 'message': 'Seller account rejected'}), 200
            
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


@admin_users_sellers_bp.route('/api/admin/sellers/<int:seller_id>/suspend', methods=['POST'])
def suspend_seller(seller_id):
    """Suspend a seller account using Supabase"""
    try:
        print(f"\n⏸️ [SUSPEND SELLER] Processing seller_id: {seller_id}")
        
        supabase = get_supabase_client()
        if not supabase:
            print("❌ Supabase connection failed")
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Get seller's user_id and details
            seller_response = supabase.table('sellers').select('user_id, first_name, last_name, users(email)').eq('seller_id', seller_id).execute()
            
            if not seller_response.data:
                print(f"❌ Seller not found")
                return jsonify({'success': False, 'message': 'Seller not found'}), 404
            
            seller = seller_response.data[0]
            user_email = seller.get('users', {}).get('email') if seller.get('users') else None
            
            # Update user status to suspended
            supabase.table('users').update({'status': 'suspended'}).eq('user_id', seller['user_id']).execute()
            
            print(f"✅ Seller {seller_id} suspended")
            
            # Send suspension email
            if user_email:
                send_suspension_email(
                    user_email,
                    seller['first_name'],
                    seller['last_name'],
                    'seller',
                    action='suspend',
                    reason='Account suspended by administrator'
                )
            
            return jsonify({'success': True, 'message': 'Seller account suspended'}), 200
            
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


@admin_users_sellers_bp.route('/api/admin/sellers/<int:seller_id>/ban', methods=['POST'])
def ban_seller(seller_id):
    """Ban a seller account using Supabase"""
    try:
        print(f"\n🚫 [BAN SELLER] Processing seller_id: {seller_id}")
        
        supabase = get_supabase_client()
        if not supabase:
            print("❌ Supabase connection failed")
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Get seller's user_id and details
            seller_response = supabase.table('sellers').select('user_id, first_name, last_name, users(email)').eq('seller_id', seller_id).execute()
            
            if not seller_response.data:
                print(f"❌ Seller not found")
                return jsonify({'success': False, 'message': 'Seller not found'}), 404
            
            seller = seller_response.data[0]
            user_email = seller.get('users', {}).get('email') if seller.get('users') else None
            
            # Update user status to banned
            supabase.table('users').update({'status': 'banned'}).eq('user_id', seller['user_id']).execute()
            
            print(f"✅ Seller {seller_id} banned")
            
            # Send ban email
            if user_email:
                send_suspension_email(
                    user_email,
                    seller['first_name'],
                    seller['last_name'],
                    'seller',
                    action='ban',
                    reason='Account permanently banned by administrator'
                )
            
            return jsonify({'success': True, 'message': 'Seller account banned'}), 200
            
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
