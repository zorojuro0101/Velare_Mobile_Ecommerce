from flask import Blueprint, render_template, request, jsonify, session, abort, redirect, url_for
import sys
import os

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.supabase_helper import *
from .notification_helper import create_stock_notification

cart_bp = Blueprint('cart', __name__)

@cart_bp.route('/cart')
def cart():
    # Check if user is logged in
    if 'user_id' not in session or not session.get('logged_in'):
        return redirect(url_for('auth.login', next=request.path))
    
    try:
        # Get buyer_id from user_id
        buyer = get_buyer_by_user_id(session['user_id'])
        
        if not buyer:
            return render_template('cart.html', shop_groups=[])
        
        buyer_id = buyer['buyer_id']
        
        # Get Supabase client
        supabase = get_supabase()
        if not supabase:
            abort(500, description="Database connection failed")
        
        # Fetch all cart items with product details, shop info, size, and check if favorited
        # Filter for active products after fetching
        cart_response = supabase.table('cart').select('''
            cart_id,
            product_id,
            quantity,
            variant_id,
            added_at,
            products (
                product_name,
                materials,
                price,
                is_active,
                seller_id
            ),
            product_variants (
                stock_quantity,
                size,
                color
            )
        ''').eq('buyer_id', buyer_id).order('added_at', desc=True).execute()
        
        cart_items = cart_response.data if cart_response.data else []
        
        # Filter out inactive products
        cart_items = [item for item in cart_items if item.get('products', {}).get('is_active', False)]
        
        # Get seller info separately for each product
        if cart_items:
            seller_ids = list(set([item['products']['seller_id'] for item in cart_items if item.get('products', {}).get('seller_id')]))
            if seller_ids:
                sellers_response = supabase.table('sellers').select('seller_id, shop_name, shop_logo').in_('seller_id', seller_ids).execute()
                sellers_dict = {s['seller_id']: s for s in sellers_response.data} if sellers_response.data else {}
            else:
                sellers_dict = {}
        else:
            sellers_dict = {}
        
        # Get primary images for products
        if cart_items:
            product_ids = [item['product_id'] for item in cart_items]
            images_response = supabase.table('product_images').select('product_id, image_url').eq('is_primary', True).in_('product_id', product_ids).execute()
            images_dict = {img['product_id']: img['image_url'] for img in images_response.data} if images_response.data else {}
            
            # Check favorites
            favorites_response = supabase.table('favorites').select('product_id').eq('buyer_id', buyer_id).in_('product_id', product_ids).execute()
            favorite_ids = [fav['product_id'] for fav in favorites_response.data] if favorites_response.data else []
            
            # Flatten nested data and add images/favorites
            for item in cart_items:
                product = item.get('products', {})
                variant = item.get('product_variants', {})
                
                # Get seller info from sellers_dict
                seller_id = product.get('seller_id')
                seller = sellers_dict.get(seller_id, {}) if seller_id else {}
                
                # Get and fix image path
                image_url = images_dict.get(item['product_id'])
                if image_url and not (image_url.startswith('http://') or image_url.startswith('https://')):
                    # If it starts with /static/, remove the leading slash
                    if image_url.startswith('/static/'):
                        image_url = image_url[1:]  # Remove leading /
                    # If it doesn't start with static/, add it
                    elif not image_url.startswith('static/'):
                        image_url = f'static/{image_url}'
                
                item['product_name'] = product.get('product_name')
                item['materials'] = product.get('materials')
                item['price'] = product.get('price')
                item['is_active'] = product.get('is_active')
                item['seller_id'] = seller_id
                item['shop_name'] = seller.get('shop_name')
                item['shop_logo'] = seller.get('shop_logo')
                item['primary_image'] = image_url
                item['stock_quantity'] = variant.get('stock_quantity') if variant else None
                item['size'] = variant.get('size') if variant else None
                item['color'] = variant.get('color') if variant else None
                item['is_favorite'] = 1 if item['product_id'] in favorite_ids else 0
        
        # Group items by shop
        from collections import defaultdict
        shops = defaultdict(list)
        for item in cart_items:
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
        
        return render_template('cart.html', shop_groups=shop_groups)
    
    except Exception as e:
        import traceback
        print(f"Error fetching cart items: {e}")
        print(traceback.format_exc())
        abort(500, description=f"Error fetching cart items: {str(e)}")

