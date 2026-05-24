from flask import Blueprint, render_template, request, jsonify, session
from .profile_helper import get_user_profile_data
import sys
import os

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.supabase_helper import *

myAccount_address_bp = Blueprint('myAccount_address', __name__)

@myAccount_address_bp.route('/myAccount_address')
def myAccount_address():
    """📍 Render address page with optimized data loading"""
    print("=" * 80)
    print("📍 [ADDRESS PAGE] Loading address page...")
    print("=" * 80)
    
    profile = get_user_profile_data()
    
    # Get user's addresses from database (limited to 50)
    addresses = []
    if 'user_id' in session:
        buyer = get_buyer_by_user_id(session['user_id'])
        if buyer:
            addresses = get_buyer_addresses(buyer['buyer_id'])
            print(f"✅ Loaded {len(addresses)} addresses for buyer_id={buyer['buyer_id']}")
    
    return render_template('accounts/myAccount_address.html', user_profile=profile, addresses=addresses)

@myAccount_address_bp.route('/myAccount_address/add', methods=['POST'])
def add_address():
    """Add new address"""
    try:
        # Check if user is logged in
        if 'user_id' not in session:
            return jsonify({'success': False, 'message': 'Please login to continue'}), 401
        
        # Get form data
        data = request.get_json()
        recipient_name = data.get('recipient_name', '').strip()
        phone_number = data.get('phone_number', '').strip()
        house_number = data.get('house_number', '').strip()
        street_name = data.get('street_name', '').strip()
        full_address = data.get('full_address', '').strip()
        region = data.get('region', '').strip()
        province = data.get('province', '').strip()
        city = data.get('city', '').strip()
        barangay = data.get('barangay', '').strip()
        postal_code = data.get('postal_code', '').strip()
        is_default = data.get('is_default', False)
        
        # Validate required fields
        if not all([recipient_name, phone_number, full_address, region, city, barangay, postal_code]):
            return jsonify({'success': False, 'message': 'All fields are required'}), 400
        
        # Validate recipient name (at least 2 characters)
        if len(recipient_name) < 2:
            return jsonify({'success': False, 'message': 'Recipient name must be at least 2 characters'}), 400
        
        # Validate phone number (must be 11 digits starting with 09)
        import re
        if not re.match(r'^09\d{9}$', phone_number):
            return jsonify({'success': False, 'message': 'Phone number must be 11 digits starting with 09 (e.g., 09123456789)'}), 400
        
        # Validate postal code (must be 4 digits)
        if not re.match(r'^\d{4}$', postal_code):
            return jsonify({'success': False, 'message': 'Postal code must be exactly 4 digits'}), 400
        
        supabase = get_supabase()
        if not supabase:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Get buyer_id from user_id
            buyer = get_buyer_by_user_id(session['user_id'])
            
            if not buyer:
                return jsonify({'success': False, 'message': 'Buyer profile not found'}), 404
            
            buyer_id = buyer['buyer_id']
            
            # If this is set as default, unset all other defaults
            if is_default:
                supabase.table('addresses').update({'is_default': False}).eq('user_type', 'buyer').eq('user_ref_id', buyer_id).execute()
            
            # Insert new address
            address_data = {
                'user_type': 'buyer',
                'user_ref_id': buyer_id,
                'recipient_name': recipient_name,
                'phone_number': phone_number,
                'house_number': house_number,
                'street_name': street_name,
                'full_address': full_address,
                'region': region,
                'province': province,
                'city': city,
                'barangay': barangay,
                'postal_code': postal_code,
                'is_default': is_default
            }
            
            insert_response = supabase.table('addresses').insert(address_data).execute()
            
            return jsonify({
                'success': True,
                'message': 'Address added successfully!'
            }), 201
            
        except Exception as e:
            print(f"Error adding address: {e}")
            return jsonify({'success': False, 'message': 'Failed to add address. Please try again.'}), 500
            
    except Exception as e:
        print(f"Unexpected error: {e}")
        return jsonify({'success': False, 'message': 'An unexpected error occurred. Please try again.'}), 500

