from flask import Blueprint, render_template, request, jsonify, session, abort, redirect, url_for
import sys
import os

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.supabase_helper import *

favorite_bp = Blueprint('favorite', __name__)

@favorite_bp.route('/favorite')
def favorite():
    # Check if user is logged in
    if 'user_id' not in session or not session.get('logged_in'):
        return redirect(url_for('auth.login', next=request.path))
    
    try:
        # Get buyer_id from user_id
        buyer = get_buyer_by_user_id(session['user_id'])
        
        if not buyer:
            return render_template('favorite.html', shop_groups=[])
        
        buyer_id = buyer['buyer_id']
        
        # Get Supabase client
        supabase = get_supabase()
        if not supabase:
            abort(500, description="Database connection failed")
        
        # Fetch all favorite products with shop info
        # Filter for active products after fetching
        favorites_response = supabase.table('favorites').select('''
            favorite_id,
            product_id,
            added_at,
            products (
                product_name,
                materials,
                price,
                seller_id,
                is_active
            )
        ''').eq('buyer_id', buyer_id).order('added_at', desc=True).execute()
        
        favorites = favorites_response.data if favorites_response.data else []
        
        # Filter out inactive products
        favorites = [item for item in favorites if item.get('products', {}).get('is_active', False)]
        
        # Get seller info separately
        if favorites:
            seller_ids = list(set([item['products']['seller_id'] for item in favorites if item.get('products', {}).get('seller_id')]))
            if seller_ids:
                sellers_response = supabase.table('sellers').select('seller_id, shop_name, shop_logo').in_('seller_id', seller_ids).execute()
                sellers_dict = {s['seller_id']: s for s in sellers_response.data} if sellers_response.data else {}
            else:
                sellers_dict = {}
        else:
            sellers_dict = {}
        
        # Get primary images and stock for products
        if favorites:
            product_ids = [item['product_id'] for item in favorites]
            
            # Get primary images
            images_response = supabase.table('product_images').select('product_id, image_url').eq('is_primary', True).in_('product_id', product_ids).execute()
            images_dict = {img['product_id']: img['image_url'] for img in images_response.data} if images_response.data else {}
            
            # Get total stock for each product
            variants_response = supabase.table('product_variants').select('product_id, stock_quantity').in_('product_id', product_ids).execute()
            stock_dict = {}
            if variants_response.data:
                for variant in variants_response.data:
                    pid = variant['product_id']
                    if pid not in stock_dict:
                        stock_dict[pid] = 0
                    stock_dict[pid] += variant['stock_quantity']
            
            # Flatten nested data and add images/stock
            for item in favorites:
                product = item.get('products', {})
                
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
                
                # Fix shop logo path
                shop_logo = seller.get('shop_logo')
                if shop_logo and not (shop_logo.startswith('http://') or shop_logo.startswith('https://')):
                    if shop_logo.startswith('/static/'):
                        shop_logo = shop_logo[1:]
                    elif not shop_logo.startswith('static/'):
                        shop_logo = f'static/{shop_logo}'
                
                item['product_name'] = product.get('product_name')
                item['materials'] = product.get('materials')
                item['price'] = product.get('price')
                item['seller_id'] = product.get('seller_id')
                item['shop_name'] = seller.get('shop_name')
                item['shop_logo'] = shop_logo
                item['primary_image'] = image_url
                item['stock_quantity'] = stock_dict.get(item['product_id'], 0)
        
        # Group favorites by shop
        from collections import defaultdict
        shops = defaultdict(list)
        for item in favorites:
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
        
        return render_template('favorite.html', shop_groups=shop_groups)
    
    except Exception as e:
        import traceback
        print(f"Error fetching favorites: {e}")
        print(traceback.format_exc())
        abort(500, description=f"Error fetching favorites: {str(e)}")

