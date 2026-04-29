#!/usr/bin/env python3
"""
Insert support tickets into Snowflake Postgres.
Pulls customer_ids from Snowflake RAW tables to ensure data consistency.
"""
import json
import os
import psycopg2
import random
from datetime import datetime, timedelta

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

categories = ['Shipping', 'Product Quality', 'Returns', 'Billing', 'Technical Support', 'Order Status', 'Account Issues', 'General Inquiry']
priorities = ['Low', 'Medium', 'High', 'Urgent']
statuses = ['Open', 'In Progress', 'Resolved', 'Closed']

# Negative/Complaint tickets
negative_tickets = [
    {
        'subject': 'Order never arrived - very frustrated',
        'description': """I placed an order two weeks ago and it still hasn't arrived. The tracking information hasn't updated in over a week and shows the package stuck at a distribution center. I've tried contacting shipping support multiple times with no resolution. This is completely unacceptable for the premium shipping I paid for. I needed this gear for my ski trip which I've now had to postpone. I'm extremely disappointed with this level of service and am considering disputing the charge with my credit card company if this isn't resolved immediately. Please escalate this issue and provide a concrete solution.""",
        'resolution': """Investigated shipping issue and found package was lost in transit. Issued full refund for shipping costs and expedited a replacement order with overnight delivery at no additional charge. Provided 20% discount code for future purchase as compensation for the inconvenience. Customer confirmed receipt of replacement order.""",
        'category': 'Shipping'
    },
    {
        'subject': 'Product arrived damaged - requesting refund',
        'description': """The ski boots I ordered arrived with significant damage to the outer shell. There are visible cracks near the buckle area and scuff marks all over. The box was also crushed which suggests mishandling during shipping. I took photos of everything before opening further. This is a $450 product and I expected it to arrive in perfect condition. I want a full refund processed immediately and a return label sent to me. I don't want a replacement as I've lost confidence in the shipping process. Very disappointed with my first purchase from this company.""",
        'resolution': """Reviewed customer photos confirming product damage. Initiated immediate full refund to original payment method. Sent prepaid return label via email. Refund processed within 24 hours. Filed claim with shipping carrier for damaged goods. Offered customer 15% discount on future order which they accepted.""",
        'category': 'Product Quality'
    },
    {
        'subject': 'Charged twice for same order',
        'description': """I checked my credit card statement and noticed I was charged twice for the same order. The order number is the same but there are two separate charges on my account for the full amount. This has put me over my credit limit and caused additional fees. I need one of these charges reversed immediately. I've attached screenshots of my credit card statement showing the duplicate charges. This is a serious billing error that needs urgent attention. Please process the refund as soon as possible and confirm once completed.""",
        'resolution': """Verified duplicate charge in payment system due to processing error. Submitted immediate refund request for duplicate charge. Refund processed within 2 business days. Contacted customer to confirm refund appeared on statement. Offered $25 store credit for inconvenience caused by the billing error.""",
        'category': 'Billing'
    },
    {
        'subject': 'Defective bindings - safety concern',
        'description': """The snowboard bindings I purchased have a serious defect. The ratchet mechanism on one binding keeps slipping and won't hold tension properly. This is a major safety issue as my boot came loose while riding yesterday and I nearly had a serious accident. I've only used these bindings three times and they should not be failing like this. I need an immediate replacement or refund. This type of defect should have been caught in quality control. I'm very concerned about the safety standards of your products after this experience.""",
        'resolution': """Escalated as safety priority issue. Arranged immediate replacement with expedited shipping at no cost. Requested defective bindings be returned for quality analysis. Engineering team notified of potential batch defect. Full replacement delivered within 48 hours. Follow-up call confirmed new bindings functioning properly. Added customer to priority support list.""",
        'category': 'Product Quality'
    },
    {
        'subject': 'Return rejected unfairly',
        'description': """My return request was rejected and I'm disputing this decision. I returned the ski poles within the 30-day window as stated in your policy. The items were unused and in original packaging. Now I'm being told the return is rejected because of "signs of use" which is absolutely false. I have photos proving the items were never used. This feels like a scam to avoid honoring your return policy. I demand someone review this decision and process my refund immediately. If this isn't resolved, I will be filing a complaint with consumer protection.""",
        'resolution': """Reviewed return case with warehouse team. Upon re-inspection, confirmed items were indeed in new condition. Original rejection was made in error. Processed full refund and sent apology email to customer. Updated return inspection procedures to prevent similar issues. Customer satisfied with resolution.""",
        'category': 'Returns'
    }
]

