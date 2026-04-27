-- ============================================
-- CHECK RIDER_WITHDRAWALS TABLE STRUCTURE
-- ============================================

-- 1. Check if table exists and view its structure
SELECT 
    column_name,
    data_type,
    character_maximum_length,
    column_default,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'rider_withdrawals'
ORDER BY ordinal_position;

-- ============================================
-- 2. View all withdrawals with rider info
-- ============================================
SELECT 
    rw.*,
    r.first_name,
    r.last_name,
    u.email
FROM rider_withdrawals rw
JOIN riders r ON rw.rider_id = r.rider_id
JOIN users u ON r.user_id = u.user_id
ORDER BY rw.requested_at DESC
LIMIT 10;

-- ============================================
-- 3. Check column names specifically
-- ============================================
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'rider_withdrawals'
ORDER BY ordinal_position;

-- ============================================
-- 4. View sample data (first 5 rows)
-- ============================================
SELECT * FROM rider_withdrawals 
ORDER BY requested_at DESC 
LIMIT 5;
