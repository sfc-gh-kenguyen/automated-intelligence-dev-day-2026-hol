-- ============================================================================
-- SQL Pipe Operator Demo (->>)
-- ============================================================================
-- The pipe operator chains SQL statements, passing results between them.
-- Released in Snowflake 9.13 (May 2025)
-- 
-- Key Benefits:
-- - Eliminates RESULT_SCAN() complexity
-- - Guaranteed execution order (no concurrency issues)
-- - Cleaner, more readable SQL workflows
-- - Error handling: execution stops at point of failure
-- ============================================================================

USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
USE DATABASE AUTOMATED_INTELLIGENCE;
USE WAREHOUSE AUTOMATED_INTELLIGENCE_WH;

-- ============================================================================
-- PART 1: Basic Pipe Operator with SHOW Commands
-- ============================================================================

-- Query SHOW command output without RESULT_SCAN
SHOW TABLES IN AUTOMATED_INTELLIGENCE.RAW
->> SELECT "name" AS table_name, "rows" AS row_count, "bytes" AS size_bytes 
    FROM $1
    ORDER BY "bytes" DESC;

-- Filter SHOW WAREHOUSES output
SHOW WAREHOUSES
->> SELECT "name" AS warehouse_name, "state" AS status, "type" AS wh_type, "size" AS wh_size
    FROM $1
    WHERE "name" LIKE 'AUTOMATED_INTELLIGENCE%';

-- List schemas with filtering
SHOW SCHEMAS IN DATABASE AUTOMATED_INTELLIGENCE
->> SELECT "name" AS schema_name, "owner" AS schema_owner
    FROM $1
    WHERE "name" NOT LIKE 'DBT%';

-- ============================================================================
-- PART 2: Chaining Multiple Statements
-- ============================================================================

-- Chain SELECT statements with transformation
SELECT * FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS WHERE state = 'CO'
->> SELECT customer_id, first_name, last_name, customer_segment FROM $1
->> SELECT COUNT(*) AS colorado_customer_count FROM $1;

-- Reference results from multiple previous statements
SELECT order_id, customer_id, total_amount FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS WHERE total_amount > 500 LIMIT 100
->> SELECT AVG(total_amount) AS avg_amount, MIN(total_amount) AS min_amount, MAX(total_amount) AS max_amount FROM $1
->> SELECT 'High-value orders (>$500) stats' AS metric_type, * FROM $1;

-- ============================================================================
-- PART 3: DML Operations with Row Counts
-- ============================================================================

-- Create a temp table and track inserts (row counts)
CREATE OR REPLACE TEMP TABLE pipe_demo_temp (id INT, value VARCHAR)
->> INSERT INTO pipe_demo_temp VALUES (1, 'first')
->> INSERT INTO pipe_demo_temp VALUES (2, 'second')
->> INSERT INTO pipe_demo_temp VALUES (3, 'third')
->> SELECT SUM(s.$1) AS total_rows_inserted FROM (
       SELECT $1 FROM $3 
       UNION ALL 
       SELECT $1 FROM $2 
       UNION ALL 
       SELECT $1 FROM $1
   ) s;

-- ============================================================================
-- PART 4: Join Operations Across Piped Results
-- ============================================================================

-- Chain with joins (note: regular joins are usually more performant)
SELECT DISTINCT deptno FROM (SELECT 30 AS deptno) dept_demo WHERE deptno = 30
->> SELECT o.order_id, o.total_amount, c.first_name, c.customer_segment
    FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS o
    JOIN AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS c ON o.customer_id = c.customer_id
    WHERE c.customer_segment = 'Premium'
    LIMIT 5;

-- ============================================================================
-- PART 5: Metadata Exploration Pattern
-- ============================================================================

-- Common pattern: Get table stats for multiple tables
SHOW TABLES IN AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES
->> SELECT 
       "name" AS table_name,
       "rows" AS row_count,
       ROUND("bytes" / 1024 / 1024, 2) AS size_mb,
       "comment" AS description
    FROM $1
    ORDER BY "rows" DESC;

-- Check column details for specific tables
DESCRIBE TABLE AUTOMATED_INTELLIGENCE.RAW.ORDERS
->> SELECT "name" AS column_name, "type" AS data_type, "null?" AS nullable
    FROM $1;

-- ============================================================================
-- PART 6: Stored Procedure Results (Advanced)
-- ============================================================================

-- Pipe operator works with stored procedures that return tables
-- Example pattern:
/*
CALL my_procedure(param1, param2)
->> SELECT column1, column2 FROM $1
->> WHERE some_condition;
*/

-- ============================================================================
-- Key Syntax Rules
-- ============================================================================

/*
1. REFERENCE PATTERN:
   - $1 = result from immediately previous statement
   - $2 = result from two statements back
   - $3, $4, etc. for further back

2. COLUMN NAMES:
   - SHOW/DESCRIBE output columns are lowercase
   - Use double-quotes: "name", "type", "rows"

3. EXECUTION:
   - Sequential guaranteed
   - Error stops chain
   - Semicolon only at end

4. PERFORMANCE:
   - Regular JOINs usually faster than chained queries
   - Best for metadata queries and workflow automation
*/

-- ============================================================================
-- Comparison: Old vs New Approach
-- ============================================================================

-- OLD (without pipe operator):
-- SHOW TABLES IN AUTOMATED_INTELLIGENCE.RAW;
-- SELECT "name", "rows" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- NEW (with pipe operator):
SHOW TABLES IN AUTOMATED_INTELLIGENCE.RAW
->> SELECT "name", "rows" FROM $1;

-- ============================================================================
-- Demo Complete
-- ============================================================================
SELECT '✅ SQL Pipe Operator Demo Complete!' AS status;
