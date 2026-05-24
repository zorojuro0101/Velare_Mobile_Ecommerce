from flask import Blueprint, render_template, session, redirect, url_for, jsonify, request
import sys
import os

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.supabase_helper import *

rider_activeDelivery_bp = Blueprint('rider_activeDelivery', __name__)

@rider_activeDelivery_bp.route('/rider/active-delivery')
def rider_activeDelivery():
    print(f"\n{'='*80}")
    print(f"🚚 [ACTIVE DELIVERY] Loading active deliveries page...")
    print(f"{'='*80}\n")
    
    # Check if user is logged in and is a rider
    if 'user_id' not in session or session.get('user_type') != 'rider':
        return redirect(url_for('auth.login'))
    
    try:
        # Get rider information from Supabase
        rider_data = get_rider_by_user_id(session['user_id'])
        
        if not rider_data:
            print("❌ Rider profile not found")
            return render_template('rider/rider_activeDelivery.html', error='Rider profile not found')
        
        print(f"✅ Rider: {rider_data.get('first_name')} {rider_data.get('last_name')}")
        print(f"{'='*80}\n")
        return render_template('rider/rider_activeDelivery.html', rider=rider_data)
        
    except Exception as e:
        print(f"❌ Error fetching rider data: {e}")
        return render_template('rider/rider_activeDelivery.html', error='Failed to load rider data')

@rider_activeDelivery_bp.route('/rider/active-delivery/api/active-deliveries', methods=['GET'])
def get_active_deliveries_api():
    """API endpoint to fetch active deliveries for the current rider"""
    print(f"\n{'='*80}")
    print(f"📦 [ACTIVE DELIVERIES API] Fetching active deliveries...")
    print(f"{'='*80}\n")
    
    if 'user_id' not in session or session.get('user_type') != 'rider':
        return jsonify({'error': 'Unauthorized'}), 401
    
    try:
        # Get rider_id for the current user
        rider = get_rider_by_user_id(session['user_id'])
        
        if not rider:
            return jsonify({'error': 'Rider not found'}), 404
        
        rider_id = rider['rider_id']
        print(f"🔍 Rider ID: {rider_id}")
        
        # Fetch active deliveries from Supabase
        deliveries_data = get_rider_active_deliveries(rider_id)
        print(f"📦 Found {len(deliveries_data)} active deliveries")
        
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
                'rider_earnings': float(delivery.get('rider_earnings', 0) or 0),
                'status': delivery['status'],
                'assigned_at': delivery.get('assigned_at'),
                'picked_up_at': delivery.get('picked_up_at'),
                'order_number': order.get('order_number'),
                'total_amount': float(order.get('total_amount', 0)),
                'order_received': order.get('order_received'),
                'buyer_name': f"{buyer.get('first_name', '')} {buyer.get('last_name', '')}",
                'buyer_phone': buyer.get('phone_number'),
                'seller_shop_name': seller.get('shop_name'),
                'seller_phone': seller.get('phone_number')
            })
        
        print(f"✅ Returning {len(formatted_deliveries)} deliveries")
        print(f"{'='*80}\n")
        return jsonify({'success': True, 'deliveries': formatted_deliveries}), 200
        
    except Exception as e:
        print(f"❌ Error fetching active deliveries: {e}")
        return jsonify({'error': 'Failed to fetch deliveries'}), 500

