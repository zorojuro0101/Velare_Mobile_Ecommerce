from flask import Blueprint, render_template, jsonify, request
from database.db_config import get_supabase_client
from datetime import datetime, timedelta
from utils.auth_decorators import admin_required

admin_dashboard_bp = Blueprint('admin_dashboard', __name__)

def calculate_monthly_growth(current_count, previous_count):
    """Calculate percentage growth between current and previous month"""
    if previous_count == 0:
        return 0.0 if current_count == 0 else 100.0
    return ((current_count - previous_count) / previous_count) * 100

def get_all_time_stats(supabase):
    """Get statistics for display (all time counts)"""
    stats = {
        'total_users': 0,
        'active_sellers': 0,
        'total_orders': 0,
        'total_revenue': 0.0
    }
    
    try:
        # Total users count (all time for display)
        users_response = supabase.table('users').select('user_id', count='exact').execute()
        stats['total_users'] = users_response.count
        
        # Active sellers count (all time for display)
        sellers_response = supabase.table('users').select('user_id', count='exact').eq('user_type', 'seller').eq('status', 'active').execute()
        stats['active_sellers'] = sellers_response.count
        
        # Total orders count (all time for display)
        orders_response = supabase.table('orders').select('order_id', count='exact').execute()
        stats['total_orders'] = orders_response.count
        
        # Total revenue from delivered orders (all time for display)
        revenue_response = supabase.table('orders').select('total_amount').eq('order_status', 'delivered').execute()
        stats['total_revenue'] = sum(order['total_amount'] for order in revenue_response.data if order.get('total_amount'))
        
    except Exception as e:
        print(f"❌ Error getting all-time stats: {str(e)}")
    
    return stats

def get_previous_month_stats(supabase):
    """Get statistics for previous month"""
    stats = {
        'total_users': 0,
        'active_sellers': 0,
        'total_orders': 0,
        'total_revenue': 0.0
    }
    
    try:
        # Calculate previous month date range
        today = datetime.utcnow()
        first_day_current_month = today.replace(day=1)
        last_day_previous_month = first_day_current_month - timedelta(days=1)
        first_day_previous_month = last_day_previous_month.replace(day=1)
        
        start_date = first_day_previous_month.isoformat()
        end_date = (last_day_previous_month.replace(hour=23, minute=59, second=59)).isoformat()
        
        # Total users count (previous month)
        users_response = supabase.table('users').select('user_id', count='exact').gte('created_at', start_date).lte('created_at', end_date).execute()
        stats['total_users'] = users_response.count
        
        # Active sellers count (previous month)
        sellers_response = supabase.table('users').select('user_id', count='exact').eq('user_type', 'seller').eq('status', 'active').gte('created_at', start_date).lte('created_at', end_date).execute()
        stats['active_sellers'] = sellers_response.count
        
        # Total orders count (previous month)
        orders_response = supabase.table('orders').select('order_id', count='exact').gte('created_at', start_date).lte('created_at', end_date).execute()
        stats['total_orders'] = orders_response.count
        
        # Total revenue from delivered orders (previous month)
        revenue_response = supabase.table('orders').select('total_amount').eq('order_status', 'delivered').gte('created_at', start_date).lte('created_at', end_date).execute()
        stats['total_revenue'] = sum(order['total_amount'] for order in revenue_response.data if order.get('total_amount'))
        
    except Exception as e:
        print(f"❌ Error getting previous month stats: {str(e)}")
    
    return stats

