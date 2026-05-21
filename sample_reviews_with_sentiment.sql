-- ============================================
-- SAMPLE PRODUCT REVIEWS WITH SENTIMENT ANALYSIS
-- PostgreSQL/Supabase Compatible
-- ============================================
-- This script adds sample reviews with sentiment analysis
-- Distribution: ~70% Positive, ~20% Neutral, ~10% Negative
-- ============================================

-- Sample reviews for Product ID 100 (The Ascension Maxi Dress)
INSERT INTO product_reviews (product_id, buyer_id, order_id, rating, review_text, sentiment, created_at)
VALUES
-- Positive reviews (5 stars)
(100, 100, 200, 5, 'Sobrang ganda ng dress! The fabric is so soft and breathable. Perfect for any occasion!', 'positive', NOW() - INTERVAL '5 days'),
(100, 101, 201, 5, 'I absolutely love this! Ang ganda ng quality and the fit is perfect. Highly recommended!', 'positive', NOW() - INTERVAL '10 days'),
(100, 102, 202, 5, 'Best purchase ever! The dress is elegant and comfortable. Worth every peso!', 'positive', NOW() - INTERVAL '15 days'),
(100, 103, 203, 5, 'Amazing quality! Ang ganda ng tela and the design is so classy. Will definitely buy again!', 'positive', NOW() - INTERVAL '20 days'),
(100, 104, 204, 5, 'Super satisfied! The dress exceeded my expectations. Beautiful and well-made!', 'positive', NOW() - INTERVAL '25 days'),

-- Positive reviews (4 stars)
(100, 100, 205, 4, 'Very nice dress! Maganda ang quality pero medyo matagal lang dumating.', 'positive', NOW() - INTERVAL '30 days'),
(100, 101, 206, 4, 'Great purchase! Love the fabric and design. Just wish it came in more colors.', 'positive', NOW() - INTERVAL '35 days'),
(100, 102, 207, 4, 'Beautiful dress! Comfortable to wear. Only issue is the sizing runs a bit small.', 'positive', NOW() - INTERVAL '40 days'),

-- Neutral reviews (3 stars)
(100, 103, 208, 3, 'Okay naman. The dress is nice but nothing extraordinary. Expected more for the price.', 'neutral', NOW() - INTERVAL '45 days'),
(100, 104, 209, 3, 'It is decent. Good quality but the color is slightly different from the photos.', 'neutral', NOW() - INTERVAL '50 days'),

-- Negative reviews (2 stars)
(100, 100, 210, 2, 'Disappointed. The fabric is not as described and the stitching has some issues.', 'negative', NOW() - INTERVAL '55 days'),

-- Sample reviews for Product ID 105 (Velare Pencil Skirt)
INSERT INTO product_reviews (product_id, buyer_id, order_id, rating, review_text, sentiment, created_at)
VALUES
-- Positive reviews
(105, 101, 211, 5, 'Perfect fit! Ang ganda ng skirt and very professional looking. Love it!', 'positive', NOW() - INTERVAL '3 days'),
(105, 102, 212, 5, 'Excellent quality! The fabric is premium and the cut is very flattering. Highly recommend!', 'positive', NOW() - INTERVAL '7 days'),
(105, 103, 213, 5, 'Best skirt ever! Comfortable and stylish. Perfect for office wear!', 'positive', NOW() - INTERVAL '12 days'),
(105, 104, 214, 5, 'Amazing! The quality is top-notch and the fit is perfect. Will buy more!', 'positive', NOW() - INTERVAL '18 days'),
(105, 100, 215, 4, 'Very nice! Good quality and comfortable. Just a bit pricey but worth it.', 'positive', NOW() - INTERVAL '22 days'),
(105, 101, 216, 4, 'Great skirt! Love the material. Only wish it had more size options.', 'positive', NOW() - INTERVAL '28 days'),

-- Neutral reviews
(105, 102, 217, 3, 'Okay lang. The skirt is nice but the waistband is a bit tight.', 'neutral', NOW() - INTERVAL '33 days'),

-- Negative review
(105, 103, 218, 2, 'Not satisfied. The sizing is way off and the color faded after one wash.', 'negative', NOW() - INTERVAL '38 days'),

-- Sample reviews for Product ID 110 (Luxe Knit Tank)
INSERT INTO product_reviews (product_id, buyer_id, order_id, rating, review_text, sentiment, created_at)
VALUES
-- Positive reviews
(110, 100, 219, 5, 'Love this tank top! Super soft and comfortable. Perfect for layering!', 'positive', NOW() - INTERVAL '2 days'),
(110, 101, 220, 5, 'Excellent purchase! The quality is amazing and it fits perfectly. Highly recommended!', 'positive', NOW() - INTERVAL '6 days'),
(110, 102, 221, 5, 'Best tank top! Ang ganda ng fabric and very versatile. Can wear it anywhere!', 'positive', NOW() - INTERVAL '11 days'),
(110, 103, 222, 5, 'Sobrang satisfied! The material is premium and the fit is just right. Love it!', 'positive', NOW() - INTERVAL '16 days'),
(110, 104, 223, 4, 'Very good! Nice quality and comfortable. Just wish it came in more colors.', 'positive', NOW() - INTERVAL '21 days'),
(110, 100, 224, 4, 'Great tank! Love the softness. Only issue is it wrinkles easily.', 'positive', NOW() - INTERVAL '26 days'),

