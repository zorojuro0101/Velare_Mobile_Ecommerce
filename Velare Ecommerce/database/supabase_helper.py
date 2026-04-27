"""
Supabase Helper Functions for Database Operations
Replaces MySQL queries with Supabase equivalents
"""
import os
from supabase import create_client
from dotenv import load_dotenv

load_dotenv()

def get_supabase():
    """Get Supabase client instance"""
    try:
        url = os.getenv('SUPABASE_URL')
        key = os.getenv('SUPABASE_KEY')
        
        if not url or not key:
            print("❌ Supabase credentials not found")
            return None
        
        return create_client(url, key)
    except Exception as e:
        print(f"❌ Supabase connection error: {e}")
        return None

def get_buyer_by_user_id(user_id):
    """Get buyer record by user_id"""
    try:
        supabase = get_supabase()
        if not supabase:
            return None
        
        response = supabase.table('buyers').select('*').eq('user_id', user_id).execute()
        return response.data[0] if response.data else None
    except Exception as e:
        print(f"Error getting buyer: {e}")
        return None

def get_cart_items(buyer_id):
    """Get all cart items for a buyer with product details"""
    try:
        supabase = get_supabase()
        if not supabase:
            return []
        
        # Get cart items with joins
        response = supabase.table('cart').select('''
            cart_id,
            product_id,
            quantity,
            variant_id,
            added_at,
            products (
                product_name,
                materials,
                price,
                is_active,
                seller_id,
                sellers (
                    shop_name,
                    shop_logo
                )
            ),
            product_variants (
                stock_quantity,
                size,
                color
            )
        ''').eq('buyer_id', buyer_id).execute()
        
        return response.data if response.data else []
    except Exception as e:
        print(f"Error getting cart items: {e}")
        return []

def add_to_cart_supabase(buyer_id, product_id, quantity, variant_id):
    """Add item to cart or update quantity"""
    try:
        supabase = get_supabase()
        if not supabase:
            return None
        
        # Check if item already exists
        existing = supabase.table('cart').select('*').eq('buyer_id', buyer_id).eq('product_id', product_id).eq('variant_id', variant_id).execute()
        
        if existing.data:
            # Update quantity
            cart_id = existing.data[0]['cart_id']
            new_quantity = existing.data[0]['quantity'] + quantity
            response = supabase.table('cart').update({'quantity': new_quantity}).eq('cart_id', cart_id).execute()
            return {'cart_id': cart_id, 'updated': True}
        else:
            # Insert new
            response = supabase.table('cart').insert({
                'buyer_id': buyer_id,
                'product_id': product_id,
                'quantity': quantity,
                'variant_id': variant_id
            }).execute()
            return {'cart_id': response.data[0]['cart_id'], 'updated': False} if response.data else None
    except Exception as e:
        print(f"Error adding to cart: {e}")
        return None

def update_cart_quantity_supabase(cart_id, buyer_id, quantity):
    """Update cart item quantity"""
    try:
        supabase = get_supabase()
        if not supabase:
            return False
        
        response = supabase.table('cart').update({'quantity': quantity}).eq('cart_id', cart_id).eq('buyer_id', buyer_id).execute()
        return True if response.data else False
    except Exception as e:
        print(f"Error updating cart: {e}")
        return False

def remove_from_cart_supabase(cart_id, buyer_id):
    """Remove item from cart"""
    try:
        supabase = get_supabase()
        if not supabase:
            return False
        
        response = supabase.table('cart').delete().eq('cart_id', cart_id).eq('buyer_id', buyer_id).execute()
        return True
    except Exception as e:
        print(f"Error removing from cart: {e}")
        return False

def get_cart_count_supabase(buyer_id):
    """Get total count of items in cart"""
    try:
        supabase = get_supabase()
        if not supabase:
            return 0
        
        response = supabase.table('cart').select('cart_id', count='exact').eq('buyer_id', buyer_id).execute()
        return response.count if response.count else 0
    except Exception as e:
        print(f"Error getting cart count: {e}")
        return 0

def get_product_variant(variant_id):
    """Get product variant details"""
    try:
        supabase = get_supabase()
        if not supabase:
            return None
        
        response = supabase.table('product_variants').select('*').eq('variant_id', variant_id).execute()
        return response.data[0] if response.data else None
    except Exception as e:
        print(f"Error getting variant: {e}")
        return None

def get_product(product_id):
    """Get product details"""
    try:
        supabase = get_supabase()
        if not supabase:
            return None
        
        response = supabase.table('products').select('*').eq('product_id', product_id).execute()
        return response.data[0] if response.data else None
    except Exception as e:
        print(f"Error getting product: {e}")
        return None

def get_favorites(buyer_id):
    """Get all favorite items for a buyer"""
    try:
        supabase = get_supabase()
        if not supabase:
            return []
        
        response = supabase.table('favorites').select('''
            favorite_id,
            product_id,
            added_at,
            products (
                product_name,
                materials,
                price,
                seller_id,
                sellers (
                    shop_name,
                    shop_logo
                )
            )
        ''').eq('buyer_id', buyer_id).execute()
        
        return response.data if response.data else []
    except Exception as e:
        print(f"Error getting favorites: {e}")
        return []

def add_to_favorites_supabase(buyer_id, product_id):
    """Add product to favorites"""
    try:
        supabase = get_supabase()
        if not supabase:
            return None
        
        # Check if already exists
        existing = supabase.table('favorites').select('*').eq('buyer_id', buyer_id).eq('product_id', product_id).execute()
        
        if existing.data:
            return {'exists': True}
        
        response = supabase.table('favorites').insert({
            'buyer_id': buyer_id,
            'product_id': product_id
        }).execute()
        
        return {'favorite_id': response.data[0]['favorite_id']} if response.data else None
    except Exception as e:
        print(f"Error adding to favorites: {e}")
        return None

def remove_from_favorites_supabase(favorite_id, buyer_id):
    """Remove product from favorites"""
    try:
        supabase = get_supabase()
        if not supabase:
            return False
        
        response = supabase.table('favorites').delete().eq('favorite_id', favorite_id).eq('buyer_id', buyer_id).execute()
        return True
    except Exception as e:
        print(f"Error removing from favorites: {e}")
        return False

def get_buyer_addresses(buyer_id):
    """Get all addresses for a buyer"""
    try:
        supabase = get_supabase()
        if not supabase:
            return []
        
        response = supabase.table('addresses').select('*').eq('user_type', 'buyer').eq('user_ref_id', buyer_id).order('is_default', desc=True).order('created_at', desc=True).execute()
        
        return response.data if response.data else []
    except Exception as e:
        print(f"Error getting addresses: {e}")
        return []

def add_address_supabase(buyer_id, address_data):
    """Add new address for buyer"""
    try:
        supabase = get_supabase()
        if not supabase:
            return None
        
        # If setting as default, unset others
        if address_data.get('is_default'):
            supabase.table('addresses').update({'is_default': False}).eq('user_type', 'buyer').eq('user_ref_id', buyer_id).execute()
        
        address_data['user_type'] = 'buyer'
        address_data['user_ref_id'] = buyer_id
        
        response = supabase.table('addresses').insert(address_data).execute()
        return response.data[0] if response.data else None
    except Exception as e:
        print(f"Error adding address: {e}")
        return None

