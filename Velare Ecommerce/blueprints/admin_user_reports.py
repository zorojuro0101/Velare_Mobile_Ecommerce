from flask import Blueprint, render_template, request, redirect, url_for, flash, session, jsonify
from database.db_config import get_db_connection

admin_user_reports_bp = Blueprint('admin_user_reports', __name__)

@admin_user_reports_bp.route('/admin/user-reports', methods=['GET'])
def user_reports():
    """Display all user reports"""
    if 'user_id' not in session or session.get('user_type') != 'admin':
        flash('Unauthorized access', 'error')
        return redirect(url_for('auth.login'))
    
    connection = get_db_connection()
    cursor = connection.cursor(dictionary=True)
    
    # Get filter parameters
    status_filter = request.args.get('status', 'all')
    
    # Build query
    query = """
        SELECT 
            ur.report_id,
            ur.reporter_type,
            ur.reported_user_type,
            ur.report_category,
            ur.report_reason,
            ur.status,
            ur.created_at,
            ur.order_id,
            ur.delivery_id,
            ur.evidence_image,
            CASE 
                WHEN ur.reporter_type = 'buyer' THEN CONCAT(b.first_name, ' ', b.last_name)
                WHEN ur.reporter_type = 'seller' THEN s.shop_name
                WHEN ur.reporter_type = 'rider' THEN CONCAT(r.first_name, ' ', r.last_name)
            END as reporter_name,
            CASE 
                WHEN ur.reported_user_type = 'buyer' THEN CONCAT(b2.first_name, ' ', b2.last_name)
                WHEN ur.reported_user_type = 'seller' THEN s2.shop_name
                WHEN ur.reported_user_type = 'rider' THEN CONCAT(r2.first_name, ' ', r2.last_name)
            END as reported_user_name
        FROM user_reports ur
        LEFT JOIN buyers b ON ur.reporter_id = b.user_id AND ur.reporter_type = 'buyer'
        LEFT JOIN sellers s ON ur.reporter_id = s.user_id AND ur.reporter_type = 'seller'
        LEFT JOIN riders r ON ur.reporter_id = r.user_id AND ur.reporter_type = 'rider'
        LEFT JOIN buyers b2 ON ur.reported_user_id = b2.user_id AND ur.reported_user_type = 'buyer'
        LEFT JOIN sellers s2 ON ur.reported_user_id = s2.user_id AND ur.reported_user_type = 'seller'
        LEFT JOIN riders r2 ON ur.reported_user_id = r2.user_id AND ur.reported_user_type = 'rider'
    """
    
    if status_filter != 'all':
        query += " WHERE ur.status = %s"
        cursor.execute(query + " ORDER BY ur.created_at DESC", (status_filter,))
    else:
        cursor.execute(query + " ORDER BY ur.created_at DESC")
    
    reports = cursor.fetchall()
    
    cursor.close()
    connection.close()
    
    return render_template('admin/admin_user_reports.html', reports=reports, status_filter=status_filter)


