"""
Helper functions for user profile data
Shared across all account page blueprints
"""
from flask import session, g, has_request_context
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_config import get_supabase_client


def get_user_profile_data():
    """Get current logged-in user's profile data for sidebar display.

    Cached on Flask `g` so multiple callers in the same request only trigger
    one Supabase round-trip. Each request gets a fresh `g`, so suspensions or
    profile edits show up on the next page load.
    """
    if 'user_id' not in session or not session.get('logged_in'):
        return None

    # Per-request cache.
    if has_request_context():
        cached = getattr(g, '_user_profile_data', None)
        if cached is not None:
            return cached if cached != '__missing__' else None

    profile = _fetch_user_profile_data(session['user_id'])

    if has_request_context():
        # Store sentinel for misses so subsequent calls don't re-query.
        g._user_profile_data = profile if profile is not None else '__missing__'

    return profile


def _fetch_user_profile_data(user_id):
    """Actual Supabase fetch for the current user's profile."""
    try:
        supabase = get_supabase_client()
        if not supabase:
            return None

        # Get user email
        user_response = supabase.table('users').select('email').eq('user_id', user_id).execute()
        if not user_response.data:
            return None

        # Get buyer profile
        buyer_response = supabase.table('buyers').select(
            'first_name, last_name, gender, phone_number, profile_image'
        ).eq('user_id', user_id).execute()
        if not buyer_response.data:
            return None

        buyer = buyer_response.data[0]
        return {
            'email': user_response.data[0]['email'],
            'first_name': buyer['first_name'],
            'last_name': buyer['last_name'],
            'gender': buyer['gender'],
            'phone_number': buyer['phone_number'],
            'profile_image': buyer['profile_image'],
        }
    except Exception as e:
        print(f"❌ Error getting profile data: {e}")
        return None