def update_address_supabase(address_id, buyer_id, address_data):
    """Update existing address"""
    try:
        supabase = get_supabase()
        if not supabase:
            return False
        
        response = supabase.table('addresses').update(address_data).eq('address_id', address_id).eq('user_type', 'buyer').eq('user_ref_id', buyer_id).execute()
        return True if response.data else False
    except Exception as e:
        print(f"Error updating address: {e}")
        return False

def delete_address_supabase(address_id, buyer_id):
    """Delete address"""
    try:
        supabase = get_supabase()
        if not supabase:
            return False
        
        response = supabase.table('addresses').delete().eq('address_id', address_id).eq('user_type', 'buyer').eq('user_ref_id', buyer_id).execute()
        return True
    except Exception as e:
        print(f"Error deleting address: {e}")
        return False

def set_default_address_supabase(address_id, buyer_id):
    """Set address as default"""
    try:
        supabase = get_supabase()
        if not supabase:
            return False
        
        # Unset all defaults
        supabase.table('addresses').update({'is_default': False}).eq('user_type', 'buyer').eq('user_ref_id', buyer_id).execute()
        
        # Set new default
        response = supabase.table('addresses').update({'is_default': True}).eq('address_id', address_id).eq('user_type', 'buyer').eq('user_ref_id', buyer_id).execute()
        return True if response.data else False
    except Exception as e:
        print(f"Error setting default address: {e}")
        return False

def get_buyer_profile(user_id):
    """Get buyer profile with user data"""
    try:
        supabase = get_supabase()
        if not supabase:
            return None
        
        response = supabase.table('buyers').select('''
            *,
            users (
                email
            )
        ''').eq('user_id', user_id).execute()
        
        return response.data[0] if response.data else None
    except Exception as e:
        print(f"Error getting profile: {e}")
        return None

def update_buyer_profile_supabase(user_id, profile_data):
    """Update buyer profile"""
    try:
        supabase = get_supabase()
        if not supabase:
            return False
        
        response = supabase.table('buyers').update(profile_data).eq('user_id', user_id).execute()
        return True if response.data else False
    except Exception as e:
        print(f"Error updating profile: {e}")
        return False

def update_user_email_supabase(user_id, email):
    """Update user email"""
    try:
        supabase = get_supabase()
        if not supabase:
            return False
        
        response = supabase.table('users').update({'email': email}).eq('user_id', user_id).execute()
        return True if response.data else False
    except Exception as e:
        print(f"Error updating email: {e}")
        return False

def get_buyer_orders(buyer_id):
    """Get all orders for a buyer"""
    try:
        supabase = get_supabase()
        if not supabase:
            return []
        
        response = supabase.table('orders').select('''
            *,
            sellers (
                shop_name,
                shop_logo
            ),
            deliveries (
                *
            )
        ''').eq('buyer_id', buyer_id).order('created_at', desc=True).execute()
        
        # Convert datetime fields
        orders = convert_datetime_fields(response.data if response.data else [])
        return orders
    except Exception as e:
        print(f"Error getting orders: {e}")
        return []

def get_order_items(order_id):
    """Get all items in an order"""
    try:
        supabase = get_supabase()
        if not supabase:
            return []
        
        response = supabase.table('order_items').select('*').eq('order_id', order_id).execute()
        return response.data if response.data else []
    except Exception as e:
        print(f"Error getting order items: {e}")
        return []

def get_buyer_vouchers(buyer_id):
    """Get available vouchers for buyer"""
    try:
        supabase = get_supabase()
        if not supabase:
            return []
        
        response = supabase.table('buyer_vouchers').select('''
            *,
            vouchers (
                *
            )
        ''').eq('buyer_id', buyer_id).gt('times_remaining', 0).execute()
        
        return response.data if response.data else []
    except Exception as e:
        print(f"Error getting vouchers: {e}")
        return []

def create_order_supabase(order_data):
    """Create new order"""
    try:
        supabase = get_supabase()
        if not supabase:
            return None
        
        response = supabase.table('orders').insert(order_data).execute()
        return response.data[0] if response.data else None
    except Exception as e:
        print(f"Error creating order: {e}")
        return None

def create_order_items_supabase(order_items):
    """Create order items"""
    try:
        supabase = get_supabase()
        if not supabase:
            return False
        
        response = supabase.table('order_items').insert(order_items).execute()
        return True if response.data else False
    except Exception as e:
        print(f"Error creating order items: {e}")
        return False

def update_product_stock_supabase(variant_id, quantity_sold):
    """Update product variant stock after purchase"""
    try:
        supabase = get_supabase()
        if not supabase:
            return False
        
        # Get current stock
        variant = get_product_variant(variant_id)
        if not variant:
            return False
        
        new_stock = variant['stock_quantity'] - quantity_sold
        response = supabase.table('product_variants').update({'stock_quantity': new_stock}).eq('variant_id', variant_id).execute()
        return True if response.data else False
    except Exception as e:
        print(f"Error updating stock: {e}")
        return False

def update_product_total_sold_supabase(product_id, quantity):
    """Update product total_sold count"""
    try:
        supabase = get_supabase()
        if not supabase:
            return False
        
        # Get current total_sold
        product = get_product(product_id)
        if not product:
            return False
        
        new_total = (product.get('total_sold') or 0) + quantity
        response = supabase.table('products').update({'total_sold': new_total}).eq('product_id', product_id).execute()
        return True if response.data else False
    except Exception as e:
        print(f"Error updating total sold: {e}")
        return False

def use_voucher_supabase(buyer_voucher_id, buyer_id):
    """Mark voucher as used"""
    try:
        supabase = get_supabase()
        if not supabase:
            return False
        
        # Get current voucher
        response = supabase.table('buyer_vouchers').select('*').eq('buyer_voucher_id', buyer_voucher_id).eq('buyer_id', buyer_id).execute()
        
        if not response.data:
            return False
        
        voucher = response.data[0]
        new_remaining = voucher['times_remaining'] - 1
        
        update_data = {
            'times_remaining': new_remaining,
            'is_used': new_remaining <= 0
        }
        
        if new_remaining <= 0:
            from datetime import datetime
            update_data['used_at'] = datetime.now().isoformat()
        
        response = supabase.table('buyer_vouchers').update(update_data).eq('buyer_voucher_id', buyer_voucher_id).execute()
        return True if response.data else False
    except Exception as e:
        print(f"Error using voucher: {e}")
        return False

# ============================================
# VOUCHER PRODUCTS FUNCTIONS
# ============================================

def get_voucher_with_shop_count(voucher_id):
    """Get voucher details with shop count"""
    try:
        supabase = get_supabase()
        if not supabase:
            return None
        
        # Get voucher details
        voucher_response = supabase.table('vouchers').select('*').eq('voucher_id', voucher_id).execute()
        
        if not voucher_response.data:
            return None
        
        voucher = voucher_response.data[0]
        
        # Count active sellers offering this voucher
        seller_vouchers = supabase.table('seller_vouchers').select('seller_id').eq('voucher_id', voucher_id).eq('is_active', True).execute()
        
        voucher['shop_count'] = len(seller_vouchers.data) if seller_vouchers.data else 0
        
        return voucher
    except Exception as e:
        print(f"Error getting voucher with shop count: {e}")
        return None

