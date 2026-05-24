import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_config import get_db_connection, close_db_connection

conn = get_db_connection()
cursor = conn.cursor(dictionary=True)

print("\n=== CURRENT DATABASE PATHS ===\n")

cursor.execute("SELECT seller_id, id_file_path, business_permit_file_path FROM sellers WHERE seller_id = 7")
seller = cursor.fetchone()
if seller:
    print(f"Seller 7:")
    print(f"  ID: {seller['id_file_path']}")
    print(f"  Permit: {seller['business_permit_file_path']}")

cursor.execute("SELECT rider_id, orcr_file_path, driver_license_file_path FROM riders WHERE rider_id = 6")
rider = cursor.fetchone()
if rider:
    print(f"\nRider 6:")
    print(f"  ORCR: {rider['orcr_file_path']}")
    print(f"  DL: {rider['driver_license_file_path']}")

close_db_connection(conn, cursor)

print("\n=== ACTUAL FILES IN FOLDERS ===\n")
import glob

seller_id_files = glob.glob("static/uploads/seller_ids/user_7/*")
print(f"Seller 7 ID files: {[os.path.basename(f) for f in seller_id_files]}")

seller_permit_files = glob.glob("static/uploads/seller_permits/user_7/*")
print(f"Seller 7 Permit files: {[os.path.basename(f) for f in seller_permit_files]}")

rider_orcr_files = glob.glob("static/uploads/rider_orcr/user_6/*")
print(f"Rider 6 ORCR files: {[os.path.basename(f) for f in rider_orcr_files]}")

rider_dl_files = glob.glob("static/uploads/rider_dl/user_6/*")
print(f"Rider 6 DL files: {[os.path.basename(f) for f in rider_dl_files]}")