@cart_bp.route('/add_to_cart', methods=['POST'])
def add_to_cart():
    try:
        # Check if user is logged in
        if 'user_id' not in session or not session.get('logged_in'):
            return jsonify({'success': False, 'message': 'Please login to add items to cart'}), 401
        
        data = request.get_json()
        product_id = data.get('product_id')
        quantity = data.get('quantity', 1)
        variant_id = data.get('variant_id')
        selected_color = data.get('color')
        
        print(f"\n{'='*80}")
        print(f"[ADD_TO_CART] Request received from user_id: {session.get('user_id')}")
        print(f"[ADD_TO_CART] Data received: product_id={product_id}, quantity={quantity}, variant_id={variant_id}, color={selected_color}")
        print(f"{'='*80}\n")
        
        if not product_id:
            return jsonify({'success': False, 'message': 'Product ID is required'}), 400
        
        if quantity < 1:
            return jsonify({'success': False, 'message': 'Quantity must be at least 1'}), 400
        
        supabase = get_supabase()
        if not supabase:
            print("Database connection failed")
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Get buyer_id from user_id
            buyer = get_buyer_by_user_id(session['user_id'])
            
            if not buyer:
                return jsonify({'success': False, 'message': 'Buyer account not found'}), 404
            
            buyer_id = buyer['buyer_id']
            print(f"[ADD_TO_CART] Buyer ID: {buyer_id}")
            
            # Logic to determine the correct variant_id
            if variant_id and selected_color:
                try:
                    # Get the size from the variant_id
                    size_response = supabase.table('product_variants').select('size').eq('variant_id', variant_id).execute()
                    
                    if size_response.data:
                        selected_size = size_response.data[0]['size']
                        
                        # Find the variant that matches product, size, AND color
                        final_variant_response = supabase.table('product_variants').select('variant_id').eq('product_id', product_id).eq('size', selected_size).eq('color', selected_color).execute()
                        
                        if final_variant_response.data:
                            variant_id = final_variant_response.data[0]['variant_id']
                            print(f"[ADD_TO_CART] Found matching variant: variant_id={variant_id} for size={selected_size}, color={selected_color}")
                        else:
                            print(f"[ADD_TO_CART] ERROR: No variant found for size={selected_size}, color={selected_color}")
                            return jsonify({'success': False, 'message': 'Selected color and size combination is not available.'}), 400
                except Exception as e:
                    print(f"Error looking up variant: {e}")
                    return jsonify({'success': False, 'message': 'Error finding product variant.'}), 500
            
            # Check if product exists and is active
            product_response = supabase.table('products').select('product_id').eq('product_id', product_id).eq('is_active', True).execute()
            
            if not product_response.data:
                return jsonify({'success': False, 'message': 'Product not found or unavailable'}), 404
            
            # Check stock from variant if variant_id is provided
            if variant_id:
                variant = get_product_variant(variant_id)
                
                if not variant:
                    return jsonify({'success': False, 'message': 'Product variant not found'}), 404
                
                if variant['stock_quantity'] <= 0:
                    return jsonify({'success': False, 'message': 'This product is out of stock'}), 400
                
                if variant['stock_quantity'] < quantity:
                    return jsonify({'success': False, 'message': f'Only {variant["stock_quantity"]} items available in stock'}), 400
                
                available_stock = variant['stock_quantity']
                
                # Check current quantity in cart for this variant
                current_cart_response = supabase.table('cart').select('quantity').eq('buyer_id', buyer_id).eq('product_id', product_id).eq('variant_id', variant_id).execute()
                
                current_quantity = current_cart_response.data[0]['quantity'] if current_cart_response.data else 0
                
                # Check if already at maximum stock in cart
                if current_quantity >= available_stock:
                    return jsonify({
                        'success': False, 
                        'message': 'Already in maximum stocks in cart'
                    }), 400
                
                # Check if adding new quantity would exceed stock
                if current_quantity + quantity > available_stock:
                    return jsonify({
                        'success': False, 
                        'message': f'Cannot add {quantity} more items. Only {available_stock - current_quantity} items can be added to reach maximum stock.'
                    }), 400
            else:
                return jsonify({'success': False, 'message': 'Product variant is required'}), 400
            
            # Add to cart or update quantity
            print(f"[ADD_TO_CART] Executing INSERT/UPDATE with: buyer_id={buyer_id}, product_id={product_id}, quantity={quantity}, variant_id={variant_id}")
            
            # Check if item already exists
            existing_cart_response = supabase.table('cart').select('cart_id, quantity').eq('buyer_id', buyer_id).eq('product_id', product_id).eq('variant_id', variant_id).execute()
            
            if existing_cart_response.data:
                # Update existing cart item
                cart_id = existing_cart_response.data[0]['cart_id']
                new_quantity = existing_cart_response.data[0]['quantity'] + quantity
                
                # Verify final quantity doesn't exceed stock
                if new_quantity > available_stock:
                    new_quantity = available_stock
                    update_response = supabase.table('cart').update({'quantity': new_quantity}).eq('cart_id', cart_id).execute()
                    return jsonify({
                        'success': False, 
                        'message': f'Cannot add more. Only {available_stock} items available. Cart updated to maximum available.',
                        'cart_id': cart_id
                    }), 400
                
                update_response = supabase.table('cart').update({'quantity': new_quantity}).eq('cart_id', cart_id).execute()
                print(f"[ADD_TO_CART] Cart operation completed. cart_id={cart_id}")
            else:
                # Insert new cart item
                insert_response = supabase.table('cart').insert({
                    'buyer_id': buyer_id,
                    'product_id': product_id,
                    'quantity': quantity,
                    'variant_id': variant_id
                }).execute()
                cart_id = insert_response.data[0]['cart_id'] if insert_response.data else None
                print(f"[ADD_TO_CART] Cart operation completed. cart_id={cart_id}")
            
            print(f"[ADD_TO_CART] SUCCESS: Item added/updated in cart. cart_id={cart_id}")
            print(f"{'='*80}\n")
            return jsonify({'success': True, 'message': 'Added to cart successfully', 'cart_id': cart_id})
        
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

