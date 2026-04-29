-- ============================================================================
-- Data Quality Testing Script
-- Purpose: Test DMFs and alerts by inserting problematic data
-- ============================================================================

USE DATABASE automated_intelligence;
USE SCHEMA raw;
USE WAREHOUSE automated_intelligence_wh;

-- ============================================================================
-- STEP 1: Check Current State
-- ============================================================================

SELECT 'Current Orders Count' AS metric, COUNT(*) AS value FROM orders
UNION ALL
SELECT 'Current Order Items Count', COUNT(*) FROM order_items
UNION ALL
SELECT 'Current DQ Alerts', COUNT(*) FROM data_quality_alerts;

-- ============================================================================
-- STEP 2: Check Table Constraints (to understand what we can test)
-- ============================================================================

-- Describe tables to see constraints
DESCRIBE TABLE orders;
DESCRIBE TABLE order_items;

-- ============================================================================
-- STEP 3: Insert Valid Data First (baseline)
-- ============================================================================

-- Insert valid orders
INSERT INTO orders (order_id, customer_id, order_date, order_status, total_amount, discount_percent, shipping_cost)
VALUES 
  (999990, 1, CURRENT_TIMESTAMP(), 'Pending', 100.00, 0, 5.00),
  (999991, 2, CURRENT_TIMESTAMP(), 'Pending', 200.00, 10, 10.00);

-- Insert valid order items
INSERT INTO order_items (order_item_id, order_id, product_id, product_name, product_category, quantity, unit_price, line_total)
VALUES 
  (999990, 999990, 5000, 'Test Product A', 'Electronics', 1, 95.00, 95.00),
  (999991, 999991, 5001, 'Test Product B', 'Clothing', 2, 95.00, 190.00);

SELECT 'Valid records inserted successfully' AS status;

-- ============================================================================
-- STEP 4: Wait for DMFs to Execute
-- ============================================================================

-- DMFs execute on TRIGGER_ON_CHANGES, so they should run immediately
-- Wait a few seconds for DMF execution
CALL SYSTEM$WAIT(5);

-- ============================================================================
-- STEP 5: Check DMF Results for Valid Data (should show 0 NULLs)
-- ============================================================================

SELECT 
  measurement_time,
  table_name,
  column_name,
  metric_name,
  value,
  'Expected: 0 NULLs for valid data' AS note
FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS
WHERE 
  table_database = 'AUTOMATED_INTELLIGENCE'
  AND table_schema = 'RAW'
  AND table_name IN ('ORDERS', 'ORDER_ITEMS')
  AND measurement_time >= DATEADD('MINUTE', -5, CURRENT_TIMESTAMP())
ORDER BY measurement_time DESC, table_name, column_name;

-- ============================================================================
-- STEP 6: Test with Columns That Allow NULLs
-- ============================================================================

-- Check which columns allow NULLs
SELECT 
  table_name,
  column_name,
  is_nullable,
  data_type
FROM INFORMATION_SCHEMA.COLUMNS
WHERE table_schema = 'RAW'
  AND table_name IN ('ORDERS', 'ORDER_ITEMS')
ORDER BY table_name, ordinal_position;

-- Insert records with NULLs in nullable columns
INSERT INTO orders (order_id, customer_id, order_date, order_status, total_amount, discount_percent, shipping_cost)
VALUES 
  (999992, NULL, CURRENT_TIMESTAMP(), 'Pending', 175.00, NULL, NULL),  -- NULL customer_id, discount, shipping
  (999993, NULL, NULL, 'Pending', 225.00, NULL, NULL);  -- Multiple NULLs

INSERT INTO order_items (order_item_id, order_id, product_id, product_name, product_category, quantity, unit_price, line_total)
VALUES 
  (999992, 999992, NULL, 'Test Product C', NULL, NULL, 50.00, NULL),  -- Multiple NULLs
  (999993, 999993, NULL, NULL, NULL, NULL, NULL, NULL);  -- Extreme case - many NULLs

SELECT 'Problematic records with NULLs inserted (if columns allow NULLs)' AS status;

-- ============================================================================
-- STEP 7: Wait for DMFs to Process New Data
-- ============================================================================

