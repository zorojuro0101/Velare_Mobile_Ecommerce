from flask import Blueprint, render_template, session, redirect, url_for
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.supabase_helper import *

view_shop_bp = Blueprint('view_shop', __name__)

@view_shop_bp.route('/shop/<int:seller_id>')
def view_shop(seller_id):
    if 'user_id' not in session or not session.get('logged_in'):
        return redirect(url_for('auth.login'))
    
    supabase = get_supabase()
    if not supabase:
        return render_template('view_shop.html', shop=None, products=[])
    
    try:
        # Get shop info
        shop_response = supabase.table('sellers').select('seller_id, shop_name, shop_logo, shop_description').eq('seller_id', seller_id).execute()
        
        if not shop_response.data:
            return render_template('view_shop.html', shop=None, products=[])
        
        shop = shop_response.data[0]
        
        # Get shop products
        products_response = supabase.table('products').select('''
            product_id,
            product_name,
            price,
            rating,
            total_reviews,
            total_sold
        ''').eq('seller_id', seller_id).eq('is_active', True).order('created_at', desc=True).execute()
        
        products = []
        if products_response.data:
            product_ids = [p['product_id'] for p in products_response.data]
            
            # Get primary images
            images_response = supabase.table('product_images').select('product_id, image_url').eq('is_primary', True).in_('product_id', product_ids).execute()
            images_dict = {img['product_id']: img['image_url'] for img in images_response.data} if images_response.data else {}
            
            for product in products_response.data:
                product['primary_image'] = images_dict.get(product['product_id'])
                products.append(product)
        
        return render_template('view_shop.html', shop=shop, products=products)
    
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        return render_template('view_shop.html', shop=None, products=[])
