from flask import Blueprint, render_template, session, redirect, url_for, request, jsonify
from werkzeug.utils import secure_filename
import sys
import os

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.supabase_helper import *
from utils.file_manager import save_user_document, allowed_file as file_allowed

rider_profile_bp = Blueprint('rider_profile', __name__)

# Configuration for profile image uploads
UPLOAD_FOLDER = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'static', 'uploads', 'profiles')
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg'}

# Create upload folder if it doesn't exist
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

def allowed_file(filename):
    """Check if file extension is allowed"""
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@rider_profile_bp.route('/rider/profile')
def rider_profile():
    # Check if user is logged in and is a rider
    if 'user_id' not in session or session.get('user_type') != 'rider':
        return redirect(url_for('auth.login'))
    
    try:
        # Get rider information from Supabase
        rider_data = get_rider_profile(session['user_id'])
        
        if not rider_data:
            return render_template('rider/rider_profile.html', error='Rider profile not found')
        
        return render_template('rider/rider_profile.html', rider=rider_data)
        
    except Exception as e:
        print(f"Error fetching rider data: {e}")
        return render_template('rider/rider_profile.html', error='Failed to load rider data')

@rider_profile_bp.route('/rider/profile/update', methods=['POST'])
def update_profile():
    """Handle rider profile update"""
    # Check if user is logged in and is a rider
    if 'user_id' not in session or session.get('user_type') != 'rider':
        return jsonify({'success': False, 'message': 'Unauthorized'}), 401
    
    try:
        # Get form data
        first_name = request.form.get('first_name', '').strip()
        last_name = request.form.get('last_name', '').strip()
        phone_number = request.form.get('phone_number', '').strip()
        vehicle_type = request.form.get('vehicle_type', '').strip()
        plate_number = request.form.get('plate_number', '').strip()
        
        # Validate required fields
        if not all([first_name, last_name, phone_number]):
            return jsonify({'success': False, 'message': 'First name, last name, and phone number are required'}), 400
        
        # Handle profile image upload
        profile_image_path = None
        if 'profile_image' in request.files:
            file = request.files['profile_image']
            if file and file.filename and allowed_file(file.filename):
                try:
                    filename = secure_filename(f"rider_{session['user_id']}_{file.filename}")
                    file_path = os.path.join(UPLOAD_FOLDER, filename)
                    file.save(file_path)
                    profile_image_path = f"uploads/profiles/{filename}"
                except Exception as e:
                    print(f"Error uploading profile image: {e}")
                    return jsonify({'success': False, 'message': 'Failed to upload profile image'}), 500
        
        # Prepare update data
        update_data = {
            'first_name': first_name,
            'last_name': last_name,
            'phone_number': phone_number,
            'vehicle_type': vehicle_type,
            'plate_number': plate_number
        }
        
        if profile_image_path:
            update_data['profile_image'] = profile_image_path
        
        # Update rider profile using Supabase
        success = update_rider_profile_supabase(session['user_id'], update_data)
        
        if not success:
            return jsonify({'success': False, 'message': 'Failed to update profile'}), 500
        
        return jsonify({
            'success': True,
            'message': 'Profile updated successfully!',
            'data': {
                'first_name': first_name,
                'last_name': last_name,
                'profile_image': profile_image_path
            }
        }), 200
            
    except Exception as e:
        print(f"Error in update_profile: {e}")
        return jsonify({'success': False, 'message': 'An unexpected error occurred'}), 500

@rider_profile_bp.route('/rider/profile/update-documents', methods=['POST'])
def update_documents():
    """Handle rider documents upload"""
    # Check if user is logged in and is a rider
    if 'user_id' not in session or session.get('user_type') != 'rider':
        return jsonify({'success': False, 'message': 'Unauthorized'}), 401
    
    try:
        # Get rider_id
        rider = get_rider_by_user_id(session['user_id'])
        
        if not rider:
            return jsonify({'success': False, 'message': 'Rider not found'}), 404
        
        rider_id = rider['rider_id']
        
        # Handle OR/CR upload
        or_cr_path = None
        if 'or_cr' in request.files:
            file = request.files['or_cr']
            print(f"📄 OR/CR: {file.filename}")
            if file and file.filename and file_allowed(file.filename):
                success, or_cr_path, error = save_user_document(file, 'rider', rider_id, 'orcr', file.filename)
                if success:
                    print(f"✅ OR/CR uploaded: {or_cr_path}")
                else:
                    print(f"❌ OR/CR upload failed: {error}")
                    return jsonify({'success': False, 'message': f'Failed to upload OR/CR: {error}'}), 500
        
        # Handle Driver's License upload
        license_path = None
        if 'drivers_license' in request.files:
            file = request.files['drivers_license']
            print(f"🪪 Driver's License: {file.filename}")
            if file and file.filename and file_allowed(file.filename):
                success, license_path, error = save_user_document(file, 'rider', rider_id, 'driver_license', file.filename)
                if success:
                    print(f"✅ License uploaded: {license_path}")
                else:
                    print(f"❌ License upload failed: {error}")
                    return jsonify({'success': False, 'message': f'Failed to upload license: {error}'}), 500
        
        if not or_cr_path and not license_path:
            return jsonify({'success': False, 'message': 'No documents uploaded'}), 400
        
        # Update rider documents using Supabase
        update_data = {}
        
        if or_cr_path:
            update_data['orcr_file_path'] = or_cr_path
        
        if license_path:
            update_data['driver_license_file_path'] = license_path
        
        if update_data:
            success = update_rider_profile_supabase(session['user_id'], update_data)
            
            if not success:
                return jsonify({'success': False, 'message': 'Failed to update documents'}), 500
        
        return jsonify({
            'success': True,
            'message': 'Documents uploaded successfully!'
        }), 200
            
    except Exception as e:
        print(f"Error in update_documents: {e}")
        return jsonify({'success': False, 'message': 'An unexpected error occurred'}), 500
