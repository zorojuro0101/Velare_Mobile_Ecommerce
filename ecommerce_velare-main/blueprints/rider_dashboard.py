from flask import Blueprint, render_template, session, redirect, url_for, jsonify
import sys
import os

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.supabase_helper import *
from utils.auth_decorators import rider_required

rider_dashboard_bp = Blueprint('rider_dashboard', __name__)

@rider_dashboard_bp.route('/rider/dashboard')
@rider_required
def rider_dashboard():
    print(f"\n{'='*80}")
    print(f"🏍️ [RIDER DASHBOARD] Loading dashboard...")
    print(f"{'='*80}\n")
    
    try:
        # Get rider information from Supabase
        rider_data = get_rider_by_user_id(session['user_id'])
        
        if not rider_data:
            print("❌ Rider profile not found")
            return render_template('rider/rider_dashboard.html', error='Rider profile not found')
        
        print(f"✅ Rider: {rider_data.get('first_name')} {rider_data.get('last_name')}")
        print(f"{'='*80}\n")
        return render_template('rider/rider_dashboard.html', rider=rider_data)
        
    except Exception as e:
        print(f"❌ Error fetching rider data: {e}")
        return render_template('rider/rider_dashboard.html', error='Failed to load rider data')

@rider_dashboard_bp.route('/rider/dashboard/api/summary', methods=['GET'])
def get_dashboard_summary():
    """API endpoint to fetch dashboard summary statistics"""
    print(f"\n{'='*80}")
    print(f"📊 [DASHBOARD SUMMARY] Loading statistics...")
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
        
        # Get dashboard summary from Supabase
        summary = get_rider_dashboard_summary(rider_id)
        
        if not summary:
            return jsonify({'error': 'Failed to fetch summary data'}), 500
        
        # Count completed deliveries
        supabase = get_supabase()
        completed_response = supabase.table('deliveries').select('delivery_id', count='exact').eq('rider_id', rider_id).eq('status', 'delivered').execute()
        completed_deliveries = completed_response.count if completed_response.count else 0

        print(f"📦 Pending pickups: {summary['pending_pickups']}")
        print(f"🚚 Active deliveries: {summary['active_deliveries']}")
        print(f"✅ Completed deliveries: {completed_deliveries}")
        print(f"💰 Total earnings: ₱{summary['total_earnings']}")
        print(f"💵 Today's earnings: ₱{summary['today_earnings']}")
        print(f"{'='*80}\n")

        return jsonify({
            'success': True,
            'summary': {
                'pendingPickups': summary['pending_pickups'],
                'activeDeliveries': summary['active_deliveries'],
                'completedDeliveries': completed_deliveries,
                'totalEarnings': summary['total_earnings'],
                'todayEarnings': summary['today_earnings']
            }
        }), 200
        
    except Exception as e:
        print(f"❌ Error fetching dashboard summary: {e}")
        return jsonify({'error': 'Failed to fetch summary data'}), 500

@rider_dashboard_bp.route('/rider/dashboard/api/pending-pickups', methods=['GET'])
def get_pending_pickups_summary():
    """API endpoint to fetch pending pickups for dashboard summary"""
    print(f"\n{'='*80}")
    print(f"📦 [PENDING PICKUPS] Loading pending pickups...")
    print(f"{'='*80}\n")
    
    if 'user_id' not in session or session.get('user_type') != 'rider':
        return jsonify({'error': 'Unauthorized'}), 401
    
    try:
        # Fetch pending deliveries from Supabase (limit to 3 for dashboard)
        supabase = get_supabase()
        
        response = supabase.table('deliveries').select('''
            delivery_id,
            pickup_address,
            orders (
                order_number,
                buyers (
                    first_name,
                    last_name,
                    phone_number
                ),
                sellers (
                    shop_name,
                    first_name,
                    last_name,
                    phone_number
                )
            )
        ''').eq('status', 'pending').is_('rider_id', 'null').neq('orders.order_status', 'cancelled').order('created_at', desc=True).limit(3).execute()
        
        pickups = clean_supabase_data(response.data) if response.data else []
        print(f"📦 Found {len(pickups)} pending pickups")
        
        # Format the data
        formatted_pickups = []
        for pickup in pickups:
            order = pickup.get('orders', {})
            buyer = order.get('buyers', {})
            seller = order.get('sellers', {})
            
            formatted_pickup = {
                'deliveryId': pickup.get('delivery_id'),
                'orderId': order.get('order_number'),
                'buyer': {
                    'name': f"{buyer.get('first_name', '')} {buyer.get('last_name', '')}",
                    'address': pickup.get('pickup_address')
                },
                'seller': {
                    'name': f"{seller.get('first_name', '')} {seller.get('last_name', '')}",
                    'storeName': seller.get('shop_name'),
                    'storeAddress': pickup.get('pickup_address'),
                    'phone': seller.get('phone_number')
                }
            }
            
            formatted_pickups.append(formatted_pickup)
        
        print(f"✅ Returning {len(formatted_pickups)} pickups")
        print(f"{'='*80}\n")
        return jsonify({'success': True, 'pickups': formatted_pickups}), 200
        
    except Exception as e:
        print(f"❌ Error fetching pending pickups: {e}")
        return jsonify({'error': 'Failed to fetch pickups'}), 500

