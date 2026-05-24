from flask import Blueprint, render_template, request, redirect, url_for, flash, session, jsonify
from database.db_config import get_supabase_client
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

admin_user_reports_bp = Blueprint('admin_user_reports', __name__)

def send_suspension_email(recipient_email, first_name, last_name, user_type, action='suspend', duration_text='', reason='Violation of terms of service'):
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
                            <p style="margin: 0; color: #92400E;"><strong>Your {user_type} account has been suspended for {duration_text}.</strong></p>
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
            
            Your {user_type} account has been suspended for {duration_text}.
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

@admin_user_reports_bp.route('/admin/user-reports', methods=['GET'])
def user_reports():
    """Display all user reports"""
    if 'user_id' not in session or session.get('user_type') != 'admin':
        flash('Unauthorized access', 'error')
        return redirect(url_for('auth.login'))
    
    print("📋 Fetching user reports...")
    supabase = get_supabase_client()
    
    # Get filter parameters
    status_filter = request.args.get('status', 'all')
    
    # Build query with nested joins
    query = supabase.table('user_reports').select('''
        report_id,
        reporter_id,
        reporter_type,
        reported_user_id,
        reported_user_type,
        report_category,
        report_reason,
        status,
        created_at,
        order_id,
        delivery_id,
        evidence_image
    ''')
    
    if status_filter != 'all':
        query = query.eq('status', status_filter)
    
    response = query.order('created_at', desc=True).execute()
    reports = response.data
    
    print(f"✅ Fetched {len(reports)} reports")
    
    # Parse date strings to datetime objects
    from datetime import datetime
    for report in reports:
        if report.get('created_at') and isinstance(report['created_at'], str):
            try:
                report['created_at'] = datetime.fromisoformat(report['created_at'].replace('Z', '+00:00'))
            except:
                pass
    
    # Optimize: Fetch all users at once instead of one by one (N+1 problem fix)
    # Collect all unique user IDs
    reporter_ids = list(set(r['reporter_id'] for r in reports))
    reported_ids = list(set(r['reported_user_id'] for r in reports))
    
    # Fetch all buyers, sellers, riders at once
    buyers_map = {}
    sellers_map = {}
    riders_map = {}
    
    if reporter_ids or reported_ids:
        all_user_ids = list(set(reporter_ids + reported_ids))
        
        # Fetch all buyers
        buyers_response = supabase.table('buyers').select('user_id, first_name, last_name').in_('user_id', all_user_ids).execute()
        buyers_map = {b['user_id']: f"{b['first_name']} {b['last_name']}" for b in buyers_response.data}
        
        # Fetch all sellers
        sellers_response = supabase.table('sellers').select('user_id, shop_name').in_('user_id', all_user_ids).execute()
        sellers_map = {s['user_id']: s['shop_name'] for s in sellers_response.data}
        
        # Fetch all riders
        riders_response = supabase.table('riders').select('user_id, first_name, last_name').in_('user_id', all_user_ids).execute()
        riders_map = {r['user_id']: f"{r['first_name']} {r['last_name']}" for r in riders_response.data}
    
    # Assign names to reports using the maps
    for report in reports:
        # Get reporter name
        if report['reporter_type'] == 'buyer':
            report['reporter_name'] = buyers_map.get(report['reporter_id'], 'Unknown Buyer')
        elif report['reporter_type'] == 'seller':
            report['reporter_name'] = sellers_map.get(report['reporter_id'], 'Unknown Seller')
        elif report['reporter_type'] == 'rider':
            report['reporter_name'] = riders_map.get(report['reporter_id'], 'Unknown Rider')
        
        # Get reported user name
        if report['reported_user_type'] == 'buyer':
            report['reported_user_name'] = buyers_map.get(report['reported_user_id'], 'Unknown Buyer')
        elif report['reported_user_type'] == 'seller':
            report['reported_user_name'] = sellers_map.get(report['reported_user_id'], 'Unknown Seller')
        elif report['reported_user_type'] == 'rider':
            report['reported_user_name'] = riders_map.get(report['reported_user_id'], 'Unknown Rider')
    
    return render_template('admin/admin_user_reports.html', reports=reports, status_filter=status_filter)


