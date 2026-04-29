-- ============================================================================
-- Snowpipe Streaming Setup for Automated Intelligence
-- 
-- This script creates the PIPE objects required for Snowpipe Streaming
-- high-performance architecture to ingest data into the raw tables.
--
-- Prerequisites:
--   - Automated Intelligence database and tables must exist (run setup.sql first)
--   - User must have OPERATE privilege on PIPEs
-- ============================================================================

USE ROLE AUTOMATED_INTELLIGENCE;
USE DATABASE AUTOMATED_INTELLIGENCE;
USE SCHEMA RAW;
USE WAREHOUSE AUTOMATED_INTELLIGENCE_WH;

-- ============================================================================
-- Create PIPE Objects for Snowpipe Streaming
-- ============================================================================

-- Customers PIPE
-- Streams data directly into the customers table with simple pass-through mapping
-- Note: ON_ERROR defaults to CONTINUE (only supported option for Snowpipe Streaming)
CREATE OR REPLACE PIPE CUSTOMERS_PIPE
AS COPY INTO CUSTOMERS FROM (
    SELECT 
        $1:CUSTOMER_ID::INT,
        $1:FIRST_NAME::VARCHAR(50),
        $1:LAST_NAME::VARCHAR(50),
        $1:EMAIL::VARCHAR(100),
        $1:PHONE::VARCHAR(20),
        $1:ADDRESS::VARCHAR(200),
        $1:CITY::VARCHAR(50),
        $1:STATE::VARCHAR(2),
        $1:ZIP_CODE::VARCHAR(10),
        $1:REGISTRATION_DATE::DATE,
        $1:CUSTOMER_SEGMENT::VARCHAR(20)
    FROM TABLE(DATA_SOURCE(TYPE => 'STREAMING'))
);

-- Orders PIPE
-- Streams order data with proper type casting
CREATE OR REPLACE PIPE ORDERS_PIPE
AS COPY INTO ORDERS FROM (
    SELECT 
        $1:ORDER_ID::INT,
        $1:CUSTOMER_ID::INT,
        $1:ORDER_DATE::TIMESTAMP,
        $1:ORDER_STATUS::VARCHAR(20),
        $1:TOTAL_AMOUNT::DECIMAL(10,2),
        $1:DISCOUNT_PERCENT::DECIMAL(5,2),
        $1:SHIPPING_COST::DECIMAL(8,2)
    FROM TABLE(DATA_SOURCE(TYPE => 'STREAMING'))
);

-- Order Items PIPE
-- Streams order item details with product information
CREATE OR REPLACE PIPE ORDER_ITEMS_PIPE
AS COPY INTO ORDER_ITEMS FROM (
    SELECT 
        $1:ORDER_ITEM_ID::INT,
        $1:ORDER_ID::INT,
        $1:PRODUCT_ID::INT,
        $1:PRODUCT_NAME::VARCHAR(100),
        $1:PRODUCT_CATEGORY::VARCHAR(50),
        $1:QUANTITY::INT,
        $1:UNIT_PRICE::DECIMAL(10,2),
        $1:LINE_TOTAL::DECIMAL(12,2)
    FROM TABLE(DATA_SOURCE(TYPE => 'STREAMING'))
);

-- ============================================================================
-- Verify PIPE Objects
-- ============================================================================

SHOW PIPES IN SCHEMA AUTOMATED_INTELLIGENCE.RAW;

-- ============================================================================
-- Grant Privileges (if needed for specific users)
-- ============================================================================

-- Grant OPERATE privilege on pipes to allow Snowpipe Streaming client to use them
-- Replace YOUR_STREAMING_USER with the actual user running the Java application

-- GRANT OPERATE ON PIPE AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS_PIPE TO USER YOUR_STREAMING_USER;
-- GRANT OPERATE ON PIPE AUTOMATED_INTELLIGENCE.RAW.ORDERS_PIPE TO USER YOUR_STREAMING_USER;
-- GRANT OPERATE ON PIPE AUTOMATED_INTELLIGENCE.RAW.ORDER_ITEMS_PIPE TO USER YOUR_STREAMING_USER;

-- Alternatively, grant to role
-- GRANT OPERATE ON PIPE AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS_PIPE TO ROLE AUTOMATED_INTELLIGENCE;
-- GRANT OPERATE ON PIPE AUTOMATED_INTELLIGENCE.RAW.ORDERS_PIPE TO ROLE AUTOMATED_INTELLIGENCE;
-- GRANT OPERATE ON PIPE AUTOMATED_INTELLIGENCE.RAW.ORDER_ITEMS_PIPE TO ROLE AUTOMATED_INTELLIGENCE;

-- ============================================================================
-- Monitoring Queries
-- ============================================================================

-- Check channel status and ingestion progress
-- Note: SNOWPIPE_STREAMING_CHANNEL_HISTORY view shows channel activity
-- This view is available in ACCOUNT_USAGE schema

-- SELECT 
--     CHANNEL_NAME,
--     PIPE_NAME,
--     TABLE_NAME,
--     CREATED_TIME,
--     LAST_COMMITTED_TIME,
--     OFFSET_TOKEN,
--     STATUS
-- FROM SNOWFLAKE.ACCOUNT_USAGE.SNOWPIPE_STREAMING_CHANNEL_HISTORY
-- WHERE TABLE_DATABASE = 'AUTOMATED_INTELLIGENCE'
--   AND TABLE_SCHEMA = 'RAW'
-- ORDER BY LAST_COMMITTED_TIME DESC;

-- Check recent data in tables
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM CUSTOMERS
UNION ALL
SELECT 'orders', COUNT(*) FROM ORDERS
UNION ALL
SELECT 'order_items', COUNT(*) FROM ORDER_ITEMS
ORDER BY table_name;

-- ============================================================================
-- Setup Complete!
-- 
-- Next Steps:
--   1. Generate RSA key pair for authentication (see README.md)
--   2. Configure profile.json with your connection details
--   3. Update config.properties if needed
--   4. Build and run the Java application
-- ============================================================================
