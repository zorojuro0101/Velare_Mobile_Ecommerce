"""
Supabase Helper Functions
This module provides helper functions for interacting with Supabase database.
"""

from database.db_config import get_supabase_client
from datetime import datetime, timedelta
import time
import httpx

# Alias for backward compatibility
def get_supabase():
    """Alias for get_supabase_client() for backward compatibility"""
    return get_supabase_client()

def supabase_retry(func, max_retries=3, delay=1):
    """
    Retry wrapper for Supabase operations to handle network errors
    
    Args:
        func: Function to execute
        max_retries: Maximum number of retry attempts (default: 3)
        delay: Delay in seconds between retries (default: 1)
    
    Returns:
        Result of the function call
    
    Raises:
        Exception: If all retries fail
    """
    last_exception = None
    
    for attempt in range(max_retries):
        try:
            return func()
        except (httpx.ConnectError, httpx.RemoteProtocolError, ConnectionError) as e:
            last_exception = e
            if attempt < max_retries - 1:
                print(f"⚠️ Network error (attempt {attempt + 1}/{max_retries}): {str(e)}")
                print(f"🔄 Retrying in {delay} second(s)...")
                time.sleep(delay)
                continue
            else:
                print(f"❌ All {max_retries} retry attempts failed")
                raise e
        except Exception as e:
            # Don't retry for non-network errors
            raise e
    
    # If we get here, all retries failed
    if last_exception:
        raise last_exception

def clean_supabase_data(data):
    """Clean Supabase data by removing None values and converting types"""
    if isinstance(data, list):
        return [clean_supabase_data(item) for item in data]
    elif isinstance(data, dict):
        return {k: clean_supabase_data(v) for k, v in data.items() if v is not None}
    return data

def fix_image_urls_in_data(data):
    """
    Process image URLs in data (placeholder for future URL transformation)
    Currently returns data as-is since URLs are already correct from Supabase
    """
    return data

# ============================================================================
# BUYER HELPER FUNCTIONS
# ============================================================================

def get_buyer_by_user_id(user_id):
    """Get buyer information by user_id"""
    try:
        supabase = get_supabase_client()
        response = supabase.table('buyers').select('*').eq('user_id', user_id).execute()
        return response.data[0] if response.data else None
    except Exception as e:
        print(f"❌ Error getting buyer: {e}")
        return None

def get_buyer_orders_with_sellers_riders(buyer_id):
    """Get buyer orders with seller and rider information (limited to 50 most recent)"""
    try:
        supabase = get_supabase_client()
        # Limited to 50 most recent orders for performance
        # Simplified: Get riders info separately to avoid nested join issues
        response = supabase.table('orders').select('''
            *,
            sellers (
                seller_id,
                shop_name,
                user_id
            ),
            deliveries (
                delivery_id,
                rider_id
            )
        ''').eq('buyer_id', buyer_id).order('created_at', desc=True).limit(50).execute()
        
        # If we have orders with deliveries, fetch rider details separately
        if response.data:
            rider_ids = set()
            for order in response.data:
                deliveries = order.get('deliveries')
                if deliveries:
                    # Handle both single object and array
                    if isinstance(deliveries, list):
                        for delivery in deliveries:
                            if delivery.get('rider_id'):
                                rider_ids.add(delivery['rider_id'])
                    elif isinstance(deliveries, dict) and deliveries.get('rider_id'):
                        rider_ids.add(deliveries['rider_id'])
            
            # Fetch all rider details at once
            riders_map = {}
            if rider_ids:
                riders_response = supabase.table('riders').select('rider_id, user_id, first_name, last_name').in_('rider_id', list(rider_ids)).execute()
                if riders_response.data:
                    riders_map = {r['rider_id']: r for r in riders_response.data}
            
            # Attach rider details to orders
            for order in response.data:
                deliveries = order.get('deliveries')
                if deliveries:
                    if isinstance(deliveries, list):
                        for delivery in deliveries:
                            rider_id = delivery.get('rider_id')
                            if rider_id and rider_id in riders_map:
                                delivery['rider'] = riders_map[rider_id]
                    elif isinstance(deliveries, dict):
                        rider_id = deliveries.get('rider_id')
                        if rider_id and rider_id in riders_map:
                            deliveries['rider'] = riders_map[rider_id]
        
        return response.data if response.data else []
    except Exception as e:
        print(f"❌ Error getting buyer orders: {e}")
        return []

def get_buyer_reports(buyer_id):
    """Get reports filed by a buyer (optimized - limited to 50 most recent)"""
    try:
        from datetime import datetime
        supabase = get_supabase_client()
        # Fixed: Use reporter_id instead of reporter_buyer_id
        response = supabase.table('user_reports').select('*').eq('reporter_id', buyer_id).eq('reporter_type', 'buyer').order('created_at', desc=True).limit(50).execute()
        
        # Parse dates from ISO strings to datetime objects
        if response.data:
            for report in response.data:
                if report.get('created_at') and isinstance(report['created_at'], str):
                    try:
                        report['created_at'] = datetime.fromisoformat(report['created_at'].replace('Z', '+00:00'))
                    except:
                        pass
        
        return response.data if response.data else []
    except Exception as e:
        print(f"❌ Error getting buyer reports: {e}")
        return []

# ============================================================================
# SELLER HELPER FUNCTIONS
# ============================================================================

def get_seller_by_id(seller_id):
    """Get seller information by seller_id"""
    try:
        supabase = get_supabase_client()
        response = supabase.table('sellers').select('*').eq('seller_id', seller_id).execute()
        return response.data[0] if response.data else None
    except Exception as e:
        print(f"❌ Error getting seller: {e}")
        return None

def get_seller_user_details(seller_id):
    """Get seller with user details"""
    try:
        supabase = get_supabase_client()
        response = supabase.table('sellers').select('''
            *,
            users (
                email,
                first_name,
                last_name
            )
        ''').eq('seller_id', seller_id).execute()
        return response.data[0] if response.data else None
    except Exception as e:
        print(f"❌ Error getting seller user details: {e}")
        return None

