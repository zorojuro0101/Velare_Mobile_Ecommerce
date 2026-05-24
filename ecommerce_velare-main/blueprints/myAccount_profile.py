from flask import Blueprint, render_template, request, jsonify, session
from werkzeug.utils import secure_filename
import os
import sys

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.supabase_helper import *

myAccount_profile_bp = Blueprint('myAccount_profile', __name__)

# Configuration for profile image uploads
UPLOAD_FOLDER = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'static', 'uploads', 'profiles')
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg'}

# Create upload folder if it doesn't exist
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

def allowed_file(filename):
    """Check if file extension is allowed"""
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def get_user_profile_data():
    """Helper function to get current user's profile data"""
    if 'user_id' not in session or not session.get('logged_in'):
        return None
    
    try:
        profile = get_buyer_profile(session['user_id'])
        if profile:
            # Flatten nested user data
            user_data = profile.get('users', {})
            if isinstance(user_data, dict):
                profile['email'] = user_data.get('email')
            elif isinstance(user_data, list) and user_data:
                profile['email'] = user_data[0].get('email')
        return profile
    except:
        return None

@myAccount_profile_bp.route('/myAccount_profile')
def myAccount_profile():
    """🖼️ Render profile page with optimized data loading"""
    print("=" * 80)
    print("🖼️ [PROFILE PAGE] Loading profile page...")
    print("=" * 80)
    
    profile = get_user_profile_data()
    
    # Get buyer's ID verification status in same query (already optimized)
    id_data = None
    if 'user_id' in session and profile:
        # ID data is already in profile from get_buyer_profile, no extra query needed
        if profile.get('id_file_path'):
            id_data = {
                'id_file_path': profile.get('id_file_path'),
                'id_type': profile.get('id_type')
            }
    
    print(f"✅ Profile loaded for user_id={session.get('user_id')}")
    return render_template('accounts/myAccount_profile.html', user_profile=profile, id_data=id_data)

@myAccount_profile_bp.route('/api/profile/get', methods=['GET'])
def get_profile():
    """Get buyer profile data"""
    try:
        # Get user_id from session
        if 'user_id' not in session or not session.get('logged_in'):
            return jsonify({'success': False, 'message': 'Not logged in'}), 401
        
        user_id = session['user_id']
        
        supabase = get_supabase()
        if not supabase:
            print("Database connection failed")
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Get the logged-in user's profile data
            profile = get_buyer_profile(user_id)
            
            if not profile:
                return jsonify({'success': False, 'message': 'Profile not found'}), 404
            
            # Flatten nested user data
            user_data = profile.get('users', {})
            if isinstance(user_data, dict):
                profile['email'] = user_data.get('email')
            elif isinstance(user_data, list) and user_data:
                profile['email'] = user_data[0].get('email')
            
            return jsonify({
                'success': True,
                'profile': profile
            }), 200
            
        except Exception as e:
            print(f"Database query error: {e}")
            return jsonify({'success': False, 'message': f'Database error: {str(e)}'}), 500
            
    except Exception as e:
        print(f"Unexpected error: {e}")
        return jsonify({'success': False, 'message': f'Unexpected error: {str(e)}'}), 500

@myAccount_profile_bp.route('/api/profile/update', methods=['POST'])
def update_profile():
    """Update buyer profile data"""
    try:
        # Get user_id from session
        if 'user_id' not in session or not session.get('logged_in'):
            return jsonify({'success': False, 'message': 'Not logged in'}), 401
        
        user_id = session['user_id']
        
        # Get form data
        first_name = request.form.get('first_name', '').strip()
        last_name = request.form.get('last_name', '').strip()
        email = request.form.get('email', '').strip()
        phone_number = request.form.get('phone_number', '').strip()
        gender = request.form.get('gender', '').strip()
        
        # Validate required fields
        if not all([first_name, last_name]):
            return jsonify({'success': False, 'message': 'First name and last name are required'}), 400
        
        # Validate email if provided
        if email:
            import re
            email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
            if not re.match(email_pattern, email):
                return jsonify({'success': False, 'message': 'Invalid email format'}), 400
        
        # Validate phone number if provided
        if phone_number:
            if not phone_number.isdigit():
                return jsonify({'success': False, 'message': 'Phone number must contain only numbers'}), 400
            if len(phone_number) != 11:
                return jsonify({'success': False, 'message': 'Phone number must be exactly 11 digits'}), 400
        
        supabase = get_supabase()
        if not supabase:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Handle profile image upload to Supabase Storage
            profile_image_path = None
            if 'profile_image' in request.files:
                file = request.files['profile_image']
                if file and file.filename and allowed_file(file.filename):
                    try:
                        import uuid
                        from datetime import datetime
                        
                        # Generate unique filename
                        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                        unique_id = str(uuid.uuid4())[:8]
                        filename = secure_filename(file.filename)
                        unique_filename = f"static/uploads/profiles/buyer_{user_id}_{timestamp}_{unique_id}_{filename}"
                        
                        print(f"📤 Uploading profile image to Supabase: {unique_filename}")
                        
                        # Read file content
                        file.seek(0)
                        file_content = file.read()
                        
                        print(f"📦 Content type: {file.content_type}")
                        print(f"📦 Content length: {len(file_content)} bytes")
                        
                        # Upload to Supabase Storage bucket "Images"
                        upload_response = supabase.storage.from_('Images').upload(
                            path=unique_filename,
                            file=file_content,
                            file_options={"content-type": file.content_type or 'image/jpeg'}
                        )
                        
                        print(f"📤 Upload response: {upload_response}")
                        
                        if not upload_response:
                            raise Exception("Upload failed - no response from Supabase")
                        
                        # Get public URL
                        profile_image_path = supabase.storage.from_('Images').get_public_url(unique_filename)
                        
                        print(f"✅ Profile image uploaded to Supabase: {profile_image_path}")
                        
                    except Exception as e:
                        print(f"❌ File upload error: {e}")
                        import traceback
                        traceback.print_exc()
                        return jsonify({'success': False, 'message': 'Failed to upload profile image'}), 500
            
            # Build update data for buyers table
            profile_data = {
                'first_name': first_name,
                'last_name': last_name
            }
            
            if phone_number:
                profile_data['phone_number'] = phone_number
            
            if gender and gender in ['Male', 'Female', 'Other']:
                profile_data['gender'] = gender
            
            if profile_image_path:
                profile_data['profile_image'] = profile_image_path
            
            # Update buyer profile
            success = update_buyer_profile_supabase(user_id, profile_data)
            
            if not success:
                return jsonify({'success': False, 'message': 'Failed to update profile'}), 500
            
            # Update email in users table if provided
            if email:
                email_success = update_user_email_supabase(user_id, email)
                if not email_success:
                    return jsonify({'success': False, 'message': 'Failed to update email'}), 500
            
            return jsonify({
                'success': True,
                'message': 'Profile updated successfully!',
                'profile_image': profile_image_path
            }), 200
            
        except Exception as e:
            print(f"Update error: {e}")
            return jsonify({'success': False, 'message': f'Failed to update profile: {str(e)}'}), 500
            
    except Exception as e:
        print(f"Unexpected error: {e}")
        return jsonify({'success': False, 'message': f'An unexpected error occurred: {str(e)}'}), 500