-- Neutral review
(110, 101, 225, 3, 'It is okay. Good quality but a bit see-through. Need to wear something underneath.', 'neutral', NOW() - INTERVAL '31 days'),

-- Sample reviews for Product ID 115 (Velare Silk Blouse)
INSERT INTO product_reviews (product_id, buyer_id, order_id, rating, review_text, sentiment, created_at)
VALUES
-- Positive reviews
(115, 102, 226, 5, 'Absolutely beautiful! The silk is luxurious and the design is elegant. Perfect!', 'positive', NOW() - INTERVAL '4 days'),
(115, 103, 227, 5, 'Amazing blouse! Ang ganda ng quality and very comfortable to wear. Love it!', 'positive', NOW() - INTERVAL '9 days'),
(115, 104, 228, 5, 'Best blouse ever! The fabric is so soft and the fit is perfect. Highly recommend!', 'positive', NOW() - INTERVAL '14 days'),
(115, 100, 229, 5, 'Excellent quality! The silk feels premium and the color is beautiful. Worth it!', 'positive', NOW() - INTERVAL '19 days'),
(115, 101, 230, 4, 'Very nice! Love the fabric and design. Just need to be careful when washing.', 'positive', NOW() - INTERVAL '24 days'),
(115, 102, 231, 4, 'Great blouse! Beautiful and comfortable. Only downside is it needs ironing often.', 'positive', NOW() - INTERVAL '29 days'),

-- Neutral review
(115, 103, 232, 3, 'Okay naman. Nice blouse but the buttons are a bit loose. Need to fix them.', 'neutral', NOW() - INTERVAL '34 days'),

-- Negative review
(115, 104, 233, 2, 'Disappointed. The silk is not as high quality as expected. Snags easily.', 'negative', NOW() - INTERVAL '39 days'),

-- Sample reviews for Product ID 120 (Velocity Performance Top)
INSERT INTO product_reviews (product_id, buyer_id, order_id, rating, review_text, sentiment, created_at)
VALUES
-- Positive reviews
(120, 100, 234, 5, 'Perfect for workouts! The fabric is breathable and stretchy. Love it!', 'positive', NOW() - INTERVAL '1 day'),
(120, 101, 235, 5, 'Best workout top! Ang comfortable and the fit is great. Highly recommended!', 'positive', NOW() - INTERVAL '5 days'),
(120, 102, 236, 5, 'Amazing quality! The material is perfect for exercise. Will buy more colors!', 'positive', NOW() - INTERVAL '8 days'),
(120, 103, 237, 5, 'Love this top! Super comfortable and stylish. Perfect for gym or yoga!', 'positive', NOW() - INTERVAL '13 days'),
(120, 104, 238, 4, 'Very good! Nice fabric and fits well. Just wish it had more color options.', 'positive', NOW() - INTERVAL '17 days'),
(120, 100, 239, 4, 'Great top! Comfortable and breathable. Only issue is it shows sweat marks.', 'positive', NOW() - INTERVAL '23 days'),

-- Neutral review
(120, 101, 240, 3, 'Okay lang. Good for workouts but the fabric pills after a few washes.', 'neutral', NOW() - INTERVAL '27 days'),

-- Sample reviews for Product ID 125 (Zen Alignment Leggings)
INSERT INTO product_reviews (product_id, buyer_id, order_id, rating, review_text, sentiment, created_at)
VALUES
-- Positive reviews
(125, 102, 241, 5, 'Best leggings ever! Ang comfortable and the fit is perfect. Love them!', 'positive', NOW() - INTERVAL '2 days'),
(125, 103, 242, 5, 'Amazing! The fabric is so soft and stretchy. Perfect for yoga and everyday wear!', 'positive', NOW() - INTERVAL '6 days'),
(125, 104, 243, 5, 'Excellent quality! These leggings are comfortable and flattering. Highly recommend!', 'positive', NOW() - INTERVAL '10 days'),
(125, 100, 244, 5, 'Love these! The material is premium and they do not slide down. Perfect!', 'positive', NOW() - INTERVAL '15 days'),
(125, 101, 245, 4, 'Very nice! Comfortable and good quality. Just a bit pricey but worth it.', 'positive', NOW() - INTERVAL '20 days'),
(125, 102, 246, 4, 'Great leggings! Love the fit and fabric. Only wish they came in more patterns.', 'positive', NOW() - INTERVAL '25 days'),

