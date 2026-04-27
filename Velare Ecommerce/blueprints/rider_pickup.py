from flask import Blueprint, render_template, session, redirect, url_for, jsonify, request
import sys
import os

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.supabase_helper import *

rider_pickup_bp = Blueprint('rider_pickup', __name__)

@rider_pickup_bp.route('/rider/pickup')
def rider_pickup():
    # Check if user is logged in and is a rider
    if 'user_id' not in session or session.get('user_type') != 'rider':
        return redirect(url_for('auth.login'))
    
    try:
        # Get rider information from Supabase
        rider_data = get_rider_by_user_id(session['user_id'])
        
        if not rider_data:
            return render_template('rider/rider_pickup.html', error='Rider profile not found')
        
        # Check if rider has a phone number
        if not rider_data.get('phone_number') or rider_data.get('phone_number') == 'N/A':
            # Redirect to profile page with error message
            return redirect(url_for('rider_profile.rider_profile') + '?error=phone_required')
        
        return render_template('rider/rider_pickup.html', rider=rider_data)
        
    except Exception as e:
        print(f"Error fetching rider data: {e}")
        return render_template('rider/rider_pickup.html', error='Failed to load rider data')

@rider_pickup_bp.route('/rider/pickup/api/pending-deliveries', methods=['GET'])
def get_pending_deliveries_api():
    """API endpoint to fetch pending deliveries for pickup"""
    if 'user_id' not in session or session.get('user_type') != 'rider':
        return jsonify({'error': 'Unauthorized'}), 401
    
    try:
        # Get rider_id for the current user
        rider = get_rider_by_user_id(session['user_id'])
        
        if not rider:
            return jsonify({'error': 'Rider not found'}), 404
        
        # Fetch pending deliveries from Supabase
        deliveries_data = get_pending_deliveries()
        
        # Debug logging
        print(f"=== PENDING DELIVERIES DEBUG ===")
        print(f"Number of pending deliveries found: {len(deliveries_data)}")
        if len(deliveries_data) > 0:
            print(f"First delivery: {deliveries_data[0]}")
        else:
            print("No pending deliveries found!")
        
        # Format deliveries for response
        formatted_deliveries = []
        for delivery in deliveries_data:
            order = delivery.get('orders', {})
            buyer = order.get('buyers', {})
            seller = order.get('sellers', {})
            
            formatted_deliveries.append({
                'delivery_id': delivery['delivery_id'],
                'order_id': delivery['order_id'],
                'pickup_address': delivery['pickup_address'],
                'delivery_address': delivery['delivery_address'],
                'delivery_fee': float(delivery.get('delivery_fee', 0)),
                'status': delivery['status'],
                'order_number': order.get('order_number'),
                'total_amount': float(order.get('total_amount', 0)),
                'buyer_name': f"{buyer.get('first_name', '')} {buyer.get('last_name', '')}",
                'buyer_phone': buyer.get('phone_number') or 'N/A',
                'seller_shop_name': seller.get('shop_name'),
                'seller_phone': seller.get('phone_number') or 'N/A'
            })
        
        print(f"Returning deliveries: {formatted_deliveries}")
        return jsonify({'success': True, 'deliveries': formatted_deliveries}), 200
        
    except Exception as e:
        print(f"Error fetching pending deliveries: {e}")
        return jsonify({'error': 'Failed to fetch deliveries'}), 500

@rider_pickup_bp.route('/rider/pickup/api/accept-delivery', methods=['POST'])
def accept_delivery():
    """API endpoint to accept a delivery assignment"""
    if 'user_id' not in session or session.get('user_type') != 'rider':
        return jsonify({'error': 'Unauthorized'}), 401
    
    data = request.get_json()
    delivery_id = data.get('delivery_id')
    
    if not delivery_id:
        return jsonify({'error': 'Delivery ID is required'}), 400
    
    try:
        # Get rider_id for the current user
        rider = get_rider_by_user_id(session['user_id'])
        
        if not rider:
            return jsonify({'error': 'Rider not found'}), 404
        
        rider_id = rider['rider_id']
        
        # Check if delivery is still pending
        delivery = get_delivery_by_id(delivery_id)
        
        if not delivery:
            return jsonify({'error': 'Delivery not found'}), 404
        
        if delivery['status'] != 'pending' or delivery.get('rider_id') is not None:
            return jsonify({'error': 'Delivery is no longer available'}), 400
        
        # Assign delivery to rider using Supabase helper
        success = accept_delivery_supabase(delivery_id, rider_id)
        
        if not success:
            return jsonify({'error': 'Failed to accept delivery'}), 500
        
        # Update rider status to busy
        supabase = get_supabase()
        supabase.table('riders').update({'status': 'busy'}).eq('rider_id', rider_id).execute()
        
        return jsonify({'success': True, 'message': 'Delivery accepted successfully'}), 200
        
    except Exception as e:
        print(f"Error accepting delivery: {e}")
        return jsonify({'error': 'Failed to accept delivery'}), 500

@rider_pickup_bp.route('/rider/pickup/api/reject-delivery', methods=['POST'])
def reject_delivery():
    """API endpoint to reject a delivery assignment"""
    if 'user_id' not in session or session.get('user_type') != 'rider':
        return jsonify({'error': 'Unauthorized'}), 401
    
    data = request.get_json()
    delivery_id = data.get('delivery_id')
    
    if not delivery_id:
        return jsonify({'error': 'Delivery ID is required'}), 400
    
    # For now, rejecting just means not accepting it
    # The delivery remains in pending state for other riders
    
    return jsonify({'success': True, 'message': 'Delivery rejected'}), 200