CALL SYSTEM$WAIT(10);

-- ============================================================================
-- STEP 8: Check DMF Results After Problematic Data
-- ============================================================================

SELECT 
  measurement_time,
  table_name,
  column_name,
  metric_name,
  value,
  'Check for increased NULL counts' AS note
FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS
WHERE 
  table_database = 'AUTOMATED_INTELLIGENCE'
  AND table_schema = 'RAW'
  AND table_name IN ('ORDERS', 'ORDER_ITEMS')
  AND value > 0  -- Only show columns with NULL values
ORDER BY measurement_time DESC, table_name, column_name
LIMIT 20;

-- ============================================================================
-- STEP 9: Wait for Alert to Run (alert checks every 5 minutes)
-- ============================================================================

SELECT 
  'Alert runs every 5 minutes. Check data_quality_alerts table after ~5 minutes.' AS info,
  'Or manually execute alert condition query below to see what alert would detect:' AS next_step;

-- Manually run the alert condition to see what it would detect
SELECT 
  measurement_time,
  table_name,
  metric_name,
  column_name,
  value,
  'This would trigger an alert' AS alert_trigger
FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS
WHERE 
  table_database = 'AUTOMATED_INTELLIGENCE'
  AND table_schema = 'RAW'
  AND table_name IN ('ORDERS', 'ORDER_ITEMS')
  AND metric_name = 'NULL_COUNT'
  AND value > 0
  AND measurement_time >= DATEADD('MINUTE', -10, CURRENT_TIMESTAMP())
ORDER BY measurement_time DESC;

-- ============================================================================
-- STEP 10: Check Alert History
-- ============================================================================

-- Wait a bit more for alert to execute
CALL SYSTEM$WAIT(30);

-- Check if alert fired
SELECT 
  alert_time,
  issue_summary,
  'Alert fired automatically when NULLs detected' AS note
FROM data_quality_alerts
ORDER BY alert_time DESC
LIMIT 10;

-- If no alerts yet, check alert status
SHOW ALERTS LIKE 'data_quality_alert' IN SCHEMA automated_intelligence.raw;

-- ============================================================================
-- STEP 11: View Alert History
-- ============================================================================

-- Check alert execution history
SELECT 
  name,
  state,
  scheduled_time,
  completed_time,
  condition_evaluates_to_true,
  error
FROM TABLE(INFORMATION_SCHEMA.ALERT_HISTORY(
  SCHEDULED_TIME_RANGE_START => DATEADD('hour', -1, CURRENT_TIMESTAMP())
))
WHERE alert_name = 'DATA_QUALITY_ALERT'
ORDER BY scheduled_time DESC
LIMIT 10;

-- ============================================================================
-- STEP 12: Cleanup Test Data (Optional)
-- ============================================================================

-- Uncomment to remove test data
/*
DELETE FROM order_items WHERE order_item_id >= 999990;
DELETE FROM orders WHERE order_id >= 999990;
DELETE FROM data_quality_alerts WHERE issue_summary LIKE '%Test%';
SELECT 'Test data cleaned up' AS status;
*/

-- ============================================================================
-- STEP 13: Summary
-- ============================================================================

SELECT '=== DATA QUALITY TEST SUMMARY ===' AS summary
UNION ALL SELECT ''
UNION ALL SELECT '1. Valid data inserted - DMFs should show 0 NULLs'
UNION ALL SELECT '2. Problematic data inserted (where allowed by constraints)'
UNION ALL SELECT '3. DMFs detect NULL values automatically'
UNION ALL SELECT '4. Alert runs every 5 minutes and logs to data_quality_alerts'
UNION ALL SELECT '5. Check data_quality_alerts table for alert records'
UNION ALL SELECT ''
UNION ALL SELECT 'Key Monitoring Queries:'
UNION ALL SELECT '- SELECT * FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS WHERE value > 0'
UNION ALL SELECT '- SELECT * FROM data_quality_alerts ORDER BY alert_time DESC'
UNION ALL SELECT '- SHOW ALERTS IN SCHEMA automated_intelligence.raw';
