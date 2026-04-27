from flask import Blueprint, request, session, jsonify
import sys
import os
from decimal import Decimal
from datetime import datetime

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.supabase_helper import *

checkout_order_bp = Blueprint('checkout_order', __name__)

@checkout_order_bp.route('/place_order', methods=['POST'])
def place_order():
    # Check if user is logged in
    if 'user_id' not in session or not session.get('logged_in'):
        return jsonify({'success': False, 'message': 'Not logged in'}), 401
    
    try:
        data = request.get_json()
        
        # Get required data
        cart_ids = data.get('cart_ids', [])
        address_id = data.get('address_id')
        subtotal = Decimal(str(data.get('subtotal', 0)))
        shipping_fee = Decimal(str(data.get('shipping_fee', 0)))
        discount_amount = Decimal(str(data.get('discount_amount', 0)))
        total_amount = Decimal(str(data.get('total_amount', 0)))
        voucher_type = data.get('voucher_type')
        buyer_voucher_id = data.get('voucher_id')
        
        # Check if free shipping voucher is applied
        is_free_shipping = (voucher_type == 'free_shipping')
        
        if not cart_ids or not address_id:
            return jsonify({'success': False, 'message': 'Missing required data'}), 400
        
        supabase = get_supabase()
        if not supabase:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Get buyer_id
            buyer = get_buyer_by_user_id(session['user_id'])
            
            if not buyer:
                return jsonify({'success': False, 'message': 'Buyer account not found'}), 404
            
            buyer_id = buyer['buyer_id']
            
            # Get actual voucher_id from buyer_voucher_id
            print(f"VOUCHER DEBUG:")
            print(f"  voucher_type: {voucher_type}")
            print(f"  buyer_voucher_id: {buyer_voucher_id}")
            
            actual_voucher_id = None
            if buyer_voucher_id:
                voucher_response = supabase.table('buyer_vouchers').select('voucher_id').eq('buyer_voucher_id', buyer_voucher_id).eq('buyer_id', buyer_id).execute()
                if voucher_response.data:
                    actual_voucher_id = voucher_response.data[0]['voucher_id']
                    print(f"  Found voucher_id: {actual_voucher_id}")
            
            voucher_id = actual_voucher_id
            
            # Get cart items with variant information and stock
            cart_response = supabase.table('cart').select('''
                cart_id,
                product_id,
                quantity,
                variant_id,
                products (
                    product_name,
                    materials,
                    price,
                    seller_id
                ),
                product_variants (
                    color,
                    size,
                    stock_quantity
                )
            ''').in_('cart_id', cart_ids).execute()
            
            if not cart_response.data:
                return jsonify({'success': False, 'message': 'No items found'}), 404
            
            # Flatten cart items
            cart_items = []
            for item in cart_response.data:
                product = item.get('products', {})
                variant = item.get('product_variants', {})
                
                cart_items.append({
                    'cart_id': item['cart_id'],
                    'product_id': item['product_id'],
                    'quantity': item['quantity'],
                    'variant_id': item['variant_id'],
                    'product_name': product.get('product_name'),
                    'materials': product.get('materials'),
                    'price': product.get('price'),
                    'seller_id': product.get('seller_id'),
                    'variant_color': variant.get('color') if variant else None,
                    'variant_size': variant.get('size') if variant else None,
                    'variant_stock': variant.get('stock_quantity') if variant else None
                })
            
            # Validate stock availability
            for item in cart_items:
                if not item.get('variant_id'):
                    return jsonify({'success': False, 'message': f"Please select a variant for {item['product_name']}."}), 400
                
                if item.get('variant_stock') is None:
                    return jsonify({'success': False, 'message': f"Variant for {item['product_name']} is no longer available."}), 400
                
                if item['variant_stock'] <= 0:
                    return jsonify({'success': False, 'message': f"{item['product_name']} is out of stock."}), 400
                
                if item['quantity'] > item['variant_stock']:
                    return jsonify({'success': False, 'message': f"Insufficient stock for {item['product_name']}."}), 400
            
            # Group items by seller
            from collections import defaultdict
            seller_items = defaultdict(list)
            for item in cart_items:
                seller_items[item['seller_id']].append(item)
            
            # Get starting order number
            current_year = datetime.now().year
            last_order_response = supabase.table('orders').select('order_number').like('order_number', f'VEL-{current_year}-%').order('order_id', desc=True).limit(1).execute()
            
            if last_order_response.data:
                try:
                    last_num = int(last_order_response.data[0]['order_number'].split('-')[-1])
                    next_num = last_num + 1
                except (ValueError, IndexError):
                    next_num = 1
            else:
                next_num = 1
            
            # Create orders for each seller
            order_ids = []
            num_sellers = len(seller_items)
            
            for seller_id, items in seller_items.items():
                seller_subtotal = sum(Decimal(str(item['price'])) * item['quantity'] for item in items)
                seller_shipping = shipping_fee / num_sellers
                seller_discount = discount_amount / num_sellers
                commission_amount = seller_subtotal * Decimal('0.05')
                seller_total = seller_subtotal + seller_shipping - seller_discount
                
                order_number = f'VEL-{current_year}-{next_num:04d}'
                next_num += 1
                
                # Insert order
                order_data = {
                    'order_number': order_number,
                    'buyer_id': buyer_id,
                    'seller_id': seller_id,
                    'address_id': address_id,
                    'subtotal': float(seller_subtotal),
                    'shipping_fee': float(seller_shipping),
                    'discount_amount': float(seller_discount),
                    'total_amount': float(seller_total),
                    'commission_amount': float(commission_amount),
                    'voucher_id': voucher_id,
                    'order_status': 'pending'
                }
                
                order_response = supabase.table('orders').insert(order_data).execute()
                if not order_response.data:
                    raise Exception("Failed to create order")
                
                order_id = order_response.data[0]['order_id']
                order_ids.append(order_id)
                
                # Get seller address
                seller_response = supabase.table('sellers').select('shop_name').eq('seller_id', seller_id).execute()
                pickup_address = seller_response.data[0]['shop_name'] if seller_response.data else 'N/A'
                
                # Get buyer address
                address_response = supabase.table('addresses').select('full_address').eq('address_id', address_id).execute()
                delivery_address = address_response.data[0]['full_address'] if address_response.data else 'N/A'
                
                # Calculate delivery fee
                actual_delivery_fee = Decimal('49.00') / num_sellers if is_free_shipping else shipping_fee / num_sellers
                
                # Create delivery record
                delivery_data = {
                    'order_id': order_id,
                    'pickup_address': pickup_address,
                    'delivery_address': delivery_address,
                    'delivery_fee': float(actual_delivery_fee),
                    'paid_by_platform': is_free_shipping,
                    'status': None
                }
                supabase.table('deliveries').insert(delivery_data).execute()
                
                # Insert order items and update stock
                for item in items:
                    item_subtotal = Decimal(str(item['price'])) * item['quantity']
                    
                    order_item_data = {
                        'order_id': order_id,
                        'product_id': item['product_id'],
                        'product_name': item['product_name'],
                        'materials': item['materials'],
                        'variant_color': item.get('variant_color'),
                        'variant_size': item.get('variant_size'),
                        'quantity': item['quantity'],
                        'unit_price': float(item['price']),
                        'subtotal': float(item_subtotal)
                    }
                    supabase.table('order_items').insert(order_item_data).execute()
                    
                    # Update product total_sold
                    update_product_total_sold_supabase(item['product_id'], item['quantity'])
                    
                    # Update variant stock
                    if item.get('variant_id'):
                        update_product_stock_supabase(item['variant_id'], item['quantity'])
            
            # Remove items from cart
            for cart_id in cart_ids:
                supabase.table('cart').delete().eq('cart_id', cart_id).execute()
            
            # Mark voucher as used
            if buyer_voucher_id:
                use_voucher_supabase(buyer_voucher_id, buyer_id)
                print(f"Voucher {buyer_voucher_id} marked as used")
            
            return jsonify({'success': True, 'message': 'Order placed successfully', 'order_ids': order_ids})
        
        except Exception as e:
            print(f"Database error: {e}")
            import traceback
            print(traceback.format_exc())
            return jsonify({'success': False, 'message': f'Database error: {str(e)}'}), 500
    
    except Exception as e:
        print(f"Unexpected error: {e}")
        import traceback
        print(traceback.format_exc())
        return jsonify({'success': False, 'message': f'Unexpected error: {str(e)}'}), 500