@rider_dashboard_bp.route('/rider/dashboard/api/active-deliveries', methods=['GET'])
def get_active_deliveries_summary():
    """API endpoint to fetch active deliveries for dashboard summary"""
    print(f"\n{'='*80}")
    print(f"🚚 [ACTIVE DELIVERIES] Loading active deliveries...")
    print(f"{'='*80}\n")
    
    if 'user_id' not in session or session.get('user_type') != 'rider':
        return jsonify({'error': 'Unauthorized'}), 401
    
    try:
        # Get rider_id
        rider = get_rider_by_user_id(session['user_id'])
        
        if not rider:
            return jsonify({'error': 'Rider not found'}), 404
        
        rider_id = rider['rider_id']
        print(f"🔍 Rider ID: {rider_id}")
        
        # Fetch active deliveries from Supabase (limit to 3 for dashboard)
        supabase = get_supabase()
        
        response = supabase.table('deliveries').select('''
            delivery_id,
            orders (
                order_number,
                total_amount,
                address_id,
                buyers (
                    first_name,
                    last_name
                ),
                sellers (
                    shop_name
                )
            )
        ''').eq('rider_id', rider_id).in_('status', ['assigned', 'in_transit']).neq('orders.order_status', 'cancelled').order('assigned_at', desc=True).limit(3).execute()
        
        deliveries = clean_supabase_data(response.data) if response.data else []
        print(f"📦 Found {len(deliveries)} active deliveries")
        
        # Collect all address IDs for batch fetching
        address_ids = []
        for delivery in deliveries:
            order = delivery.get('orders', {})
            address_id = order.get('address_id')
            if address_id and address_id not in address_ids:
                address_ids.append(address_id)
        
        # Batch fetch all addresses
        addresses_dict = {}
        if address_ids:
            print(f"📍 Batch fetching {len(address_ids)} addresses...")
            addr_response = supabase.table('addresses').select('address_id, full_address').in_('address_id', address_ids).execute()
            if addr_response.data:
                addresses_dict = {addr['address_id']: addr['full_address'] for addr in addr_response.data}
            print(f"✅ Found {len(addresses_dict)} addresses")
        
        # Format the data
        formatted_deliveries = []
        for delivery in deliveries:
            order = delivery.get('orders', {})
            buyer = order.get('buyers', {})
            seller = order.get('sellers', {})
            
            # Get address from batch data
            address_id = order.get('address_id')
            buyer_address = addresses_dict.get(address_id, 'N/A')
            
            formatted_deliveries.append({
                'orderId': order.get('order_number'),
                'item': {
                    'storeName': seller.get('shop_name')
                },
                'buyer': {
                    'name': f"{buyer.get('first_name', '')} {buyer.get('last_name', '')}",
                    'address': buyer_address
                },
                'amount': float(order.get('total_amount', 0))
            })
        
        print(f"✅ Returning {len(formatted_deliveries)} deliveries")
        print(f"{'='*80}\n")
        return jsonify({'success': True, 'deliveries': formatted_deliveries}), 200
        
    except Exception as e:
        print(f"❌ Error fetching active deliveries: {e}")
        return jsonify({'error': 'Failed to fetch deliveries'}), 500

