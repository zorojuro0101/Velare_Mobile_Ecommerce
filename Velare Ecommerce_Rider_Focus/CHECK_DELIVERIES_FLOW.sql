-- ============================================
-- CHECK DELIVERIES TABLE STRUCTURE AND FLOW
-- ============================================

-- 1. Check deliveries table structure
SELECT 
    column_name,
    data_type,
    column_default,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'deliveries'
ORDER BY ordinal_position;

-- 2. Check recent deliveries with all status transitions
SELECT 
    d.delivery_id,
    d.order_id,
    d.rider_id,
    d.status,
    d.delivery_fee,
    d.rider_earnings,
    d.assigned_at,
    d.picked_up_at,
    d.delivered_at,
    d.completed_at,
    o.order_number,
    o.order_status,
    r.first_name as rider_name
FROM deliveries d
LEFT JOIN orders o ON d.order_id = o.order_id
LEFT JOIN riders r ON d.rider_id = r.rider_id
ORDER BY d.created_at DESC
LIMIT 10;

-- 3. Check orders table structure
SELECT 
    column_name,
    data_type,
    column_default,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'orders'
ORDER BY ordinal_position;

-- 4. Check if there are any constraints or triggers on deliveries
SELECT 
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(oid) as definition
FROM pg_constraint
WHERE conrelid = 'deliveries'::regclass;
