-- ============================================
-- COMPREHENSIVE PRODUCT REVIEWS WITH SENTIMENT ANALYSIS
-- PostgreSQL/Supabase Compatible - FIXED VERSION
-- ============================================
-- This version removes order_id requirement by setting it to NULL
-- or uses existing order IDs from your database
-- ============================================

-- Option 1: If order_id can be NULL, use this version
-- If order_id is required, we'll need to use existing order IDs

-- First, let's check if we can make order_id nullable temporarily
-- Or we can use existing order IDs (200-539 based on your data)

-- Product 41 Reviews
INSERT INTO product_reviews (product_id, buyer_id, order_id, rating, review_text, sentiment, created_at) VALUES
(41, 100, 200, 5, 'Sobrang ganda! Perfect quality and very comfortable. Love it!', 'positive', NOW() - INTERVAL '2 days'),
(41, 101, 201, 5, 'Best purchase ever! Ang ganda ng quality. Highly recommended!', 'positive', NOW() - INTERVAL '5 days'),
(41, 102, 202, 4, 'Very nice! Good quality pero medyo mahal lang.', 'positive', NOW() - INTERVAL '8 days'),
(41, 103, 203, 5, 'Amazing! The fabric is premium and the fit is perfect!', 'positive', NOW() - INTERVAL '12 days'),
(41, 104, 204, 3, 'Okay naman. Nice pero nothing extraordinary for the price.', 'neutral', NOW() - INTERVAL '15 days'),
(41, 100, 205, 2, 'Disappointed. The quality is not as described.', 'negative', NOW() - INTERVAL '20 days');

-- Product 42 Reviews
INSERT INTO product_reviews (product_id, buyer_id, order_id, rating, review_text, sentiment, created_at) VALUES
(42, 101, 206, 5, 'Excellent quality! Love the design and very comfortable to wear!', 'positive', NOW() - INTERVAL '1 day'),
(42, 102, 207, 5, 'Perfect! Exceeded my expectations. Will definitely buy again!', 'positive', NOW() - INTERVAL '4 days'),
(42, 103, 208, 4, 'Great purchase! Love it pero medyo matagal dumating.', 'positive', NOW() - INTERVAL '7 days'),
(42, 104, 209, 5, 'Love this! Ang ganda and very stylish. Worth every peso!', 'positive', NOW() - INTERVAL '10 days'),
(42, 100, 210, 4, 'Nice! Good quality. Just wish it came in more colors.', 'positive', NOW() - INTERVAL '14 days'),
(42, 101, 211, 3, 'Okay lang. Nice pero the sizing is a bit off.', 'neutral', NOW() - INTERVAL '18 days'),
(42, 102, 212, 2, 'Not satisfied. The fabric is cheap and poor quality.', 'negative', NOW() - INTERVAL '22 days');

-- Product 100 Reviews
INSERT INTO product_reviews (product_id, buyer_id, order_id, rating, review_text, sentiment, created_at) VALUES
(100, 100, 213, 5, 'Outstanding! The quality is top-notch. Highly satisfied!', 'positive', NOW() - INTERVAL '3 days'),
(100, 101, 214, 5, 'Superb! Beautiful design and excellent craftsmanship!', 'positive', NOW() - INTERVAL '6 days'),
(100, 102, 215, 4, 'Beautiful! Comfortable pero runs a bit small.', 'positive', NOW() - INTERVAL '9 days'),
(100, 103, 216, 5, 'Fantastic! The material is luxurious and fits perfectly!', 'positive', NOW() - INTERVAL '13 days'),
(100, 104, 217, 4, 'Excellent! Love the design. Only issue is the sizing.', 'positive', NOW() - INTERVAL '16 days'),
(100, 100, 218, 3, 'It is decent. Good quality pero expected more.', 'neutral', NOW() - INTERVAL '19 days'),
(100, 101, 219, 2, 'Not happy. The sizing is way off and uncomfortable.', 'negative', NOW() - INTERVAL '23 days');

-- Product 101 Reviews
INSERT INTO product_reviews (product_id, buyer_id, order_id, rating, review_text, sentiment, created_at) VALUES
(101, 102, 220, 5, 'Incredible! Best quality I have seen. Absolutely love it!', 'positive', NOW() - INTERVAL '2 days'),
(101, 103, 221, 5, 'Sobrang ganda! Perfect quality and very comfortable. Love it!', 'positive', NOW() - INTERVAL '5 days'),
(101, 104, 222, 4, 'Very good! Quality is great pero a bit pricey.', 'positive', NOW() - INTERVAL '8 days'),
(101, 100, 223, 5, 'Best purchase ever! Ang ganda ng quality. Highly recommended!', 'positive', NOW() - INTERVAL '12 days'),
(101, 101, 224, 3, 'Fair. Good pero the color is different from photos.', 'neutral', NOW() - INTERVAL '15 days'),
(101, 102, 225, 2, 'Poor quality. The stitching has issues.', 'negative', NOW() - INTERVAL '20 days');

-- Product 102 Reviews
INSERT INTO product_reviews (product_id, buyer_id, order_id, rating, review_text, sentiment, created_at) VALUES
(102, 103, 226, 5, 'Amazing! The fabric is premium and the fit is perfect!', 'positive', NOW() - INTERVAL '1 day'),
(102, 104, 227, 5, 'Excellent quality! Love the design and very comfortable to wear!', 'positive', NOW() - INTERVAL '4 days'),
(102, 100, 228, 4, 'Love it! Nice fabric pero need to be careful when washing.', 'positive', NOW() - INTERVAL '7 days'),
(102, 101, 229, 5, 'Perfect! Exceeded my expectations. Will definitely buy again!', 'positive', NOW() - INTERVAL '10 days'),
(102, 102, 230, 4, 'Great! Beautiful design pero the color is slightly different.', 'positive', NOW() - INTERVAL '14 days'),
(102, 103, 231, 3, 'Decent quality pero expected better for the price.', 'neutral', NOW() - INTERVAL '18 days');