def get_products_by_voucher(voucher_id):
    """Get all products from sellers offering this voucher"""
    try:
        supabase = get_supabase()
        if not supabase:
            return []
        
        # Get seller IDs offering this voucher
        seller_vouchers = supabase.table('seller_vouchers').select('seller_id').eq('voucher_id', voucher_id).eq('is_active', True).execute()
        
        if not seller_vouchers.data:
            return []
        
        seller_ids = [sv['seller_id'] for sv in seller_vouchers.data]
        
        # Get products from these sellers
        products_response = supabase.table('products').select('''
            product_id,
            product_name,
            price,
            category,
            description,
            created_at,
            materials,
            rating,
            total_reviews,
            seller_id,
            sellers (
                shop_name,
                shop_logo
            ),
            product_images!left (
                image_url
            )
        ''').in_('seller_id', seller_ids).eq('is_active', True).order('created_at', desc=True).execute()
        
        # Flatten product images (get primary image)
        products = []
        for product in products_response.data if products_response.data else []:
            # Get primary image or first image
            images = product.get('product_images', [])
            product['image_url'] = images[0]['image_url'] if images else None
            del product['product_images']
            products.append(product)
        
        return products
    except Exception as e:
        print(f"Error getting products by voucher: {e}")
        return []

# ============================================
# BUYER REPORT USER FUNCTIONS
# ============================================

def get_buyer_orders_with_sellers_riders(buyer_id):
    """Get recent orders with sellers and riders"""
    try:
        supabase = get_supabase()
        if not supabase:
            return []
        
        # Get orders with seller info
        orders_response = supabase.table('orders').select('''
            order_id,
            order_number,
            seller_id,
            sellers (
                shop_name
            )
        ''').eq('buyer_id', buyer_id).order('created_at', desc=True).limit(20).execute()
        
        if not orders_response.data:
            return []
        
        orders = orders_response.data
        
        # Get delivery info for each order
        for order in orders:
            delivery_response = supabase.table('deliveries').select('''
                delivery_id,
                rider_id,
                riders (
                    first_name,
                    last_name
                )
            ''').eq('order_id', order['order_id']).execute()
            
            if delivery_response.data:
                delivery = delivery_response.data[0]
                order['delivery_id'] = delivery['delivery_id']
                order['rider_id'] = delivery['rider_id']
                if delivery.get('riders'):
                    order['rider_name'] = f"{delivery['riders']['first_name']} {delivery['riders']['last_name']}"
                else:
                    order['rider_name'] = None
            else:
                order['delivery_id'] = None
                order['rider_id'] = None
                order['rider_name'] = None
        
        return orders
    except Exception as e:
        print(f"Error getting buyer orders with sellers/riders: {e}")
        return []

def get_buyer_reports(reporter_id):
    """Get all reports submitted by buyer"""
    try:
        supabase = get_supabase()
        if not supabase:
            return []
        
        # Get reports
        reports_response = supabase.table('user_reports').select('*').eq('reporter_id', reporter_id).eq('reporter_type', 'buyer').order('created_at', desc=True).execute()
        
        if not reports_response.data:
            return []
        
        reports = convert_datetime_fields(reports_response.data)
        
        # Get reported user names
        for report in reports:
            if report['reported_user_type'] == 'seller':
                seller_response = supabase.table('sellers').select('shop_name').eq('user_id', report['reported_user_id']).execute()
                report['reported_user_name'] = seller_response.data[0]['shop_name'] if seller_response.data else None
            elif report['reported_user_type'] == 'rider':
                rider_response = supabase.table('riders').select('first_name, last_name').eq('user_id', report['reported_user_id']).execute()
                if rider_response.data:
                    rider = rider_response.data[0]
                    report['reported_user_name'] = f"{rider['first_name']} {rider['last_name']}"
                else:
                    report['reported_user_name'] = None
        
        return reports
    except Exception as e:
        print(f"Error getting buyer reports: {e}")
        return []

def get_seller_by_id(seller_id):
    """Get seller by seller_id"""
    try:
        supabase = get_supabase()
        if not supabase:
            return None
        
        response = supabase.table('sellers').select('*').eq('seller_id', seller_id).execute()
        return response.data[0] if response.data else None
    except Exception as e:
        print(f"Error getting seller: {e}")
        return None

def get_rider_by_id(rider_id):
    """Get rider by rider_id"""
    try:
        supabase = get_supabase()
        if not supabase:
            return None
        
        response = supabase.table('riders').select('*').eq('rider_id', rider_id).execute()
        return response.data[0] if response.data else None
    except Exception as e:
        print(f"Error getting rider: {e}")
        return None

def insert_user_report(reporter_id, reporter_type, reported_user_id, reported_user_type, report_category, report_reason, order_id=None, delivery_id=None, evidence_image=None):
    """Insert a new user report"""
    try:
        supabase = get_supabase()
        if not supabase:
            return None
        
        report_data = {
            'reporter_id': reporter_id,
            'reporter_type': reporter_type,
            'reported_user_id': reported_user_id,
            'reported_user_type': reported_user_type,
            'report_category': report_category,
            'report_reason': report_reason,
            'order_id': order_id,
            'delivery_id': delivery_id,
            'evidence_image': evidence_image
        }
        
        response = supabase.table('user_reports').insert(report_data).execute()
        return response.data[0] if response.data else None
    except Exception as e:
        print(f"Error inserting user report: {e}")
        return None

def get_user_report_count(user_id):
    """Get total report count for a user"""
    try:
        supabase = get_supabase()
        if not supabase:
            return 0
        
        response = supabase.table('user_reports').select('report_id', count='exact').eq('reported_user_id', user_id).execute()
        return response.count if response.count else 0
    except Exception as e:
        print(f"Error getting user report count: {e}")
        return 0

def update_seller_report_count(seller_id, report_count):
    """Update seller report count"""
    try:
        supabase = get_supabase()
        if not supabase:
            return False
        
        response = supabase.table('sellers').update({'report_count': report_count}).eq('seller_id', seller_id).execute()
        return True if response.data else False
    except Exception as e:
        print(f"Error updating seller report count: {e}")
        return False

def update_rider_report_count(rider_id, report_count):
    """Update rider report count"""
    try:
        supabase = get_supabase()
        if not supabase:
            return False
        
        response = supabase.table('riders').update({'report_count': report_count}).eq('rider_id', rider_id).execute()
        return True if response.data else False
    except Exception as e:
        print(f"Error updating rider report count: {e}")
        return False

def get_seller_user_details(seller_id):
    """Get seller details with user email"""
    try:
        supabase = get_supabase()
        if not supabase:
            return None
        
        response = supabase.table('sellers').select('''
            first_name,
            last_name,
            user_id,
            users (
                email
            )
        ''').eq('seller_id', seller_id).execute()
        
        if response.data:
            seller = response.data[0]
            return {
                'first_name': seller['first_name'],
                'last_name': seller['last_name'],
                'email': seller['users']['email']
            }
        return None
    except Exception as e:
        print(f"Error getting seller user details: {e}")
        return None