def update_seller_report_count(seller_id):
    """Update seller report count"""
    try:
        supabase = get_supabase_client()
        # Get current count
        response = supabase.table('sellers').select('report_count').eq('seller_id', seller_id).execute()
        if response.data:
            current_count = response.data[0].get('report_count', 0) or 0
            new_count = current_count + 1
            supabase.table('sellers').update({'report_count': new_count}).eq('seller_id', seller_id).execute()
            return True
        return False
    except Exception as e:
        print(f"❌ Error updating seller report count: {e}")
        return False

# ============================================================================
# RIDER HELPER FUNCTIONS
# ============================================================================

def get_rider_by_id(rider_id):
    """Get rider information by rider_id"""
    try:
        supabase = get_supabase_client()
        response = supabase.table('riders').select('*').eq('rider_id', rider_id).execute()
        return response.data[0] if response.data else None
    except Exception as e:
        print(f"❌ Error getting rider: {e}")
        return None

def get_rider_user_details(rider_id):
    """Get rider with user details"""
    try:
        supabase = get_supabase_client()
        response = supabase.table('riders').select('''
            *,
            users (
                email,
                first_name,
                last_name
            )
        ''').eq('rider_id', rider_id).execute()
        return response.data[0] if response.data else None
    except Exception as e:
        print(f"❌ Error getting rider user details: {e}")
        return None

def update_rider_report_count(rider_id):
    """Update rider report count"""
    try:
        supabase = get_supabase_client()
        # Get current count
        response = supabase.table('riders').select('report_count').eq('rider_id', rider_id).execute()
        if response.data:
            current_count = response.data[0].get('report_count', 0) or 0
            new_count = current_count + 1
            supabase.table('riders').update({'report_count': new_count}).eq('rider_id', rider_id).execute()
            return True
        return False
    except Exception as e:
        print(f"❌ Error updating rider report count: {e}")
        return False

# ============================================================================
# REPORT HELPER FUNCTIONS
# ============================================================================

def insert_user_report(report_data):
    """Insert a new user report"""
    try:
        supabase = get_supabase_client()
        response = supabase.table('user_reports').insert(report_data).execute()
        return response.data[0] if response.data else None
    except Exception as e:
        print(f"❌ Error inserting user report: {e}")
        return None

def get_user_report_count(reported_user_id):
    """Get count of reports against a specific user"""
    try:
        supabase = get_supabase_client()
        response = supabase.table('user_reports').select('report_id', count='exact').eq('reported_user_id', reported_user_id).execute()
        return response.count if hasattr(response, 'count') else 0
    except Exception as e:
        print(f"❌ Error getting user report count: {e}")
        return 0

# ============================================================================
# VOUCHER HELPER FUNCTIONS
# ============================================================================

def get_voucher_with_shop_count(voucher_id):
    """Get voucher details with count of shops offering it"""
    try:
        from dateutil import parser
        
        supabase = get_supabase_client()
        # Get voucher details
        voucher_response = supabase.table('vouchers').select('*').eq('voucher_id', voucher_id).execute()
        if not voucher_response.data:
            return None
        
        voucher = voucher_response.data[0]
        
        # Parse date strings to datetime objects
        if voucher.get('start_date'):
            try:
                voucher['start_date'] = parser.parse(voucher['start_date'])
            except:
                pass
        
        if voucher.get('end_date'):
            try:
                voucher['end_date'] = parser.parse(voucher['end_date'])
            except:
                pass
        
        if voucher.get('created_at'):
            try:
                voucher['created_at'] = parser.parse(voucher['created_at'])
            except:
                pass
        
        # Get count of sellers offering this voucher
        sellers_response = supabase.table('seller_vouchers').select('seller_id', count='exact').eq('voucher_id', voucher_id).execute()
        voucher['shop_count'] = sellers_response.count if hasattr(sellers_response, 'count') else 0
        
        return voucher
    except Exception as e:
        print(f"❌ Error getting voucher with shop count: {e}")
        return None

def get_products_by_voucher(voucher_id):
    """Get all products from sellers offering a specific voucher"""
    try:
        supabase = get_supabase_client()
        
        # Get seller IDs offering this voucher
        seller_vouchers_response = supabase.table('seller_vouchers').select('seller_id').eq('voucher_id', voucher_id).execute()
        
        if not seller_vouchers_response.data:
            return []
        
        seller_ids = [sv['seller_id'] for sv in seller_vouchers_response.data]
        
        # Get products from these sellers (limit to 100 for performance)
        products_response = supabase.table('products').select('''
            product_id,
            product_name,
            price,
            rating,
            total_reviews,
            total_sold,
            sellers (
                shop_name
            )
        ''').in_('seller_id', seller_ids).eq('is_active', True).order('created_at', desc=True).limit(100).execute()
        
        if not products_response.data:
            return []
        
        # Get primary images for products
        product_ids = [p['product_id'] for p in products_response.data]
        images_response = supabase.table('product_images').select('product_id, image_url').eq('is_primary', True).in_('product_id', product_ids).execute()
        
        images_dict = {}
        if images_response.data:
            images_dict = {img['product_id']: img['image_url'] for img in images_response.data}
        
        # Add images to products
        products = []
        for product in products_response.data:
            seller = product.get('sellers', {})
            image_url = images_dict.get(product['product_id'])
            
            # Fix image path for Supabase URLs
            if image_url:
                # If it's a Supabase URL, keep as-is
                if not (image_url.startswith('http://') or image_url.startswith('https://')):
                    # If it starts with /static/, remove the leading slash
                    if image_url.startswith('/static/'):
                        image_url = image_url[1:]  # Remove leading /
                    # If it doesn't start with static/, add it
                    elif not image_url.startswith('static/'):
                        image_url = f'static/{image_url}'
            
            products.append({
                'product_id': product['product_id'],
                'product_name': product['product_name'],
                'price': product['price'],
                'rating': product.get('rating'),
                'total_reviews': product.get('total_reviews'),
                'total_sold': product.get('total_sold'),
                'shop_name': seller.get('shop_name') if isinstance(seller, dict) else None,
                'primary_image': image_url,
                'image_url': image_url  # Add this for template compatibility
            })
        
        return products
    except Exception as e:
        print(f"❌ Error getting products by voucher: {e}")
        return []


# ============================================================================
# PRODUCT HELPER FUNCTIONS
# ============================================================================

