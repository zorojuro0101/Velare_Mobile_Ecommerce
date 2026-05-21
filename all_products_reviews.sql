-- ============================================
-- COMPREHENSIVE PRODUCT REVIEWS WITH SENTIMENT ANALYSIS
-- PostgreSQL/Supabase Compatible
-- ============================================
-- Distribution: ~70% Positive, ~20% Neutral, ~10% Negative
-- Products: 41, 42, 100-159 (62 products total)
-- ============================================

-- Product 41 Reviews
INSERT INTO product_reviews (product_id, buyer_id, order_id, rating, review_text, sentiment, created_at) VALUES
(41, 100, 2001, 5, 'Sobrang ganda! Perfect quality and very comfortable. Love it!', 'positive', NOW() - INTERVAL '2 days'),
(41, 101, 2002, 5, 'Best purchase ever! Ang ganda ng quality. Highly recommended!', 'positive', NOW() - INTERVAL '5 days'),
(41, 102, 2003, 4, 'Very nice! Good quality pero medyo mahal lang.', 'positive', NOW() - INTERVAL '8 days'),
(41, 103, 2004, 5, 'Amazing! The fabric is premium and the fit is perfect!', 'positive', NOW() - INTERVAL '12 days'),
(41, 104, 2005, 3, 'Okay naman. Nice pero nothing extraordinary for the price.', 'neutral', NOW() - INTERVAL '15 days'),
(41, 100, 2006, 2, 'Disappointed. The quality is not as described.', 'negative', NOW() - INTERVAL '20 days');

-- Product 42 Reviews
INSERT INTO product_reviews (product_id, buyer_id, order_id, rating, review_text, sentiment, created_at) VALUES
(42, 101, 2007, 5, 'Excellent quality! Love the design and very comfortable to wear!', 'positive', NOW() - INTERVAL '1 day'),
(42, 102, 2008, 5, 'Perfect! Exceeded my expectations. Will definitely buy again!', 'positive', NOW() - INTERVAL '4 days'),
(42, 103, 2009, 4, 'Great purchase! Love it pero medyo matagal dumating.', 'positive', NOW() - INTERVAL '7 days'),
(42, 104, 2010, 5, 'Love this! Ang ganda and very stylish. Worth every peso!', 'positive', NOW() - INTERVAL '10 days'),
(42, 100, 2011, 4, 'Nice! Good quality. Just wish it came in more colors.', 'positive', NOW() - INTERVAL '14 days'),
(42, 101, 2012, 3, 'Okay lang. Nice pero the sizing is a bit off.', 'neutral', NOW() - INTERVAL '18 days'),
(42, 102, 2013, 2, 'Not satisfied. The fabric is cheap and poor quality.', 'negative', NOW() - INTERVAL '22 days');

-- Product 100 Reviews
INSERT INTO product_reviews (product_id, buyer_id, order_id, rating, review_text, sentiment, created_at) VALUES
(100, 100, 2014, 5, 'Outstanding! The quality is top-notch. Highly satisfied!', 'positive', NOW() - INTERVAL '3 days'),
(100, 101, 2015, 5, 'Superb! Beautiful design and excellent craftsmanship!', 'positive', NOW() - INTERVAL '6 days'),
(100, 102, 2016, 4, 'Beautiful! Comfortable pero runs a bit small.', 'positive', NOW() - INTERVAL '9 days'),
(100, 103, 2017, 5, 'Fantastic! The material is luxurious and fits perfectly!', 'positive', NOW() - INTERVAL '13 days'),
(100, 104, 2018, 4, 'Excellent! Love the design. Only issue is the sizing.', 'positive', NOW() - INTERVAL '16 days'),
(100, 100, 2019, 3, 'It is decent. Good quality pero expected more.', 'neutral', NOW() - INTERVAL '19 days'),
(100, 101, 2020, 2, 'Not happy. The sizing is way off and uncomfortable.', 'negative', NOW() - INTERVAL '23 days');

-- Product 101 Reviews
INSERT INTO product_reviews (product_id, buyer_id, order_id, rating, review_text, sentiment, created_at) VALUES
(101, 102, 2021, 5, 'Incredible! Best quality I have seen. Absolutely love it!', 'positive', NOW() - INTERVAL '2 days'),
(101, 103, 2022, 5, 'Sobrang ganda! Perfect quality and very comfortable. Love it!', 'positive', NOW() - INTERVAL '5 days'),
(101, 104, 2023, 4, 'Very good! Quality is great pero a bit pricey.', 'positive', NOW() - INTERVAL '8 days'),
(101, 100, 2024, 5, 'Best purchase ever! Ang ganda ng quality. Highly recommended!', 'positive', NOW() - INTERVAL '12 days'),
(101, 101, 2025, 3, 'Fair. Good pero the color is different from photos.', 'neutral', NOW() - INTERVAL '15 days'),
(101, 102, 2026, 2, 'Poor quality. The stitching has issues.', 'negative', NOW() - INTERVAL '20 days');

-- Product 102 Reviews
INSERT INTO product_reviews (product_id, buyer_id, order_id, rating, review_text, sentiment, created_at) VALUES
(102, 103, 2027, 5, 'Amazing! The fabric is premium and the fit is perfect!', 'positive', NOW() - INTERVAL '1 day'),
(102, 104, 2028, 5, 'Excellent quality! Love the design and very comfortable to wear!', 'positive', NOW() - INTERVAL '4 days'),
(102, 100, 2029, 4, 'Love it! Nice fabric pero need to be careful when washing.', 'positive', NOW() - INTERVAL '7 days'),
(102, 101, 2030, 5, 'Perfect! Exceeded my expectations. Will definitely buy again!', 'positive', NOW() - INTERVAL '10 days'),
(102, 102, 2031, 4, 'Great! Beautiful design pero the color is slightly different.', 'positive', NOW() - INTERVAL '14 days'),
(102, 103, 2032, 3, 'Decent quality pero expected better for the price.', 'neutral', NOW() - INTERVAL '18 days');

-- Product 103 Reviews
INSERT INTO product_reviews (product_id, buyer_id, order_id, rating, review_text, sentiment, created_at) VALUES
(103, 104, 2033, 5, 'Love this! Ang ganda and very stylish. Worth every peso!', 'positive', NOW() - INTERVAL '3 days'),
(103, 100, 2034, 5, 'Outstanding! The quality is top-notch. Highly satisfied!', 'positive', NOW() - INTERVAL '6 days'),
(103, 101, 2035, 4, 'Very nice! Good quality pero medyo mahal lang.', 'positive', NOW() - INTERVAL '9 days'),
(103, 102, 2036, 5, 'Superb! Beautiful design and excellent craftsmanship!', 'positive', NOW() - INTERVAL '13 days'),
(103, 103, 2037, 3, 'Okay. Nice pero the fit is not perfect.', 'neutral', NOW() - INTERVAL '16 days'),
(103, 104, 2038, 2, 'Disappointed. Not worth the price. Expected better.', 'negative', NOW() - INTERVAL '20 days');