def get_rider_user_details(rider_id):
    """Get rider details with user email"""
    try:
        supabase = get_supabase()
        if not supabase:
            return None
        
        response = supabase.table('riders').select('''
            first_name,
            last_name,
            user_id,
            users (
                email
            )
        ''').eq('rider_id', rider_id).execute()
        
        if response.data:
            rider = response.data[0]
            return {
                'first_name': rider['first_name'],
                'last_name': rider['last_name'],
                'email': rider['users']['email']
            }
        return None
    except Exception as e:
        print(f"Error getting rider user details: {e}")
        return None

# ============================================
# CHAT API FUNCTIONS
# ============================================

def get_buyer_conversations(user_id):
    """Get all conversations for buyer"""
    try:
        supabase = get_supabase()
        if not supabase:
            return []
        
        # Get buyer_id
        buyer_response = supabase.table('buyers').select('buyer_id').eq('user_id', user_id).execute()
        if not buyer_response.data:
            return []
        
        buyer_id = buyer_response.data[0]['buyer_id']
        
        # Get conversations
        conversations_response = supabase.table('conversations').select('''
            conversation_id,
            seller_id,
            rider_id,
            delivery_id,
            last_message,
            last_message_at,
            buyer_unread_count
        ''').eq('buyer_id', buyer_id).not_.is_('last_message', 'null').order('last_message_at', desc=True).execute()
        
        if not conversations_response.data:
            return []
        
        conversations = []
        for conv in conversations_response.data:
            # Determine contact type and get details
            if conv.get('rider_id'):
                # Rider conversation
                rider_response = supabase.table('riders').select('first_name, last_name, profile_image').eq('rider_id', conv['rider_id']).execute()
                if rider_response.data:
                    rider = rider_response.data[0]
                    conv['contact_id'] = conv['rider_id']
                    conv['contact_name'] = f"{rider['first_name']} {rider['last_name']}"
                    conv['contact_avatar'] = rider.get('profile_image')
                    conv['contact_type'] = 'rider'
                    
                    # Get delivery status
                    if conv.get('delivery_id'):
                        delivery_response = supabase.table('deliveries').select('status').eq('delivery_id', conv['delivery_id']).execute()
                        conv['delivery_status'] = delivery_response.data[0]['status'] if delivery_response.data else None
            else:
                # Seller conversation
                seller_response = supabase.table('sellers').select('shop_name, shop_logo').eq('seller_id', conv['seller_id']).execute()
                if seller_response.data:
                    seller = seller_response.data[0]
                    conv['contact_id'] = conv['seller_id']
                    conv['contact_name'] = seller['shop_name']
                    conv['contact_avatar'] = seller.get('shop_logo')
                    conv['contact_type'] = 'seller'
            
            conv['last_message_time'] = conv['last_message_at']
            conv['unread_count'] = conv['buyer_unread_count']
            conversations.append(conv)
        
        return conversations
    except Exception as e:
        print(f"Error getting buyer conversations: {e}")
        return []

def get_seller_conversations(user_id):
    """Get all conversations for seller"""
    try:
        supabase = get_supabase()
        if not supabase:
            return []
        
        # Get seller_id
        seller_response = supabase.table('sellers').select('seller_id').eq('user_id', user_id).execute()
        if not seller_response.data:
            return []
        
        seller_id = seller_response.data[0]['seller_id']
        
        # Get conversations
        conversations_response = supabase.table('conversations').select('''
            conversation_id,
            buyer_id,
            last_message,
            last_message_at,
            seller_unread_count,
            buyers (
                first_name,
                last_name,
                profile_image
            )
        ''').eq('seller_id', seller_id).order('last_message_at', desc=True).execute()
        
        if not conversations_response.data:
            return []
        
        conversations = []
        for conv in conversations_response.data:
            buyer = conv.get('buyers', {})
            conversations.append({
                'conversation_id': conv['conversation_id'],
                'contact_id': conv['buyer_id'],
                'contact_name': f"{buyer.get('first_name', '')} {buyer.get('last_name', '')}",
                'contact_avatar': buyer.get('profile_image'),
                'last_message': conv['last_message'],
                'last_message_time': conv['last_message_at'],
                'unread_count': conv['seller_unread_count'],
                'contact_type': 'buyer'
            })
        
        return conversations
    except Exception as e:
        print(f"Error getting seller conversations: {e}")
        return []

def get_conversation_messages(conversation_id):
    """Get all messages for a conversation"""
    try:
        supabase = get_supabase()
        if not supabase:
            return []
        
        response = supabase.table('messages').select('*').eq('conversation_id', conversation_id).order('created_at', desc=False).execute()
        return response.data if response.data else []
    except Exception as e:
        print(f"Error getting conversation messages: {e}")
        return []

def mark_messages_as_read_buyer(conversation_id):
    """Mark seller messages as read for buyer"""
    try:
        supabase = get_supabase()
        if not supabase:
            return False
        
        response = supabase.table('messages').update({'is_read': True}).eq('conversation_id', conversation_id).eq('sender_type', 'seller').eq('is_read', False).execute()
        return True
    except Exception as e:
        print(f"Error marking messages as read: {e}")
        return False

def mark_messages_as_read_seller(conversation_id):
    """Mark buyer messages as read for seller"""
    try:
        supabase = get_supabase()
        if not supabase:
            return False
        
        response = supabase.table('messages').update({'is_read': True}).eq('conversation_id', conversation_id).eq('sender_type', 'buyer').eq('is_read', False).execute()
        return True
    except Exception as e:
        print(f"Error marking messages as read: {e}")
        return False

def reset_buyer_unread_count(conversation_id):
    """Reset buyer unread count to 0"""
    try:
        supabase = get_supabase()
        if not supabase:
            return False
        
        response = supabase.table('conversations').update({'buyer_unread_count': 0}).eq('conversation_id', conversation_id).execute()
        return True
    except Exception as e:
        print(f"Error resetting buyer unread count: {e}")
        return False

def reset_seller_unread_count(conversation_id):
    """Reset seller unread count to 0"""
    try:
        supabase = get_supabase()
        if not supabase:
            return False
        
        response = supabase.table('conversations').update({'seller_unread_count': 0}).eq('conversation_id', conversation_id).execute()
        return True
    except Exception as e:
        print(f"Error resetting seller unread count: {e}")
        return False

def get_seller_by_user_id(user_id):
    """Get seller by user_id"""
    try:
        supabase = get_supabase()
        if not supabase:
            return None
        
        response = supabase.table('sellers').select('*').eq('user_id', user_id).execute()
        return response.data[0] if response.data else None
    except Exception as e:
        print(f"Error getting seller: {e}")
        return None

def create_conversation(buyer_id, seller_id, last_message, rider_id=None, delivery_id=None):
    """Create a new conversation"""
    try:
        supabase = get_supabase()
        if not supabase:
            print("❌ Supabase client not available")
            return None
        
        from datetime import datetime
        
        conversation_data = {
            'buyer_id': buyer_id,
            'seller_id': seller_id,
            'last_message': last_message,
            'last_message_at': datetime.now().isoformat()
        }
        
        if rider_id:
            conversation_data['rider_id'] = rider_id
        if delivery_id:
            conversation_data['delivery_id'] = delivery_id
        
        print(f"📤 Creating conversation: buyer_id={buyer_id}, seller_id={seller_id}")
        
        response = supabase.table('conversations').insert(conversation_data).execute()
        
        if response.data:
            conversation_id = response.data[0]['conversation_id']
            print(f"✅ Conversation created successfully: conversation_id={conversation_id}")
            return conversation_id
        else:
            print(f"❌ No data returned from conversation insert")
            return None
            
    except Exception as e:
        print(f"❌ Error creating conversation: {e}")
        import traceback
        traceback.print_exc()
        return None

