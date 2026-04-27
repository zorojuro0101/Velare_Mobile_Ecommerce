from flask import Blueprint, render_template, session, jsonify, request
from datetime import datetime, timedelta
import os
import sys

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_config import get_db_connection, close_db_connection
from utils.auth_decorators import seller_required

seller_customer_feedback_bp = Blueprint('seller_customer_feedback', __name__)

@seller_customer_feedback_bp.route('/seller/customer-feedback')
@seller_required
def seller_customer_feedback():
    """Display seller customer feedback page"""
    try:
        seller_id = session.get('seller_id')
        
        connection = get_db_connection()
        if not connection:
            return render_template('seller/seller_customer_feedback.html', error='Database connection failed')
        
        cursor = connection.cursor(dictionary=True)
        
        # Get seller information for profile display
        cursor.execute("""
            SELECT first_name, last_name, shop_name, shop_logo
            FROM sellers
            WHERE seller_id = %s
        """, (seller_id,))
        seller_info = cursor.fetchone()
        
        # Fix shop_logo path: remove 'static/' prefix for url_for
        if seller_info and seller_info.get('shop_logo'):
            if seller_info['shop_logo'].startswith('static/'):
                seller_info['shop_logo'] = seller_info['shop_logo'][7:]  # Remove 'static/' prefix
        
        close_db_connection(connection, cursor)
        
        return render_template('seller/seller_customer_feedback.html', seller=seller_info)
        
    except Exception as e:
        print(f"Error loading seller customer feedback: {e}")
        return render_template('seller/seller_customer_feedback.html', error=str(e))

