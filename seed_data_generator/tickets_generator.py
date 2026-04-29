import random
from datetime import datetime
from config import NUM_TICKETS, MONTH_DAYS

TICKET_TEMPLATES = {
    "Return Request": {
        "priority": ["Medium", "High"],
        "subjects": [
            "Request to return {product}",
            "Return/exchange needed for {product}",
            "Would like to return my recent purchase",
            "Need to process a return - {product}",
            "Returning {product} - wrong size",
        ],
        "descriptions": [
            "I received my {product} but they don't fit properly. The sizing chart was inaccurate and I need to return them for a refund. Order placed on {order_date}.",
            "I'd like to return the {product} I purchased as a gift. The recipient already has this item. Please provide return instructions.",
            "The {product} I received are not what I expected based on the description. They're much {issue} than advertised. I'd like a full refund.",
            "Purchased {product} during the holiday sale but they arrived damaged. Need to initiate a return and get a replacement or refund.",
            "I bought these {product} for Christmas but they're the wrong size for my {person}. Need to exchange for a different size but my size is out of stock.",
        ],
        "resolutions": [
            "Return label sent. Refund processed within 5-7 business days of receipt.",
            "Exchange approved. New size shipping within 2 business days.",
            "Full refund issued to original payment method. Return label emailed.",
            "Replacement item shipped. Customer can keep or donate original.",
            None,
        ],
    },
    "Sizing Issue": {
        "priority": ["Medium", "Low"],
        "subjects": [
            "Size chart seems wrong for {product}",
            "Help with sizing for {product}",
            "{product} sizing question before purchase",
            "Boots don't fit - need sizing advice",
            "Exchange needed - sizing issue with {product}",
        ],
        "descriptions": [
            "I normally wear size {size} in other brands but the {product} feel extremely {issue}. Is your sizing different from standard? Should I go up a size?",
            "Looking to buy {product} but reviews mention sizing issues. I'm a {size} in {brand}. What size would you recommend?",
            "The {product} I received are way too {issue}. I measured according to your size chart and ordered {size}. This seems like a manufacturing defect.",
            "My {person} received {product} as a gift but they're too {issue}. Can I exchange for a {alt_size} without paying return shipping?",
            "I heat molded my {product} at a shop but they're still causing pressure points on the {area}. Is this a known issue with this model?",
        ],
        "resolutions": [
            "Recommended going up half a size. Customer exchanged successfully.",
            "Provided detailed sizing guide. Customer made informed purchase.",
            "Arranged free exchange for correct size. Expedited shipping provided.",
            "Suggested visiting local retailer for professional fitting.",
            None,
        ],
    },
    "Shipping Delay": {
        "priority": ["High", "High", "Medium"],
        "subjects": [
            "Order still not shipped after {days} days",
            "Holiday order delayed - need by Christmas",
            "Tracking shows no movement for {days} days",
            "Urgent: Gift order not arriving on time",
            "Where is my order? Purchased {days} days ago",
        ],
        "descriptions": [
            "I placed an order {days} days ago and it still shows as 'Processing'. I needed these {product} for a ski trip on {trip_date}. Can you expedite?",
            "My order containing {product} was supposed to arrive by {trip_date} but tracking shows it's stuck in {location}. This was a Christmas gift!",
            "It's been {days} days since I ordered and the package hasn't moved from the distribution center. I'm very frustrated with this experience.",
            "I paid for express shipping on my {product} order but it's been {days} days with no delivery. I want a shipping refund at minimum.",
            "Order #{order_ref} placed on {order_date} still showing 'Pending'. All other retailers I've ordered from have already delivered. Very disappointing.",
        ],
        "resolutions": [
            "Expedited replacement shipment sent via overnight delivery. Original order refunded shipping cost.",
            "Package located at distribution center. Re-routed for priority delivery. Arrived 2 days later.",
            "Shipping refund processed. Package delivered 1 day after ticket creation.",
            "Customer cancelled order due to delay. Full refund issued within 24 hours.",
            None,
        ],
    },
    "Product Quality": {
        "priority": ["Medium", "High"],
        "subjects": [
            "Defective {product} received",
            "Quality issue with {product}",
            "{product} broke after {days} days of use",
            "Manufacturing defect on my {product}",
            "Disappointed with {product} quality",
        ],
        "descriptions": [
            "My {product} have a visible manufacturing defect - the {defect}. This is unacceptable for a ${price} product. I expect a replacement or full refund.",
            "After only {days} days of normal use, the {defect} on my {product}. I've always taken care of my gear and this shouldn't happen this quickly.",
            "The {product} I received look nothing like the photos on your website. The {defect} and the overall finish quality is much lower than expected.",
            "I'm an experienced {activity} and these {product} failed during normal use. The {defect}. This could have been dangerous.",
            "Compared to last year's model, the quality of these {product} has clearly declined. The {defect} after just {days} days is unacceptable.",
        ],
        "resolutions": [
            "Warranty replacement approved. New item shipping within 3 business days.",
            "Offered 30% discount on replacement. Customer accepted and reordered.",
            "Full refund processed. Product reported to quality team for investigation.",
            "Escalated to product team. Customer received upgraded replacement model.",
            None,
        ],
    },
    "General Inquiry": {
        "priority": ["Low", "Low", "Medium"],
        "subjects": [
            "When will new {year} models be available?",
            "Question about {product} compatibility",
            "Warranty coverage question",
            "Do you offer group discounts?",
            "Product recommendation request",
        ],
        "descriptions": [
            "I'm looking to upgrade my gear for next season. When will the {year} models of {product} be available? I want to be first to order.",
            "I currently have {product} and want to know if they're compatible with the new {accessory}. Can't find this info on your website.",
            "My {product} have a small crack after 2 years of use. Are they still under warranty? I have my original receipt.",
            "Our ski club has 25 members looking to buy equipment. Do you offer any group or bulk discounts on {product}?",
            "I'm {level} level and looking for the best {product} for my ability. I'm {height} and {weight}. What would you recommend?",
        ],
        "resolutions": [
            "Provided estimated release date and added customer to notification list.",
            "Confirmed compatibility and provided setup instructions.",
            "Verified warranty coverage. Replacement approved under 3-year warranty.",
            "Connected with sales team for group pricing. 15% group discount offered.",
            "Provided personalized product recommendation based on ability and measurements.",
        ],
    },
}

