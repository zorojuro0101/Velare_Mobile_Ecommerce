from flask import Blueprint, render_template, session
import os
import sys
from datetime import datetime

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_config import get_db_connection, close_db_connection, get_supabase_client
from utils.auth_decorators import seller_required

seller_dashboard_bp = Blueprint('seller_dashboard', __name__)

@seller_dashboard_bp.route('/seller/dashboard')
@seller_required
def seller_dashboard():
    """Display seller dashboard with order statistics and recent orders using Supabase"""
    print(f"\n{'='*80}")
    print(f"📊 [SELLER DASHBOARD] Loading dashboard...")
    print(f"{'='*80}\n")
    
    try:
        # Get seller_id from session - guaranteed to exist due to @seller_required decorator
        seller_id = session.get('seller_id')
        print(f"🔍 Seller ID: {seller_id}")
        
        supabase = get_supabase_client()
        if not supabase:
            print("❌ Supabase client not available")
            return render_template('seller/seller_dashboard.html', 
                                 seller=None,
                                 order_stats={'pending_count': 0, 'shipped_count': 0, 'delivered_count': 0, 'cancelled_count': 0},
                                 recent_orders=[],
                                 error='Database connection failed')
        
        try:
            # Get seller information for profile display
            print(f"👤 Fetching seller info...")
            seller_response = supabase.table('sellers').select(
                'first_name, last_name, shop_name, shop_logo'
            ).eq('seller_id', seller_id).execute()
            
            seller_info = seller_response.data[0] if seller_response.data else None
            print(f"✅ Seller: {seller_info.get('shop_name') if seller_info else 'None'}")
            
            # Get order status counts efficiently using separate queries with count
            print(f"📊 Fetching order stats for seller_id: {seller_id}")
            
            pending_response = supabase.table('orders').select('order_id', count='exact').eq('seller_id', seller_id).eq('order_status', 'pending').execute()
            shipped_response = supabase.table('orders').select('order_id', count='exact').eq('seller_id', seller_id).eq('order_status', 'in_transit').execute()
            delivered_response = supabase.table('orders').select('order_id', count='exact').eq('seller_id', seller_id).eq('order_status', 'delivered').execute()
            cancelled_response = supabase.table('orders').select('order_id', count='exact').eq('seller_id', seller_id).eq('order_status', 'cancelled').execute()
            
            order_stats = {
                'pending_count': pending_response.count or 0,
                'shipped_count': shipped_response.count or 0,
                'delivered_count': delivered_response.count or 0,
                'cancelled_count': cancelled_response.count or 0
            }
            
            print(f"📊 Order stats: {order_stats}")
            
            # Get recent orders (last 10) with buyer info and delivery status
            print(f"📊 Fetching recent orders for seller_id: {seller_id}")
            recent_orders_response = supabase.table('orders').select(
                'order_id, order_number, created_at, subtotal, total_amount, order_status, buyer_id, buyers(first_name, last_name), deliveries(status)'
            ).eq('seller_id', seller_id).order('created_at', desc=True).limit(10).execute()
            
            print(f"📦 Recent orders response: {len(recent_orders_response.data) if recent_orders_response.data else 0} orders")
            
            recent_orders = []
            if recent_orders_response.data:
                # Collect all order IDs for batch fetching
                order_ids = [order['order_id'] for order in recent_orders_response.data]
                
                # Batch fetch all order items for these orders
                print(f"📦 Batch fetching order items for {len(order_ids)} orders")
                all_order_items_response = supabase.table('order_items').select(
                    'order_id, product_id, product_name, quantity, unit_price, variant_color, variant_size'
                ).in_('order_id', order_ids).execute()
                
                # Group order items by order_id
                order_items_dict = {}
                product_ids = []
                if all_order_items_response.data:
                    for item in all_order_items_response.data:
                        order_id = item['order_id']
                        if order_id not in order_items_dict:
                            order_items_dict[order_id] = []
                        order_items_dict[order_id].append(item)
                        if item['product_id'] not in product_ids:
                            product_ids.append(item['product_id'])
                
                print(f"📦 Found {len(all_order_items_response.data) if all_order_items_response.data else 0} total items")
                print(f"🖼️ Batch fetching images for {len(product_ids)} products")
                
                # Batch fetch all product images
                images_dict = {}
                if product_ids:
                    images_response = supabase.table('product_images').select(
                        'product_id, image_url'
                    ).eq('is_primary', True).in_('product_id', product_ids).execute()
                    
                    if images_response.data:
                        images_dict = {img['product_id']: img['image_url'] for img in images_response.data}
                    
                    print(f"🖼️ Found {len(images_dict)} primary images")
                
                # Process each order
                for order in recent_orders_response.data:
                    print(f"🔍 Processing order: {order.get('order_id')}")
                    
                    # Convert created_at string to datetime object
                    if order.get('created_at'):
                        try:
                            order['created_at'] = datetime.fromisoformat(order['created_at'].replace('Z', '+00:00'))
                        except:
                            order['created_at'] = None
                    
                    # Flatten buyer data
                    buyer_data = order.get('buyers', {})
                    order['buyer_name'] = f"{buyer_data.get('first_name', '')} {buyer_data.get('last_name', '')}"
                    
                    # Get delivery status
                    deliveries = order.get('deliveries')
                    order['delivery_status'] = deliveries[0].get('status') if deliveries and len(deliveries) > 0 else None
                    
                    # Remove nested objects
                    if 'buyers' in order:
                        del order['buyers']
                    if 'deliveries' in order:
                        del order['deliveries']
                    
                    # Get order items from batch-fetched data
                    order_items = order_items_dict.get(order['order_id'], [])
                    
                    # Add images to items
                    for item in order_items:
                        item['image'] = images_dict.get(item['product_id'])
                    
                    order['order_items'] = order_items
                    
                    # Only add order if it has items
                    if order['order_items']:
                        recent_orders.append(order)
                    else:
                        print(f"   ⚠️ Skipping order {order['order_id']} - no items found")
            
            # Get sold products (delivered and confirmed orders) - last 10
            print(f"📊 Fetching sold orders for seller_id: {seller_id}")
            sold_orders_response = supabase.table('orders').select(
                'order_id, order_number, subtotal, commission_amount, updated_at, buyer_id, buyers(first_name, last_name)'
            ).eq('seller_id', seller_id).eq('order_status', 'delivered').eq('order_received', True).order('updated_at', desc=True).limit(10).execute()
            
            print(f"📦 Sold orders response: {len(sold_orders_response.data) if sold_orders_response.data else 0} orders")
            
            sold_orders = []
            if sold_orders_response.data:
                # Collect all sold order IDs for batch fetching
                sold_order_ids = [order['order_id'] for order in sold_orders_response.data]
                
                # Batch fetch all order items for sold orders
                print(f"📦 Batch fetching sold items for {len(sold_order_ids)} orders")
                all_sold_items_response = supabase.table('order_items').select(
                    'order_id, product_name, variant_color, variant_size, quantity, unit_price, subtotal'
                ).in_('order_id', sold_order_ids).execute()
                
                # Group sold items by order_id
                sold_items_dict = {}
                if all_sold_items_response.data:
                    for item in all_sold_items_response.data:
                        order_id = item['order_id']
                        if order_id not in sold_items_dict:
                            sold_items_dict[order_id] = []
                        sold_items_dict[order_id].append(item)
                
                print(f"📦 Found {len(all_sold_items_response.data) if all_sold_items_response.data else 0} total sold items")
                
                # Process each sold order
                for order in sold_orders_response.data:
                    print(f"🔍 Processing sold order: {order.get('order_id')}")
                    
                    # Convert updated_at string to datetime object
                    if order.get('updated_at'):
                        try:
                            order['updated_at'] = datetime.fromisoformat(order['updated_at'].replace('Z', '+00:00'))
                        except:
                            order['updated_at'] = None
                    
                    # Flatten buyer data
                    buyer_data = order.get('buyers', {})
                    order['buyer_name'] = f"{buyer_data.get('first_name', '')} {buyer_data.get('last_name', '')}"
                    order['order_received_date'] = order.get('updated_at')
                    order['order_total'] = order.get('subtotal')
                    
                    # Remove nested objects
                    if 'buyers' in order:
                        del order['buyers']
                    
                    # Get order items from batch-fetched data
                    order['sold_items'] = sold_items_dict.get(order['order_id'], [])
                    
                    # Only add order if it has items
                    if order['sold_items']:
                        sold_orders.append(order)
                    else:
                        print(f"   ⚠️ Skipping sold order {order['order_id']} - no items found")
            
            print(f"✅ Dashboard loaded successfully")
            print(f"   📊 Stats: {order_stats['pending_count']} pending, {order_stats['shipped_count']} shipped, {order_stats['delivered_count']} delivered")
            print(f"   📦 Recent orders: {len(recent_orders)}")
            print(f"   💰 Sold orders: {len(sold_orders)}")
            print(f"{'='*80}\n")
            
            return render_template('seller/seller_dashboard.html',
                                 seller=seller_info,
                                 order_stats=order_stats,
                                 recent_orders=recent_orders,
                                 sold_orders=sold_orders)
            
        except Exception as e:
            print(f"❌ Database error: {str(e)}")
            import traceback
            traceback.print_exc()
            return render_template('seller/seller_dashboard.html', 
                                 seller=None,
                                 order_stats={'pending_count': 0, 'shipped_count': 0, 'delivered_count': 0, 'cancelled_count': 0},
                                 recent_orders=[],
                                 error=str(e))
        
    except Exception as e:
        print(f"❌ Error in seller_dashboard: {str(e)}")
        import traceback
        traceback.print_exc()
        return render_template('seller/seller_dashboard.html', 
                             seller=None,
                             order_stats={'pending_count': 0, 'shipped_count': 0, 'delivered_count': 0, 'cancelled_count': 0},
                             recent_orders=[],
                             error=str(e))
