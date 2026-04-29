-- ============================================================================
-- ASYNC SQL Demo - Asynchronous Child Jobs in Stored Procedures
-- ============================================================================
-- Execute SQL statements concurrently within stored procedures using
-- the ASYNC and AWAIT keywords. Similar to async/await in C# or JavaScript.
-- 
-- Key Concepts:
-- - ASYNC (statement): Run statement asynchronously
-- - AWAIT resultset: Wait for specific async job
-- - AWAIT ALL: Wait for all pending async jobs
-- ============================================================================

USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
USE DATABASE AUTOMATED_INTELLIGENCE;
USE WAREHOUSE AUTOMATED_INTELLIGENCE_WH;

-- ============================================================================
-- PART 1: Basic ASYNC Pattern
-- ============================================================================

-- Simple procedure with parallel inserts
CREATE OR REPLACE PROCEDURE AUTOMATED_INTELLIGENCE.RAW.demo_async_basic()
RETURNS VARCHAR
LANGUAGE SQL
AS
BEGIN
    -- Create test table
    CREATE OR REPLACE TEMP TABLE async_test (id INT, message VARCHAR, ts TIMESTAMP);
    
    -- Run 3 inserts asynchronously (in parallel)
    ASYNC (INSERT INTO async_test VALUES (1, 'First insert', CURRENT_TIMESTAMP()));
    ASYNC (INSERT INTO async_test VALUES (2, 'Second insert', CURRENT_TIMESTAMP()));
    ASYNC (INSERT INTO async_test VALUES (3, 'Third insert', CURRENT_TIMESTAMP()));
    
    -- Wait for all to complete
    AWAIT ALL;
    
    RETURN 'Inserted 3 rows in parallel';
END;

-- Test it
CALL AUTOMATED_INTELLIGENCE.RAW.demo_async_basic();

-- ============================================================================
-- PART 2: ASYNC with RESULTSET - Capture Results
-- ============================================================================

-- Procedure that runs queries concurrently and collects results
CREATE OR REPLACE PROCEDURE AUTOMATED_INTELLIGENCE.RAW.demo_async_with_results()
RETURNS TABLE(metric VARCHAR, count_value INT)
LANGUAGE SQL
AS
BEGIN
    -- Run queries asynchronously and capture results
    LET orders_count RESULTSET := ASYNC (SELECT COUNT(*) AS cnt FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS);
    LET customers_count RESULTSET := ASYNC (SELECT COUNT(*) AS cnt FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS);
    LET products_count RESULTSET := ASYNC (SELECT COUNT(*) AS cnt FROM AUTOMATED_INTELLIGENCE.RAW.PRODUCT_CATALOG);
    
    -- Wait for each and store results
    AWAIT orders_count;
    AWAIT customers_count;
    AWAIT products_count;
    
    -- Combine results
    CREATE OR REPLACE TEMP TABLE async_results (metric VARCHAR, count_value INT);
    
    -- Use cursors to extract values
    LET c1 CURSOR FOR orders_count;
    OPEN c1;
    FOR r IN c1 DO
        INSERT INTO async_results VALUES ('orders', r.cnt);
    END FOR;
    
    LET c2 CURSOR FOR customers_count;
    OPEN c2;
    FOR r IN c2 DO
        INSERT INTO async_results VALUES ('customers', r.cnt);
    END FOR;
    
    LET c3 CURSOR FOR products_count;
    OPEN c3;
    FOR r IN c3 DO
        INSERT INTO async_results VALUES ('products', r.cnt);
    END FOR;
    
    LET result RESULTSET := (SELECT * FROM async_results);
    RETURN TABLE(result);
END;

-- Test it
CALL AUTOMATED_INTELLIGENCE.RAW.demo_async_with_results();

-- ============================================================================
-- PART 3: ASYNC in Loops - Dynamic Parallel Processing
-- ============================================================================

-- Process multiple customers in parallel
CREATE OR REPLACE PROCEDURE AUTOMATED_INTELLIGENCE.RAW.demo_async_loop()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
BEGIN
    -- Create target table
    CREATE OR REPLACE TEMP TABLE customer_order_counts (customer_id INT, order_count INT);
    
    -- Get sample customers
    LET customers RESULTSET := (
        SELECT customer_id 
        FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS 
        WHERE customer_segment = 'Premium' 
        LIMIT 10
    );
    
    -- Process each customer asynchronously
    FOR cust IN customers DO
        LET cid INT := cust.customer_id;
        ASYNC (
            INSERT INTO customer_order_counts 
            SELECT :cid, COUNT(*) 
            FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS 
            WHERE customer_id = :cid
        );
    END FOR;
    
    -- Wait for all parallel jobs
    AWAIT ALL;
    
    RETURN 'Processed 10 customers in parallel';
