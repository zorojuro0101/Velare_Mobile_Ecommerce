from flask import Blueprint, render_template
from database.db_config import get_db_connection, close_db_connection

admin_rider_payouts_bp = Blueprint('admin_rider_payouts', __name__)

@admin_rider_payouts_bp.route('/admin/rider-payouts')
def admin_rider_payouts():
    from flask import request
    from datetime import datetime, timedelta
    
    # Get date range from query parameters
    start_date_str = request.args.get('startDate')
    end_date_str = request.args.get('endDate')
    
    # Calculate date range
    today = datetime.now()
    
    if start_date_str and end_date_str:
        # Custom date range from user input
        start_date = datetime.strptime(start_date_str, '%Y-%m-%d')
        end_date = datetime.strptime(end_date_str, '%Y-%m-%d')
    else:
        # Default to this month
        start_date = today.replace(day=1)
        end_date = today
    
    connection = get_db_connection()
    if not connection:
        return render_template('admin/admin_rider_payouts.html', error="Database connection failed")
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        # Get active riders count
        cursor.execute("""
            SELECT COUNT(*) as count 
            FROM users u 
            JOIN riders r ON u.user_id = r.user_id 
            WHERE u.user_type = 'rider' AND u.status = 'active'
        """)
        active_riders = cursor.fetchone()['count']
        
        # Get individual rider payout data within date range
        cursor.execute("""
            SELECT 
                r.rider_id,
                r.first_name,
                r.last_name,
                r.rating,
                COUNT(CASE WHEN d.status = 'delivered' AND d.delivered_at BETWEEN %s AND %s THEN d.delivery_id END) as total_deliveries,
                COALESCE(SUM(CASE WHEN d.status = 'delivered' AND d.delivered_at BETWEEN %s AND %s THEN d.rider_earnings ELSE 0 END), 0) as total_earnings
            FROM riders r
            JOIN users u ON r.user_id = u.user_id
            LEFT JOIN deliveries d ON r.rider_id = d.rider_id
            WHERE u.user_type = 'rider' AND u.status = 'active'
            GROUP BY r.rider_id, r.first_name, r.last_name, r.rating
            ORDER BY total_deliveries DESC, r.rider_id ASC
        """, (start_date, end_date, start_date, end_date))
        rider_payouts = cursor.fetchall()
        
        # Format rider data for display and calculate total earnings
        formatted_payouts = []
        total_earnings = 0.0
        
        for rider in rider_payouts:
            # No commission deduction - riders get full earnings
            rider_earnings = float(rider['total_earnings'] or 0.0)
            total_earnings += rider_earnings
            
            formatted_payouts.append({
                'rider_id': rider['rider_id'],
                'name': f"{rider['first_name']} {rider['last_name']}",
                'rating': float(rider['rating'] or 0.0),
                'total_deliveries': rider['total_deliveries'] or 0,
                'total_earnings': rider_earnings
            })
        
        cursor.close()
        
        stats = {
            'active_riders': active_riders,
            'total_earnings': total_earnings,
            'rider_payouts': formatted_payouts
        }
        
    except Exception as e:
        print(f"Error fetching rider payouts: {e}")
        stats = {
            'active_riders': 0,
            'total_earnings': 0.0,
            'rider_payouts': []
        }
        if 'cursor' in locals():
            cursor.close()
    finally:
        close_db_connection(connection)
    
    return render_template('admin/admin_rider_payouts.html', stats=stats)


@admin_rider_payouts_bp.route('/admin/rider-payouts/api/withdrawal-requests', methods=['GET'])
def get_withdrawal_requests():
    """Get all pending withdrawal requests"""
    from flask import jsonify
    
    connection = get_db_connection()
    if not connection:
        return jsonify({'error': 'Database connection failed'}), 500
    
    cursor = connection.cursor(dictionary=True)
    
    try:
        cursor.execute("""
            SELECT 
                rw.withdrawal_id,
                rw.rider_id,
                rw.amount,
                rw.withdrawal_method,
                rw.status,
                rw.requested_at,
                rw.notes,
                CONCAT(r.first_name, ' ', r.last_name) as rider_name,
                u.email as rider_email
            FROM rider_withdrawals rw
            JOIN riders r ON rw.rider_id = r.rider_id
            JOIN users u ON r.user_id = u.user_id
            WHERE rw.status = 'pending'
            ORDER BY rw.requested_at DESC
        """)
        
        requests = cursor.fetchall()
        
        formatted_requests = []
        for req in requests:
            formatted_requests.append({
                'withdrawalId': req['withdrawal_id'],
                'riderId': req['rider_id'],
                'riderName': req['rider_name'],
                'riderEmail': req['rider_email'],
                'amount': float(req['amount']),
                'method': req['withdrawal_method'],
                'status': req['status'],
                'requestedAt': req['requested_at'].strftime('%Y-%m-%d %H:%M:%S'),
                'notes': req['notes']
            })
        
        return jsonify({'success': True, 'requests': formatted_requests}), 200
        
    except Exception as e:
        print(f"Error fetching withdrawal requests: {e}")
        return jsonify({'error': str(e)}), 500
    
    finally:
        close_db_connection(connection, cursor)


