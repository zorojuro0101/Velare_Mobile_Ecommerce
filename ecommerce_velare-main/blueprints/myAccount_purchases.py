from flask import Blueprint, render_template, session, redirect, url_for, jsonify, request
from .profile_helper import get_user_profile_data
from datetime import datetime
from dateutil import parser
import sys
import os

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.supabase_helper import *

myAccount_purchases_bp = Blueprint('myAccount_purchases', __name__)

@myAccount_purchases_bp.route('/myAccount_purchases')
def myAccount_purchases():
    """🛍️ Render purchases page with optimized data loading"""
    print("=" * 80)
    print("🛍️ [PURCHASES PAGE] Loading purchases page...")
    print("=" * 80)
    
    # Check if user is logged in
    if 'user_id' not in session:
        return redirect(url_for('auth.login'))
    
    profile = get_user_profile_data()
    
    try:
        supabase = get_supabase()
        if not supabase:
            print("❌ Supabase connection failed")
            return render_template('accounts/myAccount_purchases.html', user_profile=profile, orders=[])
        
        # Get buyer_id from session user_id
        print(f"🔍 Looking for buyer with user_id: {session['user_id']}")
        buyer = get_buyer_by_user_id(session['user_id'])
        
        if not buyer:
            print("❌ No buyer found, returning empty orders")
            return render_template('accounts/myAccount_purchases.html', user_profile=profile, orders=[])
        
        buyer_id = buyer['buyer_id']
        print(f"📦 Fetching orders for buyer_id: {buyer_id}")
        
        # Get orders for this buyer (limit to 50 most recent for performance)
        orders_response = supabase.table('orders').select('''
            order_id,
            order_number,
            order_status,
            order_received,
            seller_id,
            address_id,
            subtotal,
            shipping_fee,
            discount_amount,
            total_amount,
            voucher_id,
            created_at,
            updated_at,
            sellers (
                shop_name,
                shop_logo
            ),
            addresses (
                full_address,
                city,
                province
            ),
            deliveries (
                status
            ),
            vouchers (
                voucher_code,
                voucher_name,
                voucher_type
            )
        ''').eq('buyer_id', buyer_id).order('created_at', desc=True).limit(50).execute()
        
        print(f"✅ Found {len(orders_response.data) if orders_response.data else 0} orders")
        
        orders = []
        if orders_response.data:
            # Get all order_ids to fetch items and reviews in batch (NO N+1 QUERY)
            order_ids = [o['order_id'] for o in orders_response.data]
            
            # Fetch ALL order items at once
            all_items_response = supabase.table('order_items').select('*').in_('order_id', order_ids).execute()
            items_by_order = {}
            product_ids = set()
            
            if all_items_response.data:
                for item in all_items_response.data:
                    order_id = item['order_id']
                    if order_id not in items_by_order:
                        items_by_order[order_id] = []
                    items_by_order[order_id].append(item)
                    product_ids.add(item['product_id'])
            
            # Fetch ALL primary product images at once
            images_by_product = {}
            if product_ids:
                all_images_response = supabase.table('product_images').select('product_id, image_url').in_('product_id', list(product_ids)).eq('is_primary', True).execute()
                if all_images_response.data:
                    images_by_product = {img['product_id']: img['image_url'] for img in all_images_response.data}
            
            # Fetch ALL review counts at once
            reviews_by_order = {}
            all_reviews_response = supabase.table('product_reviews').select('order_id', count='exact').in_('order_id', order_ids).eq('buyer_id', buyer_id).execute()
            if all_reviews_response.data:
                # Count reviews per order
                for review in all_reviews_response.data:
                    order_id = review['order_id']
                    reviews_by_order[order_id] = reviews_by_order.get(order_id, 0) + 1

            # Fallback: fetch sellers/addresses/vouchers/deliveries directly in
            # case the nested PostgREST joins didn't resolve on this Supabase
            # project (happens on Railway when the FK metadata cache is stale
            # or RLS blocks the nested read). Without this, the purchases page
            # ends up missing shop_name and shop_logo.
            seller_ids = set()
            address_ids = set()
            voucher_ids = set()
            for o in orders_response.data:
                if o.get('seller_id'):
                    seller_ids.add(o['seller_id'])
                if o.get('address_id'):
                    address_ids.add(o['address_id'])
                if o.get('voucher_id'):
                    voucher_ids.add(o['voucher_id'])

            sellers_by_id = {}
            if seller_ids:
                try:
                    s_resp = supabase.table('sellers').select(
                        'seller_id, shop_name, shop_logo'
                    ).in_('seller_id', list(seller_ids)).execute()
                    if s_resp.data:
                        sellers_by_id = {s['seller_id']: s for s in s_resp.data}
                except Exception as fb_err:
                    print(f"⚠️ Seller fallback fetch failed: {fb_err}")

            addresses_by_id = {}
            if address_ids:
                try:
                    a_resp = supabase.table('addresses').select(
                        'address_id, full_address, city, province'
                    ).in_('address_id', list(address_ids)).execute()
                    if a_resp.data:
                        addresses_by_id = {a['address_id']: a for a in a_resp.data}
                except Exception as fb_err:
                    print(f"⚠️ Address fallback fetch failed: {fb_err}")

            vouchers_by_id = {}
            if voucher_ids:
                try:
                    v_resp = supabase.table('vouchers').select(
                        'voucher_id, voucher_code, voucher_name, voucher_type'
                    ).in_('voucher_id', list(voucher_ids)).execute()
                    if v_resp.data:
                        vouchers_by_id = {v['voucher_id']: v for v in v_resp.data}
                except Exception as fb_err:
                    print(f"⚠️ Voucher fallback fetch failed: {fb_err}")

            deliveries_by_order = {}
            try:
                d_resp = supabase.table('deliveries').select(
                    'order_id, status'
                ).in_('order_id', order_ids).execute()
                if d_resp.data:
                    deliveries_by_order = {d['order_id']: d for d in d_resp.data}
            except Exception as fb_err:
                print(f"⚠️ Delivery fallback fetch failed: {fb_err}")

            print(f"📊 Batch fetched: {len(items_by_order)} orders with items, {len(images_by_product)} product images, {len(reviews_by_order)} orders with reviews")
            
            for order in orders_response.data:
                # Flatten nested data - handle both single objects and arrays.
                # If the nested join is empty (Railway/FK-cache issue), fall
                # back to the dictionaries we just built directly above.
                seller_data = order.get('sellers', {})
                seller = seller_data[0] if isinstance(seller_data, list) and seller_data else (seller_data if isinstance(seller_data, dict) else {})
                if not seller and order.get('seller_id'):
                    seller = sellers_by_id.get(order['seller_id'], {})

                address_data = order.get('addresses', {})
                address = address_data[0] if isinstance(address_data, list) and address_data else (address_data if isinstance(address_data, dict) else {})
                if not address and order.get('address_id'):
                    address = addresses_by_id.get(order['address_id'], {})

                delivery_data = order.get('deliveries', {})
                delivery = delivery_data[0] if isinstance(delivery_data, list) and delivery_data else (delivery_data if isinstance(delivery_data, dict) else {})
                if not delivery:
                    delivery = deliveries_by_order.get(order['order_id'], {})

                voucher_data = order.get('vouchers', {})
                voucher = voucher_data[0] if isinstance(voucher_data, list) and voucher_data else (voucher_data if isinstance(voucher_data, dict) else {})
                if not voucher and order.get('voucher_id'):
                    voucher = vouchers_by_id.get(order['voucher_id'], {})
                
                order_data = {
                    'order_id': order['order_id'],
                    'order_number': order['order_number'],
                    'order_status': order['order_status'],
                    'order_received': order['order_received'],
                    'subtotal': order['subtotal'],
                    'shipping_fee': order['shipping_fee'],
                    'discount_amount': order['discount_amount'],
                    'total_amount': order['total_amount'],
                    'voucher_id': order['voucher_id'],
                    'created_at': parser.parse(order['created_at']) if order.get('created_at') else None,
                    'updated_at': parser.parse(order['updated_at']) if order.get('updated_at') else None,
                    'shop_name': seller.get('shop_name') if isinstance(seller, dict) else None,
                    'shop_logo': seller.get('shop_logo') if isinstance(seller, dict) else None,
                    'full_address': address.get('full_address') if isinstance(address, dict) else None,
                    'city': address.get('city') if isinstance(address, dict) else None,
                    'province': address.get('province') if isinstance(address, dict) else None,
                    'delivery_status': delivery.get('status') if isinstance(delivery, dict) else None,
                    'voucher_code': voucher.get('voucher_code') if isinstance(voucher, dict) else None,
                    'voucher_name': voucher.get('voucher_name') if isinstance(voucher, dict) else None,
                    'voucher_type': voucher.get('voucher_type') if isinstance(voucher, dict) else None
                }
                
                # Get order items from pre-fetched data
                order_data['order_items'] = []
                order_items = items_by_order.get(order['order_id'], [])
                
                for item in order_items:
                    # Get image from pre-fetched data
                    item['image_url'] = images_by_product.get(item['product_id'])
                    order_data['order_items'].append(item)
                
                # Calculate total
                order_data['calculated_total'] = order_data['subtotal'] + order_data['shipping_fee'] - order_data['discount_amount']
                
                # Check if order has reviews from pre-fetched data
                order_data['has_reviews'] = reviews_by_order.get(order['order_id'], 0) > 0
                
                orders.append(order_data)
        
        print(f"✅ Processed {len(orders)} orders with all data")
        
        # Calculate counts for each tab
        counts = {
            'pending_shipment': 0,
            'in_transit': 0,
            'delivered': 0,
            'cancelled': 0
        }
        
        for order in orders:
            if order['order_status'] == 'cancelled':
                counts['cancelled'] += 1
            elif order['delivery_status'] in ['pending', 'assigned', 'preparing'] or order['delivery_status'] is None:
                counts['pending_shipment'] += 1
            elif order['delivery_status'] == 'in_transit':
                counts['in_transit'] += 1
            elif order['delivery_status'] == 'delivered':
                if not order['order_received']:
                    counts['delivered'] += 1
        
        return render_template('accounts/myAccount_purchases.html', user_profile=profile, orders=orders, counts=counts)
        
    except Exception as err:
        print(f"❌ Database error: {err}")
        import traceback
        traceback.print_exc()
        return render_template('accounts/myAccount_purchases.html', user_profile=profile, orders=[], counts={'pending_shipment': 0, 'in_transit': 0, 'delivered': 0, 'cancelled': 0})