# Positive/Resolved tickets  
positive_tickets = [
    {
        'subject': 'Thank you for great service!',
        'description': """I just wanted to reach out and thank your customer service team for the amazing help I received yesterday. I had questions about sizing for ski boots and the representative spent over 30 minutes helping me find the perfect fit. They even followed up with an email containing additional sizing tips. The boots arrived today and fit perfectly! This level of service is rare these days and I wanted to make sure management knows how impressed I am. I'll definitely be a repeat customer.""",
        'resolution': """Thanked customer for positive feedback. Forwarded compliment to relevant team member and their supervisor. Added note to customer profile for recognition. No further action required - ticket closed as positive feedback.""",
        'category': 'General Inquiry'
    },
    {
        'subject': 'Quick question about product care',
        'description': """Hi there! I recently purchased the All-Mountain Skis and I'm loving them so far. I have a quick question about maintenance - how often should I wax them and is there a specific wax type you recommend? Also, any tips for storing them during the off-season? I want to make sure I take proper care of them so they last for many seasons. Thanks in advance for any guidance you can provide!""",
        'resolution': """Provided detailed ski maintenance guide via email including waxing frequency recommendations (every 4-6 days of use), recommended wax types for different conditions, and proper off-season storage tips. Customer thanked us for the thorough response. Ticket resolved.""",
        'category': 'General Inquiry'
    },
    {
        'subject': 'Loyalty program inquiry',
        'description': """I've made several purchases over the past year and was wondering if you have any loyalty or rewards program I could join. I really enjoy your products and plan to continue shopping here for all my winter sports needs. If there's a program that offers discounts or early access to new products, I'd love to sign up. Also interested in knowing if there are any referral bonuses since I've already recommended your store to several friends.""",
        'resolution': """Enrolled customer in VIP rewards program with immediate 10% discount on next purchase. Explained tier benefits and point accumulation system. Provided referral code that gives both referrer and new customer 15% off. Customer very pleased with program benefits. Ticket closed.""",
        'category': 'Account Issues'
    },
    {
        'subject': 'Order arrived early - impressed!',
        'description': """Just wanted to let you know my order arrived two days earlier than expected! Everything was packed perfectly and the products look even better in person than on the website. The ski goggles have amazing clarity and the helmet fits like a glove. I was worried about ordering gear online without trying it first, but your sizing guides were spot on. Keep up the great work! Already browsing for my next purchase.""",
        'resolution': """Thanked customer for positive feedback. Shared feedback with fulfillment and product teams. Offered early access to upcoming seasonal sale as appreciation. No issues to resolve - closed as positive customer experience.""",
        'category': 'Order Status'
    },
    {
        'subject': 'Easy return process - thank you',
        'description': """I wanted to compliment your returns process. I needed to exchange my snowboard boots for a different size and the whole process was incredibly smooth. The return label was easy to print, the exchange was processed quickly, and my new boots arrived within a week. Many companies make returns difficult but you've made it hassle-free. This kind of customer-friendly policy is why I'll keep shopping with you. Thanks for making it so easy!""",
        'resolution': """Thanked customer for taking time to share positive experience. Noted feedback for customer service quality metrics. No action needed - ticket closed as positive feedback on returns process.""",
        'category': 'Returns'
    }
]

