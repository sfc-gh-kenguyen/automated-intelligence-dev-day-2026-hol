#!/usr/bin/env python3
"""
DEPRECATED - Use insert_product_reviews.py and insert_support_tickets.py instead.

Those scripts:
- Pull customer_id and product_id from Snowflake RAW tables
- Generate realistic data with proper sentiment distribution
- Only require product_reviews and support_tickets tables in Postgres
"""

print("This script is deprecated.")
print()
print("Use the following scripts instead:")
print("  python insert_product_reviews.py   # Generate product reviews")
print("  python insert_support_tickets.py   # Generate support tickets")
print()
print("These scripts pull IDs from Snowflake RAW tables to ensure data consistency.")
print("Set SNOWFLAKE_CONNECTION_NAME env var to specify your connection (default: dash-builder-si)")