@cart_bp.route('/buy_now_cart', methods=['POST'])
def buy_now_cart():
    """Add to cart for Buy Now - doesn't increase quantity if already exists"""
    try:
        # Check if user is logged in
        if 'user_id' not in session or not session.get('logged_in'):
            return jsonify({'success': False, 'message': 'Please login to continue'}), 401
        
        data = request.get_json()
        product_id = data.get('product_id')
        variant_id = data.get('variant_id')
        selected_color = data.get('color')
        quantity = data.get('quantity', 1)
        
        print(f"\n{'='*80}")
        print(f"[BUY_NOW_CART] Request received from user_id: {session.get('user_id')}")
        print(f"[BUY_NOW_CART] Data: product_id={product_id}, variant_id={variant_id}, color={selected_color}, quantity={quantity}")
        print(f"{'='*80}\n")
        
        if not product_id:
            return jsonify({'success': False, 'message': 'Product ID is required'}), 400
        
        if quantity < 1:
            return jsonify({'success': False, 'message': 'Quantity must be at least 1'}), 400
        
        supabase = get_supabase()
        if not supabase:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Get buyer_id
            buyer = get_buyer_by_user_id(session['user_id'])
            
            if not buyer:
                return jsonify({'success': False, 'message': 'Buyer account not found'}), 404
            
            buyer_id = buyer['buyer_id']
            
            # Logic to determine the correct variant_id (same as add_to_cart)
            if variant_id and selected_color:
                try:
                    size_response = supabase.table('product_variants').select('size').eq('variant_id', variant_id).execute()
                    
                    if size_response.data:
                        selected_size = size_response.data[0]['size']
                        final_variant_response = supabase.table('product_variants').select('variant_id').eq('product_id', product_id).eq('size', selected_size).eq('color', selected_color).execute()
                        
                        if final_variant_response.data:
                            variant_id = final_variant_response.data[0]['variant_id']
                            print(f"[BUY_NOW_CART] Found matching variant: variant_id={variant_id}")
                        else:
                            return jsonify({'success': False, 'message': 'Selected color and size combination is not available.'}), 400
                except Exception as e:
                    print(f"Error looking up variant: {e}")
                    return jsonify({'success': False, 'message': 'Error finding product variant.'}), 500
            
            # Check if product exists
            product_response = supabase.table('products').select('product_id').eq('product_id', product_id).eq('is_active', True).execute()
            
            if not product_response.data:
                return jsonify({'success': False, 'message': 'Product not found or unavailable'}), 404
            
            # Check stock from variant
            if variant_id:
                variant = get_product_variant(variant_id)
                
                if not variant:
                    return jsonify({'success': False, 'message': 'Product variant not found'}), 404
                
                if variant['stock_quantity'] < quantity:
                    return jsonify({'success': False, 'message': f'Only {variant["stock_quantity"]} items available in stock'}), 400
            else:
                return jsonify({'success': False, 'message': 'Product variant is required'}), 400
            
            # Check if item already exists in cart
            existing_cart_response = supabase.table('cart').select('cart_id').eq('buyer_id', buyer_id).eq('product_id', product_id).eq('variant_id', variant_id).execute()
            
            if existing_cart_response.data:
                # Item already exists, update quantity to the new quantity (not add)
                cart_id = existing_cart_response.data[0]['cart_id']
                supabase.table('cart').update({'quantity': quantity}).eq('cart_id', cart_id).execute()
                print(f"[BUY_NOW_CART] Item already in cart. Updated quantity to {quantity}. cart_id={cart_id}")
            else:
                # Item doesn't exist, create new cart entry
                insert_response = supabase.table('cart').insert({
                    'buyer_id': buyer_id,
                    'product_id': product_id,
                    'quantity': quantity,
                    'variant_id': variant_id
                }).execute()
                cart_id = insert_response.data[0]['cart_id'] if insert_response.data else None
                print(f"[BUY_NOW_CART] New cart item created with quantity={quantity}. cart_id={cart_id}")
            
            print(f"[BUY_NOW_CART] SUCCESS: cart_id={cart_id}")
            print(f"{'='*80}\n")
            return jsonify({'success': True, 'message': 'Ready for checkout', 'cart_id': cart_id})
        
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

