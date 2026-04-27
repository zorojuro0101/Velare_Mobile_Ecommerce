from flask import Blueprint, render_template, request, redirect, url_for, flash, session, jsonify
from database.db_config import get_db_connection
from werkzeug.utils import secure_filename
import os
from datetime import datetime

seller_report_user_bp = Blueprint('seller_report_user', __name__)

UPLOAD_FOLDER = 'static/uploads/reports'
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif'}

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@seller_report_user_bp.route('/seller/reports', methods=['GET'])
def report_user_page():
    """Display report user form and my reports"""
    if 'user_id' not in session or session.get('user_type') != 'seller':
        flash('Please login as seller', 'error')
        return redirect(url_for('auth.login'))
    
    connection = get_db_connection()
    cursor = connection.cursor(dictionary=True)
    
    # Get seller info
    cursor.execute("""
        SELECT s.seller_id, s.shop_name, s.shop_logo
        FROM sellers s
        WHERE s.user_id = %s
    """, (session['user_id'],))
    seller = cursor.fetchone()
    
    # Get recent orders with buyers and riders
    cursor.execute("""
        SELECT DISTINCT
            o.order_id,
            o.order_number,
            o.buyer_id,
            CONCAT(b.first_name, ' ', b.last_name) as buyer_name,
            d.delivery_id,
            d.rider_id,
            CONCAT(r.first_name, ' ', r.last_name) as rider_name
        FROM orders o
        JOIN buyers b ON o.buyer_id = b.buyer_id
        LEFT JOIN deliveries d ON o.order_id = d.order_id
        LEFT JOIN riders r ON d.rider_id = r.rider_id
        WHERE o.seller_id = %s
        ORDER BY o.created_at DESC
        LIMIT 20
    """, (seller['seller_id'],))
    orders = cursor.fetchall()
    
    # Get seller's reports
    cursor.execute("""
        SELECT 
            ur.*,
            CASE 
                WHEN ur.reported_user_type = 'buyer' THEN CONCAT(b.first_name, ' ', b.last_name)
                WHEN ur.reported_user_type = 'rider' THEN CONCAT(r.first_name, ' ', r.last_name)
            END as reported_user_name
        FROM user_reports ur
        LEFT JOIN buyers b ON ur.reported_user_id = b.user_id AND ur.reported_user_type = 'buyer'
        LEFT JOIN riders r ON ur.reported_user_id = r.user_id AND ur.reported_user_type = 'rider'
        WHERE ur.reporter_id = %s AND ur.reporter_type = 'seller'
        ORDER BY ur.created_at DESC
    """, (session['user_id'],))
    reports = cursor.fetchall()
    
    cursor.close()
    connection.close()
    
    return render_template('seller/seller_reports.html', 
                         seller=seller, 
                         orders=orders,
                         reports=reports)

@seller_report_user_bp.route('/seller/submit-report', methods=['POST'])
def submit_report():
    """Submit a report"""
    if 'user_id' not in session or session.get('user_type') != 'seller':
        return jsonify({'success': False, 'message': 'Unauthorized'}), 401
    
    try:
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)
        
        reported_type = request.form.get('reported_type')
        reported_id = request.form.get('reported_id')
        category = request.form.get('category')
        reason = request.form.get('reason')
        order_id = request.form.get('order_id') or None
        delivery_id = request.form.get('delivery_id') or None
        
        # Get reported user_id
        if reported_type == 'buyer':
            cursor.execute("SELECT user_id FROM buyers WHERE buyer_id = %s", (reported_id,))
        elif reported_type == 'rider':
            cursor.execute("SELECT user_id FROM riders WHERE rider_id = %s", (reported_id,))
        else:
            return jsonify({'success': False, 'message': 'Invalid user type'}), 400
        
        reported_user = cursor.fetchone()
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
        cursor.execute("""
            INSERT INTO user_reports 
            (reporter_id, reporter_type, reported_user_id, reported_user_type, 
             report_category, report_reason, order_id, delivery_id, evidence_image)
            VALUES (%s, 'seller', %s, %s, %s, %s, %s, %s, %s)
        """, (session['user_id'], reported_user['user_id'], reported_type, 
              category, reason, order_id, delivery_id, evidence_path))
        
        connection.commit()
        cursor.close()
        connection.close()
        
        # Send notification to the reported user
        from blueprints.notification_helper import create_report_notification
        create_report_notification(reported_user['user_id'], reported_type, category)
        
        return jsonify({'success': True, 'message': 'Report submitted successfully'})
    
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500


