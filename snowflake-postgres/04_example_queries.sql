-- ============================================================================
-- Example Queries: Using Postgres External Access
-- ============================================================================
-- Run these in Snowflake (Snowsight) to query your Postgres database
-- ============================================================================

-- ============================================================================
-- Context: Database, Schema, Role
-- ============================================================================
USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
USE DATABASE AUTOMATED_INTELLIGENCE;
USE WAREHOUSE AUTOMATED_INTELLIGENCE_WH;
USE SCHEMA POSTGRES;

-- ============================================================================
-- Method 1: Using CALL query_postgres() - Returns VARIANT
-- ============================================================================

-- Get row counts
CALL query_postgres('SELECT COUNT(*) as cnt FROM product_reviews');
CALL query_postgres('SELECT COUNT(*) as cnt FROM support_tickets');

-- Get table summary
CALL query_postgres('
    SELECT 
        ''product_reviews'' as table_name, COUNT(*) as row_count FROM product_reviews
    UNION ALL
    SELECT ''support_tickets'', COUNT(*) FROM support_tickets
');

-- ============================================================================
-- Method 2: Using TABLE(pg_query()) - Returns Table
-- ============================================================================

-- Query product reviews as a table
SELECT result FROM TABLE(pg_query('SELECT * FROM product_reviews LIMIT 10'));

-- Extract specific fields from reviews
SELECT 
    result:review_id::INT as review_id,
    result:product_id::INT as product_id,
    result:rating::INT as rating,
    result:review_title::STRING as title,
    result:verified_purchase::BOOLEAN as verified
FROM TABLE(pg_query('SELECT * FROM product_reviews ORDER BY review_date DESC LIMIT 10'));

-- Query support tickets with formatting
SELECT 
    result:ticket_id::INT as ticket_id,
    result:customer_id::INT as customer_id,
    result:ticket_date::TIMESTAMP as ticket_date,
    result:category::STRING as category,
    result:priority::STRING as priority,
    result:status::STRING as status
FROM TABLE(pg_query('SELECT * FROM support_tickets ORDER BY ticket_date DESC LIMIT 10'));

-- ============================================================================
-- Method 3: Analytics Queries (run in Postgres)
-- ============================================================================

-- Rating distribution
SELECT result FROM TABLE(pg_query('
    SELECT 
        rating,
        COUNT(*) as count,
        ROUND(AVG(CASE WHEN verified_purchase THEN 1 ELSE 0 END) * 100, 1) as verified_pct
    FROM product_reviews
    GROUP BY rating
    ORDER BY rating DESC
'));

-- Ticket status summary
SELECT result FROM TABLE(pg_query('
    SELECT 
        status,
        COUNT(*) as count,
        COUNT(*) FILTER (WHERE priority = ''High'' OR priority = ''Urgent'') as high_priority
    FROM support_tickets
    GROUP BY status
    ORDER BY count DESC
'));

-- Tickets by category and priority
SELECT result FROM TABLE(pg_query('
    SELECT 
        category,
        priority,
        COUNT(*) as ticket_count
    FROM support_tickets
    GROUP BY category, priority
    ORDER BY category, 
        CASE priority 
            WHEN ''Urgent'' THEN 1 
            WHEN ''High'' THEN 2 
            WHEN ''Medium'' THEN 3 
            ELSE 4 
        END
'));

-- Recent negative reviews (for follow-up)
SELECT result FROM TABLE(pg_query('
    SELECT 
        review_id,
        product_id,
        customer_id,
        rating,
        review_title,
        review_date
    FROM product_reviews
    WHERE rating <= 2
    ORDER BY review_date DESC
    LIMIT 10
'));
