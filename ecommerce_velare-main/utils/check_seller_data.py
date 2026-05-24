import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_config import get_db_connection, close_db_connection

conn = get_db_connection()
cursor = conn.cursor(dictionary=True)

cursor.execute("""
    SELECT seller_id, first_name, last_name, id_type, id_file_path, business_permit_file_path, shop_logo, shop_name
    FROM sellers 
    WHERE seller_id = 7
""")
seller = cursor.fetchone()

if seller:
    print("\n=== SELLER 7 DATA ===")
    print(f"Name: {seller['first_name']} {seller['last_name']}")
    print(f"Shop Name: {seller['shop_name']}")
    print(f"Shop Logo: {seller['shop_logo']}")
    print(f"ID Type: {seller['id_type']}")
    print(f"ID Path: {seller['id_file_path']}")
    print(f"Permit Path: {seller['business_permit_file_path']}")
    
    # Check if files exist
    print("\n=== FILE EXISTENCE ===")
    if seller['id_file_path']:
        id_path = seller['id_file_path'].lstrip('/')
        exists = os.path.exists(id_path)
        print(f"ID File: {'✅ EXISTS' if exists else '❌ NOT FOUND'} - {id_path}")
    
    if seller['business_permit_file_path']:
        permit_path = seller['business_permit_file_path'].lstrip('/')
        exists = os.path.exists(permit_path)
        print(f"Permit File: {'✅ EXISTS' if exists else '❌ NOT FOUND'} - {permit_path}")
    
    if seller['shop_logo']:
        logo_path = f"static/{seller['shop_logo']}"
        exists = os.path.exists(logo_path)
        print(f"Shop Logo: {'✅ EXISTS' if exists else '❌ NOT FOUND'} - {logo_path}")
else:
    print("Seller 7 not found")

close_db_connection(conn, cursor)
