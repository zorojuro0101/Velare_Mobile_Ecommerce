-- ============================================
-- RIDER 4 CHAT QUERIES
-- ============================================

-- 1. Get all deliveries for rider_id 4
SELECT 
    d.delivery_id,
    d.order_id,
    d.status,
    d.delivery_address,
    d.assigned_at,
    d.delivered_at,
    o.order_number,
    o.buyer_id,
    o.seller_id,
    o.created_at,
    b.first_name as buyer_first_name,
    b.last_name as buyer_last_name,
    b.profile_image as buyer_avatar,
    b.phone_number as buyer_phone,
    s.shop_name,
    s.first_name as seller_first_name,
    s.last_name as seller_last_name,
    s.shop_logo,
    s.phone_number as seller_phone
FROM deliveries d
INNER JOIN orders o ON d.order_id = o.order_id
LEFT JOIN buyers b ON o.buyer_id = b.buyer_id
LEFT JOIN sellers s ON o.seller_id = s.seller_id
WHERE d.rider_id = 4
  AND d.status IN ('assigned', 'in_transit', 'delivered')
ORDER BY d.assigned_at DESC;

-- ============================================
-- 2. Group by BUYER_ID (Profile-based conversations)
-- ============================================

-- Expected BUYER conversations for rider_id 4:
SELECT 
    o.buyer_id,
    b.first_name || ' ' || b.last_name as buyer_name,
    b.profile_image as buyer_avatar,
    b.phone_number as buyer_phone,
    COUNT(*) as total_deliveries,
    COUNT(CASE WHEN d.status IN ('assigned', 'in_transit') THEN 1 END) as active_deliveries,
    COUNT(CASE WHEN d.status = 'delivered' THEN 1 END) as delivered_count,
    STRING_AGG(
        CASE 
            WHEN d.status = 'assigned' THEN '📦 ' || o.order_number
            WHEN d.status = 'in_transit' THEN '🚚 ' || o.order_number
            WHEN d.status = 'delivered' THEN '✅ ' || o.order_number
        END, 
        ' • ' 
        ORDER BY d.assigned_at DESC
    ) as context_message
FROM deliveries d
INNER JOIN orders o ON d.order_id = o.order_id
INNER JOIN buyers b ON o.buyer_id = b.buyer_id
WHERE d.rider_id = 4
  AND d.status IN ('assigned', 'in_transit', 'delivered')
GROUP BY o.buyer_id, b.first_name, b.last_name, b.profile_image, b.phone_number
ORDER BY MAX(d.assigned_at) DESC;

-- ============================================
-- 3. Group by SELLER_ID (Profile-based conversations)
-- ============================================

-- Expected SELLER conversations for rider_id 4:
SELECT 
    o.seller_id,
    s.shop_name,
    s.first_name || ' ' || s.last_name as seller_name,
    s.shop_logo,
    s.phone_number as seller_phone,
    COUNT(*) as total_deliveries,
    COUNT(CASE WHEN d.status IN ('assigned', 'in_transit') THEN 1 END) as active_deliveries,
    COUNT(CASE WHEN d.status = 'delivered' THEN 1 END) as delivered_count,
    STRING_AGG(
        CASE 
            WHEN d.status = 'assigned' THEN '📦 ' || o.order_number
            WHEN d.status = 'in_transit' THEN '🚚 ' || o.order_number
            WHEN d.status = 'delivered' THEN '✅ ' || o.order_number
        END, 
        ' • ' 
        ORDER BY d.assigned_at DESC
    ) as context_message
FROM deliveries d
INNER JOIN orders o ON d.order_id = o.order_id
INNER JOIN sellers s ON o.seller_id = s.seller_id
WHERE d.rider_id = 4
  AND d.status IN ('assigned', 'in_transit', 'delivered')
GROUP BY o.seller_id, s.shop_name, s.first_name, s.last_name, s.shop_logo, s.phone_number
ORDER BY MAX(d.assigned_at) DESC;

-- ============================================
-- 4. Get existing conversations for rider_id 4
-- ============================================

-- BUYER conversations:
SELECT 
    c.conversation_id,
    c.buyer_id,
    c.seller_id,
    c.rider_id,
    c.delivery_id,
    c.last_message,
    c.last_message_at,
    c.buyer_unread_count,
    c.seller_unread_count,
    c.rider_unread_count,
    b.first_name || ' ' || b.last_name as buyer_name
