from flask import Blueprint, render_template, jsonify, request
from database.db_config import get_db_connection, close_db_connection
from datetime import datetime, timedelta
from utils.auth_decorators import admin_required

admin_dashboard_bp = Blueprint('admin_dashboard', __name__)

def calculate_monthly_growth(current_count, previous_count):
    """Calculate percentage growth between current and previous month"""
    if previous_count == 0:
        return 0.0 if current_count == 0 else 100.0
    return ((current_count - previous_count) / previous_count) * 100

def get_all_time_stats(connection):
    """Get statistics for display (all time counts)"""
    cursor = connection.cursor(dictionary=True)
    stats = {
        'total_users': 0,
        'active_sellers': 0,
        'total_orders': 0,
        'total_revenue': 0.0
    }
    
    try:
        # Total users count (all time for display)
        cursor.execute("SELECT COUNT(*) as count FROM users")
        stats['total_users'] = cursor.fetchone()['count']
        
        # Active sellers count (all time for display)
        cursor.execute("SELECT COUNT(*) as count FROM users WHERE user_type = 'seller' AND status = 'active'")
        stats['active_sellers'] = cursor.fetchone()['count']
        
        # Total orders count (all time for display)
        cursor.execute("SELECT COUNT(*) as count FROM orders")
        stats['total_orders'] = cursor.fetchone()['count']
        
        # Total revenue from delivered orders (all time for display)
        cursor.execute("SELECT SUM(total_amount) as total FROM orders WHERE order_status = 'delivered'")
        result = cursor.fetchone()
        stats['total_revenue'] = result['total'] if result['total'] else 0.0
        
    finally:
        cursor.close()
    
    return stats

def get_previous_month_stats(connection):
    """Get statistics for previous month"""
    cursor = connection.cursor(dictionary=True)
    stats = {
        'total_users': 0,
        'active_sellers': 0,
        'total_orders': 0,
        'total_revenue': 0.0
    }
    
    try:
        # Total users count (previous month)
        cursor.execute("""
            SELECT COUNT(*) as count FROM users 
            WHERE MONTH(created_at) = MONTH(CURRENT_DATE() - INTERVAL 1 MONTH) 
            AND YEAR(created_at) = YEAR(CURRENT_DATE() - INTERVAL 1 MONTH)
        """)
        stats['total_users'] = cursor.fetchone()['count']
        
        # Active sellers count (previous month)
        cursor.execute("""
            SELECT COUNT(*) as count FROM users 
            WHERE user_type = 'seller' AND status = 'active'
            AND MONTH(created_at) = MONTH(CURRENT_DATE() - INTERVAL 1 MONTH) 
            AND YEAR(created_at) = YEAR(CURRENT_DATE() - INTERVAL 1 MONTH)
        """)
        stats['active_sellers'] = cursor.fetchone()['count']
        
        # Total orders count (previous month)
        cursor.execute("""
            SELECT COUNT(*) as count FROM orders 
            WHERE MONTH(created_at) = MONTH(CURRENT_DATE() - INTERVAL 1 MONTH) 
            AND YEAR(created_at) = YEAR(CURRENT_DATE() - INTERVAL 1 MONTH)
        """)
        stats['total_orders'] = cursor.fetchone()['count']
        
        # Total revenue from delivered orders (previous month)
        cursor.execute("""
            SELECT SUM(total_amount) as total FROM orders 
            WHERE order_status = 'delivered'
            AND MONTH(created_at) = MONTH(CURRENT_DATE() - INTERVAL 1 MONTH) 
            AND YEAR(created_at) = YEAR(CURRENT_DATE() - INTERVAL 1 MONTH)
        """)
        result = cursor.fetchone()
        stats['total_revenue'] = result['total'] if result['total'] else 0.0
        
    finally:
        cursor.close()
    
    return stats

@admin_dashboard_bp.route('/admin/dashboard')
@admin_required
def admin_dashboard():
    connection = get_db_connection()
    if not connection:
        return render_template('admin/admin_dashboard.html', error="Database connection failed")
    
    try:
        # Get all-time stats for display
        current_stats = get_all_time_stats(connection)
        
        # Get previous month stats
        previous_stats = get_previous_month_stats(connection)
        
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
        
    except Exception as e:
        print(f"Error fetching dashboard stats: {e}")
        # Fallback to total counts if monthly queries fail
        cursor = connection.cursor(dictionary=True)
        
        # Total users count (all time)
        cursor.execute("SELECT COUNT(*) as count FROM users")
        total_users = cursor.fetchone()['count']
        
        # Active sellers count (all time)
        cursor.execute("SELECT COUNT(*) as count FROM users WHERE user_type = 'seller' AND status = 'active'")
        active_sellers = cursor.fetchone()['count']
        
        # Total orders count (all time)
        cursor.execute("SELECT COUNT(*) as count FROM orders")
        total_orders = cursor.fetchone()['count']
        
        # Total revenue from delivered orders (all time)
        cursor.execute("SELECT SUM(total_amount) as total FROM orders WHERE order_status = 'delivered'")
        result = cursor.fetchone()
        total_revenue = result['total'] if result['total'] else 0.0
        
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
        
        cursor.close()
    finally:
        close_db_connection(connection)
    
    return render_template('admin/admin_dashboard.html', stats=stats)

