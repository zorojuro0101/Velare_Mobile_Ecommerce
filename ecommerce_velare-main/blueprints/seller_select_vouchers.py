from flask import Blueprint, render_template, request, jsonify, session
from datetime import datetime
from dateutil import parser
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_config import get_supabase_client
from utils.auth_decorators import seller_required

seller_select_vouchers_bp = Blueprint('seller_select_vouchers', __name__)

@seller_select_vouchers_bp.route('/seller/select-vouchers')
@seller_required
def seller_select_vouchers():
    """Display seller voucher selection page"""
    seller_id = session.get('seller_id')
    print(f"🔍 Seller Select Vouchers - seller_id: {seller_id}")
    
    supabase = get_supabase_client()
    if not supabase:
        print("❌ Supabase client not available")
        return render_template('seller/seller_select_vouchers.html', 
                             seller=None,
                             available_vouchers=[], 
                             selected_vouchers=[], 
                             error='Database connection failed')
    
    try:
        # Get seller information
        seller_response = supabase.table('sellers').select(
            'seller_id, shop_name, shop_logo'
        ).eq('seller_id', seller_id).execute()
        
        seller = seller_response.data[0] if seller_response.data else None
        print(f"👤 Seller: {seller}")
        
        # Get all available vouchers (not expired)
        today = datetime.now().date().isoformat()
        vouchers_response = supabase.table('vouchers').select(
            'voucher_id, voucher_code, voucher_name, voucher_type, discount_percent, start_date, end_date, created_at'
        ).gte('end_date', today).order('created_at', desc=True).execute()
        
        all_vouchers = vouchers_response.data if vouchers_response.data else []
        print(f"📦 Found {len(all_vouchers)} available vouchers")
        
        # Get vouchers selected by this seller
        selected_response = supabase.table('seller_vouchers').select(
            'seller_voucher_id, voucher_id, is_active, selected_at, vouchers(voucher_code, voucher_name, voucher_type, discount_percent, start_date, end_date)'
        ).eq('seller_id', seller_id).eq('is_active', True).order('selected_at', desc=True).execute()
        
        # Format selected vouchers
        selected_vouchers = []
        if selected_response.data:
            for sv in selected_response.data:
                voucher_data = sv.get('vouchers', {})
                
                # Parse dates
                start_date = parser.parse(voucher_data.get('start_date')) if voucher_data.get('start_date') else None
                end_date = parser.parse(voucher_data.get('end_date')) if voucher_data.get('end_date') else None
                
                selected_vouchers.append({
                    'seller_voucher_id': sv['seller_voucher_id'],
                    'voucher_id': sv['voucher_id'],
                    'is_active': sv['is_active'],
                    'selected_at': sv['selected_at'],
                    'voucher_code': voucher_data.get('voucher_code'),
                    'voucher_name': voucher_data.get('voucher_name'),
                    'voucher_type': voucher_data.get('voucher_type'),
                    'discount_percent': voucher_data.get('discount_percent'),
                    'start_date': start_date,
                    'end_date': end_date
                })
        
        print(f"✅ Found {len(selected_vouchers)} selected vouchers")
        
        # Mark which vouchers are already selected
        selected_voucher_ids = {v['voucher_id'] for v in selected_vouchers}
        
        available_vouchers = []
        for voucher in all_vouchers:
            # Parse dates for available vouchers
            start_date = parser.parse(voucher.get('start_date')) if voucher.get('start_date') else None
            end_date = parser.parse(voucher.get('end_date')) if voucher.get('end_date') else None
            
            voucher['start_date'] = start_date
            voucher['end_date'] = end_date
            voucher['is_selected'] = voucher['voucher_id'] in selected_voucher_ids
            available_vouchers.append(voucher)
        
        print(f"📦 Prepared {len(available_vouchers)} available vouchers with parsed dates")
        
        return render_template('seller/seller_select_vouchers.html',
                             seller=seller,
                             available_vouchers=available_vouchers,
                             selected_vouchers=selected_vouchers)
    
    except Exception as e:
        print(f"❌ Error fetching seller vouchers: {e}")
        import traceback
        traceback.print_exc()
        return render_template('seller/seller_select_vouchers.html',
                             seller=None,
                             available_vouchers=[], 
                             selected_vouchers=[], 
                             error=str(e))

