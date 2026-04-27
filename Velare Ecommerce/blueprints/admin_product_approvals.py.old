from flask import Blueprint, render_template, jsonify, request
import sys
import os

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_config import get_db_connection, close_db_connection

admin_product_approvals_bp = Blueprint('admin_product_approvals', __name__)

@admin_product_approvals_bp.route('/admin/product-approvals')
def admin_product_approvals():
    return render_template('admin/admin_product_approvals.html')

@admin_product_approvals_bp.route('/api/admin/products/pending', methods=['GET'])
def get_pending_products():
    """Fetch all products pending approval"""
    try:
        # Get optional filters from query parameters
        status_filter = request.args.get('status', 'pending')
        category_filter = request.args.get('category', '')
        search_query = request.args.get('search', '')
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            # Build query with filters
            query = """
                SELECT 
                    p.product_id,
                    p.product_name,
                    p.description,
                    p.materials,
                    p.SDG,
                    p.price,
                    p.category,
                    p.approval_status,
                    p.created_at,
                    s.shop_name,
                    s.seller_id,
                    u.email as seller_email
                FROM products p
                JOIN sellers s ON p.seller_id = s.seller_id
                JOIN users u ON s.user_id = u.user_id
                WHERE 1=1
            """
            params = []
            
            # Apply status filter
            if status_filter and status_filter != 'all':
                query += " AND p.approval_status = %s"
                params.append(status_filter)
            
            # Apply category filter
            if category_filter:
                query += " AND p.category = %s"
                params.append(category_filter)
            
            # Apply search filter
            if search_query:
                query += " AND (p.product_name LIKE %s OR s.shop_name LIKE %s)"
                search_param = f"%{search_query}%"
                params.extend([search_param, search_param])
            
            query += " ORDER BY p.created_at DESC"
            
            cursor.execute(query, params)
            products = cursor.fetchall()
            
            # Fetch images and variants for each product
            for product in products:
                # Fetch product images
                image_query = """
                    SELECT image_url, is_primary, display_order
                    FROM product_images
                    WHERE product_id = %s
                    ORDER BY display_order ASC
                """
                cursor.execute(image_query, (product['product_id'],))
                images = cursor.fetchall()
                product['images'] = [img['image_url'] for img in images]
                product['primary_image'] = images[0]['image_url'] if images else None
                
                # Fetch product variants with color and size details
                variant_query = """
                    SELECT 
                        pv.variant_id, 
                        pv.color, 
                        pv.hex_code,
                        pv.size, 
                        pv.stock_quantity, 
                        pv.image_url
                    FROM product_variants pv
                    WHERE pv.product_id = %s
                    ORDER BY pv.color, pv.size
                """
                cursor.execute(variant_query, (product['product_id'],))
                variants = cursor.fetchall()
                
                # Fetch images for each variant
                variants_with_images = []
                for variant in variants:
                    variant_dict = dict(variant)
                    
                    # Fetch images for this variant
                    variant_images_query = """
                        SELECT image_url, is_primary, display_order
                        FROM product_images
                        WHERE variant_id = %s
                        ORDER BY display_order
                    """
                    cursor.execute(variant_images_query, (variant['variant_id'],))
                    variant_images = cursor.fetchall()
                    variant_dict['images'] = [{'url': img['image_url'], 'is_primary': img['is_primary']} for img in variant_images]
                    
                    variants_with_images.append(variant_dict)
                
                product['variants'] = variants_with_images
            
            # Count pending products
            count_query = "SELECT COUNT(*) as count FROM products WHERE approval_status = 'pending'"
            cursor.execute(count_query)
            pending_count = cursor.fetchone()['count']
            
            return jsonify({
                'success': True,
                'products': products,
                'pending_count': pending_count
            }), 200
            
        except Exception as db_error:
            print(f"Database error: {str(db_error)}")
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
        finally:
            close_db_connection(connection, cursor)
        
    except Exception as e:
        print(f"Error fetching pending products: {str(e)}")
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@admin_product_approvals_bp.route('/api/admin/products/<int:product_id>/approve', methods=['POST'])
def approve_product(product_id):
    """Approve a product"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            # Check if product exists and is pending
            check_query = "SELECT product_id, product_name, approval_status FROM products WHERE product_id = %s"
            cursor.execute(check_query, (product_id,))
            product = cursor.fetchone()
            
            if not product:
                return jsonify({'success': False, 'message': 'Product not found'}), 404
            
            if product['approval_status'] == 'approved':
                return jsonify({'success': False, 'message': 'Product is already approved'}), 400
            
            # Update product status to approved
            update_query = """
                UPDATE products 
                SET approval_status = 'approved', is_active = TRUE
                WHERE product_id = %s
            """
            cursor.execute(update_query, (product_id,))
            connection.commit()
            
            print(f"Product {product_id} approved: {product['product_name']}")
            
            return jsonify({
                'success': True,
                'message': 'Product approved successfully',
                'product_id': product_id
            }), 200
            
        except Exception as db_error:
            connection.rollback()
            print(f"Database error: {str(db_error)}")
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
        finally:
            close_db_connection(connection, cursor)
        
    except Exception as e:
        print(f"Error approving product: {str(e)}")
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@admin_product_approvals_bp.route('/api/admin/products/<int:product_id>/reject', methods=['POST'])
def reject_product(product_id):
    """Reject a product"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            # Check if product exists
            check_query = "SELECT product_id, product_name, approval_status FROM products WHERE product_id = %s"
            cursor.execute(check_query, (product_id,))
            product = cursor.fetchone()
            
            if not product:
                return jsonify({'success': False, 'message': 'Product not found'}), 404
            
            if product['approval_status'] == 'rejected':
                return jsonify({'success': False, 'message': 'Product is already rejected'}), 400
            
            # Update product status to rejected and set inactive
            update_query = """
                UPDATE products 
                SET approval_status = 'rejected', is_active = FALSE
                WHERE product_id = %s
            """
            cursor.execute(update_query, (product_id,))
            connection.commit()
            
            print(f"Product {product_id} rejected: {product['product_name']}")
            
            return jsonify({
                'success': True,
                'message': 'Product rejected',
                'product_id': product_id
            }), 200
            
        except Exception as db_error:
            connection.rollback()
            print(f"Database error: {str(db_error)}")
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
        finally:
            close_db_connection(connection, cursor)
        
    except Exception as e:
        print(f"Error rejecting product: {str(e)}")
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500
