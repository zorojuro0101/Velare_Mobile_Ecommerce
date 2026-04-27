from flask import Blueprint, render_template, session
import os
import sys

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_config import get_db_connection, close_db_connection
from utils.auth_decorators import seller_required

seller_dashboard_bp = Blueprint('seller_dashboard', __name__)

@seller_dashboard_bp.route('/seller/dashboard')
@seller_required
def seller_dashboard():
    """Display seller dashboard with order statistics and recent orders"""
    try:
        # Get seller_id from session - guaranteed to exist due to @seller_required decorator
        seller_id = session.get('seller_id')
        
        connection = get_db_connection()
        if not connection:
            return render_template('seller/seller_dashboard.html', 
                                 seller=None,
                                 order_stats={'pending_count': 0, 'shipped_count': 0, 'delivered_count': 0, 'cancelled_count': 0},
                                 recent_orders=[],
                                 error='Database connection failed')
        
        cursor = connection.cursor(dictionary=True)
        
        # Get seller information for profile display
        cursor.execute("""
            SELECT first_name, last_name, shop_name, shop_logo
            FROM sellers
            WHERE seller_id = %s
        """, (seller_id,))
        seller_info = cursor.fetchone()
        
        # Fix shop_logo path: remove 'static/' prefix for url_for
        if seller_info and seller_info.get('shop_logo'):
            if seller_info['shop_logo'].startswith('static/'):
                seller_info['shop_logo'] = seller_info['shop_logo'][7:]  # Remove 'static/' prefix
        
        # Get order status counts
        cursor.execute("""
            SELECT 
                COALESCE(SUM(CASE WHEN o.order_status = 'pending' THEN 1 ELSE 0 END), 0) as pending_count,
                COALESCE(SUM(CASE WHEN o.order_status = 'in_transit' THEN 1 ELSE 0 END), 0) as shipped_count,
                COALESCE(SUM(CASE WHEN o.order_status = 'delivered' THEN 1 ELSE 0 END), 0) as delivered_count,
                COALESCE(SUM(CASE WHEN o.order_status = 'cancelled' THEN 1 ELSE 0 END), 0) as cancelled_count
            FROM orders o
            WHERE o.seller_id = %s
        """, (seller_id,))
        order_stats = cursor.fetchone()
        
        # If no orders exist, set default values
        if not order_stats or order_stats['pending_count'] is None:
            order_stats = {
                'pending_count': 0,
                'shipped_count': 0,
                'delivered_count': 0,
                'cancelled_count': 0
            }
        
        # Get recent orders (last 10) - same as seller_product_management
        cursor.execute("""
            SELECT o.order_id, o.order_number, o.created_at, o.subtotal, o.total_amount, o.order_status,
                   CONCAT(b.first_name, ' ', b.last_name) as buyer_name,
                   d.status as delivery_status
            FROM orders o
            JOIN buyers b ON o.buyer_id = b.buyer_id
            LEFT JOIN deliveries d ON o.order_id = d.order_id
            WHERE o.seller_id = %s
            ORDER BY o.created_at DESC
            LIMIT 10
        """, (seller_id,))
        recent_orders = cursor.fetchall()
        
        # Get order items for each order
        for order in recent_orders:
            cursor.execute("""
                SELECT oi.product_id, oi.product_name, oi.quantity, oi.unit_price,
                       oi.variant_color, oi.variant_size,
                       (SELECT image_url FROM product_images WHERE product_id = oi.product_id AND is_primary = TRUE LIMIT 1) as image
                FROM order_items oi
                WHERE oi.order_id = %s
            """, (order['order_id'],))
            order['order_items'] = cursor.fetchall()
        
        # Get sold products (delivered and confirmed orders) - last 10
        cursor.execute("""
            SELECT 
                o.order_id,
                o.order_number,
                o.subtotal as order_total,
                o.commission_amount,
                o.updated_at as order_received_date,
                CONCAT(b.first_name, ' ', b.last_name) as buyer_name
            FROM orders o
            JOIN buyers b ON o.buyer_id = b.buyer_id
            WHERE o.seller_id = %s 
            AND o.order_status = 'delivered'
            AND o.order_received = TRUE
            ORDER BY o.updated_at DESC
            LIMIT 10
        """, (seller_id,))
        sold_orders = cursor.fetchall()
        
        # Get order items for each sold order
        for order in sold_orders:
            cursor.execute("""
                SELECT 
                    product_name,
                    variant_color,
                    variant_size,
                    quantity,
                    unit_price,
                    subtotal
                FROM order_items
                WHERE order_id = %s
            """, (order['order_id'],))
            order['sold_items'] = cursor.fetchall()
        
        close_db_connection(connection, cursor)
        
        return render_template('seller/seller_dashboard.html',
                             seller=seller_info,
                             order_stats=order_stats,
                             recent_orders=recent_orders,
                             sold_orders=sold_orders)
        
    except Exception as e:
        print(f"Error in seller_dashboard: {str(e)}")
        import traceback
        traceback.print_exc()
        return render_template('seller/seller_dashboard.html', 
                             seller=None,
                             order_stats={'pending_count': 0, 'shipped_count': 0, 'delivered_count': 0, 'cancelled_count': 0},
                             recent_orders=[],
                             error=str(e))