@myAccount_address_bp.route('/myAccount_address/update/<int:address_id>', methods=['PUT'])
def update_address(address_id):
    """Update existing address"""
    try:
        # Check if user is logged in
        if 'user_id' not in session:
            return jsonify({'success': False, 'message': 'Please login to continue'}), 401
        
        # Get form data
        data = request.get_json()
        recipient_name = data.get('recipient_name', '').strip()
        phone_number = data.get('phone_number', '').strip()
        house_number = data.get('house_number', '').strip()
        street_name = data.get('street_name', '').strip()
        full_address = data.get('full_address', '').strip()
        region = data.get('region', '').strip()
        province = data.get('province', '').strip()
        city = data.get('city', '').strip()
        barangay = data.get('barangay', '').strip()
        postal_code = data.get('postal_code', '').strip()
        
        # Validate required fields
        if not all([recipient_name, phone_number, full_address, region, city, barangay, postal_code]):
            return jsonify({'success': False, 'message': 'All fields are required'}), 400
        
        # Validate recipient name (at least 2 characters)
        if len(recipient_name) < 2:
            return jsonify({'success': False, 'message': 'Recipient name must be at least 2 characters'}), 400
        
        # Validate phone number (must be 11 digits starting with 09)
        import re
        if not re.match(r'^09\d{9}$', phone_number):
            return jsonify({'success': False, 'message': 'Phone number must be 11 digits starting with 09 (e.g., 09123456789)'}), 400
        
        # Validate postal code (must be 4 digits)
        if not re.match(r'^\d{4}$', postal_code):
            return jsonify({'success': False, 'message': 'Postal code must be exactly 4 digits'}), 400
        
        supabase = get_supabase()
        if not supabase:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Get buyer_id from user_id
            buyer = get_buyer_by_user_id(session['user_id'])
            
            if not buyer:
                return jsonify({'success': False, 'message': 'Buyer profile not found'}), 404
            
            buyer_id = buyer['buyer_id']
            
            # Verify address belongs to this buyer
            address_check = supabase.table('addresses').select('*').eq('address_id', address_id).eq('user_type', 'buyer').eq('user_ref_id', buyer_id).execute()
            
            if not address_check.data:
                return jsonify({'success': False, 'message': 'Address not found'}), 404
            
            address = address_check.data[0]
            
            # Check if any changes were made
            no_changes = (
                address['recipient_name'] == recipient_name and
                address['phone_number'] == phone_number and
                (address.get('house_number') or '') == house_number and
                (address.get('street_name') or '') == street_name and
                address['full_address'] == full_address and
                address['region'] == region and
                (address.get('province') or '') == province and
                address['city'] == city and
                address['barangay'] == barangay and
                address['postal_code'] == postal_code
            )
            
            if no_changes:
                return jsonify({'success': False, 'message': 'No changes were made to the address'}), 400
            
            # Update address
            print(f"[UPDATE_ADDRESS] Updating address_id={address_id} for buyer_id={buyer_id}")
            
            update_data = {
                'recipient_name': recipient_name,
                'phone_number': phone_number,
                'house_number': house_number,
                'street_name': street_name,
                'full_address': full_address,
                'region': region,
                'province': province,
                'city': city,
                'barangay': barangay,
                'postal_code': postal_code
            }
            
            success = update_address_supabase(address_id, buyer_id, update_data)
            
            if success:
                print(f"[UPDATE_ADDRESS] Update completed successfully")
                return jsonify({
                    'success': True,
                    'message': 'Address updated successfully!'
                }), 200
            else:
                return jsonify({'success': False, 'message': 'Failed to update address'}), 500
            
        except Exception as e:
            print(f"Error updating address: {e}")
            return jsonify({'success': False, 'message': 'Failed to update address. Please try again.'}), 500
            
    except Exception as e:
        print(f"Unexpected error: {e}")
        return jsonify({'success': False, 'message': 'An unexpected error occurred. Please try again.'}), 500

