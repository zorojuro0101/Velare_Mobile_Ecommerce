from flask import Blueprint, render_template, request
import sys
import os
import random

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.supabase_helper import get_supabase, fix_image_urls_in_data

browse_product_bp = Blueprint('browse_product', __name__)

@browse_product_bp.route('/browse_product')
def browse_product():
    category = request.args.get('category', '')
    search_query = request.args.get('q', '')
    filter_type = request.args.get('filter', '')
    
    supabase = get_supabase()
    products = []
    category_name = "All Products"
    hero_product = None
    
    if supabase:
        try:
            # Category mapping
            category_mapping = {
                'tops-blouses': ['tops-blouses', 'tops', 'blouses'],
                'dresses-skirts': ['dresses-skirts', 'Dresses', 'Skirts'],
                'activewear-yoga': ['activewear-yoga', 'Active Wear', 'Yoga Pants', 'Active Wear-Yoga Pants', 'activewear', 'yoga-pants'],
                'lingerie-sleepwear': ['lingerie-sleepwear', 'Lingerie', 'Sleepwear'],
                'jackets-coats': ['jackets-coats', 'Jackets', 'Coats'],
                'shoes-accessories': ['shoes-accessories', 'Shoes', 'Accessories']
            }
            
            # Get hero product (randomly choose type)
            hero_type = random.choice(['best_seller', 'top_rated', 'new_arrival'])
            
            hero_query = supabase.table('products').select('''
                product_id,
                product_name,
                price,
                rating,
                total_reviews,
                total_sold,
                created_at,
                sellers (
                    shop_name
                )
            ''').eq('is_active', True)
            
            # Apply category filter for hero if category is selected
            if category and category in category_mapping:
                hero_query = hero_query.in_('category', category_mapping[category])
            
            if hero_type == 'best_seller':
                hero_query = hero_query.order('total_sold', desc=True).order('rating', desc=True)
            elif hero_type == 'top_rated':
                hero_query = hero_query.gt('rating', 0).order('rating', desc=True).order('total_reviews', desc=True)
            else:  # new_arrival
                hero_query = hero_query.order('created_at', desc=True)
            
            hero_response = hero_query.limit(1).execute()
            
            if hero_response.data:
                hero = hero_response.data[0]
                seller = hero.get('sellers', {})
                
                # Get primary image
                image_response = supabase.table('product_images').select('image_url').eq('product_id', hero['product_id']).eq('is_primary', True).order('display_order').limit(1).execute()
                
                # Fix image URL case
                primary_image = None
                if image_response.data:
                    image_data = fix_image_urls_in_data(image_response.data[0])
                    primary_image = image_data.get('image_url')
                
                hero_product = {
                    'product_id': hero['product_id'],
                    'product_name': hero['product_name'],
                    'price': hero['price'],
                    'rating': hero.get('rating'),
                    'total_sold': hero.get('total_sold'),
                    'shop_name': seller.get('shop_name') if isinstance(seller, dict) else None,
                    'primary_image': primary_image,
                    'badge_type': 'Best Seller' if hero_type == 'best_seller' else ('Top Rated' if hero_type == 'top_rated' else 'New Arrival')
                }
            
            # Build main products query
            products_query = supabase.table('products').select('''
                product_id,
                product_name,
                materials,
                price,
                category,
                rating,
                total_reviews,
                total_sold,
                created_at,
                sellers (
                    shop_name
                )
            ''').eq('is_active', True)
            
            # Apply filters
            if filter_type == 'best-sellers':
                products_query = products_query.order('total_sold', desc=True).order('rating', desc=True)
                category_name = "Exclusively In Demand"
            elif filter_type == 'new-arrivals':
                products_query = products_query.order('created_at', desc=True)
                category_name = "What's New"
            elif filter_type == 'top-rated':
                products_query = products_query.gt('total_reviews', 0).order('rating', desc=True).order('total_reviews', desc=True)
                category_name = "Beloved by Connoisseurs"
            elif filter_type == 'random':
                # Supabase doesn't have RAND(), so we'll fetch all and shuffle in Python
                category_name = "The Art of Choice"
            else:
                # Default: filter by category and/or search
                if category and category in category_mapping:
                    products_query = products_query.in_('category', category_mapping[category])
                    category_map = {
                        'dresses-skirts': 'Dresses & Skirts',
                        'tops-blouses': 'Tops & Blouses',
                        'activewear-yoga': 'Activewear & Yoga',
                        'lingerie-sleepwear': 'Lingerie & Sleepwear',
                        'jackets-coats': 'Jackets & Coats',
                        'shoes-accessories': 'Shoes & Accessories'
                    }
                    category_name = category_map.get(category, 'Products')
                
                if search_query:
                    products_query = products_query.ilike('product_name', f'%{search_query}%')
                    category_name = f"Search Results for '{search_query}'"
                
                products_query = products_query.order('created_at', desc=True)
            
            products_response = products_query.execute()
            
            if products_response.data:
                # Get product IDs for batch image fetch
                product_ids = [p['product_id'] for p in products_response.data]
                
                # Fetch primary images for all products
                images_response = supabase.table('product_images').select('product_id, image_url').eq('is_primary', True).in_('product_id', product_ids).execute()
                
                # Debug: Print original images
                print(f"\n=== BROWSE PRODUCT IMAGES (BEFORE FIX) ===")
                if images_response.data:
                    for img in images_response.data[:3]:  # Show first 3
                        print(f"  Product {img.get('product_id')}: {img.get('image_url')}")
                
                # Fix image URL cases
                images_data = fix_image_urls_in_data(images_response.data) if images_response.data else []
                
                # Debug: Print fixed images
                print(f"\n=== BROWSE PRODUCT IMAGES (AFTER FIX) ===")
                for img in images_data[:3]:  # Show first 3
                    print(f"  Product {img.get('product_id')}: {img.get('image_url')}")
                
                images_dict = {img['product_id']: img['image_url'] for img in images_data}
                
                # Build products list
                for product in products_response.data:
                    seller = product.get('sellers', {})
                    
                    products.append({
                        'product_id': product['product_id'],
                        'product_name': product['product_name'],
                        'materials': product['materials'],
                        'price': product['price'],
                        'category': product['category'],
                        'rating': product.get('rating'),
                        'total_reviews': product.get('total_reviews'),
                        'total_sold': product.get('total_sold'),
                        'shop_name': seller.get('shop_name') if isinstance(seller, dict) else None,
                        'primary_image': images_dict.get(product['product_id'])
                    })
                
                # Shuffle for random filter
                if filter_type == 'random':
                    random.shuffle(products)
            
        except Exception as e:
            print(f"Error fetching products: {e}")
            import traceback
            traceback.print_exc()
    
    return render_template('browse_product.html', 
                          category=category, 
                          category_name=category_name, 
                          products=products, 
                          search_query=search_query,
                          hero_product=hero_product,
                          filter_type=filter_type)