def get_product(product_id):
    """Get product information by product_id"""
    try:
        supabase = get_supabase_client()
        response = supabase.table('products').select('*').eq('product_id', product_id).execute()
        return response.data[0] if response.data else None
    except Exception as e:
        print(f"❌ Error getting product: {e}")
        return None

def get_product_variant(variant_id):
    """Get product variant information by variant_id"""
    try:
        supabase = get_supabase_client()
        response = supabase.table('product_variants').select('*').eq('variant_id', variant_id).execute()
        return response.data[0] if response.data else None
    except Exception as e:
        print(f"❌ Error getting product variant: {e}")
        return None

# ============================================================================
# BUYER PROFILE HELPER FUNCTIONS
# ============================================================================

def get_buyer_profile(user_id):
    """Get buyer profile with user details.

    Tries the PostgREST nested join first (`users(email)`). If that join
    returns nothing — e.g. the FK isn't visible to the anon role on this
    Supabase project — we fall back to a separate `users` query so the
    profile page never ends up showing 'None' for the email. This keeps
    behavior consistent between local dev and the Railway deployment.
    """
    try:
        supabase = get_supabase_client()
        # Get buyer data (first_name, last_name, phone_number are in buyers table)
        response = supabase.table('buyers').select('''
            *,
            users (
                email
            )
        ''').eq('user_id', user_id).execute()

        if not response.data:
            return None

        buyer = response.data[0]

        # Flatten user data (only email is from users table)
        nested_users = buyer.get('users')
        if isinstance(nested_users, dict) and nested_users.get('email'):
            buyer['email'] = nested_users['email']
        elif isinstance(nested_users, list) and nested_users and nested_users[0].get('email'):
            buyer['email'] = nested_users[0]['email']
        else:
            # Fallback: nested join didn't resolve (missing FK metadata in
            # PostgREST schema cache, RLS, or the join just returned null).
            # Fetch the email directly from the users table.
            buyer['email'] = None
            try:
                user_response = supabase.table('users').select('email').eq('user_id', user_id).execute()
                if user_response.data:
                    buyer['email'] = user_response.data[0].get('email')
            except Exception as fallback_err:
                print(f"⚠️ Email fallback fetch failed for user_id={user_id}: {fallback_err}")

        return buyer
    except Exception as e:
        print(f"❌ Error getting buyer profile: {e}")
        return None

def update_buyer_profile_supabase(user_id, profile_data):
    """Update buyer profile in Supabase"""
    try:
        supabase = get_supabase_client()
        
        # Update buyers table
        buyer_fields = {}
        if 'first_name' in profile_data:
            buyer_fields['first_name'] = profile_data['first_name']
        if 'last_name' in profile_data:
            buyer_fields['last_name'] = profile_data['last_name']
        if 'phone_number' in profile_data:
            buyer_fields['phone_number'] = profile_data['phone_number']
        if 'gender' in profile_data:
            buyer_fields['gender'] = profile_data['gender']
        if 'profile_image' in profile_data:
            buyer_fields['profile_image'] = profile_data['profile_image']
        if 'address' in profile_data:
            buyer_fields['address'] = profile_data['address']
        if 'city' in profile_data:
            buyer_fields['city'] = profile_data['city']
        if 'province' in profile_data:
            buyer_fields['province'] = profile_data['province']
        if 'postal_code' in profile_data:
            buyer_fields['postal_code'] = profile_data['postal_code']
        
        if buyer_fields:
            print(f"🔄 Updating buyer profile for user_id {user_id}")
            print(f"📝 Fields to update: {buyer_fields.keys()}")
            response = supabase.table('buyers').update(buyer_fields).eq('user_id', user_id).execute()
            print(f"✅ Update response: {response.data}")
        
        return True
    except Exception as e:
        print(f"❌ Error updating buyer profile: {e}")
        import traceback
        traceback.print_exc()
        return False

def update_user_email_supabase(user_id, email):
    """Update user email in Supabase"""
    try:
        supabase = get_supabase_client()
        supabase.table('users').update({'email': email}).eq('user_id', user_id).execute()
        return True
    except Exception as e:
        print(f"❌ Error updating user email: {e}")
        return False

# ============================================================================
# NOTIFICATION HELPER FUNCTIONS
# ============================================================================

def get_user_notifications(user_id):
    """Get all notifications for a user"""
    try:
        supabase = get_supabase_client()
        response = supabase.table('notifications').select('*').eq('user_id', user_id).order('created_at', desc=True).execute()
        return response.data if response.data else []
    except Exception as e:
        print(f"❌ Error getting user notifications: {e}")
        return []


# NOTE: get_user_profile_data() previously lived here. It now resides in
# blueprints/profile_helper.py with per-request caching via Flask `g` so that
# repeated calls within the same request only hit Supabase once. Importing this
# module via `from database.supabase_helper import *` no longer shadows the
# cached version. If you need the helper, use:
#     from blueprints.profile_helper import get_user_profile_data


# ============================================================================
# ADDRESS HELPER FUNCTIONS
# ============================================================================

def get_buyer_addresses(buyer_id):
    """Get all addresses for a buyer (limited to 50 most recent)"""
    try:
        supabase = get_supabase_client()
        # Addresses table uses user_ref_id and user_type, not buyer_id
        # Limit to 50 addresses to prevent slow loading
        response = supabase.table('addresses').select('*').eq('user_type', 'buyer').eq('user_ref_id', buyer_id).order('is_default', desc=True).order('created_at', desc=True).limit(50).execute()
        return response.data if response.data else []
    except Exception as e:
        print(f"❌ Error getting buyer addresses: {e}")
        return []

# ============================================================================
# ORDER/PRODUCT UPDATE HELPER FUNCTIONS
# ============================================================================

def update_product_total_sold_supabase(product_id, quantity):
    """Update product total_sold count"""
    try:
        supabase = get_supabase_client()
        # Get current total_sold
        response = supabase.table('products').select('total_sold').eq('product_id', product_id).execute()
        if response.data:
            current_total = response.data[0].get('total_sold', 0) or 0
            new_total = current_total + quantity
            supabase.table('products').update({'total_sold': new_total}).eq('product_id', product_id).execute()
            return True
        return False
    except Exception as e:
        print(f"❌ Error updating product total_sold: {e}")
        return False