-- Product 104 Reviews
INSERT INTO product_reviews (product_id, buyer_id, order_id, rating, review_text, sentiment, created_at) VALUES
(104, 100, 2039, 5, 'Fantastic! The material is luxurious and fits perfectly!', 'positive', NOW() - INTERVAL '2 days'),
(104, 101, 2040, 5, 'Incredible! Best quality I have seen. Absolutely love it!', 'positive', NOW() - INTERVAL '5 days'),
(104, 102, 2041, 4, 'Great purchase! Love it pero medyo matagal dumating.', 'positive', NOW() - INTERVAL '8 days'),
(104, 103, 2042, 5, 'Sobrang ganda! Perfect quality and very comfortable. Love it!', 'positive', NOW() - INTERVAL '12 days'),
(104, 104, 2043, 4, 'Nice! Good quality. Just wish it came in more colors.', 'positive', NOW() - INTERVAL '15 days'),
(104, 100, 2044, 3, 'It is alright. Good pero nothing special.', 'neutral', NOW() - INTERVAL '19 days');

-- Product 105 Reviews
INSERT INTO product_reviews (product_id, buyer_id, order_id, rating, review_text, sentiment, created_at) VALUES
(105, 101, 2045, 5, 'Best purchase ever! Ang ganda ng quality. Highly recommended!', 'positive', NOW() - INTERVAL '1 day'),
(105, 102, 2046, 5, 'Amazing! The fabric is premium and the fit is perfect!', 'positive', NOW() - INTERVAL '4 days'),
(105, 103, 2047, 4, 'Beautiful! Comfortable pero runs a bit small.', 'positive', NOW() - INTERVAL '7 days'),
(105, 104, 2048, 5, 'Excellent quality! Love the design and very comfortable to wear!', 'positive', NOW() - INTERVAL '10 days'),
(105, 100, 2049, 4, 'Excellent! Love the design. Only issue is the sizing.', 'positive', NOW() - INTERVAL '14 days'),
(105, 101, 2050, 3, 'Acceptable. Okay naman pero may minor issues.', 'neutral', NOW() - INTERVAL '18 days'),
(105, 102, 2051, 2, 'Not good. The material is not as advertised.', 'negative', NOW() - INTERVAL '22 days');

-- Product 106 Reviews
INSERT INTO product_reviews (product_id, buyer_id, order_id, rating, review_text, sentiment, created_at) VALUES
(106, 103, 2052, 5, 'Perfect! Exceeded my expectations. Will definitely buy again!', 'positive', NOW() - INTERVAL '3 days'),
(106, 104, 2053, 5, 'Love this! Ang ganda and very stylish. Worth every peso!', 'positive', NOW() - INTERVAL '6 days'),
(106, 100, 2054, 4, 'Very good! Quality is great pero a bit pricey.', 'positive', NOW() - INTERVAL '9 days'),
(106, 101, 2055, 5, 'Outstanding! The quality is top-notch. Highly satisfied!', 'positive', NOW() - INTERVAL '13 days'),
(106, 102, 2056, 3, 'Okay naman. Nice pero nothing extraordinary for the price.', 'neutral', NOW() - INTERVAL '16 days'),
(106, 103, 2057, 2, 'Unsatisfied. The product has defects.', 'negative', NOW() - INTERVAL '20 days');

-- Product 107 Reviews
INSERT INTO product_reviews (product_id, buyer_id, order_id, rating, review_text, sentiment, created_at) VALUES
(107, 104, 2058, 5, 'Superb! Beautiful design and excellent craftsmanship!', 'positive', NOW() - INTERVAL '2 days'),
(107, 100, 2059, 5, 'Fantastic! The material is luxurious and fits perfectly!', 'positive', NOW() - INTERVAL '5 days'),
(107, 101, 2060, 4, 'Love it! Nice fabric pero need to be careful when washing.', 'positive', NOW() - INTERVAL '8 days'),
(107, 102, 2061, 5, 'Incredible! Best quality I have seen. Absolutely love it!', 'positive', NOW() - INTERVAL '12 days'),
(107, 103, 2062, 4, 'Great! Beautiful design pero the color is slightly different.', 'positive', NOW() - INTERVAL '15 days'),
(107, 104, 2063, 3, 'It is decent. Good quality pero expected more.', 'neutral', NOW() - INTERVAL '19 days');

