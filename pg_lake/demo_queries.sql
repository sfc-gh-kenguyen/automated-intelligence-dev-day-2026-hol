-- ============================================================
-- pg_lake Demo Queries
-- Query Snowflake Iceberg data directly from Postgres
-- ============================================================

-- ------------------------------------------------------------
-- 1. Verify Data - Compare counts with Snowflake
-- ------------------------------------------------------------

SELECT 'product_reviews' as table_name, COUNT(*) as row_count FROM product_reviews
UNION ALL
SELECT 'support_tickets', COUNT(*) FROM support_tickets;

-- ------------------------------------------------------------
-- 2. Product Reviews Analysis
-- ------------------------------------------------------------

-- Rating distribution
SELECT rating, COUNT(*) as count
FROM product_reviews
GROUP BY rating
ORDER BY rating DESC;

-- Recent reviews with sentiment
SELECT 
    review_id,
    review_date,
    rating,
    review_title,
    CASE 
        WHEN rating >= 4 THEN 'Positive'
        WHEN rating = 3 THEN 'Neutral'
        ELSE 'Negative'
    END as sentiment
FROM product_reviews
ORDER BY review_date DESC
LIMIT 10;

-- Average rating by product
SELECT 
    product_id,
    COUNT(*) as review_count,
    ROUND(AVG(rating)::numeric, 2) as avg_rating
FROM product_reviews
GROUP BY product_id
ORDER BY review_count DESC;

-- ------------------------------------------------------------
-- 3. Support Tickets Analysis  
-- ------------------------------------------------------------

-- Tickets by status
SELECT status, COUNT(*) as count
FROM support_tickets
GROUP BY status
ORDER BY count DESC;

-- Tickets by category and priority
SELECT 
    category,
    priority,
    COUNT(*) as count
FROM support_tickets
GROUP BY category, priority
ORDER BY category, priority;

-- Open high-priority tickets
SELECT 
    ticket_id,
    category,
    priority,
    subject
FROM support_tickets
WHERE status = 'Open' AND priority IN ('High', 'Urgent')
ORDER BY ticket_date DESC
LIMIT 10;

-- ------------------------------------------------------------
-- 4. Cross-table Analytics (if customer_id matches)
-- ------------------------------------------------------------

-- Customers with both negative reviews and support tickets
SELECT 
    pr.customer_id,
    COUNT(DISTINCT pr.review_id) as negative_reviews,
    COUNT(DISTINCT st.ticket_id) as support_tickets
FROM product_reviews pr
JOIN support_tickets st ON pr.customer_id = st.customer_id
WHERE pr.rating <= 2
GROUP BY pr.customer_id
ORDER BY negative_reviews DESC
LIMIT 10;

-- ------------------------------------------------------------
-- 5. Time-based Analysis
-- ------------------------------------------------------------

-- Reviews by date
SELECT 
    review_date,
    COUNT(*) as reviews,
    ROUND(AVG(rating)::numeric, 2) as avg_rating
FROM product_reviews
GROUP BY review_date
ORDER BY review_date DESC
LIMIT 14;

-- Ticket volume by date
SELECT 
    ticket_date::date as date,
    COUNT(*) as tickets
FROM support_tickets
GROUP BY ticket_date::date
ORDER BY date DESC
LIMIT 14;

-- ------------------------------------------------------------
-- 6. Summary
-- ------------------------------------------------------------

SELECT '=== pg_lake Demo Summary ===' as summary
UNION ALL
SELECT '✓ Successfully queried Snowflake Iceberg data from Postgres'
UNION ALL
SELECT '✓ Product Reviews: ' || COUNT(*)::text || ' rows' FROM product_reviews
UNION ALL
SELECT '✓ Support Tickets: ' || COUNT(*)::text || ' rows' FROM support_tickets
UNION ALL
SELECT '✓ Avg Product Rating: ' || ROUND(AVG(rating)::numeric, 2)::text || ' stars' FROM product_reviews
UNION ALL
SELECT '✓ Open Tickets: ' || COUNT(*)::text FROM support_tickets WHERE status = 'Open'
UNION ALL
SELECT '✓ High Priority Open: ' || COUNT(*)::text FROM support_tickets WHERE status = 'Open' AND priority IN ('High', 'Urgent')
UNION ALL
SELECT '================================';