@admin_dashboard_bp.route('/admin/dashboard')
@admin_required
def admin_dashboard():
    print("📊 Loading admin dashboard...")
    supabase = get_supabase_client()
    
    try:
        # Get all-time stats for display
        current_stats = get_all_time_stats(supabase)
        
        # Get previous month stats
        previous_stats = get_previous_month_stats(supabase)
        
        # Calculate growth percentages
        stats = {
            'total_users': current_stats['total_users'],
            'active_sellers': current_stats['active_sellers'], 
            'total_orders': current_stats['total_orders'],
            'total_revenue': current_stats['total_revenue'],
            'user_growth': calculate_monthly_growth(current_stats['total_users'], previous_stats['total_users']),
            'seller_growth': calculate_monthly_growth(current_stats['active_sellers'], previous_stats['active_sellers']),
            'order_growth': calculate_monthly_growth(current_stats['total_orders'], previous_stats['total_orders']),
            'revenue_growth': calculate_monthly_growth(current_stats['total_revenue'], previous_stats['total_revenue'])
        }
        
        print(f"✅ Dashboard stats loaded successfully")
        
    except Exception as e:
        print(f"❌ Error fetching dashboard stats: {e}")
        # Fallback to total counts if monthly queries fail
        
        # Total users count (all time)
        users_response = supabase.table('users').select('user_id', count='exact').execute()
        total_users = users_response.count
        
        # Active sellers count (all time)
        sellers_response = supabase.table('users').select('user_id', count='exact').eq('user_type', 'seller').eq('status', 'active').execute()
        active_sellers = sellers_response.count
        
        # Total orders count (all time)
        orders_response = supabase.table('orders').select('order_id', count='exact').execute()
        total_orders = orders_response.count
        
        # Total revenue from delivered orders (all time)
        revenue_response = supabase.table('orders').select('total_amount').eq('order_status', 'delivered').execute()
        total_revenue = sum(order['total_amount'] for order in revenue_response.data if order.get('total_amount'))
        
        stats = {
            'total_users': total_users,
            'active_sellers': active_sellers,
            'total_orders': total_orders,
            'total_revenue': total_revenue,
            'user_growth': 0.0,
            'seller_growth': 0.0,
            'order_growth': 0.0,
            'revenue_growth': 0.0
        }
    
    return render_template('admin/admin_dashboard.html', stats=stats)

@admin_dashboard_bp.route('/admin/dashboard/sales-data')
@admin_required
def get_sales_data():
    """API endpoint to fetch sales data for chart"""
    period = request.args.get('period', '7days')
    start_date = request.args.get('start_date')
    end_date = request.args.get('end_date')
    
    print(f"📈 Fetching sales data for period: {period}")
    supabase = get_supabase_client()
    
    try:
        # Determine date range and grouping
        is_monthly = False
        
        # Handle custom date range
        if period == 'custom' and start_date and end_date:
            try:
                start_dt = datetime.strptime(start_date, '%Y-%m-%d')
                end_dt = datetime.strptime(end_date, '%Y-%m-%d')
                
                # Calculate days difference to determine grouping
                days_diff = (end_dt - start_dt).days
                is_monthly = days_diff > 90
                
                # Query with custom date range
                start_iso = start_dt.isoformat()
                end_iso = (end_dt.replace(hour=23, minute=59, second=59)).isoformat()
                
            except ValueError:
                return jsonify({'error': 'Invalid date format'}), 400
        else:
            # Determine date range based on period
            if period == '7days':
                days = 7
            elif period == '30days':
                days = 30
            elif period == '90days':
                days = 90
            elif period == 'year':
                days = 365
                is_monthly = True
            else:
                days = 7
            
            # Calculate start date
            end_dt = datetime.utcnow()
            start_dt = end_dt - timedelta(days=days)
            start_iso = start_dt.isoformat()
            end_iso = end_dt.isoformat()
        
        # Fetch orders data
        response = supabase.table('orders').select('created_at, total_amount').eq('order_status', 'delivered').gte('created_at', start_iso).lte('created_at', end_iso).order('created_at').execute()
        
        orders = response.data
        
        # Group data by date
        from collections import defaultdict
        grouped_data = defaultdict(lambda: {'total_sales': 0.0, 'order_count': 0})
        
        for order in orders:
            created_at = datetime.fromisoformat(order['created_at'].replace('Z', '+00:00'))
            
            if is_monthly:
                # Group by month
                date_key = created_at.strftime('%Y-%m')
            else:
                # Group by day
                date_key = created_at.strftime('%Y-%m-%d')
            
            grouped_data[date_key]['total_sales'] += float(order['total_amount']) if order.get('total_amount') else 0
            grouped_data[date_key]['order_count'] += 1
        
        # Format data for chart
        labels = []
        sales_data = []
        order_counts = []
        
        # Sort by date
        sorted_dates = sorted(grouped_data.keys())
        
        for date_key in sorted_dates:
            data = grouped_data[date_key]
            
            if is_monthly:
                # Format as "Jan 2024"
                date_obj = datetime.strptime(date_key, '%Y-%m')
                labels.append(date_obj.strftime('%b %Y'))
            else:
                # Format as "Jan 15"
                date_obj = datetime.strptime(date_key, '%Y-%m-%d')
                labels.append(date_obj.strftime('%b %d'))
            
            sales_data.append(data['total_sales'])
            order_counts.append(data['order_count'])
        
        print(f"✅ Sales data fetched: {len(labels)} data points")
        
        return jsonify({
            'labels': labels,
            'sales': sales_data,
            'orders': order_counts
        })
        
    except Exception as e:
        print(f"❌ Error fetching sales data: {e}")
        return jsonify({'error': str(e)}), 500
