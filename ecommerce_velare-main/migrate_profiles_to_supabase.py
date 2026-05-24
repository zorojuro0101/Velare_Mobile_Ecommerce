"""
Migration Script: Move all local profile images to Supabase Storage
Run this once to migrate all existing profile images from local storage to Supabase
"""

import os
import sys
from datetime import datetime
import uuid

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_config import get_supabase_client

def migrate_buyer_profiles():
    """Migrate all buyer profile images to Supabase"""
    print("\n" + "="*80)
    print("📤 MIGRATING BUYER PROFILE IMAGES TO SUPABASE")
    print("="*80 + "\n")
    
    supabase = get_supabase_client()
    if not supabase:
        print("❌ Failed to connect to Supabase")
        return
    
    # Get all buyers with profile images
    response = supabase.table('buyers').select('buyer_id, user_id, profile_image').execute()
    buyers = response.data if response.data else []
    
    print(f"📊 Found {len(buyers)} buyers")
    
    migrated = 0
    skipped = 0
    errors = 0
    
    for buyer in buyers:
        buyer_id = buyer['buyer_id']
        user_id = buyer['user_id']
        profile_image = buyer.get('profile_image')
        
        # Skip if no profile image
        if not profile_image:
            print(f"  ⏭️  Buyer {buyer_id}: No profile image")
            skipped += 1
            continue
        
        # Skip if already Supabase URL
        if profile_image.startswith('http://') or profile_image.startswith('https://'):
            print(f"  ✅ Buyer {buyer_id}: Already on Supabase")
            skipped += 1
            continue
        
        # Construct local file path
        local_path = profile_image
        if local_path.startswith('/'):
            local_path = local_path[1:]  # Remove leading /
        if not local_path.startswith('static/'):
            local_path = 'static/' + local_path
        
        print(f"\n  🔄 Buyer {buyer_id}: Migrating {profile_image}")
        print(f"     Local path: {local_path}")
        
        # Check if file exists
        if not os.path.exists(local_path):
            print(f"     ❌ File not found - skipping")
            errors += 1
            continue
        
        try:
            # Read file
            with open(local_path, 'rb') as f:
                file_content = f.read()
            
            # Determine file extension
            file_ext = os.path.splitext(local_path)[1] or '.jpg'
            
            # Generate unique filename
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            unique_id = str(uuid.uuid4())[:8]
            unique_filename = f"static/uploads/profiles/buyer_{user_id}_{timestamp}_{unique_id}{file_ext}"
            
            print(f"     📤 Uploading to: {unique_filename}")
            
            # Determine content type
            content_type = 'image/jpeg'
            if file_ext.lower() in ['.png']:
                content_type = 'image/png'
            elif file_ext.lower() in ['.gif']:
                content_type = 'image/gif'
            elif file_ext.lower() in ['.webp']:
                content_type = 'image/webp'
            
            # Upload to Supabase
            upload_response = supabase.storage.from_('Images').upload(
                path=unique_filename,
                file=file_content,
                file_options={"content-type": content_type}
            )
            
            if not upload_response:
                raise Exception("Upload failed - no response")
            
            # Get public URL
            public_url = supabase.storage.from_('Images').get_public_url(unique_filename)
            
            print(f"     ✅ Uploaded: {public_url[:80]}...")
            
            # Update database
            supabase.table('buyers').update({
                'profile_image': public_url
            }).eq('buyer_id', buyer_id).execute()
            
            print(f"     ✅ Database updated")
            migrated += 1
            
        except Exception as e:
            print(f"     ❌ Error: {e}")
            errors += 1
    
    print(f"\n{'='*80}")
    print(f"📊 BUYER MIGRATION SUMMARY")
    print(f"{'='*80}")
    print(f"✅ Migrated: {migrated}")
    print(f"⏭️  Skipped: {skipped}")
    print(f"❌ Errors: {errors}")
    print(f"{'='*80}\n")