@favorite_bp.route('/add_to_favorites', methods=['POST'])
def add_to_favorites():
    try:
        # Check if user is logged in
        if 'user_id' not in session or not session.get('logged_in'):
            return jsonify({'success': False, 'message': 'Not logged in'}), 401
        
        data = request.get_json()
        product_id = data.get('product_id')
        
        print(f"\n{'='*80}")
        print(f"[ADD_TO_FAVORITES] Request received from user_id: {session.get('user_id')}")
        print(f"[ADD_TO_FAVORITES] Product ID: {product_id}")
        print(f"{'='*80}\n")
        
        if not product_id:
            return jsonify({'success': False, 'message': 'Product ID is required'}), 400
        
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
            print(f"[ADD_TO_FAVORITES] Buyer ID: {buyer_id}")
            
            # Check if already in favorites
            existing_response = supabase.table('favorites').select('favorite_id').eq('buyer_id', buyer_id).eq('product_id', product_id).execute()
            
            if existing_response.data:
                print(f"[ADD_TO_FAVORITES] Product already in favorites: favorite_id={existing_response.data[0]['favorite_id']}")
                return jsonify({'success': False, 'message': 'Already in favorites'}), 400
            
            # Add to favorites
            print(f"[ADD_TO_FAVORITES] Inserting into favorites table")
            insert_response = supabase.table('favorites').insert({
                'buyer_id': buyer_id,
                'product_id': product_id
            }).execute()
            
            favorite_id = insert_response.data[0]['favorite_id'] if insert_response.data else None
            
            print(f"[ADD_TO_FAVORITES] SUCCESS: Added to favorites. favorite_id={favorite_id}")
            print(f"{'='*80}\n")
            return jsonify({'success': True, 'message': 'Added to favorites successfully'})
        
        except Exception as e:
            print(f"Database error: {e}")
            return jsonify({'success': False, 'message': f'Database error: {str(e)}'}), 500
    
    except Exception as e:
        print(f"Unexpected error: {e}")
        return jsonify({'success': False, 'message': f'Unexpected error: {str(e)}'}), 500

@favorite_bp.route('/remove_from_favorites', methods=['POST'])
def remove_from_favorites():
    try:
        # Check if user is logged in
        if 'user_id' not in session or not session.get('logged_in'):
            return jsonify({'success': False, 'message': 'Not logged in'}), 401
        
        data = request.get_json()
        favorite_id = data.get('favorite_id')
        
        if not favorite_id:
            return jsonify({'success': False, 'message': 'Favorite ID is required'}), 400
        
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
            
            # Verify the favorite belongs to this buyer before deleting
            favorite_check = supabase.table('favorites').select('favorite_id').eq('favorite_id', favorite_id).eq('buyer_id', buyer_id).execute()
            
            if not favorite_check.data:
                return jsonify({'success': False, 'message': 'Favorite not found'}), 404
            
            # Delete from favorites
            supabase.table('favorites').delete().eq('favorite_id', favorite_id).execute()
            
            return jsonify({'success': True, 'message': 'Removed from favorites successfully'})
        
        except Exception as e:
            print(f"Database error: {e}")
            return jsonify({'success': False, 'message': f'Database error: {str(e)}'}), 500
    
    except Exception as e:
        print(f"Unexpected error: {e}")
        return jsonify({'success': False, 'message': f'Unexpected error: {str(e)}'}), 500

@favorite_bp.route('/remove_from_favorites_by_product', methods=['POST'])
def remove_from_favorites_by_product():
    try:
        # Check if user is logged in
        if 'user_id' not in session or not session.get('logged_in'):
            return jsonify({'success': False, 'message': 'Not logged in'}), 401
        
        data = request.get_json()
        product_id = data.get('product_id')
        
        if not product_id:
            return jsonify({'success': False, 'message': 'Product ID is required'}), 400
        
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
            
            # Delete from favorites using product_id and buyer_id
            delete_response = supabase.table('favorites').delete().eq('buyer_id', buyer_id).eq('product_id', product_id).execute()
            
            if delete_response.data:
                return jsonify({'success': True, 'message': 'Removed from favorites successfully'})
            else:
                return jsonify({'success': False, 'message': 'Product not in favorites'}), 404
        
        except Exception as e:
            print(f"Database error: {e}")
            return jsonify({'success': False, 'message': f'Database error: {str(e)}'}), 500
    
    except Exception as e:
        print(f"Unexpected error: {e}")
        return jsonify({'success': False, 'message': f'Unexpected error: {str(e)}'}), 500
