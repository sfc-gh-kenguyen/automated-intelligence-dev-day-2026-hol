-- Quick Refresh Script for Dynamic Tables
-- Run this to manually trigger refreshes (instead of waiting 12 hours)

USE ROLE AUTOMATED_INTELLIGENCE;
USE WAREHOUSE automated_intelligence_wh;

-- Refresh the chain of dynamic tables
ALTER DYNAMIC TABLE automated_intelligence.dynamic_tables.enriched_orders REFRESH;
ALTER DYNAMIC TABLE automated_intelligence.dynamic_tables.enriched_order_items REFRESH;

-- Note: fact_orders may have time-travel issues
-- Alternative: Manually refresh interactive tables instead
USE WAREHOUSE automated_intelligence_wh;
ALTER DYNAMIC TABLE automated_intelligence.interactive.customer_order_analytics REFRESH;
ALTER DYNAMIC TABLE automated_intelligence.interactive.order_lookup REFRESH;

-- Verify refresh completed
SELECT 
    'enriched_orders' as table_name,
    MAX(order_id) as max_order_id,
    MAX(order_date) as latest_date
FROM automated_intelligence.dynamic_tables.enriched_orders
UNION ALL
SELECT 
    'enriched_order_items',
    MAX(order_id),
    NULL
FROM automated_intelligence.dynamic_tables.enriched_order_items
UNION ALL
SELECT 
    'customer_order_analytics',
    MAX(order_id),
    MAX(order_date)
FROM automated_intelligence.interactive.customer_order_analytics
UNION ALL
SELECT 
    'order_lookup',
    MAX(order_id),
    MAX(order_date)
FROM automated_intelligence.interactive.order_lookup;