@admin_dashboard_bp.route('/admin/dashboard/sales-data')
@admin_required
def get_sales_data():
    """API endpoint to fetch sales data for chart"""
    period = request.args.get('period', '7days')
    start_date = request.args.get('start_date')
    end_date = request.args.get('end_date')
    
    connection = get_db_connection()
    if not connection:
        return jsonify({'error': 'Database connection failed'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        # Handle custom date range
        if period == 'custom' and start_date and end_date:
            # Validate dates
            try:
                start_dt = datetime.strptime(start_date, '%Y-%m-%d')
                end_dt = datetime.strptime(end_date, '%Y-%m-%d')
                
                # Calculate days difference to determine grouping
                days_diff = (end_dt - start_dt).days
                
                if days_diff > 90:
                    # Group by month for long ranges
                    group_by = 'DATE_FORMAT(created_at, "%Y-%m")'
                    is_monthly = True
                else:
                    # Group by day for shorter ranges
                    group_by = 'DATE(created_at)'
                    is_monthly = False
                
                # Query with custom date range
                query = f"""
                    SELECT 
                        {group_by} as date,
                        COUNT(*) as order_count,
                        SUM(total_amount) as total_sales
                    FROM orders
                    WHERE DATE(created_at) BETWEEN %s AND %s
                    AND order_status = 'delivered'
                    GROUP BY {group_by}
                    ORDER BY date ASC
                """
                
                cursor.execute(query, (start_date, end_date))
                
            except ValueError:
                return jsonify({'error': 'Invalid date format'}), 400
        else:
            # Determine date range based on period
            if period == '7days':
                days = 7
                group_by = 'DATE(created_at)'
                is_monthly = False
            elif period == '30days':
                days = 30
                group_by = 'DATE(created_at)'
                is_monthly = False
            elif period == '90days':
                days = 90
                group_by = 'DATE(created_at)'
                is_monthly = False
            elif period == 'year':
                days = 365
                group_by = 'DATE_FORMAT(created_at, "%Y-%m")'
                is_monthly = True
            else:
                days = 7
                group_by = 'DATE(created_at)'
                is_monthly = False
            
            # Query to get sales data grouped by date
            query = f"""
                SELECT 
                    {group_by} as date,
                    COUNT(*) as order_count,
                    SUM(total_amount) as total_sales
                FROM orders
                WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL {days} DAY)
                AND order_status = 'delivered'
                GROUP BY {group_by}
                ORDER BY date ASC
            """
            
            cursor.execute(query)
        
        results = cursor.fetchall()
        
        # Format data for chart
        labels = []
        sales_data = []
        order_counts = []
        
        for row in results:
            # Handle different date types from MySQL
            date_value = row['date']
            
            if is_monthly:
                # For monthly grouping, date is a string like "2024-11"
                if isinstance(date_value, str):
                    date_obj = datetime.strptime(date_value, '%Y-%m')
                else:
                    # If it's a date object, convert to datetime
                    date_obj = datetime.combine(date_value, datetime.min.time())
                labels.append(date_obj.strftime('%b %Y'))
            else:
                # For daily grouping, date is a date object
                if isinstance(date_value, str):
                    date_obj = datetime.strptime(date_value, '%Y-%m-%d')
                elif hasattr(date_value, 'strftime'):
                    # It's a date or datetime object
                    labels.append(date_value.strftime('%b %d'))
                    sales_data.append(float(row['total_sales']) if row['total_sales'] else 0)
                    order_counts.append(row['order_count'])
                    continue
                else:
                    # Fallback to string representation
                    labels.append(str(date_value))
                    sales_data.append(float(row['total_sales']) if row['total_sales'] else 0)
                    order_counts.append(row['order_count'])
                    continue
                
                labels.append(date_obj.strftime('%b %d'))
            
            sales_data.append(float(row['total_sales']) if row['total_sales'] else 0)
            order_counts.append(row['order_count'])
        
        cursor.close()
        
        return jsonify({
            'labels': labels,
            'sales': sales_data,
            'orders': order_counts
        })
        
    except Exception as e:
        print(f"Error fetching sales data: {e}")
        return jsonify({'error': str(e)}), 500
    finally:
        close_db_connection(connection)
