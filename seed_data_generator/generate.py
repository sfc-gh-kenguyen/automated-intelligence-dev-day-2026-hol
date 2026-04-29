import csv
import os
import random
import sys
import time
from config import NUM_CUSTOMERS, PRODUCTS

SEED = 42
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "output")


def generate_customers(num_customers):
    random.seed(SEED)
    first_names = ["John", "Sarah", "Michael", "Emily", "David", "Jessica", "Chris", "Ashley",
                   "Matt", "Amanda", "Ryan", "Lauren", "Kevin", "Nicole", "Brian", "Rachel",
                   "Tyler", "Megan", "Josh", "Katie"]
    last_names = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis",
                  "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson",
                  "Thomas", "Taylor", "Moore", "Jackson", "Martin"]
    cities = ["Denver", "Salt Lake City", "Boulder", "Aspen", "Park City", "Jackson",
              "Telluride", "Steamboat Springs", "Vail", "Breckenridge", "Mammoth Lakes",
              "Tahoe City", "Whistler", "Banff", "Portland"]
    states = ["CO", "UT", "WY", "CA", "WA", "OR", "MT", "ID", "NV", "BC"]
    segments = ["Premium", "Standard", "Basic"]

    customers = []
    for i in range(1, num_customers + 1):
        state = random.choice(states)
        segment = random.choice(segments)
        reg_days_ago = random.randint(1, 1825)
        from datetime import datetime, timedelta
        reg_date = (datetime(2026, 6, 4) - timedelta(days=reg_days_ago)).strftime("%Y-%m-%d")

        customers.append({
            "customer_id": i,
            "first_name": random.choice(first_names),
            "last_name": random.choice(last_names),
            "email": f"customer{i}@email.com",
            "phone": f"555-{random.randint(100,999):03d}-{random.randint(1000,9999):04d}",
            "address": f"{random.randint(100,9999)} {random.choice(['Main St','Oak Ave','Maple Dr','Cedar Ln','Pine Rd','Elm St','Washington Blvd','Lake View Dr','Mountain Way','Summit Trail'])}",
            "city": random.choice(cities),
            "state": state,
            "zip_code": f"{random.randint(10000,99999)}",
            "registration_date": reg_date,
            "customer_segment": segment,
        })

    return customers


