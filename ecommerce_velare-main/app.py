from flask import Flask
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

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
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'velare-secret-key-2025')
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max file upload
app.config['TEMPLATES_AUTO_RELOAD'] = os.environ.get('FLASK_ENV') != 'production'
app.config['SEND_FILE_MAX_AGE_DEFAULT'] = 0 if os.environ.get('FLASK_ENV') != 'production' else 31536000

# Session configuration for production (Railway)
app.config['SESSION_COOKIE_SECURE'] = os.environ.get('FLASK_ENV') == 'production'  # HTTPS only in production
app.config['SESSION_COOKIE_HTTPONLY'] = True  # Prevent JavaScript access
app.config['SESSION_COOKIE_SAMESITE'] = 'Lax'  # CSRF protection
app.config['PERMANENT_SESSION_LIFETIME'] = 86400  # 24 hours
app.config['SESSION_COOKIE_NAME'] = 'velare_session'
# NOTE: SEND_FILE_MAX_AGE_DEFAULT is configured above based on FLASK_ENV.
# Static assets (CSS/JS/images) get a 1-year cache in production and 0 in dev.
# Protected HTML pages still get explicit no-cache headers via add_cache_control_headers
# below, so we don't need to disable static caching globally.

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
# Register seller_edit_products_bp BEFORE seller_product_management_bp
# so its routes (/api/products/<id> GET/PUT) take precedence
app.register_blueprint(seller_edit_products_bp)
app.register_blueprint(seller_product_management_bp)
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
# How long to trust a cached "active" status before re-checking with Supabase.
# Suspensions/bans need to be enforced quickly but we don't want to query the
# DB on every single tab navigation.
SUSPENSION_CHECK_CACHE_SECONDS = 60


@app.before_request
def check_user_suspension():
    """Check if logged-in user is suspended or banned and force logout.

    Optimized: results are cached in the session for SUSPENSION_CHECK_CACHE_SECONDS
    so a normal user pays the Supabase round-trip at most once per minute instead
    of once per tab switch. Active users also exit before issuing the second
    suspension-details query.
    """
    from flask import session, redirect, url_for, flash, request
    from database.db_config import get_supabase_client
    import time

    # Skip check for static files, login/register, root, the login POST endpoint,
    # the logout endpoint, the health endpoint (called by Docker/Railway probes),
    # and the favicon.
    path = request.path
    if (path.startswith('/static') or
            path == '/login' or
            path == '/register' or
            path == '/' or
            path == '/health' or
            path == '/favicon.ico' or
            request.endpoint in ('auth.login_post', 'auth.logout')):
        return None

    if 'user_id' not in session or 'user_type' not in session:
        return None

    user_type = session['user_type']

    # Admins are not subject to suspension checks.
    if user_type == 'admin':
        return None

    # Use a per-session cache so we don't hit Supabase on every navigation.
    now = time.time()
    cached_at = session.get('_status_checked_at', 0)
    if now - cached_at < SUSPENSION_CHECK_CACHE_SECONDS:
        return None

    user_id = session['user_id']

    try:
        supabase = get_supabase_client()
        if not supabase:
            return None

        user_response = supabase.table('users').select('status').eq('user_id', user_id).execute()

        if not user_response.data:
            # User row missing — refresh cache and let downstream handlers decide.
            session['_status_checked_at'] = now
            return None

        status = user_response.data[0].get('status')

        # Happy path: user is active, refresh cache and skip the second query.
        if status not in ('suspended', 'banned'):
            session['_status_checked_at'] = now
            return None

        # Suspended/banned path. Fetch reason + end date from the role table.
        suspension_end = None
        suspension_reason = None

        role_table = {
            'buyer': 'buyers',
            'seller': 'sellers',
            'rider': 'riders',
        }.get(user_type)

        if role_table:
            suspension_response = supabase.table(role_table).select(
                'suspension_end, suspension_reason'
            ).eq('user_id', user_id).execute()
            if suspension_response.data:
                suspension_data = suspension_response.data[0]
                suspension_end = suspension_data.get('suspension_end')
                suspension_reason = suspension_data.get('suspension_reason')

        # Force logout.
        session.clear()

        # Format the flash message exactly as before.
        if status == 'suspended' and suspension_end:
            from datetime import datetime
            end_date_obj = datetime.fromisoformat(suspension_end.replace('Z', '+00:00'))
            end_date = end_date_obj.strftime('%B %d, %Y')
            message = f'Your account has been suspended until {end_date}.'
            if suspension_reason:
                message += f' Reason: {suspension_reason}'
        elif status == 'banned':
            message = 'Your account has been permanently banned.'
            if suspension_reason:
                message += f' Reason: {suspension_reason}'
        else:
            message = 'Your account has been suspended. Please contact support.'

        flash(message, 'error')
        return redirect(url_for('auth.login'))

    except Exception as e:
        print(f"❌ Error checking user suspension: {e}")

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


# Lightweight health check used by Docker, docker-compose, and Railway. Must
# be cheap and not touch external services so a transient Supabase outage
# doesn't make the container restart in a loop.
@app.route('/health')
def health_check():
    from flask import jsonify
    return jsonify({'status': 'ok'}), 200


if __name__ == '__main__':
    import os
    port = int(os.environ.get('PORT', 5000))
    debug = os.environ.get('FLASK_ENV') != 'production'
    app.run(host='0.0.0.0', port=port, debug=debug)
