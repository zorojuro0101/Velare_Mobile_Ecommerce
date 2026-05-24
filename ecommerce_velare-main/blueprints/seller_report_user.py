from flask import Blueprint, render_template, request, redirect, url_for, flash, session, jsonify
from database.db_config import get_supabase_client
from dateutil import parser
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
    
    print(f"🔍 Seller Reports - user_id: {session['user_id']}")
    
    supabase = get_supabase_client()
    if not supabase:
        print("❌ Supabase client not available")
        flash('Database connection failed', 'error')
        return redirect(url_for('seller_dashboard.seller_dashboard'))
    
    try:
        # Get seller info
        seller_response = supabase.table('sellers').select(
            'seller_id, shop_name, shop_logo'
        ).eq('user_id', session['user_id']).execute()
        
        seller = seller_response.data[0] if seller_response.data else None
        print(f"👤 Seller: {seller}")
        
        if not seller:
            flash('Seller not found', 'error')
            return redirect(url_for('seller_dashboard.seller_dashboard'))
        
        # Get recent orders with buyers and riders
        orders_response = supabase.table('orders').select(
            'order_id, order_number, buyer_id, buyers(first_name, last_name), deliveries(delivery_id, rider_id, riders(first_name, last_name))'
        ).eq('seller_id', seller['seller_id']).order('created_at', desc=True).limit(20).execute()
        
        # Format orders data
        orders = []
        if orders_response.data:
            for order in orders_response.data:
                buyer_data = order.get('buyers', {})
                deliveries = order.get('deliveries', [])
                delivery = deliveries[0] if deliveries else {}
                rider_data = delivery.get('riders', {}) if delivery else {}
                
                orders.append({
                    'order_id': order['order_id'],
                    'order_number': order['order_number'],
                    'buyer_id': order['buyer_id'],
                    'buyer_name': f"{buyer_data.get('first_name', '')} {buyer_data.get('last_name', '')}".strip() if buyer_data else 'Unknown',
                    'delivery_id': delivery.get('delivery_id') if delivery else None,
                    'rider_id': delivery.get('rider_id') if delivery else None,
                    'rider_name': f"{rider_data.get('first_name', '')} {rider_data.get('last_name', '')}".strip() if rider_data else None
                })
        
        print(f"📦 Found {len(orders)} orders")
        
        # Get seller's reports (without nested joins - we'll fetch user details separately)
        reports_response = supabase.table('user_reports').select(
            '*'
        ).eq('reporter_id', session['user_id']).eq('reporter_type', 'seller').order('created_at', desc=True).execute()
        
        # Format reports data and fetch reported user details
        reports = []
        if reports_response.data:
            for report in reports_response.data:
                reported_user_name = 'Unknown'
                
                # Fetch reported user details based on type
                if report['reported_user_type'] == 'buyer':
                    buyer_response = supabase.table('buyers').select(
                        'first_name, last_name'
                    ).eq('user_id', report['reported_user_id']).execute()
                    
                    if buyer_response.data:
                        buyer = buyer_response.data[0]
                        reported_user_name = f"{buyer.get('first_name', '')} {buyer.get('last_name', '')}".strip()
                
                elif report['reported_user_type'] == 'rider':
                    rider_response = supabase.table('riders').select(
                        'first_name, last_name'
                    ).eq('user_id', report['reported_user_id']).execute()
                    
                    if rider_response.data:
                        rider = rider_response.data[0]
                        reported_user_name = f"{rider.get('first_name', '')} {rider.get('last_name', '')}".strip()
                
                # Parse created_at date
                if report.get('created_at'):
                    report['created_at'] = parser.parse(report['created_at'])
                
                report['reported_user_name'] = reported_user_name
                reports.append(report)
        
        print(f"📋 Found {len(reports)} reports")
        
        return render_template('seller/seller_reports.html', 
                             seller=seller, 
                             orders=orders,
                             reports=reports)
    
    except Exception as e:
        print(f"❌ Error loading seller reports: {e}")
        import traceback
        traceback.print_exc()
        flash('Error loading reports', 'error')
        return redirect(url_for('seller_dashboard.seller_dashboard'))

@seller_report_user_bp.route('/seller/submit-report', methods=['POST'])
def submit_report():
    """Submit a report"""
    if 'user_id' not in session or session.get('user_type') != 'seller':
        return jsonify({'success': False, 'message': 'Unauthorized'}), 401
    
    try:
        print(f"🔍 Submit Report - user_id: {session['user_id']}")
        
        supabase = get_supabase_client()
        if not supabase:
            print("❌ Supabase client not available")
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        reported_type = request.form.get('reported_type')
        reported_id = request.form.get('reported_id')
        category = request.form.get('category')
        reason = request.form.get('reason')
        order_id = request.form.get('order_id') or None
        delivery_id = request.form.get('delivery_id') or None
        
        print(f"📝 Report details: type={reported_type}, id={reported_id}, category={category}")
        
        # Get reported user_id
        if reported_type == 'buyer':
            user_response = supabase.table('buyers').select('user_id').eq('buyer_id', reported_id).execute()
        elif reported_type == 'rider':
            user_response = supabase.table('riders').select('user_id').eq('rider_id', reported_id).execute()
        else:
            return jsonify({'success': False, 'message': 'Invalid user type'}), 400
        
        if not user_response.data:
            return jsonify({'success': False, 'message': 'User not found'}), 404
        
        reported_user = user_response.data[0]
        print(f"👤 Reported user_id: {reported_user['user_id']}")
        
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
                print(f"📎 Evidence uploaded: {evidence_path}")
        
        # Insert report
        report_data = {
            'reporter_id': session['user_id'],
            'reporter_type': 'seller',
            'reported_user_id': reported_user['user_id'],
            'reported_user_type': reported_type,
            'report_category': category,
            'report_reason': reason,
            'order_id': int(order_id) if order_id else None,
            'delivery_id': int(delivery_id) if delivery_id else None,
            'evidence_image': evidence_path
        }
        
        insert_response = supabase.table('user_reports').insert(report_data).execute()
        print(f"✅ Report inserted: {insert_response.data}")
        
        # Send notification to the reported user
        try:
            from blueprints.notification_helper import create_report_notification
            create_report_notification(reported_user['user_id'], reported_type, category)
            print(f"📬 Notification sent to user {reported_user['user_id']}")
        except Exception as notif_error:
            print(f"⚠️ Failed to send notification: {notif_error}")
        
        return jsonify({'success': True, 'message': 'Report submitted successfully'})
    
    except Exception as e:
        print(f"❌ Error submitting report: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': str(e)}), 500