TICKET_CATEGORY_BY_SEASON = {
    "peak": {"Shipping Delay": 0.40, "General Inquiry": 0.25, "Sizing Issue": 0.15, "Return Request": 0.10, "Product Quality": 0.10},
    "preseason": {"Sizing Issue": 0.35, "General Inquiry": 0.30, "Shipping Delay": 0.15, "Return Request": 0.10, "Product Quality": 0.10},
    "crash": {"Return Request": 0.40, "Sizing Issue": 0.25, "Product Quality": 0.15, "General Inquiry": 0.10, "Shipping Delay": 0.10},
    "shoulder": {"General Inquiry": 0.30, "Return Request": 0.25, "Product Quality": 0.20, "Sizing Issue": 0.15, "Shipping Delay": 0.10},
    "clearance": {"General Inquiry": 0.35, "Sizing Issue": 0.20, "Return Request": 0.20, "Shipping Delay": 0.15, "Product Quality": 0.10},
    "off": {"General Inquiry": 0.45, "Product Quality": 0.20, "Sizing Issue": 0.15, "Return Request": 0.10, "Shipping Delay": 0.10},
}

TICKET_VOLUME_BY_MONTH = {
    "2025-06": 0.03, "2025-07": 0.03, "2025-08": 0.04,
    "2025-09": 0.06, "2025-10": 0.07,
    "2025-11": 0.12, "2025-12": 0.15,
    "2026-01": 0.12, "2026-02": 0.15,
    "2026-03": 0.08, "2026-04": 0.06,
    "2026-05": 0.05, "2026-06": 0.04,
}

MONTH_TO_SEASON = {
    "2025-06": "off", "2025-07": "off", "2025-08": "off",
    "2025-09": "preseason", "2025-10": "preseason",
    "2025-11": "peak", "2025-12": "peak",
    "2026-01": "peak", "2026-02": "crash",
    "2026-03": "shoulder", "2026-04": "clearance",
    "2026-05": "clearance", "2026-06": "off",
}

