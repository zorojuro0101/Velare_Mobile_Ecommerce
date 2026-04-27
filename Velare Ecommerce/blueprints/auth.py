from flask import Blueprint, render_template, request, jsonify, session, current_app
from werkzeug.utils import secure_filename
import os
import sys
import re
import secrets
import string
from datetime import datetime, timedelta
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_config import get_db_connection, close_db_connection, get_supabase_client
from utils.file_manager import save_user_document, allowed_file as check_allowed_file

auth_bp = Blueprint('auth', __name__)

def init_mail(app):
    """Initialize mail configuration (using built-in SMTP, no Flask-Mail needed)"""
    # Store mail config in app config for reference if needed
    app.config['MAIL_SERVER'] = 'smtp.gmail.com'
    app.config['MAIL_PORT'] = 587
    app.config['MAIL_USE_TLS'] = True
    app.config['MAIL_USERNAME'] = 'parokyanigahi21@gmail.com'
    app.config['MAIL_PASSWORD'] = 'ahzyzotndedbxeco'  # App password without spaces
    app.config['MAIL_DEFAULT_SENDER'] = 'parokyanigahi21@gmail.com'
    app.config['MAIL_USE_SSL'] = False
    return None  # No Flask-Mail object needed

def send_reset_email(recipient_email, reset_code):
    """Send password reset email using SMTP directly"""
    try:
        sender_email = 'parokyanigahi21@gmail.com'
        sender_password = 'ahzyzotndedbxeco'  # Remove spaces from app password
        
        print(f"Attempting to send email to: {recipient_email}")
        print(f"Reset code: {reset_code}")
        
        # Create message
        msg = MIMEMultipart('alternative')
        msg['Subject'] = 'Velare - Password Reset Code'
        msg['From'] = sender_email
        msg['To'] = recipient_email
        
        # HTML content
        html_content = f'''
        <html>
            <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
                <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                    <h2 style="color: #4A5568;">Password Reset Request</h2>
                    <p>You requested to reset your password for your Velare account.</p>
                    <p>Your password reset code is:</p>
                    <div style="background-color: #f7fafc; padding: 20px; text-align: center; margin: 20px 0; border-radius: 5px;">
                        <h1 style="color: #2D3748; letter-spacing: 5px; margin: 0;">{reset_code}</h1>
                    </div>
                    <p>This code will expire in <strong>15 minutes</strong>.</p>
                    <p>If you didn't request this, please ignore this email.</p>
                    <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 20px 0;">
                    <p style="color: #718096; font-size: 12px;">This is an automated message from Velare Ecommerce.</p>
                </div>
            </body>
        </html>
        '''
        
        # Plain text version as fallback
        text_content = f'''
        Password Reset Request
        
        You requested to reset your password for your Velare account.
        
        Your password reset code is: {reset_code}
        
        This code will expire in 15 minutes.
        
        If you didn't request this, please ignore this email.
        '''
        
        # Attach both plain text and HTML
        text_part = MIMEText(text_content, 'plain')
        html_part = MIMEText(html_content, 'html')
        msg.attach(text_part)
        msg.attach(html_part)
        
        # Send email using SMTP with detailed error handling
        print("Connecting to Gmail SMTP server...")
        server = smtplib.SMTP('smtp.gmail.com', 587, timeout=10)
        server.set_debuglevel(1)  # Enable debug output
        
        print("Starting TLS...")
        server.starttls()
        
        print("Logging in...")
        server.login(sender_email, sender_password)
        
        print("Sending message...")
        server.send_message(msg)
        
        print("Closing connection...")
        server.quit()
        
        print("Email sent successfully!")
        return True
        
    except smtplib.SMTPAuthenticationError as e:
        print("\n" + "="*60)
        print("❌ GMAIL AUTHENTICATION FAILED!")
        print("="*60)
        print(f"Error: {str(e)}")
        print("\n🔧 SOLUTION:")
        print("1. Go to: https://myaccount.google.com/security")
        print("2. Enable '2-Step Verification'")
        print("3. Go to: https://myaccount.google.com/apppasswords")
        print("4. Create App Password for 'Mail' app")
        print("5. Copy the 16-character password (remove spaces)")
        print("6. Update line 40 in auth.py with new password")
        print("="*60 + "\n")
        return False
    except smtplib.SMTPException as e:
        print("\n" + "="*60)
        print("❌ SMTP ERROR!")
        print("="*60)
        print(f"Error: {str(e)}")
        print("="*60 + "\n")
        return False
    except Exception as e:
        print("\n" + "="*60)
        print("❌ EMAIL SENDING ERROR!")
        print("="*60)
        print(f"Error Type: {type(e).__name__}")
        print(f"Error Message: {str(e)}")
        print("\n📋 Full Error Details:")
        import traceback
        traceback.print_exc()
        print("="*60 + "\n")
        return False

