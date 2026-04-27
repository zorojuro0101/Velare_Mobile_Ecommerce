from flask import Blueprint, render_template, request, jsonify, session
from datetime import datetime
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_config import get_db_connection, close_db_connection
from utils.auth_decorators import seller_required

seller_vouchers_bp = Blueprint('seller_vouchers', __name__)

@seller_vouchers_bp.route('/seller/vouchers')
@seller_required
def seller_vouchers():
    """Display seller voucher selection page"""
    seller_id = session.get('seller_id')
    
    connection = get_db_connection()
    if not connection:
        return render_template('seller/seller_vouchers.html', 
                             available_vouchers=[], 
                             selected_vouchers=[], 
                             error='Database connection failed')
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        # Get all available vouchers (not expired)
        cursor.execute("""
            SELECT voucher_id, voucher_code, voucher_name, voucher_type, 
                   discount_percent, start_date, end_date, created_at
            FROM vouchers
            WHERE end_date >= CURDATE()
            ORDER BY created_at DESC
        """)
        all_vouchers = cursor.fetchall()
        
        # Get vouchers selected by this seller
        cursor.execute("""
            SELECT sv.seller_voucher_id, sv.voucher_id, sv.is_active, sv.selected_at,
                   v.voucher_code, v.voucher_name, v.voucher_type, v.discount_percent,
                   v.start_date, v.end_date
            FROM seller_vouchers sv
            JOIN vouchers v ON sv.voucher_id = v.voucher_id
            WHERE sv.seller_id = %s AND sv.is_active = TRUE
            ORDER BY sv.selected_at DESC
        """, (seller_id,))
        selected_vouchers = cursor.fetchall()
        
        # Mark which vouchers are already selected
        selected_voucher_ids = {v['voucher_id'] for v in selected_vouchers}
        
        available_vouchers = []
        for voucher in all_vouchers:
            voucher['is_selected'] = voucher['voucher_id'] in selected_voucher_ids
            available_vouchers.append(voucher)
        
        return render_template('seller/seller_vouchers.html', 
                             available_vouchers=available_vouchers,
                             selected_vouchers=selected_vouchers)
    
    except Exception as e:
        print(f"Error fetching seller vouchers: {e}")
        import traceback
        print(traceback.format_exc())
        return render_template('seller/seller_vouchers.html', 
                             available_vouchers=[], 
                             selected_vouchers=[], 
                             error=str(e))
    
    finally:
        close_db_connection(connection, cursor)

@seller_vouchers_bp.route('/seller/vouchers/select', methods=['POST'])
@seller_required
def select_voucher():
    """Select a voucher for the seller's shop"""
    try:
        data = request.get_json()
        voucher_id = data.get('voucher_id')
        seller_id = session.get('seller_id')
        
        if not voucher_id:
            return jsonify({'success': False, 'message': 'Voucher ID is required'}), 400
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            cursor = connection.cursor(dictionary=True)
            
            # Check if voucher exists and is valid
            cursor.execute("""
                SELECT voucher_id, voucher_code, voucher_name, end_date
                FROM vouchers 
                WHERE voucher_id = %s AND end_date >= CURDATE()
            """, (voucher_id,))
            voucher = cursor.fetchone()
            
            if not voucher:
                return jsonify({'success': False, 'message': 'Voucher not found or expired'}), 404
            
            # Check if already selected
            cursor.execute("""
                SELECT seller_voucher_id FROM seller_vouchers 
                WHERE seller_id = %s AND voucher_id = %s AND is_active = TRUE
            """, (seller_id, voucher_id))
            
            if cursor.fetchone():
                return jsonify({'success': False, 'message': 'Voucher already selected'}), 400
            
            # Insert new selection
            cursor.execute("""
                INSERT INTO seller_vouchers (seller_id, voucher_id, is_active)
                VALUES (%s, %s, TRUE)
            """, (seller_id, voucher_id))
            
            # AUTO-ASSIGN VOUCHER TO ALL BUYERS
            # Get all active buyers
            cursor.execute("""
                SELECT b.buyer_id
                FROM buyers b
                JOIN users u ON b.user_id = u.user_id
                WHERE u.status = 'active'
            """)
            buyers = cursor.fetchall()
            
            # Assign voucher to each buyer (if not already assigned)
            for buyer in buyers:
                cursor.execute("""
                    INSERT IGNORE INTO buyer_vouchers (buyer_id, voucher_id, is_used)
                    VALUES (%s, %s, FALSE)
                """, (buyer['buyer_id'], voucher_id))
            
            connection.commit()
            
            buyers_count = len(buyers)
            return jsonify({
                'success': True,
                'message': f'Voucher "{voucher["voucher_code"]}" added to your shop and assigned to {buyers_count} buyers'
            })
        
        except Exception as e:
            connection.rollback()
            print(f"Database error: {e}")
            import traceback
            print(traceback.format_exc())
            return jsonify({'success': False, 'message': f'Database error: {str(e)}'}), 500
        
        finally:
            close_db_connection(connection, cursor)
    
    except Exception as e:
        print(f"Unexpected error: {e}")
        import traceback
        print(traceback.format_exc())
        return jsonify({'success': False, 'message': f'Unexpected error: {str(e)}'}), 500

@seller_vouchers_bp.route('/seller/vouchers/remove', methods=['POST'])
@seller_required
def remove_voucher():
    """Remove a voucher from the seller's shop"""
    try:
        data = request.get_json()
        voucher_id = data.get('voucher_id')
        seller_id = session.get('seller_id')
        
        if not voucher_id:
            return jsonify({'success': False, 'message': 'Voucher ID is required'}), 400
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            cursor = connection.cursor()
            
            # Remove voucher selection (set is_active to FALSE)
            cursor.execute("""
                UPDATE seller_vouchers 
                SET is_active = FALSE 
                WHERE seller_id = %s AND voucher_id = %s AND is_active = TRUE
            """, (seller_id, voucher_id))
            
            connection.commit()
            
            if cursor.rowcount == 0:
                return jsonify({'success': False, 'message': 'Voucher selection not found'}), 404
            
            return jsonify({
                'success': True,
                'message': 'Voucher removed from your shop'
            })
        
        except Exception as e:
            connection.rollback()
            print(f"Error removing voucher: {e}")
            import traceback
            print(traceback.format_exc())
            return jsonify({'success': False, 'message': f'Error: {str(e)}'}), 500
        
        finally:
            close_db_connection(connection, cursor)
    
    except Exception as e:
        print(f"Unexpected error: {e}")
        import traceback
        print(traceback.format_exc())
        return jsonify({'success': False, 'message': f'Unexpected error: {str(e)}'}), 500