-- Products 108-115 Reviews (Batch 1)
INSERT INTO product_reviews (product_id, buyer_id, order_id, rating, review_text, sentiment, created_at) VALUES
-- Product 108
(108, 100, 2064, 5, 'Sobrang ganda! Perfect quality and very comfortable. Love it!', 'positive', NOW() - INTERVAL '1 day'),
(108, 101, 2065, 5, 'Best purchase ever! Ang ganda ng quality. Highly recommended!', 'positive', NOW() - INTERVAL '4 days'),
(108, 102, 2066, 4, 'Very nice! Good quality pero medyo mahal lang.', 'positive', NOW() - INTERVAL '7 days'),
(108, 103, 2067, 5, 'Amazing! The fabric is premium and the fit is perfect!', 'positive', NOW() - INTERVAL '11 days'),
(108, 104, 2068, 3, 'Fair. Good pero the color is different from photos.', 'neutral', NOW() - INTERVAL '15 days'),
-- Product 109
(109, 100, 2069, 5, 'Excellent quality! Love the design and very comfortable to wear!', 'positive', NOW() - INTERVAL '2 days'),
(109, 101, 2070, 5, 'Perfect! Exceeded my expectations. Will definitely buy again!', 'positive', NOW() - INTERVAL '5 days'),
(109, 102, 2071, 4, 'Great purchase! Love it pero medyo matagal dumating.', 'positive', NOW() - INTERVAL '8 days'),
(109, 103, 2072, 5, 'Love this! Ang ganda and very stylish. Worth every peso!', 'positive', NOW() - INTERVAL '12 days'),
(109, 104, 2073, 3, 'Decent quality pero expected better for the price.', 'neutral', NOW() - INTERVAL '16 days'),
(109, 100, 2074, 2, 'Disappointed. The quality is not as described.', 'negative', NOW() - INTERVAL '20 days'),
-- Product 110
(110, 101, 2075, 5, 'Outstanding! The quality is top-notch. Highly satisfied!', 'positive', NOW() - INTERVAL '3 days'),
(110, 102, 2076, 5, 'Superb! Beautiful design and excellent craftsmanship!', 'positive', NOW() - INTERVAL '6 days'),
(110, 103, 2077, 4, 'Beautiful! Comfortable pero runs a bit small.', 'positive', NOW() - INTERVAL '9 days'),
(110, 104, 2078, 5, 'Fantastic! The material is luxurious and fits perfectly!', 'positive', NOW() - INTERVAL '13 days'),
(110, 100, 2079, 4, 'Excellent! Love the design. Only issue is the sizing.', 'positive', NOW() - INTERVAL '17 days'),
(110, 101, 2080, 3, 'Okay. Nice pero the fit is not perfect.', 'neutral', NOW() - INTERVAL '21 days'),
-- Product 111
(111, 102, 2081, 5, 'Incredible! Best quality I have seen. Absolutely love it!', 'positive', NOW() - INTERVAL '1 day'),
(111, 103, 2082, 5, 'Sobrang ganda! Perfect quality and very comfortable. Love it!', 'positive', NOW() - INTERVAL '4 days'),
(111, 104, 2083, 4, 'Very good! Quality is great pero a bit pricey.', 'positive', NOW() - INTERVAL '7 days'),
(111, 100, 2084, 5, 'Best purchase ever! Ang ganda ng quality. Highly recommended!', 'positive', NOW() - INTERVAL '11 days'),
(111, 101, 2085, 3, 'It is alright. Good pero nothing special.', 'neutral', NOW() - INTERVAL '15 days'),
(111, 102, 2086, 2, 'Not satisfied. The fabric is cheap and poor quality.', 'negative', NOW() - INTERVAL '19 days'),
-- Product 112
(112, 103, 2087, 5, 'Amazing! The fabric is premium and the fit is perfect!', 'positive', NOW() - INTERVAL '2 days'),
(112, 104, 2088, 5, 'Excellent quality! Love the design and very comfortable to wear!', 'positive', NOW() - INTERVAL '5 days'),
(112, 100, 2089, 4, 'Love it! Nice fabric pero need to be careful when washing.', 'positive', NOW() - INTERVAL '8 days'),
(112, 101, 2090, 5, 'Perfect! Exceeded my expectations. Will definitely buy again!', 'positive', NOW() - INTERVAL '12 days'),
(112, 102, 2091, 4, 'Great! Beautiful design pero the color is slightly different.', 'positive', NOW() - INTERVAL '16 days'),
(112, 103, 2092, 3, 'Acceptable. Okay naman pero may minor issues.', 'neutral', NOW() - INTERVAL '20 days'),
-- Product 113
(113, 104, 2093, 5, 'Love this! Ang ganda and very stylish. Worth every peso!', 'positive', NOW() - INTERVAL '3 days'),
(113, 100, 2094, 5, 'Outstanding! The quality is top-notch. Highly satisfied!', 'positive', NOW() - INTERVAL '6 days'),
(113, 101, 2095, 4, 'Very nice! Good quality pero medyo mahal lang.', 'positive', NOW() - INTERVAL '9 days'),
(113, 102, 2096, 5, 'Superb! Beautiful design and excellent craftsmanship!', 'positive', NOW() - INTERVAL '13 days'),
(113, 103, 2097, 3, 'Okay naman. Nice pero nothing extraordinary for the price.', 'neutral', NOW() - INTERVAL '17 days'),
(113, 104, 2098, 2, 'Poor quality. The stitching has issues.', 'negative', NOW() - INTERVAL '21 days'),
-- Product 114
(114, 100, 2099, 5, 'Fantastic! The material is luxurious and fits perfectly!', 'positive', NOW() - INTERVAL '1 day'),
(114, 101, 2100, 5, 'Incredible! Best quality I have seen. Absolutely love it!', 'positive', NOW() - INTERVAL '4 days'),
(114, 102, 2101, 4, 'Great purchase! Love it pero medyo matagal dumating.', 'positive', NOW() - INTERVAL '7 days'),
(114, 103, 2102, 5, 'Sobrang ganda! Perfect quality and very comfortable. Love it!', 'positive', NOW() - INTERVAL '11 days'),
(114, 104, 2103, 4, 'Nice! Good quality. Just wish it came in more colors.', 'positive', NOW() - INTERVAL '15 days'),
(114, 100, 2104, 3, 'It is decent. Good quality pero expected more.', 'neutral', NOW() - INTERVAL '19 days'),
-- Product 115
(115, 101, 2105, 5, 'Best purchase ever! Ang ganda ng quality. Highly recommended!', 'positive', NOW() - INTERVAL '2 days'),
(115, 102, 2106, 5, 'Amazing! The fabric is premium and the fit is perfect!', 'positive', NOW() - INTERVAL '5 days'),
(115, 103, 2107, 4, 'Beautiful! Comfortable pero runs a bit small.', 'positive', NOW() - INTERVAL '8 days'),
(115, 104, 2108, 5, 'Excellent quality! Love the design and very comfortable to wear!', 'positive', NOW() - INTERVAL '12 days'),
(115, 100, 2109, 4, 'Excellent! Love the design. Only issue is the sizing.', 'positive', NOW() - INTERVAL '16 days'),
(115, 101, 2110, 3, 'Fair. Good pero the color is different from photos.', 'neutral', NOW() - INTERVAL '20 days'),
(115, 102, 2111, 2, 'Disappointed. Not worth the price. Expected better.', 'negative', NOW() - INTERVAL '24 days');

-- Products 116-159 Reviews (Remaining Products)
-- Each product has 5-7 reviews with 70% positive, 20% neutral, 10% negative distribution
INSERT INTO product_reviews (product_id, buyer_id, order_id, rating, review_text, sentiment, created_at) VALUES
-- Products 116-120
(116, 103, 2112, 5, 'Perfect! Exceeded my expectations. Will definitely buy again!', 'positive', NOW() - INTERVAL '3 days'),
(116, 104, 2113, 5, 'Love this! Ang ganda and very stylish. Worth every peso!', 'positive', NOW() - INTERVAL '6 days'),
(116, 100, 2114, 4, 'Very good! Quality is great pero a bit pricey.', 'positive', NOW() - INTERVAL '9 days'),
(116, 101, 2115, 5, 'Outstanding! The quality is top-notch. Highly satisfied!', 'positive', NOW() - INTERVAL '13 days'),
(116, 102, 2116, 3, 'Decent quality pero expected better for the price.', 'neutral', NOW() - INTERVAL '17 days'),
(117, 103, 2117, 5, 'Superb! Beautiful design and excellent craftsmanship!', 'positive', NOW() - INTERVAL '2 days'),
(117, 104, 2118, 5, 'Fantastic! The material is luxurious and fits perfectly!', 'positive', NOW() - INTERVAL '5 days'),
(117, 100, 2119, 4, 'Love it! Nice fabric pero need to be careful when washing.', 'positive', NOW() - INTERVAL '8 days'),
(117, 101, 2120, 5, 'Incredible! Best quality I have seen. Absolutely love it!', 'positive', NOW() - INTERVAL '12 days'),
(117, 102, 2121, 3, 'Okay. Nice pero the fit is not perfect.', 'neutral', NOW() - INTERVAL '16 days'),
(117, 103, 2122, 2, 'Not good. The material is not as advertised.', 'negative', NOW() - INTERVAL '20 days'),
(118, 104, 2123, 5, 'Sobrang ganda! Perfect quality and very comfortable. Love it!', 'positive', NOW() - INTERVAL '1 day'),
(118, 100, 2124, 5, 'Best purchase ever! Ang ganda ng quality. Highly recommended!', 'positive', NOW() - INTERVAL '4 days'),
(118, 101, 2125, 4, 'Very nice! Good quality pero medyo mahal lang.', 'positive', NOW() - INTERVAL '7 days'),
(118, 102, 2126, 5, 'Amazing! The fabric is premium and the fit is perfect!', 'positive', NOW() - INTERVAL '11 days'),
(118, 103, 2127, 3, 'It is alright. Good pero nothing special.', 'neutral', NOW() - INTERVAL '15 days'),
(119, 104, 2128, 5, 'Excellent quality! Love the design and very comfortable to wear!', 'positive', NOW() - INTERVAL '2 days'),
(119, 100, 2129, 5, 'Perfect! Exceeded my expectations. Will definitely buy again!', 'positive', NOW() - INTERVAL '5 days'),
(119, 101, 2130, 4, 'Great purchase! Love it pero medyo matagal dumating.', 'positive', NOW() - INTERVAL '8 days'),
(119, 102, 2131, 5, 'Love this! Ang ganda and very stylish. Worth every peso!', 'positive', NOW() - INTERVAL '12 days'),
(119, 103, 2132, 4, 'Nice! Good quality. Just wish it came in more colors.', 'positive', NOW() - INTERVAL '16 days'),
(119, 104, 2133, 3, 'Acceptable. Okay naman pero may minor issues.', 'neutral', NOW() - INTERVAL '20 days'),
(120, 100, 2134, 5, 'Outstanding! The quality is top-notch. Highly satisfied!', 'positive', NOW() - INTERVAL '3 days'),
(120, 101, 2135, 5, 'Superb! Beautiful design and excellent craftsmanship!', 'positive', NOW() - INTERVAL '6 days'),
(120, 102, 2136, 4, 'Beautiful! Comfortable pero runs a bit small.', 'positive', NOW() - INTERVAL '9 days'),
(120, 103, 2137, 5, 'Fantastic! The material is luxurious and fits perfectly!', 'positive', NOW() - INTERVAL '13 days'),
(120, 104, 2138, 3, 'Okay naman. Nice pero nothing extraordinary for the price.', 'neutral', NOW() - INTERVAL '17 days'),
(120, 100, 2139, 2, 'Unsatisfied. The product has defects.', 'negative', NOW() - INTERVAL '21 days');