@admin_user_reports_bp.route('/admin/report/<int:report_id>', methods=['GET'])
def view_report(report_id):
    """View detailed report"""
    if 'user_id' not in session or session.get('user_type') != 'admin':
        flash('Unauthorized access', 'error')
        return redirect(url_for('auth.login'))
    
    connection = get_db_connection()
    cursor = connection.cursor(dictionary=True)
    
    cursor.execute("""
        SELECT 
            ur.*,
            CASE 
                WHEN ur.reporter_type = 'buyer' THEN CONCAT(b.first_name, ' ', b.last_name)
                WHEN ur.reporter_type = 'seller' THEN s.shop_name
                WHEN ur.reporter_type = 'rider' THEN CONCAT(r.first_name, ' ', r.last_name)
            END as reporter_name,
            CASE 
                WHEN ur.reported_user_type = 'buyer' THEN CONCAT(b2.first_name, ' ', b2.last_name)
                WHEN ur.reported_user_type = 'seller' THEN s2.shop_name
                WHEN ur.reported_user_type = 'rider' THEN CONCAT(r2.first_name, ' ', r2.last_name)
            END as reported_user_name,
            o.order_number,
            d.delivery_id
        FROM user_reports ur
        LEFT JOIN buyers b ON ur.reporter_id = b.user_id AND ur.reporter_type = 'buyer'
        LEFT JOIN sellers s ON ur.reporter_id = s.user_id AND ur.reporter_type = 'seller'
        LEFT JOIN riders r ON ur.reporter_id = r.user_id AND ur.reporter_type = 'rider'
        LEFT JOIN buyers b2 ON ur.reported_user_id = b2.user_id AND ur.reported_user_type = 'buyer'
        LEFT JOIN sellers s2 ON ur.reported_user_id = s2.user_id AND ur.reported_user_type = 'seller'
        LEFT JOIN riders r2 ON ur.reported_user_id = r2.user_id AND ur.reported_user_type = 'rider'
        LEFT JOIN orders o ON ur.order_id = o.order_id
        LEFT JOIN deliveries d ON ur.delivery_id = d.delivery_id
        WHERE ur.report_id = %s
    """, (report_id,))
    report = cursor.fetchone()
    
    cursor.close()
    connection.close()
    
    if not report:
        flash('Report not found', 'error')
        return redirect(url_for('admin_user_reports.user_reports'))
    
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
        
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)
        
        # Get admin_id
        cursor.execute("SELECT admin_id FROM admins WHERE user_id = %s", (session['user_id'],))
        admin = cursor.fetchone()
        
        cursor.execute("""
            UPDATE user_reports 
            SET status = %s, admin_notes = %s, admin_id = %s,
                resolved_at = CASE WHEN %s IN ('resolved', 'dismissed') THEN NOW() ELSE NULL END
            WHERE report_id = %s
        """, (status, admin_notes, admin['admin_id'], status, report_id))
        
        connection.commit()
        cursor.close()
        connection.close()
        
        return jsonify({'success': True, 'message': 'Report status updated'})
    
    except Exception as e:
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
        
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)
        
        # Calculate suspension end date
        if action == 'ban':
            # Permanent ban - set to NULL or far future date
            suspension_end = None
            status = 'banned'
            duration_text = 'permanently'
        else:
            # Temporary suspension
            if duration_unit == 'weeks':
                interval = f"{duration_value} WEEK"
            else:  # months
                interval = f"{duration_value} MONTH"
            
            cursor.execute(f"SELECT DATE_ADD(NOW(), INTERVAL {interval}) as end_date")
            result = cursor.fetchone()
            suspension_end = result['end_date']
            status = 'suspended'
            duration_text = f"{duration_value} {duration_unit}"
        
        # Update user status in the users table (for login check)
        print(f"🔄 Updating users table: user_id={reported_user_id}, status={status}")
        cursor.execute("""
            UPDATE users 
            SET status = %s
            WHERE user_id = %s
        """, (status, reported_user_id))
        users_affected = cursor.rowcount
        print(f"✅ Users table updated: {users_affected} rows affected")
        
        # Update user status in the appropriate table
        if reported_user_type == 'buyer':
            print(f"🔄 Updating buyers table: user_id={reported_user_id}")
            cursor.execute("""
                UPDATE buyers 
                SET account_status = %s, suspension_end = %s, suspension_reason = %s
                WHERE user_id = %s
            """, (status, suspension_end, reason, reported_user_id))
            print(f"✅ Buyers table updated: {cursor.rowcount} rows affected")
        elif reported_user_type == 'seller':
            print(f"🔄 Updating sellers table: user_id={reported_user_id}")
            cursor.execute("""
                UPDATE sellers 
                SET account_status = %s, suspension_end = %s, suspension_reason = %s
                WHERE user_id = %s
            """, (status, suspension_end, reason, reported_user_id))
            print(f"✅ Sellers table updated: {cursor.rowcount} rows affected")
        elif reported_user_type == 'rider':
            print(f"🔄 Updating riders table: user_id={reported_user_id}")
            cursor.execute("""
                UPDATE riders 
                SET account_status = %s, suspension_end = %s, suspension_reason = %s
                WHERE user_id = %s
            """, (status, suspension_end, reason, reported_user_id))
            print(f"✅ Riders table updated: {cursor.rowcount} rows affected")
        
        # Update report status to resolved
        if report_id:
            cursor.execute("""
                UPDATE user_reports 
                SET status = 'resolved', 
                    admin_notes = CONCAT(COALESCE(admin_notes, ''), '\n', 'User ', %s, ' for ', %s, '. Reason: ', %s),
                    resolved_at = NOW()
                WHERE report_id = %s
            """, (action + 'ed', duration_text, reason, report_id))
        
        print(f"💾 Committing changes...")
        connection.commit()
        print(f"✅ Changes committed successfully")
        
        # Verify the update
        cursor.execute("SELECT status FROM users WHERE user_id = %s", (reported_user_id,))
        verify = cursor.fetchone()
        print(f"🔍 Verification - User status in database: {verify['status'] if verify else 'NOT FOUND'}")
        
        # Send notification to the suspended/banned user
        from blueprints.notification_helper import create_suspension_notification
        create_suspension_notification(reported_user_id, action, duration_text, reason)
        
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True, 
            'message': f'User {action}ed successfully for {duration_text}'
        })
    
    except Exception as e:
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
        
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)
        
        cursor.execute("""
            SELECT COUNT(*) as total_reports
            FROM user_reports
            WHERE reported_user_id = %s AND reported_user_type = %s
        """, (reported_user_id, reported_user_type))
        
        result = cursor.fetchone()
        
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'total_reports': result['total_reports']
        })
    
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500
