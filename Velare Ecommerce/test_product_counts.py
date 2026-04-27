import mysql.connector
from mysql.connector import Error

def get_db_connection():
    try:
        connection = mysql.connector.connect(
            host='localhost',
            database='velare_ecommerce',
            user='root',
            password=''
        )
        return connection
    except Error as e:
        print(f"Error connecting to database: {e}")
        return None

def test_product_counts():
    connection = get_db_connection()
    if not connection:
        print("Failed to connect to database!")
        return
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print("=" * 80)
        print("TESTING PRODUCT COUNTS FOR INDEX PAGE SECTIONS")
        print("=" * 80)
        
        # Test 1: Best Sellers (Exclusively In Demand)
        print("\n1. EXCLUSIVELY IN DEMAND (Best Sellers - total_sold > 0)")
        print("-" * 80)
        cursor.execute("""
            SELECT p.product_id, p.product_name, p.total_sold, pi.image_url
            FROM products p
            LEFT JOIN product_images pi ON p.product_id = pi.product_id AND pi.is_primary = 1
            WHERE p.is_active = 1 AND p.total_sold > 0
            ORDER BY p.total_sold DESC
        """)
        best_sellers = cursor.fetchall()
        print(f"Total Count: {len(best_sellers)} products")
        if best_sellers:
            print("\nTop 5:")
            for i, product in enumerate(best_sellers[:5], 1):
                has_image = "✓" if product['image_url'] else "✗"
                print(f"  {i}. [{has_image}] {product['product_name']} (Sold: {product['total_sold']})")
        else:
            print("  ⚠️  No products with sales found!")
        
        # Test 2: Latest Products (What's New)
        print("\n2. WHAT'S NEW (Latest Products)")
        print("-" * 80)
        cursor.execute("""
            SELECT p.product_id, p.product_name, p.created_at, pi.image_url
            FROM products p
            LEFT JOIN product_images pi ON p.product_id = pi.product_id AND pi.is_primary = 1
            WHERE p.is_active = 1
            ORDER BY p.created_at DESC
        """)
        latest_products = cursor.fetchall()
        print(f"Total Count: {len(latest_products)} products")
        if latest_products:
            print("\nTop 5:")
            for i, product in enumerate(latest_products[:5], 1):
                has_image = "✓" if product['image_url'] else "✗"
                print(f"  {i}. [{has_image}] {product['product_name']} (Created: {product['created_at']})")
        else:
            print("  ⚠️  No active products found!")
        
        # Test 3: Top Rated (Beloved by Connoisseurs)
        print("\n3. BELOVED BY CONNOISSEURS (Top Rated - has reviews)")
        print("-" * 80)
        cursor.execute("""
            SELECT p.product_id, p.product_name, p.rating, p.total_reviews, pi.image_url
            FROM products p
            LEFT JOIN product_images pi ON p.product_id = pi.product_id AND pi.is_primary = 1
            WHERE p.is_active = 1 AND p.total_reviews > 0
            ORDER BY p.rating DESC, p.total_reviews DESC
        """)
        top_rated_products = cursor.fetchall()
        print(f"Total Count: {len(top_rated_products)} products")
        if top_rated_products:
            print("\nTop 5:")
            for i, product in enumerate(top_rated_products[:5], 1):
                has_image = "✓" if product['image_url'] else "✗"
                print(f"  {i}. [{has_image}] {product['product_name']} (Rating: {product['rating']:.1f}, Reviews: {product['total_reviews']})")
        else:
            print("  ⚠️  No products with reviews found!")
        
        # Test 4: Random Products (The Art of Choice)
        print("\n4. THE ART OF CHOICE (All Active Products)")
        print("-" * 80)
        cursor.execute("""
            SELECT p.product_id, p.product_name, pi.image_url
            FROM products p
            LEFT JOIN product_images pi ON p.product_id = pi.product_id AND pi.is_primary = 1
            WHERE p.is_active = 1
        """)
        random_products = cursor.fetchall()
        print(f"Total Count: {len(random_products)} products")
        if random_products:
            print("\nFirst 5:")
            for i, product in enumerate(random_products[:5], 1):
                has_image = "✓" if product['image_url'] else "✗"
                print(f"  {i}. [{has_image}] {product['product_name']}")
        else:
            print("  ⚠️  No active products found!")
        
        # Summary
        print("\n" + "=" * 80)
        print("SUMMARY")
        print("=" * 80)
        print(f"Exclusively In Demand (Best Sellers):  {len(best_sellers)} products")
        print(f"What's New (Latest):                   {len(latest_products)} products")
        print(f"Beloved by Connoisseurs (Top Rated):   {len(top_rated_products)} products")
        print(f"The Art of Choice (Random):            {len(random_products)} products")
        print("=" * 80)
        
        # Check for products without images
        print("\n⚠️  PRODUCTS WITHOUT PRIMARY IMAGES:")
        print("-" * 80)
        cursor.execute("""
            SELECT p.product_id, p.product_name
            FROM products p
            LEFT JOIN product_images pi ON p.product_id = pi.product_id AND pi.is_primary = 1
            WHERE p.is_active = 1 AND pi.image_url IS NULL
        """)
        no_image_products = cursor.fetchall()
        if no_image_products:
            print(f"Found {len(no_image_products)} products without primary images:")
            for product in no_image_products[:10]:
                print(f"  - ID {product['product_id']}: {product['product_name']}")
            if len(no_image_products) > 10:
                print(f"  ... and {len(no_image_products) - 10} more")
        else:
            print("✓ All active products have primary images!")
        
        cursor.close()
        
    except Error as e:
        print(f"Error: {e}")
    finally:
        connection.close()

if __name__ == "__main__":
    test_product_counts()
