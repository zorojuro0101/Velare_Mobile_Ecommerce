import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_config import get_db_connection, close_db_connection

conn = get_db_connection()
cursor = conn.cursor(dictionary=True)

# Check all riders
cursor.execute("""
    SELECT rider_id, first_name, last_name, profile_image
    FROM riders
""")
all_riders = cursor.fetchall()

print("\n=== ALL RIDERS ===")
for r in all_riders:
    profile_status = "✅ HAS PROFILE" if r['profile_image'] else "❌ NO PROFILE"
    print(f"Rider {r['rider_id']}: {r['first_name']} {r['last_name']} - {profile_status}")
    if r['profile_image']:
        print(f"  Path: {r['profile_image']}")

# Check specific rider
cursor.execute("""
    SELECT rider_id, first_name, last_name, orcr_file_path, driver_license_file_path, profile_image
    FROM riders 
    WHERE rider_id = 6
""")
rider = cursor.fetchone()

if rider:
    print("\n=== RIDER 6 DETAILED DATA ===")
    print(f"Name: {rider['first_name']} {rider['last_name']}")
    print(f"Profile Image: {rider['profile_image']}")
    print(f"ORCR Path: {rider['orcr_file_path']}")
    print(f"Driver License Path: {rider['driver_license_file_path']}")
    
    # Check if files exist
    print("\n=== FILE EXISTENCE ===")
    if rider['orcr_file_path']:
        orcr_path = rider['orcr_file_path'].lstrip('/')
        exists = os.path.exists(orcr_path)
        print(f"ORCR File: {'✅ EXISTS' if exists else '❌ NOT FOUND'} - {orcr_path}")
    
    if rider['driver_license_file_path']:
        dl_path = rider['driver_license_file_path'].lstrip('/')
        exists = os.path.exists(dl_path)
        print(f"DL File: {'✅ EXISTS' if exists else '❌ NOT FOUND'} - {dl_path}")
    
    if rider['profile_image']:
        profile_path = f"static/{rider['profile_image']}"
        exists = os.path.exists(profile_path)
        print(f"Profile Image: {'✅ EXISTS' if exists else '❌ NOT FOUND'} - {profile_path}")
    else:
        print(f"Profile Image: ❌ NULL in database")
else:
    print("Rider 6 not found")

close_db_connection(conn, cursor)