@rider_dashboard_bp.route('/rider/dashboard/api/earnings-summary', methods=['GET'])
def get_earnings_summary():
    """API endpoint to fetch earnings for dashboard summary"""
    print(f"\n{'='*80}")
    print(f"💰 [EARNINGS SUMMARY] Loading earnings...")
    print(f"{'='*80}\n")
    
    if 'user_id' not in session or session.get('user_type') != 'rider':
        return jsonify({'error': 'Unauthorized'}), 401
    
    try:
        # Get rider_id
        rider = get_rider_by_user_id(session['user_id'])
        
        if not rider:
            return jsonify({'error': 'Rider not found'}), 404
        
        rider_id = rider['rider_id']
        print(f"🔍 Rider ID: {rider_id}")
        
        # Fetch recent earnings from Supabase (limit to 3 for dashboard)
        supabase = get_supabase()
        
        response = supabase.table('deliveries').select('''
            delivery_id,
            rider_earnings,
            delivered_at,
            orders (
                order_number,
                address_id,
                buyers (
                    first_name,
                    last_name
                ),
                sellers (
                    shop_name,
                    first_name,
                    last_name
                ),
                order_items (
                    products (
                        product_name
                    )
                )
            )
        ''').eq('rider_id', rider_id).eq('status', 'delivered').order('delivered_at', desc=True).limit(3).execute()
        
        earnings = clean_supabase_data(response.data) if response.data else []
        print(f"💵 Found {len(earnings)} earnings records")
        
        # Collect all address IDs for batch fetching
        address_ids = []
        for earning in earnings:
            order = earning.get('orders', {})
            address_id = order.get('address_id')
            if address_id and address_id not in address_ids:
                address_ids.append(address_id)
        
        # Batch fetch all addresses
        addresses_dict = {}
        if address_ids:
            print(f"📍 Batch fetching {len(address_ids)} addresses...")
            addr_response = supabase.table('addresses').select('address_id, full_address').in_('address_id', address_ids).execute()
            if addr_response.data:
                addresses_dict = {addr['address_id']: addr['full_address'] for addr in addr_response.data}
            print(f"✅ Found {len(addresses_dict)} addresses")
        
        # Format the data
        formatted_earnings = []
        for earning in earnings:
            order = earning.get('orders', {})
            buyer = order.get('buyers', {})
            seller = order.get('sellers', {})
            order_items = order.get('order_items', [])
            
            # Get address from batch data
            address_id = order.get('address_id')
            buyer_address = addresses_dict.get(address_id, 'N/A')
            
            # Get product name from first order item
            product_name = 'N/A'
            if order_items and len(order_items) > 0:
                product = order_items[0].get('products', {})
                product_name = product.get('product_name', 'N/A')
            
            # Parse delivered_at
            delivered_date = None
            if earning.get('delivered_at'):
                from datetime import datetime
                try:
                    delivered_date = datetime.fromisoformat(earning['delivered_at'].replace('Z', '+00:00')).strftime('%Y-%m-%d')
                except:
                    delivered_date = None
            
            formatted_earnings.append({
                'orderId': order.get('order_number'),
                'buyer': {
                    'name': f"{buyer.get('first_name', '')} {buyer.get('last_name', '')}",
                    'address': buyer_address,
                    'deliveryDate': delivered_date
                },
                'seller': {
                    'name': f"{seller.get('first_name', '')} {seller.get('last_name', '')}",
                    'storeName': seller.get('shop_name')
                },
                'productName': product_name,
                'amount': float(earning.get('rider_earnings', 0) or 0)
            })
        
        print(f"✅ Returning {len(formatted_earnings)} earnings")
        print(f"{'='*80}\n")
        return jsonify({'success': True, 'earnings': formatted_earnings}), 200
        
    except Exception as e:
        print(f"❌ Error fetching earnings summary: {e}")
        return jsonify({'error': 'Failed to fetch earnings'}), 500
