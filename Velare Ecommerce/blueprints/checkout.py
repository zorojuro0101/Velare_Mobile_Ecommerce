from flask import Blueprint, render_template, request, session, redirect, url_for, abort, jsonify
import sys
import os

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.supabase_helper import *

checkout_bp = Blueprint('checkout', __name__)

@checkout_bp.route('/checkout')
def checkout():
    # Check if user is logged in
    if 'user_id' not in session or not session.get('logged_in'):
        return redirect(url_for('auth.login', next=request.path))
    
    # Get cart_ids from query parameters (passed from cart page via JavaScript)
    cart_ids_param = request.args.get('cart_ids', '')
    
    if not cart_ids_param:
        # No items selected, redirect back to cart
        return redirect(url_for('cart.cart'))
    
    try:
        # Parse cart IDs
        cart_ids = [int(id.strip()) for id in cart_ids_param.split(',') if id.strip()]
        
        if not cart_ids:
            return redirect(url_for('cart.cart'))
        
        supabase = get_supabase()
        if not supabase:
            abort(500, description="Database connection failed")
        
        try:
            # Get buyer_id from user_id
            buyer = get_buyer_by_user_id(session['user_id'])
            
            if not buyer:
                return redirect(url_for('cart.cart'))
            
            buyer_id = buyer['buyer_id']
            
            # Fetch selected cart items with product details
            print(f"[CHECKOUT] Cart IDs: {cart_ids}")
            print(f"[CHECKOUT] Buyer ID: {buyer_id}")
            
            checkout_response = supabase.table('cart').select('''
                cart_id,
                product_id,
                quantity,
                variant_id,
                products (
                    product_name,
                    materials,
                    price,
                    seller_id,
                    sellers (
                        shop_name,
                        shop_logo
                    )
                ),
                product_variants (
                    stock_quantity,
                    size,
                    color
                )
            ''').in_('cart_id', cart_ids).order('products.sellers.shop_name').execute()
            
            checkout_items = checkout_response.data if checkout_response.data else []
            
            if not checkout_items:
                return redirect(url_for('cart.cart'))
            
            # Get primary images for products
            product_ids = [item['product_id'] for item in checkout_items]
            images_response = supabase.table('product_images').select('product_id, image_url').eq('is_primary', True).in_('product_id', product_ids).execute()
            images_dict = {img['product_id']: img['image_url'] for img in images_response.data} if images_response.data else {}
            
            # Flatten nested data and add images
            for item in checkout_items:
                product = item.get('products', {})
                variant = item.get('product_variants', {})
                seller = product.get('sellers', {}) if isinstance(product.get('sellers'), dict) else {}
                
                item['product_name'] = product.get('product_name')
                item['materials'] = product.get('materials')
                item['price'] = product.get('price')
                item['seller_id'] = product.get('seller_id')
                item['shop_name'] = seller.get('shop_name')
                item['shop_logo'] = seller.get('shop_logo')
                item['primary_image'] = images_dict.get(item['product_id'])
                item['stock_quantity'] = variant.get('stock_quantity') if variant else None
                item['size'] = variant.get('size') if variant else None
                item['color'] = variant.get('color') if variant else None
            
            # Group items by shop
            from collections import defaultdict
            shops = defaultdict(list)
            for item in checkout_items:
                shop_key = item['seller_id']
                shops[shop_key].append(item)
            
            # Convert to list of shop groups
            shop_groups = []
            for seller_id, items in shops.items():
                shop_groups.append({
                    'seller_id': seller_id,
                    'shop_name': items[0]['shop_name'],
                    'shop_logo': items[0]['shop_logo'],
                    'shop_items': items
                })
            
            # Fetch buyer's addresses
            addresses = get_buyer_addresses(buyer_id)
            
            # Separate default and other addresses
            default_address = None
            other_addresses = []
            for addr in addresses:
                if addr['is_default']:
                    default_address = addr
                else:
                    other_addresses.append(addr)
            
            # Fetch buyer's available vouchers (has remaining uses and not expired)
            from datetime import date
            today = date.today().isoformat()
            
            vouchers_response = supabase.table('buyer_vouchers').select('''
                buyer_voucher_id,
                times_remaining,
                vouchers (
                    voucher_id,
                    voucher_code,
                    voucher_name,
                    voucher_type,
                    discount_percent,
                    end_date
                )
            ''').eq('buyer_id', buyer_id).gt('times_remaining', 0).gte('vouchers.end_date', today).execute()
            
            vouchers = []
            if vouchers_response.data:
                for bv in vouchers_response.data:
                    voucher = bv.get('vouchers', {})
                    vouchers.append({
                        'buyer_voucher_id': bv['buyer_voucher_id'],
                        'voucher_id': voucher.get('voucher_id'),
                        'voucher_code': voucher.get('voucher_code'),
                        'voucher_name': voucher.get('voucher_name'),
                        'voucher_type': voucher.get('voucher_type'),
                        'discount_percent': voucher.get('discount_percent'),
                        'end_date': voucher.get('end_date'),
                        'times_remaining': bv['times_remaining']
                    })
                
                # Sort by voucher_type and discount_percent
                vouchers.sort(key=lambda x: (x['voucher_type'], -x['discount_percent']))
            
            return render_template('checkout.html', 
                                 shop_groups=shop_groups,
                                 default_address=default_address,
                                 other_addresses=other_addresses,
                                 vouchers=vouchers)
        
        except Exception as e:
            import traceback
            print(f"Error fetching checkout items: {e}")
            print(traceback.format_exc())
            abort(500, description=f"Error fetching checkout items: {str(e)}")
    
    except ValueError:
        # Invalid cart IDs format
        return redirect(url_for('cart.cart'))

