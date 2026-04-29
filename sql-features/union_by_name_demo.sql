-- ============================================================================
-- UNION BY NAME Demo
-- ============================================================================
-- Match columns by name instead of position in UNION operations.
-- Eliminates column ordering issues and simplifies schema evolution.
-- ============================================================================

USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
USE DATABASE AUTOMATED_INTELLIGENCE;
USE WAREHOUSE AUTOMATED_INTELLIGENCE_WH;

-- ============================================================================
-- PART 1: Basic UNION BY NAME
-- ============================================================================

-- Traditional UNION requires matching column order
-- SELECT id, name, amount FROM table1
-- UNION ALL
-- SELECT id, name, amount FROM table2  -- Must be same order!

-- UNION BY NAME matches by column name, not position
SELECT 1 AS id, 'Alice' AS name, 100 AS amount
UNION ALL BY NAME
SELECT 200 AS amount, 2 AS id, 'Bob' AS name;  -- Different column order works!

-- ============================================================================
-- PART 2: Handling Missing Columns
-- ============================================================================

-- When columns don't exist in all queries, NULL is filled in
SELECT 1 AS id, 'Alice' AS name, 100 AS amount
UNION ALL BY NAME
SELECT 2 AS id, 'Bob' AS name, 'Engineering' AS department;

-- Result: All columns appear, missing values are NULL
-- | ID | NAME  | AMOUNT | DEPARTMENT  |
-- | 1  | Alice | 100    | NULL        |
-- | 2  | Bob   | NULL   | Engineering |

-- ============================================================================
-- PART 3: Real-World Example - Combining Different Data Sources
-- ============================================================================

-- Scenario: Combine order data from different systems with varying schemas
WITH online_orders AS (
    SELECT 
        order_id,
        customer_id,
        order_date,
        total_amount,
        'online' AS source
    FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS
    WHERE total_amount > 300
    LIMIT 3
),
retail_orders AS (
    SELECT
        '9999-' || SEQ4() AS order_id,
        0 AS customer_id,
        CURRENT_DATE() AS order_date,
        150.00 AS total_amount,
        'POS-123' AS terminal_id,  -- Extra column only in retail
        'retail' AS source
    FROM TABLE(GENERATOR(ROWCOUNT => 3))
)
SELECT * FROM online_orders
UNION ALL BY NAME
SELECT * FROM retail_orders;

-- ============================================================================
-- PART 4: Schema Evolution Pattern
-- ============================================================================

-- Old schema (v1) has fewer columns
SELECT 
    customer_id,
    first_name,
    last_name,
    state
FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS
WHERE customer_segment = 'Premium'
LIMIT 3

UNION ALL BY NAME

-- New schema (v2) has additional columns
SELECT 
    customer_id,
    first_name,
    last_name,
    state,
    customer_segment,  -- New column
    registration_date   -- New column
FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS
WHERE customer_segment = 'Basic'
LIMIT 3;

-- ============================================================================
-- PART 5: EXCEPT BY NAME and INTERSECT BY NAME
-- ============================================================================

-- EXCEPT BY NAME - find differences matching by column name
SELECT 1 AS id, 'Alice' AS name
EXCEPT BY NAME
SELECT 'Alice' AS name, 1 AS id;  -- No results - matches despite order

-- INTERSECT BY NAME - find common rows matching by column name
SELECT 1 AS id, 'Alice' AS name
INTERSECT BY NAME
SELECT 'Alice' AS name, 1 AS id;  -- Returns the matching row

-- ============================================================================
-- PART 6: Combining Multiple Tables with Different Schemas
-- ============================================================================

-- Useful for consolidating similar but not identical tables
WITH orders_summary AS (
    SELECT 
        'orders' AS table_name,
        COUNT(*) AS record_count,
        SUM(total_amount) AS total_value
    FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS
),
customers_summary AS (
    SELECT 
        'customers' AS table_name,
        COUNT(*) AS record_count,
        NULL::NUMBER AS total_value,  -- Different metrics
        COUNT(DISTINCT state) AS unique_states
    FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS
),
products_summary AS (
    SELECT 
        'products' AS table_name,
        COUNT(*) AS record_count,
        SUM(price) AS total_value,
        COUNT(DISTINCT category) AS unique_categories
    FROM AUTOMATED_INTELLIGENCE.RAW.PRODUCT_CATALOG
)
SELECT * FROM orders_summary
UNION ALL BY NAME
SELECT * FROM customers_summary
UNION ALL BY NAME
SELECT * FROM products_summary;

-- ============================================================================
-- Key Benefits Summary
-- ============================================================================

/*
1. COLUMN ORDER INDEPENDENCE:
   - No need to match column positions
   - Reduces bugs from column reordering

2. SCHEMA FLEXIBILITY:
   - Handles missing columns automatically (fills with NULL)
   - Perfect for evolving schemas

3. DATA CONSOLIDATION:
   - Easily combine data from different sources
   - Ideal for data lakes and ETL processes

4. READABILITY:
   - Intent is clearer in the SQL
   - Self-documenting column matching
*/

-- ============================================================================
-- Demo Complete
-- ============================================================================
SELECT '✅ UNION BY NAME Demo Complete!' AS status;