-- Products 121-140
INSERT INTO product_reviews (product_id, buyer_id, order_id, rating, review_text, sentiment, created_at) VALUES
(121, 101, 2140, 5, 'Incredible! Best quality I have seen. Absolutely love it!', 'positive', NOW() - INTERVAL '1 day'),
(121, 102, 2141, 5, 'Sobrang ganda! Perfect quality and very comfortable. Love it!', 'positive', NOW() - INTERVAL '4 days'),
(121, 103, 2142, 4, 'Very good! Quality is great pero a bit pricey.', 'positive', NOW() - INTERVAL '7 days'),
(121, 104, 2143, 5, 'Best purchase ever! Ang ganda ng quality. Highly recommended!', 'positive', NOW() - INTERVAL '11 days'),
(121, 100, 2144, 3, 'It is decent. Good quality pero expected more.', 'neutral', NOW() - INTERVAL '15 days'),
(122, 101, 2145, 5, 'Amazing! The fabric is premium and the fit is perfect!', 'positive', NOW() - INTERVAL '2 days'),
(122, 102, 2146, 5, 'Excellent quality! Love the design and very comfortable to wear!', 'positive', NOW() - INTERVAL '5 days'),
(122, 103, 2147, 4, 'Love it! Nice fabric pero need to be careful when washing.', 'positive', NOW() - INTERVAL '8 days'),
(122, 104, 2148, 5, 'Perfect! Exceeded my expectations. Will definitely buy again!', 'positive', NOW() - INTERVAL '12 days'),
(122, 100, 2149, 3, 'Fair. Good pero the color is different from photos.', 'neutral', NOW() - INTERVAL '16 days'),
(122, 101, 2150, 2, 'Disappointed. The quality is not as described.', 'negative', NOW() - INTERVAL '20 days'),
(123, 102, 2151, 5, 'Love this! Ang ganda and very stylish. Worth every peso!', 'positive', NOW() - INTERVAL '3 days'),
(123, 103, 2152, 5, 'Outstanding! The quality is top-notch. Highly satisfied!', 'positive', NOW() - INTERVAL '6 days'),
(123, 104, 2153, 4, 'Very nice! Good quality pero medyo mahal lang.', 'positive', NOW() - INTERVAL '9 days'),
(123, 100, 2154, 5, 'Superb! Beautiful design and excellent craftsmanship!', 'positive', NOW() - INTERVAL '13 days'),
(123, 101, 2155, 3, 'Decent quality pero expected better for the price.', 'neutral', NOW() - INTERVAL '17 days'),
(124, 102, 2156, 5, 'Fantastic! The material is luxurious and fits perfectly!', 'positive', NOW() - INTERVAL '1 day'),
(124, 103, 2157, 5, 'Incredible! Best quality I have seen. Absolutely love it!', 'positive', NOW() - INTERVAL '4 days'),
(124, 104, 2158, 4, 'Great purchase! Love it pero medyo matagal dumating.', 'positive', NOW() - INTERVAL '7 days'),
(124, 100, 2159, 5, 'Sobrang ganda! Perfect quality and very comfortable. Love it!', 'positive', NOW() - INTERVAL '11 days'),
(124, 101, 2160, 4, 'Nice! Good quality. Just wish it came in more colors.', 'positive', NOW() - INTERVAL '15 days'),
(124, 102, 2161, 3, 'Okay. Nice pero the fit is not perfect.', 'neutral', NOW() - INTERVAL '19 days'),
(125, 103, 2162, 5, 'Best purchase ever! Ang ganda ng quality. Highly recommended!', 'positive', NOW() - INTERVAL '2 days'),
(125, 104, 2163, 5, 'Amazing! The fabric is premium and the fit is perfect!', 'positive', NOW() - INTERVAL '5 days'),
(125, 100, 2164, 4, 'Beautiful! Comfortable pero runs a bit small.', 'positive', NOW() - INTERVAL '8 days'),
(125, 101, 2165, 5, 'Excellent quality! Love the design and very comfortable to wear!', 'positive', NOW() - INTERVAL '12 days'),
(125, 102, 2166, 3, 'It is alright. Good pero nothing special.', 'neutral', NOW() - INTERVAL '16 days'),
(125, 103, 2167, 2, 'Not satisfied. The fabric is cheap and poor quality.', 'negative', NOW() - INTERVAL '20 days'),
(126, 104, 2168, 5, 'Perfect! Exceeded my expectations. Will definitely buy again!', 'positive', NOW() - INTERVAL '3 days'),
(126, 100, 2169, 5, 'Love this! Ang ganda and very stylish. Worth every peso!', 'positive', NOW() - INTERVAL '6 days'),
(126, 101, 2170, 4, 'Very good! Quality is great pero a bit pricey.', 'positive', NOW() - INTERVAL '9 days'),
(126, 102, 2171, 5, 'Outstanding! The quality is top-notch. Highly satisfied!', 'positive', NOW() - INTERVAL '13 days'),
(126, 103, 2172, 3, 'Acceptable. Okay naman pero may minor issues.', 'neutral', NOW() - INTERVAL '17 days'),
(127, 104, 2173, 5, 'Superb! Beautiful design and excellent craftsmanship!', 'positive', NOW() - INTERVAL '1 day'),
(127, 100, 2174, 5, 'Fantastic! The material is luxurious and fits perfectly!', 'positive', NOW() - INTERVAL '4 days'),
(127, 101, 2175, 4, 'Love it! Nice fabric pero need to be careful when washing.', 'positive', NOW() - INTERVAL '7 days'),
(127, 102, 2176, 5, 'Incredible! Best quality I have seen. Absolutely love it!', 'positive', NOW() - INTERVAL '11 days'),
(127, 103, 2177, 3, 'Okay naman. Nice pero nothing extraordinary for the price.', 'neutral', NOW() - INTERVAL '15 days'),
(127, 104, 2178, 2, 'Poor quality. The stitching has issues.', 'negative', NOW() - INTERVAL '19 days'),
(128, 100, 2179, 5, 'Sobrang ganda! Perfect quality and very comfortable. Love it!', 'positive', NOW() - INTERVAL '2 days'),
(128, 101, 2180, 5, 'Best purchase ever! Ang ganda ng quality. Highly recommended!', 'positive', NOW() - INTERVAL '5 days'),
(128, 102, 2181, 4, 'Very nice! Good quality pero medyo mahal lang.', 'positive', NOW() - INTERVAL '8 days'),
(128, 103, 2182, 5, 'Amazing! The fabric is premium and the fit is perfect!', 'positive', NOW() - INTERVAL '12 days'),
(128, 104, 2183, 3, 'It is decent. Good quality pero expected more.', 'neutral', NOW() - INTERVAL '16 days'),
(129, 100, 2184, 5, 'Excellent quality! Love the design and very comfortable to wear!', 'positive', NOW() - INTERVAL '3 days'),
(129, 101, 2185, 5, 'Perfect! Exceeded my expectations. Will definitely buy again!', 'positive', NOW() - INTERVAL '6 days'),
(129, 102, 2186, 4, 'Great purchase! Love it pero medyo matagal dumating.', 'positive', NOW() - INTERVAL '9 days'),
(129, 103, 2187, 5, 'Love this! Ang ganda and very stylish. Worth every peso!', 'positive', NOW() - INTERVAL '13 days'),
(129, 104, 2188, 4, 'Nice! Good quality. Just wish it came in more colors.', 'positive', NOW() - INTERVAL '17 days'),
(129, 100, 2189, 3, 'Fair. Good pero the color is different from photos.', 'neutral', NOW() - INTERVAL '21 days'),
(130, 101, 2190, 5, 'Outstanding! The quality is top-notch. Highly satisfied!', 'positive', NOW() - INTERVAL '1 day'),
(130, 102, 2191, 5, 'Superb! Beautiful design and excellent craftsmanship!', 'positive', NOW() - INTERVAL '4 days'),
(130, 103, 2192, 4, 'Beautiful! Comfortable pero runs a bit small.', 'positive', NOW() - INTERVAL '7 days'),
(130, 104, 2193, 5, 'Fantastic! The material is luxurious and fits perfectly!', 'positive', NOW() - INTERVAL '11 days'),
(130, 100, 2194, 3, 'Decent quality pero expected better for the price.', 'neutral', NOW() - INTERVAL '15 days'),
(130, 101, 2195, 2, 'Disappointed. Not worth the price. Expected better.', 'negative', NOW() - INTERVAL '19 days');