@checkout_bp.route('/add_address', methods=['POST'])
def add_address():
    # Check if user is logged in
    if 'user_id' not in session or not session.get('logged_in'):
        return jsonify({'success': False, 'message': 'Not logged in'}), 401
    
    try:
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['recipient_name', 'phone_number', 'region', 'province', 
                          'city', 'barangay', 'postal_code']
        for field in required_fields:
            if not data.get(field):
                return jsonify({'success': False, 'message': f'{field} is required'}), 400
        
        supabase = get_supabase()
        if not supabase:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Get buyer_id
            buyer = get_buyer_by_user_id(session['user_id'])
            
            if not buyer:
                return jsonify({'success': False, 'message': 'Buyer account not found'}), 404
            
            buyer_id = buyer['buyer_id']
            
            # Build full address
            full_address_parts = [
                data.get('house_number', ''),
                data.get('street_name', ''),
                data['barangay'],
                data['city'],
                data['province'],
                data['region'],
                data['postal_code']
            ]
            full_address = ', '.join([part for part in full_address_parts if part])
            
            # Check if this is the first address (make it default)
            count_response = supabase.table('addresses').select('address_id', count='exact').eq('user_type', 'buyer').eq('user_ref_id', buyer_id).execute()
            is_default = count_response.count == 0
            
            # If setting as default, unset other defaults
            if data.get('is_default') or is_default:
                supabase.table('addresses').update({'is_default': False}).eq('user_type', 'buyer').eq('user_ref_id', buyer_id).execute()
                is_default = True
            
            # Insert new address
            address_data = {
                'user_type': 'buyer',
                'user_ref_id': buyer_id,
                'recipient_name': data['recipient_name'],
                'phone_number': data['phone_number'],
                'full_address': full_address,
                'region': data['region'],
                'province': data['province'],
                'city': data['city'],
                'barangay': data['barangay'],
                'street_name': data.get('street_name', ''),
                'house_number': data.get('house_number', ''),
                'postal_code': data['postal_code'],
                'is_default': is_default
            }
            
            insert_response = supabase.table('addresses').insert(address_data).execute()
            address_id = insert_response.data[0]['address_id'] if insert_response.data else None
            
            return jsonify({
                'success': True, 
                'message': 'Address added successfully',
                'address_id': address_id
            })
        
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

@checkout_bp.route('/set_default_address', methods=['POST'])
def set_default_address():
    # Check if user is logged in
    if 'user_id' not in session or not session.get('logged_in'):
        return jsonify({'success': False, 'message': 'Not logged in'}), 401
    
    try:
        data = request.get_json()
        address_id = data.get('address_id')
        
        if not address_id:
            return jsonify({'success': False, 'message': 'Address ID is required'}), 400
        
        supabase = get_supabase()
        if not supabase:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Get buyer_id
            buyer = get_buyer_by_user_id(session['user_id'])
            
            if not buyer:
                return jsonify({'success': False, 'message': 'Buyer account not found'}), 404
            
            buyer_id = buyer['buyer_id']
            
            # Verify address belongs to buyer
            address_check = supabase.table('addresses').select('address_id').eq('address_id', address_id).eq('user_type', 'buyer').eq('user_ref_id', buyer_id).execute()
            
            if not address_check.data:
                return jsonify({'success': False, 'message': 'Address not found'}), 404
            
            # Use helper function to set default
            success = set_default_address_supabase(address_id, buyer_id)
            
            if success:
                return jsonify({'success': True, 'message': 'Default address updated'})
            else:
                return jsonify({'success': False, 'message': 'Failed to update default address'}), 500
        
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
