from flask import Blueprint, render_template, session, jsonify, request
from datetime import datetime, timedelta
import os
import sys

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_config import get_supabase_client
from utils.auth_decorators import seller_required

seller_customer_feedback_bp = Blueprint('seller_customer_feedback', __name__)

@seller_customer_feedback_bp.route('/seller/customer-feedback')
@seller_required
def seller_customer_feedback():
    """Display seller customer feedback page"""
    try:
        seller_id = session.get('seller_id')
        print(f"🔍 Customer Feedback - seller_id: {seller_id}")
        
        supabase = get_supabase_client()
        if not supabase:
            print("❌ Supabase client not available")
            return render_template('seller/seller_customer_feedback.html', error='Database connection failed')
        
        # Get seller information for profile display
        seller_response = supabase.table('sellers').select(
            'first_name, last_name, shop_name, shop_logo'
        ).eq('seller_id', seller_id).execute()
        
        seller_info = seller_response.data[0] if seller_response.data else None
        print(f"👤 Seller info: {seller_info}")
        
        return render_template('seller/seller_customer_feedback.html', seller=seller_info)
        
    except Exception as e:
        print(f"❌ Error loading seller customer feedback: {e}")
        import traceback
        traceback.print_exc()
        return render_template('seller/seller_customer_feedback.html', error=str(e))