# Configuration for file uploads (kept for backward compatibility with buyer registration)
UPLOAD_FOLDER = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'static', 'uploads', 'ids')
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'pdf'}

# Create upload folder if it doesn't exist
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

def allowed_file(filename):
    """Check if file extension is allowed (local function for buyer registration)"""
    return check_allowed_file(filename, ALLOWED_EXTENSIONS)

def validate_password(password):
    """Validate password requirements"""
    errors = []
    
    if len(password) < 6:
        errors.append('Password must be at least 6 characters long')
    
    if not re.search(r'[A-Z]', password):
        errors.append('Password must contain at least one uppercase letter')
    
    if not re.search(r'[a-z]', password):
        errors.append('Password must contain at least one lowercase letter')
    
    if not re.search(r'\d', password):
        errors.append('Password must contain at least one number')
    
    return errors

def validate_email(email):
    """Validate email format"""
    email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return re.match(email_pattern, email) is not None

def save_address(cursor, user_type, user_ref_id, form_data, prefix):
    """Save address data to addresses table (MySQL version)"""
    try:
        # Get address data from form
        phone_number = form_data.get(f'{prefix}_phone_number', '').strip()
        region = form_data.get(f'{prefix}_region', '').strip()
        province = form_data.get(f'{prefix}_province', '').strip()
        city = form_data.get(f'{prefix}_city', '').strip()
        barangay = form_data.get(f'{prefix}_barangay', '').strip()
        street_name = form_data.get(f'{prefix}_street', '').strip()
        house_number = form_data.get(f'{prefix}_house_number', '').strip()
        postal_code = form_data.get(f'{prefix}_postal_code', '').strip()
        
        # Build full address string
        address_parts = [house_number, street_name, barangay, city, province, region]
        full_address = ', '.join([part for part in address_parts if part])
        
        # Get recipient name from first and last name
        first_name = form_data.get(f'{prefix}_first_name', '').strip()
        last_name = form_data.get(f'{prefix}_last_name', '').strip()
        recipient_name = f"{first_name} {last_name}"
        
        # Insert address
        cursor.execute("""
            INSERT INTO addresses 
            (user_type, user_ref_id, recipient_name, phone_number, full_address, 
             region, province, city, barangay, street_name, house_number, postal_code, is_default)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, TRUE)
        """, (user_type, user_ref_id, recipient_name, phone_number, full_address,
              region, province, city, barangay, street_name, house_number, postal_code))
        
        return True
    except Exception as e:
        print(f"Error saving address: {e}")
        return False

def save_address_supabase(supabase, user_type, user_ref_id, form_data, prefix):
    """Save address data to addresses table (Supabase version)"""
    try:
        from datetime import datetime
        
        # Get address data from form
        phone_number = form_data.get(f'{prefix}_phone_number', '').strip()
        region = form_data.get(f'{prefix}_region', '').strip()
        province = form_data.get(f'{prefix}_province', '').strip()
        city = form_data.get(f'{prefix}_city', '').strip()
        barangay = form_data.get(f'{prefix}_barangay', '').strip()
        street_name = form_data.get(f'{prefix}_street', '').strip()
        house_number = form_data.get(f'{prefix}_house_number', '').strip()
        postal_code = form_data.get(f'{prefix}_postal_code', '').strip()
        
        # Build full address string
        address_parts = [house_number, street_name, barangay, city, province, region]
        full_address = ', '.join([part for part in address_parts if part])
        
        # Get recipient name from first and last name
        first_name = form_data.get(f'{prefix}_first_name', '').strip()
        last_name = form_data.get(f'{prefix}_last_name', '').strip()
        recipient_name = f"{first_name} {last_name}"
        
        # Insert address
        address_data = {
            'user_type': user_type,
            'user_ref_id': user_ref_id,
            'recipient_name': recipient_name,
            'phone_number': phone_number,
            'full_address': full_address,
            'region': region,
            'province': province,
            'city': city,
            'barangay': barangay,
            'street_name': street_name,
            'house_number': house_number,
            'postal_code': postal_code,
            'is_default': True,
            'created_at': datetime.now().isoformat()
        }
        
        supabase.table('addresses').insert(address_data).execute()
        return True
    except Exception as e:
        print(f"Error saving address: {e}")
        return False

