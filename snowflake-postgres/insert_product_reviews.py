#!/usr/bin/env python3
"""
Insert product reviews into Snowflake Postgres.
Pulls customer_ids and product_ids from Snowflake RAW tables to ensure data consistency.
"""
import json
import os
import psycopg2
import random
from datetime import date, timedelta

import snowflake.connector

# Load Postgres config
config_path = os.path.join(os.path.dirname(__file__), 'postgres_config.json')
if os.path.exists(config_path):
    with open(config_path) as f:
        config = json.load(f)
    POSTGRES_HOST = config.get('host')
    POSTGRES_PORT = config.get('port', 5432)
    POSTGRES_DB = config.get('database', 'postgres')
    POSTGRES_USER = config.get('user')
    POSTGRES_PASSWORD = config.get('password')
else:
    POSTGRES_HOST = os.getenv('POSTGRES_HOST')
    POSTGRES_PORT = int(os.getenv('POSTGRES_PORT', '5432'))
    POSTGRES_DB = os.getenv('POSTGRES_DB', 'postgres')
    POSTGRES_USER = os.getenv('POSTGRES_USER')
    POSTGRES_PASSWORD = os.getenv('POSTGRES_PASSWORD')

if not POSTGRES_PASSWORD:
    raise ValueError('postgres_config.json not found and POSTGRES_PASSWORD env var not set.')

# Snowflake connection name
SNOWFLAKE_CONNECTION = os.getenv('SNOWFLAKE_CONNECTION_NAME', 'dash-builder-si')

positive_reviews = [
    """I absolutely love this product! After using it for several weeks now, I can confidently say it exceeded all my expectations. The build quality is exceptional and you can tell a lot of thought went into the design. It performs flawlessly in all conditions I've tested it in. The comfort level is outstanding and I never feel fatigued even after extended use. I've recommended this to all my friends and family who are into winter sports. The price point is very reasonable considering the quality you get. Customer service was also very helpful when I had questions. This is definitely a top-tier product that I would purchase again without hesitation. Five stars all the way!""",
    """What an amazing purchase this turned out to be! I was initially hesitant given the price but decided to take the plunge and I'm so glad I did. From the moment I unboxed it, I could see the attention to detail. The materials feel premium and durable. Performance on the mountain has been incredible - it handles everything I throw at it with ease. My skills have actually improved since switching to this product. The fit is perfect and the adjustability options are great. I've used it in various weather conditions and it performs consistently well. Highly recommend to anyone serious about their winter sports gear. This brand has earned a loyal customer!""",
    """This is hands down the best purchase I've made for my winter sports setup! The quality is superb and it shows in every detail. I've been using it regularly for the past month and it still looks and performs like new. The engineering behind this product is evident - it's lightweight yet sturdy, responsive yet forgiving. I compared it extensively with competitors before buying and this one came out on top in every category that mattered to me. The value for money is excellent. Setup was straightforward and the included instructions were clear. I'm already planning to buy more gear from this brand based on this experience. Absolutely stellar product!""",
    """Exceeded my expectations in every way possible! I've been skiing for over fifteen years and have tried many different brands and models. This product stands out from the crowd with its exceptional performance characteristics. The technology incorporated here makes a real difference on the slopes. I noticed improvements in my control and confidence from day one. The aesthetic design is also beautiful - I get compliments every time I'm on the mountain. Construction quality is top-notch and I expect this to last for many seasons. The brand clearly understands what serious winter sports enthusiasts need. Cannot recommend highly enough to anyone looking for premium gear!"""
]

