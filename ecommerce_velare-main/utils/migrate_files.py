"""
File Migration Script
Moves existing user documents from old structure to new organized structure
Run this AFTER running the SQL migration script
"""
import os
import shutil
import sys

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_config import get_db_connection, close_db_connection

def create_directory_structure():
    """Create the new directory structure"""
    base_dir = 'static/uploads'
    
    folders = [
        'seller_ids',
        'seller_permits',
        'rider_orcr',
        'rider_dl',
        'buyer_ids'
    ]
    
    for folder in folders:
        folder_path = os.path.join(base_dir, folder)
        os.makedirs(folder_path, exist_ok=True)
        print(f"✅ Created directory: {folder_path}")

def migrate_seller_files():
    """Migrate seller ID and business permit files"""
    print("\n📦 Migrating Seller Files...")
    
    connection = get_db_connection()
    if not connection:
        print("❌ Database connection failed")
        return
    
    cursor = connection.cursor(dictionary=True)
    
    # Get all sellers with file paths
    cursor.execute("""
        SELECT seller_id, id_file_path, business_permit_file_path
        FROM sellers
        WHERE id_file_path IS NOT NULL OR business_permit_file_path IS NOT NULL
    """)
    
    sellers = cursor.fetchall()
    print(f"Found {len(sellers)} sellers with documents")
    
    for seller in sellers:
        seller_id = seller['seller_id']
        
        # Create user folder
        id_folder = f"static/uploads/seller_ids/user_{seller_id}"
        permit_folder = f"static/uploads/seller_permits/user_{seller_id}"
        os.makedirs(id_folder, exist_ok=True)
        os.makedirs(permit_folder, exist_ok=True)
        
        # Migrate ID file
        if seller['id_file_path']:
            old_path = seller['id_file_path'].lstrip('/')
            if os.path.exists(old_path):
                filename = os.path.basename(old_path)
                new_filename = f"id_{filename}"
                new_path = os.path.join(id_folder, new_filename)
                
                try:
                    shutil.copy2(old_path, new_path)
                    print(f"  ✅ Seller {seller_id}: Copied ID file")
                except Exception as e:
                    print(f"  ❌ Seller {seller_id}: Failed to copy ID - {e}")
            else:
                print(f"  ⚠️  Seller {seller_id}: ID file not found at {old_path}")
        
        # Migrate business permit file
        if seller['business_permit_file_path']:
            old_path = seller['business_permit_file_path'].lstrip('/')
            if os.path.exists(old_path):
                filename = os.path.basename(old_path)
                new_filename = f"business_permit_{filename}"
                new_path = os.path.join(permit_folder, new_filename)
                
                try:
                    shutil.copy2(old_path, new_path)
                    print(f"  ✅ Seller {seller_id}: Copied business permit")
                except Exception as e:
                    print(f"  ❌ Seller {seller_id}: Failed to copy permit - {e}")
            else:
                print(f"  ⚠️  Seller {seller_id}: Permit file not found at {old_path}")
    
    close_db_connection(connection, cursor)

def migrate_rider_files():
    """Migrate rider ORCR and driver license files"""
    print("\n🏍️  Migrating Rider Files...")
    
    connection = get_db_connection()
    if not connection:
        print("❌ Database connection failed")
        return
    
    cursor = connection.cursor(dictionary=True)
    
    # Get all riders with file paths
    cursor.execute("""
        SELECT rider_id, orcr_file_path, driver_license_file_path
        FROM riders
        WHERE orcr_file_path IS NOT NULL OR driver_license_file_path IS NOT NULL
    """)
    
    riders = cursor.fetchall()
    print(f"Found {len(riders)} riders with documents")
    
    for rider in riders:
        rider_id = rider['rider_id']
        
        # Create user folders
        orcr_folder = f"static/uploads/rider_orcr/user_{rider_id}"
        dl_folder = f"static/uploads/rider_dl/user_{rider_id}"
        os.makedirs(orcr_folder, exist_ok=True)
        os.makedirs(dl_folder, exist_ok=True)
        
        # Migrate ORCR file
        if rider['orcr_file_path']:
            old_path = rider['orcr_file_path'].lstrip('/')
            if os.path.exists(old_path):
                filename = os.path.basename(old_path)
                new_filename = f"orcr_{filename}"
                new_path = os.path.join(orcr_folder, new_filename)
                
                try:
                    shutil.copy2(old_path, new_path)
                    print(f"  ✅ Rider {rider_id}: Copied ORCR file")
                except Exception as e:
                    print(f"  ❌ Rider {rider_id}: Failed to copy ORCR - {e}")
            else:
                print(f"  ⚠️  Rider {rider_id}: ORCR file not found at {old_path}")
        
        # Migrate driver license file
        if rider['driver_license_file_path']:
            old_path = rider['driver_license_file_path'].lstrip('/')
            if os.path.exists(old_path):
                filename = os.path.basename(old_path)
                new_filename = f"driver_license_{filename}"
                new_path = os.path.join(dl_folder, new_filename)
                
                try:
                    shutil.copy2(old_path, new_path)
                    print(f"  ✅ Rider {rider_id}: Copied driver license")
                except Exception as e:
                    print(f"  ❌ Rider {rider_id}: Failed to copy DL - {e}")
            else:
                print(f"  ⚠️  Rider {rider_id}: DL file not found at {old_path}")
    
    close_db_connection(connection, cursor)

