from flask import Blueprint, render_template, request, jsonify, session
from .profile_helper import get_user_profile_data
import sys
import os
import re

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.supabase_helper import *
from utils.password_utils import hash_password, verify_password

myAccount_changepass_bp = Blueprint('myAccount_changepass', __name__)


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


@myAccount_changepass_bp.route('/myAccount_changepass')
def myAccount_changepass():
    profile = get_user_profile_data()
    return render_template('accounts/myAccount_changepass.html', user_profile=profile)


@myAccount_changepass_bp.route('/myAccount_changepass/update', methods=['POST'])
def update_password():
    """Handle password change. Always stores the new password as a bcrypt hash."""
    try:
        if 'user_id' not in session:
            return jsonify({'success': False, 'message': 'Please login to continue'}), 401

        data = request.get_json()
        current_password = data.get('current_password', '').strip()
        new_password = data.get('new_password', '').strip()
        confirm_password = data.get('confirm_password', '').strip()

        if not all([current_password, new_password, confirm_password]):
            return jsonify({'success': False, 'message': 'All fields are required'}), 400

        if new_password != confirm_password:
            return jsonify({'success': False, 'message': 'New passwords do not match'}), 400

        password_errors = validate_password(new_password)
        if password_errors:
            return jsonify({'success': False, 'message': password_errors[0]}), 400

        if current_password == new_password:
            return jsonify({'success': False, 'message': 'New password must be different from current password'}), 400

        supabase = get_supabase()
        if not supabase:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500

        try:
            # Get user's current stored password (may be hash or legacy plain text)
            user_response = supabase.table('users').select('password').eq('user_id', session['user_id']).execute()

            if not user_response.data:
                return jsonify({'success': False, 'message': 'User not found'}), 404

            stored = user_response.data[0]['password']

            # Verify current password — verify_password handles both new bcrypt
            # hashes and legacy plain-text rows so existing users aren't locked out.
            if not verify_password(current_password, stored):
                return jsonify({'success': False, 'message': 'Current password is incorrect'}), 401

            # Always write the new password as a bcrypt hash.
            supabase.table('users').update(
                {'password': hash_password(new_password)}
            ).eq('user_id', session['user_id']).execute()

            return jsonify({'success': True, 'message': 'Password changed successfully!'}), 200

        except Exception as e:
            print(f"❌ Error updating password: {e}")
            return jsonify({'success': False, 'message': 'Failed to update password. Please try again.'}), 500

    except Exception as e:
        print(f"❌ Unexpected error in update_password: {e}")
        return jsonify({'success': False, 'message': 'An unexpected error occurred. Please try again.'}), 500
