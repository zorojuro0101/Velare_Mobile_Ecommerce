-- ============================================
-- VELARE ECOMMERCE - COMPLETE SUPABASE SCHEMA
-- ============================================
-- Run this in Supabase SQL Editor to create all tables

-- ============================================
-- 1. USERS TABLE (Main authentication)
-- ============================================
CREATE TABLE users (
    user_id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    user_type VARCHAR(50) NOT NULL CHECK (user_type IN ('buyer', 'seller', 'rider', 'admin')),
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('active', 'pending', 'suspended', 'banned')),
    reset_token VARCHAR(255),
    reset_token_expiry TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    last_login TIMESTAMP
);

-- ============================================
-- 2. BUYERS TABLE
-- ============================================
CREATE TABLE buyers (
    buyer_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT UNIQUE NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    gender VARCHAR(20),
    phone_number VARCHAR(50),
    id_type VARCHAR(50),
    id_file_path VARCHAR(500),
    profile_image VARCHAR(500),
    account_status VARCHAR(50) DEFAULT 'active',
    suspension_end TIMESTAMP,
    suspension_reason TEXT,
    report_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- 3. SELLERS TABLE
-- ============================================
CREATE TABLE sellers (
    seller_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT UNIQUE NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    shop_name VARCHAR(255) NOT NULL,
    shop_description TEXT,
    shop_logo VARCHAR(500),
    phone_number VARCHAR(50),
    id_type VARCHAR(50),
    id_file_path VARCHAR(500),
    business_permit_file_path VARCHAR(500),
    rating DECIMAL(3,2) DEFAULT 0.00,
    total_sales DECIMAL(10,2) DEFAULT 0.00,
    account_status VARCHAR(50) DEFAULT 'active',
    suspension_end TIMESTAMP,
    suspension_reason TEXT,
    report_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- 4. RIDERS TABLE
-- ============================================
CREATE TABLE riders (
    rider_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT UNIQUE NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone_number VARCHAR(50) NOT NULL,
    profile_image VARCHAR(500),
    vehicle_type VARCHAR(50),
    id_type VARCHAR(50),
    id_file_path VARCHAR(500),
    orcr_file_path VARCHAR(500),
    driver_license_file_path VARCHAR(500),
    plate_number VARCHAR(50),
    rating DECIMAL(3,2) DEFAULT 0.00,
    total_earnings DECIMAL(10,2) DEFAULT 0.00,
    available_balance DECIMAL(10,2) DEFAULT 0.00,
    status VARCHAR(50) DEFAULT 'offline',
    account_status VARCHAR(50) DEFAULT 'active',
    suspension_end TIMESTAMP,
    suspension_reason TEXT,
    report_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- 5. ADMINS TABLE
-- ============================================
CREATE TABLE admins (
    admin_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT UNIQUE NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- 6. ADDRESSES TABLE
-- ============================================
CREATE TABLE addresses (
    address_id BIGSERIAL PRIMARY KEY,
    user_type VARCHAR(50) NOT NULL,
    user_ref_id BIGINT NOT NULL,
    recipient_name VARCHAR(255),
    phone_number VARCHAR(50),
    full_address TEXT NOT NULL,
    region VARCHAR(100),
    province VARCHAR(100),
    city VARCHAR(100),
    barangay VARCHAR(100),
    street_name VARCHAR(255),
    house_number VARCHAR(50),
    postal_code VARCHAR(20),
    is_default BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- 7. PRODUCTS TABLE
-- ============================================
CREATE TABLE products (
    product_id BIGSERIAL PRIMARY KEY,
    seller_id BIGINT NOT NULL REFERENCES sellers(seller_id) ON DELETE CASCADE,
    product_name VARCHAR(255) NOT NULL,
    description TEXT,
    materials TEXT,
    sdg VARCHAR(100),
    price DECIMAL(10,2) NOT NULL,
    category VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    views_count INT DEFAULT 0,
    rating DECIMAL(3,2) DEFAULT 0.00,
    total_reviews INT DEFAULT 0,
    total_sold INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- 8. PRODUCT VARIANTS TABLE
-- ============================================
CREATE TABLE product_variants (
    variant_id BIGSERIAL PRIMARY KEY,
    product_id BIGINT NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    color VARCHAR(100),
    hex_code VARCHAR(20),
    size VARCHAR(50),
    stock_quantity INT DEFAULT 0,
    image_url VARCHAR(500),
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- 9. PRODUCT IMAGES TABLE
-- ============================================
CREATE TABLE product_images (
    image_id BIGSERIAL PRIMARY KEY,
    product_id BIGINT NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    variant_id BIGINT REFERENCES product_variants(variant_id) ON DELETE CASCADE,
    image_url VARCHAR(500) NOT NULL,
    is_primary BOOLEAN DEFAULT false,
    display_order INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- 10. VOUCHERS TABLE
-- ============================================
CREATE TABLE vouchers (
    voucher_id BIGSERIAL PRIMARY KEY,
    voucher_code VARCHAR(50) UNIQUE NOT NULL,
    voucher_name VARCHAR(255) NOT NULL,
    voucher_type VARCHAR(50) NOT NULL,
    discount_percent INT DEFAULT 0,
    description TEXT,
    restriction VARCHAR(255),
    is_active BOOLEAN DEFAULT true,
    start_date TIMESTAMP DEFAULT NOW(),
    end_date TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- 11. BUYER VOUCHERS TABLE
-- ============================================
CREATE TABLE buyer_vouchers (
    buyer_voucher_id BIGSERIAL PRIMARY KEY,
    buyer_id BIGINT NOT NULL REFERENCES buyers(buyer_id) ON DELETE CASCADE,
    voucher_id BIGINT NOT NULL REFERENCES vouchers(voucher_id) ON DELETE CASCADE,
    is_used BOOLEAN DEFAULT false,
    times_remaining INT DEFAULT 1,
    used_at TIMESTAMP,
    claimed_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- 12. SELLER VOUCHERS TABLE
-- ============================================
CREATE TABLE seller_vouchers (
    seller_voucher_id BIGSERIAL PRIMARY KEY,
    seller_id BIGINT NOT NULL REFERENCES sellers(seller_id) ON DELETE CASCADE,
    voucher_id BIGINT NOT NULL REFERENCES vouchers(voucher_id) ON DELETE CASCADE,
    is_active BOOLEAN DEFAULT true,
    selected_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- 13. ORDERS TABLE
-- ============================================
CREATE TABLE orders (
    order_id BIGSERIAL PRIMARY KEY,
    order_number VARCHAR(100) UNIQUE NOT NULL,
    buyer_id BIGINT NOT NULL REFERENCES buyers(buyer_id),
    seller_id BIGINT NOT NULL REFERENCES sellers(seller_id),
    address_id BIGINT NOT NULL REFERENCES addresses(address_id),
    subtotal DECIMAL(10,2) NOT NULL,
    shipping_fee DECIMAL(10,2) DEFAULT 0.00,
    discount_amount DECIMAL(10,2) DEFAULT 0.00,
    total_amount DECIMAL(10,2) NOT NULL,
    commission_amount DECIMAL(10,2) DEFAULT 0.00,
    voucher_id BIGINT REFERENCES vouchers(voucher_id),
    order_status VARCHAR(50) DEFAULT 'pending',
    order_received BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- 14. ORDER ITEMS TABLE
-- ============================================
CREATE TABLE order_items (
    order_item_id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL REFERENCES products(product_id),
    product_name VARCHAR(255) NOT NULL,
    materials TEXT,
    variant_color VARCHAR(100),
    variant_size VARCHAR(50),
    quantity INT NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- 15. DELIVERIES TABLE
-- ============================================
CREATE TABLE deliveries (
    delivery_id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES orders(order_id),
    rider_id BIGINT REFERENCES riders(rider_id),
    pickup_address TEXT NOT NULL,
    delivery_address TEXT NOT NULL,
    delivery_fee DECIMAL(10,2) NOT NULL,
    rider_earnings DECIMAL(10,2) DEFAULT 0.00,
    paid_by_platform BOOLEAN DEFAULT false,
    status VARCHAR(50),
    assigned_at TIMESTAMP,
    picked_up_at TIMESTAMP,
    delivered_at TIMESTAMP,
    completed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- 16. CART TABLE
-- ============================================
CREATE TABLE cart (
    cart_id BIGSERIAL PRIMARY KEY,
    buyer_id BIGINT NOT NULL REFERENCES buyers(buyer_id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    variant_id BIGINT REFERENCES product_variants(variant_id) ON DELETE CASCADE,
    quantity INT NOT NULL DEFAULT 1,
    added_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- 17. FAVORITES TABLE
-- ============================================
CREATE TABLE favorites (
    favorite_id BIGSERIAL PRIMARY KEY,
    buyer_id BIGINT NOT NULL REFERENCES buyers(buyer_id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    added_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- 18. PRODUCT REVIEWS TABLE
-- ============================================
CREATE TABLE product_reviews (
    review_id BIGSERIAL PRIMARY KEY,
    product_id BIGINT NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    buyer_id BIGINT NOT NULL REFERENCES buyers(buyer_id),
    order_id BIGINT NOT NULL REFERENCES orders(order_id),
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    review_text TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- 19. REVIEW IMAGES TABLE
-- ============================================
CREATE TABLE review_images (
    review_image_id BIGSERIAL PRIMARY KEY,
    review_id BIGINT NOT NULL REFERENCES product_reviews(review_id) ON DELETE CASCADE,
    image_url VARCHAR(500) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- 20. CONVERSATIONS TABLE
-- ============================================
CREATE TABLE conversations (
    conversation_id BIGSERIAL PRIMARY KEY,
    buyer_id BIGINT NOT NULL REFERENCES buyers(buyer_id),
    seller_id BIGINT REFERENCES sellers(seller_id),
    rider_id BIGINT REFERENCES riders(rider_id),
    delivery_id BIGINT REFERENCES deliveries(delivery_id),
    last_message TEXT,
    buyer_unread_count INT DEFAULT 0,
    seller_unread_count INT DEFAULT 0,
    rider_unread_count INT DEFAULT 0,
    last_message_at TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- 21. MESSAGES TABLE
-- ============================================
CREATE TABLE messages (
    message_id BIGSERIAL PRIMARY KEY,
    conversation_id BIGINT NOT NULL REFERENCES conversations(conversation_id) ON DELETE CASCADE,
    sender_id BIGINT NOT NULL,
    sender_type VARCHAR(50) NOT NULL,
    message_text TEXT NOT NULL,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- 22. NOTIFICATIONS TABLE
-- ============================================
CREATE TABLE notifications (
    notification_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    notification_type VARCHAR(50) NOT NULL,
    is_read BOOLEAN DEFAULT false,
    order_id BIGINT REFERENCES orders(order_id),
    product_names TEXT,
    product_images TEXT,
    order_total DECIMAL(10,2),
    formatted_date VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- 23. USER REPORTS TABLE
-- ============================================
CREATE TABLE user_reports (
    report_id BIGSERIAL PRIMARY KEY,
    reporter_id BIGINT NOT NULL REFERENCES users(user_id),
    reporter_type VARCHAR(50) NOT NULL,
    reported_user_id BIGINT NOT NULL REFERENCES users(user_id),
    reported_user_type VARCHAR(50) NOT NULL,
    report_category VARCHAR(100) NOT NULL,
    report_reason TEXT NOT NULL,
    order_id BIGINT REFERENCES orders(order_id),
    delivery_id BIGINT REFERENCES deliveries(delivery_id),
    evidence_image VARCHAR(500),
    status VARCHAR(50) DEFAULT 'pending',
    admin_notes TEXT,
    admin_id BIGINT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    resolved_at TIMESTAMP
);

-- ============================================
-- 24. RIDER WITHDRAWALS TABLE
-- ============================================
CREATE TABLE rider_withdrawals (
    withdrawal_id BIGSERIAL PRIMARY KEY,
    rider_id BIGINT NOT NULL REFERENCES riders(rider_id) ON DELETE CASCADE,
    amount DECIMAL(10,2) NOT NULL,
    withdrawal_method VARCHAR(50) DEFAULT 'Cash',
    status VARCHAR(50) DEFAULT 'pending',
    requested_at TIMESTAMP DEFAULT NOW(),
    processed_at TIMESTAMP,
    notes TEXT
);

-- ============================================
-- ENABLE ROW LEVEL SECURITY (RLS)
-- ============================================
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE buyers ENABLE ROW LEVEL SECURITY;
ALTER TABLE sellers ENABLE ROW LEVEL SECURITY;
ALTER TABLE riders ENABLE ROW LEVEL SECURITY;
ALTER TABLE admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE vouchers ENABLE ROW LEVEL SECURITY;
ALTER TABLE buyer_vouchers ENABLE ROW LEVEL SECURITY;
ALTER TABLE seller_vouchers ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE cart ENABLE ROW LEVEL SECURITY;
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE review_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE rider_withdrawals ENABLE ROW LEVEL SECURITY;

-- ============================================
-- CREATE POLICIES (Allow all for development)
-- ============================================
CREATE POLICY "Allow all" ON users FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON buyers FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON sellers FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON riders FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON admins FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON addresses FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON products FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON product_variants FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON product_images FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON vouchers FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON buyer_vouchers FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON seller_vouchers FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON orders FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON order_items FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON deliveries FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON cart FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON favorites FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON product_reviews FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON review_images FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON conversations FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON messages FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON notifications FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON user_reports FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON rider_withdrawals FOR ALL USING (true) WITH CHECK (true);
