from functools import wraps
from flask import session, redirect, url_for, jsonify, request, make_response

def no_cache(f):
    """Decorator to prevent caching of protected pages"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        response = make_response(f(*args, **kwargs))
        response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate, post-check=0, pre-check=0'
        response.headers['Pragma'] = 'no-cache'
        response.headers['Expires'] = '0'
        return response
    return decorated_function

def seller_required(f):
    """Decorator to require seller authentication and prevent caching"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'seller_id' not in session or 'user_type' not in session:
            # For AJAX requests, return JSON error
            if request.is_json or request.headers.get('X-Requested-With') == 'XMLHttpRequest':
                return jsonify({'success': False, 'message': 'Authentication required'}), 401
            # For regular requests, redirect to login
            return redirect(url_for('auth.login'))
        
        if session.get('user_type') != 'seller':
            if request.is_json or request.headers.get('X-Requested-With') == 'XMLHttpRequest':
                return jsonify({'success': False, 'message': 'Seller access required'}), 403
            return redirect(url_for('auth.login'))
        
        # Add no-cache headers to response
        response = make_response(f(*args, **kwargs))
        response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate, post-check=0, pre-check=0'
        response.headers['Pragma'] = 'no-cache'
        response.headers['Expires'] = '0'
        return response
    return decorated_function

def admin_required(f):
    """Decorator to require admin authentication and prevent caching"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        # Check authentication first
        if 'user_id' not in session or 'user_type' not in session:
            if request.is_json or request.headers.get('X-Requested-With') == 'XMLHttpRequest':
                return jsonify({'success': False, 'message': 'Authentication required'}), 401
            return redirect(url_for('auth.login'))
        
        if session.get('user_type') != 'admin':
            if request.is_json or request.headers.get('X-Requested-With') == 'XMLHttpRequest':
                return jsonify({'success': False, 'message': 'Admin access required'}), 403
            return redirect(url_for('auth.login'))
        
        # Call the function and get response
        result = f(*args, **kwargs)
        
        # Add no-cache headers to response
        response = make_response(result)
        response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate, max-age=0'
        response.headers['Pragma'] = 'no-cache'
        response.headers['Expires'] = '0'
        return response
    return decorated_function

def buyer_required(f):
    """Decorator to require buyer authentication and prevent caching"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'buyer_id' not in session or 'user_type' not in session:
            if request.is_json or request.headers.get('X-Requested-With') == 'XMLHttpRequest':
                return jsonify({'success': False, 'message': 'Authentication required'}), 401
            return redirect(url_for('auth.login'))
        
        if session.get('user_type') != 'buyer':
            if request.is_json or request.headers.get('X-Requested-With') == 'XMLHttpRequest':
                return jsonify({'success': False, 'message': 'Buyer access required'}), 403
            return redirect(url_for('auth.login'))
        
        # Add no-cache headers to response
        response = make_response(f(*args, **kwargs))
        response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate, post-check=0, pre-check=0'
        response.headers['Pragma'] = 'no-cache'
        response.headers['Expires'] = '0'
        return response
    return decorated_function

def rider_required(f):
    """Decorator to require rider authentication and prevent caching"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'rider_id' not in session or 'user_type' not in session:
            if request.is_json or request.headers.get('X-Requested-With') == 'XMLHttpRequest':
                return jsonify({'success': False, 'message': 'Authentication required'}), 401
            return redirect(url_for('auth.login'))
        
        if session.get('user_type') != 'rider':
            if request.is_json or request.headers.get('X-Requested-With') == 'XMLHttpRequest':
                return jsonify({'success': False, 'message': 'Rider access required'}), 403
            return redirect(url_for('auth.login'))
        
        # Add no-cache headers to response
        response = make_response(f(*args, **kwargs))
        response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate, post-check=0, pre-check=0'
        response.headers['Pragma'] = 'no-cache'
        response.headers['Expires'] = '0'
        return response
    return decorated_function
