-- ============================================
-- VELARE ECOMMERCE DATABASE
-- Simplified & Tailored for Actual System
-- ============================================

DROP DATABASE IF EXISTS velare_ecommerce;
CREATE DATABASE velare_ecommerce;
USE velare_ecommerce;

-- ============================================
-- USERS & AUTHENTICATION
-- ============================================

CREATE TABLE users (
    user_id INT PRIMARY KEY AUTO_INCREMENT,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    user_type ENUM('buyer', 'seller', 'rider', 'admin') NOT NULL,
    status ENUM('active', 'pending', 'suspended', 'banned') DEFAULT 'active',
    reset_token VARCHAR(255) NULL,
    reset_token_expiry TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP NULL,
    INDEX idx_email (email),
    INDEX idx_user_type (user_type),
    INDEX idx_status (status),
    INDEX idx_reset_token (reset_token)
);

-- Buyer Profiles
CREATE TABLE buyers (
    buyer_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT UNIQUE NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    gender ENUM('Male', 'Female', 'Other') NULL,
    phone_number VARCHAR(20),
    id_type VARCHAR(50),
    id_file_path VARCHAR(255),
    profile_image VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Seller Profiles
CREATE TABLE sellers (
    seller_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT UNIQUE NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    shop_name VARCHAR(255) NOT NULL,
    shop_description TEXT,
    shop_logo VARCHAR(255),
    phone_number VARCHAR(20),
    id_type VARCHAR(50),
    id_file_path VARCHAR(255),
    rating DECIMAL(3,2) DEFAULT 0.00,
    total_sales DECIMAL(12,2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    INDEX idx_shop_name (shop_name)
);

-- Rider Profiles
CREATE TABLE riders (
    rider_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT UNIQUE NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone_number VARCHAR(20) NOT NULL,
    profile_image VARCHAR(255),
    vehicle_type VARCHAR(50),
    id_type VARCHAR(50),
    id_file_path VARCHAR(255),
    rating DECIMAL(3,2) DEFAULT 0.00,
    total_earnings DECIMAL(10,2) DEFAULT 0.00,
    status ENUM('available', 'busy', 'offline') DEFAULT 'offline',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    INDEX idx_status (status)
);

-- Admin Profiles
CREATE TABLE admins (
    admin_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT UNIQUE NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- ============================================
-- ADDRESSES
-- ============================================

CREATE TABLE addresses (
    address_id INT PRIMARY KEY AUTO_INCREMENT,
    user_type ENUM('buyer', 'seller', 'rider') NOT NULL,
    user_ref_id INT NOT NULL,
    recipient_name VARCHAR(200) NULL,
    phone_number VARCHAR(20) NULL,
    full_address TEXT NOT NULL,
    region VARCHAR(100),
    province VARCHAR(100),
    city VARCHAR(100),
    barangay VARCHAR(100),
    street_name VARCHAR(200),
    house_number VARCHAR(50),
    postal_code VARCHAR(20),
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_type (user_type),
    INDEX idx_user_ref_id (user_ref_id),
    INDEX idx_is_default (is_default)
);

-- ============================================
-- PRODUCTS
-- ============================================

CREATE TABLE products (
    product_id INT PRIMARY KEY AUTO_INCREMENT,
    seller_id INT NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    description TEXT,
    materials TEXT,
    SDG ENUM('handmade', 'biodegradable', 'both') NULL,
    price DECIMAL(10,2) NOT NULL,
    category VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    views_count INT DEFAULT 0,
    rating DECIMAL(3,2) DEFAULT 0.00,
    total_reviews INT DEFAULT 0,
    total_sold INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (seller_id) REFERENCES sellers(seller_id) ON DELETE CASCADE,
    INDEX idx_seller_id (seller_id),
    INDEX idx_category (category),
    INDEX idx_product_name (product_name)
);

-- Product Variants (Color, Size)
CREATE TABLE product_variants (
    variant_id INT PRIMARY KEY AUTO_INCREMENT,
    product_id INT NOT NULL,
    color VARCHAR(50),
    hex_code VARCHAR(7),
    size VARCHAR(20),
    stock_quantity INT DEFAULT 0,
    image_url VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
    INDEX idx_product_id (product_id),
    INDEX idx_image_url (image_url)
);

-- Product Images
CREATE TABLE product_images (
    image_id INT PRIMARY KEY AUTO_INCREMENT,
    product_id INT NOT NULL,
    variant_id INT NULL,
    image_url VARCHAR(255) NOT NULL,
    is_primary BOOLEAN DEFAULT FALSE,
    display_order INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
    FOREIGN KEY (variant_id) REFERENCES product_variants(variant_id) ON DELETE CASCADE,
    INDEX idx_product_id (product_id),
    INDEX idx_variant_id (variant_id)
);

-- ============================================
-- CART & FAVORITES
-- ============================================

CREATE TABLE cart (
    cart_id INT PRIMARY KEY AUTO_INCREMENT,
    buyer_id INT NOT NULL,
    product_id INT NOT NULL,
    variant_id INT NULL,
    quantity INT NOT NULL DEFAULT 1,
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (buyer_id) REFERENCES buyers(buyer_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
    FOREIGN KEY (variant_id) REFERENCES product_variants(variant_id) ON DELETE SET NULL,
    INDEX idx_buyer_id (buyer_id)
);

CREATE TABLE favorites (
    favorite_id INT PRIMARY KEY AUTO_INCREMENT,
    buyer_id INT NOT NULL,
    product_id INT NOT NULL,
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (buyer_id) REFERENCES buyers(buyer_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
    UNIQUE KEY unique_favorite (buyer_id, product_id),
    INDEX idx_buyer_id (buyer_id)
);

-- ============================================
-- VOUCHERS
-- ============================================

CREATE TABLE vouchers (
    voucher_id INT PRIMARY KEY AUTO_INCREMENT,
    voucher_code VARCHAR(50) UNIQUE NOT NULL,
    voucher_name VARCHAR(255) NOT NULL,
    voucher_type ENUM('free_shipping', 'discount') NOT NULL,
    discount_percent INT DEFAULT 0,
    description TEXT,
    restriction VARCHAR(255),
    is_active BOOLEAN DEFAULT TRUE,
    start_date TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    end_date TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_voucher_code (voucher_code),
    INDEX idx_is_active (is_active)
);

CREATE TABLE buyer_vouchers (
    buyer_voucher_id INT PRIMARY KEY AUTO_INCREMENT,
    buyer_id INT NOT NULL,
    voucher_id INT NOT NULL,
    is_used BOOLEAN DEFAULT FALSE,
    used_at TIMESTAMP NULL,
    claimed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (buyer_id) REFERENCES buyers(buyer_id) ON DELETE CASCADE,
    FOREIGN KEY (voucher_id) REFERENCES vouchers(voucher_id) ON DELETE CASCADE,
    INDEX idx_buyer_id (buyer_id)
);

-- ============================================
-- ORDERS
-- ============================================

CREATE TABLE orders (
    order_id INT PRIMARY KEY AUTO_INCREMENT,
    order_number VARCHAR(50) UNIQUE NOT NULL,
    buyer_id INT NOT NULL,
    seller_id INT NOT NULL,
    address_id INT NOT NULL,
    subtotal DECIMAL(10,2) NOT NULL,
    shipping_fee DECIMAL(10,2) DEFAULT 0.00,
    discount_amount DECIMAL(10,2) DEFAULT 0.00,
    total_amount DECIMAL(10,2) NOT NULL,
    commission_amount DECIMAL(10,2) DEFAULT 0.00,
    voucher_id INT NULL,
    order_status ENUM('pending', 'in_transit', 'delivered', 'cancelled') DEFAULT 'pending',
    order_received BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (buyer_id) REFERENCES buyers(buyer_id) ON DELETE RESTRICT,
    FOREIGN KEY (seller_id) REFERENCES sellers(seller_id) ON DELETE RESTRICT,
    FOREIGN KEY (address_id) REFERENCES addresses(address_id) ON DELETE RESTRICT,
    FOREIGN KEY (voucher_id) REFERENCES vouchers(voucher_id) ON DELETE SET NULL,
    INDEX idx_order_number (order_number),
    INDEX idx_buyer_id (buyer_id),
    INDEX idx_seller_id (seller_id),
    INDEX idx_order_status (order_status),
    INDEX idx_created_at (created_at)
);

CREATE TABLE order_items (
    order_item_id INT PRIMARY KEY AUTO_INCREMENT,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    materials TEXT,
    variant_color VARCHAR(50),
    variant_size VARCHAR(20),
    quantity INT NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE RESTRICT,
    INDEX idx_order_id (order_id),
    INDEX idx_product_id (product_id)
);

-- ============================================
-- DELIVERIES
-- ============================================

CREATE TABLE deliveries (
    delivery_id INT PRIMARY KEY AUTO_INCREMENT,
    order_id INT NOT NULL,
    rider_id INT NULL,
    pickup_address TEXT NOT NULL,
    delivery_address TEXT NOT NULL,
    delivery_fee DECIMAL(10,2) NOT NULL,
    rider_earnings DECIMAL(10,2) DEFAULT 0.00,
    status ENUM('preparing', 'pending', 'assigned', 'picked_up', 'in_transit', 'delivered', 'cancelled') DEFAULT NULL,
    assigned_at TIMESTAMP NULL,
    picked_up_at TIMESTAMP NULL,
    delivered_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (rider_id) REFERENCES riders(rider_id) ON DELETE SET NULL,
    INDEX idx_order_id (order_id),
    INDEX idx_rider_id (rider_id),
    INDEX idx_status (status)
);

-- ============================================
-- REVIEWS
-- ============================================

CREATE TABLE product_reviews (
    review_id INT PRIMARY KEY AUTO_INCREMENT,
    product_id INT NOT NULL,
    buyer_id INT NOT NULL,
    order_id INT NOT NULL,
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    review_text TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
    FOREIGN KEY (buyer_id) REFERENCES buyers(buyer_id) ON DELETE CASCADE,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    INDEX idx_product_id (product_id),
    INDEX idx_buyer_id (buyer_id)
);

CREATE TABLE review_images (
    review_image_id INT PRIMARY KEY AUTO_INCREMENT,
    review_id INT NOT NULL,
    image_url VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (review_id) REFERENCES product_reviews(review_id) ON DELETE CASCADE,
    INDEX idx_review_id (review_id)
);

-- ============================================
-- MESSAGING
-- ============================================

-- Conversations (supports buyer-seller, buyer-rider, and 3-way chats)
CREATE TABLE conversations (
    conversation_id INT PRIMARY KEY AUTO_INCREMENT,
    buyer_id INT NOT NULL,
    seller_id INT NULL,
    rider_id INT NULL,
    delivery_id INT NULL,
    last_message TEXT,
    buyer_unread_count INT DEFAULT 0,
    seller_unread_count INT DEFAULT 0,
    rider_unread_count INT DEFAULT 0,
    last_message_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (buyer_id) REFERENCES buyers(buyer_id) ON DELETE CASCADE,
    FOREIGN KEY (seller_id) REFERENCES sellers(seller_id) ON DELETE CASCADE,
    FOREIGN KEY (rider_id) REFERENCES riders(rider_id) ON DELETE CASCADE,
    FOREIGN KEY (delivery_id) REFERENCES deliveries(delivery_id) ON DELETE CASCADE,
    UNIQUE KEY unique_buyer_seller (buyer_id, seller_id, delivery_id),
    UNIQUE KEY unique_buyer_rider_delivery (buyer_id, rider_id, delivery_id),
    INDEX idx_buyer_id (buyer_id),
    INDEX idx_seller_id (seller_id),
    INDEX idx_rider_id (rider_id),
    INDEX idx_delivery_id (delivery_id),
    INDEX idx_last_message_at (last_message_at)
);

CREATE TABLE messages (
    message_id INT PRIMARY KEY AUTO_INCREMENT,
    conversation_id INT NOT NULL,
    sender_id INT NOT NULL,
    sender_type ENUM('buyer', 'seller', 'rider') NOT NULL,
    message_text TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (conversation_id) REFERENCES conversations(conversation_id) ON DELETE CASCADE,
    FOREIGN KEY (sender_id) REFERENCES users(user_id) ON DELETE CASCADE,
    INDEX idx_conversation_id (conversation_id),
    INDEX idx_sender_id (sender_id),
    INDEX idx_sender_type (sender_type),
    INDEX idx_is_read (is_read),
    INDEX idx_created_at (created_at)
);

-- ============================================
-- NOTIFICATIONS
-- ============================================

CREATE TABLE notifications (
    notification_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    notification_type ENUM('order', 'delivery', 'product', 'message', 'system') NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_is_read (is_read),
    INDEX idx_created_at (created_at)
);

-- ============================================
-- DEFAULT DATA
-- ============================================

-- Insert default admin
INSERT INTO users (email, password, user_type, status) 
VALUES ('admin@velare.com', 'admin123', 'admin', 'active');

INSERT INTO admins (user_id, first_name, last_name) 
VALUES (LAST_INSERT_ID(), 'Admin', 'Velare');

-- Insert default vouchers
INSERT INTO vouchers (voucher_code, voucher_name, voucher_type, discount_percent, description, restriction, is_active, start_date, end_date)
VALUES 
('FREESHIP', 'Free Shipping', 'free_shipping', 0, 'Get free shipping on your order', 'None', TRUE, CURRENT_TIMESTAMP, DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 1 YEAR)),
('DISCOUNT20', 'All Items Discount', 'discount', 20, 'Get 20% off on any product', 'New Users Only', TRUE, CURRENT_TIMESTAMP, DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 1 YEAR));

-- ============================================
-- TRIGGERS
-- ============================================

DELIMITER //

-- Update product rating after review
CREATE TRIGGER update_product_rating_after_review
AFTER INSERT ON product_reviews
FOR EACH ROW
BEGIN
    UPDATE products p
    SET 
        rating = (SELECT AVG(rating) FROM product_reviews WHERE product_id = NEW.product_id),
        total_reviews = (SELECT COUNT(*) FROM product_reviews WHERE product_id = NEW.product_id)
    WHERE product_id = NEW.product_id;
END //

-- Update seller rating after review
CREATE TRIGGER update_seller_rating_after_review
AFTER INSERT ON product_reviews
FOR EACH ROW
BEGIN
    UPDATE sellers s
    SET rating = (
        SELECT AVG(pr.rating) 
        FROM product_reviews pr
        JOIN products p ON pr.product_id = p.product_id
        WHERE p.seller_id = (SELECT seller_id FROM products WHERE product_id = NEW.product_id)
    )
    WHERE seller_id = (SELECT seller_id FROM products WHERE product_id = NEW.product_id);
END //

DELIMITER ;

-- ============================================
-- VIEWS FOR REPORTING
-- ============================================

-- Sales Report View
CREATE VIEW view_sales_report AS
SELECT 
    o.order_id,
    o.order_number,
    o.created_at as order_date,
    CONCAT(b.first_name, ' ', b.last_name) as buyer_name,
    s.shop_name,
    o.total_amount,
    o.commission_amount,
    o.order_status
FROM orders o
JOIN buyers b ON o.buyer_id = b.buyer_id
JOIN sellers s ON o.seller_id = s.seller_id;

-- Product Performance View
CREATE VIEW view_product_performance AS
SELECT 
    p.product_id,
    p.product_name,
    s.shop_name,
    p.category,
    p.price,
    p.views_count,
    p.rating,
    p.total_reviews,
    p.total_sold,
    p.approval_status
FROM products p
JOIN sellers s ON p.seller_id = s.seller_id;

-- ============================================
-- END OF DATABASE SCHEMA
-- ============================================