def update_conversation_last_message(conversation_id, last_message):
    """Update conversation last message"""
    try:
        supabase = get_supabase()
        if not supabase:
            return False
        
        from datetime import datetime
        
        response = supabase.table('conversations').update({
            'last_message': last_message,
            'last_message_at': datetime.now().isoformat()
        }).eq('conversation_id', conversation_id).execute()
        return True if response.data else False
    except Exception as e:
        print(f"Error updating conversation: {e}")
        return False

def insert_message(conversation_id, sender_type, sender_id, message_text):
    """Insert a new message"""
    try:
        supabase = get_supabase()
        if not supabase:
            print("❌ Supabase client not available")
            return None
        
        from datetime import datetime
        
        message_data = {
            'conversation_id': conversation_id,
            'sender_type': sender_type,
            'sender_id': sender_id,
            'message_text': message_text,
            'created_at': datetime.now().isoformat()
        }
        
        print(f"📤 Inserting message: conv_id={conversation_id}, sender={sender_type}, text='{message_text[:50]}...'")
        
        response = supabase.table('messages').insert(message_data).execute()
        
        if response.data:
            message_id = response.data[0]['message_id']
            print(f"✅ Message inserted successfully: message_id={message_id}")
            return message_id
        else:
            print(f"❌ No data returned from insert")
            return None
            
    except Exception as e:
        print(f"❌ Error inserting message: {e}")
        import traceback
        traceback.print_exc()
        return None

def get_message_by_id(message_id):
    """Get message by ID"""
    try:
        supabase = get_supabase()
        if not supabase:
            return None
        
        response = supabase.table('messages').select('*').eq('message_id', message_id).execute()
        return response.data[0] if response.data else None
    except Exception as e:
        print(f"Error getting message: {e}")
        return None

def search_sellers_by_shop_name(query):
    """Search sellers by shop name"""
    try:
        supabase = get_supabase()
        if not supabase:
            return []
        
        response = supabase.table('sellers').select('seller_id, shop_name, shop_logo, shop_description').ilike('shop_name', f'%{query}%').order('shop_name').limit(20).execute()
        return response.data if response.data else []
    except Exception as e:
        print(f"Error searching sellers: {e}")
        return []

def get_conversation_by_buyer_seller(buyer_id, seller_id):
    """Get conversation by buyer and seller IDs"""
    try:
        supabase = get_supabase()
        if not supabase:
            return None
        
        response = supabase.table('conversations').select('conversation_id').eq('buyer_id', buyer_id).eq('seller_id', seller_id).execute()
        return response.data[0] if response.data else None
    except Exception as e:
        print(f"Error getting conversation: {e}")
        return None

def increment_seller_unread_count(conversation_id):
    """Increment seller unread count"""
    try:
        supabase = get_supabase()
        if not supabase:
            return False
        
        # Get current count
        response = supabase.table('conversations').select('seller_unread_count').eq('conversation_id', conversation_id).execute()
        if not response.data:
            return False
        
        current_count = response.data[0].get('seller_unread_count', 0)
        
        # Update count
        response = supabase.table('conversations').update({'seller_unread_count': current_count + 1}).eq('conversation_id', conversation_id).execute()
        return True if response.data else False
    except Exception as e:
        print(f"Error incrementing seller unread count: {e}")
        return False

def increment_buyer_unread_count(conversation_id):
    """Increment buyer unread count"""
    try:
        supabase = get_supabase()
        if not supabase:
            return False
        
        # Get current count
        response = supabase.table('conversations').select('buyer_unread_count').eq('conversation_id', conversation_id).execute()
        if not response.data:
            return False
        
        current_count = response.data[0].get('buyer_unread_count', 0)
        
        # Update count
        response = supabase.table('conversations').update({'buyer_unread_count': current_count + 1}).eq('conversation_id', conversation_id).execute()
        return True if response.data else False
    except Exception as e:
        print(f"Error incrementing buyer unread count: {e}")
        return False

# ============================================
# NOTIFICATIONS API FUNCTIONS
# ============================================

def get_user_unread_notification_count(user_id):
    """Get unread notification count for user"""
    try:
        supabase = get_supabase()
        if not supabase:
            return 0
        
        response = supabase.table('notifications').select('notification_id', count='exact').eq('user_id', user_id).eq('is_read', False).execute()
        return response.count if response.count else 0
    except Exception as e:
        print(f"Error getting unread notification count: {e}")
        return 0

def get_user_recent_notifications(user_id):
    """Get recent notifications for user (last 20)"""
    try:
        supabase = get_supabase()
        if not supabase:
            return []
        
        response = supabase.table('notifications').select('notification_id, title, message, notification_type, is_read, created_at').eq('user_id', user_id).order('created_at', desc=True).limit(20).execute()
        return response.data if response.data else []
    except Exception as e:
        print(f"Error getting recent notifications: {e}")
        return []

def mark_notification_as_read(notification_id, user_id):
    """Mark notification as read"""
    try:
        supabase = get_supabase()
        if not supabase:
            return False
        
        response = supabase.table('notifications').update({'is_read': True}).eq('notification_id', notification_id).eq('user_id', user_id).execute()
        return True if response.data else False
    except Exception as e:
        print(f"Error marking notification as read: {e}")
        return False


# ============================================
# UTILITY FUNCTIONS
# ============================================

def clean_supabase_data(data):
    """
    Clean Supabase data by converting Undefined types to None
    This fixes JSON serialization issues
    """
    if data is None:
        return None
    
    # Check if it's an Undefined type
    if str(type(data)) == "<class 'postgrest._types.Undefined'>":
        return None
    
    # Handle dictionaries
    if isinstance(data, dict):
        cleaned = {}
        for key, value in data.items():
            cleaned[key] = clean_supabase_data(value)
        return cleaned
    
    # Handle lists
    if isinstance(data, list):
        return [clean_supabase_data(item) for item in data]
    
    # Return as-is for other types
    return data


def convert_datetime_fields(data, fields=None):
    """
    Convert datetime string fields to datetime objects
    
    Args:
        data: Dictionary or list of dictionaries
        fields: List of field names to convert (default: common datetime fields)
    
    Returns:
        Data with datetime strings converted to datetime objects
    """
    from datetime import datetime
    
    if fields is None:
        # Common datetime field names
        fields = ['created_at', 'updated_at', 'delivered_at', 'assigned_at', 'picked_up_at', 
                  'start_date', 'end_date', 'resolved_at', 'order_received_date']
    
    if data is None:
        return None
    
    # Handle lists
    if isinstance(data, list):
        return [convert_datetime_fields(item, fields) for item in data]
    
    # Handle dictionaries
    if isinstance(data, dict):
        converted = {}
        for key, value in data.items():
            if key in fields and value and isinstance(value, str):
                try:
                    # Convert ISO string to datetime object
                    converted[key] = datetime.fromisoformat(value.replace('Z', '+00:00'))
                except:
                    converted[key] = value
            elif isinstance(value, (dict, list)):
                converted[key] = convert_datetime_fields(value, fields)
            else:
                converted[key] = value
        return converted
    
    # Return as-is for other types
    return data


