from flask import Blueprint, render_template, request, jsonify, session, redirect, url_for
from datetime import datetime
import sys
import os

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_config import get_supabase_client
from utils.auth_decorators import admin_required

admin_vouchers_bp = Blueprint('admin_vouchers', __name__)

@admin_vouchers_bp.route('/admin/vouchers')
@admin_required
def admin_vouchers():
    """Display admin voucher management page using Supabase"""
    print("\n" + "="*80)
    print("🎟️ [ADMIN VOUCHERS] Loading vouchers page...")
    print("="*80 + "\n")
    
    supabase = get_supabase_client()
    if not supabase:
        print("❌ Supabase connection failed")
        return render_template('admin/admin_vouchers.html', vouchers=[], error='Database connection failed')
    
    try:
        # Fetch all vouchers
        print("🔍 Fetching all vouchers...")
        vouchers_response = supabase.table('vouchers').select('''
            voucher_id,
            voucher_code,
            voucher_name,
            voucher_type,
            discount_percent,
            start_date,
            end_date,
            created_at
        ''').order('created_at', desc=True).execute()
        
        vouchers = vouchers_response.data if vouchers_response.data else []
        
        # Parse date strings to datetime objects
        for voucher in vouchers:
            if voucher.get('start_date') and isinstance(voucher['start_date'], str):
                try:
                    voucher['start_date'] = datetime.fromisoformat(voucher['start_date'].replace('Z', '+00:00'))
                except:
                    pass
            if voucher.get('end_date') and isinstance(voucher['end_date'], str):
                try:
                    voucher['end_date'] = datetime.fromisoformat(voucher['end_date'].replace('Z', '+00:00'))
                except:
                    pass
            if voucher.get('created_at') and isinstance(voucher['created_at'], str):
                try:
                    voucher['created_at'] = datetime.fromisoformat(voucher['created_at'].replace('Z', '+00:00'))
                except:
                    pass
        
        print(f"✅ Found {len(vouchers)} vouchers")
        print("="*80 + "\n")
        
        return render_template('admin/admin_vouchers.html', vouchers=vouchers)
    
    except Exception as e:
        print(f"❌ Error fetching vouchers: {e}")
        import traceback
        traceback.print_exc()
        return render_template('admin/admin_vouchers.html', vouchers=[], error=str(e))

@admin_vouchers_bp.route('/admin/vouchers/create', methods=['POST'])
@admin_required
def create_voucher():
    """Create a new voucher using Supabase"""
    try:
        data = request.get_json()
        
        print("\n" + "="*80)
        print("➕ [CREATE VOUCHER] Processing new voucher...")
        print(f"📦 Data: {data}")
        print("="*80 + "\n")
        
        # Validate required fields
        required_fields = ['voucher_type', 'voucher_percent', 'start_date', 'end_date']
        for field in required_fields:
            if not data.get(field):
                return jsonify({'success': False, 'message': f'{field} is required'}), 400
        
        voucher_type_input = data['voucher_type'].strip().lower()  # 'shipping' or 'discount'
        voucher_percent = int(data.get('voucher_percent', 0))
        start_date = data['start_date']
        end_date = data['end_date']
        
        # Validate voucher type
        if voucher_type_input not in ['shipping', 'discount']:
            return jsonify({'success': False, 'message': 'Invalid voucher type'}), 400
        
        # Validate percentage
        if voucher_percent <= 0 or voucher_percent > 100:
            return jsonify({'success': False, 'message': 'Percentage must be between 1 and 100'}), 400
        
        # Auto-generate voucher code and name based on type and percentage
        if voucher_type_input == 'shipping':
            if voucher_percent == 100:
                voucher_code = 'FREESHIP'
            else:
                voucher_code = f'SHIP{voucher_percent}'
            voucher_name = f'{voucher_percent}% Free Shipping'
            voucher_type = 'free_shipping'  # Database uses 'free_shipping'
            discount_percent = voucher_percent
        else:  # discount
            voucher_code = f'SAVE{voucher_percent}'
            voucher_name = f'{voucher_percent}% Discount'
            voucher_type = 'discount'
            discount_percent = voucher_percent
        
        print(f"🎟️ Generated: code={voucher_code}, name={voucher_name}, type={voucher_type}")
        
        # Validate dates
        try:
            start = datetime.strptime(start_date, '%Y-%m-%d')
            end = datetime.strptime(end_date, '%Y-%m-%d')
            if end < start:
                return jsonify({'success': False, 'message': 'End date must be after start date'}), 400
        except ValueError:
            return jsonify({'success': False, 'message': 'Invalid date format'}), 400
        
        supabase = get_supabase_client()
        if not supabase:
            print("❌ Supabase connection failed")
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Check if voucher code already exists
            print(f"🔍 Checking if voucher code '{voucher_code}' exists...")
            existing_response = supabase.table('vouchers').select('voucher_id').eq('voucher_code', voucher_code).execute()
            
            if existing_response.data:
                print(f"❌ Voucher code already exists")
                return jsonify({'success': False, 'message': 'Voucher code already exists'}), 400
            
            # Insert new voucher
            print(f"💾 Inserting new voucher...")
            insert_response = supabase.table('vouchers').insert({
                'voucher_code': voucher_code,
                'voucher_name': voucher_name,
                'voucher_type': voucher_type,
                'discount_percent': discount_percent,
                'start_date': start_date,
                'end_date': end_date,
                'created_at': datetime.now().isoformat()
            }).execute()
            
            if not insert_response.data:
                print(f"❌ Failed to insert voucher")
                return jsonify({'success': False, 'message': 'Failed to create voucher'}), 500
            
            voucher_id = insert_response.data[0]['voucher_id']
            
            print(f"✅ Voucher created successfully! voucher_id={voucher_id}")
            print("="*80 + "\n")
            
            return jsonify({
                'success': True,
                'message': 'Voucher created successfully',
                'voucher_id': voucher_id
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

@admin_vouchers_bp.route('/admin/vouchers/delete/<int:voucher_id>', methods=['DELETE'])
@admin_required
def delete_voucher(voucher_id):
    """Delete a voucher using Supabase"""
    print(f"\n🗑️ [DELETE VOUCHER] Processing voucher_id: {voucher_id}")
    
    supabase = get_supabase_client()
    if not supabase:
        print("❌ Supabase connection failed")
        return jsonify({'success': False, 'message': 'Database connection failed'}), 500
    
    try:
        # Delete voucher
        delete_response = supabase.table('vouchers').delete().eq('voucher_id', voucher_id).execute()
        
        if not delete_response.data:
            print(f"❌ Voucher not found")
            return jsonify({'success': False, 'message': 'Voucher not found'}), 404
        
        print(f"✅ Voucher deleted successfully")
        return jsonify({'success': True, 'message': 'Voucher deleted successfully'})
    
    except Exception as e:
        print(f"❌ Error deleting voucher: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': f'Error: {str(e)}'}), 500
