from flask import Blueprint, render_template, session, redirect, url_for
from dateutil import parser
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.supabase_helper import *

view_shop_bp = Blueprint('view_shop', __name__)

@view_shop_bp.route('/shop/<int:seller_id>')
def view_shop(seller_id):
    print(f"🏪 DEBUG: Accessing shop with seller_id: {seller_id}")
    
    if 'user_id' not in session or not session.get('logged_in'):
        print("❌ DEBUG: User not logged in, redirecting to login")
        return redirect(url_for('auth.login'))
    
    supabase = get_supabase()
    if not supabase:
        print("❌ DEBUG: Supabase connection failed")
        return render_template('view_shop.html', shop=None, products=[], total_reviews=0, all_categories=[])
    
    try:
        # Get shop info
        print(f"🔍 DEBUG: Fetching shop info for seller_id: {seller_id}")
        shop_response = supabase.table('sellers').select('seller_id, shop_name, shop_logo, shop_description, created_at').eq('seller_id', seller_id).execute()
        
        if not shop_response.data:
            print(f"❌ DEBUG: No shop found for seller_id: {seller_id}")
            return render_template('view_shop.html', shop=None, products=[], total_reviews=0, all_categories=[])
        
        shop = shop_response.data[0]
        print(f"✅ DEBUG: Shop found: {shop['shop_name']}")
        
        # Parse created_at date
        if shop.get('created_at'):
            shop['created_at'] = parser.parse(shop['created_at'])
        
        # Get shop products (limit to 50 for performance)
        print(f"📦 DEBUG: Fetching products for seller_id: {seller_id}")
        products_response = supabase.table('products').select('''
            product_id,
            product_name,
            category,
            price,
            rating,
            total_reviews,
            total_sold,
            created_at
        ''').eq('seller_id', seller_id).eq('is_active', True).order('created_at', desc=True).limit(50).execute()
        
        products = []
        total_reviews = 0
        total_rating = 0
        products_with_reviews = 0
        
        if products_response.data:
            print(f"✅ DEBUG: Found {len(products_response.data)} products")
            product_ids = [p['product_id'] for p in products_response.data]
            
            # Get primary images
            images_response = supabase.table('product_images').select('product_id, image_url').eq('is_primary', True).in_('product_id', product_ids).execute()
            images_dict = {img['product_id']: img['image_url'] for img in images_response.data} if images_response.data else {}
            print(f"🖼️ DEBUG: Found {len(images_dict)} product images")
            
            for product in products_response.data:
                product['primary_image'] = images_dict.get(product['product_id'])
                
                # Parse created_at date
                if product.get('created_at'):
                    product['created_at'] = parser.parse(product['created_at'])
                
                products.append(product)
                
                # Calculate shop rating and total reviews
                if product.get('total_reviews', 0) > 0:
                    total_reviews += product['total_reviews']
                    total_rating += product.get('rating', 0) * product['total_reviews']
                    products_with_reviews += 1
        else:
            print("⚠️ DEBUG: No products found for this shop")
        
        # Calculate average shop rating
        shop['rating'] = (total_rating / total_reviews) if total_reviews > 0 else 0.0
        
        # Get unique categories from products
        all_categories = list(set([p.get('category') for p in products_response.data if p.get('category')])) if products_response.data else []
        all_categories.sort()
        
        print(f"✅ DEBUG: Rendering view_shop with {len(products)} products, rating: {shop['rating']}, reviews: {total_reviews}, categories: {len(all_categories)}")
        return render_template('view_shop.html', shop=shop, products=products, total_reviews=total_reviews, all_categories=all_categories)
    
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return render_template('view_shop.html', shop=None, products=[], total_reviews=0, all_categories=[])