@admin_user_reports_bp.route('/admin/report/<int:report_id>', methods=['GET'])
def view_report(report_id):
    """View detailed report"""
    if 'user_id' not in session or session.get('user_type') != 'admin':
        flash('Unauthorized access', 'error')
        return redirect(url_for('auth.login'))
    
    print(f"🔍 Fetching report details for report_id={report_id}...")
    supabase = get_supabase_client()
    
    # Fetch report
    response = supabase.table('user_reports').select('*').eq('report_id', report_id).execute()
    
    if not response.data:
        print(f"❌ Report not found")
        flash('Report not found', 'error')
        return redirect(url_for('admin_user_reports.user_reports'))
    
    report = response.data[0]
    
    # Get reporter name
    if report['reporter_type'] == 'buyer':
        buyer_response = supabase.table('buyers').select('first_name, last_name').eq('user_id', report['reporter_id']).execute()
        if buyer_response.data:
            report['reporter_name'] = f"{buyer_response.data[0]['first_name']} {buyer_response.data[0]['last_name']}"
        else:
            report['reporter_name'] = 'Unknown Buyer'
    elif report['reporter_type'] == 'seller':
        seller_response = supabase.table('sellers').select('shop_name').eq('user_id', report['reporter_id']).execute()
        if seller_response.data:
            report['reporter_name'] = seller_response.data[0]['shop_name']
        else:
            report['reporter_name'] = 'Unknown Seller'
    elif report['reporter_type'] == 'rider':
        rider_response = supabase.table('riders').select('first_name, last_name').eq('user_id', report['reporter_id']).execute()
        if rider_response.data:
            report['reporter_name'] = f"{rider_response.data[0]['first_name']} {rider_response.data[0]['last_name']}"
        else:
            report['reporter_name'] = 'Unknown Rider'
    
    # Get reported user name
    if report['reported_user_type'] == 'buyer':
        buyer_response = supabase.table('buyers').select('first_name, last_name').eq('user_id', report['reported_user_id']).execute()
        if buyer_response.data:
            report['reported_user_name'] = f"{buyer_response.data[0]['first_name']} {buyer_response.data[0]['last_name']}"
        else:
            report['reported_user_name'] = 'Unknown Buyer'
    elif report['reported_user_type'] == 'seller':
        seller_response = supabase.table('sellers').select('shop_name').eq('user_id', report['reported_user_id']).execute()
        if seller_response.data:
            report['reported_user_name'] = seller_response.data[0]['shop_name']
        else:
            report['reported_user_name'] = 'Unknown Seller'
    elif report['reported_user_type'] == 'rider':
        rider_response = supabase.table('riders').select('first_name, last_name').eq('user_id', report['reported_user_id']).execute()
        if rider_response.data:
            report['reported_user_name'] = f"{rider_response.data[0]['first_name']} {rider_response.data[0]['last_name']}"
        else:
            report['reported_user_name'] = 'Unknown Rider'
    
    # Get order number if order_id exists
    if report.get('order_id'):
        order_response = supabase.table('orders').select('order_number').eq('order_id', report['order_id']).execute()
        if order_response.data:
            report['order_number'] = order_response.data[0]['order_number']
    
    # Get delivery_id if exists (already in report)
    
    print(f"✅ Report details fetched successfully")
    
    return render_template('admin/admin_report_detail.html', report=report)

@admin_user_reports_bp.route('/admin/update-report-status', methods=['POST'])
def update_report_status():
    """Update report status"""
    if 'user_id' not in session or session.get('user_type') != 'admin':
        return jsonify({'success': False, 'message': 'Unauthorized'}), 401
    
    try:
        report_id = request.form.get('report_id')
        status = request.form.get('status')
        admin_notes = request.form.get('admin_notes')
        
        print(f"📝 Updating report status: report_id={report_id}, status={status}")
        supabase = get_supabase_client()
        
        # Get admin_id
        admin_response = supabase.table('admins').select('admin_id').eq('user_id', session['user_id']).execute()
        
        if not admin_response.data:
            print(f"❌ Admin not found")
            return jsonify({'success': False, 'message': 'Admin not found'}), 404
        
        admin_id = admin_response.data[0]['admin_id']
        
        # Prepare update data
        update_data = {
            'status': status,
            'admin_notes': admin_notes,
            'admin_id': admin_id
        }
        
        # Set resolved_at if status is resolved or dismissed
        if status in ['resolved', 'dismissed']:
            from datetime import datetime
            update_data['resolved_at'] = datetime.utcnow().isoformat()
        else:
            update_data['resolved_at'] = None
        
        supabase.table('user_reports').update(update_data).eq('report_id', report_id).execute()
        
        print(f"✅ Report status updated successfully")
        return jsonify({'success': True, 'message': 'Report status updated'})
    
    except Exception as e:
        print(f"❌ Error updating report status: {str(e)}")
        return jsonify({'success': False, 'message': str(e)}), 500

