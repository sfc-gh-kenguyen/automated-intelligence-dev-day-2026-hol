import random
from datetime import datetime, timedelta
from config import PRODUCTS, NUM_REVIEWS

POSITIVE_TEMPLATES = {
    "Skis": [
        ("Incredible performance", "These {product} are absolutely incredible on the mountain. The edge hold is phenomenal and they float beautifully in powder. Worth every penny."),
        ("Best skis I've owned", "After 20 years of skiing, these {product} are the best I've ever had. Responsive, stable at speed, and surprisingly light."),
        ("Perfect gift", "Bought these {product} as a holiday gift for my husband. He's been raving about them every trip. Great quality craftsmanship."),
        ("Amazing versatility", "The {product} handle everything from groomers to trees to powder. Can't believe one ski can do it all this well."),
        ("Exceeded expectations", "I was skeptical about the hype but these {product} deliver. Smooth turns, great stability, and they look fantastic."),
        ("New season favorite", "Just got these for the new season and they're already my favorites. The new construction is noticeably better than last year."),
        ("Fast and stable", "Took these {product} out in variable conditions and they crushed it. No chatter at speed, great dampening."),
    ],
    "Snowboards": [
        ("So much fun", "The {product} is an absolute blast to ride. Playful in the park but can still hold an edge on groomers."),
        ("Perfect flex", "The flex profile on this {product} is exactly right. Not too stiff, not too soft. Perfect for all-mountain riding."),
        ("Holiday present hit", "Got this for my daughter for Christmas and she absolutely loves it. Great board for intermediate to advanced riders."),
        ("Buttery smooth", "This {product} is buttery smooth on rails and boxes. The pop off jumps is insane too. Best park board I've ridden."),
        ("Charges hard", "If you want a board that charges hard in any conditions, this is it. The {product} handles steeps and crud like a dream."),
        ("Great progression board", "Moving from beginner to intermediate, this {product} has been perfect for building confidence. Very forgiving."),
    ],
    "Boots": [
        ("Perfect fit out of box", "The {product} fit perfectly right out of the box. No break-in period needed. Comfortable all day long."),
        ("Great support", "Excellent ankle support and the walk mode is a game changer for hiking to sidecountry spots. Love these {product}."),
        ("Warm and comfortable", "Spent 8 hours on the mountain and my feet were warm and comfortable the entire time. Best boots I've owned."),
        ("Easy to use", "The Boa system on these {product} makes adjustments so easy, even with gloves on. Quick in, quick out."),
        ("Worth the investment", "Spent the money on quality {product} and it makes all the difference. No more foot pain after long days."),
    ],
    "Accessories": [
        ("Crystal clear optics", "The {product} have incredible optics. Crystal clear visibility even in flat light. Anti-fog works great."),
        ("Lightweight and strong", "These {product} are incredibly lightweight but feel very durable. Great quality for the price."),
        ("Essential gear", "Can't imagine skiing without these {product} now. They make such a difference in comfort and safety."),
        ("Great value", "For the price, these {product} are unbeatable. Quality comparable to brands costing twice as much."),
        ("Solid construction", "The build quality on these {product} is impressive. Everything feels solid and well-made."),
        ("Love the features", "All the features I wanted at a great price point. The {product} exceeded my expectations."),
    ],
}

NEGATIVE_TEMPLATES = {
    "Skis": [
        ("Delaminating after 5 days", "The top sheet on these {product} started delaminating after just 5 days of use. Very disappointing for the price point."),
        ("Not as described", "These {product} are much stiffer than described. Not suitable for intermediate skiers despite the marketing claims."),
        ("Edge cracking", "Found edge cracks on these {product} after only 10 days. Quality control seems to be an issue this season."),
    ],
    "Snowboards": [
        ("Base damage out of box", "Received the {product} with a gouge in the base. Clearly a quality control issue. Had to return."),
        ("Too stiff for advertised level", "The {product} is marketed as intermediate-friendly but the flex is way too stiff. Returning."),
        ("Binding inserts stripped", "The binding inserts stripped after just two days of riding. Unacceptable quality for this price range."),
    ],
    "Boots": [
        ("Terrible sizing", "Ordered my usual size in these {product} and they're way too narrow. My feet were killing me after one run. Returning immediately."),
        ("Painful pressure points", "These {product} create terrible pressure points on the top of my foot. Tried heat molding twice, no improvement."),
        ("Sizing runs small", "WARNING: These {product} run at least a full size small. Ordered my normal size and can barely get my foot in. Gift gone wrong."),
        ("Buckle broke first day", "The third buckle on these {product} snapped on the very first day. Cheap plastic construction. Very disappointed."),
        ("Liner packed out fast", "The liner on these {product} packed out in about 8 days of skiing. Now they're too loose and I have no heel hold."),
        ("Wrong size for holiday gift", "Bought these as a Christmas gift based on the size chart and they're completely wrong. Now dealing with exchanges in January."),
        ("Cold feet guaranteed", "These {product} provide zero insulation. My feet were numb after 30 minutes in -5°C. Worthless for actual cold weather skiing."),
        ("Uncomfortable walk mode", "The walk mode on these {product} barely works. Still very stiff when hiking. Not what I expected from the description."),
    ],
    "Accessories": [
        ("Fogging issues", "Despite 'anti-fog' claims, these {product} fog up constantly. Had to wipe them every run. Useless in snowy conditions."),
        ("Broke after one fall", "These {product} broke after a single minor fall. Plastic feels very cheap. Not worth even the sale price."),
        ("Doesn't fit with helmet", "These {product} are advertised as helmet-compatible but they don't fit with any of my three helmets. Misleading."),
    ],
}

