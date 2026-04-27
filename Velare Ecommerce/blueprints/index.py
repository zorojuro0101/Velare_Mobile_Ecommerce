from flask import Blueprint, render_template, session
import mysql.connector
from mysql.connector import Error
import random

index_bp = Blueprint('index', __name__)

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

def fix_image_path(image_url):
    """Remove 'static/' prefix if it exists in the image path"""
    if image_url and image_url.startswith('static/'):
        return image_url[7:]  # Remove 'static/' prefix
    return image_url

@index_bp.route('/')
def index():
    # Debug: Print session contents
    print("=" * 50)
    print("INDEX PAGE - Session Debug:")
    print(f"Session contents: {dict(session)}")
    print(f"'user_id' in session: {'user_id' in session}")
    print(f"'logged_in' in session: {session.get('logged_in')}")
    print("=" * 50)
    
    is_logged_in = 'user_id' in session
    
    # Initialize default values
    best_sellers = []
    latest_products = []
    top_rated_products = []
    random_products = []
    
    connection = get_db_connection()
    if connection:
        try:
            cursor = connection.cursor(dictionary=True)
            
            # Get ALL best sellers (highest total_sold) with active status
            cursor.execute("""
                SELECT p.product_id, p.product_name, p.category, pi.image_url
                FROM products p
                LEFT JOIN product_images pi ON p.product_id = pi.product_id AND pi.is_primary = 1
                WHERE p.is_active = 1 AND p.total_sold > 0
                ORDER BY p.total_sold DESC
            """)
            best_sellers = cursor.fetchall()
            for product in best_sellers:
                if product.get('image_url'):
                    product['image_url'] = fix_image_path(product['image_url'])
            
            # Get ALL latest products (most recent)
            cursor.execute("""
                SELECT p.product_id, p.product_name, p.category, pi.image_url
                FROM products p
                LEFT JOIN product_images pi ON p.product_id = pi.product_id AND pi.is_primary = 1
                WHERE p.is_active = 1
                ORDER BY p.created_at DESC
            """)
            latest_products = cursor.fetchall()
            for product in latest_products:
                if product.get('image_url'):
                    product['image_url'] = fix_image_path(product['image_url'])
            
            # Get ALL top rated products (highest rating with at least 1 review)
            cursor.execute("""
                SELECT p.product_id, p.product_name, p.category, pi.image_url
                FROM products p
                LEFT JOIN product_images pi ON p.product_id = pi.product_id AND pi.is_primary = 1
                WHERE p.is_active = 1 AND p.total_reviews > 0
                ORDER BY p.rating DESC, p.total_reviews DESC
            """)
            top_rated_products = cursor.fetchall()
            for product in top_rated_products:
                if product.get('image_url'):
                    product['image_url'] = fix_image_path(product['image_url'])
            
            # Get ALL random products
            cursor.execute("""
                SELECT p.product_id, p.product_name, p.category, pi.image_url
                FROM products p
                LEFT JOIN product_images pi ON p.product_id = pi.product_id AND pi.is_primary = 1
                WHERE p.is_active = 1
            """)
            random_products = cursor.fetchall()
            # Shuffle all products for random display
            if random_products:
                random.shuffle(random_products)
                for product in random_products:
                    if product.get('image_url'):
                        product['image_url'] = fix_image_path(product['image_url'])
            
            cursor.close()
        except Error as e:
            print(f"Error fetching products: {e}")
        finally:
            connection.close()
    
    return render_template('index.html', 
                         is_logged_in=is_logged_in,
                         best_sellers=best_sellers,
                         latest_products=latest_products,
                         top_rated_products=top_rated_products,
                         random_products=random_products)