@myAccount_purchases_bp.route('/api/cancel_order/<int:order_id>', methods=['POST'])
def cancel_order(order_id):
    """Cancel an order"""
    if 'user_id' not in session:
        return jsonify({'success': False, 'message': 'Not authenticated'}), 401
    
    try:
        supabase = get_supabase()
        if not supabase:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        # Get buyer_id
        buyer = get_buyer_by_user_id(session['user_id'])
        
        if not buyer:
            return jsonify({'success': False, 'message': 'Buyer not found'}), 404
        
        # Verify order belongs to this buyer and can be cancelled
        order_response = supabase.table('orders').select('''
            order_status,
            deliveries (
                status
            )
        ''').eq('order_id', order_id).eq('buyer_id', buyer['buyer_id']).execute()
        
        if not order_response.data:
            return jsonify({'success': False, 'message': 'Order not found'}), 404
        
        order = order_response.data[0]
        delivery = order.get('deliveries', {})
        delivery_status = delivery.get('status') if isinstance(delivery, dict) else None
        
        # Only allow cancellation if delivery status is 'pending' or 'assigned'
        if delivery_status not in ['pending', 'assigned', None]:
            return jsonify({'success': False, 'message': 'Order cannot be cancelled at this stage'}), 400
        
        # Get order items to restore stock
        items_response = supabase.table('order_items').select('product_id, quantity, variant_color, variant_size').eq('order_id', order_id).execute()
        
        if items_response.data:
            for item in items_response.data:
                # Get current total_sold
                product = get_product(item['product_id'])
                if product:
                    new_total_sold = max(0, (product.get('total_sold') or 0) - item['quantity'])
                    supabase.table('products').update({'total_sold': new_total_sold}).eq('product_id', item['product_id']).execute()
                
                # Restore variant stock
                if item.get('variant_color') and item.get('variant_size'):
                    variant_response = supabase.table('product_variants').select('variant_id, stock_quantity').eq('product_id', item['product_id']).eq('color', item['variant_color']).eq('size', item['variant_size']).execute()
                    
                    if variant_response.data:
                        variant = variant_response.data[0]
                        new_stock = variant['stock_quantity'] + item['quantity']
                        supabase.table('product_variants').update({'stock_quantity': new_stock}).eq('variant_id', variant['variant_id']).execute()
        
        # Update order status to cancelled
        supabase.table('orders').update({
            'order_status': 'cancelled',
            'updated_at': datetime.now().isoformat()
        }).eq('order_id', order_id).execute()
        
        return jsonify({'success': True, 'message': 'Order cancelled successfully'})
        
    except Exception as err:
        print(f"Database error: {err}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': 'Database error'}), 500

@myAccount_purchases_bp.route('/api/confirm_order_received/<int:order_id>', methods=['POST'])
def confirm_order_received(order_id):
    """Confirm that the buyer has received the order"""
    if 'user_id' not in session:
        return jsonify({'success': False, 'message': 'Not authenticated'}), 401
    
    try:
        supabase = get_supabase()
        if not supabase:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        # Get buyer_id
        buyer = get_buyer_by_user_id(session['user_id'])
        
        if not buyer:
            return jsonify({'success': False, 'message': 'Buyer not found'}), 404
        
        # Verify order belongs to this buyer and check delivery status
        print(f"🔍 Confirming order_id: {order_id} for buyer_id: {buyer['buyer_id']}")
        order_response = supabase.table('orders').select('''
            order_status,
            order_received,
            deliveries (
                status
            )
        ''').eq('order_id', order_id).eq('buyer_id', buyer['buyer_id']).execute()
        
        if not order_response.data:
            print(f"❌ Order {order_id} not found")
            return jsonify({'success': False, 'message': 'Order not found'}), 404
        
        order = order_response.data[0]
        print(f"📦 Order data: {order}")
        
        # Handle delivery data - can be array, dict, or None
        delivery_data = order.get('deliveries', {})
        print(f"🚚 Delivery data type: {type(delivery_data)}, value: {delivery_data}")
        
        # Extract delivery status
        if isinstance(delivery_data, list):
            delivery_status = delivery_data[0].get('status') if delivery_data else None
        elif isinstance(delivery_data, dict):
            delivery_status = delivery_data.get('status')
        else:
            delivery_status = None
        
        print(f"📋 Order status: {order['order_status']}, Delivery status: {delivery_status}, Order received: {order['order_received']}")
        
        # Check if delivery status is 'delivered'
        if delivery_status != 'delivered':
            print(f"❌ Delivery status is '{delivery_status}', not 'delivered'")
            return jsonify({'success': False, 'message': f'Order is not ready for confirmation yet. Current status: {delivery_status}'}), 400
        
        if order['order_received']:
            print(f"❌ Order already confirmed as received")
            return jsonify({'success': False, 'message': 'Order already confirmed as received'}), 400
        
        # Update order_received to TRUE and order_status to 'delivered'
        print(f"✅ Updating order {order_id}: order_received=True, order_status='delivered'")
        supabase.table('orders').update({
            'order_received': True,
            'order_status': 'delivered',
            'updated_at': datetime.now().isoformat()
        }).eq('order_id', order_id).execute()
        
        print(f"🎉 Order {order_id} confirmed as received!")
        return jsonify({'success': True, 'message': 'Order confirmed as received. You can now write a review!'})
        
    except Exception as e:
        print(f"❌ Error confirming order received: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': f'Database error: {str(e)}'}), 500

@myAccount_purchases_bp.route('/api/get_order_reviews/<int:order_id>', methods=['GET'])
def get_order_reviews(order_id):
    """Get existing reviews for an order (optimized - no N+1 queries)"""
    if 'user_id' not in session:
        return jsonify({'success': False, 'message': 'Not authenticated'}), 401
    
    try:
        supabase = get_supabase()
        if not supabase:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        # Get buyer_id
        buyer = get_buyer_by_user_id(session['user_id'])
        
        if not buyer:
            return jsonify({'success': False, 'message': 'Buyer not found'}), 404
        
        # Get reviews for this order
        reviews_response = supabase.table('product_reviews').select('''
            review_id,
            product_id,
            rating,
            review_text
        ''').eq('order_id', order_id).eq('buyer_id', buyer['buyer_id']).execute()
        
        reviews = []
        if reviews_response.data:
            # Get all product_ids to fetch data in batch (NO N+1 QUERY)
            product_ids = [r['product_id'] for r in reviews_response.data]
            
            # Fetch ALL order items at once
            items_by_product = {}
            items_response = supabase.table('order_items').select('product_id, product_name, variant_color, variant_size, unit_price').eq('order_id', order_id).in_('product_id', product_ids).execute()
            if items_response.data:
                items_by_product = {item['product_id']: item for item in items_response.data}
            
            # Fetch ALL primary images at once
            images_by_product = {}
            images_response = supabase.table('product_images').select('product_id, image_url').in_('product_id', product_ids).eq('is_primary', True).execute()
            if images_response.data:
                images_by_product = {img['product_id']: img['image_url'] for img in images_response.data}
            
            # Build reviews with pre-fetched data
            for review in reviews_response.data:
                product_id = review['product_id']
                item = items_by_product.get(product_id, {})
                
                review['product_name'] = item.get('product_name')
                review['variant_color'] = item.get('variant_color')
                review['variant_size'] = item.get('variant_size')
                review['unit_price'] = item.get('unit_price')
                review['image_url'] = images_by_product.get(product_id)
                
                reviews.append(review)
        
        return jsonify({'success': True, 'reviews': reviews})
        
    except Exception as err:
        print(f"❌ Database error: {err}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': 'Database error'}), 500

@myAccount_purchases_bp.route('/api/submit_review', methods=['POST'])
def submit_review():
    """Submit a product review"""
    if 'user_id' not in session:
        return jsonify({'success': False, 'message': 'Not authenticated'}), 401
    
    try:
        data = request.get_json()
        order_id = data.get('order_id')
        product_id = data.get('product_id')
        rating = data.get('rating')
        review_text = data.get('review_text', '').strip()
        
        # Validate input
        if not all([order_id, product_id, rating]):
            return jsonify({'success': False, 'message': 'Missing required fields'}), 400
        
        if not (1 <= int(rating) <= 5):
            return jsonify({'success': False, 'message': 'Rating must be between 1 and 5'}), 400
        
        supabase = get_supabase()
        if not supabase:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        # Get buyer_id
        buyer = get_buyer_by_user_id(session['user_id'])
        
        if not buyer:
            return jsonify({'success': False, 'message': 'Buyer not found'}), 404
        
        buyer_id = buyer['buyer_id']
        
        # Verify order belongs to buyer and order_received is TRUE
        order_response = supabase.table('orders').select('order_received').eq('order_id', order_id).eq('buyer_id', buyer_id).execute()
        
        if not order_response.data:
            return jsonify({'success': False, 'message': 'Order not found'}), 404
        
        if not order_response.data[0]['order_received']:
            return jsonify({'success': False, 'message': 'Please confirm order received first'}), 400
        
        # Check if review already exists
        existing_response = supabase.table('product_reviews').select('review_id').eq('buyer_id', buyer_id).eq('product_id', product_id).eq('order_id', order_id).execute()
        
        if existing_response.data:
            # Update existing review
            supabase.table('product_reviews').update({
                'rating': rating,
                'review_text': review_text,
                'created_at': datetime.now().isoformat()
            }).eq('review_id', existing_response.data[0]['review_id']).execute()
        else:
            # Insert new review
            supabase.table('product_reviews').insert({
                'buyer_id': buyer_id,
                'product_id': product_id,
                'order_id': order_id,
                'rating': rating,
                'review_text': review_text,
                'created_at': datetime.now().isoformat()
            }).execute()
        
        # Update product rating and total_reviews
        reviews_response = supabase.table('product_reviews').select('rating').eq('product_id', product_id).execute()
        
        if reviews_response.data:
            total_reviews = len(reviews_response.data)
            avg_rating = sum(r['rating'] for r in reviews_response.data) / total_reviews
            
            supabase.table('products').update({
                'total_reviews': total_reviews,
                'rating': avg_rating
            }).eq('product_id', product_id).execute()
        
        return jsonify({'success': True, 'message': 'Review submitted successfully!'})
        
    except Exception as err:
        print(f"Database error: {err}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': 'Database error'}), 500
    except Exception as e:
        print(f"Error: {e}")
        return jsonify({'success': False, 'message': str(e)}), 500
