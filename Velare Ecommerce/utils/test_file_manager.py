"""
Test script for file_manager utility
Run this to verify the file manager works correctly
"""
import os
import sys

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from utils.file_manager import get_user_document_path, allowed_file, DOCUMENT_TYPES

def test_get_user_document_path():
    """Test path generation"""
    print("Testing get_user_document_path()...")
    
    # Test seller paths
    full_path, db_path = get_user_document_path('seller', 7, 'id')
    print(f"✅ Seller ID: {db_path}")
    assert db_path == "/static/uploads/seller_ids/user_7"
    
    full_path, db_path = get_user_document_path('seller', 7, 'business_permit')
    print(f"✅ Seller Permit: {db_path}")
    assert db_path == "/static/uploads/seller_permits/user_7"
    
    # Test rider paths
    full_path, db_path = get_user_document_path('rider', 3, 'orcr')
    print(f"✅ Rider ORCR: {db_path}")
    assert db_path == "/static/uploads/rider_orcr/user_3"
    
    full_path, db_path = get_user_document_path('rider', 3, 'driver_license')
    print(f"✅ Rider DL: {db_path}")
    assert db_path == "/static/uploads/rider_dl/user_3"
    
    # Test buyer paths
    full_path, db_path = get_user_document_path('buyer', 10, 'id')
    print(f"✅ Buyer ID: {db_path}")
    assert db_path == "/static/uploads/buyer_ids/user_10"
    
    print("✅ All path tests passed!\n")

def test_allowed_file():
    """Test file extension validation"""
    print("Testing allowed_file()...")
    
    # Valid extensions
    assert allowed_file('document.jpg') == True
    assert allowed_file('document.jpeg') == True
    assert allowed_file('document.png') == True
    assert allowed_file('document.pdf') == True
    assert allowed_file('document.gif') == True
    assert allowed_file('document.webp') == True
    print("✅ Valid extensions accepted")
    
    # Invalid extensions
    assert allowed_file('document.exe') == False
    assert allowed_file('document.txt') == False
    assert allowed_file('document') == False
    assert allowed_file('') == False
    print("✅ Invalid extensions rejected")
    
    # Case insensitive
    assert allowed_file('document.JPG') == True
    assert allowed_file('document.PDF') == True
    print("✅ Case insensitive check works")
    
    print("✅ All file validation tests passed!\n")

def test_document_types():
    """Test document type configuration"""
    print("Testing DOCUMENT_TYPES configuration...")
    
    assert 'seller' in DOCUMENT_TYPES
    assert 'rider' in DOCUMENT_TYPES
    assert 'buyer' in DOCUMENT_TYPES
    
    assert 'id' in DOCUMENT_TYPES['seller']
    assert 'business_permit' in DOCUMENT_TYPES['seller']
    
    assert 'orcr' in DOCUMENT_TYPES['rider']
    assert 'driver_license' in DOCUMENT_TYPES['rider']
    
    assert 'id' in DOCUMENT_TYPES['buyer']
    
    print("✅ All document types configured correctly!\n")

def test_error_handling():
    """Test error handling"""
    print("Testing error handling...")
    
    try:
        get_user_document_path('invalid_type', 1, 'id')
        print("❌ Should have raised ValueError for invalid user_type")
    except ValueError as e:
        print(f"✅ Correctly raised ValueError: {e}")
    
    try:
        get_user_document_path('seller', 1, 'invalid_doc')
        print("❌ Should have raised ValueError for invalid document_type")
    except ValueError as e:
        print(f"✅ Correctly raised ValueError: {e}")
    
    print("✅ Error handling works correctly!\n")

def main():
    """Run all tests"""
    print("=" * 60)
    print("FILE MANAGER UTILITY TESTS")
    print("=" * 60)
    print()
    
    try:
        test_document_types()
        test_get_user_document_path()
        test_allowed_file()
        test_error_handling()
        
        print("=" * 60)
        print("✅ ALL TESTS PASSED!")
        print("=" * 60)
        print("\nThe file_manager utility is working correctly.")
        print("You can now proceed with the migration.")
        
    except AssertionError as e:
        print("\n" + "=" * 60)
        print("❌ TEST FAILED!")
        print("=" * 60)
        print(f"\nError: {e}")
        sys.exit(1)
    except Exception as e:
        print("\n" + "=" * 60)
        print("❌ UNEXPECTED ERROR!")
        print("=" * 60)
        print(f"\nError: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == '__main__':
    main()