def update_product_stock_supabase(variant_id, quantity):
    """Update product variant stock"""
    try:
        supabase = get_supabase_client()
        # Get current stock
        response = supabase.table('product_variants').select('stock_quantity').eq('variant_id', variant_id).execute()
        if response.data:
            current_stock = response.data[0].get('stock_quantity', 0) or 0
            new_stock = max(0, current_stock - quantity)
            supabase.table('product_variants').update({'stock_quantity': new_stock}).eq('variant_id', variant_id).execute()
            print(f"✅ Updated stock for variant_id {variant_id}: {current_stock} → {new_stock}")
            return True
        return False
    except Exception as e:
        print(f"❌ Error updating product stock: {e}")
        return False

def use_voucher_supabase(buyer_voucher_id, buyer_id):
    """Mark a buyer voucher as used"""
    try:
        supabase = get_supabase_client()
        from datetime import datetime
        
        # Update buyer_voucher to mark as used
        response = supabase.table('buyer_vouchers').update({
            'is_used': True,
            'used_at': datetime.now().isoformat()
        }).eq('buyer_voucher_id', buyer_voucher_id).eq('buyer_id', buyer_id).execute()
        
        if response.data:
            print(f"✅ Voucher {buyer_voucher_id} marked as used")
            return True
        return False
    except Exception as e:
        print(f"❌ Error marking voucher as used: {e}")
        return False


# ============================================================================
# RIDER PROFILE HELPER FUNCTIONS
# ============================================================================

def get_rider_by_user_id(user_id):
    """Get rider information by user_id"""
    try:
        supabase = get_supabase_client()
        response = supabase.table('riders').select('*').eq('user_id', user_id).execute()
        return response.data[0] if response.data else None
    except Exception as e:
        print(f"❌ Error getting rider by user_id: {e}")
        return None

def get_rider_profile(user_id):
    """Get rider profile with user details"""
    try:
        supabase = get_supabase_client()
        # Get rider data (first_name, last_name, phone_number are in riders table)
        response = supabase.table('riders').select('''
            *,
            users (
                email
            )
        ''').eq('user_id', user_id).execute()
        
        if response.data:
            rider = response.data[0]
            print(f"🔍 Rider data fetched: {rider.keys()}")
            print(f"🔍 Vehicle type: {rider.get('vehicle_type')}")
            
            # Flatten user data (only email is from users table)
            if 'users' in rider and rider['users']:
                user_data = rider['users']
                rider['email'] = user_data.get('email')
            return rider
        return None
    except Exception as e:
        print(f"❌ Error getting rider profile: {e}")
        return None

def update_rider_profile_supabase(user_id, profile_data):
    """Update rider profile in Supabase"""
    try:
        supabase = get_supabase_client()
        
        # Update riders table
        rider_fields = {}
        if 'first_name' in profile_data:
            rider_fields['first_name'] = profile_data['first_name']
        if 'last_name' in profile_data:
            rider_fields['last_name'] = profile_data['last_name']
        if 'phone_number' in profile_data:
            rider_fields['phone_number'] = profile_data['phone_number']
        if 'profile_image' in profile_data:
            rider_fields['profile_image'] = profile_data['profile_image']
        if 'address' in profile_data:
            rider_fields['address'] = profile_data['address']
        if 'city' in profile_data:
            rider_fields['city'] = profile_data['city']
        if 'province' in profile_data:
            rider_fields['province'] = profile_data['province']
        if 'postal_code' in profile_data:
            rider_fields['postal_code'] = profile_data['postal_code']
        if 'driver_license_file_path' in profile_data:
            rider_fields['driver_license_file_path'] = profile_data['driver_license_file_path']
        if 'orcr_file_path' in profile_data:
            rider_fields['orcr_file_path'] = profile_data['orcr_file_path']
        
        if rider_fields:
            supabase.table('riders').update(rider_fields).eq('user_id', user_id).execute()
        
        return True
    except Exception as e:
        print(f"❌ Error updating rider profile: {e}")
        return False

# ============================================================================
# ADDRESS UPDATE/DELETE FUNCTIONS
# ============================================================================

def update_address_supabase(address_id, buyer_id, address_data):
    """Update address in Supabase"""
    try:
        supabase = get_supabase_client()
        # Verify address belongs to buyer before updating
        supabase.table('addresses').update(address_data).eq('address_id', address_id).eq('user_ref_id', buyer_id).eq('user_type', 'buyer').execute()
        return True
    except Exception as e:
        print(f"❌ Error updating address: {e}")
        return False

def delete_address_supabase(address_id, buyer_id):
    """Delete address from Supabase"""
    try:
        supabase = get_supabase_client()
        # Verify address belongs to buyer before deleting
        supabase.table('addresses').delete().eq('address_id', address_id).eq('user_ref_id', buyer_id).eq('user_type', 'buyer').execute()
        return True
    except Exception as e:
        print(f"❌ Error deleting address: {e}")
        return False

def set_default_address_supabase(address_id, buyer_id):
    """Set address as default for buyer"""
    try:
        supabase = get_supabase_client()
        
        # First, unset all other defaults for this buyer
        supabase.table('addresses').update({'is_default': False}).eq('user_type', 'buyer').eq('user_ref_id', buyer_id).execute()
        
        # Then set this address as default
        supabase.table('addresses').update({'is_default': True}).eq('address_id', address_id).eq('user_ref_id', buyer_id).eq('user_type', 'buyer').execute()
        
        return True
    except Exception as e:
        print(f"❌ Error setting default address: {e}")
        return False

# ============================================================================
# ORDER UPDATE FUNCTIONS
# ============================================================================

def update_order_status_supabase(order_id, status):
    """Update order status in Supabase"""
    try:
        supabase = get_supabase_client()
        supabase.table('orders').update({'order_status': status}).eq('order_id', order_id).execute()
        print(f"✅ Order {order_id} status updated to {status}")
        return True
    except Exception as e:
        print(f"❌ Error updating order status: {e}")
        return False


# ============================================================================
# DELIVERY HELPER FUNCTIONS
# ============================================================================

