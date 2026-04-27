from flask import Blueprint, render_template, request, jsonify, session, redirect, url_for
from datetime import datetime
import sys
import os

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_config import get_db_connection, close_db_connection
from utils.auth_decorators import admin_required

admin_vouchers_bp = Blueprint('admin_vouchers', __name__)

@admin_vouchers_bp.route('/admin/vouchers')
@admin_required
def admin_vouchers():
    """Display admin voucher management page"""
    connection = get_db_connection()
    if not connection:
        return render_template('admin/admin_vouchers.html', vouchers=[], error='Database connection failed')
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        # Fetch all vouchers
        cursor.execute("""
            SELECT voucher_id, voucher_code, voucher_name, voucher_type, 
                   discount_percent, start_date, end_date, created_at
            FROM vouchers
            ORDER BY created_at DESC
        """)
        vouchers = cursor.fetchall()
        
        return render_template('admin/admin_vouchers.html', vouchers=vouchers)
    
    except Exception as e:
        print(f"Error fetching vouchers: {e}")
        import traceback
        print(traceback.format_exc())
        return render_template('admin/admin_vouchers.html', vouchers=[], error=str(e))
    
    finally:
        close_db_connection(connection, cursor)

@admin_vouchers_bp.route('/admin/vouchers/create', methods=['POST'])
@admin_required
def create_voucher():
    """Create a new voucher"""
    try:
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['voucher_type', 'voucher_percent', 'start_date', 'end_date']
        for field in required_fields:
            if not data.get(field):
                return jsonify({'success': False, 'message': f'{field} is required'}), 400
        
        voucher_type_input = data['voucher_type'].strip().lower()  # 'shipping' or 'discount'
        voucher_percent = int(data.get('voucher_percent', 0))
        start_date = data['start_date']
        end_date = data['end_date']
        
        # Validate voucher type
        if voucher_type_input not in ['shipping', 'discount']:
            return jsonify({'success': False, 'message': 'Invalid voucher type'}), 400
        
        # Validate percentage
        if voucher_percent <= 0 or voucher_percent > 100:
            return jsonify({'success': False, 'message': 'Percentage must be between 1 and 100'}), 400
        
        # Auto-generate voucher code and name based on type and percentage
        if voucher_type_input == 'shipping':
            if voucher_percent == 100:
                voucher_code = 'FREESHIP'
            else:
                voucher_code = f'SHIP{voucher_percent}'
            voucher_name = f'{voucher_percent}% Free Shipping'
            voucher_type = 'free_shipping'  # Database uses 'free_shipping'
            discount_percent = voucher_percent
        else:  # discount
            voucher_code = f'SAVE{voucher_percent}'
            voucher_name = f'{voucher_percent}% Discount'
            voucher_type = 'discount'
            discount_percent = voucher_percent
        
        # Validate dates
        try:
            start = datetime.strptime(start_date, '%Y-%m-%d')
            end = datetime.strptime(end_date, '%Y-%m-%d')
            if end < start:
                return jsonify({'success': False, 'message': 'End date must be after start date'}), 400
        except ValueError:
            return jsonify({'success': False, 'message': 'Invalid date format'}), 400
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            cursor = connection.cursor(dictionary=True)
            
            # Check if voucher code already exists
            cursor.execute("SELECT voucher_id FROM vouchers WHERE voucher_code = %s", (voucher_code,))
            if cursor.fetchone():
                return jsonify({'success': False, 'message': 'Voucher code already exists'}), 400
            
            # Insert new voucher
            cursor.execute("""
                INSERT INTO vouchers (voucher_code, voucher_name, voucher_type, discount_percent, start_date, end_date)
                VALUES (%s, %s, %s, %s, %s, %s)
            """, (voucher_code, voucher_name, voucher_type, discount_percent, start_date, end_date))
            
            connection.commit()
            voucher_id = cursor.lastrowid
            
            return jsonify({
                'success': True,
                'message': 'Voucher created successfully',
                'voucher_id': voucher_id
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

@admin_vouchers_bp.route('/admin/vouchers/delete/<int:voucher_id>', methods=['DELETE'])
@admin_required
def delete_voucher(voucher_id):
    """Delete a voucher"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'message': 'Database connection failed'}), 500
    
    try:
        cursor = connection.cursor()
        
        # Delete voucher directly (no checks needed since vouchers are not yet connected to buyers/sellers)
        cursor.execute("DELETE FROM vouchers WHERE voucher_id = %s", (voucher_id,))
        connection.commit()
        
        if cursor.rowcount == 0:
            return jsonify({'success': False, 'message': 'Voucher not found'}), 404
        
        return jsonify({'success': True, 'message': 'Voucher deleted successfully'})
    
    except Exception as e:
        connection.rollback()
        print(f"Error deleting voucher: {e}")
        import traceback
        print(traceback.format_exc())
        return jsonify({'success': False, 'message': f'Error: {str(e)}'}), 500
    
    finally:
        close_db_connection(connection, cursor)
