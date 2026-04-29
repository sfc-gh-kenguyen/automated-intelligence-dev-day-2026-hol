import random
import uuid
from datetime import datetime, timedelta
from config import (
    MONTHLY_CONFIG, STATUS_DISTRIBUTION, SEGMENT_AOV_MULTIPLIER,
    TOTAL_ORDERS, NUM_CUSTOMERS, MONTH_DAYS
)


def pick_weighted(choices_weights):
    items = list(choices_weights.keys())
    weights = list(choices_weights.values())
    return random.choices(items, weights=weights, k=1)[0]


def generate_orders(customer_segments):
    orders = []
    order_id_counter = 0

    months = list(MONTHLY_CONFIG.keys())

    for month_key in months:
        cfg = MONTHLY_CONFIG[month_key]
        month_order_count = int(TOTAL_ORDERS * cfg["volume_pct"])
        year, month_num = month_key.split("-")
        year = int(year)
        month_num = int(month_num)
        start_day, end_day = MONTH_DAYS[month_key]

        season = cfg["season"]
        status_dist = STATUS_DISTRIBUTION.get("crash" if season == "crash" else "normal")
        seg_weights = cfg["segment_weights"]  # (Premium, Standard, Basic)
        discount_lo, discount_hi = cfg["discount_range"]

        for _ in range(month_order_count):
            order_id_counter += 1
            oid = str(uuid.uuid4())

            seg_roll = random.random()
            if seg_roll < seg_weights[0]:
                segment = "Premium"
            elif seg_roll < seg_weights[0] + seg_weights[1]:
                segment = "Standard"
            else:
                segment = "Basic"

            cust_pool = customer_segments[segment]
            customer_id = random.choice(cust_pool)

            day = random.randint(start_day, end_day)
            hour = random.randint(0, 23)
            minute = random.randint(0, 59)
            second = random.randint(0, 59)
            order_date = datetime(year, month_num, day, hour, minute, second)

            order_status = pick_weighted(status_dist)

            base_amount = random.uniform(50, 800)
            aov_mult = SEGMENT_AOV_MULTIPLIER[segment]
            if season == "peak":
                aov_mult *= random.uniform(1.1, 1.4)
            elif season == "clearance":
                aov_mult *= random.uniform(0.6, 0.85)
            total_amount = round(base_amount * aov_mult, 2)

            if segment == "Premium":
                discount = round(random.uniform(max(0, discount_lo - 3), discount_hi - 2), 2)
            elif segment == "Basic":
                discount = round(random.uniform(discount_lo + 2, min(50, discount_hi + 5)), 2)
            else:
                discount = round(random.uniform(discount_lo, discount_hi), 2)

            if random.random() > 0.6:
                discount = 0.0

            shipping = round(random.uniform(5, 35), 2)

            orders.append({
                "order_id": oid,
                "customer_id": customer_id,
                "order_date": order_date.strftime("%Y-%m-%d %H:%M:%S"),
                "order_status": order_status,
                "total_amount": total_amount,
                "discount_percent": discount,
                "shipping_cost": shipping,
                "_segment": segment,
                "_month": month_key,
                "_season": season,
            })

    return orders
