from flask import Blueprint, render_template, request, jsonify, session
from werkzeug.utils import secure_filename
import os
import sys

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_config import get_db_connection, close_db_connection
from utils.auth_decorators import seller_required
from utils.file_manager import save_user_document, allowed_file as file_allowed

seller_information_bp = Blueprint('seller_information', __name__)

# Configure upload folder
UPLOAD_FOLDER = 'static/uploads/shop_logos'  # Full path for saving
UPLOAD_FOLDER_DB = 'uploads/shop_logos'  # Path for database (without 'static/' - url_for adds it)
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif', 'webp'}

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@seller_information_bp.route('/seller/information')
@seller_required
def seller_information():
    """Display seller information page"""
    try:
        seller_id = session.get('seller_id')  # Guaranteed to exist due to @seller_required
        
        connection = get_db_connection()
        if not connection:
            return render_template('seller/seller_information.html', error='Database connection failed')
        
        cursor = connection.cursor(dictionary=True)
        
        # Get seller information including ID and business permit
        cursor.execute("""
            SELECT first_name, last_name, shop_name, shop_description, shop_logo, phone_number,
                   id_file_path, id_type, business_permit_file_path
            FROM sellers
            WHERE seller_id = %s
        """, (seller_id,))
        
        seller_data = cursor.fetchone()
        
        # Get seller address from addresses table
        cursor.execute("""
            SELECT recipient_name, phone_number, full_address, region, province, city, 
                   barangay, street_name, house_number, postal_code, is_default
            FROM addresses
            WHERE user_type = 'seller' AND user_ref_id = %s
            ORDER BY is_default DESC, created_at DESC
            LIMIT 1
        """, (seller_id,))
        
        address_data = cursor.fetchone()
        
        # Merge address data into seller_data
        if seller_data and address_data:
            seller_data.update(address_data)
        elif seller_data:
            # No address yet, set empty values
            seller_data['region'] = ''
            seller_data['province'] = ''
            seller_data['city'] = ''
            seller_data['barangay'] = ''
            seller_data['street_name'] = ''
            seller_data['house_number'] = ''
            seller_data['postal_code'] = ''
        
        # Paths already include /static/ prefix, no need to modify
        
        close_db_connection(connection, cursor)
        
        return render_template('seller/seller_information.html', seller=seller_data)
        
    except Exception as e:
        print(f"Error loading seller information: {e}")
        return render_template('seller/seller_information.html', error=str(e))