@seller_select_vouchers_bp.route('/seller/vouchers/select', methods=['POST'])
@seller_required
def select_voucher():
    """Select a voucher for the seller's shop"""
    try:
        data = request.get_json()
        voucher_id = data.get('voucher_id')
        seller_id = session.get('seller_id')
        
        print(f"🔍 Select Voucher - seller_id: {seller_id}, voucher_id: {voucher_id}")
        
        if not voucher_id:
            return jsonify({'success': False, 'message': 'Voucher ID is required'}), 400
        
        supabase = get_supabase_client()
        if not supabase:
            print("❌ Supabase client not available")
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Check if voucher exists and is valid
            today = datetime.now().date().isoformat()
            voucher_response = supabase.table('vouchers').select(
                'voucher_id, voucher_code, voucher_name, end_date'
            ).eq('voucher_id', voucher_id).gte('end_date', today).execute()
            
            if not voucher_response.data:
                return jsonify({'success': False, 'message': 'Voucher not found or expired'}), 404
            
            voucher = voucher_response.data[0]
            print(f"✅ Voucher found: {voucher['voucher_code']}")
            
            # Check if already selected (active or inactive)
            existing_response = supabase.table('seller_vouchers').select(
                'seller_voucher_id, is_active'
            ).eq('seller_id', seller_id).eq('voucher_id', voucher_id).execute()
            
            existing = existing_response.data[0] if existing_response.data else None
            
            if existing:
                if existing['is_active']:
                    return jsonify({'success': False, 'message': 'Voucher already selected'}), 400
                else:
                    # Reactivate existing entry instead of inserting new one
                    update_response = supabase.table('seller_vouchers').update({
                        'is_active': True,
                        'selected_at': datetime.now().isoformat()
                    }).eq('seller_id', seller_id).eq('voucher_id', voucher_id).execute()
                    print(f"✅ Voucher reactivated: {update_response.data}")
            else:
                # Insert new selection
                insert_response = supabase.table('seller_vouchers').insert({
                    'seller_id': seller_id,
                    'voucher_id': voucher_id,
                    'is_active': True
                }).execute()
                print(f"✅ Voucher selection inserted: {insert_response.data}")
            
            # AUTO-ASSIGN VOUCHER TO ALL BUYERS
            # Get all active buyers
            buyers_response = supabase.table('buyers').select(
                'buyer_id, users!inner(status)'
            ).eq('users.status', 'active').execute()
            
            buyers = buyers_response.data if buyers_response.data else []
            print(f"📦 Found {len(buyers)} active buyers")
            
            if buyers:
                print(f"   Buyer IDs: {[b['buyer_id'] for b in buyers]}")
            
            # Assign voucher to each buyer (if not already assigned)
            assigned_count = 0
            for buyer in buyers:
                buyer_id = buyer['buyer_id']
                
                # Check if buyer already has this voucher
                existing_buyer_voucher = supabase.table('buyer_vouchers').select(
                    'buyer_voucher_id, is_used, times_remaining'
                ).eq('buyer_id', buyer_id).eq('voucher_id', voucher_id).execute()
                
                if not existing_buyer_voucher.data:
                    print(f"   ➕ Assigning to buyer_id: {buyer_id}")
                    # Insert new buyer voucher with times_remaining
                    insert_result = supabase.table('buyer_vouchers').insert({
                        'buyer_id': buyer_id,
                        'voucher_id': voucher_id,
                        'is_used': False,
                        'times_remaining': 1  # Set default times_remaining to 1
                    }).execute()
                    print(f"      ✅ Inserted: {insert_result.data}")
                    assigned_count += 1
                else:
                    existing_data = existing_buyer_voucher.data[0]
                    print(f"   ⏭️ Skipping buyer_id: {buyer_id} (already has voucher: is_used={existing_data.get('is_used')}, times_remaining={existing_data.get('times_remaining')})")
            
            print(f"✅ Assigned voucher to {assigned_count} buyers")
            
            return jsonify({
                'success': True,
                'message': f'Voucher "{voucher["voucher_code"]}" added to your shop and assigned to {assigned_count} buyers'
            })
        
        except Exception as e:
            print(f"❌ Database error: {e}")
            import traceback
            traceback.print_exc()
            return jsonify({'success': False, 'message': f'Database error: {str(e)}'}), 500
    
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': f'Unexpected error: {str(e)}'}), 500

@seller_select_vouchers_bp.route('/seller/vouchers/remove', methods=['POST'])
@seller_required
def remove_voucher():
    """Remove a voucher from the seller's shop"""
    try:
        data = request.get_json()
        voucher_id = data.get('voucher_id')
        seller_id = session.get('seller_id')
        
        print(f"🔍 Remove Voucher - seller_id: {seller_id}, voucher_id: {voucher_id}")
        
        if not voucher_id:
            return jsonify({'success': False, 'message': 'Voucher ID is required'}), 400
        
        supabase = get_supabase_client()
        if not supabase:
            print("❌ Supabase client not available")
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Remove voucher selection (set is_active to FALSE)
            update_response = supabase.table('seller_vouchers').update({
                'is_active': False
            }).eq('seller_id', seller_id).eq('voucher_id', voucher_id).eq('is_active', True).execute()
            
            if not update_response.data:
                return jsonify({'success': False, 'message': 'Voucher selection not found'}), 404
            
            print(f"✅ Voucher removed: {update_response.data}")
            
            return jsonify({
                'success': True,
                'message': 'Voucher removed from your shop'
            })
        
        except Exception as e:
            print(f"❌ Error removing voucher: {e}")
            import traceback
            traceback.print_exc()
            return jsonify({'success': False, 'message': f'Error: {str(e)}'}), 500
    
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': f'Unexpected error: {str(e)}'}), 500

