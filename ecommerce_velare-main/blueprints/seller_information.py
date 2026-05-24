from flask import Blueprint, render_template, request, jsonify, session
from werkzeug.utils import secure_filename
import os
import sys

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_config import get_db_connection, close_db_connection, get_supabase_client
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
    """Display seller information page using Supabase"""
    try:
        seller_id = session.get('seller_id')  # Guaranteed to exist due to @seller_required
        
        supabase = get_supabase_client()
        if not supabase:
            return render_template('seller/seller_information.html', error='Database connection failed')
        
        try:
            # Get seller information including ID and business permit
            seller_response = supabase.table('sellers').select(
                'first_name, last_name, shop_name, shop_description, shop_logo, phone_number, id_file_path, id_type, business_permit_file_path'
            ).eq('seller_id', seller_id).execute()
            
            if not seller_response.data:
                return render_template('seller/seller_information.html', error='Seller not found')
            
            seller_data = seller_response.data[0]
            
            # Get seller address from addresses table
            address_response = supabase.table('addresses').select(
                'recipient_name, phone_number, full_address, region, province, city, barangay, street_name, house_number, postal_code, is_default'
            ).eq('user_type', 'seller').eq('user_ref_id', seller_id).order('is_default', desc=True).order('created_at', desc=True).limit(1).execute()
            
            # Merge address data into seller_data
            if address_response.data:
                address_data = address_response.data[0]
                seller_data.update(address_data)
            else:
                # No address yet, set empty values
                seller_data['region'] = ''
                seller_data['province'] = ''
                seller_data['city'] = ''
                seller_data['barangay'] = ''
                seller_data['street_name'] = ''
                seller_data['house_number'] = ''
                seller_data['postal_code'] = ''
            
            return render_template('seller/seller_information.html', seller=seller_data)
            
        except Exception as e:
            print(f"❌ Database error: {e}")
            import traceback
            traceback.print_exc()
            return render_template('seller/seller_information.html', error=str(e))
        
    except Exception as e:
        print(f"❌ Error loading seller information: {e}")
        return render_template('seller/seller_information.html', error=str(e))

