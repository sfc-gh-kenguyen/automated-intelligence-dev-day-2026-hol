import random
import uuid
from config import PRODUCTS, CATEGORY_WEIGHTS_BY_SEASON, MONTHLY_CONFIG


def get_products_by_category():
    by_cat = {}
    for p in PRODUCTS:
        by_cat.setdefault(p["category"], []).append(p)
    return by_cat


PRODUCTS_BY_CATEGORY = get_products_by_category()


def generate_order_items(orders):
    items = []

    for order in orders:
        season = order["_season"]
        month_key = order["_month"]
        segment = order["_segment"]
        cfg = MONTHLY_CONFIG[month_key]

        items_lo, items_hi = cfg["items_range"]
        if segment == "Premium":
            num_items = random.randint(items_lo, items_hi + 1)
        elif segment == "Basic":
            num_items = random.randint(max(1, items_lo - 1), items_hi)
        else:
            num_items = random.randint(items_lo, items_hi)

        cat_weights = CATEGORY_WEIGHTS_BY_SEASON[season]
        categories = list(cat_weights.keys())
        weights = list(cat_weights.values())

        chosen_categories = random.choices(categories, weights=weights, k=num_items)

        for cat in chosen_categories:
            product = random.choice(PRODUCTS_BY_CATEGORY[cat])

            quantity = 1
            if segment == "Premium" and random.random() < 0.15:
                quantity = random.randint(2, 3)
            elif segment == "Basic" and random.random() < 0.05:
                quantity = 2

            price_variance = random.uniform(0.9, 1.1)
            unit_price = round(product["price"] * price_variance, 2)
            line_total = round(unit_price * quantity, 2)

            items.append({
                "order_item_id": str(uuid.uuid4()),
                "order_id": order["order_id"],
                "product_id": product["id"],
                "product_name": product["name"],
                "product_category": product["category"],
                "quantity": quantity,
                "unit_price": unit_price,
                "line_total": line_total,
            })

    return items
