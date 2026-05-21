"""
Script to generate comprehensive product reviews with sentiment analysis
Run this to create SQL file with reviews for all products
"""

import random
from datetime import datetime, timedelta

# Product IDs to generate reviews for
PRODUCT_IDS = [41, 42] + list(range(100, 160))  # 41, 42, 100-159

# Buyer IDs available
BUYER_IDS = [100, 101, 102, 103, 104]

# Review templates by sentiment
POSITIVE_REVIEWS_5_STAR = [
    "Sobrang ganda! Perfect quality and very comfortable. Love it!",
    "Best purchase ever! Ang ganda ng quality. Highly recommended!",
    "Amazing! The fabric is premium and the fit is perfect!",
    "Excellent quality! Love the design and very comfortable to wear!",
    "Perfect! Exceeded my expectations. Will definitely buy again!",
    "Love this! Ang ganda and very stylish. Worth every peso!",
    "Outstanding! The quality is top-notch. Highly satisfied!",
    "Superb! Beautiful design and excellent craftsmanship!",
    "Fantastic! The material is luxurious and fits perfectly!",
    "Incredible! Best quality I have seen. Absolutely love it!",
]

POSITIVE_REVIEWS_4_STAR = [
    "Very nice! Good quality pero medyo mahal lang.",
    "Great purchase! Love it pero medyo matagal dumating.",
    "Nice! Good quality. Just wish it came in more colors.",
    "Beautiful! Comfortable pero runs a bit small.",
    "Excellent! Love the design. Only issue is the sizing.",
    "Very good! Quality is great pero a bit pricey.",
    "Love it! Nice fabric pero need to be careful when washing.",
    "Great! Beautiful design pero the color is slightly different.",
]

NEUTRAL_REVIEWS = [
    "Okay naman. Nice pero nothing extraordinary for the price.",
    "It is decent. Good quality pero expected more.",
    "Okay lang. Nice pero the sizing is a bit off.",
    "Fair. Good pero the color is different from photos.",
    "Decent quality pero expected better for the price.",
    "Okay. Nice pero the fit is not perfect.",
    "It is alright. Good pero nothing special.",
    "Acceptable. Okay naman pero may minor issues.",
]

NEGATIVE_REVIEWS = [
    "Disappointed. The quality is not as described.",
    "Not satisfied. The fabric is cheap and poor quality.",
    "Not happy. The sizing is way off and uncomfortable.",
    "Poor quality. The stitching has issues.",
    "Disappointed. Not worth the price. Expected better.",
    "Not good. The material is not as advertised.",
    "Unsatisfied. The product has defects.",
]

def generate_reviews_for_product(product_id, start_order_id):
    """Generate 5-8 reviews for a product with 70-20-10 distribution"""
    num_reviews = random.randint(5, 8)
    reviews = []
    order_id = start_order_id
    
    # Calculate distribution
    num_positive = int(num_reviews * 0.7)
    num_neutral = int(num_reviews * 0.2)
    num_negative = num_reviews - num_positive - num_neutral
    
    # Ensure at least some variety
    if num_positive < 3:
        num_positive = 3
    if num_neutral == 0 and num_reviews >= 5:
        num_neutral = 1
        num_positive -= 1
    
    # Generate positive reviews (mix of 5 and 4 stars)
    for i in range(num_positive):
        buyer_id = BUYER_IDS[i % len(BUYER_IDS)]
        if i < num_positive // 2:
            rating = 5
            review_text = random.choice(POSITIVE_REVIEWS_5_STAR)
        else:
            rating = 4
            review_text = random.choice(POSITIVE_REVIEWS_4_STAR)
        
        days_ago = random.randint(1, 30)
        reviews.append((product_id, buyer_id, order_id, rating, review_text, 'positive', days_ago))
        order_id += 1
    
    # Generate neutral reviews
    for i in range(num_neutral):
        buyer_id = BUYER_IDS[(num_positive + i) % len(BUYER_IDS)]
        rating = 3
        review_text = random.choice(NEUTRAL_REVIEWS)
        days_ago = random.randint(1, 30)
        reviews.append((product_id, buyer_id, order_id, rating, review_text, 'neutral', days_ago))
        order_id += 1
    
    # Generate negative reviews
    for i in range(num_negative):
        buyer_id = BUYER_IDS[(num_positive + num_neutral + i) % len(BUYER_IDS)]
        rating = random.choice([1, 2])
        review_text = random.choice(NEGATIVE_REVIEWS)
        days_ago = random.randint(1, 30)
        reviews.append((product_id, buyer_id, order_id, rating, review_text, 'negative', days_ago))
        order_id += 1
    
    return reviews, order_id

# Generate SQL
output_file = "comprehensive_reviews_with_sentiment.sql"
with open(output_file, 'w', encoding='utf-8') as f:
    f.write("""-- ============================================
-- COMPREHENSIVE PRODUCT REVIEWS WITH SENTIMENT ANALYSIS
-- PostgreSQL/Supabase Compatible
-- ============================================
-- Distribution: ~70% Positive, ~20% Neutral, ~10% Negative
-- Products: 41, 42, 100-159 (62 products total)
-- Reviews per product: 5-8 reviews
-- Total: ~400 reviews
-- ============================================

""")
    
    order_id = 2000
    total_reviews = 0
    
    for product_id in PRODUCT_IDS:
        reviews, order_id = generate_reviews_for_product(product_id, order_id)
        total_reviews += len(reviews)
        
        f.write(f"-- Reviews for Product {product_id}\n")
        f.write("INSERT INTO product_reviews (product_id, buyer_id, order_id, rating, review_text, sentiment, created_at)\n")
        f.write("VALUES\n")
        
        for idx, (pid, bid, oid, rating, text, sentiment, days) in enumerate(reviews):
            comma = "," if idx < len(reviews) - 1 else ";"
            f.write(f"({pid}, {bid}, {oid}, {rating}, '{text}', '{sentiment}', NOW() - INTERVAL '{days} days'){comma}\n")
        
        f.write("\n")
    
    f.write(f"""-- ============================================
-- SUMMARY
-- ============================================
-- Total Products: {len(PRODUCT_IDS)}
-- Total Reviews: {total_reviews}
-- ============================================
""")

print(f"✅ Generated {total_reviews} reviews for {len(PRODUCT_IDS)} products!")
print(f"📄 File saved: {output_file}")
print("\n🚀 Run this SQL in your Supabase SQL Editor to insert all reviews!")
