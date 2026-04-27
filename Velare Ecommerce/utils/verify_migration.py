"""
Verification Script - Check if migration was successful
"""
import os
import sys

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_config import get_db_connection, close_db_connection

def verify_database_paths():
    """Verify database paths are updated correctly"""
    print("=" * 70)
    print("VERIFYING DATABASE PATHS")
    print("=" * 70)
    
    connection = get_db_connection()
    if not connection:
        print("❌ Database connection failed")
        return False
    
    cursor = connection.cursor(dictionary=True)
    all_good = True
    
    # Check sellers
    print("\n📦 SELLERS:")
    cursor.execute("""
        SELECT seller_id, id_file_path, business_permit_file_path
        FROM sellers
        WHERE id_file_path IS NOT NULL OR business_permit_file_path IS NOT NULL
    """)
    sellers = cursor.fetchall()
    
    for seller in sellers:
        seller_id = seller['seller_id']
        id_path = seller['id_file_path']
        permit_path = seller['business_permit_file_path']
        
        print(f"\n  Seller {seller_id}:")
        
        # Check ID path
        if id_path:
            expected_prefix = f"/static/uploads/seller_ids/user_{seller_id}/"
            if id_path.startswith(expected_prefix):
                print(f"    ✅ ID Path: {id_path}")
            else:
                print(f"    ❌ ID Path: {id_path}")
                print(f"       Expected to start with: {expected_prefix}")
                all_good = False
        
        # Check permit path
        if permit_path:
            expected_prefix = f"/static/uploads/seller_permits/user_{seller_id}/"
            if permit_path.startswith(expected_prefix):
                print(f"    ✅ Permit Path: {permit_path}")
            else:
                print(f"    ❌ Permit Path: {permit_path}")
                print(f"       Expected to start with: {expected_prefix}")
                all_good = False
    
    # Check riders
    print("\n🏍️  RIDERS:")
    cursor.execute("""
        SELECT rider_id, orcr_file_path, driver_license_file_path
        FROM riders
        WHERE orcr_file_path IS NOT NULL OR driver_license_file_path IS NOT NULL
    """)
    riders = cursor.fetchall()
    
    for rider in riders:
        rider_id = rider['rider_id']
        orcr_path = rider['orcr_file_path']
        dl_path = rider['driver_license_file_path']
        
        print(f"\n  Rider {rider_id}:")
        
        # Check ORCR path
        if orcr_path:
            expected_prefix = f"/static/uploads/rider_orcr/user_{rider_id}/"
            if orcr_path.startswith(expected_prefix):
                print(f"    ✅ ORCR Path: {orcr_path}")
            else:
                print(f"    ❌ ORCR Path: {orcr_path}")
                print(f"       Expected to start with: {expected_prefix}")
                all_good = False
        
        # Check DL path
        if dl_path:
            expected_prefix = f"/static/uploads/rider_dl/user_{rider_id}/"
            if dl_path.startswith(expected_prefix):
                print(f"    ✅ DL Path: {dl_path}")
            else:
                print(f"    ❌ DL Path: {dl_path}")
                print(f"       Expected to start with: {expected_prefix}")
                all_good = False
    
    # Check buyers
    print("\n🛒 BUYERS:")
    cursor.execute("""
        SELECT buyer_id, id_file_path
        FROM buyers
        WHERE id_file_path IS NOT NULL
    """)
    buyers = cursor.fetchall()
    
    for buyer in buyers:
        buyer_id = buyer['buyer_id']
        id_path = buyer['id_file_path']
        
        print(f"\n  Buyer {buyer_id}:")
        
        if id_path:
            expected_prefix = f"/static/uploads/buyer_ids/user_{buyer_id}/"
            if id_path.startswith(expected_prefix):
                print(f"    ✅ ID Path: {id_path}")
            else:
                print(f"    ❌ ID Path: {id_path}")
                print(f"       Expected to start with: {expected_prefix}")
                all_good = False
    
    close_db_connection(connection, cursor)
    return all_good