@seller_customer_feedback_bp.route('/api/seller/reviews', methods=['GET'])
@seller_required
def get_seller_reviews():
    """API endpoint to get all reviews for seller's products with optional date range"""
    try:
        seller_id = session.get('seller_id')
        date_from = request.args.get('dateFrom')
        date_to = request.args.get('dateTo')
        print(f"🔍 Fetching reviews for seller_id: {seller_id}, date_from: {date_from}, date_to: {date_to}")
        
        supabase = get_supabase_client()
        if not supabase:
            print("❌ Supabase client not available")
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        # Get all products for this seller first
        products_response = supabase.table('products').select('product_id').eq('seller_id', seller_id).execute()
        product_ids = [p['product_id'] for p in products_response.data] if products_response.data else []
        print(f"📦 Found {len(product_ids)} products for seller")
        
        if not product_ids:
            return jsonify({
                'success': True,
                'reviews': [],
                'statistics': {
                    'total_reviews': 0,
                    'avg_rating': 0,
                    'rating_counts': {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
                    'positive_percentage': 0
                },
                'product_quality': {
                    'top_rated': [],
                    'lowest_rated': []
                }
            }), 200
        
        # Build query for reviews. We deliberately omit the orders embed because
        # PostgREST's schema cache may not have the product_reviews -> orders FK
        # registered. We fetch order_numbers in a single batched query below.
        reviews_query = supabase.table('product_reviews').select(
            'review_id, product_id, rating, review_text, created_at, buyer_id, order_id, '
            'products(product_name), buyers(first_name, last_name)'
        ).in_('product_id', product_ids)
        
        # Add date range filtering if provided
        if date_from and date_to:
            start_date = datetime.strptime(date_from, '%Y-%m-%d')
            end_date = datetime.strptime(date_to, '%Y-%m-%d')
            end_date = end_date.replace(hour=23, minute=59, second=59)
            reviews_query = reviews_query.gte('created_at', start_date.isoformat()).lte('created_at', end_date.isoformat())
        
        reviews_response = reviews_query.order('created_at', desc=True).execute()
        print(f"📦 Found {len(reviews_response.data) if reviews_response.data else 0} reviews")

        # Batch-fetch order_numbers for the order_ids referenced in the reviews.
        order_numbers_by_id = {}
        if reviews_response.data:
            order_ids = list({r['order_id'] for r in reviews_response.data if r.get('order_id') is not None})
            if order_ids:
                orders_response = supabase.table('orders').select(
                    'order_id, order_number'
                ).in_('order_id', order_ids).execute()
                if orders_response.data:
                    order_numbers_by_id = {
                        o['order_id']: o.get('order_number') for o in orders_response.data
                    }
        
        # Format reviews data
        reviews = []
        if reviews_response.data:
            for review in reviews_response.data:
                # Flatten nested data
                product_data = review.get('products', {})
                buyer_data = review.get('buyers', {})
                order_number = order_numbers_by_id.get(review.get('order_id')) or 'N/A'

                formatted_review = {
                    'review_id': review['review_id'],
                    'product_id': review['product_id'],
                    'rating': review['rating'],
                    'review_text': review.get('review_text'),
                    'created_at': review['created_at'],
                    'product_name': product_data.get('product_name') if product_data else 'Unknown Product',
                    'buyer_name': f"{buyer_data.get('first_name', '')} {buyer_data.get('last_name', '')}".strip() if buyer_data else 'Unknown Buyer',
                    'order_number': order_number
                }
                reviews.append(formatted_review)
        
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
        
        print(f"📊 Statistics: total={total_reviews}, avg={avg_rating:.1f}, positive={positive_percentage:.0f}%")
        
        # Get product quality analysis - batch fetch all reviews for all products in one query
        product_ratings = []
        all_reviews_response = supabase.table('product_reviews').select(
            'product_id, rating, products(product_name)'
        ).in_('product_id', product_ids).execute()

        # Group ratings by product_id
        ratings_by_product = {}
        names_by_product = {}
        if all_reviews_response.data:
            for r in all_reviews_response.data:
                pid = r['product_id']
                ratings_by_product.setdefault(pid, []).append(r['rating'])
                if pid not in names_by_product:
                    product_data = r.get('products') or {}
                    names_by_product[pid] = product_data.get('product_name', 'Unknown')

        for pid, ratings in ratings_by_product.items():
            if not ratings:
                continue
            product_ratings.append({
                'product_id': pid,
                'product_name': names_by_product.get(pid, 'Unknown'),
                'avg_rating': sum(ratings) / len(ratings),
                'review_count': len(ratings)
            })
        
        # Sort by average rating
        product_ratings.sort(key=lambda x: x['avg_rating'], reverse=True)
        
        top_rated = [p for p in product_ratings if p['avg_rating'] >= 4.5][:5]
        lowest_rated = [p for p in product_ratings if p['avg_rating'] < 4.0][:5]
        
        print(f"📊 Product quality: {len(top_rated)} top rated, {len(lowest_rated)} needs improvement")
        
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
        print(f"❌ Error fetching seller reviews: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@seller_customer_feedback_bp.route('/api/seller/reviews/charts', methods=['GET'])
@seller_required
def get_reviews_charts():
    """API endpoint to get chart data for reviews based on date range"""
    try:
        seller_id = session.get('seller_id')
        date_from = request.args.get('dateFrom')
        date_to = request.args.get('dateTo')
        print(f"🔍 Fetching chart data for seller_id: {seller_id}, date_from: {date_from}, date_to: {date_to}")
        
        supabase = get_supabase_client()
        if not supabase:
            print("❌ Supabase client not available")
            return jsonify({'error': 'Database connection failed'}), 500
        
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
        print(f"📅 Date range: {days_diff} days")
        
        # Get all products for this seller
        products_response = supabase.table('products').select('product_id').eq('seller_id', seller_id).execute()
        product_ids = [p['product_id'] for p in products_response.data] if products_response.data else []
        
        if not product_ids:
            return jsonify({
                'trend': {
                    'labels': [],
                    'data': [],
                    'label': 'No Data'
                },
                'distribution': {
                    'labels': ['1 Star', '2 Stars', '3 Stars', '4 Stars', '5 Stars'],
                    'data': [0, 0, 0, 0, 0]
                },
                'rating_counts': {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
            })
        
        # Get all reviews in date range
        reviews_response = supabase.table('product_reviews').select(
            'rating, created_at'
        ).in_('product_id', product_ids).gte('created_at', start_date.isoformat()).lte('created_at', end_date.isoformat()).execute()
        
        reviews_data = reviews_response.data if reviews_response.data else []
        print(f"📦 Found {len(reviews_data)} reviews in date range")
        
        # Process trend data based on date range
        trend_data = []
        trend_label = ''
        
        if days_diff <= 7:
            # Daily grouping for 7 days or less
            trend_label = 'Daily Average Rating'
            daily_ratings = {}
            
            for review in reviews_data:
                review_date = datetime.fromisoformat(review['created_at'].replace('Z', '+00:00'))
                date_key = review_date.strftime('%b %d')
                
                if date_key not in daily_ratings:
                    daily_ratings[date_key] = []
                daily_ratings[date_key].append(review['rating'])
            
            # Sort by date and calculate averages
            for date_label in sorted(daily_ratings.keys(), key=lambda x: datetime.strptime(x, '%b %d')):
                avg_rating = sum(daily_ratings[date_label]) / len(daily_ratings[date_label])
                trend_data.append({
                    'date_label': date_label,
                    'avg_rating': avg_rating
                })
                
        elif days_diff <= 30:
            # Weekly grouping for up to 30 days
            trend_label = 'Weekly Average Rating'
            weekly_ratings = {}
            
            for review in reviews_data:
                review_date = datetime.fromisoformat(review['created_at'].replace('Z', '+00:00'))
                # Get week start date (Monday)
                week_start = review_date - timedelta(days=review_date.weekday())
                date_key = week_start.strftime('%b %d')
                
                if date_key not in weekly_ratings:
                    weekly_ratings[date_key] = []
                weekly_ratings[date_key].append(review['rating'])
            
            # Sort by date and calculate averages
            for date_label in sorted(weekly_ratings.keys(), key=lambda x: datetime.strptime(x, '%b %d')):
                avg_rating = sum(weekly_ratings[date_label]) / len(weekly_ratings[date_label])
                trend_data.append({
                    'date_label': date_label,
                    'avg_rating': avg_rating
                })
                
        else:
            # Monthly grouping for longer periods
            trend_label = 'Monthly Average Rating'
            monthly_ratings = {}
            
            for review in reviews_data:
                review_date = datetime.fromisoformat(review['created_at'].replace('Z', '+00:00'))
                date_key = review_date.strftime('%b %Y')
                
                if date_key not in monthly_ratings:
                    monthly_ratings[date_key] = []
                monthly_ratings[date_key].append(review['rating'])
            
            # Sort by date and calculate averages
            for date_label in sorted(monthly_ratings.keys(), key=lambda x: datetime.strptime(x, '%b %Y')):
                avg_rating = sum(monthly_ratings[date_label]) / len(monthly_ratings[date_label])
                trend_data.append({
                    'date_label': date_label,
                    'avg_rating': avg_rating
                })
        
        # Get rating distribution for the date range
        rating_counts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
        for review in reviews_data:
            rating = review['rating']
            if rating in rating_counts:
                rating_counts[rating] += 1
        
        print(f"📊 Trend data points: {len(trend_data)}, Rating distribution: {rating_counts}")
        
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
        print(f"❌ Error getting chart data: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500