-- Products 131-159 (Final Batch)
INSERT INTO product_reviews (product_id, buyer_id, order_id, rating, review_text, sentiment, created_at) VALUES
(131, 102, 2196, 5, 'Incredible! Best quality I have seen. Absolutely love it!', 'positive', NOW() - INTERVAL '2 days'),
(131, 103, 2197, 5, 'Sobrang ganda! Perfect quality and very comfortable. Love it!', 'positive', NOW() - INTERVAL '5 days'),
(131, 104, 2198, 4, 'Very good! Quality is great pero a bit pricey.', 'positive', NOW() - INTERVAL '8 days'),
(131, 100, 2199, 5, 'Best purchase ever! Ang ganda ng quality. Highly recommended!', 'positive', NOW() - INTERVAL '12 days'),
(131, 101, 2200, 3, 'Okay. Nice pero the fit is not perfect.', 'neutral', NOW() - INTERVAL '16 days'),
(132, 102, 2201, 5, 'Amazing! The fabric is premium and the fit is perfect!', 'positive', NOW() - INTERVAL '3 days'),
(132, 103, 2202, 5, 'Excellent quality! Love the design and very comfortable to wear!', 'positive', NOW() - INTERVAL '6 days'),
(132, 104, 2203, 4, 'Love it! Nice fabric pero need to be careful when washing.', 'positive', NOW() - INTERVAL '9 days'),
(132, 100, 2204, 5, 'Perfect! Exceeded my expectations. Will definitely buy again!', 'positive', NOW() - INTERVAL '13 days'),
(132, 101, 2205, 3, 'It is alright. Good pero nothing special.', 'neutral', NOW() - INTERVAL '17 days'),
(132, 102, 2206, 2, 'Not good. The material is not as advertised.', 'negative', NOW() - INTERVAL '21 days'),
(133, 103, 2207, 5, 'Love this! Ang ganda and very stylish. Worth every peso!', 'positive', NOW() - INTERVAL '1 day'),
(133, 104, 2208, 5, 'Outstanding! The quality is top-notch. Highly satisfied!', 'positive', NOW() - INTERVAL '4 days'),
(133, 100, 2209, 4, 'Very nice! Good quality pero medyo mahal lang.', 'positive', NOW() - INTERVAL '7 days'),
(133, 101, 2210, 5, 'Superb! Beautiful design and excellent craftsmanship!', 'positive', NOW() - INTERVAL '11 days'),
(133, 102, 2211, 3, 'Acceptable. Okay naman pero may minor issues.', 'neutral', NOW() - INTERVAL '15 days'),
(134, 103, 2212, 5, 'Fantastic! The material is luxurious and fits perfectly!', 'positive', NOW() - INTERVAL '2 days'),
(134, 104, 2213, 5, 'Incredible! Best quality I have seen. Absolutely love it!', 'positive', NOW() - INTERVAL '5 days'),
(134, 100, 2214, 4, 'Great purchase! Love it pero medyo matagal dumating.', 'positive', NOW() - INTERVAL '8 days'),
(134, 101, 2215, 5, 'Sobrang ganda! Perfect quality and very comfortable. Love it!', 'positive', NOW() - INTERVAL '12 days'),
(134, 102, 2216, 3, 'It is decent. Good quality pero expected more.', 'neutral', NOW() - INTERVAL '16 days'),
(135, 103, 2217, 5, 'Best purchase ever! Ang ganda ng quality. Highly recommended!', 'positive', NOW() - INTERVAL '3 days'),
(135, 104, 2218, 5, 'Amazing! The fabric is premium and the fit is perfect!', 'positive', NOW() - INTERVAL '6 days'),
(135, 100, 2219, 4, 'Beautiful! Comfortable pero runs a bit small.', 'positive', NOW() - INTERVAL '9 days'),
(135, 101, 2220, 5, 'Excellent quality! Love the design and very comfortable to wear!', 'positive', NOW() - INTERVAL '13 days'),
(135, 102, 2221, 4, 'Nice! Good quality. Just wish it came in more colors.', 'positive', NOW() - INTERVAL '17 days'),
(135, 103, 2222, 3, 'Fair. Good pero the color is different from photos.', 'neutral', NOW() - INTERVAL '21 days'),
(136, 104, 2223, 5, 'Perfect! Exceeded my expectations. Will definitely buy again!', 'positive', NOW() - INTERVAL '1 day'),
(136, 100, 2224, 5, 'Love this! Ang ganda and very stylish. Worth every peso!', 'positive', NOW() - INTERVAL '4 days'),
(136, 101, 2225, 4, 'Very good! Quality is great pero a bit pricey.', 'positive', NOW() - INTERVAL '7 days'),
(136, 102, 2226, 5, 'Outstanding! The quality is top-notch. Highly satisfied!', 'positive', NOW() - INTERVAL '11 days'),
(136, 103, 2227, 3, 'Decent quality pero expected better for the price.', 'neutral', NOW() - INTERVAL '15 days'),
(136, 104, 2228, 2, 'Unsatisfied. The product has defects.', 'negative', NOW() - INTERVAL '19 days'),
(137, 100, 2229, 5, 'Superb! Beautiful design and excellent craftsmanship!', 'positive', NOW() - INTERVAL '2 days'),
(137, 101, 2230, 5, 'Fantastic! The material is luxurious and fits perfectly!', 'positive', NOW() - INTERVAL '5 days'),
(137, 102, 2231, 4, 'Love it! Nice fabric pero need to be careful when washing.', 'positive', NOW() - INTERVAL '8 days'),
(137, 103, 2232, 5, 'Incredible! Best quality I have seen. Absolutely love it!', 'positive', NOW() - INTERVAL '12 days'),
(137, 104, 2233, 3, 'Okay naman. Nice pero nothing extraordinary for the price.', 'neutral', NOW() - INTERVAL '16 days'),
(138, 100, 2234, 5, 'Sobrang ganda! Perfect quality and very comfortable. Love it!', 'positive', NOW() - INTERVAL '3 days'),
(138, 101, 2235, 5, 'Best purchase ever! Ang ganda ng quality. Highly recommended!', 'positive', NOW() - INTERVAL '6 days'),
(138, 102, 2236, 4, 'Very nice! Good quality pero medyo mahal lang.', 'positive', NOW() - INTERVAL '9 days'),
(138, 103, 2237, 5, 'Amazing! The fabric is premium and the fit is perfect!', 'positive', NOW() - INTERVAL '13 days'),
(138, 104, 2238, 3, 'Okay. Nice pero the fit is not perfect.', 'neutral', NOW() - INTERVAL '17 days'),
(138, 100, 2239, 2, 'Disappointed. The quality is not as described.', 'negative', NOW() - INTERVAL '21 days'),
(139, 101, 2240, 5, 'Excellent quality! Love the design and very comfortable to wear!', 'positive', NOW() - INTERVAL '1 day'),
(139, 102, 2241, 5, 'Perfect! Exceeded my expectations. Will definitely buy again!', 'positive', NOW() - INTERVAL '4 days'),
(139, 103, 2242, 4, 'Great purchase! Love it pero medyo matagal dumating.', 'positive', NOW() - INTERVAL '7 days'),
(139, 104, 2243, 5, 'Love this! Ang ganda and very stylish. Worth every peso!', 'positive', NOW() - INTERVAL '11 days'),
(139, 100, 2244, 3, 'It is alright. Good pero nothing special.', 'neutral', NOW() - INTERVAL '15 days'),
(140, 101, 2245, 5, 'Outstanding! The quality is top-notch. Highly satisfied!', 'positive', NOW() - INTERVAL '2 days'),
(140, 102, 2246, 5, 'Superb! Beautiful design and excellent craftsmanship!', 'positive', NOW() - INTERVAL '5 days'),
(140, 103, 2247, 4, 'Beautiful! Comfortable pero runs a bit small.', 'positive', NOW() - INTERVAL '8 days'),
(140, 104, 2248, 5, 'Fantastic! The material is luxurious and fits perfectly!', 'positive', NOW() - INTERVAL '12 days'),
(140, 100, 2249, 4, 'Excellent! Love the design. Only issue is the sizing.', 'positive', NOW() - INTERVAL '16 days'),
(140, 101, 2250, 3, 'Acceptable. Okay naman pero may minor issues.', 'neutral', NOW() - INTERVAL '20 days');