@cart_bp.route('/remove_from_cart', methods=['POST'])
def remove_from_cart():
    try:
        # Check if user is logged in
        if 'user_id' not in session or not session.get('logged_in'):
            return jsonify({'success': False, 'message': 'Not logged in'}), 401
        
        data = request.get_json()
        cart_id = data.get('cart_id')
        
        if not cart_id:
            return jsonify({'success': False, 'message': 'Cart ID is required'}), 400
        
        supabase = get_supabase()
        if not supabase:
            print("Database connection failed")
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Get buyer_id from user_id
            buyer = get_buyer_by_user_id(session['user_id'])
            
            if not buyer:
                return jsonify({'success': False, 'message': 'Buyer account not found'}), 404
            
            buyer_id = buyer['buyer_id']
            
            # Verify the cart item belongs to this buyer before deleting
            cart_check = supabase.table('cart').select('cart_id').eq('cart_id', cart_id).eq('buyer_id', buyer_id).execute()
            
            if not cart_check.data:
                return jsonify({'success': False, 'message': 'Cart item not found'}), 404
            
            # Delete from cart
            supabase.table('cart').delete().eq('cart_id', cart_id).execute()
            
            return jsonify({'success': True, 'message': 'Removed from cart successfully'})
        
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

@cart_bp.route('/update_cart_quantity', methods=['POST'])
def update_cart_quantity():
    try:
        # Check if user is logged in
        if 'user_id' not in session or not session.get('logged_in'):
            return jsonify({'success': False, 'message': 'Not logged in'}), 401
        
        data = request.get_json()
        cart_id = data.get('cart_id')
        quantity = data.get('quantity')
        
        if not cart_id or quantity is None:
            return jsonify({'success': False, 'message': 'Cart ID and quantity are required'}), 400
        
        if quantity < 1:
            return jsonify({'success': False, 'message': 'Quantity must be at least 1'}), 400
        
        supabase = get_supabase()
        if not supabase:
            print("Database connection failed")
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Get buyer_id from user_id
            buyer = get_buyer_by_user_id(session['user_id'])
            
            if not buyer:
                return jsonify({'success': False, 'message': 'Buyer account not found'}), 404
            
            buyer_id = buyer['buyer_id']
            
            # Get cart item and verify ownership
            cart_response = supabase.table('cart').select('cart_id, product_id, variant_id').eq('cart_id', cart_id).eq('buyer_id', buyer_id).execute()
            
            if not cart_response.data:
                return jsonify({'success': False, 'message': 'Cart item not found'}), 404
            
            cart_item = cart_response.data[0]
            
            # Check stock availability from variant
            if cart_item['variant_id']:
                variant = get_product_variant(cart_item['variant_id'])
                
                if not variant:
                    return jsonify({'success': False, 'message': 'Product variant not found'}), 404
                
                if quantity > variant['stock_quantity']:
                    return jsonify({'success': False, 'message': f'Only {variant["stock_quantity"]} items available in stock'}), 400
            else:
                return jsonify({'success': False, 'message': 'Product variant is required'}), 400
            
            # Update quantity
            supabase.table('cart').update({'quantity': quantity}).eq('cart_id', cart_id).execute()
            
            return jsonify({'success': True, 'message': 'Quantity updated successfully'})
        
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