negative_reviews = [
    """I'm quite disappointed with this purchase unfortunately. While the product looks nice, the actual performance doesn't match what was advertised. I've had issues from the very first day of use. The fit was uncomfortable and no amount of adjustment seemed to help. After a few sessions, I noticed wear and tear that shouldn't happen so quickly on a product at this price point. Customer support was slow to respond to my concerns. I expected much better quality given the brand reputation and cost. The materials feel cheaper than I anticipated. I've had to make do with it for now but will definitely be looking at alternatives for my next purchase. Not recommended unless they significantly improve quality control.""",
    """Very underwhelming experience with this product. I did extensive research before buying and thought this would be perfect for my needs, but reality didn't match expectations. The product arrived with minor cosmetic defects which was already a bad start. Performance on the mountain was mediocre at best - it felt unstable in challenging conditions where I needed reliability most. The sizing chart was inaccurate which led to fit issues. For what I paid, I expected premium quality but this feels like a mid-range product at best. I've reached out to customer service multiple times with limited success. Will be returning this and trying a different brand. Disappointing experience overall.""",
    """Not worth the money in my opinion. I was drawn in by positive reviews and marketing but my personal experience has been frustrating. The product developed problems within just a few weeks of moderate use. Build quality is questionable - I can see areas where corners were cut in manufacturing. The performance is inconsistent and I never feel fully confident when using it. Compared to my previous gear from a different brand, this is a clear downgrade despite costing more. I've tried working with the warranty department but the process is tedious. I would caution others to look carefully at alternatives before committing to this purchase. Lesson learned for me.""",
    """Regret this purchase entirely. The product simply doesn't live up to the hype. Within the first month, I encountered multiple issues that shouldn't happen with supposedly premium gear. The materials feel flimsy and I'm concerned about long-term durability. Performance is below average and I've noticed a decline in my overall experience on the mountain since switching to this. The ergonomics are poor and lead to discomfort during extended sessions. I tried contacting customer support but wait times were excessive. At this price point, I expected excellence but received mediocrity. Would not recommend to friends or family. Looking to sell this and recoup some of my investment."""
]

neutral_reviews = [
    """This product is decent but nothing extraordinary. It does what it's supposed to do without any major issues, but also without any wow factor. The build quality is acceptable for the price range. I've used it several times now and it performs adequately in most conditions. There are some minor inconveniences with the design that could be improved. The fit took some getting used to but eventually became comfortable. I think for beginners or casual enthusiasts, this would be a fine choice. More serious athletes might want to look at higher-end options though. Customer service was responsive when I had questions. Overall a fair product that meets basic expectations without exceeding them. Average rating seems appropriate.""",
    """Middle of the road product in my assessment. There are things I like about it and things I wish were better. On the positive side, the aesthetics are nice and initial setup was easy. Performance is consistent if unspectacular. On the negative side, I feel like some features advertised aren't as impactful as claimed. The price is reasonable but I'm not sure if I got great value. I've had no major problems but also no moments where I was impressed. It's a safe choice if you don't want to take risks, but won't blow you away either. Durability seems okay so far though time will tell. Would consider other options if purchasing again but no strong feelings either way.""",
    """Solid but unremarkable describes my experience with this product. It functions as expected without any surprises good or bad. The quality is what you'd expect at this price point - not premium but not cheap either. I've used it in various conditions and it holds up reasonably well. There are small design choices I'd change if I could, but nothing deal-breaking. Comfort is adequate after a brief adjustment period. I compared this with a friend's gear from another brand and honestly they seem quite similar in real-world performance. If you need something reliable without breaking the bank, this fits the bill. Just don't expect to be amazed. Three stars feels right.""",
    """Fair product with both strengths and weaknesses. I'll try to be balanced in this review. The pros include decent construction, acceptable performance, and reasonable pricing. The cons include some design quirks, average durability indicators, and nothing that really sets it apart from competitors. My experience has been neither great nor terrible - just okay. It serves its purpose on the mountain without causing problems but also without enhancing my experience significantly. I've seen better and I've seen worse. If you're looking for a middle-ground option without strong opinions either way, this could work. Customer service was average. Would give this a neutral recommendation overall."""
]