def get_pending_deliveries():
    """Get all pending deliveries (not yet assigned to a rider) - ONLY those marked as ready for pickup"""
    try:
        supabase = get_supabase_client()
        # Only get deliveries with status='pending' (ready for pickup by seller)
        # Do NOT include null or 'preparing' status
        response = supabase.table('deliveries').select('''
            delivery_id,
            order_id,
            pickup_address,
            delivery_address,
            delivery_fee,
            status,
            rider_id,
            orders (
                order_number,
                total_amount,
                buyer_id,
                seller_id,
                buyers (
                    first_name,
                    last_name,
                    phone_number
                ),
                sellers (
                    shop_name,
                    phone_number
                )
            )
        ''').is_('rider_id', 'null').eq('status', 'pending').execute()
        
        return response.data if response.data else []
    except Exception as e:
        print(f"❌ Error getting pending deliveries: {e}")
        return []

def get_delivery_by_id(delivery_id):
    """Get delivery information by delivery_id"""
    try:
        supabase = get_supabase_client()
        response = supabase.table('deliveries').select('*').eq('delivery_id', delivery_id).execute()
        return response.data[0] if response.data else None
    except Exception as e:
        print(f"❌ Error getting delivery: {e}")
        return None

def accept_delivery_supabase(delivery_id, rider_id):
    """Assign a delivery to a rider (when rider accepts from pickup list)"""
    try:
        from datetime import datetime
        supabase = get_supabase_client()
        
        # Get delivery details first
        delivery_response = supabase.table('deliveries').select('''
            delivery_id,
            order_id,
            orders (
                order_number,
                buyer_id,
                seller_id,
                sellers (
                    shop_name
                )
            )
        ''').eq('delivery_id', delivery_id).execute()
        
        if not delivery_response.data:
            print(f"❌ Delivery {delivery_id} not found")
            return False
        
        delivery = delivery_response.data[0]
        order = delivery.get('orders', {})
        buyer_id = order.get('buyer_id')
        seller_id = order.get('seller_id')
        order_number = order.get('order_number')
        shop_name = order.get('sellers', {}).get('shop_name', 'Shop')
        
        # Update delivery with rider_id and status
        response = supabase.table('deliveries').update({
            'rider_id': rider_id,
            'status': 'assigned',
            'assigned_at': datetime.now().isoformat()
        }).eq('delivery_id', delivery_id).execute()
        
        if not response.data:
            return False
        
        print(f"✅ Delivery {delivery_id} assigned to rider {rider_id}")
        
        # Send automatic introduction messages to BOTH buyer and seller
        # Check if there are other active deliveries for this buyer/seller with same rider
        active_buyer_deliveries = supabase.table('deliveries').select('''
            delivery_id,
            orders (
                order_number
            )
        ''').eq('rider_id', rider_id).eq('order_id', order.get('order_id')).in_('status', ['assigned', 'in_transit']).execute()
        
        # Get all order numbers for this buyer
        buyer_order_numbers = []
        if active_buyer_deliveries.data:
            for d in active_buyer_deliveries.data:
                order_num = d.get('orders', {}).get('order_number')
                if order_num:
                    buyer_order_numbers.append(order_num)
        
        # Create message for buyer
        if len(buyer_order_numbers) > 1:
            orders_text = ", ".join([f"#{num}" for num in buyer_order_numbers])
            buyer_message = f"Hi! I'm your rider for Orders {orders_text} from {shop_name}. I'll keep you updated on your deliveries."
        else:
            buyer_message = f"Hi! I'm your rider for Order #{order_number} from {shop_name}. I'll keep you updated on your delivery."
        
        # Create message for seller
        seller_message = f"Hi! I'm the rider assigned to pick up Order #{order_number}. I'll be there soon to collect the package."
        
        # Send message to buyer
        if buyer_id:
            # Check/create conversation with buyer
            buyer_conv_response = supabase.table('conversations').select('conversation_id').eq('rider_id', rider_id).eq('buyer_id', buyer_id).is_('seller_id', 'null').execute()
            
            if buyer_conv_response.data:
                buyer_conv_id = buyer_conv_response.data[0]['conversation_id']
            else:
                # Create new conversation
                buyer_conv_data = {
                    'buyer_id': buyer_id,
                    'rider_id': rider_id,
                    'last_message': buyer_message,
                    'last_message_at': datetime.now().isoformat()
                }
                buyer_conv_response = supabase.table('conversations').insert(buyer_conv_data).execute()
                if buyer_conv_response.data:
                    buyer_conv_id = buyer_conv_response.data[0]['conversation_id']
                else:
                    buyer_conv_id = None
            
            # Insert message
            if buyer_conv_id:
                supabase.table('messages').insert({
                    'conversation_id': buyer_conv_id,
                    'sender_type': 'rider',
                    'sender_id': rider_id,
                    'message_text': buyer_message,
                    'is_read': False,
                    'topic': 'delivery_assignment',
                    'extension': 'text'
                }).execute()
                print(f"✅ Sent introduction message to buyer {buyer_id}")
        
        # Send message to seller
        if seller_id:
            # Check/create conversation with seller
            seller_conv_response = supabase.table('conversations').select('conversation_id').eq('rider_id', rider_id).eq('seller_id', seller_id).is_('buyer_id', 'null').execute()
            
            if seller_conv_response.data:
                seller_conv_id = seller_conv_response.data[0]['conversation_id']
            else:
                # Create new conversation
                seller_conv_data = {
                    'seller_id': seller_id,
                    'rider_id': rider_id,
                    'last_message': seller_message,
                    'last_message_at': datetime.now().isoformat()
                }
                seller_conv_response = supabase.table('conversations').insert(seller_conv_data).execute()
                if seller_conv_response.data:
                    seller_conv_id = seller_conv_response.data[0]['conversation_id']
                else:
                    seller_conv_id = None
            
            # Insert message
            if seller_conv_id:
                supabase.table('messages').insert({
                    'conversation_id': seller_conv_id,
                    'sender_type': 'rider',
                    'sender_id': rider_id,
                    'message_text': seller_message,
                    'is_read': False,
                    'topic': 'delivery_assignment',
                    'extension': 'text'
                }).execute()
                print(f"✅ Sent introduction message to seller {seller_id}")
        
        return True
        
    except Exception as e:
        print(f"❌ Error accepting delivery: {e}")
        import traceback
        traceback.print_exc()
        return False