@seller_information_bp.route('/seller/information/save', methods=['POST'])
@seller_required
def save_seller_information():
    """Save seller information to database"""
    try:
        seller_id = session.get('seller_id')  # Guaranteed to exist due to @seller_required
        
        # Get form data
        data = request.form
        
        first_name = data.get('first_name')
        last_name = data.get('last_name')
        shop_name = data.get('shop_name')
        phone_number = data.get('phone_number')
        region = data.get('region')
        province = data.get('province')
        city = data.get('city')
        barangay = data.get('barangay')
        street = data.get('street')
        house_number = data.get('house_number')
        postal_code = data.get('postal_code')
        shop_description = data.get('shop_description')
        
        print(f"📝 Received data:")
        print(f"   Street: {street}")
        print(f"   House Number: {house_number}")
        print(f"   Phone: {phone_number}")
        print(f"   Description: {shop_description}")
        print(f"   Files in request: {list(request.files.keys())}")
        
        # Validate required fields
        if not all([first_name, last_name, shop_name, region, city, barangay, postal_code]):
            return jsonify({'success': False, 'message': 'Please fill in all required fields'}), 400
        
        # Handle file uploads
        shop_logo_path = None
        
        import time
        
        # Handle shop logo
        if 'shop_logo' in request.files:
            file = request.files['shop_logo']
            print(f"🖼️ Shop Logo: {file.filename}")
            if file and file.filename and allowed_file(file.filename):
                upload_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), UPLOAD_FOLDER)
                os.makedirs(upload_dir, exist_ok=True)
                
                filename = secure_filename(file.filename)
                timestamp = str(int(time.time() * 1000))
                unique_filename = f"seller_{seller_id}_{timestamp}_{filename}"
                
                file_path = os.path.join(upload_dir, unique_filename)
                file.save(file_path)
                
                shop_logo_path = f"{UPLOAD_FOLDER_DB}/{unique_filename}"
                print(f"✅ Logo uploaded: {shop_logo_path}")
        
        # Connect to database
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        # Build full address
        address_parts = [house_number, street, barangay, city, province, region, postal_code]
        full_address = ', '.join(filter(None, address_parts))
        
        # Update seller information (without documents)
        update_fields = []
        update_values = []
        
        update_fields.extend(['first_name = %s', 'last_name = %s', 'shop_name = %s', 'phone_number = %s', 'shop_description = %s'])
        update_values.extend([first_name, last_name, shop_name, phone_number, shop_description])
        
        if shop_logo_path:
            update_fields.append('shop_logo = %s')
            update_values.append(shop_logo_path)
        
        update_values.append(seller_id)
        
        query = f"UPDATE sellers SET {', '.join(update_fields)} WHERE seller_id = %s"
        cursor.execute(query, tuple(update_values))
        print(f"✅ Seller info updated with {len(update_fields)} fields")
        
        # Check if address exists for this seller
        cursor.execute("""
            SELECT address_id FROM addresses
            WHERE user_type = 'seller' AND user_ref_id = %s
            LIMIT 1
        """, (seller_id,))
        
        existing_address = cursor.fetchone()
        
        if existing_address:
            # Update existing address
            cursor.execute("""
                UPDATE addresses
                SET full_address = %s,
                    region = %s,
                    province = %s,
                    city = %s,
                    barangay = %s,
                    street_name = %s,
                    house_number = %s,
                    postal_code = %s,
                    phone_number = %s
                WHERE address_id = %s
            """, (full_address, region, province, city, barangay, street, house_number, 
                  postal_code, phone_number, existing_address['address_id']))
            print(f"✅ Address updated for seller {seller_id}")
        else:
            # Insert new address
            cursor.execute("""
                INSERT INTO addresses 
                (user_type, user_ref_id, full_address, region, province, city, barangay, 
                 street_name, house_number, postal_code, phone_number, is_default)
                VALUES ('seller', %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, TRUE)
            """, (seller_id, full_address, region, province, city, barangay, street, 
                  house_number, postal_code, phone_number))
            print(f"✅ New address created for seller {seller_id}")
        
        connection.commit()
        print(f"✅ Database updated successfully")
        close_db_connection(connection, cursor)
        
        return jsonify({'success': True, 'message': 'Seller information saved successfully'})
        
    except Exception as e:
        print(f"❌ Error saving seller information: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': str(e)}), 500

@seller_information_bp.route('/seller/documents/save', methods=['POST'])
@seller_required
def save_seller_documents():
    """Save seller verification documents to database"""
    try:
        seller_id = session.get('seller_id')  # Guaranteed to exist due to @seller_required
        
        # Get form data
        data = request.form
        id_type = data.get('id_type')
        
        print(f"📝 Received documents data:")
        print(f"   ID Type: {id_type}")
        print(f"   Files in request: {list(request.files.keys())}")
        
        # Handle file uploads using organized structure
        id_image_path = None
        business_permit_path = None
        
        # Handle ID image
        if 'id_image' in request.files:
            file = request.files['id_image']
            print(f"🆔 ID Image: {file.filename}")
            if file and file.filename and file_allowed(file.filename):
                success, id_image_path, error = save_user_document(file, 'seller', seller_id, 'id', file.filename)
                if success:
                    print(f"✅ ID uploaded: {id_image_path}")
                else:
                    print(f"❌ ID upload failed: {error}")
        
        # Handle business permit
        if 'business_permit' in request.files:
            file = request.files['business_permit']
            print(f"📄 Business Permit: {file.filename}")
            if file and file.filename and file_allowed(file.filename):
                success, business_permit_path, error = save_user_document(file, 'seller', seller_id, 'business_permit', file.filename)
                if success:
                    print(f"✅ Business permit uploaded: {business_permit_path}")
                else:
                    print(f"❌ Business permit upload failed: {error}")
        
        # Connect to database
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        # Update seller documents
        update_fields = []
        update_values = []
        
        if id_type:
            update_fields.append('id_type = %s')
            update_values.append(id_type)
        
        if id_image_path:
            update_fields.append('id_file_path = %s')
            update_values.append(id_image_path)
        
        if business_permit_path:
            update_fields.append('business_permit_file_path = %s')
            update_values.append(business_permit_path)
        
        if update_fields:
            update_values.append(seller_id)
            query = f"UPDATE sellers SET {', '.join(update_fields)} WHERE seller_id = %s"
            cursor.execute(query, tuple(update_values))
            print(f"✅ Seller documents updated with {len(update_fields)} fields")
            
            connection.commit()
            print(f"✅ Documents database updated successfully")
        
        close_db_connection(connection, cursor)
        
        return jsonify({'success': True, 'message': 'Documents submitted successfully'})
        
    except Exception as e:
        print(f"❌ Error saving seller documents: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': str(e)}), 500
