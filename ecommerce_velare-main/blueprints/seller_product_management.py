from flask import Blueprint, render_template, request, jsonify, session
from werkzeug.utils import secure_filename
import os
import sys
from datetime import datetime

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_config import get_db_connection, close_db_connection, get_supabase_client
from utils.auth_decorators import seller_required

seller_product_management_bp = Blueprint('seller_product_management', __name__)

# Configure upload folder
UPLOAD_FOLDER = 'static/uploads/products'  # Full path for saving files
UPLOAD_FOLDER_DB = 'static/uploads/products'  # Path for database (with 'static/' for Flask url_for)
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'avif'}

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def upload_product_to_supabase_storage(file, unique_filename):
    """
    Upload product image to Supabase Storage and return the public URL.
    
    Args:
        file: FileStorage object from Flask request
        unique_filename: Unique filename with path (e.g., 'static/uploads/products/20260209_120000_0_image.jpg')
    
    Returns:
        str: Public URL of the uploaded file
    """
    try:
        supabase = get_supabase_client()
        if not supabase:
            raise Exception("Supabase client not available")
        
        # Read file content
        file.seek(0)  # Reset file pointer to beginning
        file_content = file.read()
        
        # Upload to Supabase Storage bucket "Images"
        upload_response = supabase.storage.from_('Images').upload(
            unique_filename,
            file_content,
            {'content-type': file.content_type}
        )
        
        # Get public URL
        public_url = supabase.storage.from_('Images').get_public_url(unique_filename)
        
        return public_url
        
    except Exception as e:
        print(f"    ❌ Error uploading to Supabase: {str(e)}")
        raise

def fix_variant_images():
    """Fix existing variants that have NULL image_url by copying from variants with same color"""
    """Fix existing variants that have NULL image_url by copying from variants with same color"""
    try:
        print("🔧 Fixing NULL variant images...")
        supabase = get_supabase_client()
        
        # Get all variants with NULL image_url
        null_variants = supabase.table('product_variants').select('variant_id, product_id, hex_code').is_('image_url', 'null').execute()
        
        fixed_count = 0
        for variant in null_variants.data:
            # Find a variant with the same hex_code and product_id that has an image
            source_variant = supabase.table('product_variants').select('image_url').eq('product_id', variant['product_id']).eq('hex_code', variant['hex_code']).not_.is_('image_url', 'null').limit(1).execute()
            
            if source_variant.data:
                # Update the NULL variant with the image from source
                supabase.table('product_variants').update({'image_url': source_variant.data[0]['image_url']}).eq('variant_id', variant['variant_id']).execute()
                fixed_count += 1
        
        if fixed_count > 0:
            print(f"✅ Fixed {fixed_count} variants with missing images")
        
    except Exception as e:
        print(f"❌ Error fixing variant images: {str(e)}")

@seller_product_management_bp.route('/seller/product-management')
@seller_required
def seller_product_management():
    """Display seller product management page with seller info from Supabase"""
    # Get seller info for profile display
    seller_id = session.get('seller_id')
    print(f"🔍 Loading product management page for seller_id: {seller_id}")
    
    seller_info = None
    
    supabase = get_supabase_client()
    if supabase:
        try:
            # Get seller info from Supabase
            seller_response = supabase.table('sellers').select(
                'shop_name, shop_logo'
            ).eq('seller_id', seller_id).execute()
            
            if seller_response.data:
                seller_info = seller_response.data[0]
                print(f"✅ Seller info loaded: {seller_info.get('shop_name')}")
            else:
                print(f"⚠️ No seller info found for seller_id: {seller_id}")
        except Exception as e:
            print(f"❌ Error fetching seller info: {str(e)}")
    else:
        print("❌ Supabase client not available")
    
    return render_template('seller/seller_product_management.html', seller=seller_info)