@auth_bp.route('/login')
def login():
    return render_template('login.html')

@auth_bp.route('/api/featured-products')
def get_featured_products():
    """Get best seller and best rating products for login/register slideshow using Supabase"""
    try:
        supabase = get_supabase_client()
        if not supabase:
            print("❌ Supabase connection failed")
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            print("\n🔍 Fetching featured products from Supabase...")
            
            # Get products with images (best sellers)
            response = supabase.table('products').select(
                'product_id, product_name, category, total_sold, product_images(image_url, is_primary)'
            ).eq('is_active', True).order('total_sold', desc=True).limit(10).execute()
            
            featured_products = []
            seen = set()
            
            for product in response.data:
                if product['product_id'] not in seen and product.get('product_images'):
                    # Find primary image or use first image
                    image_url = None
                    for img in product['product_images']:
                        if img.get('is_primary'):
                            image_url = img['image_url']
                            break
                    if not image_url and product['product_images']:
                        image_url = product['product_images'][0]['image_url']
                    
                    if image_url:
                        seen.add(product['product_id'])
                        featured_products.append({
                            'product_id': product['product_id'],
                            'product_name': product['product_name'],
                            'image_path': image_url
                        })
                
                if len(featured_products) >= 5:
                    break
            
            print(f"🎯 Returning {len(featured_products)} products from Supabase\n")
            
            return jsonify({
                'success': True,
                'products': featured_products
            }), 200
            
        except Exception as e:
            print(f"❌ Error fetching featured products: {e}")
            import traceback
            traceback.print_exc()
            return jsonify({'success': False, 'message': str(e)}), 500
            
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': str(e)}), 500

@auth_bp.route('/login', methods=['POST'])
def login_post():
    """Handle user login using Supabase"""
    try:
        # Get form data
        email = request.form.get('email', '').strip().lower()
        password = request.form.get('password', '')
        
        # Validate required fields
        if not all([email, password]):
            return jsonify({'success': False, 'message': 'Email and password are required'}), 400
        
        # Validate email format
        if not validate_email(email):
            return jsonify({'success': False, 'message': 'Invalid email format'}), 400
        
        # Connect to Supabase
        supabase = get_supabase_client()
        if not supabase:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Check if user exists in Supabase
            response = supabase.table('users').select('*').eq('email', email).execute()
            
            if not response.data or len(response.data) == 0:
                return jsonify({'success': False, 'message': 'Invalid email or password'}), 401
            
            user = response.data[0]
            
            # Check password (plain text comparison)
            if user['password'] != password:
                return jsonify({'success': False, 'message': 'Invalid email or password'}), 401
            
            # Check user status - only 'active' users can login
            if user['status'] != 'active':
                if user['status'] == 'pending':
                    return jsonify({
                        'success': False, 
                        'message': 'Your account is pending approval. Please wait for admin verification.'
                    }), 403
                elif user['status'] == 'suspended':
                    return jsonify({
                        'success': False, 
                        'message': 'Your account has been suspended. Please contact support.'
                    }), 403
                elif user['status'] == 'banned':
                    return jsonify({
                        'success': False, 
                        'message': 'Your account has been permanently banned.'
                    }), 403
                else:
                    return jsonify({
                        'success': False, 
                        'message': 'Your account is not active. Please contact support.'
                    }), 403
            
            # Get user's name and type-specific ID based on user type
            user_name = ''
            if user['user_type'] == 'buyer':
                buyer_response = supabase.table('buyers').select('*').eq('user_id', user['user_id']).execute()
                if buyer_response.data:
                    buyer_data = buyer_response.data[0]
                    user_name = f"{buyer_data['first_name']} {buyer_data['last_name']}"
                    session['buyer_id'] = buyer_data['buyer_id']
            elif user['user_type'] == 'seller':
                seller_response = supabase.table('sellers').select('*').eq('user_id', user['user_id']).execute()
                if seller_response.data:
                    seller_data = seller_response.data[0]
                    user_name = seller_data.get('shop_name', f"{seller_data.get('first_name', '')} {seller_data.get('last_name', '')}")
                    session['seller_id'] = seller_data['seller_id']
            elif user['user_type'] == 'rider':
                rider_response = supabase.table('riders').select('*').eq('user_id', user['user_id']).execute()
                if rider_response.data:
                    rider_data = rider_response.data[0]
                    user_name = f"{rider_data['first_name']} {rider_data['last_name']}"
                    session['rider_id'] = rider_data['rider_id']
            elif user['user_type'] == 'admin':
                user_name = 'Admin'
            
            # Update last login in Supabase
            from datetime import datetime
            supabase.table('users').update({
                'last_login': datetime.now().isoformat()
            }).eq('user_id', user['user_id']).execute()
            
            # Store user info in session
            session['user_id'] = user['user_id']
            session['email'] = user['email']
            session['user_type'] = user['user_type']
            session['logged_in'] = True
            
            # Determine redirect based on user type
            redirect_urls = {
                'buyer': '/',
                'seller': '/seller/dashboard',
                'rider': '/rider/dashboard',
                'admin': '/admin/dashboard'
            }
            
            redirect_url = redirect_urls.get(user['user_type'], '/')
            
            return jsonify({
                'success': True,
                'message': f'Welcome back, {user_name}!',
                'redirect': redirect_url,
                'user_type': user['user_type']
            }), 200
            
        except Exception as e:
            print(f"❌ Login error: {e}")
            import traceback
            traceback.print_exc()
            return jsonify({'success': False, 'message': 'Login failed. Please try again.'}), 500
            
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return jsonify({'success': False, 'message': 'An unexpected error occurred. Please try again.'}), 500
            
    except Exception as e:
        return jsonify({'success': False, 'message': 'An unexpected error occurred. Please try again.'}), 500