@myAccount_profile_bp.route('/api/profile/get-id', methods=['GET'])
def get_id():
    """Get buyer's ID verification data"""
    if 'user_id' not in session:
        return jsonify({'success': False, 'message': 'Not authenticated'}), 401
    
    try:
        supabase = get_supabase()
        if not supabase:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        response = supabase.table('buyers').select('id_file_path, id_type').eq('user_id', session['user_id']).execute()
        
        id_data = response.data[0] if response.data else None
        
        if id_data and id_data.get('id_file_path'):
            return jsonify({
                'success': True,
                'id_data': {
                    'id_path': id_data['id_file_path'],
                    'id_type': id_data['id_type']
                }
            }), 200
        else:
            return jsonify({
                'success': False,
                'message': 'No ID uploaded yet'
            }), 404
            
    except Exception as e:
        print(f"Error getting ID data: {e}")
        return jsonify({'success': False, 'message': 'An error occurred'}), 500

@myAccount_profile_bp.route('/api/profile/upload-id', methods=['POST'])
def upload_id():
    """Upload buyer's valid ID for verification"""
    if 'user_id' not in session:
        return jsonify({'success': False, 'message': 'Not authenticated'}), 401
    
    try:
        # Check if file is in request
        if 'valid_id' not in request.files:
            return jsonify({'success': False, 'message': 'No file uploaded'}), 400
        
        file = request.files['valid_id']
        
        if file.filename == '':
            return jsonify({'success': False, 'message': 'No file selected'}), 400
        
        if not allowed_file(file.filename):
            return jsonify({'success': False, 'message': 'Invalid file type. Only PNG, JPG, and JPEG are allowed'}), 400
        
        # Create ID uploads folder
        ID_UPLOAD_FOLDER = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'static', 'uploads', 'buyer_ids')
        os.makedirs(ID_UPLOAD_FOLDER, exist_ok=True)
        
        # Save file
        filename = secure_filename(f"buyer_{session['user_id']}_{file.filename}")
        file_path = os.path.join(ID_UPLOAD_FOLDER, filename)
        file.save(file_path)
        
        # Save to database
        supabase = get_supabase()
        if not supabase:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        # Get buyer_id
        buyer = get_buyer_by_user_id(session['user_id'])
        
        if not buyer:
            return jsonify({'success': False, 'message': 'Buyer not found'}), 404
        
        buyer_id = buyer['buyer_id']
        
        # Get ID type from form
        id_type = request.form.get('id_type', '')
        
        if not id_type:
            return jsonify({'success': False, 'message': 'Please select an ID type'}), 400
        
        # Update buyer with ID path and type
        id_path = f"/static/uploads/buyer_ids/{filename}"
        update_response = supabase.table('buyers').update({
            'id_file_path': id_path,
            'id_type': id_type
        }).eq('buyer_id', buyer_id).execute()
        
        if not update_response.data:
            return jsonify({'success': False, 'message': 'Failed to save ID information'}), 500
        
        return jsonify({
            'success': True,
            'message': 'ID uploaded successfully! Your document will be reviewed by our team.',
            'id_path': id_path
        }), 200
        
    except Exception as e:
        print(f"Error uploading ID: {e}")
        return jsonify({'success': False, 'message': 'An error occurred while uploading'}), 500
