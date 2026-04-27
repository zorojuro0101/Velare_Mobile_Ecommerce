"""
Create a test user in Supabase for login testing
"""
from database.db_config import get_supabase_client
from datetime import datetime

def create_test_user():
    print("\n🔧 Creating test user in Supabase...")
    
    supabase = get_supabase_client()
    if not supabase:
        print("❌ Failed to connect to Supabase")
        return
    
    # Test user data
    test_email = "test@example.com"
    test_password = "Test123"  # Must have: uppercase, lowercase, number
    
    try:
        # Check if user already exists
        existing = supabase.table('users').select('*').eq('email', test_email).execute()
        if existing.data:
            print(f"✅ Test user already exists: {test_email}")
            print(f"   Password: {test_password}")
            return
        
        # Create user
        user_data = {
            'email': test_email,
            'password': test_password,
            'user_type': 'buyer',
            'status': 'active',  # Set to active so we can login immediately
            'created_at': datetime.now().isoformat()
        }
        
        user_response = supabase.table('users').insert(user_data).execute()
        
        if not user_response.data:
            print("❌ Failed to create user")
            return
        
        user_id = user_response.data[0]['user_id']
        print(f"✅ User created! user_id: {user_id}")
        
        # Create buyer profile
        buyer_data = {
            'user_id': user_id,
            'first_name': 'Test',
            'last_name': 'User',
            'created_at': datetime.now().isoformat()
        }
        
        buyer_response = supabase.table('buyers').insert(buyer_data).execute()
        
        if buyer_response.data:
            print(f"✅ Buyer profile created!")
            print(f"\n🎉 Test user ready!")
            print(f"   Email: {test_email}")
            print(f"   Password: {test_password}")
            print(f"\n   Go to: http://localhost:5000/login")
        else:
            print("❌ Failed to create buyer profile")
            
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    create_test_user()
