-- ============================================================================
-- Interactive Tables Demo Script - Performance Comparison
-- ============================================================================
-- Purpose: Demonstrate sub-second query performance with interactive tables
-- Audience: Technical decision-makers, architects, data engineers
-- Duration: 5-7 minutes
-- ============================================================================

USE ROLE AUTOMATED_INTELLIGENCE;

-- ============================================================================
-- PART 1: Baseline - Query Standard Tables
-- ============================================================================

SELECT '╔════════════════════════════════════════════════════════════════╗' AS separator
UNION ALL SELECT '║  PART 1: Baseline Performance (Standard Warehouse)        ║'
UNION ALL SELECT '╚════════════════════════════════════════════════════════════╝';

-- Switch to standard warehouse
USE WAREHOUSE automated_intelligence_wh;

-- ============================================================================
-- Query 1A: Customer Order History (Standard Table)
-- ============================================================================
-- Talking Point:
-- "Let's query a customer's order history from our standard raw table.
--  This is typical for ad-hoc queries, but watch the response time..."

SELECT 
  customer_id,
  order_id,
  order_date,
  order_status,
  total_amount
FROM automated_intelligence.raw.orders
WHERE customer_id = 5000
ORDER BY order_date DESC
LIMIT 20;

-- Expected Performance: 500ms - 2s (depends on cache state, table scan)
-- Note: Raw table has no clustering, so full table scan may occur

-- ============================================================================
-- Query 1B: Order Lookup by ID (Standard Table)
-- ============================================================================
-- Talking Point:
-- "Now let's lookup a specific order - like a support agent would do..."

SELECT 
  order_id,
  customer_id,
  order_date,
  order_status,
  total_amount,
  discount_percent,
  shipping_cost
FROM automated_intelligence.raw.orders
WHERE order_id = 15000
LIMIT 1;

-- Expected Performance: 300ms - 1.5s
-- Note: No clustering on order_id, so may be slow

-- ============================================================================
-- PART 2: Interactive Tables - Same Queries, Dramatically Faster
-- ============================================================================

SELECT '' AS separator
UNION ALL SELECT '╔════════════════════════════════════════════════════════════════╗'
UNION ALL SELECT '║  PART 2: Interactive Performance (Interactive Warehouse)   ║'
UNION ALL SELECT '╚════════════════════════════════════════════════════════════════╝';

-- Switch to interactive warehouse
USE WAREHOUSE automated_intelligence_interactive_wh;

-- ============================================================================
-- Query 2A: Customer Order History (Interactive Table)
-- ============================================================================
-- Talking Point:
-- "Now the exact same query, but using an interactive table on an interactive
--  warehouse. Notice the response time..."

SELECT 
  customer_id,
  order_id,
  order_date,
  order_status,
  total_amount
FROM automated_intelligence.interactive.customer_order_analytics
WHERE customer_id = 5000
ORDER BY order_date DESC
LIMIT 20;

-- Expected Performance: 50-100ms (5-20x faster!)
-- Talking Point: "Sub-100 millisecond response - perfect for customer portals!"

-- ============================================================================
-- Query 2B: Order Lookup by ID (Interactive Table)
-- ============================================================================
-- Talking Point:
-- "And the order lookup query - now with clustering on order_id..."

SELECT 
  order_id,
  customer_id,
  order_date,
  order_status,
  total_amount,
  discount_percent,
  shipping_cost
FROM automated_intelligence.interactive.order_lookup
WHERE order_id = 15000
LIMIT 1;

-- Expected Performance: 30-80ms (10-30x faster!)
-- Talking Point: "This is fast enough for real-time APIs serving hundreds of requests per second!"

-- ============================================================================
-- PART 3: High Concurrency Test
-- ============================================================================

SELECT '' AS separator
UNION ALL SELECT '╔════════════════════════════════════════════════════════════════╗'
UNION ALL SELECT '║  PART 3: Selective Queries (Show Clustering Benefits)      ║'
UNION ALL SELECT '╚════════════════════════════════════════════════════════════════╝';

-- Talking Point:
-- "Interactive tables are clustered for fast point lookups. Let's test
--  multiple customer queries..."

-- Query different customers (demonstrates consistent performance)
SELECT customer_id, COUNT(*) as order_count, SUM(total_amount) as total_spent
FROM automated_intelligence.interactive.customer_order_analytics
WHERE customer_id = 5001
GROUP BY customer_id;