def get_rider_active_deliveries(rider_id):
    """
    Get all active deliveries assigned to a specific rider.
    Includes:
    - assigned: Waiting for pickup
    - in_transit: On the way to buyer
    - delivered with order_received=0: Awaiting buyer confirmation
    """
    try:
        supabase = get_supabase_client()
        
        # Get deliveries with status assigned or in_transit (exclude cancelled orders)
        response1 = supabase.table('deliveries').select('''
            delivery_id,
            order_id,
            pickup_address,
            delivery_address,
            delivery_fee,
            rider_earnings,
            status,
            assigned_at,
            picked_up_at,
            delivered_at,
            orders!inner (
                order_number,
                total_amount,
                order_status,
                order_received,
                buyer_id,
                seller_id,
                buyers (
                    first_name,
                    last_name,
                    phone_number
                ),
                sellers (
                    shop_name,
                    phone_number
                )
            )
        ''').eq('rider_id', rider_id).in_('status', ['assigned', 'in_transit']).neq('orders.order_status', 'cancelled').execute()
        
        # Get delivered orders that are awaiting buyer confirmation (order_received = False, exclude cancelled)
        response2 = supabase.table('deliveries').select('''
            delivery_id,
            order_id,
            pickup_address,
            delivery_address,
            delivery_fee,
            rider_earnings,
            status,
            assigned_at,
            picked_up_at,
            delivered_at,
            orders!inner (
                order_number,
                total_amount,
                order_status,
                order_received,
                buyer_id,
                seller_id,
                buyers (
                    first_name,
                    last_name,
                    phone_number
                ),
                sellers (
                    shop_name,
                    phone_number
                )
            )
        ''').eq('rider_id', rider_id).eq('status', 'delivered').eq('orders.order_received', False).neq('orders.order_status', 'cancelled').execute()
        
        # Combine both results
        all_deliveries = []
        if response1.data:
            all_deliveries.extend(response1.data)
        if response2.data:
            all_deliveries.extend(response2.data)
        
        print(f"📦 Active deliveries: {len(response1.data or [])} in progress + {len(response2.data or [])} awaiting confirmation")
        
        return all_deliveries
    except Exception as e:
        print(f"❌ Error getting rider active deliveries: {e}")
        import traceback
        traceback.print_exc()
        return []


def mark_delivery_picked_up(delivery_id):
    """Mark a delivery as picked up (rider has collected the package from seller)"""
    try:
        from datetime import datetime
        supabase = get_supabase_client()
        
        # Update delivery status to in_transit
        response = supabase.table('deliveries').update({
            'status': 'in_transit',
            'picked_up_at': datetime.now().isoformat()
        }).eq('delivery_id', delivery_id).execute()
        
        if response.data:
            print(f"✅ Delivery {delivery_id} marked as picked up")
            return True
        return False
    except Exception as e:
        print(f"❌ Error marking delivery as picked up: {e}")
        return False

def mark_delivery_delivered(delivery_id):
    """Mark a delivery as delivered (awaiting buyer confirmation)"""
    try:
        from datetime import datetime
        supabase = get_supabase_client()
        
        # Update delivery status to delivered
        response = supabase.table('deliveries').update({
            'status': 'delivered',
            'delivered_at': datetime.now().isoformat()
        }).eq('delivery_id', delivery_id).execute()
        
        if response.data:
            print(f"✅ Delivery {delivery_id} marked as delivered (awaiting confirmation)")
            
            # Update order status to delivered BUT order_received = False (awaiting confirmation)
            delivery = response.data[0]
            order_id = delivery.get('order_id')
            if order_id:
                supabase.table('orders').update({
                    'order_status': 'delivered',
                    'order_received': False  # Awaiting buyer confirmation
                }).eq('order_id', order_id).execute()
                print(f"✅ Order {order_id} marked as delivered (awaiting buyer confirmation)")
            
            return True
        return False
    except Exception as e:
        print(f"❌ Error marking delivery as delivered: {e}")
        return False


def get_order_by_id(order_id):
    """Get order information by order_id"""
    try:
        supabase = get_supabase_client()
        response = supabase.table('orders').select('*').eq('order_id', order_id).execute()
        return response.data[0] if response.data else None
    except Exception as e:
        print(f"❌ Error getting order: {e}")
        return None


def get_rider_earnings_history(rider_id, start_date=None, end_date=None):
    """
    Get rider's earnings history with optional date filtering
    Returns list of deliveries with earnings information
    """
    try:
        print(f"💰 Fetching earnings for rider_id: {rider_id}")
        supabase = get_supabase_client()
        
        # Build query - get deliveries with status 'delivered' for this rider
        query = supabase.table('deliveries').select('''
            delivery_id,
            order_id,
            rider_earnings,
            delivered_at,
            orders (
                order_number,
                buyer_id,
                seller_id,
                address_id,
                buyers (
                    first_name,
                    last_name
                ),
                sellers (
                    first_name,
                    last_name,
                    shop_name
                )
            )
        ''').eq('rider_id', rider_id).eq('status', 'delivered')
        
        # Add date filters if provided
        if start_date:
            query = query.gte('delivered_at', start_date)
        if end_date:
            query = query.lte('delivered_at', end_date)
        
        # Execute query
        response = query.order('delivered_at', desc=True).execute()
        
        earnings_data = response.data if response.data else []
        print(f"✅ Found {len(earnings_data)} earnings records")
        
        return earnings_data
        
    except Exception as e:
        print(f"❌ Error fetching rider earnings history: {e}")
        import traceback
        traceback.print_exc()
        return []