def migrate_rider_profiles():
    """Migrate all rider profile images to Supabase"""
    print("\n" + "="*80)
    print("📤 MIGRATING RIDER PROFILE IMAGES TO SUPABASE")
    print("="*80 + "\n")
    
    supabase = get_supabase_client()
    if not supabase:
        print("❌ Failed to connect to Supabase")
        return
    
    # Get all riders with profile images
    response = supabase.table('riders').select('rider_id, user_id, profile_image').execute()
    riders = response.data if response.data else []
    
    print(f"📊 Found {len(riders)} riders")
    
    migrated = 0
    skipped = 0
    errors = 0
    
    for rider in riders:
        rider_id = rider['rider_id']
        user_id = rider['user_id']
        profile_image = rider.get('profile_image')
        
        # Skip if no profile image
        if not profile_image:
            print(f"  ⏭️  Rider {rider_id}: No profile image")
            skipped += 1
            continue
        
        # Skip if already Supabase URL
        if profile_image.startswith('http://') or profile_image.startswith('https://'):
            print(f"  ✅ Rider {rider_id}: Already on Supabase")
            skipped += 1
            continue
        
        # Construct local file path
        local_path = profile_image
        if local_path.startswith('/'):
            local_path = local_path[1:]  # Remove leading /
        if not local_path.startswith('static/'):
            local_path = 'static/' + local_path
        
        print(f"\n  🔄 Rider {rider_id}: Migrating {profile_image}")
        print(f"     Local path: {local_path}")
        
        # Check if file exists
        if not os.path.exists(local_path):
            print(f"     ❌ File not found - skipping")
            errors += 1
            continue
        
        try:
            # Read file
            with open(local_path, 'rb') as f:
                file_content = f.read()
            
            # Determine file extension
            file_ext = os.path.splitext(local_path)[1] or '.jpg'
            
            # Generate unique filename
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            unique_id = str(uuid.uuid4())[:8]
            unique_filename = f"static/uploads/profiles/rider_{user_id}_{timestamp}_{unique_id}{file_ext}"
            
            print(f"     📤 Uploading to: {unique_filename}")
            
            # Determine content type
            content_type = 'image/jpeg'
            if file_ext.lower() in ['.png']:
                content_type = 'image/png'
            elif file_ext.lower() in ['.gif']:
                content_type = 'image/gif'
            elif file_ext.lower() in ['.webp']:
                content_type = 'image/webp'
            
            # Upload to Supabase
            upload_response = supabase.storage.from_('Images').upload(
                path=unique_filename,
                file=file_content,
                file_options={"content-type": content_type}
            )
            
            if not upload_response:
                raise Exception("Upload failed - no response")
            
            # Get public URL
            public_url = supabase.storage.from_('Images').get_public_url(unique_filename)
            
            print(f"     ✅ Uploaded: {public_url[:80]}...")
            
            # Update database
            supabase.table('riders').update({
                'profile_image': public_url
            }).eq('rider_id', rider_id).execute()
            
            print(f"     ✅ Database updated")
            migrated += 1
            
        except Exception as e:
            print(f"     ❌ Error: {e}")
            errors += 1
    
    print(f"\n{'='*80}")
    print(f"📊 RIDER MIGRATION SUMMARY")
    print(f"{'='*80}")
    print(f"✅ Migrated: {migrated}")
    print(f"⏭️  Skipped: {skipped}")
    print(f"❌ Errors: {errors}")
    print(f"{'='*80}\n")

def migrate_seller_logos():
    """Check seller shop logos (should already be on Supabase)"""
    print("\n" + "="*80)
    print("📤 CHECKING SELLER SHOP LOGOS")
    print("="*80 + "\n")
    
    supabase = get_supabase_client()
    if not supabase:
        print("❌ Failed to connect to Supabase")
        return
    
    # Get all sellers with shop logos
    response = supabase.table('sellers').select('seller_id, shop_name, shop_logo').execute()
    sellers = response.data if response.data else []
    
    print(f"📊 Found {len(sellers)} sellers")
    
    supabase_count = 0
    local_count = 0
    none_count = 0
    
    for seller in sellers:
        seller_id = seller['seller_id']
        shop_logo = seller.get('shop_logo')
        
        if not shop_logo:
            none_count += 1
        elif shop_logo.startswith('http://') or shop_logo.startswith('https://'):
            supabase_count += 1
        else:
            local_count += 1
            print(f"  ⚠️  Seller {seller_id}: Still using local path: {shop_logo}")
    
    print(f"\n{'='*80}")
    print(f"📊 SELLER LOGO SUMMARY")
    print(f"{'='*80}")
    print(f"✅ On Supabase: {supabase_count}")
    print(f"⚠️  Local paths: {local_count}")
    print(f"⏭️  No logo: {none_count}")
    print(f"{'='*80}\n")

if __name__ == '__main__':
    print("\n" + "="*80)
    print("🚀 PROFILE IMAGE MIGRATION TO SUPABASE")
    print("="*80)
    print("\nThis script will migrate all local profile images to Supabase Storage.")
    print("The database will be updated with new Supabase URLs.")
    print("\n⚠️  WARNING: Make sure you have a backup of your database before proceeding!")
    print("\n" + "="*80 + "\n")
    
    response = input("Do you want to proceed? (yes/no): ")
    
    if response.lower() != 'yes':
        print("\n❌ Migration cancelled")
        sys.exit(0)
    
    # Run migrations
    migrate_buyer_profiles()
    migrate_rider_profiles()
    migrate_seller_logos()
    
    print("\n" + "="*80)
    print("✅ MIGRATION COMPLETE")
    print("="*80)
    print("\nNext steps:")
    print("1. Verify images display correctly in the app")
    print("2. Check Supabase Storage dashboard")
    print("3. Test uploading new profile images")
    print("4. (Optional) Delete old local files from static/uploads/profiles/")
    print("\n" + "="*80 + "\n")
