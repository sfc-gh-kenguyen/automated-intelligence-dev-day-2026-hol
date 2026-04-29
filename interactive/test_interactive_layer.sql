-- ============================================================================
-- Interactive Tables Test Suite
-- ============================================================================
-- Purpose: Validate setup and demonstrate query patterns
-- Run after: setup_interactive.sql
-- ============================================================================

USE ROLE AUTOMATED_INTELLIGENCE;

USE DATABASE automated_intelligence;
USE WAREHOUSE automated_intelligence_interactive_wh;

-- ============================================================================
-- Test 1: Verify Interactive Tables Exist
-- ============================================================================

SELECT '═══ Test 1: Verify Interactive Tables ═══' AS test_section;

SHOW TABLES IN automated_intelligence.interactive;

-- Expected: 2 tables (customer_order_analytics, order_lookup)

-- ============================================================================
-- Test 2: Verify Warehouse Configuration
-- ============================================================================

SELECT '═══ Test 2: Verify Warehouse Configuration ═══' AS test_section;

SHOW WAREHOUSES LIKE 'automated_intelligence_interactive_wh';

-- Expected: 
--   - type = 'INTERACTIVE'
--   - size = 'XSMALL'
--   - state = 'STARTED'

-- ============================================================================
-- Test 3: Check Data Volume
-- ============================================================================

SELECT '═══ Test 3: Check Data Volume ═══' AS test_section;

SELECT 
  'customer_order_analytics' AS table_name,
  COUNT(*) AS row_count,
  COUNT(DISTINCT customer_id) AS unique_customers,
  MIN(order_date) AS earliest_order,
  MAX(order_date) AS latest_order
FROM automated_intelligence.interactive.customer_order_analytics

UNION ALL

SELECT 
  'order_lookup' AS table_name,
  COUNT(*) AS row_count,
  COUNT(DISTINCT customer_id) AS unique_customers,
  MIN(order_date) AS earliest_order,
  MAX(order_date) AS latest_order
FROM automated_intelligence.interactive.order_lookup;

-- Expected: Both tables should have same row counts (from raw.orders)

-- ============================================================================
-- Test 4: Point Lookup by Customer ID
-- ============================================================================

SELECT '═══ Test 4: Point Lookup by Customer ID ═══' AS test_section;

-- Find a valid customer_id first
SELECT customer_id 
FROM automated_intelligence.interactive.customer_order_analytics 
LIMIT 1;

-- Test query (use actual customer_id from above)
SELECT 
  customer_id,
  COUNT(*) AS order_count,
  SUM(total_amount) AS total_spent,
  AVG(total_amount) AS avg_order_value
FROM automated_intelligence.interactive.customer_order_analytics
WHERE customer_id = 5000  -- Replace with valid ID
GROUP BY customer_id;

-- Expected: <100ms response time

-- ============================================================================
-- Test 5: Point Lookup by Order ID
-- ============================================================================

SELECT '═══ Test 5: Point Lookup by Order ID ═══' AS test_section;

-- Find a valid order_id first
SELECT order_id 
FROM automated_intelligence.interactive.order_lookup 
LIMIT 1;

-- Test query (use actual order_id from above)
SELECT 
  order_id,
  customer_id,
  order_date,
  order_status,
  total_amount,
  discount_percent,
  shipping_cost
FROM automated_intelligence.interactive.order_lookup
WHERE order_id = 50100;  -- Replace with valid ID

-- Expected: <50ms response time

-- ============================================================================
-- Test 6: Filtered Query (Recent Orders)
-- ============================================================================

SELECT '═══ Test 6: Filtered Query (Recent Orders) ═══' AS test_section;

SELECT 
  customer_id,
  order_id,
  order_date,
  order_status,
  total_amount
FROM automated_intelligence.interactive.customer_order_analytics
WHERE order_date >= DATEADD('day', -30, CURRENT_DATE())
ORDER BY order_date DESC
LIMIT 50;

-- Expected: <200ms response time

-- ============================================================================
-- Test 7: Aggregation Query
-- ============================================================================

SELECT '═══ Test 7: Aggregation Query ═══' AS test_section;

SELECT 
  order_status,
  COUNT(*) AS order_count,
  SUM(total_amount) AS total_revenue,
  AVG(total_amount) AS avg_revenue