def get_supabase_storage_url(file_path, bucket_name='Images', use_local_fallback=True):
    """
    Generate full Supabase Storage URL for a file
    
    Args:
        file_path: Path to file (e.g., 'static/uploads/products/image.jpg')
        bucket_name: Name of the Supabase storage bucket (default: 'Images')
        use_local_fallback: If True, return local path if Supabase URL fails (default: True)
    
    Returns:
        Full public URL to the file in Supabase Storage
    """
    if not file_path:
        return None
    
    # Get Supabase URL from environment
    supabase_url = os.getenv('SUPABASE_URL')
    
    if not supabase_url:
        return f"/{file_path}" if not file_path.startswith('/') else file_path
    
    # Clean the file path
    clean_path = file_path.strip()
    
    # Remove leading slash if present
    if clean_path.startswith('/'):
        clean_path = clean_path[1:]
    
    # Extract the path after 'uploads/' to match Supabase Storage structure
    # Database: static/uploads/products/image.jpg
    # Supabase Storage: products/image.jpg (without static/uploads/)
    if 'uploads/' in clean_path:
        clean_path = clean_path.split('uploads/')[-1]
    
    # Construct the full URL
    # Format: https://[project].supabase.co/storage/v1/object/public/Images/products/filename.jpg
    storage_url = f"{supabase_url}/storage/v1/object/public/{bucket_name}/{clean_path}"
    
    return storage_url

def process_image_urls(data, bucket_name='Images'):
    """
    Process image URLs in data to convert to Supabase Storage URLs
    Handles both single objects and lists
    """
    if data is None:
        return None
    
    # Handle lists
    if isinstance(data, list):
        return [process_image_urls(item, bucket_name) for item in data]
    
    # Handle dictionaries
    if isinstance(data, dict):
        processed = {}
        for key, value in data.items():
            # Check if this is an image URL field
            if key in ['image_url', 'profile_image', 'shop_logo', 'primary_image'] and isinstance(value, str):
                processed[key] = get_supabase_storage_url(value, bucket_name)
            elif isinstance(value, (dict, list)):
                processed[key] = process_image_urls(value, bucket_name)
            else:
                processed[key] = value
        return processed
    
    # Return as-is for other types
    return data


def fix_image_url_case(url):
    """
    Fix the case of 'images' to 'Images' in Supabase Storage URLs
    
    Args:
        url: Image URL that might have lowercase 'images'
    
    Returns:
        URL with correct case 'Images'
    """
    if not url or not isinstance(url, str):
        return url
    
    # Replace /images/ with /Images/ (case-sensitive)
    if '/public/images/' in url:
        url = url.replace('/public/images/', '/public/Images/')
    
    return url

def fix_image_urls_in_data(data):
    """
    Recursively fix image URL cases in data structure
    """
    if data is None:
        return None
    
    # Handle lists
    if isinstance(data, list):
        return [fix_image_urls_in_data(item) for item in data]
    
    # Handle dictionaries
    if isinstance(data, dict):
        fixed = {}
        for key, value in data.items():
            # Fix image URL fields
            if key in ['image_url', 'profile_image', 'shop_logo', 'primary_image'] and isinstance(value, str):
                fixed[key] = fix_image_url_case(value)
            elif isinstance(value, (dict, list)):
                fixed[key] = fix_image_urls_in_data(value)
            else:
                fixed[key] = value
        return fixed
    
    # Return as-is for other types
    return data


# ============================================
# PERFORMANCE OPTIMIZATION FUNCTIONS
# ============================================

from functools import lru_cache
from datetime import datetime, timedelta

# Simple in-memory cache for frequently accessed data
_cache = {}
_cache_timestamps = {}
CACHE_DURATION = 300  # 5 minutes

def get_cached_or_fetch(cache_key, fetch_function, cache_duration=CACHE_DURATION):
    """
    Get data from cache or fetch if not cached/expired
    
    Args:
        cache_key: Unique key for this data
        fetch_function: Function to call if cache miss
        cache_duration: How long to cache in seconds
    
    Returns:
        Cached or freshly fetched data
    """
    now = datetime.now()
    
    # Check if we have cached data and it's not expired
    if cache_key in _cache and cache_key in _cache_timestamps:
        cache_time = _cache_timestamps[cache_key]
        if (now - cache_time).total_seconds() < cache_duration:
            return _cache[cache_key]
    
    # Fetch fresh data
    data = fetch_function()
    
    # Store in cache
    _cache[cache_key] = data
    _cache_timestamps[cache_key] = now
    
    return data

def clear_cache(cache_key=None):
    """Clear cache for specific key or all cache"""
    global _cache, _cache_timestamps
    
    if cache_key:
        _cache.pop(cache_key, None)
        _cache_timestamps.pop(cache_key, None)
    else:
        _cache.clear()
        _cache_timestamps.clear()

def get_product_full_data(product_id):
    """
    Optimized function to get all product data in fewer queries
    Combines product, variants, images, and reviews
    """
    try:
        supabase = get_supabase()
        if not supabase:
            return None
        
        # Single query to get product with seller
        product_response = supabase.table('products').select('''
            product_id,
            product_name,
            description,
            materials,
            sdg,
            price,
            category,
            rating,
            total_reviews,
            total_sold,
            sellers (
                shop_name,
                shop_logo,
                seller_id
            )
        ''').eq('product_id', product_id).eq('is_active', True).execute()
        
        if not product_response.data:
            return None
        
        product = clean_supabase_data(product_response.data[0])
        product = fix_image_urls_in_data(product)
        
        # Get variants with images in one query
        variants_response = supabase.table('product_variants').select(
            'variant_id, color, hex_code, size, stock_quantity, image_url'
        ).eq('product_id', product_id).order('color').order('size').execute()
        
        variants = clean_supabase_data(variants_response.data) if variants_response.data else []
        variants = fix_image_urls_in_data(variants)
        
        # Get product images
        images_response = supabase.table('product_images').select(
            'image_url, is_primary, display_order'
        ).eq('product_id', product_id).order('is_primary', desc=True).order('display_order').execute()
        
        images = clean_supabase_data(images_response.data) if images_response.data else []
        images = fix_image_urls_in_data(images)
        
        return {
            'product': product,
            'variants': variants,
            'images': images
        }
        
    except Exception as e:
        print(f"Error getting product full data: {e}")
        return None


def get_optimized_image_url(image_url, width=None, height=None, quality=80):
    """
    Get optimized image URL with transformations
    Supabase supports on-the-fly image transformations
    
    Args:
        image_url: Original image URL
        width: Target width in pixels
        height: Target height in pixels
        quality: Image quality (1-100)
    
    Returns:
        Optimized image URL with transformations
    """
    if not image_url or not isinstance(image_url, str):
        return image_url
    
    # Only process Supabase Storage URLs
    if 'supabase.co/storage/v1/object/public/' not in image_url:
        return image_url
    
    # Build transformation parameters
    params = []
    if width:
        params.append(f'width={width}')
    if height:
        params.append(f'height={height}')
    if quality and quality != 80:
        params.append(f'quality={quality}')
    
    if not params:
        return image_url
    
    # Add transformation parameters to URL
    # Format: /render/image/authenticated/bucket/path?width=300&height=300
    # For public buckets, transformations are applied via query params
    separator = '&' if '?' in image_url else '?'
    return f"{image_url}{separator}{'&'.join(params)}"


