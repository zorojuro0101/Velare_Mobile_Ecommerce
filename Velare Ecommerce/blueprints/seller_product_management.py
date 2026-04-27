from flask import Blueprint, render_template, request, jsonify, session
from werkzeug.utils import secure_filename
import os
import sys
from datetime import datetime

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_config import get_db_connection, close_db_connection
from utils.auth_decorators import seller_required

seller_product_management_bp = Blueprint('seller_product_management', __name__)

# Configure upload folder
UPLOAD_FOLDER = 'static/uploads/products'  # Full path for saving files
UPLOAD_FOLDER_DB = 'static/uploads/products'  # Path for database (with 'static/' for Flask url_for)
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'avif'}

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def fix_variant_images():
    """Fix existing variants that have NULL image_url by copying from variants with same color"""
    try:
        connection = get_db_connection()
        if not connection:
            return
        
        cursor = connection.cursor(dictionary=True)
        
        # Update NULL image_urls with image from same hex_code (color)
        query = """
            UPDATE product_variants pv1
            JOIN (
                SELECT hex_code, product_id, image_url
                FROM product_variants
                WHERE image_url IS NOT NULL
                GROUP BY hex_code, product_id
            ) pv2 ON pv1.hex_code = pv2.hex_code AND pv1.product_id = pv2.product_id
            SET pv1.image_url = pv2.image_url
            WHERE pv1.image_url IS NULL
        """
        cursor.execute(query)
        rows_affected = cursor.rowcount
        connection.commit()
        
        if rows_affected > 0:
            print(f"[OK] Fixed {rows_affected} variants with missing images")
        
        close_db_connection(connection, cursor)
    except Exception as e:
        print(f"Error fixing variant images: {str(e)}")

@seller_product_management_bp.route('/seller/product-management')
@seller_required
def seller_product_management():
    # Fix any variants with missing images on page load
    fix_variant_images()
    
    # Get seller info for profile display
    seller_id = session.get('seller_id')
    connection = get_db_connection()
    seller_info = None
    
    if connection:
        cursor = connection.cursor(dictionary=True)
        cursor.execute("SELECT shop_name, shop_logo FROM sellers WHERE seller_id = %s", (seller_id,))
        seller_info = cursor.fetchone()
        
        # Fix shop_logo path: remove 'static/' prefix for url_for
        if seller_info and seller_info.get('shop_logo'):
            if seller_info['shop_logo'].startswith('static/'):
                seller_info['shop_logo'] = seller_info['shop_logo'][7:]  # Remove 'static/' prefix
        
        close_db_connection(connection, cursor)
    
    return render_template('seller/seller_product_management.html', seller=seller_info)