FROM conversations c
LEFT JOIN buyers b ON c.buyer_id = b.buyer_id
WHERE c.rider_id = 4
  AND c.buyer_id IS NOT NULL
  AND c.seller_id IS NULL
ORDER BY c.last_message_at DESC;

-- SELLER conversations:
SELECT 
    c.conversation_id,
    c.buyer_id,
    c.seller_id,
    c.rider_id,
    c.delivery_id,
    c.last_message,
    c.last_message_at,
    c.buyer_unread_count,
    c.seller_unread_count,
    c.rider_unread_count,
    s.shop_name
FROM conversations c
LEFT JOIN sellers s ON c.seller_id = s.seller_id
WHERE c.rider_id = 4
  AND c.seller_id IS NOT NULL
  AND c.buyer_id IS NULL
ORDER BY c.last_message_at DESC;

-- ============================================
-- 5. Check for duplicate buyer_id 100 issue
-- ============================================

-- This query will show if there are multiple buyers with buyer_id 100
SELECT 
    buyer_id,
    first_name,
    last_name,
    email,
    phone_number,
    COUNT(*) as count
FROM buyers
WHERE buyer_id = 100
GROUP BY buyer_id, first_name, last_name, email, phone_number;

-- ============================================
-- 6. EXPECTED OUTPUT for rider_id 4
-- ============================================

/*
BUYER CONVERSATIONS (Expected):
- buyer_id: 8 (jejeje mon)
  - Active: 📦 VEL-2026-0009, 📦 VEL-2026-0008, 🚚 VEL-2026-0014
  - Context: "📦 VEL-2026-0009 • 📦 VEL-2026-0008 • 🚚 VEL-2026-0014"
  - has_active_orders: true

- buyer_id: 103 (Chauncey Luis Galero)
  - Delivered: ✅ VEL-REV-302
  - Context: "✅ 1 order(s) delivered"
  - has_active_orders: false

- buyer_id: 100 (Lance Lordvin Concio) - ERROR: Multiple rows
  - Need to fix duplicate in database

SELLER CONVERSATIONS (Expected):
- seller_id: 102 (Seta & Stone)
  - Active: 📦 VEL-2026-0009, 📦 VEL-2026-0008, 🚚 VEL-2026-0014
  - Context: "📦 VEL-2026-0009 • 📦 VEL-2026-0008 • 🚚 VEL-2026-0014"
  - has_active_orders: true

- seller_id: 104 (Modern Muse)
  - Delivered: ✅ VEL-2025-0201
  - Context: "✅ 1 order(s) delivered"
  - has_active_orders: false

- seller_id: 100 (Velare Luxe)
  - Delivered: ✅ VEL-REV-302
  - Context: "✅ 1 order(s) delivered"
  - has_active_orders: false

- seller_id: 7 (Justine Mark Gahi's Shop)
  - Delivered: ✅ VEL-2025-0001, ✅ VEL-2025-0003
  - Context: "✅ 2 order(s) delivered"
  - has_active_orders: false
*/

-- ============================================
-- 7. Fix duplicate buyer_id 100 (if needed)
-- ============================================

-- First, check what's in the buyers table for buyer_id 100:
SELECT * FROM buyers WHERE buyer_id = 100;

-- If there are duplicates, you need to decide which one to keep
-- and update the orders table to point to the correct buyer_id

-- ============================================
-- 8. Get messages for a specific conversation
-- ============================================

-- Example: Get messages for buyer_id 103 (Chauncey Luis Galero)
SELECT 
    m.message_id,
    m.conversation_id,
    m.sender_id,
    m.sender_type,
    m.message_text,
    m.is_read,
    m.created_at
FROM messages m
INNER JOIN conversations c ON m.conversation_id = c.conversation_id
WHERE c.rider_id = 4
  AND c.buyer_id = 103
  AND c.seller_id IS NULL
ORDER BY m.created_at ASC;

-- Example: Get messages for seller_id 102 (Seta & Stone)
SELECT 
    m.message_id,
    m.conversation_id,
    m.sender_id,
    m.sender_type,
    m.message_text,
    m.is_read,
    m.created_at
FROM messages m
INNER JOIN conversations c ON m.conversation_id = c.conversation_id
WHERE c.rider_id = 4
  AND c.seller_id = 102
  AND c.buyer_id IS NULL
ORDER BY m.created_at ASC;