@admin_rider_payouts_bp.route('/admin/rider-payouts/api/approve-withdrawal', methods=['POST'])
def approve_withdrawal():
    """Approve a withdrawal request"""
    from flask import jsonify, request
    
    data = request.get_json()
    withdrawal_id = data.get('withdrawalId')
    
    if not withdrawal_id:
        return jsonify({'error': 'Withdrawal ID required'}), 400
    
    connection = get_db_connection()
    if not connection:
        return jsonify({'error': 'Database connection failed'}), 500
    
    cursor = connection.cursor(dictionary=True)
    
    try:
        # Update withdrawal status to completed
        cursor.execute("""
            UPDATE rider_withdrawals
            SET status = 'completed', processed_at = NOW()
            WHERE withdrawal_id = %s AND status = 'pending'
        """, (withdrawal_id,))
        
        if cursor.rowcount == 0:
            return jsonify({'error': 'Withdrawal not found or already processed'}), 404
        
        connection.commit()
        
        return jsonify({'success': True, 'message': 'Withdrawal approved successfully'}), 200
        
    except Exception as e:
        connection.rollback()
        print(f"Error approving withdrawal: {e}")
        return jsonify({'error': str(e)}), 500
    
    finally:
        close_db_connection(connection, cursor)


@admin_rider_payouts_bp.route('/admin/rider-payouts/api/reject-withdrawal', methods=['POST'])
def reject_withdrawal():
    """Reject a withdrawal request"""
    from flask import jsonify, request
    
    data = request.get_json()
    withdrawal_id = data.get('withdrawalId')
    reason = data.get('reason', '')
    
    if not withdrawal_id:
        return jsonify({'error': 'Withdrawal ID required'}), 400
    
    connection = get_db_connection()
    if not connection:
        return jsonify({'error': 'Database connection failed'}), 500
    
    cursor = connection.cursor(dictionary=True)
    
    try:
        # Update withdrawal status to rejected
        cursor.execute("""
            UPDATE rider_withdrawals
            SET status = 'rejected', 
                processed_at = NOW(),
                notes = CONCAT(COALESCE(notes, ''), '\nRejection reason: ', %s)
            WHERE withdrawal_id = %s AND status = 'pending'
        """, (reason, withdrawal_id))
        
        if cursor.rowcount == 0:
            return jsonify({'error': 'Withdrawal not found or already processed'}), 404
        
        connection.commit()
        
        return jsonify({'success': True, 'message': 'Withdrawal rejected'}), 200
        
    except Exception as e:
        connection.rollback()
        print(f"Error rejecting withdrawal: {e}")
        return jsonify({'error': str(e)}), 500
    
    finally:
        close_db_connection(connection, cursor)


@admin_rider_payouts_bp.route('/admin/rider-payouts/api/commission-deductions', methods=['GET'])
def get_commission_deductions():
    """Get platform commission deductions for free shipping"""
    from flask import jsonify
    
    connection = get_db_connection()
    if not connection:
        return jsonify({'error': 'Database connection failed'}), 500
    
    cursor = connection.cursor(dictionary=True)
    
    try:
        # Get deliveries where platform paid the rider (free shipping)
        cursor.execute("""
            SELECT 
                d.delivery_id,
                d.order_id,
                d.rider_earnings,
                d.delivered_at,
                o.order_number,
                o.commission_amount,
                CONCAT(r.first_name, ' ', r.last_name) as rider_name,
                CONCAT(b.first_name, ' ', b.last_name) as buyer_name
            FROM deliveries d
            JOIN orders o ON d.order_id = o.order_id
            JOIN riders r ON d.rider_id = r.rider_id
            JOIN buyers b ON o.buyer_id = b.buyer_id
            WHERE d.paid_by_platform = 1
            AND d.status = 'delivered'
            ORDER BY d.delivered_at DESC
            LIMIT 50
        """)
        
        deductions = cursor.fetchall()
        
        formatted_deductions = []
        total_deducted = 0
        
        for ded in deductions:
            amount = float(ded['rider_earnings'])
            total_deducted += amount
            
            formatted_deductions.append({
                'deliveryId': ded['delivery_id'],
                'orderNumber': ded['order_number'],
                'riderName': ded['rider_name'],
                'buyerName': ded['buyer_name'],
                'amount': amount,
                'commission': float(ded['commission_amount']),
                'deliveredAt': ded['delivered_at'].strftime('%Y-%m-%d %H:%M:%S')
            })
        
        return jsonify({
            'success': True, 
            'deductions': formatted_deductions,
            'totalDeducted': total_deducted
        }), 200
        
    except Exception as e:
        print(f"Error fetching commission deductions: {e}")
        return jsonify({'error': str(e)}), 500
    
    finally:
        close_db_connection(connection, cursor)