# ============================================
# RIDER FUNCTIONS
# ============================================

def get_rider_by_user_id(user_id):
    """Get rider record by user_id with email"""
    try:
        supabase = get_supabase()
        if not supabase:
            return None
        
        response = supabase.table('riders').select('''
            *,
            users (
                email
            )
        ''').eq('user_id', user_id).execute()
        
        if response.data:
            rider = clean_supabase_data(response.data[0])
            return fix_image_urls_in_data(rider)
        return None
    except Exception as e:
        print(f"Error getting rider: {e}")
        return None

def get_rider_profile(user_id):
    """Get full rider profile with user data"""
    try:
        supabase = get_supabase()
        if not supabase:
            return None
        
        response = supabase.table('riders').select('''
            *,
            users (
                email
            )
        ''').eq('user_id', user_id).execute()
        
        if response.data:
            rider = clean_supabase_data(response.data[0])
            return fix_image_urls_in_data(rider)
        return None
    except Exception as e:
        print(f"Error getting rider profile: {e}")
        return None

def update_rider_profile_supabase(user_id, profile_data):
    """Update rider profile"""
    try:
        supabase = get_supabase()
        if not supabase:
            return False
        
        response = supabase.table('riders').update(profile_data).eq('user_id', user_id).execute()
        return True if response.data else False
    except Exception as e:
        print(f"Error updating rider profile: {e}")
        return False

def get_rider_dashboard_summary(rider_id):
    """Get dashboard summary statistics for rider"""
    try:
        supabase = get_supabase()
        if not supabase:
            return None
        
        from datetime import datetime, date
        
        # Count pending pickups (deliveries not assigned to any rider)
        pending_response = supabase.table('deliveries').select('delivery_id', count='exact').eq('status', 'pending').is_('rider_id', 'null').execute()
        pending_pickups = pending_response.count if pending_response.count else 0
        
        # Count active deliveries for this rider
        active_response = supabase.table('deliveries').select('delivery_id', count='exact').eq('rider_id', rider_id).in_('status', ['assigned', 'in_transit']).execute()
        active_deliveries = active_response.count if active_response.count else 0
        
        # Calculate total earnings (all time)
        total_earnings_response = supabase.table('deliveries').select('rider_earnings').eq('rider_id', rider_id).eq('status', 'delivered').execute()
        total_earnings = sum(float(d.get('rider_earnings', 0) or 0) for d in (total_earnings_response.data or []))
        
        # Calculate today's earnings
        today = date.today().isoformat()
        today_earnings_response = supabase.table('deliveries').select('rider_earnings').eq('rider_id', rider_id).eq('status', 'delivered').gte('delivered_at', today).execute()
        today_earnings = sum(float(d.get('rider_earnings', 0) or 0) for d in (today_earnings_response.data or []))
        
        return {
            'pending_pickups': pending_pickups,
            'active_deliveries': active_deliveries,
            'total_earnings': total_earnings,
            'today_earnings': today_earnings
        }
    except Exception as e:
        print(f"Error getting rider dashboard summary: {e}")
        return None

def get_rider_recent_deliveries(rider_id, limit=10):
    """Get recent deliveries for rider"""
    try:
        supabase = get_supabase()
        if not supabase:
            return []
        
        response = supabase.table('deliveries').select('''
            delivery_id,
            order_id,
            status,
            delivery_fee,
            rider_earnings,
            assigned_at,
            picked_up_at,
            delivered_at,
            orders (
                order_number,
                total_amount,
                buyers (
                    first_name,
                    last_name
                ),
                sellers (
                    shop_name
                )
            )
        ''').eq('rider_id', rider_id).order('assigned_at', desc=True).limit(limit).execute()
        
        if response.data:
            deliveries = clean_supabase_data(response.data)
            return fix_image_urls_in_data(deliveries)
        return []
    except Exception as e:
        print(f"Error getting recent deliveries: {e}")
        return []

def get_pending_deliveries():
    """Get all pending deliveries (not assigned to any rider)"""
    try:
        supabase = get_supabase()
        if not supabase:
            return []
        
        response = supabase.table('deliveries').select('''
            delivery_id,
            order_id,
            pickup_address,
            delivery_address,
            delivery_fee,
            status,
            created_at,
            orders (
                order_number,
                total_amount,
                order_status,
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
        ''').eq('status', 'pending').is_('rider_id', 'null').neq('orders.order_status', 'cancelled').order('created_at', desc=True).execute()
        
        if response.data:
            deliveries = clean_supabase_data(response.data)
            return fix_image_urls_in_data(deliveries)
        return []
    except Exception as e:
        print(f"Error getting pending deliveries: {e}")
        return []

def get_rider_active_deliveries(rider_id):
    """Get active deliveries for rider (assigned, in_transit, delivered)"""
    try:
        supabase = get_supabase()
        if not supabase:
            return []
        
        response = supabase.table('deliveries').select('''
            delivery_id,
            order_id,
            pickup_address,
            delivery_address,
            delivery_fee,
            rider_earnings,
            status,
            assigned_at,
            picked_up_at,
            orders (
                order_number,
                total_amount,
                order_received,
                order_status,
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
        ''').eq('rider_id', rider_id).in_('status', ['assigned', 'in_transit', 'delivered']).eq('orders.order_received', False).neq('orders.order_status', 'cancelled').order('assigned_at', desc=True).execute()
        
        if response.data:
            deliveries = clean_supabase_data(response.data)
            return fix_image_urls_in_data(deliveries)
        return []
    except Exception as e:
        print(f"Error getting active deliveries: {e}")
        return []

def accept_delivery_supabase(delivery_id, rider_id):
    """Accept/assign delivery to rider"""
    try:
        supabase = get_supabase()
        if not supabase:
            return False
        
        from datetime import datetime
        
        response = supabase.table('deliveries').update({
            'rider_id': rider_id,
            'status': 'assigned',
            'assigned_at': datetime.now().isoformat()
        }).eq('delivery_id', delivery_id).execute()
        
        return True if response.data else False
    except Exception as e:
        print(f"Error accepting delivery: {e}")
        return False

def update_delivery_status_supabase(delivery_id, status, timestamps=None):
    """Update delivery status with optional timestamps"""
    try:
        supabase = get_supabase()
        if not supabase:
            return False
        
        update_data = {'status': status}
        
        if timestamps:
            update_data.update(timestamps)
        
        response = supabase.table('deliveries').update(update_data).eq('delivery_id', delivery_id).execute()
        return True if response.data else False
    except Exception as e:
        print(f"Error updating delivery status: {e}")
        return False

