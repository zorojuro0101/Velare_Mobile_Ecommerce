"""
Helper functions for user profile data
Shared across all account page blueprints
"""
from flask import session
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_config import get_db_connection, close_db_connection

def get_user_profile_data():
    """Get current logged-in user's profile data for sidebar display"""
    if 'user_id' not in session or not session.get('logged_in'):
        return None
    
    try:
        connection = get_db_connection()
        if not connection:
            return None
        
        cursor = connection.cursor(dictionary=True)
        cursor.execute("""
            SELECT u.email, b.first_name, b.last_name, b.gender, 
                   b.phone_number, b.profile_image
            FROM users u
            JOIN buyers b ON u.user_id = b.user_id
            WHERE u.user_id = %s
        """, (session['user_id'],))
        
        profile = cursor.fetchone()
        close_db_connection(connection, cursor)
        return profile
    except Exception as e:
        print(f"Error getting profile data: {e}")
        return None