@rider_activeDelivery_bp.route('/rider/active-delivery/api/mark-delivered', methods=['POST'])
def mark_delivered():
    """API endpoint to mark a delivery as delivered (waiting for buyer confirmation)"""
    print(f"\n{'='*80}")
    print(f"✅ [MARK DELIVERED] Processing delivery completion...")
    print(f"{'='*80}\n")
    
    if 'user_id' not in session or session.get('user_type') != 'rider':
        return jsonify({'error': 'Unauthorized'}), 401
    
    data = request.get_json()
    delivery_id = data.get('delivery_id')
    
    if not delivery_id:
        return jsonify({'error': 'Delivery ID is required'}), 400
    
    print(f"📦 Delivery ID: {delivery_id}")
    
    try:
        # Get rider_id for the current user
        rider = get_rider_by_user_id(session['user_id'])
        
        if not rider:
            return jsonify({'error': 'Rider not found'}), 404
        
        rider_id = rider['rider_id']
        print(f"🔍 Rider ID: {rider_id}")
        
        # Check if delivery belongs to this rider
        delivery = get_delivery_by_id(delivery_id)
        
        if not delivery:
            print("❌ Delivery not found")
            return jsonify({'error': 'Delivery not found'}), 404
        
        if delivery['rider_id'] != rider_id:
            print("❌ Unauthorized - delivery belongs to another rider")
            return jsonify({'error': 'This delivery does not belong to you'}), 403
        
        if delivery['status'] == 'delivered':
            print("⚠️ Already delivered")
            return jsonify({'error': 'Delivery already marked as delivered'}), 400
        
        # Check if delivery is in in_transit status (must pick up first before delivering)
        if delivery['status'] != 'in_transit':
            print(f"❌ Invalid status: {delivery['status']}")
            return jsonify({'error': 'Item must be picked up first before marking as delivered'}), 400
        
        # Calculate rider earnings (100% of delivery fee - no commission)
        delivery_fee = delivery.get('delivery_fee', 0)
        rider_earnings = float(delivery_fee)
        print(f"💰 Rider earnings: ₱{rider_earnings}")
        
        # Update delivery status to delivered using helper function
        success = mark_delivery_delivered(delivery_id)
        
        if not success:
            print("❌ Failed to update delivery status")
            return jsonify({'error': 'Failed to update delivery status'}), 500
        
        # Update rider earnings in delivery record
        supabase = get_supabase()
        supabase.table('deliveries').update({'rider_earnings': rider_earnings}).eq('delivery_id', delivery_id).execute()
        
        # Update rider's total_earnings and status
        supabase.table('riders').update({
            'status': 'available',
            'total_earnings': rider['total_earnings'] + rider_earnings if rider.get('total_earnings') else rider_earnings
        }).eq('rider_id', rider_id).execute()
        
        # Get order details for notification
        order = get_order_by_id(delivery['order_id'])
        
        print(f"✅ Delivery marked as delivered")
        print(f"   Order: {order.get('order_number') if order else 'N/A'}")
        print(f"   Rider earnings: ₱{rider_earnings}")
        
        # Create notification for buyer (non-blocking)
        if order:
            try:
                from .notification_helper import create_delivered_notification
                print(f"📧 Creating notification for buyer...")
                result = create_delivered_notification(
                    delivery['order_id'], 
                    order['order_number'], 
                    order['buyer_id'], 
                    order['total_amount']
                )
                if result:
                    print(f"   ✅ Notification sent")
                else:
                    print(f"   ⚠️ Notification failed")
            except Exception as notif_error:
                print(f"   ❌ Notification error: {notif_error}")
        
        print(f"{'='*80}\n")
        return jsonify({'success': True, 'message': 'Delivery status updated'}), 200
        
    except Exception as e:
        print(f"❌ Error marking delivery as delivered: {e}")
        return jsonify({'error': 'Failed to update delivery status'}), 500

@rider_activeDelivery_bp.route('/rider/active-delivery/api/pickup-item', methods=['POST'])
def pickup_item():
    """API endpoint to mark item as picked up from seller"""
    print(f"\n{'='*80}")
    print(f"📦 [PICKUP ITEM] Processing pickup...")
    print(f"{'='*80}\n")
    
    if 'user_id' not in session or session.get('user_type') != 'rider':
        return jsonify({'error': 'Unauthorized'}), 401
    
    data = request.get_json()
    delivery_id = data.get('delivery_id')
    
    if not delivery_id:
        return jsonify({'error': 'Delivery ID is required'}), 400
    
    print(f"📦 Delivery ID: {delivery_id}")
    
    try:
        # Get rider_id for the current user
        rider = get_rider_by_user_id(session['user_id'])
        
        if not rider:
            return jsonify({'error': 'Rider not found'}), 404
        
        rider_id = rider['rider_id']
        print(f"🔍 Rider ID: {rider_id}")
        
        # Check if delivery belongs to this rider
        supabase = get_supabase()
        delivery_response = supabase.table('deliveries').select('''
            delivery_id,
            status,
            rider_id,
            order_id,
            delivery_fee,
            orders (
                order_number,
                total_amount,
                buyer_id
            )
        ''').eq('delivery_id', delivery_id).execute()
        
        if not delivery_response.data:
            print("❌ Delivery not found")
            return jsonify({'error': 'Delivery not found'}), 404
        
        delivery = clean_supabase_data(delivery_response.data[0])
        
        if delivery['rider_id'] != rider_id:
            print("❌ Unauthorized - delivery belongs to another rider")
            return jsonify({'error': 'This delivery does not belong to you'}), 403
        
        # Allow pickup if status is 'assigned'
        if delivery['status'] not in ['assigned', None]:
            print(f"❌ Invalid status: {delivery['status']}")
            return jsonify({'error': f"Cannot pickup. Current status: {delivery['status']}"}), 400
        
        # Update delivery status to in_transit using helper function
        success = mark_delivery_picked_up(delivery_id)
        
        if not success:
            print("❌ Failed to update pickup status")
            return jsonify({'error': 'Failed to update pickup status'}), 500
        
        # Update order status to in_transit
        update_order_status_supabase(delivery['order_id'], 'in_transit')
        
        print(f"✅ Pickup successful")
        print(f"   Order: {delivery.get('orders', {}).get('order_number')}")
        print(f"   Status: in_transit")
        
        # Create notification for buyer (non-blocking)
        try:
            from .notification_helper import create_shipped_notification
            order = delivery.get('orders', {})
            print(f"📧 Creating notification for buyer...")
            result = create_shipped_notification(
                delivery['order_id'], 
                order.get('order_number'), 
                order.get('buyer_id'), 
                order.get('total_amount')
            )
            if result:
                print(f"   ✅ Notification sent")
            else:
                print(f"   ⚠️ Notification failed")
        except Exception as notif_error:
            print(f"   ❌ Notification error: {notif_error}")
        
        print(f"{'='*80}\n")
        return jsonify({'success': True, 'message': 'Item marked as picked up'}), 200
        
    except Exception as e:
        print(f"❌ Error marking item as picked up: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': f'Failed to update pickup status: {str(e)}'}), 500