@auth_bp.route('/register')
def register():
    return render_template('register.html')

@auth_bp.route('/register/buyer', methods=['POST'])
def register_buyer():
    """Handle buyer registration using Supabase"""
    try:
        # Get form data
        first_name = request.form.get('buyer_first_name', '').strip()
        last_name = request.form.get('buyer_last_name', '').strip()
        email = request.form.get('buyer_email', '').strip().lower()
        password = request.form.get('buyer_password', '')
        id_type = request.form.get('buyer_id_type', '').strip()
        
        # Validate required fields
        if not all([first_name, last_name, email, password, id_type]):
            return jsonify({'success': False, 'message': 'All fields are required'}), 400
        
        # Validate name fields
        if len(first_name) < 2 or len(last_name) < 2:
            return jsonify({'success': False, 'message': 'First name and last name must be at least 2 characters'}), 400
        
        # Validate email format
        if not validate_email(email):
            return jsonify({'success': False, 'message': 'Invalid email format'}), 400
        
        # Validate password
        password_errors = validate_password(password)
        if password_errors:
            return jsonify({'success': False, 'message': password_errors[0]}), 400
        
        # Handle file upload
        id_file_path = None
        if 'buyer_id_upload' not in request.files:
            return jsonify({'success': False, 'message': 'ID upload is required'}), 400
        
        file = request.files['buyer_id_upload']
        if not file or not file.filename:
            return jsonify({'success': False, 'message': 'Please select a valid ID file'}), 400
        
        if not allowed_file(file.filename):
            return jsonify({'success': False, 'message': 'Invalid file type. Only PNG, JPG, JPEG, and PDF are allowed'}), 400
        
        try:
            filename = secure_filename(f"buyer_{email.replace('@', '_')}_{file.filename}")
            file_path = os.path.join(UPLOAD_FOLDER, filename)
            file.save(file_path)
            id_file_path = f"/static/uploads/ids/{filename}"
        except Exception as e:
            return jsonify({'success': False, 'message': 'Failed to upload ID file. Please try again.'}), 500
        
        # Connect to Supabase
        supabase = get_supabase_client()
        if not supabase:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Check if email already exists
            existing_user = supabase.table('users').select('user_id').eq('email', email).execute()
            if existing_user.data:
                return jsonify({'success': False, 'message': 'Email already registered'}), 400
            
            # Insert into users table with PENDING status
            from datetime import datetime
            user_data = {
                'email': email,
                'password': password,
                'user_type': 'buyer',
                'status': 'pending',
                'created_at': datetime.now().isoformat()
            }
            
            user_response = supabase.table('users').insert(user_data).execute()
            
            if not user_response.data:
                return jsonify({'success': False, 'message': 'Registration failed. Please try again.'}), 500
            
            user_id = user_response.data[0]['user_id']
            
            # Insert into buyers table with ID info
            buyer_data = {
                'user_id': user_id,
                'first_name': first_name,
                'last_name': last_name,
                'id_type': id_type,
                'id_file_path': id_file_path,
                'created_at': datetime.now().isoformat()
            }
            
            buyer_response = supabase.table('buyers').insert(buyer_data).execute()
            
            if not buyer_response.data:
                # Rollback: delete user if buyer creation fails
                supabase.table('users').delete().eq('user_id', user_id).execute()
                return jsonify({'success': False, 'message': 'Registration failed. Please try again.'}), 500
            
            buyer_id = buyer_response.data[0]['buyer_id']
            
            # Assign welcome vouchers to new buyer (if vouchers exist)
            try:
                vouchers = supabase.table('vouchers').select('voucher_id').in_('voucher_code', ['FREESHIP', 'DISCOUNT20']).execute()
                if vouchers.data:
                    for voucher in vouchers.data:
                        supabase.table('buyer_vouchers').insert({
                            'buyer_id': buyer_id,
                            'voucher_id': voucher['voucher_id'],
                            'is_used': False,
                            'claimed_at': datetime.now().isoformat()
                        }).execute()
            except Exception as e:
                print(f"Warning: Could not assign welcome vouchers: {e}")
            
            # Save address
            save_address_supabase(supabase, 'buyer', buyer_id, request.form, 'buyer')
            
            return jsonify({
                'success': True, 
                'message': 'Buyer registration successful! Your account is pending approval.',
                'redirect': '/login'
            }), 201
            
        except Exception as e:
            print(f"❌ Registration error: {e}")
            import traceback
            traceback.print_exc()
            return jsonify({'success': False, 'message': 'Registration failed. Please try again.'}), 500
            
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': 'An unexpected error occurred. Please try again.'}), 500