def main():
    random.seed(SEED)
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    print("=" * 60)
    print("HOL Seed Data Generator")
    print("=" * 60)

    print("\n[1/6] Generating 500K customers...")
    t0 = time.time()
    customers = generate_customers(NUM_CUSTOMERS)
    print(f"  Done: {len(customers):,} customers ({time.time()-t0:.1f}s)")

    customer_segments = {"Premium": [], "Standard": [], "Basic": []}
    customer_ids = []
    for c in customers:
        customer_segments[c["customer_segment"]].append(c["customer_id"])
        customer_ids.append(c["customer_id"])

    print("\n[2/6] Generating 1M orders with seasonal correlations...")
    t0 = time.time()
    from orders_generator import generate_orders
    orders = generate_orders(customer_segments)
    print(f"  Done: {len(orders):,} orders ({time.time()-t0:.1f}s)")

    print("\n[3/6] Generating order items with product seasonality...")
    t0 = time.time()
    from items_generator import generate_order_items
    items = generate_order_items(orders)
    print(f"  Done: {len(items):,} order items ({time.time()-t0:.1f}s)")

    print("\n[4/6] Generating 1200+ product reviews...")
    t0 = time.time()
    from reviews_generator import generate_reviews
    reviews = generate_reviews(customer_ids)
    print(f"  Done: {len(reviews):,} reviews ({time.time()-t0:.1f}s)")

    print("\n[5/6] Generating 1200+ support tickets...")
    t0 = time.time()
    from tickets_generator import generate_tickets
    tickets = generate_tickets(customer_ids)
    print(f"  Done: {len(tickets):,} tickets ({time.time()-t0:.1f}s)")

    print("\n[6/6] Writing CSV files...")
    t0 = time.time()

    write_csv(os.path.join(OUTPUT_DIR, "customers.csv"), customers,
              ["customer_id", "first_name", "last_name", "email", "phone", "address", "city", "state", "zip_code", "registration_date", "customer_segment"])

    write_csv(os.path.join(OUTPUT_DIR, "orders.csv"), orders,
              ["order_id", "customer_id", "order_date", "order_status", "total_amount", "discount_percent", "shipping_cost"])

    write_csv(os.path.join(OUTPUT_DIR, "order_items.csv"), items,
              ["order_item_id", "order_id", "product_id", "product_name", "product_category", "quantity", "unit_price", "line_total"])

    write_csv(os.path.join(OUTPUT_DIR, "product_catalog.csv"), PRODUCTS,
              ["id", "name", "category", "price"],
              rename={"id": "product_id", "name": "product_name", "category": "product_category", "price": "price"})

    write_csv(os.path.join(OUTPUT_DIR, "product_reviews.csv"), reviews,
              ["review_id", "product_id", "customer_id", "review_date", "rating", "review_title", "review_text", "verified_purchase"])

    write_csv(os.path.join(OUTPUT_DIR, "support_tickets.csv"), tickets,
              ["ticket_id", "customer_id", "ticket_date", "category", "priority", "subject", "description", "resolution", "status"])

    print(f"  Done ({time.time()-t0:.1f}s)")

    print("\n" + "=" * 60)
    print("VALIDATION")
    print("=" * 60)
    validate(orders, items, customers, reviews, tickets)

    print("\n" + "=" * 60)
    print(f"Output directory: {OUTPUT_DIR}")
    print("=" * 60)


def write_csv(path, data, fields, rename=None):
    with open(path, "w", newline="", encoding="utf-8") as f:
        if rename:
            writer = csv.DictWriter(f, fieldnames=list(rename.values()), quoting=csv.QUOTE_MINIMAL)
            writer.writeheader()
            for row in data:
                writer.writerow({rename[k]: row[k] for k in fields})
        else:
            writer = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore", quoting=csv.QUOTE_MINIMAL)
            writer.writeheader()
            for row in data:
                writer.writerow(row)
    size_mb = os.path.getsize(path) / (1024 * 1024)
    print(f"    {os.path.basename(path)}: {len(data):,} rows ({size_mb:.1f} MB)")


def validate(orders, items, customers, reviews, tickets):
    order_ids = {o["order_id"] for o in orders}
    item_order_ids = {i["order_id"] for i in items}
    customer_ids = {c["customer_id"] for c in customers}
    order_customer_ids = {o["customer_id"] for o in orders}

    orphan_items = item_order_ids - order_ids
    orphan_orders = order_ids - item_order_ids
    missing_customers = order_customer_ids - customer_ids

    print(f"  Orders: {len(orders):,}")
    print(f"  Order Items: {len(items):,}")
    print(f"  Avg items/order: {len(items)/len(orders):.1f}")
    print(f"  Orphan orders (no items): {len(orphan_orders)}")
    print(f"  Orphan items (no order): {len(orphan_items)}")
    print(f"  Missing customers: {len(missing_customers)}")
    print(f"  Reviews: {len(reviews):,}")
    print(f"  Tickets: {len(tickets):,}")

    from collections import Counter
    month_counts = Counter(o["_month"] for o in orders)
    print("\n  Monthly Distribution:")
    for m in sorted(month_counts.keys()):
        bar = "█" * (month_counts[m] // 5000)
        print(f"    {m}: {month_counts[m]:>7,} {bar}")

    if orphan_items or orphan_orders or missing_customers:
        print("\n  ⚠️  VALIDATION FAILED — orphans detected!")
        sys.exit(1)
    else:
        print("\n  ✓ All validations passed!")


if __name__ == "__main__":
    main()