@myAccount_address_bp.route('/myAccount_address/delete/<int:address_id>', methods=['DELETE'])
def delete_address(address_id):
    """Delete address"""
    try:
        # Check if user is logged in
        if 'user_id' not in session:
            return jsonify({'success': False, 'message': 'Please login to continue'}), 401
        
        supabase = get_supabase()
        if not supabase:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Get buyer_id from user_id
            buyer = get_buyer_by_user_id(session['user_id'])
            
            if not buyer:
                return jsonify({'success': False, 'message': 'Buyer profile not found'}), 404
            
            buyer_id = buyer['buyer_id']
            
            # Verify address belongs to this buyer
            print(f"[DELETE_ADDRESS] Checking address {address_id} for buyer {buyer_id}")
            address_check = supabase.table('addresses').select('*').eq('address_id', address_id).eq('user_type', 'buyer').eq('user_ref_id', buyer_id).execute()
            
            if not address_check.data:
                print(f"[DELETE_ADDRESS] Address not found")
                return jsonify({'success': False, 'message': 'Address not found'}), 404
            
            print(f"[DELETE_ADDRESS] Address found: {address_check.data[0]}")
            
            # Check if address is being used in ANY orders (due to foreign key constraint)
            order_check = supabase.table('orders').select('order_id', count='exact').eq('address_id', address_id).execute()
            
            print(f"[DELETE_ADDRESS] Total orders using this address: {order_check.count}")
            
            if order_check.count and order_check.count > 0:
                return jsonify({'success': False, 'message': 'Cannot delete address. It has been used in previous orders and must be kept for order history.'}), 400
            
            # Delete address
            print(f"[DELETE_ADDRESS] Attempting to delete address {address_id}")
            success = delete_address_supabase(address_id, buyer_id)
            
            if success:
                print(f"[DELETE_ADDRESS] Delete completed successfully")
                return jsonify({
                    'success': True,
                    'message': 'Address deleted successfully!'
                }), 200
            else:
                return jsonify({'success': False, 'message': 'Failed to delete address'}), 500
            
        except Exception as e:
            print(f"Error deleting address: {e}")
            import traceback
            print(traceback.format_exc())
            return jsonify({'success': False, 'message': f'Failed to delete address: {str(e)}'}), 500
            
    except Exception as e:
        print(f"Unexpected error: {e}")
        return jsonify({'success': False, 'message': 'An unexpected error occurred. Please try again.'}), 500

@myAccount_address_bp.route('/myAccount_address/set_default/<int:address_id>', methods=['POST'])
def set_default_address(address_id):
    """Set address as default"""
    try:
        # Check if user is logged in
        if 'user_id' not in session:
            return jsonify({'success': False, 'message': 'Please login to continue'}), 401
        
        supabase = get_supabase()
        if not supabase:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Get buyer_id from user_id
            buyer = get_buyer_by_user_id(session['user_id'])
            
            if not buyer:
                return jsonify({'success': False, 'message': 'Buyer profile not found'}), 404
            
            buyer_id = buyer['buyer_id']
            
            # Verify address belongs to this buyer
            address_check = supabase.table('addresses').select('*').eq('address_id', address_id).eq('user_type', 'buyer').eq('user_ref_id', buyer_id).execute()
            
            if not address_check.data:
                return jsonify({'success': False, 'message': 'Address not found'}), 404
            
            # Use helper function to set default
            success = set_default_address_supabase(address_id, buyer_id)
            
            if success:
                return jsonify({
                    'success': True,
                    'message': 'Default address updated successfully!'
                }), 200
            else:
                return jsonify({'success': False, 'message': 'Failed to set default address'}), 500
            
        except Exception as e:
            print(f"Error setting default address: {e}")
            return jsonify({'success': False, 'message': 'Failed to set default address. Please try again.'}), 500
            
    except Exception as e:
        print(f"Unexpected error: {e}")
        return jsonify({'success': False, 'message': 'An unexpected error occurred. Please try again.'}), 500