@auth_bp.route('/register/seller', methods=['POST'])
def register_seller():
    """Handle seller registration"""
    try:
        # Get form data
        first_name = request.form.get('seller_first_name', '').strip()
        last_name = request.form.get('seller_last_name', '').strip()
        email = request.form.get('seller_email', '').strip().lower()
        password = request.form.get('seller_password', '')
        id_type = request.form.get('seller_id_type', '').strip()
        
        # Validate required fields
        if not all([first_name, last_name, email, password, id_type]):
            return jsonify({'success': False, 'message': 'All fields are required'}), 400
        
        # Validate name fields
        if len(first_name) < 2 or len(last_name) < 2:
            return jsonify({'success': False, 'message': 'First name and last name must be at least 2 characters'}), 400
        
        # Validate email format
        if not validate_email(email):
            return jsonify({'success': False, 'message': 'Invalid email format'}), 400
        
        # Validate password
        password_errors = validate_password(password)
        if password_errors:
            return jsonify({'success': False, 'message': password_errors[0]}), 400
        
        # Handle ID file upload - temporarily save to get user_id first
        id_file = None
        business_permit_file = None
        
        if 'seller_id_upload' not in request.files:
            return jsonify({'success': False, 'message': 'ID upload is required'}), 400
        
        id_file = request.files['seller_id_upload']
        if not id_file or not id_file.filename:
            return jsonify({'success': False, 'message': 'Please select a valid ID file'}), 400
        
        if not allowed_file(id_file.filename):
            return jsonify({'success': False, 'message': 'Invalid file type. Only PNG, JPG, JPEG, and PDF are allowed'}), 400
        
        # Handle business permit file upload
        if 'seller_business_permit_upload' not in request.files:
            return jsonify({'success': False, 'message': 'Business permit upload is required'}), 400
        
        business_permit_file = request.files['seller_business_permit_upload']
        if not business_permit_file or not business_permit_file.filename:
            return jsonify({'success': False, 'message': 'Please select a valid business permit file'}), 400
        
        if not allowed_file(business_permit_file.filename):
            return jsonify({'success': False, 'message': 'Invalid file type. Only PNG, JPG, JPEG, and PDF are allowed'}), 400
        
        # Connect to database
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor()
        
        try:
            # Check if email already exists
            cursor.execute("SELECT user_id FROM users WHERE email = %s", (email,))
            if cursor.fetchone():
                return jsonify({'success': False, 'message': 'Email already registered'}), 400
            
            # Insert into users table with PENDING status
            cursor.execute(
                "INSERT INTO users (email, password, user_type, status) VALUES (%s, %s, 'seller', 'pending')",
                (email, password)
            )
            user_id = cursor.lastrowid
            
            # Create shop name from first and last name
            shop_name = f"{first_name} {last_name}'s Shop"
            
            # Insert into sellers table first to get seller_id
            cursor.execute(
                "INSERT INTO sellers (user_id, first_name, last_name, shop_name, id_type) VALUES (%s, %s, %s, %s, %s)",
                (user_id, first_name, last_name, shop_name, id_type)
            )
            seller_id = cursor.lastrowid
            
            # Now save files with organized structure using seller_id
            success, id_file_path, error = save_user_document(id_file, 'seller', seller_id, 'id', id_file.filename)
            if not success:
                connection.rollback()
                return jsonify({'success': False, 'message': f'Failed to upload ID: {error}'}), 500
            
            success, business_permit_file_path, error = save_user_document(business_permit_file, 'seller', seller_id, 'business_permit', business_permit_file.filename)
            if not success:
                connection.rollback()
                return jsonify({'success': False, 'message': f'Failed to upload business permit: {error}'}), 500
            
            # Update seller with file paths
            cursor.execute(
                "UPDATE sellers SET id_file_path = %s, business_permit_file_path = %s WHERE seller_id = %s",
                (id_file_path, business_permit_file_path, seller_id)
            )
            
            # Save address
            save_address(cursor, 'seller', seller_id, request.form, 'seller')
            
            connection.commit()
            
            return jsonify({
                'success': True, 
                'message': 'Seller registration successful! Your account is pending approval.',
                'redirect': '/login'
            }), 201
            
        except Exception as e:
            connection.rollback()
            error_msg = str(e)
            if 'Duplicate entry' in error_msg:
                return jsonify({'success': False, 'message': 'Email already registered'}), 400
            return jsonify({'success': False, 'message': 'Registration failed. Please try again.'}), 500
        
        finally:
            close_db_connection(connection, cursor)
            
    except Exception as e:
        return jsonify({'success': False, 'message': 'An unexpected error occurred. Please try again.'}), 500

