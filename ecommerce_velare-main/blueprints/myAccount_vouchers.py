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
    """🎫 Render vouchers page with optimized data loading"""
    print("=" * 80)
    print("🎫 [VOUCHERS PAGE] Loading vouchers page...")
    print("=" * 80)
    
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
        
        # Fetch buyer's personal vouchers - LIMITED TO 100 MOST RECENT
        today = date.today().isoformat()
        
        print(f"🔍 Fetching vouchers for buyer_id: {buyer_id}, today: {today}")
        
        # Get all buyer vouchers (limited to 100)
        all_vouchers_response = supabase.table('buyer_vouchers').select('''
            buyer_voucher_id,
            times_remaining,
            used_at,
            claimed_at,
            is_used,
            vouchers (
                voucher_id,
                voucher_code,
                voucher_name,
                voucher_type,
                discount_percent,
                start_date,
                end_date
            )
        ''').eq('buyer_id', buyer_id).eq('is_used', False).order('claimed_at', desc=True).limit(100).execute()
        
        print(f"📦 Total vouchers fetched: {len(all_vouchers_response.data) if all_vouchers_response.data else 0}")
        
        # Get all unique voucher_ids to fetch shop counts in ONE query (NO N+1 QUERY)
        voucher_ids = [bv.get('vouchers', {}).get('voucher_id') for bv in all_vouchers_response.data if bv.get('vouchers', {}).get('voucher_id')]
        
        # Fetch ALL shop counts at once
        shop_counts = {}
        if voucher_ids:
            shop_count_response = supabase.table('seller_vouchers').select('voucher_id', count='exact').in_('voucher_id', voucher_ids).eq('is_active', True).execute()
            # Group by voucher_id
            if shop_count_response.data:
                for sv in shop_count_response.data:
                    vid = sv['voucher_id']
                    shop_counts[vid] = shop_counts.get(vid, 0) + 1
        
        vouchers = []
        if all_vouchers_response.data:
            for bv in all_vouchers_response.data:
                voucher = bv.get('vouchers', {})
                
                # Skip if no voucher data
                if not voucher:
                    continue
                
                # Filter expired vouchers in Python
                end_date_str = voucher.get('end_date')
                if end_date_str:
                    # Parse end_date and compare
                    from datetime import datetime
                    try:
                        end_date = datetime.fromisoformat(end_date_str.replace('Z', '+00:00')).date()
                        if end_date < date.today():
                            print(f"   ❌ Skipping expired voucher: {voucher.get('voucher_code')} (end_date: {end_date})")
                            continue
                    except Exception as e:
                        print(f"   ⚠️ Error parsing date for {voucher.get('voucher_code')}: {e}")
                        continue
                
                print(f"   ✅ Including voucher: {voucher.get('voucher_code')}")
                
                # Get shop count from pre-fetched data
                shop_count = shop_counts.get(voucher.get('voucher_id'), 0)
                
                # Parse start_date and end_date for template
                start_date_parsed = None
                end_date_parsed = None
                
                start_date_str = voucher.get('start_date')
                if start_date_str:
                    try:
                        from datetime import datetime
                        start_date_parsed = datetime.fromisoformat(start_date_str.replace('Z', '+00:00'))
                    except:
                        pass
                
                if end_date_str:
                    try:
                        from datetime import datetime
                        end_date_parsed = datetime.fromisoformat(end_date_str.replace('Z', '+00:00'))
                    except:
                        pass
                
                vouchers.append({
                    'buyer_voucher_id': bv['buyer_voucher_id'],
                    'voucher_id': voucher.get('voucher_id'),
                    'voucher_code': voucher.get('voucher_code'),
                    'voucher_name': voucher.get('voucher_name'),
                    'voucher_type': voucher.get('voucher_type'),
                    'discount_percent': voucher.get('discount_percent'),
                    'start_date': start_date_parsed,
                    'end_date': end_date_parsed,
                    'times_remaining': bv.get('times_remaining', 1),  # Default to 1 if NULL
                    'used_at': bv.get('used_at'),
                    'claimed_at': bv.get('claimed_at'),
                    'shop_count': shop_count
                })
            
            # Sort by voucher_type and discount_percent
            vouchers.sort(key=lambda x: (x['voucher_type'], -x['discount_percent'], x['end_date']), reverse=True)
        
        print(f"🎉 Final vouchers to display: {len(vouchers)}")
        
        return render_template('accounts/myAccount_vouchers.html', user_profile=profile, vouchers=vouchers)
    
    except Exception as e:
        print(f"❌ Error fetching vouchers: {e}")
        import traceback
        print(traceback.format_exc())
        return render_template('accounts/myAccount_vouchers.html', user_profile=profile, vouchers=[], error=str(e))