FILL_VALUES = {
    "product": ["Ski Boots", "Snowboard Boots", "Powder Skis", "All-Mountain Skis", "Freestyle Snowboard", "Ski Goggles", "Ski Helmet"],
    "size": ["9", "10", "10.5", "11", "26.5", "27", "28", "L", "M", "XL"],
    "brand": ["Salomon", "Burton", "Rossignol", "Nordica", "K2"],
    "issue": ["tight", "narrow", "loose", "large", "stiff", "soft"],
    "person": ["wife", "husband", "son", "daughter", "friend"],
    "area": ["instep", "shin", "toe box", "heel", "ankle"],
    "alt_size": ["one size up", "one size down", "wide version"],
    "days": ["3", "5", "7", "10", "14"],
    "location": ["Memphis TN", "Louisville KY", "Denver CO", "Salt Lake City UT"],
    "trip_date": ["December 23", "December 25", "January 2", "February 15", "March 1"],
    "order_date": ["last week", "5 days ago", "December 1", "November 28", "2 weeks ago"],
    "order_ref": ["ORD-" + str(random.randint(100000, 999999)) for _ in range(10)],
    "defect": ["stitching is coming apart", "edge is delaminating", "buckle mechanism broke", "base has deep scratches", "top sheet is peeling", "lens coating is flaking off"],
    "price": ["449", "649", "799", "349", "549"],
    "activity": ["skier", "snowboarder", "backcountry enthusiast", "park rider"],
    "year": ["2026-27", "2027"],
    "accessory": ["Snowboard Bindings", "Ski Poles", "Ski Goggles"],
    "level": ["intermediate", "advanced", "beginner", "expert"],
    "height": ["5'8\"", "5'10\"", "6'0\"", "6'2\"", "5'6\""],
    "weight": ["160 lbs", "175 lbs", "190 lbs", "145 lbs", "200 lbs"],
}


def fill_template(template):
    result = template
    for key, values in FILL_VALUES.items():
        placeholder = "{" + key + "}"
        while placeholder in result:
            result = result.replace(placeholder, random.choice(values), 1)
    return result


def generate_tickets(customer_ids):
    tickets = []
    ticket_id = 0

    for month_key, vol_pct in TICKET_VOLUME_BY_MONTH.items():
        month_count = max(1, int(NUM_TICKETS * vol_pct))
        season = MONTH_TO_SEASON[month_key]
        cat_dist = TICKET_CATEGORY_BY_SEASON[season]

        year, month_num = month_key.split("-")
        year = int(year)
        month_num = int(month_num)
        start_day, end_day = MONTH_DAYS[month_key]

        cats = list(cat_dist.keys())
        cat_weights = list(cat_dist.values())

        for _ in range(month_count):
            ticket_id += 1
            category = random.choices(cats, weights=cat_weights, k=1)[0]
            tmpl = TICKET_TEMPLATES[category]

            priority = random.choice(tmpl["priority"])
            subject = fill_template(random.choice(tmpl["subjects"]))
            description = fill_template(random.choice(tmpl["descriptions"]))
            resolution = random.choice(tmpl["resolutions"])

            day = random.randint(start_day, end_day)
            hour = random.randint(7, 22)
            minute = random.randint(0, 59)
            ticket_date = datetime(year, month_num, day, hour, minute, 0)

            if resolution:
                status = random.choices(["Resolved", "Closed"], weights=[0.6, 0.4], k=1)[0]
            else:
                status = random.choices(["Open", "In Progress"], weights=[0.4, 0.6], k=1)[0]

            customer_id = random.choice(customer_ids)

            tickets.append({
                "ticket_id": ticket_id,
                "customer_id": customer_id,
                "ticket_date": ticket_date.strftime("%Y-%m-%d %H:%M:%S"),
                "category": category,
                "priority": priority,
                "subject": subject,
                "description": description,
                "resolution": resolution if resolution else "",
                "status": status,
            })

    return tickets