@auth_bp.route('/register/rider', methods=['POST'])
def register_rider():
    """Handle rider registration"""
    try:
        # Get form data
        first_name = request.form.get('rider_first_name', '').strip()
        last_name = request.form.get('rider_last_name', '').strip()
        email = request.form.get('rider_email', '').strip().lower()
        password = request.form.get('rider_password', '')
        id_type = request.form.get('rider_id_type', '').strip()
        
        # Validate required fields
        if not all([first_name, last_name, email, password, id_type]):
            return jsonify({'success': False, 'message': 'All fields are required'}), 400
        
        # Validate name fields
        if len(first_name) < 2 or len(last_name) < 2:
            return jsonify({'success': False, 'message': 'First name and last name must be at least 2 characters'}), 400
        
        # Validate email format
        if not validate_email(email):
            return jsonify({'success': False, 'message': 'Invalid email format'}), 400
        
        # Validate password
        password_errors = validate_password(password)
        if password_errors:
            return jsonify({'success': False, 'message': password_errors[0]}), 400
        
        # Get vehicle type and plate number
        vehicle_type = request.form.get('rider_vehicle_type', '').strip()
        plate_number = request.form.get('rider_plate_number', '').strip()
        
        # Validate vehicle and plate
        if not vehicle_type or not plate_number:
            return jsonify({'success': False, 'message': 'Vehicle type and plate number are required'}), 400
        
        # Handle ORCR file upload - temporarily hold files
        orcr_file = None
        driver_license_file = None
        
        if 'rider_orcr_upload' not in request.files:
            return jsonify({'success': False, 'message': 'ORCR upload is required'}), 400
        
        orcr_file = request.files['rider_orcr_upload']
        if not orcr_file or not orcr_file.filename:
            return jsonify({'success': False, 'message': 'Please select a valid ORCR file'}), 400
        
        if not allowed_file(orcr_file.filename):
            return jsonify({'success': False, 'message': 'Invalid file type. Only PNG, JPG, JPEG, and PDF are allowed'}), 400
        
        # Handle Driver License file upload
        if 'rider_driver_license_upload' not in request.files:
            return jsonify({'success': False, 'message': 'Driver License upload is required'}), 400
        
        driver_license_file = request.files['rider_driver_license_upload']
        if not driver_license_file or not driver_license_file.filename:
            return jsonify({'success': False, 'message': 'Please select a valid Driver License file'}), 400
        
        if not allowed_file(driver_license_file.filename):
            return jsonify({'success': False, 'message': 'Invalid file type. Only PNG, JPG, JPEG, and PDF are allowed'}), 400
        
        # Connect to database
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor()
        
        try:
            # Check if email already exists
            cursor.execute("SELECT user_id FROM users WHERE email = %s", (email,))
            if cursor.fetchone():
                return jsonify({'success': False, 'message': 'Email already registered'}), 400
            
            # Insert into users table with PENDING status
            cursor.execute(
                "INSERT INTO users (email, password, user_type, status) VALUES (%s, %s, 'rider', 'pending')",
                (email, password)
            )
            user_id = cursor.lastrowid
            
            # Get phone number from address form
            phone_number = request.form.get('rider_phone_number', 'N/A').strip()
            
            # Insert into riders table first to get rider_id
            cursor.execute(
                "INSERT INTO riders (user_id, first_name, last_name, phone_number, vehicle_type, plate_number) VALUES (%s, %s, %s, %s, %s, %s)",
                (user_id, first_name, last_name, phone_number, vehicle_type, plate_number)
            )
            rider_id = cursor.lastrowid
            
            # Now save files with organized structure using rider_id
            success, orcr_file_path, error = save_user_document(orcr_file, 'rider', rider_id, 'orcr', orcr_file.filename)
            if not success:
                connection.rollback()
                return jsonify({'success': False, 'message': f'Failed to upload ORCR: {error}'}), 500
            
            success, driver_license_file_path, error = save_user_document(driver_license_file, 'rider', rider_id, 'driver_license', driver_license_file.filename)
            if not success:
                connection.rollback()
                return jsonify({'success': False, 'message': f'Failed to upload Driver License: {error}'}), 500
            
            # Update rider with file paths
            cursor.execute(
                "UPDATE riders SET orcr_file_path = %s, driver_license_file_path = %s WHERE rider_id = %s",
                (orcr_file_path, driver_license_file_path, rider_id)
            )
            
            # Save address
            save_address(cursor, 'rider', rider_id, request.form, 'rider')
            
            connection.commit()
            
            return jsonify({
                'success': True, 
                'message': 'Rider registration successful! Your account is pending approval.',
                'redirect': '/login'
            }), 201
            
        except Exception as e:
            connection.rollback()
            error_msg = str(e)
            if 'Duplicate entry' in error_msg:
                return jsonify({'success': False, 'message': 'Email already registered'}), 400
            return jsonify({'success': False, 'message': 'Registration failed. Please try again.'}), 500
        
        finally:
            close_db_connection(connection, cursor)
            
    except Exception as e:
        return jsonify({'success': False, 'message': 'An unexpected error occurred. Please try again.'}), 500

