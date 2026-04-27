from flask import Blueprint, render_template, session, redirect, url_for
from .profile_helper import get_user_profile_data
import sys
import os
from datetime import date

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.supabase_helper import *

myAccount_vouchers_bp = Blueprint('myAccount_vouchers', __name__)

@myAccount_vouchers_bp.route('/myAccount_vouchers')
def myAccount_vouchers():
    # Check if user is logged in
    if 'user_id' not in session or not session.get('logged_in'):
        return redirect(url_for('auth.login'))
    
    profile = get_user_profile_data()
    
    supabase = get_supabase()
    if not supabase:
        return render_template('accounts/myAccount_vouchers.html', user_profile=profile, vouchers=[])
    
    try:
        # Get buyer_id from user_id
        buyer = get_buyer_by_user_id(session['user_id'])
        
        if not buyer:
            return render_template('accounts/myAccount_vouchers.html', user_profile=profile, vouchers=[])
        
        buyer_id = buyer['buyer_id']
        
        # Fetch buyer's personal vouchers
        # Only show vouchers that still have remaining uses and not expired
        today = date.today().isoformat()
        
        vouchers_response = supabase.table('buyer_vouchers').select('''
            buyer_voucher_id,
            times_remaining,
            used_at,
            claimed_at,
            vouchers (
                voucher_id,
                voucher_code,
                voucher_name,
                voucher_type,
                discount_percent,
                start_date,
                end_date
            )
        ''').eq('buyer_id', buyer_id).gt('times_remaining', 0).gte('vouchers.end_date', today).execute()
        
        vouchers = []
        if vouchers_response.data:
            for bv in vouchers_response.data:
                voucher = bv.get('vouchers', {})
                
                # Get shop count for this voucher
                shop_count_response = supabase.table('seller_vouchers').select('seller_id', count='exact').eq('voucher_id', voucher.get('voucher_id')).eq('is_active', True).execute()
                shop_count = shop_count_response.count if shop_count_response.count else 0
                
                vouchers.append({
                    'buyer_voucher_id': bv['buyer_voucher_id'],
                    'voucher_id': voucher.get('voucher_id'),
                    'voucher_code': voucher.get('voucher_code'),
                    'voucher_name': voucher.get('voucher_name'),
                    'voucher_type': voucher.get('voucher_type'),
                    'discount_percent': voucher.get('discount_percent'),
                    'start_date': voucher.get('start_date'),
                    'end_date': voucher.get('end_date'),
                    'times_remaining': bv['times_remaining'],
                    'used_at': bv['used_at'],
                    'claimed_at': bv['claimed_at'],
                    'shop_count': shop_count
                })
            
            # Sort by voucher_type and discount_percent
            vouchers.sort(key=lambda x: (x['voucher_type'], -x['discount_percent'], x['end_date']), reverse=True)
        
        return render_template('accounts/myAccount_vouchers.html', user_profile=profile, vouchers=vouchers)
    
    except Exception as e:
        print(f"Error fetching vouchers: {e}")
        import traceback
        print(traceback.format_exc())
        return render_template('accounts/myAccount_vouchers.html', user_profile=profile, vouchers=[])