@seller_customer_feedback_bp.route('/api/seller/reviews', methods=['GET'])
@seller_required
def get_seller_reviews():
    """API endpoint to get all reviews for seller's products with optional date range"""
    try:
        seller_id = session.get('seller_id')
        date_from = request.args.get('dateFrom')
        date_to = request.args.get('dateTo')
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        # Build query with optional date filtering
        query = """
            SELECT 
                pr.review_id,
                pr.product_id,
                pr.rating,
                pr.review_text,
                pr.created_at,
                p.product_name,
                CONCAT(b.first_name, ' ', b.last_name) as buyer_name,
                o.order_number
            FROM product_reviews pr
            JOIN products p ON pr.product_id = p.product_id
            JOIN buyers b ON pr.buyer_id = b.buyer_id
            JOIN orders o ON pr.order_id = o.order_id
            WHERE p.seller_id = %s
        """
        
        params = [seller_id]
        
        # Add date range filtering if provided
        if date_from and date_to:
            start_date = datetime.strptime(date_from, '%Y-%m-%d')
            end_date = datetime.strptime(date_to, '%Y-%m-%d')
            end_date = end_date.replace(hour=23, minute=59, second=59)
            query += " AND pr.created_at >= %s AND pr.created_at <= %s"
            params.extend([start_date, end_date])
        
        query += " ORDER BY pr.created_at DESC"
        
        cursor.execute(query, tuple(params))
        reviews = cursor.fetchall()
        
        # Calculate statistics
        total_reviews = len(reviews)
        if total_reviews > 0:
            avg_rating = sum(r['rating'] for r in reviews) / total_reviews
            rating_counts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
            for r in reviews:
                rating_counts[r['rating']] += 1
            positive_reviews = sum(1 for r in reviews if r['rating'] >= 4)
            positive_percentage = (positive_reviews / total_reviews) * 100
        else:
            avg_rating = 0
            rating_counts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
            positive_percentage = 0
        
        # Get product quality analysis
        cursor.execute("""
            SELECT 
                p.product_id,
                p.product_name,
                AVG(pr.rating) as avg_rating,
                COUNT(pr.review_id) as review_count
            FROM products p
            LEFT JOIN product_reviews pr ON p.product_id = pr.product_id
            WHERE p.seller_id = %s
            GROUP BY p.product_id, p.product_name
            HAVING review_count > 0
            ORDER BY avg_rating DESC
        """, (seller_id,))
        product_ratings = cursor.fetchall()
        
        top_rated = [p for p in product_ratings if p['avg_rating'] >= 4.5][:5]
        lowest_rated = [p for p in product_ratings if p['avg_rating'] < 4.0][:5]
        
        close_db_connection(connection, cursor)
        
        return jsonify({
            'success': True,
            'reviews': reviews,
            'statistics': {
                'total_reviews': total_reviews,
                'avg_rating': round(avg_rating, 1),
                'rating_counts': rating_counts,
                'positive_percentage': round(positive_percentage, 0)
            },
            'product_quality': {
                'top_rated': top_rated,
                'lowest_rated': lowest_rated
            }
        }), 200
        
    except Exception as e:
        print(f"Error fetching seller reviews: {e}")
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@seller_customer_feedback_bp.route('/api/seller/reviews/charts', methods=['GET'])
@seller_required
def get_reviews_charts():
    """API endpoint to get chart data for reviews based on date range"""
    try:
        seller_id = session.get('seller_id')
        date_from = request.args.get('dateFrom')
        date_to = request.args.get('dateTo')
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'error': 'Database connection failed'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        # Calculate date range
        if date_from and date_to:
            start_date = datetime.strptime(date_from, '%Y-%m-%d')
            end_date = datetime.strptime(date_to, '%Y-%m-%d')
            end_date = end_date.replace(hour=23, minute=59, second=59)
        else:
            end_date = datetime.now()
            start_date = end_date - timedelta(days=30)
        
        # Calculate the number of days in the range
        days_diff = (end_date - start_date).days
        
        # Determine grouping based on date range for Rating Trend
        if days_diff <= 7:
            # Daily grouping for 7 days or less
            cursor.execute("""
                SELECT 
                    DATE_FORMAT(pr.created_at, '%b %d') as date_label,
                    AVG(pr.rating) as avg_rating
                FROM product_reviews pr
                JOIN products p ON pr.product_id = p.product_id
                WHERE p.seller_id = %s
                    AND pr.created_at >= %s
                    AND pr.created_at <= %s
                GROUP BY DATE(pr.created_at), date_label
                ORDER BY DATE(pr.created_at)
            """, (seller_id, start_date, end_date))
            trend_data = cursor.fetchall()
            trend_label = 'Daily Average Rating'
        elif days_diff <= 30:
            # Weekly grouping for up to 30 days
            cursor.execute("""
                SELECT 
                    DATE_FORMAT(pr.created_at, '%b %d') as date_label,
                    AVG(pr.rating) as avg_rating
                FROM product_reviews pr
                JOIN products p ON pr.product_id = p.product_id
                WHERE p.seller_id = %s
                    AND pr.created_at >= %s
                    AND pr.created_at <= %s
                GROUP BY WEEK(pr.created_at, 1), date_label
                ORDER BY WEEK(pr.created_at, 1)
            """, (seller_id, start_date, end_date))
            trend_data = cursor.fetchall()
            trend_label = 'Weekly Average Rating'
        else:
            # Monthly grouping for longer periods
            cursor.execute("""
                SELECT 
                    DATE_FORMAT(pr.created_at, '%b %Y') as date_label,
                    AVG(pr.rating) as avg_rating
                FROM product_reviews pr
                JOIN products p ON pr.product_id = p.product_id
                WHERE p.seller_id = %s
                    AND pr.created_at >= %s
                    AND pr.created_at <= %s
                GROUP BY YEAR(pr.created_at), MONTH(pr.created_at), date_label
                ORDER BY YEAR(pr.created_at), MONTH(pr.created_at)
            """, (seller_id, start_date, end_date))
            trend_data = cursor.fetchall()
            trend_label = 'Monthly Average Rating'
        
        # Get rating distribution for the date range
        cursor.execute("""
            SELECT 
                pr.rating,
                COUNT(*) as count
            FROM product_reviews pr
            JOIN products p ON pr.product_id = p.product_id
            WHERE p.seller_id = %s
                AND pr.created_at >= %s
                AND pr.created_at <= %s
            GROUP BY pr.rating
            ORDER BY pr.rating
        """, (seller_id, start_date, end_date))
        distribution_data = cursor.fetchall()
        
        # Format distribution data
        rating_counts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
        for item in distribution_data:
            rating_counts[item['rating']] = item['count']
        
        close_db_connection(connection, cursor)
        
        return jsonify({
            'trend': {
                'labels': [t['date_label'] for t in trend_data] if trend_data else [],
                'data': [round(float(t['avg_rating']), 1) for t in trend_data] if trend_data else [],
                'label': trend_label
            },
            'distribution': {
                'labels': ['1 Star', '2 Stars', '3 Stars', '4 Stars', '5 Stars'],
                'data': [rating_counts[1], rating_counts[2], rating_counts[3], rating_counts[4], rating_counts[5]]
            },
            'rating_counts': rating_counts
        })
        
    except Exception as e:
        print(f"Error getting chart data: {e}")
        return jsonify({'error': str(e)}), 500