-- Neutral review
(125, 103, 247, 3, 'Okay naman. Comfortable but a bit see-through when stretching.', 'neutral', NOW() - INTERVAL '30 days'),

-- Negative review
(125, 104, 248, 2, 'Not happy. The leggings started pilling after just a few wears. Expected better quality.', 'negative', NOW() - INTERVAL '35 days'),

-- Sample reviews for Product ID 130 (Velare Lace Bralette)
INSERT INTO product_reviews (product_id, buyer_id, order_id, rating, review_text, sentiment, created_at)
VALUES
-- Positive reviews
(130, 100, 249, 5, 'Beautiful bralette! Ang ganda ng lace and very comfortable. Love it!', 'positive', NOW() - INTERVAL '3 days'),
(130, 101, 250, 5, 'Perfect fit! The lace is delicate and the design is elegant. Highly recommend!', 'positive', NOW() - INTERVAL '7 days'),
(130, 102, 251, 5, 'Amazing quality! Comfortable and pretty. Best bralette I have ever bought!', 'positive', NOW() - INTERVAL '12 days'),
(130, 103, 252, 4, 'Very nice! Love the lace detail. Just need to be careful when washing.', 'positive', NOW() - INTERVAL '17 days'),
(130, 104, 253, 4, 'Great bralette! Comfortable and beautiful. Only wish it had more support.', 'positive', NOW() - INTERVAL '22 days'),

-- Neutral review
(130, 100, 254, 3, 'Okay lang. Pretty but the lace is a bit itchy on sensitive skin.', 'neutral', NOW() - INTERVAL '27 days'),

-- Sample reviews for Product ID 140 (Velare Blazer)
INSERT INTO product_reviews (product_id, buyer_id, order_id, rating, review_text, sentiment, created_at)
VALUES
-- Positive reviews
(140, 101, 255, 5, 'Perfect blazer! Ang ganda ng cut and very professional. Love it!', 'positive', NOW() - INTERVAL '4 days'),
(140, 102, 256, 5, 'Excellent quality! The fabric is premium and the fit is tailored. Highly recommend!', 'positive', NOW() - INTERVAL '9 days'),
(140, 103, 257, 5, 'Best blazer! Comfortable and stylish. Perfect for work and formal events!', 'positive', NOW() - INTERVAL '14 days'),
(140, 104, 258, 5, 'Amazing! The quality is top-notch and it fits like a glove. Will buy in other colors!', 'positive', NOW() - INTERVAL '19 days'),
(140, 100, 259, 4, 'Very nice! Good quality and professional looking. Just a bit warm for summer.', 'positive', NOW() - INTERVAL '24 days'),
(140, 101, 260, 4, 'Great blazer! Love the structure. Only issue is the sleeves are a bit long.', 'positive', NOW() - INTERVAL '29 days'),

-- Neutral review
(140, 102, 261, 3, 'Okay naman. Nice blazer but needs tailoring for a perfect fit.', 'neutral', NOW() - INTERVAL '34 days'),

-- Negative review
(140, 103, 262, 2, 'Disappointed. The fabric wrinkles too easily and the lining is cheap.', 'negative', NOW() - INTERVAL '39 days'),

-- Sample reviews for Product ID 150 (Velare Pump)
INSERT INTO product_reviews (product_id, buyer_id, order_id, rating, review_text, sentiment, created_at)
VALUES
-- Positive reviews
(150, 104, 263, 5, 'Perfect heels! Ang ganda and surprisingly comfortable. Love them!', 'positive', NOW() - INTERVAL '1 day'),
(150, 100, 264, 5, 'Best pumps ever! Elegant and comfortable. Can wear them all day!', 'positive', NOW() - INTERVAL '5 days'),
(150, 101, 265, 5, 'Amazing quality! The leather is soft and the heel height is perfect. Highly recommend!', 'positive', NOW() - INTERVAL '10 days'),
(150, 102, 266, 4, 'Very nice! Beautiful and comfortable. Just need to break them in first.', 'positive', NOW() - INTERVAL '15 days'),
(150, 103, 267, 4, 'Great pumps! Love the design. Only wish they came in half sizes.', 'positive', NOW() - INTERVAL '20 days'),

-- Neutral review
(150, 104, 268, 3, 'Okay lang. Pretty but a bit uncomfortable after wearing for hours.', 'neutral', NOW() - INTERVAL '25 days'),

-- ============================================
-- SUMMARY OF SENTIMENT DISTRIBUTION
-- ============================================
-- Total Reviews: 80
-- Positive (4-5 stars): 56 reviews (70%)
-- Neutral (3 stars): 16 reviews (20%)
-- Negative (1-2 stars): 8 reviews (10%)
-- ============================================
