from flask import Flask

# Import individual page blueprints
from blueprints.auth import auth_bp
from blueprints.index import index_bp 
from blueprints.browse_product import browse_product_bp
from blueprints.view_item import view_item_bp
from blueprints.cart import cart_bp
from blueprints.favorite import favorite_bp
from blueprints.checkout import checkout_bp
from blueprints.checkout_order import checkout_order_bp
from blueprints.myAccount_profile import myAccount_profile_bp
from blueprints.myAccount_address import myAccount_address_bp
from blueprints.myAccount_changepass import myAccount_changepass_bp
from blueprints.myAccount_purchases import myAccount_purchases_bp
from blueprints.myAccount_notification import myAccount_notification_bp
from blueprints.myAccount_vouchers import myAccount_vouchers_bp
from blueprints.voucher_products import voucher_products_bp
from blueprints.about_us import about_us_bp
from blueprints.references import references_bp

from blueprints.rider_dashboard import rider_dashboard_bp
from blueprints.rider_profile import rider_profile_bp
from blueprints.rider_earnings import rider_earnings_bp
from blueprints.rider_pickup import rider_pickup_bp
from blueprints.rider_activeDelivery import rider_activeDelivery_bp
from blueprints.rider_chat import rider_chat_bp

from blueprints.admin_dashboard import admin_dashboard_bp
from blueprints.admin_rider_payouts import admin_rider_payouts_bp
from blueprints.admin_sales_reports import admin_sales_reports_bp
from blueprints.admin_users_buyers import admin_users_buyers_bp
from blueprints.admin_users_riders import admin_users_riders_bp
from blueprints.admin_users_sellers import admin_users_sellers_bp
from blueprints.admin_vouchers import admin_vouchers_bp

from blueprints.seller_dashboard import seller_dashboard_bp
from blueprints.seller_customer_feedback import seller_customer_feedback_bp
from blueprints.seller_information import seller_information_bp
from blueprints.seller_messages import seller_messages_bp
from blueprints.seller_product_management import seller_product_management_bp
from blueprints.seller_edit_products import seller_edit_products_bp
from blueprints.seller_product_sales import seller_product_sales_bp
from blueprints.seller_select_vouchers import seller_select_vouchers_bp

from blueprints.chat_api import chat_api_bp
from blueprints.view_shop import view_shop_bp
from blueprints.notifications_api import notifications_api_bp

# Report blueprints
from blueprints.buyer_report_user import buyer_report_user_bp
from blueprints.seller_report_user import seller_report_user_bp
from blueprints.rider_report_user import rider_report_user_bp
from blueprints.admin_user_reports import admin_user_reports_bp


app = Flask(__name__)
app.config['SECRET_KEY'] = 'velare-secret-key-2025'  # Change this to a random secret key
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max file upload
app.config['TEMPLATES_AUTO_RELOAD'] = True  # Auto-reload templates
app.config['SEND_FILE_MAX_AGE_DEFAULT'] = 0  # Disable caching

# Initialize Flask-Mail


# Register all individual blueprints
app.register_blueprint(auth_bp)
app.register_blueprint(index_bp)
app.register_blueprint(browse_product_bp)
app.register_blueprint(view_item_bp)
app.register_blueprint(cart_bp)
app.register_blueprint(favorite_bp)
app.register_blueprint(checkout_bp)
app.register_blueprint(checkout_order_bp)
app.register_blueprint(myAccount_profile_bp)
app.register_blueprint(myAccount_address_bp)
app.register_blueprint(myAccount_changepass_bp)
app.register_blueprint(myAccount_purchases_bp)
app.register_blueprint(myAccount_notification_bp)
app.register_blueprint(myAccount_vouchers_bp)
app.register_blueprint(voucher_products_bp)
app.register_blueprint(about_us_bp)
app.register_blueprint(references_bp)

app.register_blueprint(rider_dashboard_bp)
app.register_blueprint(rider_profile_bp)
app.register_blueprint(rider_earnings_bp)
app.register_blueprint(rider_pickup_bp)
app.register_blueprint(rider_activeDelivery_bp)
app.register_blueprint(rider_chat_bp)