SELECT customer_id, COUNT(*) as order_count, SUM(total_amount) as total_spent
FROM automated_intelligence.interactive.customer_order_analytics
WHERE customer_id = 5002
GROUP BY customer_id;

SELECT customer_id, COUNT(*) as order_count, SUM(total_amount) as total_spent
FROM automated_intelligence.interactive.customer_order_analytics
WHERE customer_id = 5003
GROUP BY customer_id;

-- Note: In a real demo, you'd run 10-50 of these in parallel using a script
-- Expected: All queries complete in <100ms even under high concurrency

-- ============================================================================
-- PART 4: Architecture Summary
-- ============================================================================

SELECT '' AS separator
UNION ALL SELECT '╔════════════════════════════════════════════════════════════════╗'
UNION ALL SELECT '║  Architecture Summary                                       ║'
UNION ALL SELECT '╚════════════════════════════════════════════════════════════════╝';

-- Display the complete architecture
SELECT 
  'Layer' as component,
  'Purpose' as purpose,
  'Latency' as typical_latency,
  'Use Case' as use_case
UNION ALL
SELECT 
  '━━━━━━━━━━━━',
  '━━━━━━━━━━━━━━━━━━━━━━',
  '━━━━━━━━━━━━━',
  '━━━━━━━━━━━━━━━━━━━━━━'
UNION ALL
SELECT 
  'Snowpipe Streaming',
  'Real-time ingestion',
  'Seconds',
  'IoT sensors, clickstreams'
UNION ALL
SELECT 
  'Dynamic Tables',
  'Transformations/ETL',
  'Minutes-hours',
  'Data warehouse, analytics'
UNION ALL
SELECT 
  'Interactive Tables',
  'Query serving',
  '<5 seconds',
  'APIs, customer portals'
UNION ALL
SELECT 
  'Interactive Warehouse',
  'High-concurrency engine',
  '<100ms',
  'Real-time dashboards';

-- ============================================================================
-- Key Talking Points for Summary
-- ============================================================================

/*
TALKING POINTS:

1. **Performance Improvement**:
   - Standard table: 500ms - 2s per query (no clustering)
   - Interactive table: 50-100ms per query (clustered)
   - 10-20x faster for point lookups

2. **Clustering Benefits**:
   - customer_order_analytics: Clustered by customer_id
   - order_lookup: Clustered by order_id
   - Interactive warehouse leverages clustering for fast lookups

3. **Production Use Cases**:
   - Customer portals: "My Orders", "My Usage"
   - Support dashboards: Order lookup, account details
   - Public APIs: Product availability, order status
   - Real-time monitoring: Alerts, KPI dashboards

4. **When to Use Interactive Tables**:
   - Point lookups (WHERE id = X)
   - Selective filters (WHERE customer_id = X AND date > Y)
   - High concurrency (100+ QPS)
   - Simple aggregations on filtered data

5. **Key Limitations**:
   - 5-second query timeout (cannot be increased)
   - Always-on billing (no auto-suspend)
   - Preview feature (select AWS regions)
   - Best for simple, selective queries

6. **Complete Pipeline**:
   "From Snowpipe Streaming ingestion, through Dynamic Tables transformations,
    to Interactive Tables serving - all native Snowflake!"
*/

-- ============================================================================
-- Additional Demo Queries (Optional)
-- ============================================================================

-- Recent orders for a customer
SELECT 
  order_date,
  order_id,
  order_status,
  total_amount
FROM automated_intelligence.interactive.customer_order_analytics
WHERE customer_id = 5000
  AND order_date >= DATEADD('day', -30, CURRENT_DATE())
ORDER BY order_date DESC;

-- Orders by status
SELECT 
  order_status,
  COUNT(*) as order_count,
  SUM(total_amount) as total_revenue
FROM automated_intelligence.interactive.order_lookup
WHERE order_date >= CURRENT_DATE() - 7
GROUP BY order_status
ORDER BY order_count DESC;

-- High-value orders
SELECT 
  order_id,
  customer_id,
  order_date,
  total_amount
FROM automated_intelligence.interactive.order_lookup
WHERE total_amount > 500
  AND order_date >= CURRENT_DATE() - 30
ORDER BY total_amount DESC
LIMIT 10;

-- ============================================================================
-- Demo Complete
-- ============================================================================

SELECT '✅ Interactive Tables Demo Complete!' AS status,
       'Key message: Interactive tables provide sub-second performance for point lookups!' AS takeaway;