@admin_user_reports_bp.route('/admin/suspend-user', methods=['POST'])
def suspend_user():
    """Suspend or ban a user with specific duration"""
    if 'user_id' not in session or session.get('user_type') != 'admin':
        return jsonify({'success': False, 'message': 'Unauthorized'}), 401
    
    try:
        data = request.get_json()
        reported_user_id = data.get('reported_user_id')
        reported_user_type = data.get('reported_user_type')
        action = data.get('action')  # 'suspend' or 'ban'
        duration_value = data.get('duration_value')  # number (1, 2, 3, etc.)
        duration_unit = data.get('duration_unit')  # 'weeks' or 'months'
        reason = data.get('reason', '')
        report_id = data.get('report_id')
        
        print(f"🔨 Suspending/banning user: user_id={reported_user_id}, action={action}")
        supabase = get_supabase_client()
        
        # Calculate suspension end date
        if action == 'ban':
            # Permanent ban - set to NULL
            suspension_end = None
            status = 'banned'
            duration_text = 'permanently'
        else:
            # Temporary suspension
            from datetime import datetime, timedelta
            
            if duration_unit == 'weeks':
                delta = timedelta(weeks=int(duration_value))
            else:  # months
                delta = timedelta(days=int(duration_value) * 30)  # Approximate
            
            suspension_end = (datetime.utcnow() + delta).isoformat()
            status = 'suspended'
            duration_text = f"{duration_value} {duration_unit}"
        
        # Update user status in the users table (for login check)
        print(f"🔄 Updating users table: user_id={reported_user_id}, status={status}")
        users_response = supabase.table('users').update({'status': status}).eq('user_id', reported_user_id).execute()
        print(f"✅ Users table updated: {len(users_response.data)} rows affected")
        
        # Update user status in the appropriate table
        update_data = {
            'account_status': status,
            'suspension_end': suspension_end,
            'suspension_reason': reason
        }
        
        if reported_user_type == 'buyer':
            print(f"🔄 Updating buyers table: user_id={reported_user_id}")
            buyer_response = supabase.table('buyers').update(update_data).eq('user_id', reported_user_id).execute()
            print(f"✅ Buyers table updated: {len(buyer_response.data)} rows affected")
        elif reported_user_type == 'seller':
            print(f"🔄 Updating sellers table: user_id={reported_user_id}")
            seller_response = supabase.table('sellers').update(update_data).eq('user_id', reported_user_id).execute()
            print(f"✅ Sellers table updated: {len(seller_response.data)} rows affected")
        elif reported_user_type == 'rider':
            print(f"🔄 Updating riders table: user_id={reported_user_id}")
            rider_response = supabase.table('riders').update(update_data).eq('user_id', reported_user_id).execute()
            print(f"✅ Riders table updated: {len(rider_response.data)} rows affected")
        
        # Update report status to resolved
        if report_id:
            # Get existing admin_notes
            report_response = supabase.table('user_reports').select('admin_notes').eq('report_id', report_id).execute()
            existing_notes = report_response.data[0]['admin_notes'] if report_response.data and report_response.data[0].get('admin_notes') else ''
            
            new_notes = f"{existing_notes}\nUser {action}ed for {duration_text}. Reason: {reason}".strip()
            
            from datetime import datetime
            supabase.table('user_reports').update({
                'status': 'resolved',
                'admin_notes': new_notes,
                'resolved_at': datetime.utcnow().isoformat()
            }).eq('report_id', report_id).execute()
        
        print(f"✅ Changes committed successfully")
        
        # Verify the update
        verify_response = supabase.table('users').select('status').eq('user_id', reported_user_id).execute()
        if verify_response.data:
            print(f"🔍 Verification - User status in database: {verify_response.data[0]['status']}")
        else:
            print(f"🔍 Verification - User NOT FOUND")
        
        # Send notification to the suspended/banned user
        from blueprints.notification_helper import create_suspension_notification
        create_suspension_notification(reported_user_id, action, duration_text, reason)
        
        # Get user details and send email
        try:
            if reported_user_type == 'buyer':
                user_details = supabase.table('buyers').select('first_name, last_name, users(email)').eq('user_id', reported_user_id).execute()
            elif reported_user_type == 'seller':
                user_details = supabase.table('sellers').select('first_name, last_name, users(email)').eq('user_id', reported_user_id).execute()
            elif reported_user_type == 'rider':
                user_details = supabase.table('riders').select('first_name, last_name, users(email)').eq('user_id', reported_user_id).execute()
            
            if user_details.data:
                user = user_details.data[0]
                user_email = user.get('users', {}).get('email') if user.get('users') else None
                
                if user_email:
                    send_suspension_email(
                        user_email,
                        user['first_name'],
                        user['last_name'],
                        reported_user_type,
                        action=action,
                        duration_text=duration_text,
                        reason=reason
                    )
        except Exception as email_error:
            print(f"⚠️ Failed to send email notification: {email_error}")
        
        return jsonify({
            'success': True, 
            'message': f'User {action}ed successfully for {duration_text}'
        })
    
    except Exception as e:
        print(f"❌ Error suspending user: {str(e)}")
        return jsonify({'success': False, 'message': str(e)}), 500

@admin_user_reports_bp.route('/admin/get-user-report-count', methods=['POST'])
def get_user_report_count():
    """Get total report count for a user"""
    if 'user_id' not in session or session.get('user_type') != 'admin':
        return jsonify({'success': False, 'message': 'Unauthorized'}), 401
    
    try:
        data = request.get_json()
        reported_user_id = data.get('reported_user_id')
        reported_user_type = data.get('reported_user_type')
        
        print(f"📊 Counting reports for user_id={reported_user_id}, type={reported_user_type}")
        supabase = get_supabase_client()
        
        response = supabase.table('user_reports').select('report_id', count='exact').eq('reported_user_id', reported_user_id).eq('reported_user_type', reported_user_type).execute()
        
        total_reports = response.count
        print(f"✅ Total reports: {total_reports}")
        
        return jsonify({
            'success': True,
            'total_reports': total_reports
        })
    
    except Exception as e:
        print(f"❌ Error counting reports: {str(e)}")
        return jsonify({'success': False, 'message': str(e)}), 500
