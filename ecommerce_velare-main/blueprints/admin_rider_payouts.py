from flask import Blueprint, render_template
from database.db_config import get_supabase_client

admin_rider_payouts_bp = Blueprint('admin_rider_payouts', __name__)

@admin_rider_payouts_bp.route('/admin/rider-payouts')
def admin_rider_payouts():
    from flask import request
    from datetime import datetime, timedelta
    
    print("\n" + "="*80)
    print("📊 [ADMIN RIDER PAYOUTS] Loading page...")
    print("="*80 + "\n")
    
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
    
    print(f"📅 Date range: {start_date.date()} to {end_date.date()}")
    
    supabase = get_supabase_client()
    if not supabase:
        print("❌ Supabase connection failed")
        return render_template('admin/admin_rider_payouts.html', error="Database connection failed")
    
    try:
        # Get active riders count
        print("🔍 Fetching active riders count...")
        riders_response = supabase.table('users').select('user_id', count='exact').eq('user_type', 'rider').eq('status', 'active').execute()
        active_riders = riders_response.count if riders_response.count else 0
        print(f"✅ Active riders: {active_riders}")
        
        # Get all active riders with their info
        print("🔍 Fetching rider data...")
        riders_data_response = supabase.table('riders').select('''
            rider_id,
            first_name,
            last_name,
            rating,
            users!inner(status, user_type)
        ''').eq('users.user_type', 'rider').eq('users.status', 'active').execute()
        
        riders_data = riders_data_response.data if riders_data_response.data else []
        print(f"✅ Found {len(riders_data)} riders")
        
        # Get deliveries within date range
        print("🔍 Fetching deliveries...")
        start_date_iso = start_date.isoformat()
        end_date_iso = end_date.replace(hour=23, minute=59, second=59).isoformat()
        
        deliveries_response = supabase.table('deliveries').select('''
            delivery_id,
            rider_id,
            rider_earnings,
            status,
            delivered_at
        ''').eq('status', 'delivered').gte('delivered_at', start_date_iso).lte('delivered_at', end_date_iso).execute()
        
        deliveries = deliveries_response.data if deliveries_response.data else []
        print(f"✅ Found {len(deliveries)} deliveries in date range")
        
        # Group deliveries by rider
        rider_deliveries = {}
        for delivery in deliveries:
            rider_id = delivery['rider_id']
            if rider_id not in rider_deliveries:
                rider_deliveries[rider_id] = {
                    'count': 0,
                    'earnings': 0.0
                }
            rider_deliveries[rider_id]['count'] += 1
            rider_deliveries[rider_id]['earnings'] += float(delivery.get('rider_earnings', 0) or 0)
        
        # Format rider data for display and calculate total earnings
        formatted_payouts = []
        total_earnings = 0.0
        
        for rider in riders_data:
            rider_id = rider['rider_id']
            delivery_stats = rider_deliveries.get(rider_id, {'count': 0, 'earnings': 0.0})
            
            rider_earnings = delivery_stats['earnings']
            total_earnings += rider_earnings
            
            formatted_payouts.append({
                'rider_id': rider_id,
                'name': f"{rider['first_name']} {rider['last_name']}",
                'rating': float(rider.get('rating', 0) or 0.0),
                'total_deliveries': delivery_stats['count'],
                'total_earnings': rider_earnings
            })
        
        # Sort by total deliveries descending
        formatted_payouts.sort(key=lambda x: x['total_deliveries'], reverse=True)
        
        stats = {
            'active_riders': active_riders,
            'total_earnings': total_earnings,
            'rider_payouts': formatted_payouts
        }
        
        print(f"✅ Total earnings: ₱{total_earnings:,.2f}")
        print("="*80 + "\n")
        
    except Exception as e:
        print(f"❌ Error fetching rider payouts: {e}")
        import traceback
        traceback.print_exc()
        stats = {
            'active_riders': 0,
            'total_earnings': 0.0,
            'rider_payouts': []
        }
    
    return render_template('admin/admin_rider_payouts.html', stats=stats)