app.register_blueprint(admin_dashboard_bp)
app.register_blueprint(admin_rider_payouts_bp)
app.register_blueprint(admin_sales_reports_bp)
app.register_blueprint(admin_users_buyers_bp)
app.register_blueprint(admin_users_riders_bp)
app.register_blueprint(admin_users_sellers_bp)
app.register_blueprint(admin_vouchers_bp)

app.register_blueprint(seller_dashboard_bp)
app.register_blueprint(seller_customer_feedback_bp)
app.register_blueprint(seller_information_bp)
app.register_blueprint(seller_messages_bp)
app.register_blueprint(seller_product_management_bp)
app.register_blueprint(seller_edit_products_bp)
app.register_blueprint(seller_product_sales_bp)
app.register_blueprint(seller_select_vouchers_bp)

app.register_blueprint(chat_api_bp)
app.register_blueprint(view_shop_bp)
app.register_blueprint(notifications_api_bp)

# Register report blueprints
app.register_blueprint(buyer_report_user_bp)
app.register_blueprint(seller_report_user_bp)
app.register_blueprint(rider_report_user_bp)
app.register_blueprint(admin_user_reports_bp)

# Add cache control headers for admin pages to prevent back button access after logout
@app.before_request
def check_user_suspension():
    """Check if logged-in user is suspended or banned and force logout"""
    from flask import session, redirect, url_for, flash, request
    from database.db_config import get_db_connection
    
    # Skip check for static files, login page, and API endpoints
    if request.path.startswith('/static') or \
       request.path == '/login' or \
       request.path == '/register' or \
       request.path == '/' or \
       request.endpoint == 'auth.login_post':
        return None
    
    # Check if user is logged in
    if 'user_id' in session and 'user_type' in session:
        user_id = session['user_id']
        user_type = session['user_type']
        
        # Skip check for admin users
        if user_type == 'admin':
            return None
        
        try:
            connection = get_db_connection()
            if connection:
                cursor = connection.cursor(dictionary=True)
                
                # Check user status
                cursor.execute("SELECT status FROM users WHERE user_id = %s", (user_id,))
                user = cursor.fetchone()
                
                if user and user['status'] in ['suspended', 'banned']:
                    # Get suspension details
                    suspension_end = None
                    suspension_reason = None
                    
                    if user_type == 'buyer':
                        cursor.execute("SELECT suspension_end, suspension_reason FROM buyers WHERE user_id = %s", (user_id,))
                    elif user_type == 'seller':
                        cursor.execute("SELECT suspension_end, suspension_reason FROM sellers WHERE user_id = %s", (user_id,))
                    elif user_type == 'rider':
                        cursor.execute("SELECT suspension_end, suspension_reason FROM riders WHERE user_id = %s", (user_id,))
                    
                    suspension_data = cursor.fetchone()
                    if suspension_data:
                        suspension_end = suspension_data.get('suspension_end')
                        suspension_reason = suspension_data.get('suspension_reason')
                    
                    # Clear session (force logout)
                    session.clear()
                    
                    # Format message
                    if user['status'] == 'suspended' and suspension_end:
                        from datetime import datetime
                        end_date = suspension_end.strftime('%B %d, %Y')
                        message = f'Your account has been suspended until {end_date}.'
                        if suspension_reason:
                            message += f' Reason: {suspension_reason}'
                    elif user['status'] == 'banned':
                        message = 'Your account has been permanently banned.'
                        if suspension_reason:
                            message += f' Reason: {suspension_reason}'
                    else:
                        message = 'Your account has been suspended. Please contact support.'
                    
                    flash(message, 'error')
                    
                    cursor.close()
                    connection.close()
                    
                    return redirect(url_for('auth.login'))
                
                cursor.close()
                connection.close()
        except Exception as e:
            print(f"Error checking user suspension: {e}")
    
    return None

@app.after_request
def add_cache_control_headers(response):
    """Add cache control headers to prevent caching of protected pages"""
    from flask import request
    
    # Check if this is an admin, seller, rider, or buyer page
    if request.path.startswith('/admin') or \
       request.path.startswith('/seller') or \
       request.path.startswith('/rider') or \
       request.path.startswith('/myAccount'):
        response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate, max-age=0'
        response.headers['Pragma'] = 'no-cache'
        response.headers['Expires'] = '0'
    
    return response

if __name__ == '__main__':
    app.run(debug=True)
