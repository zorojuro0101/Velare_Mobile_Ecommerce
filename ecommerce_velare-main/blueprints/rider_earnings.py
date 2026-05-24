from flask import Blueprint, render_template, session, redirect, url_for, jsonify, request
import sys
import os
from datetime import datetime, timedelta

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.supabase_helper import *

rider_earnings_bp = Blueprint('rider_earnings', __name__)

@rider_earnings_bp.route('/rider/earnings')
def rider_earnings():
    print(f"\n{'='*80}")
    print(f"💰 [EARNINGS PAGE] Loading earnings page...")
    print(f"{'='*80}\n")
    
    # Check if user is logged in and is a rider
    if 'user_id' not in session or session.get('user_type') != 'rider':
        return redirect(url_for('auth.login'))
    
    try:
        # Get rider information from Supabase
        rider_data = get_rider_by_user_id(session['user_id'])
        
        if not rider_data:
            print("❌ Rider profile not found")
            return render_template('rider/rider_earnings.html', error='Rider profile not found')
        
        print(f"✅ Rider: {rider_data.get('first_name')} {rider_data.get('last_name')}")
        print(f"{'='*80}\n")
        return render_template('rider/rider_earnings.html', rider=rider_data)
        
    except Exception as e:
        print(f"❌ Error fetching rider data: {e}")
        return render_template('rider/rider_earnings.html', error='Failed to load rider data')

@rider_earnings_bp.route('/rider/earnings/api/earnings-data', methods=['GET'])
def get_earnings_data():
    """API endpoint to fetch earnings data for the current rider"""
    print(f"\n{'='*80}")
    print(f"💰 [EARNINGS DATA] Fetching earnings...")
    print(f"{'='*80}\n")
    
    if 'user_id' not in session or session.get('user_type') != 'rider':
        return jsonify({'error': 'Unauthorized'}), 401
    
    start_date = request.args.get('startDate')
    end_date = request.args.get('endDate')
    
    try:
        # Get rider_id for the current user
        rider = get_rider_by_user_id(session['user_id'])
        
        if not rider:
            return jsonify({'error': 'Rider not found'}), 404
        
        rider_id = rider['rider_id']
        print(f"🔍 Rider ID: {rider_id}")
        print(f"📅 Date Range: {start_date} to {end_date}")
        
        # Fetch earnings data from Supabase
        earnings_data = get_rider_earnings_history(rider_id, start_date, end_date)
        print(f"💵 Found {len(earnings_data)} earnings records")
        
        # Calculate total earnings
        total_earnings = sum(float(e.get('rider_earnings', 0) or 0) for e in earnings_data)
        
        # Collect all order IDs and address IDs for batch fetching
        order_ids = []
        address_ids = []
        for earning in earnings_data:
            order = earning.get('orders', {})
            order_ids.append(earning['order_id'])
            address_id = order.get('address_id')
            if address_id and address_id not in address_ids:
                address_ids.append(address_id)
        
        # Batch fetch all addresses
        supabase = get_supabase()
        addresses_dict = {}
        if address_ids:
            print(f"📍 Batch fetching {len(address_ids)} addresses...")
            addr_response = supabase.table('addresses').select('address_id, full_address').in_('address_id', address_ids).execute()
            if addr_response.data:
                addresses_dict = {addr['address_id']: addr['full_address'] for addr in addr_response.data}
            print(f"✅ Found {len(addresses_dict)} addresses")
        
        # Batch fetch all order items with product names
        order_items_dict = {}
        if order_ids:
            print(f"📦 Batch fetching order items for {len(order_ids)} orders...")
            items_response = supabase.table('order_items').select('''
                order_id,
                products (
                    product_name
                )
            ''').in_('order_id', order_ids).execute()
            
            if items_response.data:
                for item in items_response.data:
                    oid = item['order_id']
                    if oid not in order_items_dict:
                        order_items_dict[oid] = []
                    product = item.get('products', {})
                    if product and product.get('product_name'):
                        order_items_dict[oid].append(product['product_name'])
            
            print(f"✅ Found items for {len(order_items_dict)} orders")
        
        # Format the data for frontend
        formatted_earnings = []
        for earning in earnings_data:
            order = earning.get('orders', {})
            buyer = order.get('buyers', {})
            seller = order.get('sellers', {})
            
            # Get address from batch data
            address_id = order.get('address_id')
            buyer_address = addresses_dict.get(address_id, 'N/A')
            
            # Get product names from batch data
            product_names = order_items_dict.get(earning['order_id'], [])
            product_name = ', '.join(product_names) if product_names else 'N/A'
            
            # Parse delivered_at
            delivered_date = None
            if earning.get('delivered_at'):
                try:
                    delivered_date = datetime.fromisoformat(earning['delivered_at'].replace('Z', '+00:00')).strftime('%Y-%m-%d')
                except:
                    delivered_date = None
            
            formatted_earnings.append({
                'orderId': order.get('order_number'),
                'buyer': {
                    'name': f"{buyer.get('first_name', '')} {buyer.get('last_name', '')}",
                    'address': buyer_address,
                    'deliveryDate': delivered_date
                },
                'seller': {
                    'name': f"{seller.get('first_name', '')} {seller.get('last_name', '')}",
                    'storeName': seller.get('shop_name')
                },
                'productName': product_name,
                'amount': float(earning.get('rider_earnings', 0) or 0)
            })
        
        print(f"✅ Returning {len(formatted_earnings)} earnings")
        print(f"💰 Total: ₱{total_earnings:.2f}")
        print(f"{'='*80}\n")
        
        return jsonify({
            'success': True, 
            'earnings': formatted_earnings,
            'totalEarnings': total_earnings
        }), 200
        
    except Exception as e:
        import traceback
        error_details = traceback.format_exc()
        print(f"❌ Error fetching earnings: {e}")
        print(f"Traceback: {error_details}")
        return jsonify({
            'success': False,
            'error': f'Failed to fetch earnings data: {str(e)}',
            'details': error_details
        }), 500