@seller_information_bp.route('/seller/information/save', methods=['POST'])
@seller_required
def save_seller_information():
    """Save seller information to Supabase"""
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
        
        # Connect to Supabase
        supabase = get_supabase_client()
        if not supabase:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Handle shop logo upload to Supabase Storage
            shop_logo_url = None
            
            if 'shop_logo' in request.files:
                file = request.files['shop_logo']
                print(f"🖼️ Shop Logo: {file.filename}")
                if file and file.filename and allowed_file(file.filename):
                    import uuid
                    import time
                    
                    # Read file content
                    file.seek(0)
                    file_content = file.read()
                    
                    if file_content:
                        file_ext = file.filename.rsplit('.', 1)[1].lower() if '.' in file.filename else 'jpg'
                        timestamp = str(int(time.time() * 1000))
                        unique_filename = f"static/uploads/shop_logos/seller_{seller_id}_{timestamp}_{uuid.uuid4().hex[:8]}.{file_ext}"
                        
                        print(f"📤 Uploading shop logo to Supabase: {unique_filename}")
                        
                        # Upload to Supabase Storage
                        upload_response = supabase.storage.from_('Images').upload(
                            unique_filename,
                            file_content,
                            file_options={"content-type": file.content_type or 'image/jpeg'}
                        )
                        
                        shop_logo_url = supabase.storage.from_('Images').get_public_url(unique_filename)
                        print(f"✅ Logo uploaded: {shop_logo_url}")
            
            # Build full address
            address_parts = [house_number, street, barangay, city, province, region, postal_code]
            full_address = ', '.join(filter(None, address_parts))
            
            # Update seller information
            from datetime import datetime
            
            update_data = {
                'first_name': first_name,
                'last_name': last_name,
                'shop_name': shop_name,
                'phone_number': phone_number,
                'shop_description': shop_description
            }
            
            if shop_logo_url:
                update_data['shop_logo'] = shop_logo_url
            
            supabase.table('sellers').update(update_data).eq('seller_id', seller_id).execute()
            print(f"✅ Seller info updated")
            
            # Check if address exists for this seller
            existing_address = supabase.table('addresses').select('address_id').eq('user_type', 'seller').eq('user_ref_id', seller_id).limit(1).execute()
            
            address_data = {
                'full_address': full_address,
                'region': region,
                'province': province,
                'city': city,
                'barangay': barangay,
                'street_name': street,
                'house_number': house_number,
                'postal_code': postal_code,
                'phone_number': phone_number
            }
            
            if existing_address.data:
                # Update existing address
                supabase.table('addresses').update(address_data).eq('address_id', existing_address.data[0]['address_id']).execute()
                print(f"✅ Address updated for seller {seller_id}")
            else:
                # Insert new address
                address_data.update({
                    'user_type': 'seller',
                    'user_ref_id': seller_id,
                    'is_default': True,
                    'created_at': datetime.now().isoformat()
                })
                supabase.table('addresses').insert(address_data).execute()
                print(f"✅ New address created for seller {seller_id}")
            
            print(f"✅ Database updated successfully")
            
            return jsonify({'success': True, 'message': 'Seller information saved successfully'})
            
        except Exception as e:
            print(f"❌ Database error: {e}")
            import traceback
            traceback.print_exc()
            return jsonify({'success': False, 'message': str(e)}), 500
        
    except Exception as e:
        print(f"❌ Error saving seller information: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': str(e)}), 500

@seller_information_bp.route('/seller/documents/save', methods=['POST'])
@seller_required
def save_seller_documents():
    """Save seller verification documents to Supabase"""
    try:
        seller_id = session.get('seller_id')  # Guaranteed to exist due to @seller_required
        
        # Get form data
        data = request.form
        id_type = data.get('id_type')
        
        print(f"📝 Received documents data:")
        print(f"   ID Type: {id_type}")
        print(f"   Files in request: {list(request.files.keys())}")
        
        # Connect to Supabase
        supabase = get_supabase_client()
        if not supabase:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            import uuid
            
            # Handle ID image upload to Supabase Storage
            id_image_url = None
            
            if 'id_image' in request.files:
                file = request.files['id_image']
                print(f"🆔 ID Image: {file.filename}")
                if file and file.filename and file_allowed(file.filename):
                    file.seek(0)
                    file_content = file.read()
                    
                    if file_content:
                        file_ext = file.filename.rsplit('.', 1)[1].lower() if '.' in file.filename else 'jpg'
                        unique_filename = f"static/uploads/seller_ids/seller_{seller_id}_id_{uuid.uuid4().hex[:8]}.{file_ext}"
                        
                        print(f"📤 Uploading seller ID to Supabase: {unique_filename}")
                        
                        upload_response = supabase.storage.from_('Images').upload(
                            unique_filename,
                            file_content,
                            file_options={"content-type": file.content_type or 'image/jpeg'}
                        )
                        
                        id_image_url = supabase.storage.from_('Images').get_public_url(unique_filename)
                        print(f"✅ ID uploaded: {id_image_url}")
            
            # Handle business permit upload to Supabase Storage
            business_permit_url = None
            
            if 'business_permit' in request.files:
                file = request.files['business_permit']
                print(f"📄 Business Permit: {file.filename}")
                if file and file.filename and file_allowed(file.filename):
                    file.seek(0)
                    file_content = file.read()
                    
                    if file_content:
                        file_ext = file.filename.rsplit('.', 1)[1].lower() if '.' in file.filename else 'jpg'
                        unique_filename = f"static/uploads/seller_permits/seller_{seller_id}_permit_{uuid.uuid4().hex[:8]}.{file_ext}"
                        
                        print(f"📤 Uploading business permit to Supabase: {unique_filename}")
                        
                        upload_response = supabase.storage.from_('Images').upload(
                            unique_filename,
                            file_content,
                            file_options={"content-type": file.content_type or 'image/jpeg'}
                        )
                        
                        business_permit_url = supabase.storage.from_('Images').get_public_url(unique_filename)
                        print(f"✅ Business permit uploaded: {business_permit_url}")
            
            # Update seller documents
            update_data = {}
            
            if id_type:
                update_data['id_type'] = id_type
            
            if id_image_url:
                update_data['id_file_path'] = id_image_url
            
            if business_permit_url:
                update_data['business_permit_file_path'] = business_permit_url
            
            if update_data:
                supabase.table('sellers').update(update_data).eq('seller_id', seller_id).execute()
                print(f"✅ Seller documents updated with {len(update_data)} fields")
            
            return jsonify({'success': True, 'message': 'Documents submitted successfully'})
            
        except Exception as e:
            print(f"❌ Database error: {e}")
            import traceback
            traceback.print_exc()
            return jsonify({'success': False, 'message': str(e)}), 500
        
    except Exception as e:
        print(f"❌ Error saving seller documents: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': str(e)}), 500
