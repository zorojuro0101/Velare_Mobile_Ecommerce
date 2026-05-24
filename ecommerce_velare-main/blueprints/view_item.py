from flask import Blueprint, render_template, request, abort, session
from datetime import datetime
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.supabase_helper import (
    get_supabase, 
    get_buyer_by_user_id, 
    clean_supabase_data,
    fix_image_urls_in_data
)

view_item_bp = Blueprint('view_item', __name__)

@view_item_bp.route('/view_item/<int:product_id>')
def view_item(product_id):
    supabase = get_supabase()
    if not supabase:
        abort(500, description="Database connection failed")
    
    try:
        # Fetch product with seller info
        product_response = supabase.table('products').select('''
            product_id,
            product_name,
            description,
            materials,
            sdg,
            price,
            category,
            rating,
            total_reviews,
            total_sold,
            seller_id,
            sellers (
                shop_name,
                shop_logo,
                seller_id
            )
        ''').eq('product_id', product_id).eq('is_active', True).execute()
        
        if not product_response.data:
            abort(404, description="Product not found")
        
        # Clean the product data
        product = clean_supabase_data(product_response.data[0])
        
        print(f"🔍 DEBUG: Product seller_id from main query: {product.get('seller_id')}")
        
        # Map category for display (menuToggle)
        category_mapping = {
            'Tops': 'Tops & Blouses',
            'Blouse': 'Tops & Blouses',
            'Blouses': 'Tops & Blouses',
            'Dresses': 'Dresses & Skirts',
            'Skirts': 'Dresses & Skirts',
            'Dress': 'Dresses & Skirts',
            'Skirt': 'Dresses & Skirts',
            'Activewear': 'Activewear',
            'Lingerie': 'Lingerie & Sleepwear',
            'Sleepwear': 'Lingerie & Sleepwear',
            'Yoga Pants': 'Activewear',
            'Sports Bra': 'Activewear',
            'Leggings': 'Activewear'
        }
        
        # Get the original category and map it
        original_category = product.get('category', '')
        product['menuToggle'] = category_mapping.get(original_category, original_category)
        
        # Fix image URL case (images → Images)
        product = fix_image_urls_in_data(product)
        
        # Get seller info separately if seller_id exists
        if product.get('seller_id'):
            seller_response = supabase.table('sellers').select('seller_id, shop_name, shop_logo').eq('seller_id', product['seller_id']).execute()
            if seller_response.data:
                seller = seller_response.data[0]
                product['shop_name'] = seller.get('shop_name')
                product['shop_logo'] = seller.get('shop_logo')
                print(f"✅ DEBUG: Fetched seller info - shop_name={product['shop_name']}")
            else:
                product['shop_name'] = None
                product['shop_logo'] = None
                print(f"❌ DEBUG: No seller found for seller_id={product['seller_id']}")
        else:
            product['shop_name'] = None
            product['shop_logo'] = None
            product['seller_id'] = None
            print(f"❌ DEBUG: No seller_id in product")
        
        # Fetch images
        images_response = supabase.table('product_images').select('image_url, is_primary, display_order').eq('product_id', product_id).order('is_primary', desc=True).order('display_order').execute()
        images = clean_supabase_data(images_response.data) if images_response.data else []
        
        # Fix image URL case (images → Images)
        images = fix_image_urls_in_data(images)
        
        # Fetch variants
        variants_response = supabase.table('product_variants').select('variant_id, color, hex_code, size, stock_quantity, image_url').eq('product_id', product_id).order('color').order('size').execute()
        variants = clean_supabase_data(variants_response.data) if variants_response.data else []
        
        # Fix image URLs in variants
        variants = fix_image_urls_in_data(variants)
        
        # Get unique colors with their images
        colors_dict = {}
        for v in variants:
            color = v.get('color')
            if color and color not in colors_dict:
                colors_dict[color] = {
                    'hex': v.get('hex_code'),
                    'images': []
                }
            
            # Add image to this color if it exists and not already added
            if color and v.get('image_url'):
                image_url = v.get('image_url')
                if image_url not in colors_dict[color]['images']:
                    colors_dict[color]['images'].append(image_url)
        
        colors = [{'name': color, 'hex': data['hex'], 'images': data['images']} for color, data in colors_dict.items()]
        
        # Calculate total stock
        total_stock = sum(v['stock_quantity'] for v in variants)
        
        # Get sizes
        sizes = sorted(list(set(v['size'] for v in variants if v['size'])))
        
        # Check if favorited
        is_favorite = False
        if 'user_id' in session:
            buyer = get_buyer_by_user_id(session['user_id'])
            if buyer:
                fav_response = supabase.table('favorites').select('favorite_id').eq('buyer_id', buyer['buyer_id']).eq('product_id', product_id).execute()
                is_favorite = bool(fav_response.data)
        
        # Get reviews
        reviews_response = supabase.table('product_reviews').select('''
            rating,
            review_text,
            created_at,
            buyers (
                first_name,
                last_name
            )
        ''').eq('product_id', product_id).order('created_at', desc=True).limit(10).execute()
        
        reviews = []
        if reviews_response.data:
            reviews_data = clean_supabase_data(reviews_response.data)
            for review in reviews_data:
                buyer_data = review.get('buyers', {})
                if buyer_data and isinstance(buyer_data, dict):
                    first_name = buyer_data.get('first_name', '')
                    last_name = buyer_data.get('last_name', '')
                    buyer_name = f"{first_name} {last_name}".strip() or 'Anonymous'
                else:
                    buyer_name = 'Anonymous'
                
                # Convert created_at string to datetime object
                created_at = review.get('created_at')
                if created_at and isinstance(created_at, str):
                    try:
                        # Parse ISO format datetime string
                        created_at = datetime.fromisoformat(created_at.replace('Z', '+00:00'))
                    except:
                        created_at = None
                
                reviews.append({
                    'rating': review.get('rating', 0),
                    'review_text': review.get('review_text', ''),
                    'created_at': created_at,
                    'buyer_name': buyer_name
                })
        
        return render_template('view_item.html', 
                             product=product, 
                             images=images, 
                             variants=variants,
                             colors=colors,
                             sizes=sizes,
                             total_stock=total_stock,
                             is_favorite=is_favorite,
                             reviews=reviews)
    
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        abort(500, description=str(e))