# Neutral/Inquiry tickets
neutral_tickets = [
    {
        'subject': 'Question about product compatibility',
        'description': """I currently own the Freestyle Snowboard from your store and I'm looking to upgrade my bindings. Can you tell me if the Snowboard Bindings you sell are compatible with my board? I'm specifically wondering about the mounting pattern and whether any additional hardware would be needed. Also, would you recommend these bindings for someone who does mostly park riding? Any information would be helpful before I make my purchase decision.""",
        'resolution': """Confirmed bindings compatibility with customer's existing snowboard. Provided mounting pattern specifications and confirmed no additional hardware needed. Recommended bindings as suitable for park riding with adjustable settings. Customer thanked us for information and placed order.""",
        'category': 'Technical Support'
    },
    {
        'subject': 'Checking on order status',
        'description': """Hi, I placed an order five days ago and wanted to check on the status. My order number is in the subject line. The website shows it as "processing" but I haven't received any shipping confirmation yet. I'm not in a rush, just want to make sure everything is okay with the order. Can you provide an update on when it might ship? Thanks for your help.""",
        'resolution': """Checked order status - found order was awaiting final quality check before shipping. Expedited processing and order shipped same day. Provided tracking number to customer via email. Estimated delivery in 3-5 business days. Customer satisfied with update.""",
        'category': 'Order Status'
    },
    {
        'subject': 'Size exchange request',
        'description': """I received my order of Ski Boots but they're slightly too small. I ordered size 10 but think I need a 10.5. Can you help me process an exchange? I haven't worn them outside - only tried them on indoors. I still have all original packaging and tags. Please let me know the process for exchanging and if there are any fees involved. Also wondering how long the exchange typically takes.""",
        'resolution': """Initiated size exchange process. Emailed prepaid return label to customer. Confirmed no exchange fees apply. Reserved size 10.5 in inventory to ensure availability. Advised 5-7 business day turnaround once return received. Customer proceeded with exchange.""",
        'category': 'Returns'
    },
    {
        'subject': 'Account password reset not working',
        'description': """I'm trying to reset my account password but the reset email never arrives. I've checked my spam folder and tried multiple times over the past two days. I need to access my account to check my order history and update my shipping address for an upcoming order. Can you help me reset my password manually or verify if there's an issue with my email on file? My email should be correct as I've received order confirmations before.""",
        'resolution': """Verified customer email address was correct in system. Identified temporary email delivery issue affecting some accounts. Manually triggered password reset which was received by customer. Confirmed customer able to log in and update account details. Issue resolved.""",
        'category': 'Account Issues'
    },
    {
        'subject': 'Warranty coverage question',
        'description': """I purchased ski goggles about eight months ago and the anti-fog coating seems to be wearing off faster than expected. I'm not sure if this is covered under warranty or considered normal wear. Can you clarify what the warranty covers for this product and how I would go about making a claim if eligible? I have my original receipt and order confirmation available.""",
        'resolution': """Reviewed warranty terms for ski goggles. Anti-fog coating degradation within first year is covered under manufacturer warranty. Initiated warranty claim process for customer. Requested photos of affected goggles for documentation. Approved replacement to be shipped within 5 business days. Customer satisfied with resolution.""",
        'category': 'Technical Support'
    },
    {
        'subject': 'Gift card balance inquiry',
        'description': """I received a gift card last holiday season and wanted to check the remaining balance before making a purchase. I don't see an option to check the balance on your website. The gift card number is on the physical card I have. Can you look up the balance for me or direct me to where I can check it myself? Also wondering if gift cards have an expiration date.""",
        'resolution': """Looked up gift card balance: $75.00 remaining. Confirmed gift cards do not expire. Provided instructions for checking balance online for future reference. Customer thanked us and proceeded to place order using gift card.""",
        'category': 'Billing'
    }
]


def get_snowflake_customers():
    """Query Snowflake for customer_ids."""
    print(f"Connecting to Snowflake (connection: {SNOWFLAKE_CONNECTION})...")
    sf_conn = snowflake.connector.connect(connection_name=SNOWFLAKE_CONNECTION)
    sf_cur = sf_conn.cursor()
    
    sf_cur.execute('SELECT CUSTOMER_ID FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS')
    customer_ids = [row[0] for row in sf_cur.fetchall()]
    print(f"  Found {len(customer_ids)} customers in Snowflake")
    
    sf_conn.close()
    return customer_ids


def main():
    # Get customer IDs from Snowflake
    customer_ids = get_snowflake_customers()
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
    
    # Clear existing tickets
    cur.execute('DELETE FROM support_tickets')
    print("Deleted existing support tickets")
    
    now = datetime.now()
    insert_sql = '''INSERT INTO support_tickets (customer_id, ticket_date, category, priority, subject, description, resolution, status)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)'''
    
    total_tickets = 500
    positive_count = 0
    negative_count = 0
    neutral_count = 0
    
    for i in range(total_tickets):
        if i >= len(customer_ids):
            # Reshuffle and reuse customer IDs
            random.shuffle(customer_ids)
        
        customer_id = customer_ids[i % len(customer_ids)]
        
        # Random datetime in last 30 days
        ticket_date = now - timedelta(days=random.randint(0, 30), hours=random.randint(0, 23), minutes=random.randint(0, 59))
        
        # Sentiment distribution: 40% positive, 40% neutral, 20% negative
        sentiment_roll = random.random()
        if sentiment_roll < 0.4:
            ticket = random.choice(positive_tickets)
            priority = random.choice(['Low', 'Low', 'Medium'])
            status = 'Closed'
            positive_count += 1
        elif sentiment_roll < 0.6:
            ticket = random.choice(negative_tickets)
            priority = random.choice(['High', 'Urgent', 'Medium'])
            status = random.choice(['Resolved', 'Closed', 'Closed', 'Resolved'])
            negative_count += 1
        else:
            ticket = random.choice(neutral_tickets)
            priority = random.choice(['Low', 'Medium', 'Medium', 'High'])
            status = random.choice(['Open', 'In Progress', 'Resolved', 'Closed'])
            neutral_count += 1
        
        cur.execute(insert_sql, (
            customer_id,
            ticket_date,
            ticket['category'],
            priority,
            ticket['subject'],
            ticket['description'],
            ticket['resolution'],
            status
        ))
    
    conn.commit()
    conn.close()
    
    print(f"\nInserted {total_tickets} support tickets:")
    print(f"  Negative/Complaints: {negative_count}")
    print(f"  Positive/Feedback: {positive_count}")
    print(f"  Neutral/Inquiries: {neutral_count}")


if __name__ == '__main__':
    main()