@admin_rider_payouts_bp.route('/admin/rider-payouts/api/withdrawal-requests', methods=['GET'])
def get_withdrawal_requests():
    """Get all pending withdrawal requests using Supabase"""
    from flask import jsonify
    
    print("\n🔍 [WITHDRAWAL REQUESTS] Fetching pending requests...")
    
    supabase = get_supabase_client()
    if not supabase:
        print("❌ Supabase connection failed")
        return jsonify({'error': 'Database connection failed'}), 500
    
    try:
        # Get pending withdrawal requests with rider info
        response = supabase.table('rider_withdrawals').select('''
            withdrawal_id,
            rider_id,
            amount,
            withdrawal_method,
            status,
            requested_at,
            notes,
            riders(
                first_name,
                last_name,
                users(email)
            )
        ''').eq('status', 'pending').order('requested_at', desc=True).execute()
        
        requests = response.data if response.data else []
        print(f"✅ Found {len(requests)} pending requests")
        
        formatted_requests = []
        for req in requests:
            rider = req.get('riders', {})
            user = rider.get('users', {}) if isinstance(rider, dict) else {}
            
            formatted_requests.append({
                'withdrawalId': req['withdrawal_id'],
                'riderId': req['rider_id'],
                'riderName': f"{rider.get('first_name', '')} {rider.get('last_name', '')}".strip() if isinstance(rider, dict) else 'Unknown',
                'riderEmail': user.get('email', 'N/A') if isinstance(user, dict) else 'N/A',
                'amount': float(req['amount']),
                'method': req['withdrawal_method'],
                'status': req['status'],
                'requestedAt': req['requested_at'],
                'notes': req.get('notes', '')
            })
        
        return jsonify({'success': True, 'requests': formatted_requests}), 200
        
    except Exception as e:
        print(f"❌ Error fetching withdrawal requests: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


@admin_rider_payouts_bp.route('/admin/rider-payouts/api/approve-withdrawal', methods=['POST'])
def approve_withdrawal():
    """Approve a withdrawal request using Supabase"""
    from flask import jsonify, request
    from datetime import datetime
    
    data = request.get_json()
    withdrawal_id = data.get('withdrawalId')
    
    print(f"\n✅ [APPROVE WITHDRAWAL] Processing withdrawal_id: {withdrawal_id}")
    
    if not withdrawal_id:
        return jsonify({'error': 'Withdrawal ID required'}), 400
    
    supabase = get_supabase_client()
    if not supabase:
        print("❌ Supabase connection failed")
        return jsonify({'error': 'Database connection failed'}), 500
    
    try:
        # Update withdrawal status to completed
        update_response = supabase.table('rider_withdrawals').update({
            'status': 'completed',
            'processed_at': datetime.now().isoformat()
        }).eq('withdrawal_id', withdrawal_id).eq('status', 'pending').execute()
        
        if not update_response.data:
            print(f"❌ Withdrawal not found or already processed")
            return jsonify({'error': 'Withdrawal not found or already processed'}), 404
        
        print(f"✅ Withdrawal approved successfully")
        return jsonify({'success': True, 'message': 'Withdrawal approved successfully'}), 200
        
    except Exception as e:
        print(f"❌ Error approving withdrawal: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


@admin_rider_payouts_bp.route('/admin/rider-payouts/api/reject-withdrawal', methods=['POST'])
def reject_withdrawal():
    """Reject a withdrawal request using Supabase"""
    from flask import jsonify, request
    from datetime import datetime
    
    data = request.get_json()
    withdrawal_id = data.get('withdrawalId')
    reason = data.get('reason', '')
    
    print(f"\n❌ [REJECT WITHDRAWAL] Processing withdrawal_id: {withdrawal_id}")
    print(f"📝 Reason: {reason}")
    
    if not withdrawal_id:
        return jsonify({'error': 'Withdrawal ID required'}), 400
    
    supabase = get_supabase_client()
    if not supabase:
        print("❌ Supabase connection failed")
        return jsonify({'error': 'Database connection failed'}), 500
    
    try:
        # Get current notes
        current_response = supabase.table('rider_withdrawals').select('notes').eq('withdrawal_id', withdrawal_id).eq('status', 'pending').execute()
        
        if not current_response.data:
            print(f"❌ Withdrawal not found or already processed")
            return jsonify({'error': 'Withdrawal not found or already processed'}), 404
        
        current_notes = current_response.data[0].get('notes', '') or ''
        updated_notes = f"{current_notes}\nRejection reason: {reason}".strip()
        
        # Update withdrawal status to rejected
        update_response = supabase.table('rider_withdrawals').update({
            'status': 'rejected',
            'processed_at': datetime.now().isoformat(),
            'notes': updated_notes
        }).eq('withdrawal_id', withdrawal_id).eq('status', 'pending').execute()
        
        if not update_response.data:
            print(f"❌ Withdrawal not found or already processed")
            return jsonify({'error': 'Withdrawal not found or already processed'}), 404
        
        print(f"✅ Withdrawal rejected successfully")
        return jsonify({'success': True, 'message': 'Withdrawal rejected'}), 200
        
    except Exception as e:
        print(f"❌ Error rejecting withdrawal: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


@admin_rider_payouts_bp.route('/admin/rider-payouts/api/commission-deductions', methods=['GET'])
def get_commission_deductions():
    """Get platform commission deductions for free shipping using Supabase"""
    from flask import jsonify
    
    print("\n💰 [COMMISSION DEDUCTIONS] Fetching platform-paid deliveries...")
    
    supabase = get_supabase_client()
    if not supabase:
        print("❌ Supabase connection failed")
        return jsonify({'error': 'Database connection failed'}), 500
    
    try:
        # Get deliveries where platform paid the rider (free shipping)
        response = supabase.table('deliveries').select('''
            delivery_id,
            order_id,
            rider_earnings,
            delivered_at,
            paid_by_platform,
            orders(
                order_number,
                commission_amount,
                buyers(first_name, last_name)
            ),
            riders(first_name, last_name)
        ''').eq('paid_by_platform', True).eq('status', 'delivered').order('delivered_at', desc=True).limit(50).execute()
        
        deductions = response.data if response.data else []
        print(f"✅ Found {len(deductions)} platform-paid deliveries")
        
        formatted_deductions = []
        total_deducted = 0
        
        for ded in deductions:
            order = ded.get('orders', {})
            rider = ded.get('riders', {})
            buyer = order.get('buyers', {}) if isinstance(order, dict) else {}
            
            amount = float(ded.get('rider_earnings', 0) or 0)
            total_deducted += amount
            
            formatted_deductions.append({
                'deliveryId': ded['delivery_id'],
                'orderNumber': order.get('order_number', 'N/A') if isinstance(order, dict) else 'N/A',
                'riderName': f"{rider.get('first_name', '')} {rider.get('last_name', '')}".strip() if isinstance(rider, dict) else 'Unknown',
                'buyerName': f"{buyer.get('first_name', '')} {buyer.get('last_name', '')}".strip() if isinstance(buyer, dict) else 'Unknown',
                'amount': amount,
                'commission': float(order.get('commission_amount', 0) or 0) if isinstance(order, dict) else 0,
                'deliveredAt': ded.get('delivered_at', '')
            })
        
        print(f"✅ Total deducted: ₱{total_deducted:,.2f}")
        
        return jsonify({
            'success': True, 
            'deductions': formatted_deductions,
            'totalDeducted': total_deducted
        }), 200
        
    except Exception as e:
        print(f"❌ Error fetching commission deductions: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500