@auth_bp.route('/logout')
def logout():
    """Handle user logout and clear session"""
    try:
        # Clear all session data
        session.clear()
        
        # Return success response with cache control headers
        response = jsonify({
            'success': True,
            'message': 'Logged out successfully',
            'redirect': '/login'
        })
        
        # Add cache control headers to prevent back button access
        response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate, post-check=0, pre-check=0'
        response.headers['Pragma'] = 'no-cache'
        response.headers['Expires'] = '0'
        
        return response, 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'message': 'Logout failed',
            'redirect': '/login'
        }), 500

@auth_bp.route('/clear_session')
def clear_session():
    """Clear session for testing - redirects to index as guest"""
    from flask import redirect, url_for
    session.clear()
    return redirect('/')

@auth_bp.route('/forgot_password')
def forgot_password():
    return render_template('forgot_password.html')

@auth_bp.route('/forgot_password', methods=['POST'])
def forgot_password_post():
    """Handle forgot password request"""
    try:
        email = request.form.get('email', '').strip().lower()
        
        if not email:
            return jsonify({'success': False, 'message': 'Email is required'}), 400
        
        if not validate_email(email):
            return jsonify({'success': False, 'message': 'Invalid email format'}), 400
        
        # Connect to database
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            # Check if user exists
            cursor.execute("SELECT user_id, email FROM users WHERE email = %s", (email,))
            user = cursor.fetchone()
            
            if not user:
                # Don't reveal if email exists or not for security
                return jsonify({
                    'success': True,
                    'message': 'If this email exists, a reset code has been sent.'
                }), 200
            
            # Generate 6-digit reset code
            reset_code = ''.join(secrets.choice(string.digits) for _ in range(6))
            
            # Set expiry to 15 minutes from now
            expiry_time = datetime.now() + timedelta(minutes=15)
            
            # Store reset token in database
            cursor.execute(
                "UPDATE users SET reset_token = %s, reset_token_expiry = %s WHERE user_id = %s",
                (reset_code, expiry_time, user['user_id'])
            )
            connection.commit()
            
            # Send email with reset code
            email_sent = send_reset_email(email, reset_code)
            
            if not email_sent:
                # Rollback the reset token since email failed
                cursor.execute(
                    "UPDATE users SET reset_token = NULL, reset_token_expiry = NULL WHERE user_id = %s",
                    (user['user_id'],)
                )
                connection.commit()
                
                return jsonify({
                    'success': False,
                    'message': 'Failed to send reset email. Please check the console for Gmail authentication instructions.'
                }), 500
            
            return jsonify({
                'success': True,
                'message': 'Reset code sent to your email!',
                'redirect': f'/reset_password?email={email}'
            }), 200
            
        except Exception as e:
            connection.rollback()
            return jsonify({'success': False, 'message': 'Failed to process request. Please try again.'}), 500
        
        finally:
            close_db_connection(connection, cursor)
            
    except Exception as e:
        return jsonify({'success': False, 'message': 'An unexpected error occurred. Please try again.'}), 500

