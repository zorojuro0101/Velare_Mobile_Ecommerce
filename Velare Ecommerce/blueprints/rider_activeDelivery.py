from flask import Blueprint, render_template, session, redirect, url_for, jsonify, request
import sys
import os

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.supabase_helper import *

rider_activeDelivery_bp = Blueprint('rider_activeDelivery', __name__)

@rider_activeDelivery_bp.route('/rider/active-delivery')
def rider_activeDelivery():
    # Check if user is logged in and is a rider
    if 'user_id' not in session or session.get('user_type') != 'rider':
        return redirect(url_for('auth.login'))
    
    try:
        # Get rider information from Supabase
        rider_data = get_rider_by_user_id(session['user_id'])
        
        if not rider_data:
            return render_template('rider/rider_activeDelivery.html', error='Rider profile not found')
        
        return render_template('rider/rider_activeDelivery.html', rider=rider_data)
        
    except Exception as e:
        print(f"Error fetching rider data: {e}")
        return render_template('rider/rider_activeDelivery.html', error='Failed to load rider data')

@rider_activeDelivery_bp.route('/rider/active-delivery/api/active-deliveries', methods=['GET'])
def get_active_deliveries_api():
    """API endpoint to fetch active deliveries for the current rider"""
    if 'user_id' not in session or session.get('user_type') != 'rider':
        return jsonify({'error': 'Unauthorized'}), 401
    
    try:
        # Get rider_id for the current user
        rider = get_rider_by_user_id(session['user_id'])
        
        if not rider:
            return jsonify({'error': 'Rider not found'}), 404
        
        rider_id = rider['rider_id']
        
        # Fetch active deliveries from Supabase
        deliveries_data = get_rider_active_deliveries(rider_id)
        
        # Debug logging
        print(f"🚚 Active Deliveries for Rider {rider_id}:")
        print(f"   Total found: {len(deliveries_data)}")
        
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
        
        return jsonify({'success': True, 'deliveries': formatted_deliveries}), 200
        
    except Exception as e:
        print(f"Error fetching active deliveries: {e}")
        return jsonify({'error': 'Failed to fetch deliveries'}), 500

@rider_activeDelivery_bp.route('/rider/active-delivery/api/mark-delivered', methods=['POST'])
def mark_delivered():
    """API endpoint to mark a delivery as delivered (waiting for buyer confirmation)"""
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
        
        # Check if delivery belongs to this rider
        delivery = get_delivery_by_id(delivery_id)
        
        if not delivery:
            return jsonify({'error': 'Delivery not found'}), 404
        
        if delivery['rider_id'] != rider_id:
            return jsonify({'error': 'This delivery does not belong to you'}), 403
        
        if delivery['status'] == 'delivered':
            return jsonify({'error': 'Delivery already marked as delivered'}), 400
        
        # Check if delivery is in in_transit status (must pick up first before delivering)
        if delivery['status'] != 'in_transit':
            return jsonify({'error': 'Item must be picked up first before marking as delivered'}), 400
        
        # Calculate rider earnings (100% of delivery fee - no commission)
        delivery_fee = delivery.get('delivery_fee', 0)
        rider_earnings = float(delivery_fee)  # Full delivery fee, no commission
        
        # Update delivery status to delivered using helper function
        success = mark_delivery_delivered(delivery_id)
        
        if not success:
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
        
        # Debug: Check what was updated
        print(f"✅ Delivery marked as delivered - Delivery ID: {delivery_id}, Order ID: {delivery['order_id']}")
        print(f"   Delivery status set to: 'delivered'")
        print(f"   Rider earnings: ₱{rider_earnings}")
        
        # Create notification for buyer (non-blocking)
        if order:
            try:
                from .notification_helper import create_delivered_notification
                print(f"📧 Creating delivered notification for buyer_id: {order['buyer_id']}, order: {order['order_number']}")
                result = create_delivered_notification(
                    delivery['order_id'], 
                    order['order_number'], 
                    order['buyer_id'], 
                    order['total_amount']
                )
                if result:
                    print(f"   ✅ Delivered notification created successfully")
                else:
                    print(f"   ⚠️ Delivered notification creation returned False")
            except Exception as notif_error:
                print(f"   ❌ Failed to create delivered notification: {notif_error}")
                import traceback
                traceback.print_exc()
        
        return jsonify({'success': True, 'message': 'Delivery status updated'}), 200
        
    except Exception as e:
        print(f"Error marking delivery as delivered: {e}")
        return jsonify({'error': 'Failed to update delivery status'}), 500

@rider_activeDelivery_bp.route('/rider/active-delivery/api/pickup-item', methods=['POST'])
def pickup_item():
    """API endpoint to mark item as picked up from seller"""
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
            return jsonify({'error': 'Delivery not found'}), 404
        
        delivery = clean_supabase_data(delivery_response.data[0])
        
        if delivery['rider_id'] != rider_id:
            return jsonify({'error': 'This delivery does not belong to you'}), 403
        
        # Allow pickup if status is 'assigned'
        if delivery['status'] not in ['assigned', None]:
            return jsonify({'error': f"Cannot pickup. Current status: {delivery['status']}"}), 400
        
        # Update delivery status to in_transit using helper function
        success = mark_delivery_picked_up(delivery_id)
        
        if not success:
            return jsonify({'error': 'Failed to update pickup status'}), 500
        
        # Update order status to in_transit
        update_order_status_supabase(delivery['order_id'], 'in_transit')
        
        # Debug: Check what was updated
        print(f"✅ Pickup successful - Delivery ID: {delivery_id}, Order ID: {delivery['order_id']}")
        print(f"   Delivery status set to: 'in_transit'")
        print(f"   Order status set to: 'in_transit'")
        
        # Create notification for buyer (non-blocking)
        try:
            from .notification_helper import create_shipped_notification
            order = delivery.get('orders', {})
            print(f"📧 Creating notification for buyer_id: {order.get('buyer_id')}, order: {order.get('order_number')}")
            result = create_shipped_notification(
                delivery['order_id'], 
                order.get('order_number'), 
                order.get('buyer_id'), 
                order.get('total_amount')
            )
            if result:
                print(f"   ✅ Notification created successfully")
            else:
                print(f"   ⚠️ Notification creation returned False")
        except Exception as notif_error:
            print(f"   ❌ Failed to create notification: {notif_error}")
            import traceback
            traceback.print_exc()
        
        return jsonify({'success': True, 'message': 'Item marked as picked up'}), 200
        
    except Exception as e:
        print(f"Error marking item as picked up: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': f'Failed to update pickup status: {str(e)}'}), 500