def get_rider_total_earnings(rider_id):
    """
    Calculate total earnings for a rider from all delivered orders
    """
    try:
        print(f"💵 Calculating total earnings for rider_id: {rider_id}")
        supabase = get_supabase_client()
        
        # Get all delivered deliveries for this rider
        response = supabase.table('deliveries').select('rider_earnings').eq('rider_id', rider_id).eq('status', 'delivered').execute()
        
        if not response.data:
            print(f"📭 No delivered orders found for rider {rider_id}")
            return 0.0
        
        # Sum up all earnings
        total = sum(float(d.get('rider_earnings', 0) or 0) for d in response.data)
        print(f"✅ Total earnings: ₱{total:.2f}")
        
        return total
        
    except Exception as e:
        print(f"❌ Error calculating total earnings: {e}")
        import traceback
        traceback.print_exc()
        return 0.0


# ==================== CHAT/CONVERSATION FUNCTIONS ====================

def create_conversation(buyer_id, seller_id, initial_message, rider_id=None, delivery_id=None):
    """
    Create a new conversation OR return existing conversation between the same parties.
    
    IMPORTANT: Conversations are now based on user profiles, NOT per delivery.
    - If a conversation already exists between rider and buyer, reuse it.
    - If a conversation already exists between seller and buyer, reuse it.
    - This prevents cluttered inboxes with multiple threads for the same people.
    
    Returns conversation_id
    """
    try:
        supabase = get_supabase_client()
        
        print(f"💬 Creating/finding conversation: buyer_id={buyer_id}, seller_id={seller_id}, rider_id={rider_id}, delivery_id={delivery_id}")
        
        # Check if conversation already exists between these parties
        existing_conversation = None
        
        if rider_id and buyer_id:
            # Rider-Buyer conversation: Check if one already exists (ignore delivery_id)
            print(f"🔍 Checking for existing rider-buyer conversation...")
            response = supabase.table('conversations').select('conversation_id').eq('rider_id', rider_id).eq('buyer_id', buyer_id).is_('seller_id', 'null').execute()
            
            if response.data and len(response.data) > 0:
                existing_conversation = response.data[0]['conversation_id']
                print(f"✅ Found existing rider-buyer conversation: {existing_conversation}")
        
        elif seller_id and buyer_id:
            # Seller-Buyer conversation: Check if one already exists
            print(f"🔍 Checking for existing seller-buyer conversation...")
            response = supabase.table('conversations').select('conversation_id').eq('seller_id', seller_id).eq('buyer_id', buyer_id).is_('rider_id', 'null').execute()
            
            if response.data and len(response.data) > 0:
                existing_conversation = response.data[0]['conversation_id']
                print(f"✅ Found existing seller-buyer conversation: {existing_conversation}")
        
        # If conversation exists, update last message and return existing ID
        if existing_conversation:
            print(f"♻️ Reusing existing conversation {existing_conversation}")
            update_conversation_last_message(existing_conversation, initial_message)
            return existing_conversation
        
        # No existing conversation, create new one
        print(f"➕ Creating new conversation...")
        conversation_data = {
            'last_message': initial_message,
            'last_message_at': datetime.now().isoformat(),
            'buyer_unread_count': 0,
            'seller_unread_count': 0,
            'rider_unread_count': 0
        }
        
        # Add buyer_id if provided
        if buyer_id:
            conversation_data['buyer_id'] = buyer_id
        
        # Add seller_id if provided
        if seller_id:
            conversation_data['seller_id'] = seller_id
        
        # Add rider if provided (but NOT delivery_id - we don't link to specific deliveries anymore)
        if rider_id:
            conversation_data['rider_id'] = rider_id
        
        # NOTE: We no longer set delivery_id to keep conversations profile-based
        # delivery_id parameter is kept for backward compatibility but not used
        
        print(f"📦 Conversation data: {conversation_data}")
        
        response = supabase.table('conversations').insert(conversation_data).execute()
        
        print(f"📤 Response: {response.data}")
        
        if response.data:
            conversation_id = response.data[0]['conversation_id']
            print(f"✅ Created conversation_id: {conversation_id}")
            return conversation_id
        
        print(f"❌ No data returned from insert")
        return None
        
    except Exception as e:
        print(f"❌ Error creating conversation: {e}")
        import traceback
        traceback.print_exc()
        return None


def insert_message(conversation_id, sender_type, sender_id, message_text):
    """
    Insert a new message into a conversation
    Returns message_id
    """
    try:
        supabase = get_supabase_client()
        
        # Get current timestamp with +8 hours for Philippine time
        current_time = (datetime.utcnow() + timedelta(hours=8)).strftime('%Y-%m-%d %H:%M:%S')
        
        message_data = {
            'conversation_id': conversation_id,
            'sender_type': sender_type,
            'sender_id': sender_id,
            'message_text': message_text,
            'is_read': False,
            'created_at': current_time
        }
        
        response = supabase.table('messages').insert(message_data).execute()
        
        if response.data:
            return response.data[0]['message_id']
        return None
        
    except Exception as e:
        print(f"❌ Error inserting message: {e}")
        import traceback
        traceback.print_exc()
        return None


def get_conversation_messages(conversation_id):
    """
    Get all messages for a conversation
    """
    try:
        supabase = get_supabase_client()
        
        response = supabase.table('messages').select('*').eq('conversation_id', conversation_id).order('created_at', desc=False).execute()
        
        return response.data if response.data else []
        
    except Exception as e:
        print(f"❌ Error getting conversation messages: {e}")
        return []


def mark_messages_as_read_rider(conversation_id):
    """
    Mark all messages in a conversation as read (for rider)
    """
    try:
        supabase = get_supabase_client()
        
        print(f"📖 Marking messages as read for conversation_id: {conversation_id}")
        
        # Mark all unread messages as read (don't filter by sender_type to avoid type issues)
        response = supabase.table('messages').update({
            'is_read': True
        }).eq('conversation_id', conversation_id).eq('is_read', False).execute()
        
        print(f"✅ Marked {len(response.data) if response.data else 0} messages as read")
        
        # Reset buyer unread count in conversation
        supabase.table('conversations').update({
            'buyer_unread_count': 0
        }).eq('conversation_id', conversation_id).execute()
        
        return True
        
    except Exception as e:
        print(f"❌ Error marking messages as read: {e}")
        import traceback
        traceback.print_exc()
        return False