@auth_bp.route('/reset_password')
def reset_password():
    email = request.args.get('email', '')
    return render_template('reset_password.html', email=email)

@auth_bp.route('/reset_password', methods=['POST'])
def reset_password_post():
    """Handle password reset with code"""
    try:
        email = request.form.get('email', '').strip().lower()
        reset_code = request.form.get('reset_code', '').strip()
        new_password = request.form.get('new_password', '')
        confirm_password = request.form.get('confirm_password', '')
        
        # Validate required fields
        if not all([email, reset_code, new_password, confirm_password]):
            return jsonify({'success': False, 'message': 'All fields are required'}), 400
        
        # Validate email format
        if not validate_email(email):
            return jsonify({'success': False, 'message': 'Invalid email format'}), 400
        
        # Check if passwords match
        if new_password != confirm_password:
            return jsonify({'success': False, 'message': 'Passwords do not match'}), 400
        
        # Validate password
        password_errors = validate_password(new_password)
        if password_errors:
            return jsonify({'success': False, 'message': password_errors[0]}), 400
        
        # Connect to database
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            # Get user with reset token
            cursor.execute(
                "SELECT user_id, reset_token, reset_token_expiry FROM users WHERE email = %s",
                (email,)
            )
            user = cursor.fetchone()
            
            if not user:
                return jsonify({'success': False, 'message': 'Invalid email'}), 400
            
            if not user['reset_token']:
                return jsonify({'success': False, 'message': 'No reset code requested for this email'}), 400
            
            # Check if token matches
            if user['reset_token'] != reset_code:
                return jsonify({'success': False, 'message': 'Invalid reset code'}), 400
            
            # Check if token is expired
            if user['reset_token_expiry'] < datetime.now():
                return jsonify({'success': False, 'message': 'Reset code has expired. Please request a new one.'}), 400
            
            # Update password and clear reset token
            cursor.execute(
                "UPDATE users SET password = %s, reset_token = NULL, reset_token_expiry = NULL WHERE user_id = %s",
                (new_password, user['user_id'])
            )
            connection.commit()
            
            return jsonify({
                'success': True,
                'message': 'Password reset successful! You can now login with your new password.',
                'redirect': '/login'
            }), 200
            
        except Exception as e:
            connection.rollback()
            return jsonify({'success': False, 'message': 'Failed to reset password. Please try again.'}), 500
        
        finally:
            close_db_connection(connection, cursor)
            
    except Exception as e:
        return jsonify({'success': False, 'message': 'An unexpected error occurred. Please try again.'}), 500