@cart_bp.route('/get_cart_count', methods=['GET'])
def get_cart_count():
    try:
        # If user is not logged in, return 0
        if 'user_id' not in session or not session.get('logged_in'):
            return jsonify({'success': True, 'count': 0})
        
        supabase = get_supabase()
        if not supabase:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Get buyer_id from user_id
            buyer = get_buyer_by_user_id(session['user_id'])
            
            if not buyer:
                return jsonify({'success': True, 'count': 0})
            
            buyer_id = buyer['buyer_id']
            
            # Get total count of items in cart
            count_response = supabase.table('cart').select('cart_id', count='exact').eq('buyer_id', buyer_id).execute()
            
            count = count_response.count if count_response.count else 0
            
            return jsonify({'success': True, 'count': count})
        
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

@cart_bp.route('/check_cart_stock_status', methods=['POST'])
def check_cart_stock_status():
    """Check if any cart items have changed stock status (low on stock/out of stock)"""
    try:
        if 'user_id' not in session or not session.get('logged_in'):
            return jsonify({'success': False, 'message': 'Please login'}), 401
        
        user_id = session.get('user_id')
        data = request.get_json()
        cart_items = data.get('cart_items', [])
        
        if not cart_items:
            return jsonify({'success': True, 'changes': []})
        
        supabase = get_supabase()
        if not supabase:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            changes = []
            
            for item in cart_items:
                variant_id = item.get('variant_id')
                current_stock = item.get('current_stock')
                cart_id = item.get('cart_id')
                product_id = item.get('product_id')
                product_name = item.get('product_name')
                
                if not variant_id:
                    continue
                
                # Get current stock from database
                variant = get_product_variant(variant_id)
                
                if not variant:
                    continue
                
                new_stock = variant['stock_quantity']
                
                # Check if stock status has changed
                old_status = 'normal'
                new_status = 'normal'
                
                if current_stock <= 0:
                    old_status = 'out_of_stock'
                elif current_stock <= 5:
                    old_status = 'low_on_stock'
                
                if new_stock <= 0:
                    new_status = 'out_of_stock'
                elif new_stock <= 5:
                    new_status = 'low_on_stock'
                
                # If status changed, record it and create notification
                if old_status != new_status:
                    changes.append({
                        'cart_id': cart_id,
                        'product_id': product_id,
                        'product_name': product_name,
                        'old_stock': current_stock,
                        'new_stock': new_stock,
                        'old_status': old_status,
                        'new_status': new_status
                    })
                    
                    # Create notification for buyer
                    if new_status == 'out_of_stock':
                        create_stock_notification(user_id, product_id, product_name, 'out_of_stock')
                    elif new_status == 'low_on_stock':
                        create_stock_notification(user_id, product_id, product_name, 'low_on_stock')
            
            return jsonify({'success': True, 'changes': changes})
        
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
