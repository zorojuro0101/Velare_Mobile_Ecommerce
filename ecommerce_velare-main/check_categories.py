import sys
import os

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from database.db_config import get_db_connection, close_db_connection

def check_product_categories():
    connection = get_db_connection()
    
    if not connection:
        print("❌ Failed to connect to database")
        return
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print("=" * 80)
        print("CHECKING PRODUCT CATEGORIES IN DATABASE")
        print("=" * 80)
        print()
        
        # Check all distinct categories
        print("📊 ALL CATEGORIES WITH PRODUCT COUNT:")
        print("-" * 80)
        cursor.execute("""
            SELECT category, COUNT(*) as count 
            FROM products 
            GROUP BY category
            ORDER BY count DESC
        """)
        categories = cursor.fetchall()
        
        if categories:
            for cat in categories:
                print(f"  • {cat['category']:<30} : {cat['count']} products")
        else:
            print("  ⚠️  No products found in database")
        
        print()
        print("=" * 80)
        
        # Check specifically for activewear and yoga
        print("🔍 SEARCHING FOR ACTIVEWEAR & YOGA PANTS:")
        print("-" * 80)
        cursor.execute("""
            SELECT product_id, product_name, category, is_active
            FROM products 
            WHERE category LIKE '%active%' OR category LIKE '%yoga%'
        """)
        active_yoga = cursor.fetchall()
        
        if active_yoga:
            print(f"  ✅ Found {len(active_yoga)} products:")
            for prod in active_yoga:
                status = "✓ Active" if prod['is_active'] else "✗ Inactive"
                print(f"     [{prod['product_id']}] {prod['product_name']:<40} | {prod['category']:<20} | {status}")
        else:
            print("  ⚠️  No activewear or yoga pants products found")
        
        print()
        print("=" * 80)
        
        # Check all products
        print("📦 TOTAL PRODUCTS:")
        print("-" * 80)
        cursor.execute("SELECT COUNT(*) as total FROM products")
        total = cursor.fetchone()
        cursor.execute("SELECT COUNT(*) as active FROM products WHERE is_active = TRUE")
        active = cursor.fetchone()
        
        print(f"  Total Products: {total['total']}")
        print(f"  Active Products: {active['active']}")
        print(f"  Inactive Products: {total['total'] - active['active']}")
        
        print()
        print("=" * 80)
        
        # Check category mapping expectations
        print("🗺️  EXPECTED CATEGORY MAPPINGS:")
        print("-" * 80)
        expected_mappings = {
            'activewear-yoga': ['activewear-yoga', 'activewear', 'yoga-pants'],
            'tops-blouses': ['tops-blouses', 'tops', 'blouses'],
            'dresses-skirts': ['dresses-skirts', 'dresses', 'skirts'],
            'lingerie-sleepwear': ['lingerie-sleepwear', 'lingerie', 'sleepwear'],
            'jackets-coats': ['jackets-coats', 'jackets', 'coats'],
            'shoes-accessories': ['shoes-accessories', 'shoes', 'accessories']
        }
        
        for group, cats in expected_mappings.items():
            print(f"\n  {group.upper()}:")
            for cat in cats:
                cursor.execute("SELECT COUNT(*) as count FROM products WHERE category = %s", (cat,))
                result = cursor.fetchone()
                status = "✅" if result['count'] > 0 else "❌"
                print(f"    {status} '{cat}': {result['count']} products")
        
        print()
        print("=" * 80)
        
        cursor.close()
        
    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        close_db_connection(connection)

if __name__ == "__main__":
    check_product_categories()
