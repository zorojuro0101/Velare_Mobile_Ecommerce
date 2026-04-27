"""
Test Order Flow Script
Tests the complete order flow from buyer placing order to rider delivery

Flow:
1. Buyer places order
2. Seller prepares package
3. Seller marks ready for pickup
4. Rider accepts delivery
5. Rider picks up from seller
6. Rider delivers to buyer
7. Order completed
"""

import requests
import json
import time

# Base URL
BASE_URL = "http://127.0.0.1:5000"

# Test user credentials
BUYER_EMAIL = "jejemon@gmail.com"
BUYER_PASSWORD = "Qwerty12"

SELLER_EMAIL = "justinemarkgahi@gmail.com"
SELLER_PASSWORD = "Qwerty12"

RIDER_EMAIL = "rere@gmail.com"
RIDER_PASSWORD = "Qwerty12"

class OrderFlowTester:
    def __init__(self):
        self.buyer_session = requests.Session()
        self.seller_session = requests.Session()
        self.rider_session = requests.Session()
        self.order_id = None
        self.delivery_id = None
        
    def login_user(self, session, email, password, user_type):
        """Login a user and return session"""
        print(f"\n{'='*50}")
        print(f"Logging in {user_type}: {email}")
        print(f"{'='*50}")
        
        response = session.post(
            f"{BASE_URL}/login",
            data={
                'email': email,
                'password': password
            },
            allow_redirects=False
        )
        
        if response.status_code in [200, 302]:
            print(f"✓ {user_type} logged in successfully")
            return True
        else:
            print(f"✗ {user_type} login failed: {response.status_code}")
            return False
    
    def get_seller_product(self):
        """Get a product from the seller"""
        print(f"\n{'='*50}")
        print("Getting seller's product")
        print(f"{'='*50}")
        
        # For testing, use product ID 1 (update this if needed)
        # In production, you would query the database or API
        product_id = 1
        print(f"✓ Using product ID: {product_id}")
        print(f"⚠ Note: Make sure this product exists and belongs to seller {SELLER_EMAIL}")
        return product_id
    
    def buyer_add_to_cart(self, product_id):
        """Add seller's product to buyer's cart"""
        print(f"\n{'='*50}")
        print("Adding product to cart")
        print(f"{'='*50}")
        
        response = self.buyer_session.post(
            f"{BASE_URL}/cart/add",
            json={
                'product_id': product_id,
                'quantity': 1
            }
        )
        
        if response.status_code == 200:
            data = response.json()
            if data.get('success'):
                print(f"✓ Product added to cart")
                return True
        
        print(f"✗ Failed to add to cart: {response.status_code}")
        return False
    
    def buyer_place_order(self):
        """Step 1: Buyer places an order"""
        print(f"\n{'='*50}")
        print("STEP 1: Buyer places order")
        print(f"{'='*50}")
        
        # Get seller's product
        product_id = self.get_seller_product()
        if not product_id:
            return False
        
        # Add to cart
        if not self.buyer_add_to_cart(product_id):
            return False
        
        time.sleep(1)
        
        # Get cart items
        response = self.buyer_session.get(f"{BASE_URL}/cart/api/items")
        
        if response.status_code != 200:
            print("✗ Failed to get cart items")
            return False
        
        cart_data = response.json()
        if not cart_data.get('items'):
            print("✗ Cart is empty after adding item")
            return False
        
        cart_ids = [item['cart_id'] for item in cart_data['items']]
        print(f"Found {len(cart_ids)} items in cart")
        
        # Get buyer's address
        response = self.buyer_session.get(f"{BASE_URL}/myAccount/address/api/addresses")
        if response.status_code != 200:
            print("✗ Failed to get addresses")
            return False
        
        addresses = response.json().get('addresses', [])
        if not addresses:
            print("✗ Buyer has no delivery address")
            return False
        
        address_id = addresses[0]['address_id']
        print(f"Using address ID: {address_id}")
        
        # Place order
        response = self.buyer_session.post(
            f"{BASE_URL}/checkout/place-order",
            json={
                'cart_ids': cart_ids,
                'address_id': address_id,
                'payment_method': 'cod'
            }
        )
        
        if response.status_code == 200:
            data = response.json()
            if data.get('success'):
                self.order_id = data.get('order_id')
                print(f"✓ Order placed successfully! Order ID: {self.order_id}")
                return True
        
        print(f"✗ Failed to place order: {response.status_code}")
        print(f"Response: {response.text}")
        return False
    
    def seller_prepare_package(self):
        """Step 2: Seller prepares the package"""
        print(f"\n{'='*50}")
        print("STEP 2: Seller prepares package")
        print(f"{'='*50}")
        
        if not self.order_id:
            print("✗ No order ID available")
            return False
        
        response = self.seller_session.post(
            f"{BASE_URL}/seller/product-management/api/prepare-order",
            json={'order_id': self.order_id}
        )
        
        if response.status_code == 200:
            data = response.json()
            if data.get('success'):
                print(f"✓ Package prepared successfully!")
                time.sleep(1)
                return True
        
        print(f"✗ Failed to prepare package: {response.status_code}")
        print(f"Response: {response.text}")
        return False
    
    def seller_ready_for_pickup(self):
        """Step 3: Seller marks order ready for pickup"""
        print(f"\n{'='*50}")
        print("STEP 3: Seller marks ready for pickup")
        print(f"{'='*50}")
        
        if not self.order_id:
            print("✗ No order ID available")
            return False
        
        response = self.seller_session.post(
            f"{BASE_URL}/seller/product-management/api/ready-for-pickup",
            json={'order_id': self.order_id}
        )
        
        if response.status_code == 200:
            data = response.json()
            if data.get('success'):
                self.delivery_id = data.get('delivery_id')
                print(f"✓ Order ready for pickup! Delivery ID: {self.delivery_id}")
                time.sleep(1)
                return True
        
        print(f"✗ Failed to mark ready for pickup: {response.status_code}")
        print(f"Response: {response.text}")
        return False
    
    def rider_accept_delivery(self):
        """Step 4: Rider accepts the delivery"""
        print(f"\n{'='*50}")
        print("STEP 4: Rider accepts delivery")
        print(f"{'='*50}")
        
        if not self.delivery_id:
            print("✗ No delivery ID available")
            return False
        
        response = self.rider_session.post(
            f"{BASE_URL}/rider/pickup/api/accept-delivery",
            json={'delivery_id': self.delivery_id}
        )
        
        if response.status_code == 200:
            data = response.json()
            if data.get('success'):
                print(f"✓ Delivery accepted by rider!")
                time.sleep(1)
                return True
        
        print(f"✗ Failed to accept delivery: {response.status_code}")
        print(f"Response: {response.text}")
        return False
    
    def rider_pickup_from_seller(self):
        """Step 5: Rider picks up package from seller"""
        print(f"\n{'='*50}")
        print("STEP 5: Rider picks up from seller")
        print(f"{'='*50}")
        
        if not self.delivery_id:
            print("✗ No delivery ID available")
            return False
        
        response = self.rider_session.post(
            f"{BASE_URL}/rider/active-delivery/api/pickup-package",
            json={'delivery_id': self.delivery_id}
        )
        
        if response.status_code == 200:
            data = response.json()
            if data.get('success'):
                print(f"✓ Package picked up from seller!")
                time.sleep(1)
                return True
        
        print(f"✗ Failed to pickup package: {response.status_code}")
        print(f"Response: {response.text}")
        return False
    
    def rider_deliver_to_buyer(self):
        """Step 6: Rider delivers package to buyer"""
        print(f"\n{'='*50}")
        print("STEP 6: Rider delivers to buyer")
        print(f"{'='*50}")
        
        if not self.delivery_id:
            print("✗ No delivery ID available")
            return False
        
        response = self.rider_session.post(
            f"{BASE_URL}/rider/active-delivery/api/complete-delivery",
            json={'delivery_id': self.delivery_id}
        )
        
        if response.status_code == 200:
            data = response.json()
            if data.get('success'):
                print(f"✓ Package delivered to buyer!")
                time.sleep(1)
                return True
        
        print(f"✗ Failed to deliver package: {response.status_code}")
        print(f"Response: {response.text}")
        return False
    
    def verify_order_status(self):
        """Step 7: Verify final order status"""
        print(f"\n{'='*50}")
        print("STEP 7: Verify order completion")
        print(f"{'='*50}")
        
        if not self.order_id:
            print("✗ No order ID available")
            return False
        
        # Check from buyer's perspective
        response = self.buyer_session.get(
            f"{BASE_URL}/myAccount/purchases/api/orders"
        )
        
        if response.status_code == 200:
            data = response.json()
            orders = data.get('orders', [])
            
            for order in orders:
                if order.get('order_id') == self.order_id:
                    status = order.get('order_status')
                    print(f"✓ Order status: {status}")
                    
                    if status == 'delivered':
                        print(f"✓ Order completed successfully!")
                        return True
                    else:
                        print(f"⚠ Order status is '{status}', expected 'delivered'")
                        return False
        
        print(f"✗ Failed to verify order status")
        return False
    
    def run_full_test(self):
        """Run the complete order flow test"""
        print("\n" + "="*50)
        print("STARTING ORDER FLOW TEST")
        print("="*50)
        
        # Login all users
        if not self.login_user(self.buyer_session, BUYER_EMAIL, BUYER_PASSWORD, "Buyer"):
            return False
        
        if not self.login_user(self.seller_session, SELLER_EMAIL, SELLER_PASSWORD, "Seller"):
            return False
        
        if not self.login_user(self.rider_session, RIDER_EMAIL, RIDER_PASSWORD, "Rider"):
            return False
        
        # Run test steps
        steps = [
            ("Place Order", self.buyer_place_order),
            ("Prepare Package", self.seller_prepare_package),
            ("Ready for Pickup", self.seller_ready_for_pickup),
            ("Accept Delivery", self.rider_accept_delivery),
            ("Pickup from Seller", self.rider_pickup_from_seller),
            ("Deliver to Buyer", self.rider_deliver_to_buyer),
            ("Verify Completion", self.verify_order_status)
        ]
        
        for step_name, step_func in steps:
            if not step_func():
                print(f"\n{'='*50}")
                print(f"TEST FAILED at step: {step_name}")
                print(f"{'='*50}")
                return False
            time.sleep(2)  # Wait between steps
        
        print(f"\n{'='*50}")
        print("✓ ALL TESTS PASSED!")
        print(f"{'='*50}")
        return True


if __name__ == "__main__":
    print("\n" + "="*50)
    print("VELARE ORDER FLOW TEST")
    print("="*50)
    print("\nThis script will test the complete order flow:")
    print("1. Buyer places order")
    print("2. Seller prepares package")
    print("3. Seller marks ready for pickup")
    print("4. Rider accepts delivery")
    print("5. Rider picks up from seller")
    print("6. Rider delivers to buyer")
    print("7. Verify order completion")
    print("\nMake sure:")
    print("- Flask server is running on http://127.0.0.1:5000")
    print("- Test users exist with correct credentials")
    print("- Buyer has items in cart")
    print("- Buyer has a delivery address")
    
    print("\nStarting test in 2 seconds...")
    time.sleep(2)
    
    tester = OrderFlowTester()
    tester.run_full_test()
