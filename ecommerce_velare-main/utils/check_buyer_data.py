import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_config import get_db_connection, close_db_connection

conn = get_db_connection()
cursor = conn.cursor(dictionary=True)

# Check all buyers
cursor.execute("""
    SELECT buyer_id, first_name, last_name, id_type, id_file_path, profile_image
    FROM buyers
""")
all_buyers = cursor.fetchall()

print("\n=== ALL BUYERS ===")
for b in all_buyers:
    profile_status = "✅ HAS PROFILE" if b['profile_image'] else "❌ NO PROFILE"
    id_status = "✅ HAS ID" if b['id_file_path'] else "❌ NO ID"
    print(f"Buyer {b['buyer_id']}: {b['first_name']} {b['last_name']}")
    print(f"  Profile: {profile_status}")
    print(f"  ID: {id_status} - Type: {b['id_type'] or 'N/A'}")
    if b['profile_image']:
        print(f"  Profile Path: {b['profile_image']}")
    if b['id_file_path']:
        print(f"  ID Path: {b['id_file_path']}")
    print()

# Check specific buyers with details
print("\n=== DETAILED FILE EXISTENCE CHECK ===")
for b in all_buyers:
    print(f"\nBuyer {b['buyer_id']}: {b['first_name']} {b['last_name']}")
    
    if b['id_file_path']:
        id_path = b['id_file_path'].lstrip('/')
        exists = os.path.exists(id_path)
        print(f"  ID File: {'✅ EXISTS' if exists else '❌ NOT FOUND'} - {id_path}")
    else:
        print(f"  ID File: ❌ NULL in database")
    
    if b['profile_image']:
        profile_path = f"static/{b['profile_image']}"
        exists = os.path.exists(profile_path)
        print(f"  Profile Image: {'✅ EXISTS' if exists else '❌ NOT FOUND'} - {profile_path}")
    else:
        print(f"  Profile Image: ❌ NULL in database")

close_db_connection(conn, cursor)
