"""
Test Buyer Registration to Supabase
"""
from database.db_config import get_supabase_client
from datetime import datetime

def test_registration():
    print("\n🧪 Testing Buyer Registration to Supabase...")
    
    supabase = get_supabase_client()
    if not supabase:
        print("❌ Failed to connect to Supabase")
        return
    
    # Test data
    test_email = f"buyer_test_{datetime.now().strftime('%Y%m%d_%H%M%S')}@example.com"
    test_password = "Test123"
    
    try:
        print(f"\n1️⃣ Creating user: {test_email}")
        
        # Insert user
        user_data = {
            'email': test_email,
            'password': test_password,
            'user_type': 'buyer',
            'status': 'pending',
            'created_at': datetime.now().isoformat()
        }
        
        user_response = supabase.table('users').insert(user_data).execute()
        
        if not user_response.data:
            print("❌ Failed to create user")
            return
        
        user_id = user_response.data[0]['user_id']
        print(f"✅ User created! user_id: {user_id}")
        
        # Insert buyer
        print(f"\n2️⃣ Creating buyer profile...")
        buyer_data = {
            'user_id': user_id,
            'first_name': 'Test',
            'last_name': 'Buyer',
            'id_type': 'National ID',
            'id_file_path': '/static/uploads/ids/test.jpg',
            'created_at': datetime.now().isoformat()
        }
        
        buyer_response = supabase.table('buyers').insert(buyer_data).execute()
        
        if not buyer_response.data:
            print("❌ Failed to create buyer profile")
            return
        
        buyer_id = buyer_response.data[0]['buyer_id']
        print(f"✅ Buyer profile created! buyer_id: {buyer_id}")
        
        # Insert address
        print(f"\n3️⃣ Creating address...")
        address_data = {
            'user_type': 'buyer',
            'user_ref_id': buyer_id,
            'recipient_name': 'Test Buyer',
            'phone_number': '09123456789',
            'full_address': 'Test Street, Test City, Test Province',
            'region': 'NCR',
            'province': 'Metro Manila',
            'city': 'Manila',
            'barangay': 'Test Barangay',
            'street_name': 'Test Street',
            'house_number': '123',
            'postal_code': '1000',
            'is_default': True,
            'created_at': datetime.now().isoformat()
        }
        
        address_response = supabase.table('addresses').insert(address_data).execute()
        
        if address_response.data:
            print(f"✅ Address created!")
        else:
            print("⚠️ Address creation failed (optional)")
        
        print(f"\n🎉 Registration test successful!")
        print(f"   Email: {test_email}")
        print(f"   Password: {test_password}")
        print(f"   User ID: {user_id}")
        print(f"   Buyer ID: {buyer_id}")
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    test_registration()