END;

-- Test it
CALL AUTOMATED_INTELLIGENCE.RAW.demo_async_loop();

-- ============================================================================
-- PART 4: Nested Async Procedures
-- ============================================================================

-- Create helper procedures
CREATE OR REPLACE PROCEDURE AUTOMATED_INTELLIGENCE.RAW.demo_async_helper_orders()
RETURNS VARCHAR
LANGUAGE SQL
AS
BEGIN
    CREATE OR REPLACE TEMP TABLE order_summary AS
    SELECT DATE_TRUNC('month', order_date) AS month, COUNT(*) AS orders
    FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS
    GROUP BY month;
    RETURN 'Orders summarized';
END;

CREATE OR REPLACE PROCEDURE AUTOMATED_INTELLIGENCE.RAW.demo_async_helper_customers()
RETURNS VARCHAR
LANGUAGE SQL
AS
BEGIN
    CREATE OR REPLACE TEMP TABLE customer_summary AS
    SELECT customer_segment, COUNT(*) AS customers
    FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS
    GROUP BY customer_segment;
    RETURN 'Customers summarized';
END;

-- Main procedure that calls helpers in parallel
CREATE OR REPLACE PROCEDURE AUTOMATED_INTELLIGENCE.RAW.demo_async_nested()
RETURNS VARCHAR
LANGUAGE SQL
AS
BEGIN
    -- Run child procedures asynchronously
    ASYNC (CALL AUTOMATED_INTELLIGENCE.RAW.demo_async_helper_orders());
    ASYNC (CALL AUTOMATED_INTELLIGENCE.RAW.demo_async_helper_customers());
    
    -- Wait for both
    AWAIT ALL;
    
    RETURN 'Both summaries completed in parallel';
END;

-- Test it
CALL AUTOMATED_INTELLIGENCE.RAW.demo_async_nested();

-- ============================================================================
-- PART 5: ASYNC with Updates
-- ============================================================================

-- Parallel updates pattern
CREATE OR REPLACE PROCEDURE AUTOMATED_INTELLIGENCE.RAW.demo_async_updates()
RETURNS VARCHAR
LANGUAGE SQL
AS
BEGIN
    -- Create test table with partitions
    CREATE OR REPLACE TEMP TABLE partitioned_data (partition_id INT, value INT);
    INSERT INTO partitioned_data VALUES (1, 100), (2, 200), (3, 300);
    
    -- Update partitions in parallel
    ASYNC (UPDATE partitioned_data SET value = value * 2 WHERE partition_id = 1);
    ASYNC (UPDATE partitioned_data SET value = value * 2 WHERE partition_id = 2);
    ASYNC (UPDATE partitioned_data SET value = value * 2 WHERE partition_id = 3);
    
    AWAIT ALL;
    
    RETURN 'All partitions updated in parallel';
END;

-- Test it
CALL AUTOMATED_INTELLIGENCE.RAW.demo_async_updates();

-- ============================================================================
-- PART 6: Error Handling
-- ============================================================================

-- When an async job fails, AWAIT raises an exception
CREATE OR REPLACE PROCEDURE AUTOMATED_INTELLIGENCE.RAW.demo_async_error_handling()
RETURNS VARCHAR
LANGUAGE SQL
AS
BEGIN
    BEGIN
        -- This will fail - table doesn't exist
        LET res RESULTSET := ASYNC (SELECT * FROM nonexistent_table);
        AWAIT res;  -- Exception raised here
    EXCEPTION
        WHEN OTHER THEN
            RETURN 'Caught error: ' || SQLERRM;
    END;
    RETURN 'No error';
END;

-- Test it
CALL AUTOMATED_INTELLIGENCE.RAW.demo_async_error_handling();

-- ============================================================================
-- Key Takeaways
-- ============================================================================

/*
1. SYNTAX:
   - ASYNC (statement) - parentheses are required
   - LET res RESULTSET := ASYNC (query) - capture results
   - AWAIT resultset - wait for specific job
   - AWAIT ALL - wait for all pending jobs

2. USE CASES:
   - Parallel data loading
   - Concurrent aggregations
   - Partitioned updates
   - Calling multiple child procedures

3. BEST PRACTICES:
   - Always use AWAIT or AWAIT ALL before procedure ends
   - Handle exceptions with TRY/CATCH
   - Partition work to avoid conflicts (e.g., by partition_id)
   
4. LIMITATIONS:
   - Only works in SQL stored procedures
   - Cannot access RESULTSET until AWAIT completes
   - Failed jobs cause AWAIT to throw exception
*/

-- ============================================================================
-- Demo Complete
-- ============================================================================
SELECT '✅ ASYNC SQL Demo Complete!' AS status;