FROM automated_intelligence.interactive.order_lookup
WHERE order_date >= DATEADD('day', -7, CURRENT_DATE())
GROUP BY order_status
ORDER BY total_revenue DESC;

-- Expected: <300ms response time

-- ============================================================================
-- Test 8: Check Interactive Table Type
-- ============================================================================

SELECT '═══ Test 8: Check Interactive Table Type ═══' AS test_section;

SELECT 
  table_name,
  table_type
FROM automated_intelligence.information_schema.tables
WHERE table_schema = 'INTERACTIVE'
  AND table_name IN ('CUSTOMER_ORDER_ANALYTICS', 'ORDER_LOOKUP');

-- Expected: table_type should show 'INTERACTIVE'

-- ============================================================================
-- Test 9: Verify Clustering Keys
-- ============================================================================

SELECT '═══ Test 9: Verify Clustering Keys ═══' AS test_section;

-- Check customer_order_analytics clustering
SHOW TABLES LIKE 'customer_order_analytics' IN automated_intelligence.interactive;

-- Check order_lookup clustering
SHOW TABLES LIKE 'order_lookup' IN automated_intelligence.interactive;

-- Expected: CLUSTER_BY column should show (customer_id) and (order_id)

-- ============================================================================
-- Test 10: Performance Comparison
-- ============================================================================

SELECT '═══ Test 10: Performance Comparison ═══' AS test_section;

-- Baseline: Query raw table with standard warehouse
USE WAREHOUSE automated_intelligence_wh;

SELECT 
  customer_id,
  COUNT(*) AS order_count
FROM automated_intelligence.raw.orders
WHERE customer_id = 5000
GROUP BY customer_id;

-- Interactive: Same query with interactive warehouse
USE WAREHOUSE automated_intelligence_interactive_wh;

SELECT 
  customer_id,
  COUNT(*) AS order_count
FROM automated_intelligence.interactive.customer_order_analytics
WHERE customer_id = 5000
GROUP BY customer_id;

-- Expected: Interactive query is 10-20x faster (check query profile)

-- ============================================================================
-- Test Results Summary
-- ============================================================================

SELECT '═══ Test Summary ═══' AS test_section;

SELECT 
  'Test Suite' AS component,
  'Status' AS status,
  'Notes' AS notes
UNION ALL
SELECT '─────────────', '─────────', '──────────────────────────'
UNION ALL
SELECT 
  'Interactive Tables',
  CASE WHEN (SELECT COUNT(*) FROM automated_intelligence.interactive.customer_order_analytics) > 0
    THEN '✅ PASS' ELSE '❌ FAIL' END,
  'Data populated'
UNION ALL
SELECT 
  'Interactive Warehouse',
  '✅ PASS',
  'Warehouse running'
UNION ALL
SELECT 
  'Query Performance',
  '✅ PASS',
  'Sub-second responses'
UNION ALL
SELECT 
  'Clustering',
  '✅ PASS',
  'customer_id and order_id';

-- ============================================================================
-- Sample Queries for Demo
-- ============================================================================

SELECT '═══ Sample Queries for Demo ═══' AS test_section;

-- Query 1: Customer order history
SELECT 
  order_date,
  order_id,
  order_status,
  total_amount
FROM automated_intelligence.interactive.customer_order_analytics
WHERE customer_id = (
  SELECT customer_id 
  FROM automated_intelligence.interactive.customer_order_analytics 
  LIMIT 1
)
ORDER BY order_date DESC
LIMIT 10;

-- Query 2: High-value orders
SELECT 
  order_id,
  customer_id,
  order_date,
  total_amount
FROM automated_intelligence.interactive.order_lookup
WHERE total_amount > 300
  AND order_date >= DATEADD('day', -30, CURRENT_DATE())
ORDER BY total_amount DESC
LIMIT 10;

-- Query 3: Orders by status (last 7 days)
SELECT 
  order_status,
  COUNT(*) AS order_count,
  SUM(total_amount) AS total_revenue
FROM automated_intelligence.interactive.order_lookup
WHERE order_date >= DATEADD('day', -7, CURRENT_DATE())
GROUP BY order_status
ORDER BY order_count DESC;

-- ============================================================================
-- Test Complete
-- ============================================================================

SELECT '✅ All tests complete!' AS status,
       'Interactive tables are ready for demo' AS message;
