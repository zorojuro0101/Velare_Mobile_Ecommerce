from flask import Blueprint, render_template, session
import os
import sys

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_config import get_db_connection, close_db_connection
from utils.auth_decorators import seller_required

seller_messages_bp = Blueprint('seller_messages', __name__)

@seller_messages_bp.route('/seller/messages')
@seller_required
def seller_messages():
    """Display seller messages page"""
    try:
        seller_id = session.get('seller_id')
        
        connection = get_db_connection()
        if not connection:
            return render_template('seller/seller_messages.html', error='Database connection failed')
        
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
        
        close_db_connection(connection, cursor)
        
        return render_template('seller/seller_messages.html', seller=seller_info)
        
    except Exception as e:
        print(f"Error loading seller messages: {e}")
        return render_template('seller/seller_messages.html', error=str(e))
