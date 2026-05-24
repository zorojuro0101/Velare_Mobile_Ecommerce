from flask import Blueprint, render_template, request, jsonify, session
from werkzeug.utils import secure_filename
import os
import sys
from datetime import datetime

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_config import get_db_connection, close_db_connection, get_supabase_client
from utils.auth_decorators import seller_required

seller_edit_products_bp = Blueprint('seller_edit_products', __name__)

# Configure upload folder
UPLOAD_FOLDER = 'static/uploads/products'
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'avif'}

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def upload_to_supabase_storage(file, unique_filename):
    """
    Upload file to Supabase Storage and return the public URL.
    
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
        
        print(f"    ✅ Uploaded to Supabase: {public_url}")
        return public_url
        
    except Exception as e:
        print(f"    ❌ Error uploading to Supabase: {str(e)}")
        raise

@seller_edit_products_bp.route('/seller/edit-products')
def seller_edit_products():
    return render_template('seller/seller_edit_products.html')

@seller_edit_products_bp.route('/api/products/<int:product_id>', methods=['GET'])
@seller_required
def get_product(product_id):
    """Get product details from Supabase"""
    print("=" * 50)
    print(f"🔍 GET PRODUCT API CALLED - Product ID: {product_id}")
    print("=" * 50)
    
    try:
        seller_id = session.get('seller_id', 1)
        print(f"👤 Seller ID: {seller_id}")
        
        supabase = get_supabase_client()
        if not supabase:
            print("❌ Supabase client not available")
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Fetch product details from Supabase
            print(f"📊 Fetching product from Supabase...")
            product_response = supabase.table('products').select(
                'product_id, product_name, description, materials, sdg, price, category, is_active'
            ).eq('product_id', product_id).eq('seller_id', seller_id).execute()
            
            if not product_response.data:
                print(f"❌ Product not found")
                return jsonify({'success': False, 'message': 'Product not found'}), 404
            
            product_dict = product_response.data[0]
            print(f"✅ Product found: {product_dict.get('product_name')}")
            print(f"📦 Original category from DB: {product_dict.get('category')}")
            
            # Convert database category to form value (normalize to lowercase with hyphens)
            db_category = product_dict.get('category', '')
            
            # Mapping from database format to form values
            category_mapping = {
                'Active Wear': 'activewear',
                'Yoga Pants': 'yoga-pants',
                'Active Wear-Yoga Pants': 'activewear',  # Map combined to activewear
                'activewear': 'activewear',
                'yoga-pants': 'yoga-pants',
                'Dresses': 'dresses',
                'dresses': 'dresses',
                'Skirts': 'skirts',
                'skirts': 'skirts',
                'Tops': 'tops',
                'tops': 'tops',
                'Blouses': 'blouses',
                'blouses': 'blouses',
                'Lingerie': 'lingerie',
                'lingerie': 'lingerie',
                'Sleepwear': 'sleepwear',
                'sleepwear': 'sleepwear',
                'Jackets': 'jackets',
                'jackets': 'jackets',
                'Coats': 'coats',
                'coats': 'coats',
                'Shoes': 'shoes',
                'shoes': 'shoes',
                'Accessories': 'accessories',
                'accessories': 'accessories'
            }
            
            # Convert category to form value
            form_category = category_mapping.get(db_category, db_category.lower())
            product_dict['category'] = form_category
            print(f"✅ Converted category for form: {form_category}")
            
            # Fetch product-level images (images without variant_id)
            print(f"🖼️ Fetching product images...")
            images_response = supabase.table('product_images').select(
                'image_url, is_primary, display_order'
            ).eq('product_id', product_id).is_('variant_id', 'null').order('display_order').execute()
            
            product_dict['images'] = [img['image_url'] for img in images_response.data] if images_response.data else []
            print(f"📦 Found {len(product_dict['images'])} product-level images")
            
            # Fetch product variants with color info
            print(f"🎨 Fetching variants...")
            variants_response = supabase.table('product_variants').select(
                'variant_id, color, hex_code, size, stock_quantity, image_url'
            ).eq('product_id', product_id).order('color').order('size').execute()
            
            print(f"📦 Found {len(variants_response.data) if variants_response.data else 0} variants")
            
            # Fetch images for each variant
            variants_list = []
            if variants_response.data:
                for variant in variants_response.data:
                    # Fetch images for this variant
                    variant_images_response = supabase.table('product_images').select(
                        'image_url, is_primary, display_order'
                    ).eq('variant_id', variant['variant_id']).order('display_order').execute()
                    
                    variant['images'] = [
                        {'url': img['image_url'], 'is_primary': img['is_primary']} 
                        for img in variant_images_response.data
                    ] if variant_images_response.data else []
                    
                    print(f"   Variant {variant['variant_id']} ({variant['color']} {variant['size']}): {len(variant['images'])} images")
                    
                    variants_list.append(variant)
            
            product_dict['variants'] = variants_list
            
            print(f"✅ Returning product with {len(variants_list)} variants")
            
            return jsonify({
                'success': True,
                'product': product_dict,
                'test_message': 'MIGRATED TO SUPABASE - seller_edit_products.py'
            }), 200
            
        except Exception as db_error:
            print(f"❌ Database error: {str(db_error)}")
            import traceback
            traceback.print_exc()
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
    except Exception as e:
        print(f"❌ Error fetching product: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@seller_edit_products_bp.route('/api/products/<int:product_id>', methods=['PUT', 'POST'])
@seller_required
def update_product(product_id):
    """Update product using Supabase - NOTE: This file handles Edit Product functionality"""
    print("\n" + "="*60)
    print(f"📝 UPDATE PRODUCT REQUEST - Product ID: {product_id}")
    print("="*60)
    
    try:
        import json
        
        seller_id = session.get('seller_id', 1)
        print(f"👤 Seller ID: {seller_id}")
        
        # Get form data (with both naming conventions for compatibility)
        product_name = request.form.get('productName') or request.form.get('editProductName')
        category = request.form.get('productCategory') or request.form.get('editProductCategory')
        
        print(f"📦 Category from form: {category}")
        
        # Convert form category to database format
        # Form uses lowercase with hyphens, database uses Title Case
        category_to_db = {
            'activewear': 'Active Wear',
            'yoga-pants': 'Yoga Pants',
            'activewear-yoga': 'Active Wear-Yoga Pants',  # Combined category
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
        
        # Convert to database format (or keep as-is if already in correct format)
        db_category = category_to_db.get(category, category)
        print(f"✅ Converted category for DB: {db_category}")
        
        price = request.form.get('productPrice') or request.form.get('editProductPrice')
        description = request.form.get('productDescription') or request.form.get('editProductDescription', '')
        materials = request.form.get('productMaterials') or request.form.get('editProductMaterials', '')
        
        # Get SDG checkboxes (check both naming conventions)
        is_handmade = 'productHandmade' in request.form or 'editProductHandmade' in request.form
        is_biodegradable = 'productBiodegradable' in request.form or 'editProductBiodegradable' in request.form
        
        # Get variants data
        variants_data = request.form.get('variantsData')
        
        print(f"📋 Form data: name={product_name}, category={db_category}, price={price}")
        
        # Validate required fields
        if not all([product_name, db_category, price]):
            return jsonify({'success': False, 'message': 'All required fields must be filled'}), 400
        
        # Validate price
        try:
            price = float(price)
            if price <= 0:
                raise ValueError()
        except ValueError:
            return jsonify({'success': False, 'message': 'Invalid price'}), 400
        
        supabase = get_supabase_client()
        if not supabase:
            return jsonify({'success': False, 'message': 'Database connection failed'}), 500
        
        try:
            # Verify product belongs to seller
            print(f"🔍 Verifying product ownership...")
            product_check = supabase.table('products').select('seller_id').eq('product_id', product_id).execute()
            
            if not product_check.data or product_check.data[0]['seller_id'] != seller_id:
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
            
            # Update product basic info
            print(f"📝 Updating product info...")
            supabase.table('products').update({
                'product_name': product_name,
                'description': description,
                'materials': materials if materials else None,
                'sdg': sdg_value,
                'price': price,
                'category': db_category,
                'updated_at': datetime.now().isoformat()
            }).eq('product_id', product_id).eq('seller_id', seller_id).execute()
            
            # Update existing variants quantities
            if variants_data:
                variants = json.loads(variants_data)
                print(f"🔄 Updating {len(variants)} existing variants...")
                for variant in variants:
                    variant_id = variant.get('variant_id')
                    quantity = int(variant.get('quantity', 0))
                    if variant_id:
                        supabase.table('product_variants').update({
                            'stock_quantity': quantity
                        }).eq('variant_id', variant_id).eq('product_id', product_id).execute()
            
            # Handle deleted images
            deleted_images_data = request.form.get('deletedImages')
            if deleted_images_data:
                try:
                    deleted_images = json.loads(deleted_images_data)
                    print(f"🗑️ Deleting {len(deleted_images)} images...")
                    
                    for img_info in deleted_images:
                        variant_id = img_info.get('variantId')
                        image_url = img_info.get('imageUrl')
                        
                        if image_url:
                            # Handle both Supabase URLs and local paths
                            if image_url.startswith('http://') or image_url.startswith('https://'):
                                clean_url = image_url
                            else:
                                clean_url = image_url.lstrip('/')
                            
                            print(f"  🗑️ Deleting image: {clean_url[:80]}...")
                            
                            # Delete from product_images table
                            if variant_id:
                                supabase.table('product_images').delete().eq('variant_id', variant_id).eq('image_url', clean_url).execute()
                            else:
                                # Product-level image (no variant_id)
                                supabase.table('product_images').delete().eq('product_id', product_id).is_('variant_id', 'null').eq('image_url', clean_url).execute()
                            
                            print(f"  ✅ Image deleted")
                    
                    print(f"✅ All marked images deleted")
                    
                except Exception as delete_error:
                    print(f"⚠️ Error deleting images: {str(delete_error)}")
            
            # Handle new variants
            new_variants_data = request.form.get('newVariantsData')
            if new_variants_data:
                new_variants = json.loads(new_variants_data)
                new_variant_images = request.files.getlist('newVariantImages')
                print(f"➕ Adding {len(new_variants)} new variants with {len(new_variant_images)} total images...")
                
                # Track image index across all variants
                image_index = 0
                
                for variant_index, variant in enumerate(new_variants):
                    hex_color = variant.get('hex')
                    color_name = variant.get('colorName')
                    size = variant.get('size')
                    quantity = int(variant.get('quantity', 0))
                    num_images = int(variant.get('numImages', 0))
                    
                    print(f"  Variant {variant_index + 1}: {color_name} {size} - {num_images} images")
                    
                    # Insert new variant first to get variant_id
                    variant_response = supabase.table('product_variants').insert({
                        'product_id': product_id,
                        'color': color_name,
                        'hex_code': hex_color,
                        'size': size,
                        'stock_quantity': quantity,
                        'image_url': None  # Will be set to first image URL
                    }).execute()
                    
                    if not variant_response.data:
                        print(f"  ❌ Failed to create variant")
                        continue
                    
                    new_variant_id = variant_response.data[0]['variant_id']
                    print(f"  ✅ Created variant {new_variant_id}")
                    
                    # Upload all images for this variant
                    first_image_url = None
                    for img_idx in range(num_images):
                        if image_index < len(new_variant_images):
                            image_file = new_variant_images[image_index]
                            if image_file and image_file.filename:
                                # Generate unique filename
                                timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                                filename = secure_filename(image_file.filename)
                                unique_filename = f"static/uploads/products/{timestamp}_{new_variant_id}_{img_idx}_{filename}"
                                
                                # Upload to Supabase Storage
                                image_url = upload_to_supabase_storage(image_file, unique_filename)
                                
                                # Insert into product_images
                                is_primary = (img_idx == 0)
                                supabase.table('product_images').insert({
                                    'product_id': product_id,
                                    'variant_id': new_variant_id,
                                    'image_url': image_url,
                                    'is_primary': is_primary,
                                    'display_order': img_idx
                                }).execute()
                                
                                print(f"    ✅ Uploaded image {img_idx + 1}/{num_images}: {unique_filename}")
                                
                                # Store first image URL
                                if img_idx == 0:
                                    first_image_url = image_url
                            
                            image_index += 1
                    
                    # Update variant's image_url to first image
                    if first_image_url:
                        supabase.table('product_variants').update({
                            'image_url': first_image_url
                        }).eq('variant_id', new_variant_id).execute()
                        print(f"  ✅ Set variant image_url to first image")
            
            # Handle new product-level image uploads if provided
            uploaded_files = request.files.getlist('productImages')
            if uploaded_files and uploaded_files[0].filename != '':
                print(f"🖼️ Uploading {len(uploaded_files)} new product images...")
                
                # Delete old product-level images from database
                supabase.table('product_images').delete().eq('product_id', product_id).is_('variant_id', 'null').execute()
                
                # Save new images to Supabase Storage
                for index, file in enumerate(uploaded_files):
                    if file and allowed_file(file.filename):
                        # Generate unique filename
                        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                        filename = secure_filename(file.filename)
                        unique_filename = f"static/uploads/products/{timestamp}_{filename}"
                        
                        # Upload to Supabase Storage
                        image_url = upload_to_supabase_storage(file, unique_filename)
                        
                        # Insert new product image with Supabase URL
                        is_primary = (index == 0)  # First image is primary
                        supabase.table('product_images').insert({
                            'product_id': product_id,
                            'variant_id': None,
                            'image_url': image_url,
                            'is_primary': is_primary,
                            'display_order': index
                        }).execute()
            
            # Handle variant image uploads and updates
            print(f"\n🖼️ PROCESSING VARIANT IMAGES")
            print(f"📋 All form keys: {list(request.form.keys())}")
            
            # Collect all variant IDs that have image data (either new images or reordering)
            variant_ids_with_images = set()
            for key in request.form.keys():
                if key.startswith('variant_') and ('_has_new_images' in key or '_image_order' in key):
                    # Extract variant_id from keys like "variant_45_has_new_images" or "variant_45_image_order"
                    variant_id = key.replace('variant_', '').replace('_has_new_images', '').replace('_image_order', '')
                    variant_ids_with_images.add(variant_id)
            
            print(f"📦 Found {len(variant_ids_with_images)} variants with image data: {variant_ids_with_images}")
            
            # Process each variant
            for variant_id in variant_ids_with_images:
                print(f"\n  Processing variant {variant_id}...")
                
                # Check if there are new images to upload
                has_new_images_key = f'variant_{variant_id}_has_new_images'
                if has_new_images_key in request.form:
                    # Extract variant_id from key like "variant_45_has_new_images"
                    print(f"  📤 Uploading new images for variant {variant_id}")
                    
                    # Get uploaded files for this variant
                    file_key = f'variant_{variant_id}_images'
                    uploaded_files = request.files.getlist(file_key)
                    
                    if uploaded_files and len(uploaded_files) > 0:
                        # Get current max display_order for this variant
                        max_order_response = supabase.table('product_images').select('display_order').eq('variant_id', variant_id).order('display_order', desc=True).limit(1).execute()
                        current_max_order = max_order_response.data[0]['display_order'] if max_order_response.data else -1
                        
                        # Upload and insert new images to Supabase Storage
                        for idx, file in enumerate(uploaded_files):
                            if file and file.filename and allowed_file(file.filename):
                                timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                                filename = secure_filename(file.filename)
                                unique_filename = f"static/uploads/products/{timestamp}_{variant_id}_{idx}_{filename}"
                                
                                # Upload to Supabase Storage
                                image_url = upload_to_supabase_storage(file, unique_filename)
                                
                                # Insert into product_images with Supabase URL
                                display_order = current_max_order + 1 + idx
                                is_primary = (display_order == 0)  # First image is primary
                                
                                supabase.table('product_images').insert({
                                    'product_id': product_id,
                                    'variant_id': int(variant_id),
                                    'image_url': image_url,
                                    'is_primary': is_primary,
                                    'display_order': display_order
                                }).execute()
                                
                                print(f"    ✅ Uploaded: {unique_filename} (order: {display_order})")
                                
                                # Update variant's image_url to first image if not set
                                if is_primary or current_max_order == -1:
                                    supabase.table('product_variants').update({
                                        'image_url': image_url
                                    }).eq('variant_id', int(variant_id)).execute()
                
                # Handle image reordering (whether or not there are new images)
                order_key = f'variant_{variant_id}_image_order'
                print(f"  🔍 Checking for reordering key: {order_key}")
                print(f"  🔍 Key exists in form: {order_key in request.form}")
                
                if order_key in request.form:
                    try:
                        image_order_raw = request.form.get(order_key)
                        print(f"  📦 Raw image order data: {image_order_raw}")
                        image_order = json.loads(image_order_raw)
                        print(f"  🔄 Reordering {len(image_order)} images for variant {variant_id}")
                        
                        # Track the primary image URL
                        primary_image_url = None
                        
                        # Update display_order and is_primary for existing images
                        for idx, img_info in enumerate(image_order):
                            if not img_info.get('isNew') and img_info.get('url'):
                                # Handle both Supabase URLs and local paths
                                raw_url = img_info['url']
                                
                                # If it's a full Supabase URL, use as-is
                                if raw_url.startswith('http://') or raw_url.startswith('https://'):
                                    clean_url = raw_url
                                else:
                                    # Local path - remove leading slash
                                    clean_url = raw_url.lstrip('/')
                                
                                is_primary = (idx == 0)
                                
                                print(f"    Updating image {idx}: {clean_url[:50]}... (primary: {is_primary})")
                                
                                # Update image in product_images table
                                supabase.table('product_images').update({
                                    'display_order': idx,
                                    'is_primary': is_primary
                                }).eq('variant_id', int(variant_id)).eq('image_url', clean_url).execute()
                                
                                # Store the primary image URL
                                if is_primary:
                                    primary_image_url = clean_url
                                    print(f"    ✅ New primary image: {clean_url[:80]}...")
                        
                        # Update variant's image_url to the new primary image
                        if primary_image_url:
                            supabase.table('product_variants').update({
                                'image_url': primary_image_url
                            }).eq('variant_id', int(variant_id)).execute()
                            print(f"    ✅ Updated variant {variant_id} image_url to primary")
                            
                    except Exception as order_error:
                        print(f"    ⚠️ Error reordering images: {str(order_error)}")
                        import traceback
                        traceback.print_exc()
            
            print(f"✅ Product {product_id} updated successfully")
            
            return jsonify({
                'success': True,
                'message': 'Product updated successfully!'
            }), 200
            
        except Exception as db_error:
            print(f"❌ Database error: {str(db_error)}")
            import traceback
            traceback.print_exc()
            return jsonify({'success': False, 'message': f'Database error: {str(db_error)}'}), 500
        
    except Exception as e:
        print(f"❌ Error updating product: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500
