from flask import Blueprint, render_template, session, redirect, url_for, request
from .profile_helper import get_user_profile_data
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.supabase_helper import (
    get_voucher_with_shop_count,
    get_products_by_voucher
)

voucher_products_bp = Blueprint('voucher_products', __name__)

@voucher_products_bp.route('/voucher-products/<int:voucher_id>')
def voucher_products(voucher_id):
    """Display all products from sellers offering this voucher"""
    # Check if user is logged in
    if 'user_id' not in session or not session.get('logged_in'):
        return redirect(url_for('auth.login'))
    
    profile = get_user_profile_data()
    
    try:
        # Get voucher details with shop count
        voucher = get_voucher_with_shop_count(voucher_id)
        
        if not voucher:
            return render_template('accounts/voucher_products.html',
                                 user_profile=profile,
                                 voucher=None,
                                 products=[])
        
        # Get all products from sellers offering this voucher
        products = get_products_by_voucher(voucher_id)
        
        return render_template('accounts/voucher_products.html',
                             user_profile=profile,
                             voucher=voucher,
                             products=products)
    
    except Exception as e:
        print(f"Error fetching voucher products: {e}")
        import traceback
        print(traceback.format_exc())
        return render_template('accounts/voucher_products.html',
                             user_profile=profile,
                             voucher=None,
                             products=[])