REVIEW_SEASON_SENTIMENT = {
    "peak": {"positive": 0.80, "negative": 0.20},
    "preseason": {"positive": 0.85, "negative": 0.15},
    "crash": {"positive": 0.35, "negative": 0.65},
    "shoulder": {"positive": 0.60, "negative": 0.40},
    "clearance": {"positive": 0.70, "negative": 0.30},
    "off": {"positive": 0.75, "negative": 0.25},
}

REVIEW_CATEGORY_BY_SEASON = {
    "peak": {"Skis": 0.30, "Snowboards": 0.25, "Boots": 0.15, "Accessories": 0.30},
    "preseason": {"Skis": 0.20, "Snowboards": 0.15, "Boots": 0.40, "Accessories": 0.25},
    "crash": {"Skis": 0.10, "Snowboards": 0.10, "Boots": 0.55, "Accessories": 0.25},
    "shoulder": {"Skis": 0.20, "Snowboards": 0.20, "Boots": 0.25, "Accessories": 0.35},
    "clearance": {"Skis": 0.25, "Snowboards": 0.25, "Boots": 0.15, "Accessories": 0.35},
    "off": {"Skis": 0.10, "Snowboards": 0.10, "Boots": 0.10, "Accessories": 0.70},
}

MONTH_TO_SEASON = {
    "2025-06": "off", "2025-07": "off", "2025-08": "off",
    "2025-09": "preseason", "2025-10": "preseason",
    "2025-11": "peak", "2025-12": "peak",
    "2026-01": "peak", "2026-02": "crash",
    "2026-03": "shoulder", "2026-04": "clearance",
    "2026-05": "clearance", "2026-06": "off",
}

REVIEW_VOLUME_BY_MONTH = {
    "2025-06": 0.04, "2025-07": 0.04, "2025-08": 0.05,
    "2025-09": 0.07, "2025-10": 0.08,
    "2025-11": 0.12, "2025-12": 0.14,
    "2026-01": 0.13, "2026-02": 0.12,
    "2026-03": 0.08, "2026-04": 0.06,
    "2026-05": 0.05, "2026-06": 0.02,
}


def generate_reviews(customer_ids):
    reviews = []
    review_id = 0

    products_by_cat = {}
    for p in PRODUCTS:
        products_by_cat.setdefault(p["category"], []).append(p)

    for month_key, vol_pct in REVIEW_VOLUME_BY_MONTH.items():
        month_count = max(1, int(NUM_REVIEWS * vol_pct))
        season = MONTH_TO_SEASON[month_key]
        sentiment_dist = REVIEW_SEASON_SENTIMENT[season]
        cat_dist = REVIEW_CATEGORY_BY_SEASON[season]

        year, month_num = month_key.split("-")
        year = int(year)
        month_num = int(month_num)

        from config import MONTH_DAYS
        start_day, end_day = MONTH_DAYS[month_key]

        for _ in range(month_count):
            review_id += 1

            is_positive = random.random() < sentiment_dist["positive"]

            cats = list(cat_dist.keys())
            cat_weights = list(cat_dist.values())
            category = random.choices(cats, weights=cat_weights, k=1)[0]

            product = random.choice(products_by_cat[category])

            if is_positive:
                templates = POSITIVE_TEMPLATES[category]
                rating = random.choices([5, 4, 3], weights=[0.5, 0.4, 0.1], k=1)[0]
            else:
                templates = NEGATIVE_TEMPLATES[category]
                rating = random.choices([1, 2, 3], weights=[0.4, 0.4, 0.2], k=1)[0]

            title_template, text_template = random.choice(templates)
            title = title_template.format(product=product["name"])
            text = text_template.format(product=product["name"])

            day = random.randint(start_day, end_day)
            review_date = datetime(year, month_num, day).strftime("%Y-%m-%d")

            customer_id = random.choice(customer_ids)

            reviews.append({
                "review_id": review_id,
                "product_id": product["id"],
                "customer_id": customer_id,
                "review_date": review_date,
                "rating": rating,
                "review_title": title,
                "review_text": text,
                "verified_purchase": random.random() < 0.85,
            })

    return reviews