@rider_earnings_bp.route('/rider/earnings/api/available-balance', methods=['GET'])
def get_available_balance():
    """API endpoint to get rider's available balance for withdrawal"""
    print(f"\n{'='*80}")
    print(f"💵 [AVAILABLE BALANCE] Checking balance...")
    print(f"{'='*80}\n")
    
    if 'user_id' not in session or session.get('user_type') != 'rider':
        return jsonify({'error': 'Unauthorized'}), 401
    
    try:
        # Get rider_id
        rider = get_rider_by_user_id(session['user_id'])
        
        if not rider:
            return jsonify({'error': 'Rider not found'}), 404
        
        rider_id = rider['rider_id']
        print(f"🔍 Rider ID: {rider_id}")
        
        supabase = get_supabase()
        
        # Check for pending withdrawal
        pending_response = supabase.table('rider_withdrawals').select('amount', count='exact').eq('rider_id', rider_id).eq('status', 'pending').execute()
        has_pending = (pending_response.count or 0) > 0
        pending_amount = sum(float(w.get('amount', 0)) for w in (pending_response.data or []))
        
        # Calculate total earnings from delivered orders
        total_earnings = get_rider_total_earnings(rider_id)
        
        # Calculate total withdrawn (completed withdrawals only)
        withdrawn_response = supabase.table('rider_withdrawals').select('amount').eq('rider_id', rider_id).eq('status', 'completed').execute()
        total_withdrawn = sum(float(w.get('amount', 0)) for w in (withdrawn_response.data or []))
        
        # Calculate available balance (subtract both completed and pending withdrawals)
        available_balance = total_earnings - total_withdrawn - pending_amount
        
        print(f"💰 Total earnings: ₱{total_earnings:.2f}")
        print(f"💸 Total withdrawn: ₱{total_withdrawn:.2f}")
        print(f"⏳ Pending: ₱{pending_amount:.2f}")
        print(f"✅ Available: ₱{available_balance:.2f}")
        print(f"{'='*80}\n")
        
        return jsonify({
            'success': True,
            'availableBalance': available_balance,
            'totalEarnings': total_earnings,
            'totalWithdrawn': total_withdrawn,
            'pendingAmount': pending_amount,
            'hasPending': has_pending
        }), 200
        
    except Exception as e:
        print(f"❌ Error getting available balance: {e}")
        return jsonify({'error': str(e)}), 500