def mark_delivery_picked_up(delivery_id):
    """Mark delivery as picked up"""
    try:
        from datetime import datetime
        return update_delivery_status_supabase(delivery_id, 'in_transit', {
            'picked_up_at': datetime.now().isoformat()
        })
    except Exception as e:
        print(f"Error marking delivery picked up: {e}")
        return False

def mark_delivery_in_transit(delivery_id):
    """Mark delivery as in transit"""
    try:
        return update_delivery_status_supabase(delivery_id, 'in_transit')
    except Exception as e:
        print(f"Error marking delivery in transit: {e}")
        return False

def mark_delivery_delivered(delivery_id):
    """Mark delivery as delivered"""
    try:
        from datetime import datetime
        return update_delivery_status_supabase(delivery_id, 'delivered', {
            'delivered_at': datetime.now().isoformat()
        })
    except Exception as e:
        print(f"Error marking delivery delivered: {e}")
        return False

def get_delivery_by_id(delivery_id):
    """Get delivery details by ID"""
    try:
        supabase = get_supabase()
        if not supabase:
            return None
        
        response = supabase.table('deliveries').select('*').eq('delivery_id', delivery_id).execute()
        
        if response.data:
            delivery = clean_supabase_data(response.data[0])
            return fix_image_urls_in_data(delivery)
        return None
    except Exception as e:
        print(f"Error getting delivery: {e}")
        return None

def get_order_by_id(order_id):
    """Get order details by ID"""
    try:
        supabase = get_supabase()
        if not supabase:
            return None
        
        response = supabase.table('orders').select('*').eq('order_id', order_id).execute()
        
        if response.data:
            order = clean_supabase_data(response.data[0])
            return fix_image_urls_in_data(order)
        return None
    except Exception as e:
        print(f"Error getting order: {e}")
        return None

def update_order_status_supabase(order_id, status):
    """Update order status"""
    try:
        supabase = get_supabase()
        if not supabase:
            return False
        
        response = supabase.table('orders').update({'order_status': status}).eq('order_id', order_id).execute()
        return True if response.data else False
    except Exception as e:
        print(f"Error updating order status: {e}")
        return False


# ============================================
# RIDER EARNINGS FUNCTIONS
# ============================================

def get_rider_total_earnings(rider_id):
    """Get total earnings (all time) for rider"""
    try:
        supabase = get_supabase()
        if not supabase:
            return 0
        
        response = supabase.table('deliveries').select('rider_earnings').eq('rider_id', rider_id).eq('status', 'delivered').execute()
        
        total = sum(float(d.get('rider_earnings', 0) or 0) for d in (response.data or []))
        return total
    except Exception as e:
        print(f"Error getting total earnings: {e}")
        return 0

def get_rider_pending_earnings(rider_id):
    """Get pending/unpaid earnings for rider"""
    try:
        supabase = get_supabase()
        if not supabase:
            return 0
        
        # Pending earnings are from delivered orders that haven't been paid out yet
        response = supabase.table('deliveries').select('rider_earnings').eq('rider_id', rider_id).eq('status', 'delivered').eq('paid_out', False).execute()
        
        total = sum(float(d.get('rider_earnings', 0) or 0) for d in (response.data or []))
        return total
    except Exception as e:
        print(f"Error getting pending earnings: {e}")
        return 0

def get_rider_earnings_history(rider_id, start_date=None, end_date=None):
    """Get earnings history with optional date range"""
    try:
        supabase = get_supabase()
        if not supabase:
            return []
        
        query = supabase.table('deliveries').select('''
            delivery_id,
            rider_earnings,
            delivered_at,
            paid_out,
            order_id,
            orders (
                order_number,
                total_amount,
                buyers (
                    first_name,
                    last_name
                ),
                sellers (
                    shop_name
                )
            )
        ''').eq('rider_id', rider_id).eq('status', 'delivered').order('delivered_at', desc=True)
        
        if start_date:
            query = query.gte('delivered_at', start_date)
        if end_date:
            query = query.lte('delivered_at', end_date)
        
        response = query.execute()
        
        if response.data:
            earnings = clean_supabase_data(response.data)
            return fix_image_urls_in_data(earnings)
        return []
    except Exception as e:
        print(f"Error getting earnings history: {e}")
        return []

def get_rider_delivery_earnings(rider_id):
    """Get all deliveries with earnings details"""
    try:
        supabase = get_supabase()
        if not supabase:
            return []
        
        response = supabase.table('deliveries').select('''
            delivery_id,
            delivery_fee,
            rider_earnings,
            delivered_at,
            paid_out,
            orders (
                order_number,
                total_amount,
                buyers (
                    first_name,
                    last_name
                ),
                sellers (
                    shop_name
                )
            )
        ''').eq('rider_id', rider_id).eq('status', 'delivered').order('delivered_at', desc=True).execute()
        
        if response.data:
            deliveries = clean_supabase_data(response.data)
            return fix_image_urls_in_data(deliveries)
        return []
    except Exception as e:
        print(f"Error getting delivery earnings: {e}")
        return []


def mark_messages_as_read_rider(conversation_id):
    """Mark buyer messages as read for rider"""
    try:
        supabase = get_supabase()
        if not supabase:
            return False
        
        response = supabase.table('messages').update({'is_read': True}).eq('conversation_id', conversation_id).eq('sender_type', 'buyer').eq('is_read', False).execute()
        return True
    except Exception as e:
        print(f"Error marking messages as read: {e}")
        return False

def get_rider_deliveries_with_users(rider_id):
    """Get deliveries with buyer/seller info for reporting"""
    try:
        supabase = get_supabase()
        if not supabase:
            return []
        
        response = supabase.table('deliveries').select('''
            delivery_id,
            orders (
                order_id,
                order_number,
                buyer_id,
                seller_id,
                buyers (
                    first_name,
                    last_name
                ),
                sellers (
                    shop_name
                )
            )
        ''').eq('rider_id', rider_id).order('created_at', desc=True).limit(20).execute()
        
        if response.data:
            deliveries = clean_supabase_data(response.data)
            return fix_image_urls_in_data(deliveries)
        return []
    except Exception as e:
        print(f"Error getting rider deliveries with users: {e}")
        return []

def get_rider_reports(reporter_id):
    """Get all reports submitted by rider"""
    try:
        supabase = get_supabase()
        if not supabase:
            return []
        
        response = supabase.table('user_reports').select('*').eq('reporter_id', reporter_id).eq('reporter_type', 'rider').order('created_at', desc=True).execute()
        
        if not response.data:
            return []
        
        reports = convert_datetime_fields(clean_supabase_data(response.data))
        
        # Get reported user names
        for report in reports:
            if report['reported_user_type'] == 'buyer':
                buyer_response = supabase.table('buyers').select('first_name, last_name').eq('user_id', report['reported_user_id']).execute()
                if buyer_response.data:
                    buyer = buyer_response.data[0]
                    report['reported_user_name'] = f"{buyer['first_name']} {buyer['last_name']}"
                else:
                    report['reported_user_name'] = None
            elif report['reported_user_type'] == 'seller':
                seller_response = supabase.table('sellers').select('shop_name').eq('user_id', report['reported_user_id']).execute()
                report['reported_user_name'] = seller_response.data[0]['shop_name'] if seller_response.data else None
        
        return reports
    except Exception as e:
        print(f"Error getting rider reports: {e}")
        return []