def verify_files_exist():
    """Verify files exist in the file system"""
    print("\n" + "=" * 70)
    print("VERIFYING FILES EXIST")
    print("=" * 70)
    
    connection = get_db_connection()
    if not connection:
        print("❌ Database connection failed")
        return False
    
    cursor = connection.cursor(dictionary=True)
    all_good = True
    
    # Check seller files
    print("\n📦 SELLER FILES:")
    cursor.execute("""
        SELECT seller_id, id_file_path, business_permit_file_path
        FROM sellers
        WHERE id_file_path IS NOT NULL OR business_permit_file_path IS NOT NULL
    """)
    sellers = cursor.fetchall()
    
    for seller in sellers:
        seller_id = seller['seller_id']
        
        if seller['id_file_path']:
            file_path = seller['id_file_path'].lstrip('/')
            if os.path.exists(file_path):
                print(f"  ✅ Seller {seller_id} ID file exists")
            else:
                print(f"  ❌ Seller {seller_id} ID file NOT FOUND: {file_path}")
                all_good = False
        
        if seller['business_permit_file_path']:
            file_path = seller['business_permit_file_path'].lstrip('/')
            if os.path.exists(file_path):
                print(f"  ✅ Seller {seller_id} permit file exists")
            else:
                print(f"  ❌ Seller {seller_id} permit file NOT FOUND: {file_path}")
                all_good = False
    
    # Check rider files
    print("\n🏍️  RIDER FILES:")
    cursor.execute("""
        SELECT rider_id, orcr_file_path, driver_license_file_path
        FROM riders
        WHERE orcr_file_path IS NOT NULL OR driver_license_file_path IS NOT NULL
    """)
    riders = cursor.fetchall()
    
    for rider in riders:
        rider_id = rider['rider_id']
        
        if rider['orcr_file_path']:
            file_path = rider['orcr_file_path'].lstrip('/')
            if os.path.exists(file_path):
                print(f"  ✅ Rider {rider_id} ORCR file exists")
            else:
                print(f"  ❌ Rider {rider_id} ORCR file NOT FOUND: {file_path}")
                all_good = False
        
        if rider['driver_license_file_path']:
            file_path = rider['driver_license_file_path'].lstrip('/')
            if os.path.exists(file_path):
                print(f"  ✅ Rider {rider_id} DL file exists")
            else:
                print(f"  ❌ Rider {rider_id} DL file NOT FOUND: {file_path}")
                all_good = False
    
    # Check buyer files
    print("\n🛒 BUYER FILES:")
    cursor.execute("""
        SELECT buyer_id, id_file_path
        FROM buyers
        WHERE id_file_path IS NOT NULL
    """)
    buyers = cursor.fetchall()
    
    for buyer in buyers:
        buyer_id = buyer['buyer_id']
        
        if buyer['id_file_path']:
            file_path = buyer['id_file_path'].lstrip('/')
            if os.path.exists(file_path):
                print(f"  ✅ Buyer {buyer_id} ID file exists")
            else:
                print(f"  ❌ Buyer {buyer_id} ID file NOT FOUND: {file_path}")
                all_good = False
    
    close_db_connection(connection, cursor)
    return all_good

def verify_folder_structure():
    """Verify folder structure is correct"""
    print("\n" + "=" * 70)
    print("VERIFYING FOLDER STRUCTURE")
    print("=" * 70)
    
    folders = [
        'static/uploads/seller_ids',
        'static/uploads/seller_permits',
        'static/uploads/rider_orcr',
        'static/uploads/rider_dl',
        'static/uploads/buyer_ids'
    ]
    
    all_good = True
    for folder in folders:
        if os.path.exists(folder):
            file_count = sum([len(files) for r, d, files in os.walk(folder)])
            print(f"  ✅ {folder} exists ({file_count} files)")
        else:
            print(f"  ❌ {folder} NOT FOUND")
            all_good = False
    
    return all_good

def main():
    """Run all verification checks"""
    print("\n" + "=" * 70)
    print("MIGRATION VERIFICATION")
    print("=" * 70)
    
    results = {
        'folder_structure': verify_folder_structure(),
        'database_paths': verify_database_paths(),
        'files_exist': verify_files_exist()
    }
    
    print("\n" + "=" * 70)
    print("VERIFICATION SUMMARY")
    print("=" * 70)
    
    for check, passed in results.items():
        status = "✅ PASSED" if passed else "❌ FAILED"
        print(f"  {check.replace('_', ' ').title()}: {status}")
    
    if all(results.values()):
        print("\n" + "=" * 70)
        print("✅ ALL CHECKS PASSED!")
        print("=" * 70)
        print("\nMigration is successful! You can now:")
        print("1. Test the application")
        print("2. Register new users")
        print("3. View documents in admin panel")
        print("4. After thorough testing, delete old files from static/uploads/ids/")
        return 0
    else:
        print("\n" + "=" * 70)
        print("❌ SOME CHECKS FAILED")
        print("=" * 70)
        print("\nPlease review the errors above and:")
        print("1. Check if SQL migration was run")
        print("2. Check if file migration was run")
        print("3. Check database connection")
        return 1

if __name__ == '__main__':
    exit(main())
