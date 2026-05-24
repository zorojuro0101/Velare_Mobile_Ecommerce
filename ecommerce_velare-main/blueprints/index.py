from flask import Blueprint, render_template, session
import sys
import os
import random

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_config import get_supabase_client

index_bp = Blueprint('index', __name__)

def fix_image_path(image_url):
    """Handle both Supabase URLs and local paths"""
    if not image_url:
        return None
    
    # If it's a Supabase URL, return as-is
    if image_url.startswith('http://') or image_url.startswith('https://'):
        return image_url
    
    # If it's a local path starting with 'static/', remove the prefix
    if image_url.startswith('static/'):
        return image_url[7:]  # Remove 'static/' prefix
    
    return image_url

@index_bp.route('/')
def index():
    """🏠 Home page with optimized product loading"""
    print("=" * 80)
    print("🏠 [HOME PAGE] Loading index page...")
    print("=" * 80)
    
    is_logged_in = 'user_id' in session
    
    # Initialize default values
    best_sellers = []
    latest_products = []
    top_rated_products = []
    random_products = []
    
    supabase = get_supabase_client()
    if supabase:
        try:
            # OPTIMIZED: Limit each section to reasonable amounts for homepage
            
            # Get TOP 12 best sellers (highest total_sold) with active status
            print("📊 Fetching best sellers...")
            best_sellers_response = supabase.table('products').select(
                'product_id, product_name, category, product_images!inner(image_url)'
            ).eq('is_active', True).gt('total_sold', 0).eq('product_images.is_primary', True).order('total_sold', desc=True).limit(12).execute()
            
            if best_sellers_response.data:
                best_sellers = []
                for product in best_sellers_response.data:
                    # Extract image_url from nested product_images
                    image_url = product.get('product_images', [{}])[0].get('image_url') if product.get('product_images') else None
                    best_sellers.append({
                        'product_id': product['product_id'],
                        'product_name': product['product_name'],
                        'category': product['category'],
                        'image_url': fix_image_path(image_url)
                    })
                print(f"✅ Loaded {len(best_sellers)} best sellers")
            
            # Get TOP 12 latest products (most recent)
            print("🆕 Fetching latest products...")
            latest_response = supabase.table('products').select(
                'product_id, product_name, category, created_at, product_images!inner(image_url)'
            ).eq('is_active', True).eq('product_images.is_primary', True).order('created_at', desc=True).limit(12).execute()
            
            if latest_response.data:
                latest_products = []
                for product in latest_response.data:
                    image_url = product.get('product_images', [{}])[0].get('image_url') if product.get('product_images') else None
                    latest_products.append({
                        'product_id': product['product_id'],
                        'product_name': product['product_name'],
                        'category': product['category'],
                        'image_url': fix_image_path(image_url)
                    })
                print(f"✅ Loaded {len(latest_products)} latest products")
            
            # Get TOP 12 rated products (highest rating with at least 1 review)
            print("⭐ Fetching top rated products...")
            top_rated_response = supabase.table('products').select(
                'product_id, product_name, category, rating, total_reviews, product_images!inner(image_url)'
            ).eq('is_active', True).gt('total_reviews', 0).eq('product_images.is_primary', True).order('rating', desc=True).order('total_reviews', desc=True).limit(12).execute()
            
            if top_rated_response.data:
                top_rated_products = []
                for product in top_rated_response.data:
                    image_url = product.get('product_images', [{}])[0].get('image_url') if product.get('product_images') else None
                    top_rated_products.append({
                        'product_id': product['product_id'],
                        'product_name': product['product_name'],
                        'category': product['category'],
                        'image_url': fix_image_path(image_url)
                    })
                print(f"✅ Loaded {len(top_rated_products)} top rated products")
            
            # Get 20 random products (fetch 20 and shuffle for variety)
            print("🎲 Fetching random products...")
            random_response = supabase.table('products').select(
                'product_id, product_name, category, product_images!inner(image_url)'
            ).eq('is_active', True).eq('product_images.is_primary', True).limit(20).execute()
            
            if random_response.data:
                random_products = []
                for product in random_response.data:
                    image_url = product.get('product_images', [{}])[0].get('image_url') if product.get('product_images') else None
                    random_products.append({
                        'product_id': product['product_id'],
                        'product_name': product['product_name'],
                        'category': product['category'],
                        'image_url': fix_image_path(image_url)
                    })
                
                # Shuffle for random display
                if random_products:
                    random.shuffle(random_products)
                print(f"✅ Loaded {len(random_products)} random products")
            
            print(f"✅ Homepage loaded: {len(best_sellers)} best sellers, {len(latest_products)} latest, {len(top_rated_products)} top rated, {len(random_products)} random")
            
        except Exception as e:
            print(f"❌ Error fetching products: {str(e)}")
            import traceback
            traceback.print_exc()
    
    return render_template('index.html', 
                         is_logged_in=is_logged_in,
                         best_sellers=best_sellers,
                         latest_products=latest_products,
                         top_rated_products=top_rated_products,
                         random_products=random_products)