def update_conversation_last_message(conversation_id, message_text):
    """
    Update the last message in a conversation
    """
    try:
        supabase = get_supabase_client()
        
        # Get current timestamp with +8 hours for Philippine time
        current_time = (datetime.utcnow() + timedelta(hours=8)).strftime('%Y-%m-%d %H:%M:%S')
        
        supabase.table('conversations').update({
            'last_message': message_text,
            'last_message_at': current_time
        }).eq('conversation_id', conversation_id).execute()
        
        return True
        
    except Exception as e:
        print(f"❌ Error updating last message: {e}")
        return False


def increment_buyer_unread_count(conversation_id):
    """
    Increment the buyer's unread message count
    """
    try:
        supabase = get_supabase_client()
        
        # Get current count
        response = supabase.table('conversations').select('buyer_unread_count').eq('conversation_id', conversation_id).execute()
        
        if response.data:
            current_count = response.data[0].get('buyer_unread_count', 0)
            new_count = current_count + 1
            
            supabase.table('conversations').update({
                'buyer_unread_count': new_count
            }).eq('conversation_id', conversation_id).execute()
        
        return True
        
    except Exception as e:
        print(f"❌ Error incrementing buyer unread count: {e}")
        return False



def get_rider_deliveries_with_users(rider_id):
    """
    Get rider's deliveries with buyer and seller information for reporting
    """
    try:
        supabase = get_supabase_client()
        
        response = supabase.table('deliveries').select('''
            delivery_id,
            order_id,
            status,
            delivered_at,
            orders (
                order_number,
                buyer_id,
                seller_id,
                buyers (
                    buyer_id,
                    first_name,
                    last_name
                ),
                sellers (
                    seller_id,
                    first_name,
                    last_name,
                    shop_name
                )
            )
        ''').eq('rider_id', rider_id).order('delivered_at', desc=True).limit(50).execute()
        
        return response.data if response.data else []
        
    except Exception as e:
        print(f"❌ Error getting rider deliveries with users: {e}")
        import traceback
        traceback.print_exc()
        return []



def get_rider_reports(user_id):
    """
    Get reports filed by a rider (using user_id)
    """
    try:
        from datetime import datetime
        supabase = get_supabase_client()
        
        response = supabase.table('user_reports').select('''
            report_id,
            reported_user_id,
            reported_user_type,
            report_category,
            report_reason,
            order_id,
            delivery_id,
            evidence_image,
            status,
            admin_notes,
            created_at,
            updated_at,
            resolved_at
        ''').eq('reporter_id', user_id).eq('reporter_type', 'rider').order('created_at', desc=True).execute()
        
        # Parse date strings to datetime objects
        if response.data:
            for report in response.data:
                if report.get('created_at') and isinstance(report['created_at'], str):
                    try:
                        report['created_at'] = datetime.fromisoformat(report['created_at'].replace('Z', '+00:00'))
                    except:
                        pass
                if report.get('updated_at') and isinstance(report['updated_at'], str):
                    try:
                        report['updated_at'] = datetime.fromisoformat(report['updated_at'].replace('Z', '+00:00'))
                    except:
                        pass
                if report.get('resolved_at') and isinstance(report['resolved_at'], str):
                    try:
                        report['resolved_at'] = datetime.fromisoformat(report['resolved_at'].replace('Z', '+00:00'))
                    except:
                        pass
        
        return response.data if response.data else []
        
    except Exception as e:
        print(f"❌ Error getting rider reports: {e}")
        import traceback
        traceback.print_exc()
        return []


# ============================================================================
# SESSION MANAGEMENT FUNCTIONS (Multi-Device Login Detection)
# ============================================================================

def create_user_session(user_id, session_token, device_info, browser, os_name, ip_address):
    """Create a new user session record"""
    try:
        supabase = get_supabase_client()
        
        session_data = {
            'user_id': user_id,
            'session_token': session_token,
            'device_info': device_info,
            'browser': browser,
            'os': os_name,
            'ip_address': ip_address,
            'login_time': datetime.utcnow().isoformat() + 'Z',
            'last_activity': datetime.utcnow().isoformat() + 'Z',
            'is_active': True
        }
        
        response = supabase.table('user_sessions').insert(session_data).execute()
        
        if response.data:
            print(f"✅ Created session for user {user_id} from {device_info}")
            return response.data[0]['session_id']
        return None
        
    except Exception as e:
        print(f"❌ Error creating user session: {e}")
        return None

def get_active_sessions(user_id):
    """Get all active sessions for a user"""
    try:
        supabase = get_supabase_client()
        
        response = supabase.table('user_sessions').select('*').eq('user_id', user_id).eq('is_active', True).order('login_time', desc=True).execute()
        
        return response.data if response.data else []
        
    except Exception as e:
        print(f"❌ Error getting active sessions: {e}")
        return []

def deactivate_session(session_token):
    """Deactivate a session (logout)"""
    try:
        supabase = get_supabase_client()
        
        response = supabase.table('user_sessions').update({
            'is_active': False
        }).eq('session_token', session_token).execute()
        
        if response.data:
            print(f"✅ Deactivated session: {session_token}")
            return True
        return False
        
    except Exception as e:
        print(f"❌ Error deactivating session: {e}")
        return False

def check_new_device_login(user_id, current_device_info):
    """
    Check if this is a new device login
    Returns True if user has other active sessions from different devices
    """
    try:
        supabase = get_supabase_client()
        
        # Get all active sessions for this user
        response = supabase.table('user_sessions').select('device_info, browser, os').eq('user_id', user_id).eq('is_active', True).execute()
        
        if not response.data:
            # No active sessions, this is first login
            return False
        
        # Check if any active session is from a different device
        for session in response.data:
            existing_device = f"{session.get('browser', '')} on {session.get('os', '')}"
            if existing_device != current_device_info:
                print(f"🔔 New device login detected: {current_device_info} (existing: {existing_device})")
                return True
        
        return False
        
    except Exception as e:
        print(f"❌ Error checking new device login: {e}")
        return False

def update_session_activity(session_token):
    """Update last activity timestamp for a session"""
    try:
        supabase = get_supabase_client()
        
        supabase.table('user_sessions').update({
            'last_activity': datetime.utcnow().isoformat() + 'Z'
        }).eq('session_token', session_token).execute()
        
        return True
        
    except Exception as e:
        print(f"❌ Error updating session activity: {e}")
        return False