@seller_product_management_bp.route('/api/products/list', methods=['GET'])
@seller_required
def list_products():
    try:
        # Get seller_id from session - guaranteed to exist due to @seller_required decorator
        seller_id = session.get('seller_id')
        
        # Connect to database
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            # Fetch products for this seller
            query = """
                SELECT 
                    p.product_id,
                    p.product_name,
                    p.description,
                    p.materials,
                    p.price,
                    p.category,
                    p.is_active,
                    p.created_at
                FROM products p
                WHERE p.seller_id = %s
                ORDER BY p.created_at DESC
            """
            cursor.execute(query, (seller_id,))
            products = cursor.fetchall()
            
            # Fetch images and variants for each product
            for product in products:
                # Fetch product-level images (images without variant_id)
                image_query = """
                    SELECT image_url, is_primary, display_order
                    FROM product_images
                    WHERE product_id = %s AND variant_id IS NULL
                    ORDER BY display_order ASC
                """
                cursor.execute(image_query, (product['product_id'],))
                images = cursor.fetchall()
                product['images'] = [img['image_url'] for img in images]
                
                # Get primary image - prefer first variant image, fallback to product image
                product['primary_image'] = None
                
                # Fetch product variants with images
                variant_query = """
                    SELECT pv.variant_id, pv.color, pv.size, pv.stock_quantity, pv.image_url,
                           pv.hex_code
                    FROM product_variants pv
                    WHERE pv.product_id = %s
                    ORDER BY pv.color, pv.size
                """
                cursor.execute(variant_query, (product['product_id'],))
                variants = cursor.fetchall()
                
                # Fetch images for each variant
                for variant in variants:
                    variant_images_query = """
                        SELECT image_url, is_primary, display_order
                        FROM product_images
                        WHERE variant_id = %s
                        ORDER BY display_order
                    """
                    cursor.execute(variant_images_query, (variant['variant_id'],))
                    variant_images = cursor.fetchall()
                    variant['images'] = [{'url': img['image_url'], 'is_primary': img['is_primary']} for img in variant_images]
                    
                    # Set primary_image to the first variant's first image if not set yet
                    if not product['primary_image'] and variant_images:
                        product['primary_image'] = variant_images[0]['image_url']
                
                product['variants'] = variants
                
                # If no variant images, use product-level image as fallback
                if not product['primary_image'] and images:
                    product['primary_image'] = images[0]['image_url']
                
                # Calculate total stock from all variants
                total_stock = sum(variant['stock_quantity'] for variant in variants) if variants else 0
                product['stock_quantity'] = total_stock
                
                # Check if product has been delivered in any order
                delivered_check_query = """
                    SELECT COUNT(*) as delivered_count
                    FROM order_items oi
                    JOIN orders o ON oi.order_id = o.order_id
                    WHERE oi.product_id = %s 
                    AND o.order_status = 'delivered'
                    AND o.seller_id = %s
                """
                cursor.execute(delivered_check_query, (product['product_id'], seller_id))
                delivered_result = cursor.fetchone()
                product['has_delivered_orders'] = delivered_result['delivered_count'] > 0 if delivered_result else False
            
            response = jsonify({
                'success': True,
                'products': products
            })
            response.headers['Cache-Control'] = 'no-store, no-cache, must-revalidate, max-age=0'
            response.headers['Pragma'] = 'no-cache'
            response.headers['Expires'] = '0'
            return response, 200
            
        except Exception as db_error:
            print(f"Database error: {str(db_error)}")
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
        finally:
            close_db_connection(connection, cursor)
        
    except Exception as e:
        print(f"Error fetching products: {str(e)}")
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@seller_product_management_bp.route('/api/products/add', methods=['POST'])
@seller_required
def add_product():
    try:
        import json
        
        print("\n" + "="*60)
        print("ADD PRODUCT REQUEST RECEIVED")
        print("="*60)
        
        # Get form data
        product_name = request.form.get('productName')
        category = request.form.get('productCategory')
        
        # Convert combined category to database format
        if category == 'activewear-yoga':
            category = 'Active Wear-Yoga Pants'  # Save as Active Wear-Yoga Pants
        
        price = request.form.get('productPrice')
        description = request.form.get('productDescription', '')
        materials = request.form.get('productMaterials', '')
        product_variants_json = request.form.get('productColorsData', '[]')  # Now contains full variant data
        image_color_mapping_json = request.form.get('imageColorMapping', '[]')  # Maps images to colors
        
        print(f"Product Name: {product_name}")
        print(f"Category: {category}")
        print(f"Price: {price}")
        print(f"Variants JSON: {product_variants_json}")
        print(f"Image-Color Mapping: {image_color_mapping_json}")
        print(f"Files: {len(request.files.getlist('productImages'))} images")
        
        # Parse variants data (color-size pairs)
        try:
            product_variants = json.loads(product_variants_json)
        except:
            product_variants = []
        
        # Parse image-to-color mapping
        try:
            image_color_mapping = json.loads(image_color_mapping_json)
        except:
            image_color_mapping = []
        
        # Get stock from form (auto-calculated from variants) or calculate from variants
        stock = request.form.get('productStock', 0)
        try:
            stock = int(stock)
        except:
            stock = sum(int(variant.get('quantity', 0)) for variant in product_variants)
        
        # Get SDG checkboxes
        is_handmade = 'productHandmade' in request.form
        is_biodegradable = 'productBiodegradable' in request.form
        
        # Validate required fields
        if not all([product_name, category, price]):
            return jsonify({'success': False, 'message': 'All required fields must be filled'}), 400
        
        # Validate variants
        if not product_variants or len(product_variants) == 0:
            return jsonify({'success': False, 'message': 'Please add at least one variant (color + size)'}), 400
        
        # Validate price and stock
        try:
            price = float(price)
            if price <= 0:
                raise ValueError('Invalid price')
            if stock <= 0:
                raise ValueError('Total stock must be greater than 0')
        except ValueError as e:
            return jsonify({'success': False, 'message': str(e)}), 400
        
        # Handle file uploads (variant images)
        uploaded_files = request.files.getlist('productImages')
        if not uploaded_files or uploaded_files[0].filename == '':
            return jsonify({'success': False, 'message': 'At least one product image is required'}), 400
        
        # Create upload directory if it doesn't exist
        os.makedirs(UPLOAD_FOLDER, exist_ok=True)
        
        # Save uploaded images and map them to colors using the mapping from frontend
        color_image_map = {}  # Maps color hex to list of image paths
        
        # Save all uploaded files and map to their respective colors
        for index, file in enumerate(uploaded_files):
            if file and allowed_file(file.filename):
                # Generate unique filename
                timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                filename = secure_filename(file.filename)
                unique_filename = f"{timestamp}_{index}_{filename}"
                filepath = os.path.join(UPLOAD_FOLDER, unique_filename)
                
                # Save file
                file.save(filepath)
                # Store path for database (with 'static/' prefix for Flask)
                image_path = f"{UPLOAD_FOLDER_DB}/{unique_filename}"
                
                # Get the color for this image from the mapping
                if index < len(image_color_mapping):
                    color_hex = image_color_mapping[index].get('colorHex', '#000000').lower()
                    print(f"  Image {index} ({filename}) → Color: {image_color_mapping[index].get('colorName')} ({color_hex})")
                    
                    # Add to color map
                    if color_hex not in color_image_map:
                        color_image_map[color_hex] = []
                    color_image_map[color_hex].append(image_path)
                else:
                    print(f"  [WARN] Warning: No color mapping for image {index}")
        
        if not color_image_map:
            return jsonify({'success': False, 'message': 'No valid images uploaded'}), 400
        
        print(f"[IMAGE] Color-Image Map: {color_image_map}")
        
        # Get seller_id from session
        seller_id = session.get('seller_id')
        
        # Connect to database
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            # Determine SDG value based on checkboxes
            if is_handmade and is_biodegradable:
                sdg_value = 'both'
            elif is_handmade:
                sdg_value = 'handmade'
            elif is_biodegradable:
                sdg_value = 'biodegradable'
            else:
                sdg_value = None
            
            # Insert into products table
            insert_product_query = """
                INSERT INTO products 
                (seller_id, product_name, description, materials, SDG, price, category, is_active)
                VALUES (%s, %s, %s, %s, %s, %s, %s, TRUE)
            """
            cursor.execute(insert_product_query, (
                seller_id,
                product_name,
                description,
                materials if materials else None,
                sdg_value,
                price,
                category
            ))
            
            # Get the inserted product_id
            product_id = cursor.lastrowid
            
            # Insert product variants (exact color-size pairs, no Cartesian product)
            variant_ids_by_color = {}  # Maps color_hex to list of variant_ids
            
            for variant_data in product_variants:
                color_hex = variant_data.get('colorHex', '#000000').lower()
                color_name = variant_data.get('colorName', 'Black')
                size = variant_data.get('size')
                quantity = variant_data.get('quantity', 1)
                
                # Get the first image path for this color (for variant display)
                image_paths = color_image_map.get(color_hex, [])
                variant_image_url = image_paths[0] if image_paths else None
                
                # Insert this specific variant
                insert_variant_query = """
                    INSERT INTO product_variants 
                    (product_id, color, hex_code, size, stock_quantity, image_url)
                    VALUES (%s, %s, %s, %s, %s, %s)
                """
                cursor.execute(insert_variant_query, (
                    product_id,
                    color_name,
                    color_hex,
                    size,
                    quantity,
                    variant_image_url
                ))
                
                # Store the variant_id for this color
                variant_id = cursor.lastrowid
                if color_hex not in variant_ids_by_color:
                    variant_ids_by_color[color_hex] = []
                variant_ids_by_color[color_hex].append(variant_id)
            
            # Now insert images linked to the first variant of each color
            image_counter = 0
            for color_hex, image_paths in color_image_map.items():
                # Get the first variant_id for this color
                variant_ids = variant_ids_by_color.get(color_hex, [])
                first_variant_id = variant_ids[0] if variant_ids else None
                
                for img_idx, image_path in enumerate(image_paths):
                    insert_image_query = """
                        INSERT INTO product_images 
                        (product_id, variant_id, image_url, is_primary, display_order)
                        VALUES (%s, %s, %s, %s, %s)
                    """
                    is_primary = (image_counter == 0)  # First image overall is primary
                    cursor.execute(insert_image_query, (
                        product_id, 
                        first_variant_id,
                        image_path, 
                        is_primary, 
                        image_counter
                    ))
                    image_counter += 1
            
            # Commit the transaction
            connection.commit()
            
            # Get all images from database to show actual count
            cursor.execute("""
                SELECT image_url FROM product_images 
                WHERE product_id = %s 
                ORDER BY display_order ASC
            """, (product_id,))
            
            all_images_from_db = [row['image_url'] for row in cursor.fetchall()]
            
            product_data = {
                'product_id': product_id,
                'product_name': product_name,
                'category': category,
                'price': price,
                'stock': stock,
                'description': description,
                'sdg': sdg_value,
                'images': all_images_from_db,
                'total_images': len(all_images_from_db)
            }
            
            print(f"Product added to database: {product_data}")
            
            return jsonify({
                'success': True,
                'message': 'Product added successfully and is now visible to buyers!',
                'product': product_data
            }), 201
            
        except Exception as db_error:
            connection.rollback()
            print(f"Database error: {str(db_error)}")
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
        finally:
            close_db_connection(connection, cursor)
        
    except Exception as e:
        print(f"Error adding product: {str(e)}")
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@seller_product_management_bp.route('/api/products/<int:product_id>', methods=['GET'])
@seller_required
def get_product(product_id):
    print("=" * 50)
    print(f"GET PRODUCT API CALLED - Product ID: {product_id}")
    print("=" * 50)
    
    try:
        seller_id = session.get('seller_id')
        
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
                    p.is_active
                FROM products p
                WHERE p.product_id = %s AND p.seller_id = %s
            """
            cursor.execute(query, (product_id, seller_id))
            product = cursor.fetchone()
            
            if not product:
                return jsonify({'success': False, 'message': 'Product not found'}), 404
            
            # Convert to regular dict if needed
            product_dict = dict(product) if product else {}
            
            # Fetch product variants with color info
            variant_query = """
                SELECT pv.variant_id, pv.color, pv.hex_code, pv.size, pv.stock_quantity, pv.image_url
                FROM product_variants pv
                WHERE pv.product_id = %s
                ORDER BY pv.color, pv.size
            """
            cursor.execute(variant_query, (product_id,))
            variants = cursor.fetchall()
            
            print(f"Fetched {len(variants)} variants for product {product_id}")
            
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
                
                # Debug logging
                print(f"[DEBUG] Variant {variant['variant_id']} ({variant['color']} {variant['size']}):")
                print(f"   - Found {len(variant_images)} images in product_images table")
                print(f"   - variant.image_url: {variant.get('image_url')}")
                if variant_images:
                    for idx, img in enumerate(variant_images):
                        print(f"   - Image {idx}: {img['image_url']} (primary: {img['is_primary']}, order: {img['display_order']})")
                else:
                    print(f"   - [WARN] No images found in product_images table for this variant!")
                
                variants_list.append(variant_dict)
            
            product_dict['variants'] = variants_list
            
            print(f"Final product dict keys: {product_dict.keys()}")
            print(f"Variants in product_dict: {product_dict.get('variants')}")
            
            return jsonify({
                'success': True,
                'product': product_dict,
                'test_message': 'NEW CODE IS RUNNING!',
                'variants_count': len(variants_list)
            }), 200
            
        except Exception as db_error:
            print(f"Database error: {str(db_error)}")
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
        finally:
            close_db_connection(connection, cursor)
        
    except Exception as e:
        print(f"Error fetching product: {str(e)}")
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@seller_product_management_bp.route('/api/products/<int:product_id>', methods=['PUT'])
def update_product(product_id):
    print("\n" + "="*60)
    print(f"[UPDATE] UPDATE PRODUCT REQUEST RECEIVED - Product ID: {product_id}")
    print("="*60)
    
    try:
        import json
        
        seller_id = session.get('seller_id', 1)
        print(f"[USER] Seller ID: {seller_id}")
        
        # Get form data
        product_name = request.form.get('productName')
        category = request.form.get('productCategory')
        
        # Convert combined category to database format
        if category == 'activewear-yoga':
            category = 'Active Wear-Yoga Pants'  # Save as Active Wear-Yoga Pants
        
        price = request.form.get('productPrice')
        description = request.form.get('productDescription', '')
        materials = request.form.get('productMaterials', '')
        
        print(f"[FORM] FORM DATA RECEIVED:")
        print(f"  productName: '{product_name}'")
        print(f"  productCategory: '{category}'")
        print(f"  productPrice: '{price}'")
        
        # Get SDG checkboxes
        is_handmade = 'productHandmade' in request.form
        is_biodegradable = 'productBiodegradable' in request.form
        
        # Get variants data
        variants_json = request.form.get('variantsData', '[]')
        try:
            variants_data = json.loads(variants_json)
        except:
            variants_data = []
        
        # Get new variants data (for Add Variant modal)
        new_variants_json = request.form.get('newVariantsData', '[]')
        try:
            new_variants = json.loads(new_variants_json)
        except:
            new_variants = []
        
        # Check if this is only adding variants (check for special flag)
        add_variants_only_flag = request.form.get('addVariantsOnly', 'false')
        is_only_adding_variants = (add_variants_only_flag == 'true')
        
        print(f"[DEBUG] DEBUG - Add Variant Check:")
        print(f"  product_name: {product_name}")
        print(f"  new_variants: {new_variants}")
        print(f"  new_variants length: {len(new_variants)}")
        print(f"  is_only_adding_variants: {is_only_adding_variants}")
        
        # Validate required fields only if updating product info
        if not is_only_adding_variants:
            if not all([product_name, category, price]):
                return jsonify({'success': False, 'message': 'All required fields must be filled'}), 400
            
            try:
                price = float(price)
                if price <= 0:
                    raise ValueError('Invalid price')
            except ValueError as e:
                return jsonify({'success': False, 'message': str(e)}), 400
        
        # Connect to database
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            # Verify product belongs to seller
            cursor.execute("SELECT seller_id FROM products WHERE product_id = %s", (product_id,))
            product = cursor.fetchone()
            
            if not product or product['seller_id'] != seller_id:
                return jsonify({'success': False, 'message': 'Product not found or unauthorized'}), 404
            
            # Only update product info if not just adding variants
            if not is_only_adding_variants:
                # Determine SDG value
                if is_handmade and is_biodegradable:
                    sdg_value = 'both'
                elif is_handmade:
                    sdg_value = 'handmade'
                elif is_biodegradable:
                    sdg_value = 'biodegradable'
                else:
                    sdg_value = None
                
                # Update product basic info first (without stock)
                update_query = """
                    UPDATE products 
                    SET product_name = %s, description = %s, materials = %s, SDG = %s, 
                        price = %s, category = %s
                    WHERE product_id = %s
                """
                cursor.execute(update_query, (
                    product_name,
                    description,
                    materials if materials else None,
                    sdg_value,
                    price,
                    category,
                    product_id
                ))
                
                # Update variants
                for variant in variants_data:
                    variant_id = variant.get('variant_id')
                    quantity = int(variant.get('quantity', 0))
                    
                    if variant_id:
                        # Update existing variant
                        cursor.execute(
                            "UPDATE product_variants SET stock_quantity = %s WHERE variant_id = %s",
                            (quantity, variant_id)
                        )
            
            # Handle new variant images if uploaded
            uploaded_files = request.files.getlist('newVariantImages')
            
            if new_variants and len(new_variants) > 0:
                # Create upload directory if it doesn't exist
                os.makedirs(UPLOAD_FOLDER, exist_ok=True)
                
                # Track cumulative image index across all variants
                file_index = 0
                
                # Map images to new variants
                for variant_index, new_variant in enumerate(new_variants):
                    color_hex = new_variant.get('hex')
                    color_name = new_variant.get('colorName')
                    size = new_variant.get('size')
                    quantity = int(new_variant.get('quantity', 0))
                    num_images = int(new_variant.get('numImages', 0))  # Get number of images for this variant
                    
                    print(f"\n[VARIANT] Processing variant {variant_index}: {color_name} - {size}")
                    print(f"   Expected images: {num_images}, Starting at file_index: {file_index}")
                    
                    # Insert new variant first to get variant_id
                    cursor.execute(
                        """INSERT INTO product_variants 
                           (product_id, color, hex_code, size, stock_quantity, image_url)
                           VALUES (%s, %s, %s, %s, %s, %s)""",
                        (product_id, color_name, color_hex, size, quantity, None)
                    )
                    variant_id = cursor.lastrowid
                    print(f"   [OK] Created variant_id: {variant_id}")
                    
                    # Handle image uploads for this variant
                    first_image_url = None
                    for img_idx in range(num_images):
                        if file_index < len(uploaded_files):
                            file = uploaded_files[file_index]
                            if file and file.filename and allowed_file(file.filename):
                                timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                                filename = secure_filename(file.filename)
                                unique_filename = f"{timestamp}_{variant_id}_{img_idx}_{filename}"
                                filepath = os.path.join(UPLOAD_FOLDER, unique_filename)
                                file.save(filepath)
                                # Store path for database (with 'static/' prefix for Flask)
                                image_url = f"{UPLOAD_FOLDER_DB}/{unique_filename}"
                                
                                # Save first image for variant's image_url
                                if img_idx == 0:
                                    first_image_url = image_url
                                
                                # Get current max display_order for this product
                                cursor.execute(
                                    "SELECT COALESCE(MAX(display_order), -1) as max_order FROM product_images WHERE product_id = %s",
                                    (product_id,)
                                )
                                max_order_result = cursor.fetchone()
                                current_max_order = max_order_result['max_order'] if max_order_result else -1
                                
                                # Insert into product_images with variant_id
                                is_primary = (img_idx == 0 and current_max_order == -1)
                                display_order = current_max_order + 1 + img_idx
                                cursor.execute(
                                    """INSERT INTO product_images 
                                       (product_id, variant_id, image_url, is_primary, display_order)
                                       VALUES (%s, %s, %s, %s, %s)""",
                                    (product_id, variant_id, image_url, is_primary, display_order)
                                )
                                print(f"   [OK] Uploaded image {img_idx + 1}/{num_images}: {unique_filename}")
                            
                            file_index += 1
                    
                    # Update variant's image_url to first image
                    if first_image_url:
                        cursor.execute(
                            "UPDATE product_variants SET image_url = %s WHERE variant_id = %s",
                            (first_image_url, variant_id)
                        )
                        print(f"   [OK] Set variant image_url to: {first_image_url}")
                    else:
                        # No image uploaded - try to get image from existing variant with same color
                        cursor.execute(
                            "SELECT image_url FROM product_variants WHERE product_id = %s AND hex_code = %s AND image_url IS NOT NULL AND variant_id != %s LIMIT 1",
                            (product_id, color_hex, variant_id)
                        )
                        existing_variant = cursor.fetchone()
                        if existing_variant:
                            cursor.execute(
                                "UPDATE product_variants SET image_url = %s WHERE variant_id = %s",
                                (existing_variant['image_url'], variant_id)
                            )
                            print(f"   [INFO] Using existing color image: {existing_variant['image_url']}")
            
            # Handle deleted images
            deleted_images_json = request.form.get('deletedImages', '[]')
            print(f"\n[DEBUG] DEBUG - deletedImages JSON: {deleted_images_json}")
            try:
                deleted_images = json.loads(deleted_images_json)
                if deleted_images and len(deleted_images) > 0:
                    print(f"\n[DELETE] DELETING {len(deleted_images)} IMAGES")
                    for img_info in deleted_images:
                        image_url_raw = img_info.get('imageUrl', '')
                        variant_id = img_info.get('variantId')
                        
                        print(f"  [INPUT] Raw imageUrl from frontend: '{image_url_raw}'")
                        print(f"  [INPUT] Variant ID: {variant_id}")
                        
                        # Try both with and without 'static/' prefix
                        image_url_with_static = image_url_raw.lstrip('/')
                        image_url_without_static = image_url_raw.replace('static/', '').lstrip('/')
                        
                        print(f"  [DEBUG] Trying to delete:")
                        print(f"     - With static: '{image_url_with_static}'")
                        print(f"     - Without static: '{image_url_without_static}'")
                        
                        # Check what's actually in the database
                        cursor.execute(
                            "SELECT image_url FROM product_images WHERE variant_id = %s",
                            (variant_id,)
                        )
                        db_images = cursor.fetchall()
                        print(f"  [STATS] Images in DB for variant {variant_id}:")
                        for db_img in db_images:
                            print(f"     - '{db_img['image_url']}'")
                        
                        # Try to delete with both formats
                        cursor.execute(
                            "DELETE FROM product_images WHERE (image_url = %s OR image_url = %s) AND variant_id = %s",
                            (image_url_with_static, image_url_without_static, variant_id)
                        )
                        rows_deleted = cursor.rowcount
                        print(f"  [OK] Deleted {rows_deleted} row(s) from product_images")
                        
                        # Update product_variants.image_url if this was the variant's display image
                        cursor.execute(
                            "SELECT image_url FROM product_variants WHERE variant_id = %s",
                            (variant_id,)
                        )
                        variant_result = cursor.fetchone()
                        if variant_result:
                            variant_img_url = variant_result['image_url']
                            print(f"  [STATS] Variant's current image_url: '{variant_img_url}'")
                            
                            # Check if deleted image matches variant's image (with or without static/)
                            if variant_img_url == image_url_with_static or variant_img_url == image_url_without_static:
                                # Get remaining images for this variant
                                cursor.execute(
                                    "SELECT image_url FROM product_images WHERE variant_id = %s ORDER BY display_order LIMIT 1",
                                    (variant_id,)
                                )
                                new_image = cursor.fetchone()
                                new_image_url = new_image['image_url'] if new_image else None
                                
                                # Update variant's image_url
                                cursor.execute(
                                    "UPDATE product_variants SET image_url = %s WHERE variant_id = %s",
                                    (new_image_url, variant_id)
                                )
                                print(f"  [OK] Updated variant {variant_id} image_url to: {new_image_url}")
                            else:
                                print(f"  [INFO] Variant image_url doesn't match deleted image, no update needed")
                        
                        # Delete physical file
                        try:
                            file_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), image_url)
                            if os.path.exists(file_path):
                                os.remove(file_path)
                                print(f"  [OK] Deleted file: {file_path}")
                            else:
                                print(f"  [WARN] File not found: {file_path}")
                        except Exception as file_error:
                            print(f"  [WARN] Could not delete file: {str(file_error)}")
            except Exception as delete_error:
                print(f"[WARN] Error processing deleted images: {str(delete_error)}")
                import traceback
                traceback.print_exc()
            
            # Handle variant image uploads and updates
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
                                # Store path for database (with 'static/' prefix for Flask)
                                image_url = f"{UPLOAD_FOLDER_DB}/{unique_filename}"
                                
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
                    
            
            # Handle image reordering for ALL variants (not just those with new images)
            print(f"\n[REORDER] PROCESSING IMAGE REORDERING")
            for key in request.form.keys():
                if key.startswith('variant_') and key.endswith('_image_order'):
                    # Extract variant_id from key like "variant_45_image_order"
                    variant_id = key.replace('variant_', '').replace('_image_order', '')
                    
                    try:
                        image_order = json.loads(request.form.get(key))
                        print(f"  Reordering {len(image_order)} images for variant {variant_id}")
                        
                        # First, reset all is_primary flags for this variant
                        cursor.execute(
                            "UPDATE product_images SET is_primary = FALSE WHERE variant_id = %s",
                            (variant_id,)
                        )
                        
                        # Update display_order and is_primary for existing images
                        primary_image_url = None
                        for idx, img_info in enumerate(image_order):
                            if not img_info.get('isNew') and img_info.get('url'):
                                # Clean the URL (remove leading slash if present)
                                clean_url = img_info['url'].lstrip('/')
                                
                                print(f"    Attempting to update: {clean_url}")
                                print(f"      variant_id={variant_id}, idx={idx}, is_primary={idx == 0}")
                                
                                cursor.execute(
                                    """UPDATE product_images 
                                       SET display_order = %s, is_primary = %s 
                                       WHERE variant_id = %s AND image_url = %s""",
                                    (idx, idx == 0, variant_id, clean_url)
                                )
                                rows_affected = cursor.rowcount
                                print(f"    [OK] Rows affected: {rows_affected}")
                                
                                # Store the primary image URL
                                if idx == 0:
                                    primary_image_url = clean_url
                                
                                if rows_affected == 0:
                                    print(f"    [WARN] WARNING: No rows updated! Image might not exist in DB.")
                                    # Debug: Check what's actually in the database
                                    cursor.execute(
                                        "SELECT image_url FROM product_images WHERE variant_id = %s",
                                        (variant_id,)
                                    )
                                    db_images = cursor.fetchall()
                                    print(f"    Images in DB for variant {variant_id}:")
                                    for db_img in db_images:
                                        print(f"      - {db_img['image_url']}")
                        
                        # Update product_variants table with the primary image URL
                        if primary_image_url:
                            cursor.execute(
                                "UPDATE product_variants SET image_url = %s WHERE variant_id = %s",
                                (primary_image_url, variant_id)
                            )
                            print(f"    [OK] Updated product_variants.image_url to: {primary_image_url}")
                    except Exception as order_error:
                        print(f"    [WARN] Error reordering images for variant {variant_id}: {str(order_error)}")
            
            connection.commit()
            
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

@seller_product_management_bp.route('/api/products/variants/<int:variant_id>', methods=['DELETE'])
@seller_required
def delete_variant(variant_id):
    try:
        seller_id = session.get('seller_id')
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            # Verify variant belongs to seller's product
            cursor.execute("""
                SELECT pv.product_id, p.seller_id 
                FROM product_variants pv
                JOIN products p ON pv.product_id = p.product_id
                WHERE pv.variant_id = %s
            """, (variant_id,))
            
            result = cursor.fetchone()
            if not result or result['seller_id'] != seller_id:
                return jsonify({'success': False, 'message': 'Variant not found or unauthorized'}), 404
            
            product_id = result['product_id']
            
            # Delete variant
            cursor.execute("DELETE FROM product_variants WHERE variant_id = %s", (variant_id,))
            
            # Color information is now stored directly in product_variants
            # No need to delete from separate product_colors table
            
            connection.commit()
            
            return jsonify({
                'success': True,
                'message': 'Variant deleted successfully'
            }), 200
            
        except Exception as db_error:
            connection.rollback()
            print(f"Database error: {str(db_error)}")
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
        finally:
            close_db_connection(connection, cursor)
        
    except Exception as e:
        print(f"Error deleting variant: {str(e)}")
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@seller_product_management_bp.route('/api/products/<int:product_id>/archive', methods=['PUT'])
@seller_required
def archive_product(product_id):
    """Archive a product (soft delete - hide from store but keep data)"""
    try:
        seller_id = session.get('seller_id')
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            # Verify product belongs to seller
            cursor.execute(
                "SELECT seller_id, is_active FROM products WHERE product_id = %s",
                (product_id,)
            )
            product = cursor.fetchone()
            
            if not product:
                return jsonify({'success': False, 'message': 'Product not found'}), 404
            
            if product['seller_id'] != seller_id:
                return jsonify({'success': False, 'message': 'Unauthorized to archive this product'}), 403
            
            # Toggle is_active status (archive/unarchive)
            new_status = 0 if product['is_active'] else 1
            cursor.execute(
                "UPDATE products SET is_active = %s WHERE product_id = %s",
                (new_status, product_id)
            )
            
            connection.commit()
            
            action = 'archived' if new_status == 0 else 'restored'
            return jsonify({
                'success': True,
                'message': f'Product {action} successfully'
            }), 200
            
        except Exception as db_error:
            connection.rollback()
            print(f"Database error: {str(db_error)}")
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
        finally:
            close_db_connection(connection, cursor)
        
    except Exception as e:
        print(f"Error archiving product: {str(e)}")
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@seller_product_management_bp.route('/api/products/<int:product_id>', methods=['DELETE'])
@seller_required
def delete_product(product_id):
    """Delete a product and all its associated data"""
    try:
        seller_id = session.get('seller_id')
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            # Verify product belongs to seller
            cursor.execute(
                "SELECT seller_id FROM products WHERE product_id = %s",
                (product_id,)
            )
            product = cursor.fetchone()
            
            if not product:
                return jsonify({'success': False, 'message': 'Product not found'}), 404
            
            if product['seller_id'] != seller_id:
                return jsonify({'success': False, 'message': 'Unauthorized to delete this product'}), 403
            
            # Delete in correct order due to foreign key constraints
            # 1. Delete product variants
            cursor.execute("DELETE FROM product_variants WHERE product_id = %s", (product_id,))
            
            # 2. Product colors are now part of product_variants (no separate table)
            
            # 3. Delete product images
            cursor.execute("DELETE FROM product_images WHERE product_id = %s", (product_id,))
            
            # 4. Delete the product itself
            cursor.execute("DELETE FROM products WHERE product_id = %s", (product_id,))
            
            connection.commit()
            
            return jsonify({
                'success': True,
                'message': 'Product deleted successfully'
            }), 200
            
        except Exception as db_error:
            connection.rollback()
            print(f"Database error: {str(db_error)}")
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
        finally:
            close_db_connection(connection, cursor)
        
    except Exception as e:
        print(f"Error deleting product: {str(e)}")
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@seller_product_management_bp.route('/api/orders/seller', methods=['GET'])
@seller_required
def list_seller_orders():
    try:
        seller_id = session.get('seller_id')
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        cursor = connection.cursor(dictionary=True)
        try:
            # Fetch order info (with buyer info and delivery status) for seller
            order_query = """
                SELECT o.order_id, o.order_number, o.created_at, o.subtotal, o.total_amount, o.order_status,
                       CONCAT(b.first_name, ' ', b.last_name) as buyer_name,
                       d.status as delivery_status
                FROM orders o
                JOIN buyers b ON o.buyer_id = b.buyer_id
                LEFT JOIN deliveries d ON o.order_id = d.order_id
                WHERE o.seller_id = %s
                ORDER BY o.created_at DESC
            """
            cursor.execute(order_query, (seller_id,))
            orders = cursor.fetchall()
            
            # Fetch order items for each order (with product image and variant info)
            for order in orders:
                items_query = """
                    SELECT oi.product_id, oi.product_name, oi.quantity, oi.unit_price,
                           oi.variant_color, oi.variant_size,
                           (SELECT image_url FROM product_images WHERE product_id = oi.product_id AND is_primary = TRUE LIMIT 1) as image
                    FROM order_items oi
                    WHERE oi.order_id = %s
                """
                cursor.execute(items_query, (order['order_id'],))
                order['items'] = cursor.fetchall()
            
            return jsonify({'success': True, 'orders': orders}), 200
        except Exception as db_error:
            print(f"Database error: {str(db_error)}")
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        finally:
            close_db_connection(connection, cursor)
    except Exception as e:
        print(f"Error fetching seller orders: {str(e)}")
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@seller_product_management_bp.route('/api/orders/<int:order_id>/preparing', methods=['POST'])
@seller_required
def mark_order_preparing(order_id):
    """Mark order as being prepared by seller"""
    try:
        seller_id = session.get('seller_id')
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        cursor = connection.cursor(dictionary=True)
        try:
            # Verify this order belongs to the seller
            cursor.execute("SELECT seller_id FROM orders WHERE order_id = %s", (order_id,))
            order = cursor.fetchone()
            
            if not order:
                return jsonify({'success': False, 'message': 'Order not found'}), 404
            
            if order['seller_id'] != seller_id:
                return jsonify({'success': False, 'message': 'Unauthorized'}), 403
            
            # Update delivery status to preparing
            cursor.execute("""
                UPDATE deliveries 
                SET status = 'preparing' 
                WHERE order_id = %s
            """, (order_id,))
            
            connection.commit()
            return jsonify({'success': True, 'message': 'Package preparation started'}), 200
            
        except Exception as db_error:
            connection.rollback()
            print(f"Database error: {str(db_error)}")
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        finally:
            close_db_connection(connection, cursor)
    except Exception as e:
        print(f"Error marking order as preparing: {str(e)}")
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@seller_product_management_bp.route('/api/orders/<int:order_id>/ready-for-pickup', methods=['POST'])
@seller_required
def mark_order_ready_for_pickup(order_id):
    """Mark order as ready for pickup by rider"""
    try:
        seller_id = session.get('seller_id')
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        cursor = connection.cursor(dictionary=True)
        try:
            # Verify this order belongs to the seller
            cursor.execute("SELECT seller_id FROM orders WHERE order_id = %s", (order_id,))
            order = cursor.fetchone()
            
            if not order:
                return jsonify({'success': False, 'message': 'Order not found'}), 404
            
            if order['seller_id'] != seller_id:
                return jsonify({'success': False, 'message': 'Unauthorized'}), 403
            
            # Keep order status as pending, just mark delivery as ready for rider
            # Order will only become 'in_transit' when rider picks it up
            
            # Update delivery status to pending (ready for rider to accept)
            cursor.execute("""
                UPDATE deliveries 
                SET status = 'pending' 
                WHERE order_id = %s
            """, (order_id,))
            
            connection.commit()
            return jsonify({'success': True, 'message': 'Order marked as ready for pickup'}), 200
            
        except Exception as db_error:
            connection.rollback()
            print(f"Database error: {str(db_error)}")
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        finally:
            close_db_connection(connection, cursor)
    except Exception as e:
        print(f"Error marking order ready for pickup: {str(e)}")
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@seller_product_management_bp.route('/api/products/sold', methods=['GET'])
@seller_required
def list_sold_products():
    """Get list of sold products for the seller"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        # Get seller_id from session
        cursor.execute("SELECT seller_id FROM sellers WHERE user_id = %s", (session['user_id'],))
        seller = cursor.fetchone()
        
        if not seller:
            return jsonify({'success': False, 'message': 'Seller not found'}), 404
        
        seller_id = seller['seller_id']
        
        # Get sold products (orders that are delivered and confirmed by buyer) - grouped by order
        query = """
            SELECT 
                o.order_id,
                o.order_number,
                o.subtotal as order_total,
                o.commission_amount,
                o.updated_at as order_received_date,
                CONCAT(b.first_name, ' ', b.last_name) as buyer_name,
                b.phone_number as buyer_phone
            FROM orders o
            JOIN buyers b ON o.buyer_id = b.buyer_id
            WHERE o.seller_id = %s 
            AND o.order_status = 'delivered'
            AND o.order_received = TRUE
            ORDER BY o.updated_at DESC
        """
        
        cursor.execute(query, (seller_id,))
        sold_orders = cursor.fetchall()
        
        # Get order items for each sold order
        for order in sold_orders:
            cursor.execute("""
                SELECT 
                    product_name,
                    variant_color,
                    variant_size,
                    quantity,
                    unit_price,
                    subtotal
                FROM order_items
                WHERE order_id = %s
            """, (order['order_id'],))
            order['items'] = cursor.fetchall()
        
        close_db_connection(connection, cursor)
        
        return jsonify({'success': True, 'sold_orders': sold_orders}), 200
        
    except Exception as e:
        print(f"Error fetching sold products: {str(e)}")
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