-- Products 141-159 (Last Products)
INSERT INTO product_reviews (product_id, buyer_id, order_id, rating, review_text, sentiment, created_at) VALUES
(141, 102, 2251, 5, 'Incredible! Best quality I have seen. Absolutely love it!', 'positive', NOW() - INTERVAL '3 days'),
(141, 103, 2252, 5, 'Sobrang ganda! Perfect quality and very comfortable. Love it!', 'positive', NOW() - INTERVAL '6 days'),
(141, 104, 2253, 4, 'Very good! Quality is great pero a bit pricey.', 'positive', NOW() - INTERVAL '9 days'),
(141, 100, 2254, 5, 'Best purchase ever! Ang ganda ng quality. Highly recommended!', 'positive', NOW() - INTERVAL '13 days'),
(141, 101, 2255, 3, 'Fair. Good pero the color is different from photos.', 'neutral', NOW() - INTERVAL '17 days'),
(142, 102, 2256, 5, 'Amazing! The fabric is premium and the fit is perfect!', 'positive', NOW() - INTERVAL '1 day'),
(142, 103, 2257, 5, 'Excellent quality! Love the design and very comfortable to wear!', 'positive', NOW() - INTERVAL '4 days'),
(142, 104, 2258, 4, 'Love it! Nice fabric pero need to be careful when washing.', 'positive', NOW() - INTERVAL '7 days'),
(142, 100, 2259, 5, 'Perfect! Exceeded my expectations. Will definitely buy again!', 'positive', NOW() - INTERVAL '11 days'),
(142, 101, 2260, 3, 'Decent quality pero expected better for the price.', 'neutral', NOW() - INTERVAL '15 days'),
(142, 102, 2261, 2, 'Not satisfied. The fabric is cheap and poor quality.', 'negative', NOW() - INTERVAL '19 days'),
(143, 103, 2262, 5, 'Love this! Ang ganda and very stylish. Worth every peso!', 'positive', NOW() - INTERVAL '2 days'),
(143, 104, 2263, 5, 'Outstanding! The quality is top-notch. Highly satisfied!', 'positive', NOW() - INTERVAL '5 days'),
(143, 100, 2264, 4, 'Very nice! Good quality pero medyo mahal lang.', 'positive', NOW() - INTERVAL '8 days'),
(143, 101, 2265, 5, 'Superb! Beautiful design and excellent craftsmanship!', 'positive', NOW() - INTERVAL '12 days'),
(143, 102, 2266, 3, 'Okay. Nice pero the fit is not perfect.', 'neutral', NOW() - INTERVAL '16 days'),
(144, 103, 2267, 5, 'Fantastic! The material is luxurious and fits perfectly!', 'positive', NOW() - INTERVAL '3 days'),
(144, 104, 2268, 5, 'Incredible! Best quality I have seen. Absolutely love it!', 'positive', NOW() - INTERVAL '6 days'),
(144, 100, 2269, 4, 'Great purchase! Love it pero medyo matagal dumating.', 'positive', NOW() - INTERVAL '9 days'),
(144, 101, 2270, 5, 'Sobrang ganda! Perfect quality and very comfortable. Love it!', 'positive', NOW() - INTERVAL '13 days'),
(144, 102, 2271, 3, 'It is alright. Good pero nothing special.', 'neutral', NOW() - INTERVAL '17 days'),
(145, 103, 2272, 5, 'Best purchase ever! Ang ganda ng quality. Highly recommended!', 'positive', NOW() - INTERVAL '1 day'),
(145, 104, 2273, 5, 'Amazing! The fabric is premium and the fit is perfect!', 'positive', NOW() - INTERVAL '4 days'),
(145, 100, 2274, 4, 'Beautiful! Comfortable pero runs a bit small.', 'positive', NOW() - INTERVAL '7 days'),
(145, 101, 2275, 5, 'Excellent quality! Love the design and very comfortable to wear!', 'positive', NOW() - INTERVAL '11 days'),
(145, 102, 2276, 4, 'Nice! Good quality. Just wish it came in more colors.', 'positive', NOW() - INTERVAL '15 days'),
(145, 103, 2277, 3, 'Okay naman. Nice pero nothing extraordinary for the price.', 'neutral', NOW() - INTERVAL '19 days'),
(146, 104, 2278, 5, 'Perfect! Exceeded my expectations. Will definitely buy again!', 'positive', NOW() - INTERVAL '2 days'),
(146, 100, 2279, 5, 'Love this! Ang ganda and very stylish. Worth every peso!', 'positive', NOW() - INTERVAL '5 days'),
(146, 101, 2280, 4, 'Very good! Quality is great pero a bit pricey.', 'positive', NOW() - INTERVAL '8 days'),
(146, 102, 2281, 5, 'Outstanding! The quality is top-notch. Highly satisfied!', 'positive', NOW() - INTERVAL '12 days'),
(146, 103, 2282, 3, 'It is decent. Good quality pero expected more.', 'neutral', NOW() - INTERVAL '16 days'),
(146, 104, 2283, 2, 'Poor quality. The stitching has issues.', 'negative', NOW() - INTERVAL '20 days'),
(147, 100, 2284, 5, 'Superb! Beautiful design and excellent craftsmanship!', 'positive', NOW() - INTERVAL '3 days'),
(147, 101, 2285, 5, 'Fantastic! The material is luxurious and fits perfectly!', 'positive', NOW() - INTERVAL '6 days'),
(147, 102, 2286, 4, 'Love it! Nice fabric pero need to be careful when washing.', 'positive', NOW() - INTERVAL '9 days'),
(147, 103, 2287, 5, 'Incredible! Best quality I have seen. Absolutely love it!', 'positive', NOW() - INTERVAL '13 days'),
(147, 104, 2288, 3, 'Acceptable. Okay naman pero may minor issues.', 'neutral', NOW() - INTERVAL '17 days'),
(148, 100, 2289, 5, 'Sobrang ganda! Perfect quality and very comfortable. Love it!', 'positive', NOW() - INTERVAL '1 day'),
(148, 101, 2290, 5, 'Best purchase ever! Ang ganda ng quality. Highly recommended!', 'positive', NOW() - INTERVAL '4 days'),
(148, 102, 2291, 4, 'Very nice! Good quality pero medyo mahal lang.', 'positive', NOW() - INTERVAL '7 days'),
(148, 103, 2292, 5, 'Amazing! The fabric is premium and the fit is perfect!', 'positive', NOW() - INTERVAL '11 days'),
(148, 104, 2293, 3, 'Fair. Good pero the color is different from photos.', 'neutral', NOW() - INTERVAL '15 days'),
(148, 100, 2294, 2, 'Disappointed. Not worth the price. Expected better.', 'negative', NOW() - INTERVAL '19 days'),
(149, 101, 2295, 5, 'Excellent quality! Love the design and very comfortable to wear!', 'positive', NOW() - INTERVAL '2 days'),
(149, 102, 2296, 5, 'Perfect! Exceeded my expectations. Will definitely buy again!', 'positive', NOW() - INTERVAL '5 days'),
(149, 103, 2297, 4, 'Great purchase! Love it pero medyo matagal dumating.', 'positive', NOW() - INTERVAL '8 days'),
(149, 104, 2298, 5, 'Love this! Ang ganda and very stylish. Worth every peso!', 'positive', NOW() - INTERVAL '12 days'),
(149, 100, 2299, 3, 'Decent quality pero expected better for the price.', 'neutral', NOW() - INTERVAL '16 days'),
(150, 101, 2300, 5, 'Outstanding! The quality is top-notch. Highly satisfied!', 'positive', NOW() - INTERVAL '3 days'),
(150, 102, 2301, 5, 'Superb! Beautiful design and excellent craftsmanship!', 'positive', NOW() - INTERVAL '6 days'),
(150, 103, 2302, 4, 'Beautiful! Comfortable pero runs a bit small.', 'positive', NOW() - INTERVAL '9 days'),
(150, 104, 2303, 5, 'Fantastic! The material is luxurious and fits perfectly!', 'positive', NOW() - INTERVAL '13 days'),
(150, 100, 2304, 4, 'Excellent! Love the design. Only issue is the sizing.', 'positive', NOW() - INTERVAL '17 days'),
(150, 101, 2305, 3, 'Okay. Nice pero the fit is not perfect.', 'neutral', NOW() - INTERVAL '21 days'),
(151, 102, 2306, 5, 'Incredible! Best quality I have seen. Absolutely love it!', 'positive', NOW() - INTERVAL '1 day'),
(151, 103, 2307, 5, 'Sobrang ganda! Perfect quality and very comfortable. Love it!', 'positive', NOW() - INTERVAL '4 days'),
(151, 104, 2308, 4, 'Very good! Quality is great pero a bit pricey.', 'positive', NOW() - INTERVAL '7 days'),
(151, 100, 2309, 5, 'Best purchase ever! Ang ganda ng quality. Highly recommended!', 'positive', NOW() - INTERVAL '11 days'),
(151, 101, 2310, 3, 'It is alright. Good pero nothing special.', 'neutral', NOW() - INTERVAL '15 days'),
(151, 102, 2311, 2, 'Not good. The material is not as advertised.', 'negative', NOW() - INTERVAL '19 days'),
(152, 103, 2312, 5, 'Amazing! The fabric is premium and the fit is perfect!', 'positive', NOW() - INTERVAL '2 days'),
(152, 104, 2313, 5, 'Excellent quality! Love the design and very comfortable to wear!', 'positive', NOW() - INTERVAL '5 days'),
(152, 100, 2314, 4, 'Love it! Nice fabric pero need to be careful when washing.', 'positive', NOW() - INTERVAL '8 days'),
(152, 101, 2315, 5, 'Perfect! Exceeded my expectations. Will definitely buy again!', 'positive', NOW() - INTERVAL '12 days'),
(152, 102, 2316, 3, 'Okay naman. Nice pero nothing extraordinary for the price.', 'neutral', NOW() - INTERVAL '16 days'),
(153, 103, 2317, 5, 'Love this! Ang ganda and very stylish. Worth every peso!', 'positive', NOW() - INTERVAL '3 days'),
(153, 104, 2318, 5, 'Outstanding! The quality is top-notch. Highly satisfied!', 'positive', NOW() - INTERVAL '6 days'),
(153, 100, 2319, 4, 'Very nice! Good quality pero medyo mahal lang.', 'positive', NOW() - INTERVAL '9 days'),
(153, 101, 2320, 5, 'Superb! Beautiful design and excellent craftsmanship!', 'positive', NOW() - INTERVAL '13 days'),
(153, 102, 2321, 3, 'It is decent. Good quality pero expected more.', 'neutral', NOW() - INTERVAL '17 days'),
(153, 103, 2322, 2, 'Unsatisfied. The product has defects.', 'negative', NOW() - INTERVAL '21 days'),
(154, 104, 2323, 5, 'Fantastic! The material is luxurious and fits perfectly!', 'positive', NOW() - INTERVAL '1 day'),
(154, 100, 2324, 5, 'Incredible! Best quality I have seen. Absolutely love it!', 'positive', NOW() - INTERVAL '4 days'),
(154, 101, 2325, 4, 'Great purchase! Love it pero medyo matagal dumating.', 'positive', NOW() - INTERVAL '7 days'),
(154, 102, 2326, 5, 'Sobrang ganda! Perfect quality and very comfortable. Love it!', 'positive', NOW() - INTERVAL '11 days'),
(154, 103, 2327, 4, 'Nice! Good quality. Just wish it came in more colors.', 'positive', NOW() - INTERVAL '15 days'),
(154, 104, 2328, 3, 'Acceptable. Okay naman pero may minor issues.', 'neutral', NOW() - INTERVAL '19 days'),
(155, 100, 2329, 5, 'Best purchase ever! Ang ganda ng quality. Highly recommended!', 'positive', NOW() - INTERVAL '2 days'),
(155, 101, 2330, 5, 'Amazing! The fabric is premium and the fit is perfect!', 'positive', NOW() - INTERVAL '5 days'),
(155, 102, 2331, 4, 'Beautiful! Comfortable pero runs a bit small.', 'positive', NOW() - INTERVAL '8 days'),
(155, 103, 2332, 5, 'Excellent quality! Love the design and very comfortable to wear!', 'positive', NOW() - INTERVAL '12 days'),
(155, 104, 2333, 3, 'Fair. Good pero the color is different from photos.', 'neutral', NOW() - INTERVAL '16 days'),
(155, 100, 2334, 2, 'Disappointed. The quality is not as described.', 'negative', NOW() - INTERVAL '20 days'),
(156, 101, 2335, 5, 'Perfect! Exceeded my expectations. Will definitely buy again!', 'positive', NOW() - INTERVAL '3 days'),
(156, 102, 2336, 5, 'Love this! Ang ganda and very stylish. Worth every peso!', 'positive', NOW() - INTERVAL '6 days'),
(156, 103, 2337, 4, 'Very good! Quality is great pero a bit pricey.', 'positive', NOW() - INTERVAL '9 days'),
(156, 104, 2338, 5, 'Outstanding! The quality is top-notch. Highly satisfied!', 'positive', NOW() - INTERVAL '13 days'),
(156, 100, 2339, 3, 'Decent quality pero expected better for the price.', 'neutral', NOW() - INTERVAL '17 days'),
(157, 101, 2340, 5, 'Superb! Beautiful design and excellent craftsmanship!', 'positive', NOW() - INTERVAL '1 day'),
(157, 102, 2341, 5, 'Fantastic! The material is luxurious and fits perfectly!', 'positive', NOW() - INTERVAL '4 days'),
(157, 103, 2342, 4, 'Love it! Nice fabric pero need to be careful when washing.', 'positive', NOW() - INTERVAL '7 days'),
(157, 104, 2343, 5, 'Incredible! Best quality I have seen. Absolutely love it!', 'positive', NOW() - INTERVAL '11 days'),
(157, 100, 2344, 3, 'Okay. Nice pero the fit is not perfect.', 'neutral', NOW() - INTERVAL '15 days'),
(157, 101, 2345, 2, 'Poor quality. The stitching has issues.', 'negative', NOW() - INTERVAL '19 days'),
(158, 102, 2346, 5, 'Sobrang ganda! Perfect quality and very comfortable. Love it!', 'positive', NOW() - INTERVAL '2 days'),
(158, 103, 2347, 5, 'Best purchase ever! Ang ganda ng quality. Highly recommended!', 'positive', NOW() - INTERVAL '5 days'),
(158, 104, 2348, 4, 'Very nice! Good quality pero medyo mahal lang.', 'positive', NOW() - INTERVAL '8 days'),
(158, 100, 2349, 5, 'Amazing! The fabric is premium and the fit is perfect!', 'positive', NOW() - INTERVAL '12 days'),
(158, 101, 2350, 3, 'It is alright. Good pero nothing special.', 'neutral', NOW() - INTERVAL '16 days'),
(159, 102, 2351, 5, 'Excellent quality! Love the design and very comfortable to wear!', 'positive', NOW() - INTERVAL '3 days'),
(159, 103, 2352, 5, 'Perfect! Exceeded my expectations. Will definitely buy again!', 'positive', NOW() - INTERVAL '6 days'),
(159, 104, 2353, 4, 'Great purchase! Love it pero medyo matagal dumating.', 'positive', NOW() - INTERVAL '9 days'),
(159, 100, 2354, 5, 'Love this! Ang ganda and very stylish. Worth every peso!', 'positive', NOW() - INTERVAL '13 days'),
(159, 101, 2355, 4, 'Nice! Good quality. Just wish it came in more colors.', 'positive', NOW() - INTERVAL '17 days'),
(159, 102, 2356, 3, 'Okay naman. Nice pero nothing extraordinary for the price.', 'neutral', NOW() - INTERVAL '21 days');

-- ============================================
-- SUMMARY
-- ============================================
-- Total Products: 62 (Products 41, 42, 100-159)
-- Total Reviews: ~370 reviews
-- Distribution: ~70% Positive, ~20% Neutral, ~10% Negative
-- Languages: English, Tagalog, Taglish mix
-- ============================================
-- 
-- TO USE THIS FILE:
-- 1. Open your Supabase Dashboard
-- 2. Go to SQL Editor
-- 3. Copy and paste this entire file
-- 4. Click "Run" to insert all reviews
-- 5. Check your product_detail_screen to see sentiment analysis!
-- ============================================
