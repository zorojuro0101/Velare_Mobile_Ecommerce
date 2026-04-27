-- ============================================
-- UPDATE BUYER PROFILE IMAGES TO SUPABASE URLs
-- ============================================
-- This script updates buyer profile_image paths from local paths to full Supabase URLs
-- to match the format used by sellers (which already have full Supabase URLs)

-- BEFORE: /static/uploads/profiles/buyer_20_chito.jpg
-- AFTER:  https://lpbmlhncfnxtwzpyoqrp.supabase.co/storage/v1/object/public/Images/uploads/profiles/buyer_20_chito.jpg

-- ============================================
-- Step 1: Check current buyer profile images
-- ============================================
SELECT 
    buyer_id,
    first_name,
    last_name,
    profile_image,
    CASE 
        WHEN profile_image LIKE 'http%' THEN '✅ Already Supabase URL'
        WHEN profile_image LIKE '/static/%' THEN '❌ Local path (needs update)'
        WHEN profile_image LIKE 'static/%' THEN '❌ Local path (needs update)'
        ELSE '⚠️ Unknown format'
    END as status
FROM buyers
WHERE profile_image IS NOT NULL
ORDER BY buyer_id;

-- ============================================
-- Step 2: Update buyers with /static/ prefix
-- ============================================
UPDATE buyers
SET profile_image = 
    'https://lpbmlhncfnxtwzpyoqrp.supabase.co/storage/v1/object/public/Images/' || 
    REPLACE(profile_image, '/static/', '')
WHERE profile_image LIKE '/static/%'
  AND profile_image NOT LIKE 'http%';

-- ============================================
-- Step 3: Update buyers with static/ prefix (no leading slash)
-- ============================================
UPDATE buyers
SET profile_image = 
    'https://lpbmlhncfnxtwzpyoqrp.supabase.co/storage/v1/object/public/Images/' || 
    REPLACE(profile_image, 'static/', '')
WHERE profile_image LIKE 'static/%'
  AND profile_image NOT LIKE 'http%';

-- ============================================
-- Step 4: Verify the updates
-- ============================================
SELECT 
    buyer_id,
    first_name,
    last_name,
    profile_image,
    CASE 
        WHEN profile_image LIKE 'http%' THEN '✅ Supabase URL'
        ELSE '❌ Still local path'
    END as status
FROM buyers
WHERE profile_image IS NOT NULL
ORDER BY buyer_id;

-- ============================================
-- EXAMPLE TRANSFORMATIONS:
-- ============================================
-- /static/uploads/profiles/buyer_20_chito.jpg
-- → https://lpbmlhncfnxtwzpyoqrp.supabase.co/storage/v1/object/public/Images/uploads/profiles/buyer_20_chito.jpg

-- static/uploads/profiles/buyer_8_1775730572044.jpg
-- → https://lpbmlhncfnxtwzpyoqrp.supabase.co/storage/v1/object/public/Images/uploads/profiles/buyer_8_1775730572044.jpg

-- ============================================
-- ROLLBACK (if needed):
-- ============================================
-- If you need to rollback, you can restore the original paths:
-- UPDATE buyers
-- SET profile_image = '/static/' || REPLACE(profile_image, 'https://lpbmlhncfnxtwzpyoqrp.supabase.co/storage/v1/object/public/Images/', '')
-- WHERE profile_image LIKE 'https://lpbmlhncfnxtwzpyoqrp.supabase.co%';