@seller_product_management_bp.route('/api/products/list', methods=['GET'])
@seller_required
def list_products():
    """Fetch all products for the seller from Supabase"""
    print(f"\n{'='*80}")
    print(f"📦 [PRODUCT LIST] Loading products...")
    print(f"{'='*80}\n")
    
    try:
        # Get seller_id from session - guaranteed to exist due to @seller_required decorator
        seller_id = session.get('seller_id')
        print(f"🔍 Seller ID: {seller_id}")
        
        supabase = get_supabase_client()
        if not supabase:
            print("❌ Supabase client not available")
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Fetch products for this seller
            print(f"📊 Fetching products...")
            products_response = supabase.table('products').select(
                'product_id, product_name, description, materials, price, category, is_active, created_at, sdg'
            ).eq('seller_id', seller_id).order('created_at', desc=True).execute()
            
            print(f"📦 Found {len(products_response.data) if products_response.data else 0} products")
            
            products = []
            if products_response.data:
                # Collect all product IDs for batch fetching
                product_ids = [p['product_id'] for p in products_response.data]
                
                # Batch fetch all product images (not linked to variants)
                print(f"🖼️ Batch fetching product images...")
                all_product_images_response = supabase.table('product_images').select(
                    'product_id, image_url, is_primary, display_order'
                ).in_('product_id', product_ids).is_('variant_id', 'null').order('display_order').execute()
                
                # Group product images by product_id
                product_images_dict = {}
                if all_product_images_response.data:
                    for img in all_product_images_response.data:
                        pid = img['product_id']
                        if pid not in product_images_dict:
                            product_images_dict[pid] = []
                        product_images_dict[pid].append(img['image_url'])
                
                print(f"🖼️ Found {len(all_product_images_response.data) if all_product_images_response.data else 0} product images")
                
                # Batch fetch all variants
                print(f"🎨 Batch fetching variants...")
                all_variants_response = supabase.table('product_variants').select(
                    'variant_id, product_id, color, size, stock_quantity, image_url, hex_code'
                ).in_('product_id', product_ids).order('color').order('size').execute()
                
                # Group variants by product_id
                variants_dict = {}
                variant_ids = []
                if all_variants_response.data:
                    for variant in all_variants_response.data:
                        pid = variant['product_id']
                        if pid not in variants_dict:
                            variants_dict[pid] = []
                        variants_dict[pid].append(variant)
                        variant_ids.append(variant['variant_id'])
                
                print(f"🎨 Found {len(all_variants_response.data) if all_variants_response.data else 0} variants")
                
                # Batch fetch all variant images
                print(f"🖼️ Batch fetching variant images...")
                variant_images_dict = {}
                if variant_ids:
                    all_variant_images_response = supabase.table('product_images').select(
                        'variant_id, image_url, is_primary, display_order'
                    ).in_('variant_id', variant_ids).order('display_order').execute()
                    
                    # Group variant images by variant_id
                    if all_variant_images_response.data:
                        for img in all_variant_images_response.data:
                            vid = img['variant_id']
                            if vid not in variant_images_dict:
                                variant_images_dict[vid] = []
                            variant_images_dict[vid].append({
                                'url': img['image_url'],
                                'is_primary': img['is_primary']
                            })
                    
                    print(f"🖼️ Found {len(all_variant_images_response.data) if all_variant_images_response.data else 0} variant images")
                
                # Batch check which products have ANY order_items references.
                # The FK constraint on order_items.product_id blocks deletion regardless
                # of the order's status, so any reference must disable the delete button.
                print(f"📦 Batch checking products with existing orders...")
                order_items_response = supabase.table('order_items').select(
                    'product_id, order_id'
                ).in_('product_id', product_ids).execute()

                products_with_orders = set()
                product_to_order_ids = {}
                if order_items_response.data:
                    for item in order_items_response.data:
                        pid_o = item['product_id']
                        oid_o = item.get('order_id')
                        products_with_orders.add(pid_o)
                        if oid_o is not None:
                            product_to_order_ids.setdefault(pid_o, set()).add(oid_o)

                # Determine which products have ONGOING orders (still in fulfillment).
                # Ongoing = order_status in ('pending', 'in_transit'). The order_status
                # enum only has these four values: pending, in_transit, delivered,
                # cancelled. Sellers may also mark a delivery as 'preparing', but
                # that lives on the deliveries.delivery_status column, not on
                # orders.order_status — those orders are still 'pending' here.
                # Archiving an ongoing order would orphan in-flight orders, so the
                # seller must wait.
                products_with_ongoing_orders = set()
                all_referenced_order_ids = set()
                for oids in product_to_order_ids.values():
                    all_referenced_order_ids.update(oids)

                if all_referenced_order_ids:
                    ongoing_orders_response = supabase.table('orders').select(
                        'order_id'
                    ).in_('order_id', list(all_referenced_order_ids)).in_(
                        'order_status', ['pending', 'in_transit']
                    ).execute()
                    ongoing_order_ids = {
                        o['order_id'] for o in (ongoing_orders_response.data or [])
                    }
                    for pid_o, oids in product_to_order_ids.items():
                        if oids & ongoing_order_ids:
                            products_with_ongoing_orders.add(pid_o)

                print(
                    f"📦 Found {len(products_with_orders)} products with any orders, "
                    f"{len(products_with_ongoing_orders)} with ongoing orders"
                )
                
                # Process each product with batch-fetched data
                for product in products_response.data:
                    pid = product['product_id']
                    
                    # Convert created_at string to datetime if needed
                    if product.get('created_at') and isinstance(product['created_at'], str):
                        try:
                            product['created_at'] = datetime.fromisoformat(product['created_at'].replace('Z', '+00:00'))
                        except:
                            pass
                    
                    # Get product images from batch data
                    product['images'] = product_images_dict.get(pid, [])
                    
                    # Get variants from batch data
                    variants = variants_dict.get(pid, [])
                    
                    # Add variant images to each variant
                    product['primary_image'] = None
                    for variant in variants:
                        vid = variant['variant_id']
                        variant['images'] = variant_images_dict.get(vid, [])
                        
                        # Set primary_image to first variant's first image if not set yet
                        if not product['primary_image'] and variant['images']:
                            product['primary_image'] = variant['images'][0]['url']
                    
                    product['variants'] = variants
                    
                    # If no variant images, use product-level image as fallback
                    if not product['primary_image'] and product['images']:
                        product['primary_image'] = product['images'][0]
                    
                    # Calculate total stock from all variants
                    total_stock = sum(variant['stock_quantity'] for variant in variants) if variants else 0
                    product['stock_quantity'] = total_stock
                    
                    # Flag products that already have orders so the delete button
                    # can be disabled in the UI (FK constraint would otherwise fail).
                    product['has_orders'] = pid in products_with_orders
                    # Flag products with ongoing (un-fulfilled) orders so the UI
                    # can warn the seller before they try to archive.
                    product['has_ongoing_orders'] = pid in products_with_ongoing_orders
                    
                    products.append(product)
            
            response = jsonify({
                'success': True,
                'products': products
            })
            response.headers['Cache-Control'] = 'no-store, no-cache, must-revalidate, max-age=0'
            response.headers['Pragma'] = 'no-cache'
            response.headers['Expires'] = '0'
            
            print(f"✅ Returning {len(products)} products")
            print(f"{'='*80}\n")
            return response, 200
            
        except Exception as db_error:
            print(f"❌ Database error: {str(db_error)}")
            import traceback
            traceback.print_exc()
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
    except Exception as e:
        print(f"❌ Error fetching products: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@seller_product_management_bp.route('/api/products/add', methods=['POST'])
@seller_required
def add_product():
    """Add new product using Supabase"""
    try:
        import json
        
        print("\n" + "="*60)
        print("➕ ADD PRODUCT REQUEST RECEIVED")
        print("="*60)
        
        # Get form data
        product_name = request.form.get('productName')
        category = request.form.get('productCategory')
        
        # Convert form category to database format
        category_to_db = {
            'activewear': 'Active Wear',
            'yoga-pants': 'Yoga Pants',
            'dresses': 'Dresses',
            'skirts': 'Skirts',
            'tops': 'Tops',
            'blouses': 'Blouses',
            'lingerie': 'Lingerie',
            'sleepwear': 'Sleepwear',
            'jackets': 'Jackets',
            'coats': 'Coats',
            'shoes': 'Shoes',
            'accessories': 'Accessories'
        }
        
        db_category = category_to_db.get(category, category)
        print(f"📦 Category from form: {category} → DB: {db_category}")
        
        price = request.form.get('productPrice')
        description = request.form.get('productDescription', '')
        materials = request.form.get('productMaterials', '')
        product_variants_json = request.form.get('productColorsData', '[]')
        image_color_mapping_json = request.form.get('imageColorMapping', '[]')
        
        print(f"📝 Product Name: {product_name}")
        print(f"📂 Category: {db_category}")
        print(f"💰 Price: {price}")
        print(f"🎨 Variants JSON: {product_variants_json}")
        print(f"🖼️ Image-Color Mapping: {image_color_mapping_json}")
        print(f"📁 Files: {len(request.files.getlist('productImages'))} images")
        
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
        
        # Get stock from form or calculate from variants
        stock = request.form.get('productStock', 0)
        try:
            stock = int(stock)
        except:
            stock = sum(int(variant.get('quantity', 0)) for variant in product_variants)
        
        # Get SDG checkboxes
        is_handmade = 'productHandmade' in request.form
        is_biodegradable = 'productBiodegradable' in request.form
        
        print(f"🌱 SDG Checkboxes:")
        print(f"  Handmade: {is_handmade} (key in form: {'productHandmade' in request.form})")
        print(f"  Biodegradable: {is_biodegradable} (key in form: {'productBiodegradable' in request.form})")
        print(f"  All form keys: {list(request.form.keys())}")
        
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
        
        # Handle file uploads (variant images) - Upload to Supabase Storage
        uploaded_files = request.files.getlist('productImages')
        if not uploaded_files or uploaded_files[0].filename == '':
            return jsonify({'success': False, 'message': 'At least one product image is required'}), 400
        
        # Upload images to Supabase Storage and map them to colors
        color_image_map = {}  # Maps color hex to list of Supabase URLs
        
        print(f"\n🖼️ UPLOADING {len(uploaded_files)} IMAGES TO SUPABASE")
        for index, file in enumerate(uploaded_files):
            if file and allowed_file(file.filename):
                # Generate unique filename
                timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                filename = secure_filename(file.filename)
                unique_filename = f"static/uploads/products/{timestamp}_{index}_{filename}"
                
                # Upload to Supabase Storage
                image_url = upload_product_to_supabase_storage(file, unique_filename)
                
                # Get the color for this image from the mapping
                if index < len(image_color_mapping):
                    color_hex = image_color_mapping[index].get('colorHex', '#000000').lower()
                    color_name = image_color_mapping[index].get('colorName', 'Unknown')
                    print(f"  ✅ Image {index} ({filename}) → {color_name} ({color_hex})")
                    print(f"     Supabase URL: {image_url}")
                    
                    # Add to color map
                    if color_hex not in color_image_map:
                        color_image_map[color_hex] = []
                    color_image_map[color_hex].append(image_url)
                else:
                    print(f"  ⚠️ Warning: No color mapping for image {index}")
        
        if not color_image_map:
            return jsonify({'success': False, 'message': 'No valid images uploaded'}), 400
        
        print(f"\n📊 Color-Image Map: {len(color_image_map)} colors")
        
        # Get seller_id from session
        seller_id = session.get('seller_id')
        
        supabase = get_supabase_client()
        if not supabase:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
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
            
            print(f"\n🌱 SDG Value to be saved: {sdg_value}")
            
            # Insert into products table
            print(f"\n📝 Creating product in Supabase...")
            product_response = supabase.table('products').insert({
                'seller_id': seller_id,
                'product_name': product_name,
                'description': description,
                'materials': materials if materials else None,
                'sdg': sdg_value,
                'price': price,
                'category': db_category,
                'is_active': True
            }).execute()
            
            if not product_response.data:
                raise Exception("Failed to create product")
            
            product_id = product_response.data[0]['product_id']
            print(f"✅ Product created with ID: {product_id}")
            
            # Insert product variants (exact color-size pairs)
            variant_ids_by_color = {}  # Maps color_hex to list of variant_ids
            
            print(f"\n🎨 Creating {len(product_variants)} variants...")
            for variant_data in product_variants:
                color_hex = variant_data.get('colorHex', '#000000').lower()
                color_name = variant_data.get('colorName', 'Black')
                size = variant_data.get('size')
                quantity = variant_data.get('quantity', 1)
                
                # Get the first image path for this color (for variant display)
                image_paths = color_image_map.get(color_hex, [])
                variant_image_url = image_paths[0] if image_paths else None
                
                # Insert this specific variant
                variant_response = supabase.table('product_variants').insert({
                    'product_id': product_id,
                    'color': color_name,
                    'hex_code': color_hex,
                    'size': size,
                    'stock_quantity': quantity,
                    'image_url': variant_image_url
                }).execute()
                
                if variant_response.data:
                    variant_id = variant_response.data[0]['variant_id']
                    print(f"  ✅ Variant: {color_name} - {size} (qty: {quantity}) → ID: {variant_id}")
                    
                    # Store the variant_id for this color
                    if color_hex not in variant_ids_by_color:
                        variant_ids_by_color[color_hex] = []
                    variant_ids_by_color[color_hex].append(variant_id)
            
            # Insert images linked to the first variant of each color
            print(f"\n🖼️ Linking images to variants...")
            print(f"📊 Color-Image Map has {len(color_image_map)} colors")
            for color_hex, paths in color_image_map.items():
                print(f"  Color {color_hex}: {len(paths)} images")
            
            image_counter = 0
            inserted_images = []  # Track what we insert to detect duplicates
            
            for color_hex, image_paths in color_image_map.items():
                # Get the first variant_id for this color
                variant_ids = variant_ids_by_color.get(color_hex, [])
                first_variant_id = variant_ids[0] if variant_ids else None
                
                print(f"\n  Processing color {color_hex} with {len(image_paths)} images")
                print(f"  First variant ID: {first_variant_id}")
                
                for img_idx, image_path in enumerate(image_paths):
                    is_primary = (image_counter == 0)  # First image overall is primary
                    
                    # Check if this image was already inserted
                    if image_path in inserted_images:
                        print(f"  ⚠️ WARNING: Image already inserted! {image_path}")
                        continue
                    
                    supabase.table('product_images').insert({
                        'product_id': product_id,
                        'variant_id': first_variant_id,
                        'image_url': image_path,
                        'is_primary': is_primary,
                        'display_order': image_counter
                    }).execute()
                    
                    inserted_images.append(image_path)
                    print(f"  ✅ Image {image_counter}: {image_path[:80]}... (primary: {is_primary})")
                    image_counter += 1
            
            print(f"\n✅ Total images inserted: {len(inserted_images)}")
            
            # Get all images from database to confirm
            images_response = supabase.table('product_images').select('image_url').eq('product_id', product_id).order('display_order').execute()
            all_images = [img['image_url'] for img in images_response.data] if images_response.data else []
            
            product_data = {
                'product_id': product_id,
                'product_name': product_name,
                'category': db_category,
                'price': price,
                'stock': stock,
                'description': description,
                'sdg': sdg_value,
                'images': all_images,
                'total_images': len(all_images)
            }
            
            print(f"\n✅ Product added successfully!")
            print(f"   - Product ID: {product_id}")
            print(f"   - Variants: {len(product_variants)}")
            print(f"   - Images: {len(all_images)}")
            
            return jsonify({
                'success': True,
                'message': 'Product added successfully and is now visible to buyers!',
                'product': product_data
            }), 201
            
        except Exception as db_error:
            print(f"❌ Database error: {str(db_error)}")
            import traceback
            traceback.print_exc()
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
    except Exception as e:
        print(f"❌ Error adding product: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

"""
NOTE: get_product() and update_product() functions have been REMOVED from this file.
They are now handled by seller_edit_products.py which is fully migrated to Supabase.
The old MySQL versions caused conflicts and have been removed.

If you see errors about these endpoints, make sure seller_edit_products_bp is registered
in app.py BEFORE seller_product_management_bp so its routes take precedence.
"""

@seller_product_management_bp.route('/api/products/variants/<int:variant_id>', methods=['DELETE'])
@seller_required
def delete_variant(variant_id):
    """Delete a variant using Supabase"""
    print(f"\n🗑️ DELETE VARIANT REQUEST - Variant ID: {variant_id}")
    
    try:
        seller_id = session.get('seller_id')
        print(f"👤 Seller ID: {seller_id}")
        
        supabase = get_supabase_client()
        if not supabase:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Verify variant belongs to seller's product
            print(f"🔍 Verifying variant ownership...")
            variant_check = supabase.table('product_variants').select(
                'product_id, products!inner(seller_id)'
            ).eq('variant_id', variant_id).execute()
            
            if not variant_check.data:
                print(f"❌ Variant not found")
                return jsonify({'success': False, 'message': 'Variant not found'}), 404
            
            variant_data = variant_check.data[0]
            product_seller_id = variant_data['products']['seller_id']
            
            if product_seller_id != seller_id:
                print(f"❌ Unauthorized - variant belongs to seller {product_seller_id}")
                return jsonify({'success': False, 'message': 'Unauthorized'}), 403
            
            product_id = variant_data['product_id']
            print(f"✅ Variant belongs to product {product_id}")
            
            # Delete variant images from product_images table
            print(f"🖼️ Deleting variant images...")
            supabase.table('product_images').delete().eq('variant_id', variant_id).execute()
            
            # Delete variant
            print(f"🗑️ Deleting variant...")
            supabase.table('product_variants').delete().eq('variant_id', variant_id).execute()
            
            print(f"✅ Variant {variant_id} deleted successfully")
            
            return jsonify({
                'success': True,
                'message': 'Variant deleted successfully'
            }), 200
            
        except Exception as db_error:
            print(f"❌ Database error: {str(db_error)}")
            import traceback
            traceback.print_exc()
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
    except Exception as e:
        print(f"❌ Error deleting variant: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@seller_product_management_bp.route('/api/products/<int:product_id>/archive', methods=['PUT'])
@seller_required
def archive_product(product_id):
    """Archive a product (soft delete - hide from store but keep data) using Supabase"""
    try:
        seller_id = session.get('seller_id')
        print(f"🔍 Archiving/Unarchiving product {product_id} for seller {seller_id}")
        
        supabase = get_supabase_client()
        if not supabase:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Verify product belongs to seller
            product_response = supabase.table('products').select(
                'seller_id, is_active'
            ).eq('product_id', product_id).execute()
            
            if not product_response.data:
                return jsonify({'success': False, 'message': 'Product not found'}), 404
            
            product = product_response.data[0]
            
            if product['seller_id'] != seller_id:
                return jsonify({'success': False, 'message': 'Unauthorized to archive this product'}), 403
            
            # Toggle is_active status (archive/unarchive)
            new_status = False if product['is_active'] else True

            # If we're archiving (going active -> inactive), block when there are
            # ongoing orders so the seller knows why and can fulfill them first.
            # Unarchiving is always allowed since it only re-publishes the product.
            if not new_status:
                ongoing_items_response = supabase.table('order_items').select(
                    'order_id'
                ).eq('product_id', product_id).execute()

                referenced_order_ids = list({
                    item['order_id']
                    for item in (ongoing_items_response.data or [])
                    if item.get('order_id') is not None
                })

                if referenced_order_ids:
                    ongoing_orders_response = supabase.table('orders').select(
                        'order_id, order_number, order_status'
                    ).in_('order_id', referenced_order_ids).in_(
                        'order_status', ['pending', 'in_transit']
                    ).execute()

                    ongoing_orders = ongoing_orders_response.data or []
                    if ongoing_orders:
                        # Build a friendly per-status breakdown for the seller.
                        status_label = {
                            'pending': 'awaiting fulfillment',
                            'in_transit': 'in transit',
                        }
                        counts = {}
                        for o in ongoing_orders:
                            counts[o['order_status']] = counts.get(o['order_status'], 0) + 1

                        breakdown = ', '.join(
                            f"{count} {status_label.get(status, status)}"
                            for status, count in counts.items()
                        )
                        sample_orders = [
                            o['order_number'] for o in ongoing_orders[:3]
                            if o.get('order_number')
                        ]

                        message = (
                            f"This product has {len(ongoing_orders)} ongoing order"
                            f"{'s' if len(ongoing_orders) != 1 else ''} ({breakdown}). "
                            f"Please complete or cancel "
                            f"{'them' if len(ongoing_orders) != 1 else 'it'} before archiving."
                        )

                        print(
                            f"⚠️ Blocked archive of product {product_id}: "
                            f"{len(ongoing_orders)} ongoing order(s) -> {counts}"
                        )

                        return jsonify({
                            'success': False,
                            'message': message,
                            'reason': 'ongoing_orders',
                            'ongoing_count': len(ongoing_orders),
                            'ongoing_breakdown': counts,
                            'sample_order_numbers': sample_orders,
                        }), 409

            update_response = supabase.table('products').update({
                'is_active': new_status
            }).eq('product_id', product_id).execute()
            
            action = 'archived' if not new_status else 'restored'
            print(f"✅ Product {product_id} {action}")
            
            return jsonify({
                'success': True,
                'message': f'Product {action} successfully'
            }), 200
            
        except Exception as db_error:
            print(f"❌ Database error: {str(db_error)}")
            import traceback
            traceback.print_exc()
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
    except Exception as e:
        print(f"❌ Error archiving product: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@seller_product_management_bp.route('/api/products/<int:product_id>', methods=['DELETE'])
@seller_required
def delete_product(product_id):
    """Delete a product and all its associated data using Supabase"""
    try:
        seller_id = session.get('seller_id')
        print(f"🔍 Deleting product {product_id} for seller {seller_id}")
        
        supabase = get_supabase_client()
        if not supabase:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Verify product belongs to seller
            product_response = supabase.table('products').select(
                'seller_id'
            ).eq('product_id', product_id).execute()
            
            if not product_response.data:
                return jsonify({'success': False, 'message': 'Product not found'}), 404
            
            product = product_response.data[0]
            
            if product['seller_id'] != seller_id:
                return jsonify({'success': False, 'message': 'Unauthorized to delete this product'}), 403

            # Block deletion if the product is referenced by any order_items.
            # The FK constraint order_items_product_id_fkey would otherwise raise
            # a 23503 error. Sellers should archive instead so order history stays intact.
            order_items_check = supabase.table('order_items').select(
                'order_item_id', count='exact'
            ).eq('product_id', product_id).limit(1).execute()

            if order_items_check.data and len(order_items_check.data) > 0:
                print(f"⚠️ Product {product_id} has existing orders, blocking delete")
                return jsonify({
                    'success': False,
                    'message': 'This product has existing orders and cannot be deleted. Please archive it instead.'
                }), 409

            # Delete in correct order due to foreign key constraints
            # 1. Delete product images
            supabase.table('product_images').delete().eq('product_id', product_id).execute()
            
            # 2. Delete product variants
            supabase.table('product_variants').delete().eq('product_id', product_id).execute()
            
            # 3. Delete the product itself
            supabase.table('products').delete().eq('product_id', product_id).execute()
            
            print(f"✅ Product {product_id} deleted successfully")
            
            return jsonify({
                'success': True,
                'message': 'Product deleted successfully'
            }), 200
            
        except Exception as db_error:
            print(f"❌ Database error: {str(db_error)}")
            import traceback
            traceback.print_exc()
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
    except Exception as e:
        print(f"❌ Error deleting product: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@seller_product_management_bp.route('/api/orders/seller', methods=['GET'])
@seller_required
def list_seller_orders():
    """Fetch all orders for the seller from Supabase"""
    print(f"\n{'='*80}")
    print(f"📦 [SELLER ORDERS] Loading orders...")
    print(f"{'='*80}\n")
    
    try:
        seller_id = session.get('seller_id')
        print(f"🔍 Seller ID: {seller_id}")
        
        supabase = get_supabase_client()
        if not supabase:
            print("❌ Supabase client not available")
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Fetch orders with buyer info and delivery status
            print(f"📊 Fetching orders...")
            orders_response = supabase.table('orders').select(
                'order_id, order_number, created_at, subtotal, total_amount, order_status, buyer_id, buyers(first_name, last_name), deliveries(status)'
            ).eq('seller_id', seller_id).order('created_at', desc=True).execute()
            
            print(f"📦 Found {len(orders_response.data) if orders_response.data else 0} orders")
            
            orders = []
            if orders_response.data:
                # Collect all order IDs for batch fetching
                order_ids = [order['order_id'] for order in orders_response.data]
                
                # Batch fetch all order items
                print(f"📦 Batch fetching order items...")
                all_items_response = supabase.table('order_items').select(
                    'order_id, product_id, product_name, quantity, unit_price, variant_color, variant_size'
                ).in_('order_id', order_ids).execute()
                
                # Group items by order_id and collect product_ids
                items_dict = {}
                product_ids = []
                if all_items_response.data:
                    for item in all_items_response.data:
                        oid = item['order_id']
                        if oid not in items_dict:
                            items_dict[oid] = []
                        items_dict[oid].append(item)
                        if item['product_id'] not in product_ids:
                            product_ids.append(item['product_id'])
                
                print(f"📦 Found {len(all_items_response.data) if all_items_response.data else 0} total items")
                
                # Batch fetch all product images
                print(f"🖼️ Batch fetching images for {len(product_ids)} products...")
                images_dict = {}
                if product_ids:
                    images_response = supabase.table('product_images').select(
                        'product_id, image_url'
                    ).eq('is_primary', True).in_('product_id', product_ids).execute()
                    
                    if images_response.data:
                        images_dict = {img['product_id']: img['image_url'] for img in images_response.data}
                    
                    print(f"🖼️ Found {len(images_dict)} primary images")
                
                # Process each order
                for order in orders_response.data:
                    # Convert created_at string to datetime object
                    if order.get('created_at'):
                        try:
                            order['created_at'] = datetime.fromisoformat(order['created_at'].replace('Z', '+00:00'))
                        except:
                            order['created_at'] = None
                    
                    # Flatten buyer data
                    buyer_data = order.get('buyers', {})
                    order['buyer_name'] = f"{buyer_data.get('first_name', '')} {buyer_data.get('last_name', '')}"
                    
                    # Get delivery status
                    deliveries = order.get('deliveries')
                    order['delivery_status'] = deliveries[0].get('status') if deliveries and len(deliveries) > 0 else None
                    
                    # Remove nested objects
                    if 'buyers' in order:
                        del order['buyers']
                    if 'deliveries' in order:
                        del order['deliveries']
                    
                    # Get items from batch data
                    items = items_dict.get(order['order_id'], [])
                    
                    # Add images to items
                    for item in items:
                        item['image'] = images_dict.get(item['product_id'])
                    
                    order['items'] = items
                    orders.append(order)
            
            print(f"✅ Returning {len(orders)} orders")
            print(f"{'='*80}\n")
            return jsonify({'success': True, 'orders': orders}), 200
            
        except Exception as db_error:
            print(f"❌ Database error: {str(db_error)}")
            import traceback
            traceback.print_exc()
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
            
    except Exception as e:
        print(f"❌ Error fetching seller orders: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@seller_product_management_bp.route('/api/orders/<int:order_id>/preparing', methods=['POST'])
@seller_required
def mark_order_preparing(order_id):
    """Mark order as being prepared by seller using Supabase"""
    try:
        seller_id = session.get('seller_id')
        print(f"🔍 Marking order {order_id} as preparing for seller {seller_id}")
        
        supabase = get_supabase_client()
        if not supabase:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Verify this order belongs to the seller
            order_response = supabase.table('orders').select('seller_id').eq('order_id', order_id).execute()
            
            if not order_response.data:
                return jsonify({'success': False, 'message': 'Order not found'}), 404
            
            if order_response.data[0]['seller_id'] != seller_id:
                return jsonify({'success': False, 'message': 'Unauthorized'}), 403
            
            # Update delivery status to preparing
            update_response = supabase.table('deliveries').update({
                'status': 'preparing'
            }).eq('order_id', order_id).execute()
            
            print(f"✅ Order {order_id} marked as preparing")
            return jsonify({'success': True, 'message': 'Package preparation started'}), 200
            
        except Exception as db_error:
            print(f"❌ Database error: {str(db_error)}")
            import traceback
            traceback.print_exc()
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
            
    except Exception as e:
        print(f"❌ Error marking order as preparing: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@seller_product_management_bp.route('/api/orders/<int:order_id>/ready-for-pickup', methods=['POST'])
@seller_required
def mark_order_ready_for_pickup(order_id):
    """Mark order as ready for pickup by rider using Supabase"""
    try:
        seller_id = session.get('seller_id')
        print(f"🔍 Marking order {order_id} as ready for pickup for seller {seller_id}")
        
        supabase = get_supabase_client()
        if not supabase:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Verify this order belongs to the seller and get order details
            order_response = supabase.table('orders').select('''
                seller_id,
                buyer_id,
                order_number,
                order_items (
                    product_name,
                    quantity
                )
            ''').eq('order_id', order_id).execute()
            
            if not order_response.data:
                return jsonify({'success': False, 'message': 'Order not found'}), 404
            
            order = order_response.data[0]
            
            if order['seller_id'] != seller_id:
                return jsonify({'success': False, 'message': 'Unauthorized'}), 403
            
            # Update delivery status to pending (ready for rider to accept)
            update_response = supabase.table('deliveries').update({
                'status': 'pending'
            }).eq('order_id', order_id).execute()
            
            # Create consolidated notification message for multiple products
            order_items = order.get('order_items', [])
            if len(order_items) > 1:
                # Multiple products - consolidate into one message
                product_list = []
                for item in order_items:
                    product_list.append(f"{item['product_name']} (x{item['quantity']})")
                products_text = ", ".join(product_list)
                notification_message = f"Order #{order['order_number']} is ready for pickup. Items: {products_text}"
            elif len(order_items) == 1:
                # Single product
                item = order_items[0]
                notification_message = f"Order #{order['order_number']} is ready for pickup. Item: {item['product_name']} (x{item['quantity']})"
            else:
                # Fallback
                notification_message = f"Order #{order['order_number']} is ready for pickup."
            
            # Get buyer and seller user_ids for notifications
            buyer_response = supabase.table('buyers').select('user_id').eq('buyer_id', order['buyer_id']).execute()
            seller_response = supabase.table('sellers').select('user_id').eq('seller_id', seller_id).execute()
            
            buyer_user_id = buyer_response.data[0]['user_id'] if buyer_response.data else None
            seller_user_id = seller_response.data[0]['user_id'] if seller_response.data else None
            
            # Get current Philippine time
            from datetime import datetime, timedelta
            ph_time = (datetime.utcnow() + timedelta(hours=8)).strftime('%Y-%m-%d %H:%M:%S')
            formatted_date = datetime.now().strftime('%B %d, %Y at %I:%M %p')
            
            # Send notification to BOTH buyer and seller
            notifications_to_create = []
            
            if buyer_user_id:
                notifications_to_create.append({
                    'user_id': buyer_user_id,
                    'title': '📦 Order Ready for Pickup',
                    'message': notification_message,
                    'notification_type': 'delivery',
                    'is_read': False,
                    'order_id': order_id,
                    'formatted_date': formatted_date,
                    'created_at': ph_time
                })
            
            if seller_user_id:
                notifications_to_create.append({
                    'user_id': seller_user_id,
                    'title': '📦 Order Ready for Pickup',
                    'message': f"You marked {notification_message}",
                    'notification_type': 'delivery',
                    'is_read': False,
                    'order_id': order_id,
                    'formatted_date': formatted_date,
                    'created_at': ph_time
                })
            
            # Insert notifications
            if notifications_to_create:
                supabase.table('notifications').insert(notifications_to_create).execute()
                print(f"✅ Sent notifications to buyer and seller")
            
            print(f"✅ Order {order_id} marked as ready for pickup")
            return jsonify({'success': True, 'message': 'Order marked as ready for pickup'}), 200
            
        except Exception as db_error:
            print(f"❌ Database error: {str(db_error)}")
            import traceback
            traceback.print_exc()
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
            
    except Exception as e:
        print(f"❌ Error marking order as ready for pickup: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@seller_product_management_bp.route('/api/products/sold', methods=['GET'])
@seller_required
def list_sold_products():
    """Get list of sold products for the seller"""
    try:
        print("📦 Fetching sold products...")
        supabase = get_supabase_client()
        
        # Get seller_id from session
        seller_response = supabase.table('sellers').select('seller_id').eq('user_id', session['user_id']).execute()
        
        if not seller_response.data:
            return jsonify({'success': False, 'message': 'Seller not found'}), 404
        
        seller_id = seller_response.data[0]['seller_id']
        
        # Get sold products (orders that are delivered and confirmed by buyer)
        orders_response = supabase.table('orders').select('order_id, order_number, subtotal, commission_amount, updated_at, buyer_id').eq('seller_id', seller_id).eq('order_status', 'delivered').eq('order_received', True).order('updated_at', desc=True).execute()
        
        sold_orders = []
        
        for order in orders_response.data:
            # Get buyer info
            buyer_response = supabase.table('buyers').select('first_name, last_name, phone_number').eq('buyer_id', order['buyer_id']).execute()
            
            if buyer_response.data:
                buyer = buyer_response.data[0]
                buyer_name = f"{buyer['first_name']} {buyer['last_name']}"
                buyer_phone = buyer['phone_number']
            else:
                buyer_name = 'Unknown'
                buyer_phone = 'N/A'
            
            # Get order items
            items_response = supabase.table('order_items').select('product_name, variant_color, variant_size, quantity, unit_price, subtotal').eq('order_id', order['order_id']).execute()
            
            sold_orders.append({
                'order_id': order['order_id'],
                'order_number': order['order_number'],
                'order_total': order['subtotal'],
                'commission_amount': order['commission_amount'],
                'order_received_date': order['updated_at'],
                'buyer_name': buyer_name,
                'buyer_phone': buyer_phone,
                'items': items_response.data
            })
        
        print(f"✅ Fetched {len(sold_orders)} sold orders")
        
        return jsonify({'success': True, 'sold_orders': sold_orders}), 200
        
    except Exception as e:
        print(f"❌ Error fetching sold products: {str(e)}")
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

