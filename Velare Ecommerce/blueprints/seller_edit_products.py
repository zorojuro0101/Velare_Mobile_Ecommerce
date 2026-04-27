from flask import Blueprint, render_template, request, jsonify, session
from werkzeug.utils import secure_filename
import os
import sys
from datetime import datetime

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_config import get_db_connection, close_db_connection

seller_edit_products_bp = Blueprint('seller_edit_products', __name__)

# Configure upload folder
UPLOAD_FOLDER = 'static/uploads/products'
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif', 'webp'}

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@seller_edit_products_bp.route('/seller/edit-products')
def seller_edit_products():
    return render_template('seller/seller_edit_products.html')

@seller_edit_products_bp.route('/api/products/<int:product_id>', methods=['GET'])
def get_product(product_id):
    try:
        # Get seller_id from session (default to 1 for testing if not in session)
        seller_id = session.get('seller_id', 1)
        
        # Connect to database
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            # Fetch product details
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
                    p.is_active
                FROM products p
                WHERE p.product_id = %s AND p.seller_id = %s
            """
            cursor.execute(query, (product_id, seller_id))
            product = cursor.fetchone()
            
            if not product:
                return jsonify({'success': False, 'message': 'Product not found'}), 404
            
            # Convert to regular dict
            product_dict = dict(product) if product else {}
            
            # Convert database category to form value (reverse mapping)
            if product_dict.get('category') in ['Active Wear', 'Yoga Pants', 'activewear', 'yoga-pants', 'Active Wear-Yoga Pants']:
                product_dict['category'] = 'activewear-yoga'
            
            # Fetch product images
            image_query = """
                SELECT image_url, is_primary, display_order
                FROM product_images
                WHERE product_id = %s
                ORDER BY display_order ASC
            """
            cursor.execute(image_query, (product_id,))
            images = cursor.fetchall()
            product_dict['images'] = [img['image_url'] for img in images]
            
            # Fetch product variants with color info
            variant_query = """
                SELECT pv.variant_id, pv.color, pv.hex_code, pv.size, pv.stock_quantity, pv.image_url
                FROM product_variants pv
                WHERE pv.product_id = %s
                ORDER BY pv.color, pv.size
            """
            cursor.execute(variant_query, (product_id,))
            variants = cursor.fetchall()
            
            print(f"[OK] Fetched {len(variants)} variants for product {product_id}")
            
            # Fetch images for each variant
            variants_list = []
            for variant in variants:
                variant_images_query = """
                    SELECT image_url, is_primary, display_order
                    FROM product_images
                    WHERE variant_id = %s
                    ORDER BY display_order
                """
                cursor.execute(variant_images_query, (variant['variant_id'],))
                variant_images = cursor.fetchall()
                
                # Convert variant to dict and add images
                variant_dict = dict(variant)
                variant_dict['images'] = [{'url': img['image_url'], 'is_primary': img['is_primary']} for img in variant_images]
                
                print(f"   Variant {variant['variant_id']}: Found {len(variant_images)} images")
                
                variants_list.append(variant_dict)
            
            product_dict['variants'] = variants_list
            
            return jsonify({
                'success': True,
                'product': product_dict,
                'test_message': 'CORRECT FILE - seller_edit_products.py'
            }), 200
            
        except Exception as db_error:
            print(f"Database error: {str(db_error)}")
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
        finally:
            close_db_connection(connection, cursor)
        
    except Exception as e:
        print(f"Error fetching product: {str(e)}")
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@seller_edit_products_bp.route('/api/products/<int:product_id>', methods=['PUT', 'POST'])
def update_product(product_id):
    try:
        # Get seller_id from session (default to 1 for testing if not in session)
        seller_id = session.get('seller_id', 1)
        
        # Get form data (with both naming conventions for compatibility)
        product_name = request.form.get('productName') or request.form.get('editProductName')
        category = request.form.get('productCategory') or request.form.get('editProductCategory')
        
        # Convert combined category to database format
        if category == 'activewear-yoga':
            category = 'Active Wear-Yoga Pants'  # Save as Active Wear-Yoga Pants
        
        price = request.form.get('productPrice') or request.form.get('editProductPrice')
        description = request.form.get('productDescription') or request.form.get('editProductDescription', '')
        materials = request.form.get('productMaterials') or request.form.get('editProductMaterials', '')
        
        # Get SDG checkboxes (check both naming conventions)
        is_handmade = 'productHandmade' in request.form or 'editProductHandmade' in request.form
        is_biodegradable = 'productBiodegradable' in request.form or 'editProductBiodegradable' in request.form
        
        # Get variants data
        variants_data = request.form.get('variantsData')
        
        # Validate required fields
        if not all([product_name, category, price]):
            return jsonify({'success': False, 'message': 'All required fields must be filled'}), 400
        
        # Validate price
        try:
            price = float(price)
            if price <= 0:
                raise ValueError()
        except ValueError:
            return jsonify({'success': False, 'message': 'Invalid price'}), 400
        
        # Connect to database
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            # Verify product belongs to seller
            verify_query = "SELECT product_id FROM products WHERE product_id = %s AND seller_id = %s"
            cursor.execute(verify_query, (product_id, seller_id))
            if not cursor.fetchone():
                return jsonify({'success': False, 'message': 'Product not found or access denied'}), 404
            
            # Determine SDG value based on checkboxes
            if is_handmade and is_biodegradable:
                sdg_value = 'both'
            elif is_handmade:
                sdg_value = 'handmade'
            elif is_biodegradable:
                sdg_value = 'biodegradable'
            else:
                sdg_value = None
            
            # Calculate total stock from variants
            total_stock = 0
            if variants_data:
                import json
                variants = json.loads(variants_data)
                total_stock = sum(int(v['quantity']) for v in variants if 'quantity' in v)
            
            # Update product (stock_quantity removed - now in product_variants table)
            update_query = """
                UPDATE products 
                SET product_name = %s,
                    description = %s,
                    materials = %s,
                    SDG = %s,
                    price = %s,
                    category = %s,
                    updated_at = NOW()
                WHERE product_id = %s AND seller_id = %s
            """
            cursor.execute(update_query, (
                product_name,
                description,
                materials if materials else None,
                sdg_value,
                price,
                category,
                product_id,
                seller_id
            ))
            
            # Update existing variants quantities
            if variants_data:
                import json
                variants = json.loads(variants_data)
                for variant in variants:
                    variant_id = variant.get('variant_id')
                    quantity = int(variant.get('quantity', 0))
                    if variant_id:
                        update_variant_query = """
                            UPDATE product_variants 
                            SET stock_quantity = %s 
                            WHERE variant_id = %s AND product_id = %s
                        """
                        cursor.execute(update_variant_query, (quantity, variant_id, product_id))
            
            # Handle new variants
            new_variants_data = request.form.get('newVariantsData')
            if new_variants_data:
                import json
                new_variants = json.loads(new_variants_data)
                new_variant_images = request.files.getlist('newVariantImages')
                
                for index, variant in enumerate(new_variants):
                    hex_color = variant.get('hex')
                    color_name = variant.get('colorName')
                    size = variant.get('size')
                    quantity = int(variant.get('quantity', 0))
                    
                    # Handle image upload
                    image_url = None
                    if index < len(new_variant_images):
                        image_file = new_variant_images[index]
                        if image_file and image_file.filename:
                            os.makedirs(UPLOAD_FOLDER, exist_ok=True)
                            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                            filename = secure_filename(image_file.filename)
                            unique_filename = f"{timestamp}_{index}_{filename}"
                            filepath = os.path.join(UPLOAD_FOLDER, unique_filename)
                            image_file.save(filepath)
                            image_url = filepath.replace('\\', '/')
                    
                    # Insert new variant
                    insert_variant_query = """
                        INSERT INTO product_variants (product_id, color, hex_code, size, stock_quantity, image_url)
                        VALUES (%s, %s, %s, %s, %s, %s)
                    """
                    cursor.execute(insert_variant_query, (product_id, color_name, hex_color, size, quantity, image_url))
            
            # Handle new image uploads if provided
            uploaded_files = request.files.getlist('productImages')
            if uploaded_files and uploaded_files[0].filename != '':
                # Create upload directory if it doesn't exist
                os.makedirs(UPLOAD_FOLDER, exist_ok=True)
                
                # Delete old images from database (optional: also delete files from disk)
                delete_images_query = "DELETE FROM product_images WHERE product_id = %s"
                cursor.execute(delete_images_query, (product_id,))
                
                # Save new images
                image_paths = []
                for file in uploaded_files:  # No limit on images
                    if file and allowed_file(file.filename):
                        # Generate unique filename
                        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                        filename = secure_filename(file.filename)
                        unique_filename = f"{timestamp}_{filename}"
                        filepath = os.path.join(UPLOAD_FOLDER, unique_filename)
                        
                        # Save file
                        file.save(filepath)
                        image_paths.append(filepath.replace('\\', '/'))
                
                # Insert new product images
                for index, image_path in enumerate(image_paths):
                    insert_image_query = """
                        INSERT INTO product_images 
                        (product_id, image_url, is_primary, display_order)
                        VALUES (%s, %s, %s, %s)
                    """
                    is_primary = (index == 0)  # First image is primary
                    cursor.execute(insert_image_query, (product_id, image_path, is_primary, index))
            
            # Handle variant image uploads and updates
            import json
            print(f"\n[IMAGE] PROCESSING VARIANT IMAGES")
            for key in request.form.keys():
                if key.startswith('variant_') and key.endswith('_has_new_images'):
                    # Extract variant_id from key like "variant_45_has_new_images"
                    variant_id = key.replace('variant_', '').replace('_has_new_images', '')
                    print(f"  Processing images for variant {variant_id}")
                    
                    # Get uploaded files for this variant
                    file_key = f'variant_{variant_id}_images'
                    uploaded_files = request.files.getlist(file_key)
                    
                    if uploaded_files and len(uploaded_files) > 0:
                        # Create upload directory if it doesn't exist
                        os.makedirs(UPLOAD_FOLDER, exist_ok=True)
                        
                        # Get current max display_order for this variant
                        cursor.execute(
                            "SELECT COALESCE(MAX(display_order), -1) as max_order FROM product_images WHERE variant_id = %s",
                            (variant_id,)
                        )
                        max_order_result = cursor.fetchone()
                        current_max_order = max_order_result['max_order'] if max_order_result else -1
                        
                        # Upload and insert new images
                        for idx, file in enumerate(uploaded_files):
                            if file and file.filename and allowed_file(file.filename):
                                timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                                filename = secure_filename(file.filename)
                                unique_filename = f"{timestamp}_{variant_id}_{idx}_{filename}"
                                filepath = os.path.join(UPLOAD_FOLDER, unique_filename)
                                file.save(filepath)
                                image_url = filepath.replace('\\', '/')
                                
                                # Insert into product_images
                                display_order = current_max_order + 1 + idx
                                is_primary = (display_order == 0)  # First image is primary
                                
                                cursor.execute(
                                    """INSERT INTO product_images 
                                       (product_id, variant_id, image_url, is_primary, display_order)
                                       VALUES (%s, %s, %s, %s, %s)""",
                                    (product_id, variant_id, image_url, is_primary, display_order)
                                )
                                
                                print(f"    [OK] Uploaded: {unique_filename} (order: {display_order})")
                                
                                # Update variant's image_url to first image if not set
                                if is_primary or current_max_order == -1:
                                    cursor.execute(
                                        "UPDATE product_variants SET image_url = %s WHERE variant_id = %s",
                                        (image_url, variant_id)
                                    )
                    
                    # Handle image reordering if provided
                    order_key = f'variant_{variant_id}_image_order'
                    if order_key in request.form:
                        try:
                            image_order = json.loads(request.form.get(order_key))
                            print(f"    Reordering {len(image_order)} images for variant {variant_id}")
                            
                            # Update display_order and is_primary for existing images
                            for idx, img_info in enumerate(image_order):
                                if not img_info.get('isNew') and img_info.get('url'):
                                    # Clean the URL (remove leading slash if present)
                                    clean_url = img_info['url'].lstrip('/')
                                    cursor.execute(
                                        """UPDATE product_images 
                                           SET display_order = %s, is_primary = %s 
                                           WHERE variant_id = %s AND image_url = %s""",
                                        (idx, idx == 0, variant_id, clean_url)
                                    )
                        except Exception as order_error:
                            print(f"    [WARN] Error reordering images: {str(order_error)}")
            
            # Commit the transaction
            connection.commit()
            
            print(f"Product {product_id} updated successfully")
            
            return jsonify({
                'success': True,
                'message': 'Product updated successfully!'
            }), 200
            
        except Exception as db_error:
            connection.rollback()
            print(f"Database error: {str(db_error)}")
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
        finally:
            close_db_connection(connection, cursor)
        
    except Exception as e:
        print(f"Error updating product: {str(e)}")
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500
