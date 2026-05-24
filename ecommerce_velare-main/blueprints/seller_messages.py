from flask import Blueprint, render_template, session
import os
import sys

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_config import get_supabase_client
from utils.auth_decorators import seller_required

seller_messages_bp = Blueprint('seller_messages', __name__)

@seller_messages_bp.route('/seller/messages')
@seller_required
def seller_messages():
    """Display seller messages page"""
    try:
        seller_id = session.get('seller_id')
        print(f"🔍 Seller Messages - seller_id: {seller_id}")
        
        supabase = get_supabase_client()
        if not supabase:
            print("❌ Supabase client not available")
            return render_template('seller/seller_messages.html', error='Database connection failed')
        
        # Get seller information for profile display
        seller_response = supabase.table('sellers').select(
            'first_name, last_name, shop_name, shop_logo'
        ).eq('seller_id', seller_id).execute()
        
        seller_info = seller_response.data[0] if seller_response.data else None
        print(f"👤 Seller info: {seller_info}")
        
        return render_template('seller/seller_messages.html', seller=seller_info)
        
    except Exception as e:
        print(f"❌ Error loading seller messages: {e}")
        import traceback
        traceback.print_exc()
        return render_template('seller/seller_messages.html', error=str(e))