review_titles_positive = ['Absolutely Love It!', 'Best Purchase Ever', 'Exceeded Expectations', 'Highly Recommend!', 'Outstanding Quality', 'Worth Every Penny', 'Amazing Product!', 'Top Notch Gear']
review_titles_negative = ['Disappointed', 'Not Worth It', 'Would Not Recommend', 'Below Expectations', 'Quality Issues', 'Regret Purchase', 'Needs Improvement', 'Overpriced']
review_titles_neutral = ['Decent Product', 'Gets the Job Done', 'Average Experience', 'Okay Purchase', 'Middle of the Road', 'Fair Quality', 'Mixed Feelings', 'Nothing Special']


def get_snowflake_data():
    """Query Snowflake for customer_ids and products."""
    print(f"Connecting to Snowflake (connection: {SNOWFLAKE_CONNECTION})...")
    sf_conn = snowflake.connector.connect(connection_name=SNOWFLAKE_CONNECTION)
    sf_cur = sf_conn.cursor()
    
    # Get customer IDs
    sf_cur.execute('SELECT CUSTOMER_ID FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS')
    customer_ids = [row[0] for row in sf_cur.fetchall()]
    print(f"  Found {len(customer_ids)} customers in Snowflake")
    
    # Get products
    sf_cur.execute('SELECT PRODUCT_ID, PRODUCT_NAME FROM AUTOMATED_INTELLIGENCE.RAW.PRODUCT_CATALOG')
    products = sf_cur.fetchall()
    print(f"  Found {len(products)} products in Snowflake")
    
    sf_conn.close()
    return customer_ids, products


def main():
    # Get reference data from Snowflake
    customer_ids, products = get_snowflake_data()
    random.shuffle(customer_ids)
    
    # Connect to Postgres
    print(f"\nConnecting to Postgres ({POSTGRES_HOST})...")
    conn = psycopg2.connect(
        host=POSTGRES_HOST,
        port=POSTGRES_PORT,
        database=POSTGRES_DB,
        user=POSTGRES_USER,
        password=POSTGRES_PASSWORD,
        sslmode='require'
    )
    cur = conn.cursor()
    
    # Clear existing reviews
    cur.execute('DELETE FROM product_reviews')
    print(f"Deleted existing reviews")
    
    today = date.today()
    insert_sql = '''INSERT INTO product_reviews (product_id, customer_id, review_date, rating, review_title, review_text, verified_purchase)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)'''
    
    customer_idx = 0
    total_reviews = 0
    
    for product_id, product_name in products:
        num_reviews = random.randint(30, 50)
        product_reviews = 0
        
        for _ in range(num_reviews):
            if customer_idx >= len(customer_ids):
                # Reshuffle and reuse customer IDs
                random.shuffle(customer_ids)
                customer_idx = 0
            
            customer_id = customer_ids[customer_idx]
            customer_idx += 1
            
            # Random date in last 30 days
            review_date = today - timedelta(days=random.randint(0, 30))
            
            # Sentiment distribution: 65% positive, 15% negative, 20% neutral
            sentiment_roll = random.random()
            if sentiment_roll < 0.65:
                rating = random.randint(4, 5)
                review_text = random.choice(positive_reviews)
                review_title = random.choice(review_titles_positive)
            elif sentiment_roll < 0.80:
                rating = random.randint(1, 2)
                review_text = random.choice(negative_reviews)
                review_title = random.choice(review_titles_negative)
            else:
                rating = 3
                review_text = random.choice(neutral_reviews)
                review_title = random.choice(review_titles_neutral)
            
            verified = random.choice([True, True, True, False])  # 75% verified
            
            cur.execute(insert_sql, (product_id, customer_id, review_date, rating, review_title, review_text, verified))
            product_reviews += 1
            total_reviews += 1
        
        print(f"  {product_name}: {product_reviews} reviews")
    
    conn.commit()
    conn.close()
    print(f"\nTotal: {total_reviews} reviews inserted for {len(products)} products")


if __name__ == '__main__':
    main()
