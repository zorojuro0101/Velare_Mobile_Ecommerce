import sys
import os
import random

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from database.db_config import get_db_connection, close_db_connection

def test_hero_products():
    connection = get_db_connection()
    
    if not connection:
        print("❌ Failed to connect to database")
        return
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print("=" * 80)
        print("TESTING HERO PRODUCTS FOR ALL CATEGORIES")
        print("=" * 80)
        print()
        
        categories = {
            'tops-blouses': ['tops-blouses', 'tops', 'blouses'],
            'dresses-skirts': ['dresses-skirts', 'Dresses', 'Skirts'],
            'activewear-yoga': ['activewear-yoga', 'Active Wear', 'Yoga Pants'],
            'lingerie-sleepwear': ['lingerie-sleepwear', 'Lingerie', 'Sleepwear'],
            'jackets-coats': ['jackets-coats', 'Jackets', 'Coats'],
            'shoes-accessories': ['shoes-accessories', 'Shoes', 'Accessories']
        }
        
        for category_key, category_values in categories.items():
            print(f"📂 CATEGORY: {category_key.upper()}")
            print("-" * 80)
            
            # Build category filter
            category_conditions = []
            category_params = []
            for cat in category_values:
                category_conditions.append("p.category = %s")
                category_params.append(cat)
            
            category_filter = " AND (" + " OR ".join(category_conditions) + ")"
            
            # Test Best Seller
            print("  🏆 BEST SELLER:")
            best_seller_query = f"""
                SELECT 
                    p.product_id,
                    p.product_name,
                    p.category,
                    (SELECT image_url FROM product_images 
                     WHERE product_id = p.product_id 
                     ORDER BY is_primary DESC, display_order ASC 
                     LIMIT 1) as primary_image,
                    COALESCE(SUM(oi.quantity), 0) as total_sold
                FROM products p
                JOIN sellers s ON p.seller_id = s.seller_id
                LEFT JOIN order_items oi ON p.product_id = oi.product_id
                LEFT JOIN orders o ON oi.order_id = o.order_id AND o.order_status != 'cancelled'
                WHERE p.is_active = TRUE {category_filter}
                GROUP BY p.product_id, p.product_name, p.category, primary_image
                ORDER BY total_sold DESC, p.rating DESC
                LIMIT 1
            """
            cursor.execute(best_seller_query, category_params)
            best_seller = cursor.fetchone()
            
            if best_seller:
                img_status = "✅ Has Image" if best_seller['primary_image'] else "❌ No Image"
                print(f"     ✅ Found: {best_seller['product_name']}")
                print(f"        Category: {best_seller['category']}")
                print(f"        Image: {img_status}")
                if best_seller['primary_image']:
                    print(f"        Path: {best_seller['primary_image']}")
            else:
                print(f"     ❌ No best seller found")
            
            # Test Top Rated
            print("  ⭐ TOP RATED:")
            top_rated_query = f"""
                SELECT 
                    p.product_id,
                    p.product_name,
                    p.category,
                    p.rating,
                    (SELECT image_url FROM product_images 
                     WHERE product_id = p.product_id 
                     ORDER BY is_primary DESC, display_order ASC 
                     LIMIT 1) as primary_image
                FROM products p
                JOIN sellers s ON p.seller_id = s.seller_id
                WHERE p.is_active = TRUE AND p.rating > 0 {category_filter}
                ORDER BY p.rating DESC, p.total_reviews DESC
                LIMIT 1
            """
            cursor.execute(top_rated_query, category_params)
            top_rated = cursor.fetchone()
            
            if top_rated:
                img_status = "✅ Has Image" if top_rated['primary_image'] else "❌ No Image"
                print(f"     ✅ Found: {top_rated['product_name']}")
                print(f"        Category: {top_rated['category']}")
                print(f"        Rating: {top_rated['rating']}")
                print(f"        Image: {img_status}")
                if top_rated['primary_image']:
                    print(f"        Path: {top_rated['primary_image']}")
            else:
                print(f"     ❌ No top rated found")
            
            # Test New Arrival
            print("  🆕 NEW ARRIVAL:")
            new_arrival_query = f"""
                SELECT 
                    p.product_id,
                    p.product_name,
                    p.category,
                    p.created_at,
                    (SELECT image_url FROM product_images 
                     WHERE product_id = p.product_id 
                     ORDER BY is_primary DESC, display_order ASC 
                     LIMIT 1) as primary_image
                FROM products p
                JOIN sellers s ON p.seller_id = s.seller_id
                WHERE p.is_active = TRUE {category_filter}
                ORDER BY p.created_at DESC
                LIMIT 1
            """
            cursor.execute(new_arrival_query, category_params)
            new_arrival = cursor.fetchone()
            
            if new_arrival:
                img_status = "✅ Has Image" if new_arrival['primary_image'] else "❌ No Image"
                print(f"     ✅ Found: {new_arrival['product_name']}")
                print(f"        Category: {new_arrival['category']}")
                print(f"        Image: {img_status}")
                if new_arrival['primary_image']:
                    print(f"        Path: {new_arrival['primary_image']}")
            else:
                print(f"     ❌ No new arrival found")
            
            print()
        
        print("=" * 80)
        print("✅ TEST COMPLETE")
        print("=" * 80)
        
        cursor.close()
        
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
    finally:
        close_db_connection(connection)

if __name__ == "__main__":
    test_hero_products()