@rider_earnings_bp.route('/rider/earnings/api/withdraw', methods=['POST'])
def request_withdrawal():
    """API endpoint to request a withdrawal"""
    if 'user_id' not in session or session.get('user_type') != 'rider':
        return jsonify({'error': 'Unauthorized'}), 401
    
    data = request.get_json()
    amount = data.get('amount')
    method = data.get('method', 'Cash')
    notes = data.get('notes', '')
    
    # Validation
    if not amount or float(amount) <= 0:
        return jsonify({'error': 'Invalid amount'}), 400
    
    amount = float(amount)
    
    # Minimum withdrawal check
    if amount < 100:
        return jsonify({'error': 'Minimum withdrawal amount is ₱100.00'}), 400
    
    try:
        # Get rider_id
        rider = get_rider_by_user_id(session['user_id'])
        
        if not rider:
            return jsonify({'error': 'Rider not found'}), 404
        
        rider_id = rider['rider_id']
        
        supabase = get_supabase()
        
        # Check for existing pending withdrawal
        pending_response = supabase.table('rider_withdrawals').select('withdrawal_id', count='exact').eq('rider_id', rider_id).eq('status', 'pending').execute()
        
        if (pending_response.count or 0) > 0:
            return jsonify({
                'error': 'You already have a pending withdrawal request. Please wait for it to be processed before submitting a new one.'
            }), 400
        
        # Calculate available balance
        total_earnings = get_rider_total_earnings(rider_id)
        
        # Calculate total withdrawn (completed withdrawals only)
        withdrawn_response = supabase.table('rider_withdrawals').select('amount').eq('rider_id', rider_id).eq('status', 'completed').execute()
        total_withdrawn = sum(float(w.get('amount', 0)) for w in (withdrawn_response.data or []))
        
        # Calculate pending withdrawals
        pending_amount_response = supabase.table('rider_withdrawals').select('amount').eq('rider_id', rider_id).eq('status', 'pending').execute()
        pending_amount = sum(float(w.get('amount', 0)) for w in (pending_amount_response.data or []))
        
        # Available balance = total earnings - completed withdrawals - pending withdrawals
        available_balance = total_earnings - total_withdrawn - pending_amount
        
        # Check if sufficient balance
        if amount > available_balance:
            return jsonify({
                'error': f'Insufficient balance. Available: ₱{available_balance:.2f}'
            }), 400
        
        # Additional safety check to prevent negative balance
        if available_balance - amount < 0:
            return jsonify({
                'error': 'This withdrawal would result in a negative balance. Please check your available balance.'
            }), 400
        
        # Insert withdrawal request
        supabase.table('rider_withdrawals').insert({
            'rider_id': rider_id,
            'amount': amount,
            'withdrawal_method': method,
            'status': 'pending',
            'notes': notes
        }).execute()
        
        return jsonify({
            'success': True,
            'message': 'Withdrawal request submitted successfully',
            'newBalance': available_balance - amount
        }), 200
        
    except Exception as e:
        print(f"Error requesting withdrawal: {e}")
        return jsonify({'error': str(e)}), 500


@rider_earnings_bp.route('/rider/earnings/api/withdrawal-history', methods=['GET'])
def get_withdrawal_history():
    """API endpoint to get withdrawal history"""
    if 'user_id' not in session or session.get('user_type') != 'rider':
        return jsonify({'error': 'Unauthorized'}), 401
    
    try:
        # Get rider_id
        rider = get_rider_by_user_id(session['user_id'])
        
        if not rider:
            return jsonify({'error': 'Rider not found'}), 404
        
        rider_id = rider['rider_id']
        
        # Fetch withdrawal history from Supabase
        supabase = get_supabase()
        response = supabase.table('rider_withdrawals').select('''
            withdrawal_id,
            amount,
            withdrawal_method,
            status,
            requested_at,
            processed_at,
            notes
        ''').eq('rider_id', rider_id).order('requested_at', desc=True).execute()
        
        withdrawals = clean_supabase_data(response.data) if response.data else []
        
        # Format data
        formatted_withdrawals = []
        for w in withdrawals:
            # Parse dates
            requested_at = None
            processed_at = None
            
            if w.get('requested_at'):
                try:
                    requested_at = datetime.fromisoformat(w['requested_at'].replace('Z', '+00:00')).strftime('%Y-%m-%d %H:%M:%S')
                except:
                    requested_at = None
            
            if w.get('processed_at'):
                try:
                    processed_at = datetime.fromisoformat(w['processed_at'].replace('Z', '+00:00')).strftime('%Y-%m-%d %H:%M:%S')
                except:
                    processed_at = None
            
            formatted_withdrawals.append({
                'withdrawalId': w['withdrawal_id'],
                'amount': float(w['amount']),
                'method': w['withdrawal_method'],
                'status': w['status'],
                'requestedAt': requested_at,
                'processedAt': processed_at,
                'notes': w.get('notes')
            })
        
        return jsonify({
            'success': True,
            'withdrawals': formatted_withdrawals
        }), 200
        
    except Exception as e:
        print(f"Error getting withdrawal history: {e}")
        return jsonify({'error': str(e)}), 500