def migrate_buyer_files():
    """Migrate buyer ID files (if applicable)"""
    print("\n🛒 Migrating Buyer Files...")
    
    connection = get_db_connection()
    if not connection:
        print("❌ Database connection failed")
        return
    
    cursor = connection.cursor(dictionary=True)
    
    # Check if buyers table has id_file_path column
    cursor.execute("SHOW COLUMNS FROM buyers LIKE 'id_file_path'")
    if not cursor.fetchone():
        print("  ℹ️  Buyers table doesn't have id_file_path column, skipping...")
        close_db_connection(connection, cursor)
        return
    
    # Get all buyers with file paths
    cursor.execute("""
        SELECT buyer_id, id_file_path
        FROM buyers
        WHERE id_file_path IS NOT NULL
    """)
    
    buyers = cursor.fetchall()
    print(f"Found {len(buyers)} buyers with documents")
    
    for buyer in buyers:
        buyer_id = buyer['buyer_id']
        
        # Create user folder
        id_folder = f"static/uploads/buyer_ids/user_{buyer_id}"
        os.makedirs(id_folder, exist_ok=True)
        
        # Migrate ID file
        if buyer['id_file_path']:
            old_path = buyer['id_file_path'].lstrip('/')
            if os.path.exists(old_path):
                filename = os.path.basename(old_path)
                new_filename = f"id_{filename}"
                new_path = os.path.join(id_folder, new_filename)
                
                try:
                    shutil.copy2(old_path, new_path)
                    print(f"  ✅ Buyer {buyer_id}: Copied ID file")
                except Exception as e:
                    print(f"  ❌ Buyer {buyer_id}: Failed to copy ID - {e}")
            else:
                print(f"  ⚠️  Buyer {buyer_id}: ID file not found at {old_path}")
    
    close_db_connection(connection, cursor)

def main():
    """Main migration function"""
    print("=" * 60)
    print("FILE MIGRATION SCRIPT")
    print("=" * 60)
    print("\n⚠️  WARNING: This script will copy files to new locations.")
    print("Make sure you have:")
    print("1. Backed up your database")
    print("2. Backed up your static/uploads folder")
    print("3. Run the SQL migration script first")
    print("\n" + "=" * 60)
    
    response = input("\nDo you want to continue? (yes/no): ").strip().lower()
    if response != 'yes':
        print("Migration cancelled.")
        return
    
    print("\n🚀 Starting migration...\n")
    
    # Step 1: Create directory structure
    print("Step 1: Creating directory structure...")
    create_directory_structure()
    
    # Step 2: Migrate seller files
    print("\nStep 2: Migrating seller files...")
    migrate_seller_files()
    
    # Step 3: Migrate rider files
    print("\nStep 3: Migrating rider files...")
    migrate_rider_files()
    
    # Step 4: Migrate buyer files
    print("\nStep 4: Migrating buyer files...")
    migrate_buyer_files()
    
    print("\n" + "=" * 60)
    print("✅ MIGRATION COMPLETE!")
    print("=" * 60)
    print("\nNext steps:")
    print("1. Verify files are in new locations")
    print("2. Test file uploads with new users")
    print("3. Test file viewing in admin panels")
    print("4. Once verified, you can delete old files from static/uploads/ids/")
    print("\n⚠️  DO NOT delete old files until you've verified everything works!")

if __name__ == '__main__':
    main()
