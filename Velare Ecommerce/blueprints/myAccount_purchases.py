from flask import Blueprint, render_template, session, redirect, url_for, jsonify, request
from .profile_helper import get_user_profile_data
from datetime import datetime
import sys
import os

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.supabase_helper import *

myAccount_purchases_bp = Blueprint('myAccount_purchases', __name__)

@myAccount_purchases_bp.route('/myAccount_purchases')
def myAccount_purchases():
    # Check if user is logged in
    if 'user_id' not in session:
        return redirect(url_for('auth.login'))
    
    profile = get_user_profile_data()
    
    try:
        supabase = get_supabase()
        if not supabase:
            return render_template('accounts/myAccount_purchases.html', user_profile=profile, orders=[])
        
        # Get buyer_id from session user_id
        print(f"DEBUG: Looking for buyer with user_id: {session['user_id']}")
        buyer = get_buyer_by_user_id(session['user_id'])
        print(f"DEBUG: Buyer found: {buyer}")
        
        if not buyer:
            print("DEBUG: No buyer found, returning empty orders")
            return render_template('accounts/myAccount_purchases.html', user_profile=profile, orders=[])
        
        buyer_id = buyer['buyer_id']
        print(f"DEBUG: Fetching orders for buyer_id: {buyer_id}")
        
        # Get all orders for this buyer
        orders_response = supabase.table('orders').select('''
            order_id,
            order_number,
            order_status,
            order_received,
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
        ''').eq('buyer_id', buyer_id).order('created_at', desc=True).execute()
        
        orders = []
        if orders_response.data:
            for order in orders_response.data:
                # Flatten nested data
                seller = order.get('sellers', {})
                address = order.get('addresses', {})
                delivery = order.get('deliveries', {})
                voucher = order.get('vouchers', {})
                
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
                    'created_at': order['created_at'],
                    'updated_at': order['updated_at'],
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
                
                # Get order items
                items_response = supabase.table('order_items').select('*').eq('order_id', order['order_id']).execute()
                order_data['order_items'] = []
                
                if items_response.data:
                    for item in items_response.data:
                        # Get primary image
                        image_response = supabase.table('product_images').select('image_url').eq('product_id', item['product_id']).eq('is_primary', True).limit(1).execute()
                        item['image_url'] = image_response.data[0]['image_url'] if image_response.data else None
                        order_data['order_items'].append(item)
                
                # Calculate total
                order_data['calculated_total'] = order_data['subtotal'] + order_data['shipping_fee'] - order_data['discount_amount']
                
                # Check if order has reviews
                review_response = supabase.table('product_reviews').select('review_id', count='exact').eq('order_id', order['order_id']).eq('buyer_id', buyer_id).execute()
                order_data['has_reviews'] = review_response.count > 0 if review_response.count else False
                
                orders.append(order_data)
        
        print(f"DEBUG: Found {len(orders)} orders")
        
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
            elif order['delivery_status'] in ['pending', 'assigned', 'preparing']:
                counts['pending_shipment'] += 1
            elif order['delivery_status'] == 'in_transit':
                counts['in_transit'] += 1
            elif order['delivery_status'] == 'delivered':
                if not order['order_received']:
                    counts['delivered'] += 1
        
        return render_template('accounts/myAccount_purchases.html', user_profile=profile, orders=orders, counts=counts)
        
    except Exception as err:
        print(f"Database error: {err}")
        import traceback
        traceback.print_exc()
        return render_template('accounts/myAccount_purchases.html', user_profile=profile, orders=[])

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
        order_response = supabase.table('orders').select('''
            order_status,
            order_received,
            deliveries (
                status
            )
        ''').eq('order_id', order_id).eq('buyer_id', buyer['buyer_id']).execute()
        
        if not order_response.data:
            return jsonify({'success': False, 'message': 'Order not found'}), 404
        
        order = order_response.data[0]
        delivery = order.get('deliveries', {})
        delivery_status = delivery.get('status') if isinstance(delivery, dict) else None
        
        # Check if delivery status is 'delivered'
        if delivery_status != 'delivered':
            return jsonify({'success': False, 'message': 'Order is not ready for confirmation yet'}), 400
        
        if order['order_received']:
            return jsonify({'success': False, 'message': 'Order already confirmed as received'}), 400
        
        # Update order_received to TRUE and order_status to 'delivered'
        supabase.table('orders').update({
            'order_received': True,
            'order_status': 'delivered',
            'updated_at': datetime.now().isoformat()
        }).eq('order_id', order_id).execute()
        
        return jsonify({'success': True, 'message': 'Order confirmed as received. You can now write a review!'})
        
    except Exception as e:
        print(f"Error confirming order received: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': f'Database error: {str(e)}'}), 500

@myAccount_purchases_bp.route('/api/get_order_reviews/<int:order_id>', methods=['GET'])
def get_order_reviews(order_id):
    """Get existing reviews for an order"""
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
            for review in reviews_response.data:
                # Get order item details
                item_response = supabase.table('order_items').select('product_name, variant_color, variant_size, unit_price').eq('order_id', order_id).eq('product_id', review['product_id']).execute()
                
                if item_response.data:
                    item = item_response.data[0]
                    review['product_name'] = item['product_name']
                    review['variant_color'] = item['variant_color']
                    review['variant_size'] = item['variant_size']
                    review['unit_price'] = item['unit_price']
                
                # Get primary image
                image_response = supabase.table('product_images').select('image_url').eq('product_id', review['product_id']).eq('is_primary', True).limit(1).execute()
                review['image_url'] = image_response.data[0]['image_url'] if image_response.data else None
                
                reviews.append(review)
        
        return jsonify({'success': True, 'reviews': reviews})
        
    except Exception as err:
        print(f"Database error: {err}")
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
