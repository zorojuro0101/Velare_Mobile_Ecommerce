-- ============================================
-- DEBUG QUERIES FOR PRODUCT REVIEWS + SENTIMENT
-- PostgreSQL / Supabase
-- ============================================

-- 1) Confirm sentiment column exists.
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'product_reviews'
  AND column_name = 'sentiment';


-- 2) See your most recent reviews (newest first). These are the rows that
--    came in from the app; if any have sentiment IS NULL it means Gemini
--    did not classify them.
SELECT
    pr.review_id,
    pr.product_id,
    pr.buyer_id,
    pr.order_id,
    pr.rating,
    pr.review_text,
    pr.sentiment,
    pr.created_at,
    p.product_name,
    b.first_name || ' ' || b.last_name AS buyer_name
FROM product_reviews pr
LEFT JOIN products p ON p.product_id = pr.product_id
LEFT JOIN buyers   b ON b.buyer_id   = pr.buyer_id
ORDER BY pr.created_at DESC
LIMIT 25;


-- 3) Counts by sentiment value, including NULL.
SELECT
    COUNT(*) FILTER (WHERE sentiment IS NULL)        AS null_sentiment,
    COUNT(*) FILTER (WHERE sentiment = 'positive')   AS positive,
    COUNT(*) FILTER (WHERE sentiment = 'neutral')    AS neutral,
    COUNT(*) FILTER (WHERE sentiment = 'negative')   AS negative,
    COUNT(*)                                         AS total
FROM product_reviews;


-- 4) Look up your buyer_id from your email (replace the email).
SELECT b.buyer_id, b.first_name, b.last_name, u.email
FROM buyers b
JOIN users  u ON u.user_id = b.user_id
WHERE u.email = 'YOUR_EMAIL_HERE@example.com';
