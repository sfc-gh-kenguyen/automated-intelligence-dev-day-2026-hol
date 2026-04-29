-- ============================================================================
-- INGESTION TO INTELLIGENCE - Complete Setup Script
-- 
-- Theme: From raw data to AI-powered insights—entirely within Snowflake.
--
-- This script creates all infrastructure for the demo journey:
--   Act 1: Ingest & Stage    → Streaming tables, staging, dynamic tables
--   Act 2: Serve & Analyze   → Interactive tables, dbt schemas, ML models
--   Act 3: Intelligence      → Cortex Search, semantic views, AI functions
--   Bonus: Open Lakehouse    → Iceberg export (separate script)
--
-- Execution Order:
--   0. PREREQUISITES: Grant account-level privileges (ACCOUNTADMIN only)
--   1. Clean up existing objects (WIPE SLATE)
--   2. Create database, schemas, warehouses
--   3. Create raw tables and stored procedures (Act 1)
--   4. Create dynamic tables pipeline (Act 1)
--   5. Create interactive tables (Act 2)
--   6. Create AI/ML infrastructure (Act 3)
--   7. Create Cortex Search Service (Act 3)
--   8. Create Semantic View (Act 3)
--
-- IMPORTANT: Run PREREQUISITES section first as ACCOUNTADMIN, then the rest
-- ============================================================================

-- ============================================================================
-- PREREQUISITES: ACCOUNTADMIN GRANTS (Run as ACCOUNTADMIN first)
-- ============================================================================
-- This section MUST be run as ACCOUNTADMIN before executing the rest of the script.
-- 
-- CREATE SNOWFLAKE INTELLIGENCE ON ACCOUNT is an account-level privilege that controls 
-- who can create Snowflake Intelligence objects (Agents, Analysts) within your account.
-- This ensures proper governance over AI capabilities through:
--   - Security: Only authorized roles can create Intelligence objects
--   - Controlled Rollout: Administrators control which roles manage Snowflake Intelligence
--   - Layered Permissions: Additional USAGE/ALTER privileges control object access after creation

USE ROLE ACCOUNTADMIN;

-- Create the role for managing automated intelligence platform
CREATE ROLE IF NOT EXISTS AUTOMATED_INTELLIGENCE
  COMMENT = 'Role for managing the Automated Intelligence platform including databases, warehouses, dynamic tables, and Snowflake Intelligence objects';

-- Grant Snowflake Intelligence privilege to allow creation of AI agents and analysts
GRANT CREATE SNOWFLAKE INTELLIGENCE ON ACCOUNT TO ROLE AUTOMATED_INTELLIGENCE;

-- ============================================================================
-- MAIN SETUP: Switch to AUTOMATED_INTELLIGENCE role
-- ============================================================================
-- After running the PREREQUISITES section above, execute the rest with this role
USE ROLE AUTOMATED_INTELLIGENCE;

-- ============================================================================
-- STEP 0: WIPE SLATE - Drop all existing objects
-- ============================================================================

-- Create database if not exists (needed for context)
CREATE DATABASE IF NOT EXISTS automated_intelligence;
USE DATABASE automated_intelligence;

-- Drop alerts first (dependencies on views/tables)
DROP ALERT IF EXISTS raw.data_quality_alert;

-- Drop Cortex Search Services
DROP CORTEX SEARCH SERVICE IF EXISTS raw.product_search_service;

-- Drop views (before tables they depend on)
-- Note: Some schemas may not exist yet, which is fine
DROP VIEW IF EXISTS raw.vw_dq_monitoring_results;
-- Skip views in schemas that may not exist (they'll be dropped with CASCADE)
-- DROP VIEW IF EXISTS analytics_iceberg.ingestion_stats;
-- DROP VIEW IF EXISTS dbt_staging.stg_customers;
-- DROP VIEW IF EXISTS dbt_staging.stg_orders;
-- DROP VIEW IF EXISTS dbt_staging.stg_order_items;
-- DROP VIEW IF EXISTS dbt_staging.stg_products;

-- Drop dynamic tables (in reverse dependency order)
DROP DYNAMIC TABLE IF EXISTS dynamic_tables.product_performance_metrics;
DROP DYNAMIC TABLE IF EXISTS dynamic_tables.daily_business_metrics;
DROP DYNAMIC TABLE IF EXISTS dynamic_tables.fact_orders;
DROP DYNAMIC TABLE IF EXISTS dynamic_tables.enriched_order_items;
DROP DYNAMIC TABLE IF EXISTS dynamic_tables.enriched_orders;

-- Drop tables in schemas that may not exist (they'll be dropped with CASCADE)
-- DROP TABLE IF EXISTS interactive.customer_order_analytics;
-- DROP TABLE IF EXISTS interactive.order_lookup;

-- Drop base tables in all schemas
DROP TABLE IF EXISTS raw.trulens_records;
DROP TABLE IF EXISTS raw.trulens_ground_truth;
DROP TABLE IF EXISTS raw.trulens_feedback_defs;
DROP TABLE IF EXISTS raw.trulens_feedbacks;
DROP TABLE IF EXISTS raw.trulens_dataset;
DROP TABLE IF EXISTS raw.trulens_apps;
DROP TABLE IF EXISTS raw.trulens_alembic_version;
DROP TABLE IF EXISTS raw.support_tickets;
DROP TABLE IF EXISTS raw.product_reviews;
DROP TABLE IF EXISTS raw.product_performance_metrics;
DROP TABLE IF EXISTS raw.product_catalog;
DROP TABLE IF EXISTS raw.order_items_backup;
DROP TABLE IF EXISTS raw.order_items;
DROP TABLE IF EXISTS raw.orders_backup;
DROP TABLE IF EXISTS raw.orders;
DROP TABLE IF EXISTS raw.fact_orders;
DROP TABLE IF EXISTS raw.enriched_order_items;
DROP TABLE IF EXISTS raw.enriched_orders;
DROP TABLE IF EXISTS raw.daily_business_metrics;
DROP TABLE IF EXISTS raw.data_quality_alerts;
DROP TABLE IF EXISTS raw.customers;

DROP TABLE IF EXISTS staging.order_items_staging;
DROP TABLE IF EXISTS staging.orders_staging;
DROP TABLE IF EXISTS staging.discount_snapshot;

-- Drop tables in schemas that may not exist (they'll be dropped with CASCADE)
-- DROP TABLE IF EXISTS dbt_analytics.product_recommendations;
-- DROP TABLE IF EXISTS dbt_analytics.product_affinity;
-- DROP TABLE IF EXISTS dbt_analytics.monthly_cohorts;
-- DROP TABLE IF EXISTS dbt_analytics.customer_segmentation;
-- DROP TABLE IF EXISTS dbt_analytics.customer_lifetime_value;

-- Note: Iceberg tables require external volume privileges to drop
-- Skipping these - they will be recreated if needed or can be dropped manually with ACCOUNTADMIN
-- DROP TABLE IF EXISTS analytics_iceberg.order_items;
-- DROP TABLE IF EXISTS analytics_iceberg.orders;

-- Drop stored procedures
DROP PROCEDURE IF EXISTS raw.generate_customers(INT);
DROP PROCEDURE IF EXISTS staging.merge_staging_to_raw(BOOLEAN);
DROP PROCEDURE IF EXISTS staging.merge_staging_to_raw(VARCHAR, BOOLEAN);
DROP PROCEDURE IF EXISTS staging.enrich_raw_data(BOOLEAN);
DROP PROCEDURE IF EXISTS staging.enrich_raw_data(VARCHAR, BOOLEAN);
DROP PROCEDURE IF EXISTS staging.create_discount_snapshot();
DROP PROCEDURE IF EXISTS staging.restore_discount_snapshot();
DROP PROCEDURE IF EXISTS staging.truncate_staging_tables();
DROP PROCEDURE IF EXISTS staging.get_staging_counts();

-- Drop schemas (except INFORMATION_SCHEMA which is system-managed)
-- Note: analytics_iceberg schema may require ACCOUNTADMIN to drop due to external volume dependencies
-- DROP SCHEMA IF EXISTS analytics_iceberg CASCADE;
DROP SCHEMA IF EXISTS models CASCADE;
DROP SCHEMA IF EXISTS dbt_analytics CASCADE;
DROP SCHEMA IF EXISTS dbt_staging CASCADE;
DROP SCHEMA IF EXISTS dynamic_tables CASCADE;
DROP SCHEMA IF EXISTS interactive CASCADE;
DROP SCHEMA IF EXISTS staging CASCADE;
DROP SCHEMA IF EXISTS semantic CASCADE;
DROP SCHEMA IF EXISTS raw CASCADE;

-- ============================================================================
-- STEP 1: Infrastructure Foundation
-- Purpose: Database, schemas, and warehouses for all Acts
-- ============================================================================

-- Create database (already exists from step 0)
CREATE DATABASE IF NOT EXISTS automated_intelligence;

-- Create schemas
CREATE SCHEMA IF NOT EXISTS automated_intelligence.raw;
CREATE SCHEMA IF NOT EXISTS automated_intelligence.staging;
CREATE SCHEMA IF NOT EXISTS automated_intelligence.dynamic_tables;
CREATE SCHEMA IF NOT EXISTS automated_intelligence.interactive;
CREATE SCHEMA IF NOT EXISTS automated_intelligence.semantic;
CREATE SCHEMA IF NOT EXISTS automated_intelligence.models COMMENT = 'Schema for ML models registered via Snowflake Model Registry';
CREATE SCHEMA IF NOT EXISTS automated_intelligence.dbt_staging COMMENT = 'Schema for dbt staging models';
CREATE SCHEMA IF NOT EXISTS automated_intelligence.dbt_analytics COMMENT = 'Schema for dbt analytical models';

-- Create warehouse
CREATE WAREHOUSE IF NOT EXISTS automated_intelligence_wh
  WITH WAREHOUSE_SIZE = 'SMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Warehouse for automated intelligence dynamic tables demo';

-- Set context
USE DATABASE automated_intelligence;
USE SCHEMA raw;
USE WAREHOUSE automated_intelligence_wh;


-- ============================================================================
-- STEP 2: Raw Tables (Act 1 - Ingest & Stage)
-- Purpose: Landing zone for Snowpipe Streaming data
-- ============================================================================

-- Create customers table
CREATE OR REPLACE TABLE customers (
    customer_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    phone VARCHAR(20),
    address VARCHAR(200),
    city VARCHAR(50),
    state VARCHAR(2),
    zip_code VARCHAR(10),
    registration_date DATE,
    customer_segment VARCHAR(20)
);

-- Create orders table
-- Note: order_id uses VARCHAR to support UUID from Snowpipe Streaming
CREATE OR REPLACE TABLE orders (
    order_id VARCHAR(36) PRIMARY KEY,
    customer_id INT,
    order_date TIMESTAMP,
    order_status VARCHAR(20),
    total_amount DECIMAL(10, 2),
    discount_percent DECIMAL(5, 2),
    shipping_cost DECIMAL(8, 2)
);

-- Create order_items table
-- Note: order_item_id and order_id use VARCHAR to support UUID from Snowpipe Streaming
CREATE OR REPLACE TABLE order_items (
    order_item_id VARCHAR(36) PRIMARY KEY,
    order_id VARCHAR(36),
    product_id INT,
    product_name VARCHAR(100),
    product_category VARCHAR(50),
    quantity INT,
    unit_price DECIMAL(10, 2),
    line_total DECIMAL(12, 2)
);

-- ============================================================================
-- STEP 3: Stored Procedures (Act 1 - Ingest & Stage)
-- Purpose: Data generation and staging operations
-- ============================================================================

-- Procedure: generate_customers
-- Purpose: Generate customer records independently
-- Parameters: num_customers - Number of new customers to create
CREATE OR REPLACE PROCEDURE generate_customers(num_customers INT)
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    LET next_customer_id INT := (SELECT COALESCE(MAX(customer_id), 0) + 1 FROM customers);
    
    INSERT INTO customers
    SELECT
        :next_customer_id + ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS customer_id,
        CASE UNIFORM(1, 20, RANDOM())
            WHEN 1 THEN 'John' WHEN 2 THEN 'Sarah' WHEN 3 THEN 'Michael' WHEN 4 THEN 'Emily'
            WHEN 5 THEN 'David' WHEN 6 THEN 'Jessica' WHEN 7 THEN 'Chris' WHEN 8 THEN 'Ashley'
            WHEN 9 THEN 'Matt' WHEN 10 THEN 'Amanda' WHEN 11 THEN 'Ryan' WHEN 12 THEN 'Lauren'
            WHEN 13 THEN 'Kevin' WHEN 14 THEN 'Nicole' WHEN 15 THEN 'Brian' WHEN 16 THEN 'Rachel'
            WHEN 17 THEN 'Tyler' WHEN 18 THEN 'Megan' WHEN 19 THEN 'Josh' ELSE 'Katie'
        END AS first_name,
        CASE UNIFORM(1, 20, RANDOM())
            WHEN 1 THEN 'Smith' WHEN 2 THEN 'Johnson' WHEN 3 THEN 'Williams' WHEN 4 THEN 'Brown'
            WHEN 5 THEN 'Jones' WHEN 6 THEN 'Garcia' WHEN 7 THEN 'Miller' WHEN 8 THEN 'Davis'
            WHEN 9 THEN 'Rodriguez' WHEN 10 THEN 'Martinez' WHEN 11 THEN 'Hernandez' WHEN 12 THEN 'Lopez'
            WHEN 13 THEN 'Gonzalez' WHEN 14 THEN 'Wilson' WHEN 15 THEN 'Anderson' WHEN 16 THEN 'Thomas'
            WHEN 17 THEN 'Taylor' WHEN 18 THEN 'Moore' WHEN 19 THEN 'Jackson' ELSE 'Martin'
        END AS last_name,
        'customer' || (:next_customer_id + ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1) || '@email.com' AS email,
        '555-' || LPAD(UNIFORM(100, 999, RANDOM())::STRING, 3, '0') || '-' || LPAD(UNIFORM(1000, 9999, RANDOM())::STRING, 4, '0') AS phone,
        UNIFORM(100, 9999, RANDOM()) || ' ' || CASE UNIFORM(1, 10, RANDOM())
            WHEN 1 THEN 'Main St' WHEN 2 THEN 'Oak Ave' WHEN 3 THEN 'Maple Dr' 
            WHEN 4 THEN 'Cedar Ln' WHEN 5 THEN 'Pine Rd' WHEN 6 THEN 'Elm St'
            WHEN 7 THEN 'Washington Blvd' WHEN 8 THEN 'Lake View Dr' WHEN 9 THEN 'Mountain Way'
            ELSE 'Summit Trail'
        END AS address,
        CASE UNIFORM(1, 15, RANDOM())
            WHEN 1 THEN 'Denver' WHEN 2 THEN 'Salt Lake City' WHEN 3 THEN 'Boulder'
            WHEN 4 THEN 'Aspen' WHEN 5 THEN 'Park City' WHEN 6 THEN 'Jackson'
            WHEN 7 THEN 'Telluride' WHEN 8 THEN 'Steamboat Springs' WHEN 9 THEN 'Vail'
            WHEN 10 THEN 'Breckenridge' WHEN 11 THEN 'Mammoth Lakes' WHEN 12 THEN 'Tahoe City'
            WHEN 13 THEN 'Whistler' WHEN 14 THEN 'Banff' ELSE 'Portland'
        END AS city,
        CASE UNIFORM(1, 10, RANDOM())
            WHEN 1 THEN 'CO' WHEN 2 THEN 'UT' WHEN 3 THEN 'WY'
            WHEN 4 THEN 'CA' WHEN 5 THEN 'WA' WHEN 6 THEN 'OR'
            WHEN 7 THEN 'MT' WHEN 8 THEN 'ID' WHEN 9 THEN 'NV' ELSE 'BC'
        END AS state,
        LPAD(UNIFORM(10000, 99999, RANDOM())::STRING, 5, '0') AS zip_code,
        DATEADD(day, -UNIFORM(1, 1825, RANDOM()), CURRENT_DATE()) AS registration_date,
        CASE UNIFORM(1, 3, RANDOM())
            WHEN 1 THEN 'Premium'
            WHEN 2 THEN 'Standard'
            ELSE 'Basic'
        END AS customer_segment
    FROM TABLE(GENERATOR(ROWCOUNT => :num_customers));
    
    RETURN 'Successfully generated ' || :num_customers || ' customers';
END;
$$;

-- Verify procedures created
SHOW PROCEDURES LIKE '%generate%';


-- ============================================================================
-- STEP 3.5: Staging Layer + Gen2 Warehouse (Act 1 - Ingest & Stage)
-- Purpose: Staging tables for MERGE operations, Gen2 for Optima Indexing
-- ============================================================================

USE SCHEMA automated_intelligence.staging;

-- Create staging tables for Snowpipe Streaming
CREATE TABLE IF NOT EXISTS orders_staging (
    order_id VARCHAR(36),
    customer_id INTEGER,
    order_date TIMESTAMP_NTZ,
    order_status VARCHAR(20),
    total_amount FLOAT,
    discount_percent FLOAT,
    shipping_cost FLOAT
)
COMMENT = 'Staging table for order data from Snowpipe Streaming';

CREATE TABLE IF NOT EXISTS order_items_staging (
    order_item_id VARCHAR(36),
    order_id VARCHAR(36),
    product_id INTEGER,
    product_name VARCHAR(100),
    product_category VARCHAR(50),
    quantity INTEGER,
    unit_price FLOAT,
    line_total FLOAT
)
COMMENT = 'Staging table for order item data from Snowpipe Streaming';

-- Snapshot table for benchmarking
CREATE TABLE IF NOT EXISTS discount_snapshot (
    order_id VARCHAR(36),
    discount_percent FLOAT
);

-- Create Gen2 warehouse
CREATE WAREHOUSE IF NOT EXISTS automated_intelligence_gen2_wh
WITH 
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    GENERATION = '2'
    COMMENT = 'Gen2 warehouse for data transformation';

-- Procedure: merge_staging_to_raw
CREATE OR REPLACE PROCEDURE merge_staging_to_raw(
    return_timing BOOLEAN DEFAULT TRUE
)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    start_time TIMESTAMP_NTZ;
    end_time TIMESTAMP_NTZ;
    orders_merged INTEGER;
    order_items_merged INTEGER;
    orders_start TIMESTAMP_NTZ;
    orders_end TIMESTAMP_NTZ;
    items_start TIMESTAMP_NTZ;
    items_end TIMESTAMP_NTZ;
BEGIN
    start_time := CURRENT_TIMESTAMP();
    
    orders_start := CURRENT_TIMESTAMP();
    
    MERGE INTO raw.orders tgt
    USING (
        SELECT 
            order_id,
            customer_id,
            order_date,
            order_status,
            total_amount,
            discount_percent,
            shipping_cost
        FROM (
            SELECT *,
                   ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY order_date DESC) as rn
            FROM staging.orders_staging
        )
        WHERE rn = 1
    ) src
    ON tgt.order_id = src.order_id
    WHEN MATCHED THEN UPDATE SET
        customer_id = src.customer_id,
        order_date = src.order_date,
        order_status = src.order_status,
        total_amount = src.total_amount,
        discount_percent = src.discount_percent,
        shipping_cost = src.shipping_cost
    WHEN NOT MATCHED THEN INSERT (
        order_id, customer_id, order_date, order_status, total_amount, discount_percent, shipping_cost
    ) VALUES (
        src.order_id, src.customer_id, src.order_date, src.order_status,
        src.total_amount, src.discount_percent, src.shipping_cost
    );
    
    orders_merged := SQLROWCOUNT;
    orders_end := CURRENT_TIMESTAMP();
    
    items_start := CURRENT_TIMESTAMP();
    
    MERGE INTO raw.order_items tgt
    USING (
        SELECT 
            order_item_id,
            order_id,
            product_id,
            product_name,
            product_category,
            quantity,
            unit_price,
            line_total
        FROM (
            SELECT *,
                   ROW_NUMBER() OVER (PARTITION BY order_item_id ORDER BY order_item_id) as rn
            FROM staging.order_items_staging
        )
        WHERE rn = 1
    ) src
    ON tgt.order_item_id = src.order_item_id
    WHEN MATCHED THEN UPDATE SET
        order_id = src.order_id,
        product_id = src.product_id,
        product_name = src.product_name,
        product_category = src.product_category,
        quantity = src.quantity,
        unit_price = src.unit_price,
        line_total = src.line_total
    WHEN NOT MATCHED THEN INSERT (
        order_item_id, order_id, product_id, product_name, product_category,
        quantity, unit_price, line_total
    ) VALUES (
        src.order_item_id, src.order_id, src.product_id, src.product_name,
        src.product_category, src.quantity, src.unit_price,
        src.line_total
    );
    
    order_items_merged := SQLROWCOUNT;
    items_end := CURRENT_TIMESTAMP();
    
    end_time := CURRENT_TIMESTAMP();
    
    IF (return_timing) THEN
        RETURN OBJECT_CONSTRUCT(
            'total_duration_ms', DATEDIFF('millisecond', start_time, end_time),
            'orders', OBJECT_CONSTRUCT(
                'records_merged', orders_merged,
                'duration_ms', DATEDIFF('millisecond', orders_start, orders_end)
            ),
            'order_items', OBJECT_CONSTRUCT(
                'records_merged', order_items_merged,
                'duration_ms', DATEDIFF('millisecond', items_start, items_end)
            ),
            'start_time', start_time,
            'end_time', end_time
        );
    ELSE
        RETURN OBJECT_CONSTRUCT('status', 'success');
    END IF;
END;
$$;

-- Procedure: enrich_raw_data
CREATE OR REPLACE PROCEDURE enrich_raw_data(
    return_timing BOOLEAN DEFAULT TRUE
)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    start_time TIMESTAMP_NTZ;
    end_time TIMESTAMP_NTZ;
    orders_updated INTEGER;
BEGIN
    start_time := CURRENT_TIMESTAMP();
    
    UPDATE raw.orders
    SET discount_percent = CASE 
        WHEN total_amount >= 1000 THEN LEAST(discount_percent + 5.0, 50.0)
        WHEN total_amount >= 500 THEN LEAST(discount_percent + 2.5, 50.0)
        ELSE discount_percent
    END
    WHERE order_date >= DATEADD('day', -30, CURRENT_DATE())
      AND discount_percent < 50.0;
    
    orders_updated := SQLROWCOUNT;
    
    end_time := CURRENT_TIMESTAMP();
    
    IF (return_timing) THEN
        RETURN OBJECT_CONSTRUCT(
            'orders_updated', orders_updated,
            'duration_ms', DATEDIFF('millisecond', start_time, end_time),
            'start_time', start_time,
            'end_time', end_time
        );
    ELSE
        RETURN OBJECT_CONSTRUCT('status', 'success');
    END IF;
END;
$$;

-- Procedure: create_discount_snapshot
CREATE OR REPLACE PROCEDURE create_discount_snapshot()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    TRUNCATE TABLE staging.discount_snapshot;
    
    INSERT INTO staging.discount_snapshot
    SELECT order_id, discount_percent
    FROM raw.orders
    WHERE order_date >= DATEADD('day', -30, CURRENT_DATE());
    
    RETURN 'Discount snapshot created';
END;
$$;

-- Procedure: restore_discount_snapshot
CREATE OR REPLACE PROCEDURE restore_discount_snapshot()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    UPDATE raw.orders
    SET discount_percent = snapshot.discount_percent
    FROM staging.discount_snapshot snapshot
    WHERE raw.orders.order_id = snapshot.order_id;
    
    RETURN 'Discount values restored from snapshot';
END;
$$;

-- Procedure: truncate_staging_tables
CREATE OR REPLACE PROCEDURE truncate_staging_tables()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    TRUNCATE TABLE staging.orders_staging;
    TRUNCATE TABLE staging.order_items_staging;
    
    RETURN 'Staging tables truncated successfully';
END;
$$;

-- Procedure: get_staging_counts
CREATE OR REPLACE PROCEDURE get_staging_counts()
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    orders_count INTEGER;
    order_items_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO orders_count FROM staging.orders_staging;
    SELECT COUNT(*) INTO order_items_count FROM staging.order_items_staging;
    
    RETURN OBJECT_CONSTRUCT(
        'orders_staging', orders_count,
        'order_items_staging', order_items_count,
        'total_pending', orders_count + order_items_count
    );
END;
$$;


-- ============================================================================
-- STEP 4: Dynamic Tables Pipeline (Act 1 - Ingest & Stage)
-- Purpose: 3-tier incremental refresh pipeline (Enrichment → Integration → Aggregation)
-- ============================================================================

USE SCHEMA automated_intelligence.dynamic_tables;
USE WAREHOUSE automated_intelligence_wh;

-- Drop existing dynamic tables to avoid schema conflicts when updating
DROP DYNAMIC TABLE IF EXISTS product_performance_metrics;
DROP DYNAMIC TABLE IF EXISTS daily_business_metrics;
DROP DYNAMIC TABLE IF EXISTS fact_orders;
DROP DYNAMIC TABLE IF EXISTS enriched_order_items;
DROP DYNAMIC TABLE IF EXISTS enriched_orders;

-- ----------------------------------------------------------------------------
-- TIER 1: Enrichment Layer
-- Purpose: Add temporal dimensions and calculated fields to raw data
-- Target Lag: 12 hours (time-based scheduling)
-- Refresh Mode: INCREMENTAL
-- ----------------------------------------------------------------------------

-- Enriched Orders: Add temporal dimensions and financial calculations
-- TARGET_LAG = '1 minute' for near real-time analytics (matches Snowpipe Streaming latency)
CREATE OR REPLACE DYNAMIC TABLE enriched_orders
TARGET_LAG = '1 minute'
WAREHOUSE = automated_intelligence_wh
SCHEDULER = ENABLE
REFRESH_MODE = INCREMENTAL
AS
SELECT
    o.order_id,
    o.customer_id,
    o.order_date,
    o.order_status,
    
    -- Temporal dimensions
    DATE(o.order_date) AS order_date_only,
    YEAR(o.order_date) AS order_year,
    QUARTER(o.order_date) AS order_quarter,
    MONTH(o.order_date) AS order_month,
    DAYOFWEEK(o.order_date) AS order_day_of_week,
    DAYNAME(o.order_date) AS order_day_name,
    WEEK(o.order_date) AS order_week,
    
    -- Financial calculations
    o.total_amount,
    o.discount_percent,
    o.shipping_cost,
    ROUND(o.total_amount * (o.discount_percent / 100), 2) AS discount_amount,
    ROUND(o.total_amount - (o.total_amount * (o.discount_percent / 100)), 2) AS net_amount,
    ROUND(o.total_amount - (o.total_amount * (o.discount_percent / 100)) + o.shipping_cost, 2) AS final_amount,
    
    -- Discount flags
    CASE WHEN o.discount_percent > 0 THEN TRUE ELSE FALSE END AS has_discount,
    CASE 
        WHEN o.discount_percent = 0 THEN 'No Discount'
        WHEN o.discount_percent <= 10 THEN 'Low Discount'
        WHEN o.discount_percent <= 20 THEN 'Medium Discount'
        ELSE 'High Discount'
    END AS discount_tier,
    
    -- Order size
    CASE
        WHEN o.total_amount < 100 THEN 'Small'
        WHEN o.total_amount < 500 THEN 'Medium'
        WHEN o.total_amount < 2000 THEN 'Large'
        ELSE 'Extra Large'
    END AS order_size_category
FROM automated_intelligence.raw.orders o;

-- Enriched Order Items: Add price analysis and category flags
-- TARGET_LAG = '1 minute' for near real-time analytics (matches Snowpipe Streaming latency)
CREATE OR REPLACE DYNAMIC TABLE enriched_order_items
TARGET_LAG = '1 minute'
WAREHOUSE = automated_intelligence_wh
SCHEDULER = ENABLE
REFRESH_MODE = INCREMENTAL
AS
SELECT
    oi.order_item_id,
    oi.order_id,
    oi.product_id,
    oi.product_name,
    oi.product_category,
    oi.quantity,
    oi.unit_price,
    oi.line_total,
    
    -- Price analysis
    ROUND(oi.line_total / oi.quantity, 2) AS actual_unit_price,
    ROUND(oi.unit_price - (oi.line_total / oi.quantity), 2) AS unit_price_variance,
    
    -- Category flags
    CASE WHEN oi.product_category = 'Skis' THEN TRUE ELSE FALSE END AS is_skis,
    CASE WHEN oi.product_category = 'Snowboards' THEN TRUE ELSE FALSE END AS is_snowboards,
    
    -- Quantity tiers
    CASE
        WHEN oi.quantity = 1 THEN 'Single'
        WHEN oi.quantity <= 3 THEN 'Few'
        ELSE 'Bulk'
    END AS quantity_tier
FROM automated_intelligence.raw.order_items oi;

-- ----------------------------------------------------------------------------
-- TIER 2: Integration Layer
-- Purpose: Join enriched tables to create denormalized fact table
-- Target Lag: DOWNSTREAM (waits for Tier 1 to complete)
-- Refresh Mode: INCREMENTAL
-- ----------------------------------------------------------------------------

CREATE OR REPLACE DYNAMIC TABLE fact_orders
TARGET_LAG = DOWNSTREAM
WAREHOUSE = automated_intelligence_wh
SCHEDULER = ENABLE
REFRESH_MODE = INCREMENTAL
AS
SELECT
    eo.order_id,
    eo.customer_id,
    eo.order_date,
    eo.order_date_only,
    eo.order_year,
    eo.order_quarter,
    eo.order_month,
    eo.order_day_of_week,
    eo.order_day_name,
    eo.order_week,
    eo.order_status,
    
    -- Order-level metrics
    eo.total_amount,
    eo.discount_percent,
    eo.discount_amount,
    eo.net_amount,
    eo.shipping_cost,
    eo.final_amount,
    eo.has_discount,
    eo.discount_tier,
    eo.order_size_category,
    
    -- Item-level details
    eoi.order_item_id,
    eoi.product_id,
    eoi.product_name,
    eoi.product_category,
    eoi.quantity,
    eoi.unit_price,
    eoi.line_total,
    eoi.actual_unit_price,
    eoi.unit_price_variance,
    eoi.is_skis,
    eoi.is_snowboards,
    eoi.quantity_tier,
    
    -- Calculated metrics
    COUNT(eoi.order_item_id) OVER (PARTITION BY eo.order_id) AS items_per_order,
    SUM(eoi.line_total) OVER (PARTITION BY eo.order_id) AS order_items_total
FROM automated_intelligence.dynamic_tables.enriched_orders eo
INNER JOIN automated_intelligence.dynamic_tables.enriched_order_items eoi
    ON eo.order_id = eoi.order_id;

-- ----------------------------------------------------------------------------
-- TIER 3: Aggregation Layer
-- Purpose: Pre-compute business metrics for instant query performance
-- Target Lag: DOWNSTREAM (waits for Tier 2 to complete)
-- Refresh Mode: INCREMENTAL
-- ----------------------------------------------------------------------------

-- Daily Business Metrics: Daily aggregations of key business metrics
CREATE OR REPLACE DYNAMIC TABLE daily_business_metrics
TARGET_LAG = DOWNSTREAM
WAREHOUSE = automated_intelligence_wh
SCHEDULER = ENABLE
REFRESH_MODE = INCREMENTAL
AS
SELECT
    order_date_only,
    order_year,
    order_quarter,
    order_month,
    order_week,
    order_day_name,
    
    -- Order metrics
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_id) AS unique_customers,
    AVG(items_per_order) AS avg_items_per_order,
    
    -- Revenue metrics
    SUM(total_amount) AS total_revenue,
    SUM(net_amount) AS total_net_revenue,
    SUM(discount_amount) AS total_discounts,
    SUM(shipping_cost) AS total_shipping,
    SUM(final_amount) AS total_final_revenue,
    AVG(final_amount) AS avg_order_value,
    
    -- Discount analysis
    COUNT(DISTINCT CASE WHEN has_discount THEN order_id END) AS orders_with_discount,
    ROUND(COUNT(DISTINCT CASE WHEN has_discount THEN order_id END)::DECIMAL / COUNT(DISTINCT order_id) * 100, 2) AS discount_penetration_pct,
    AVG(CASE WHEN has_discount THEN discount_percent END) AS avg_discount_percent,
    
    -- Order size distribution
    COUNT(DISTINCT CASE WHEN order_size_category = 'Small' THEN order_id END) AS small_orders,
    COUNT(DISTINCT CASE WHEN order_size_category = 'Medium' THEN order_id END) AS medium_orders,
    COUNT(DISTINCT CASE WHEN order_size_category = 'Large' THEN order_id END) AS large_orders,
    COUNT(DISTINCT CASE WHEN order_size_category = 'Extra Large' THEN order_id END) AS extra_large_orders
FROM automated_intelligence.dynamic_tables.fact_orders
GROUP BY 
    order_date_only,
    order_year,
    order_quarter,
    order_month,
    order_week,
    order_day_name;

-- Product Performance Metrics: Product category aggregations
CREATE OR REPLACE DYNAMIC TABLE product_performance_metrics
TARGET_LAG = DOWNSTREAM
WAREHOUSE = automated_intelligence_wh
SCHEDULER = ENABLE
REFRESH_MODE = INCREMENTAL
AS
SELECT
    product_category,
    
    -- Sales metrics
    COUNT(DISTINCT order_id) AS orders_count,
    COUNT(order_item_id) AS items_sold,
    SUM(quantity) AS total_quantity_sold,
    SUM(line_total) AS total_revenue,
    
    -- Averages
    AVG(unit_price) AS avg_unit_price,
    AVG(quantity) AS avg_quantity_per_order,
    AVG(line_total) AS avg_line_total,
    
    -- Price analysis
    MIN(unit_price) AS min_unit_price,
    MAX(unit_price) AS max_unit_price,
    
    -- Category flags
    SUM(CASE WHEN is_skis THEN 1 ELSE 0 END) AS ski_items,
    SUM(CASE WHEN is_snowboards THEN 1 ELSE 0 END) AS snowboard_items,
    
    -- Quantity distribution
    COUNT(CASE WHEN quantity_tier = 'Single' THEN 1 END) AS single_item_orders,
    COUNT(CASE WHEN quantity_tier = 'Few' THEN 1 END) AS few_item_orders,
    COUNT(CASE WHEN quantity_tier = 'Bulk' THEN 1 END) AS bulk_orders
FROM automated_intelligence.dynamic_tables.fact_orders
GROUP BY product_category;


-- ============================================================================
-- STEP 4.5: Interactive Tables (Act 2 - Serve & Analyze)
-- Purpose: Sub-100ms queries for high-concurrency serving (GA Dec 2025)
-- ============================================================================

USE SCHEMA automated_intelligence.interactive;

-- Create interactive tables (aggregated customer analytics)
CREATE OR REPLACE INTERACTIVE TABLE customer_order_analytics
  CLUSTER BY (customer_id)
AS
SELECT 
  c.customer_id,
  c.first_name,
  c.last_name,
  c.email,
  c.customer_segment,
  COUNT(DISTINCT o.order_id) as total_orders,
  SUM(o.total_amount) as total_spent,
  AVG(o.total_amount) as avg_order_value,
  MIN(o.order_date) as first_order_date,
  MAX(o.order_date) as last_order_date
FROM automated_intelligence.raw.customers c
INNER JOIN automated_intelligence.raw.orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.email, c.customer_segment;

CREATE OR REPLACE INTERACTIVE TABLE order_lookup
  CLUSTER BY (order_id)
AS
SELECT 
  o.order_id,
  o.customer_id,
  o.order_date,
  o.order_status,
  o.total_amount,
  c.first_name,
  c.last_name,
  c.email
FROM automated_intelligence.raw.orders o
INNER JOIN automated_intelligence.raw.customers c ON o.customer_id = c.customer_id;

-- Create interactive warehouse
CREATE OR REPLACE INTERACTIVE WAREHOUSE automated_intelligence_interactive_wh
  TABLES (customer_order_analytics, order_lookup)
  WAREHOUSE_SIZE = 'XSMALL';

ALTER WAREHOUSE automated_intelligence_interactive_wh RESUME;


-- ============================================================================
-- STEP 5: Data Quality Monitoring (Act 3 - Intelligence & Governance)
-- Purpose: DMFs for automated data quality checks and alerting
-- ============================================================================

-- Switch back to standard warehouse for DMF views (interactive warehouses can't query DMF results)
USE WAREHOUSE automated_intelligence_wh;
USE SCHEMA automated_intelligence.raw;

-- Set DMF schedule to trigger on data changes
ALTER TABLE orders SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';
ALTER TABLE order_items SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';

-- Add NULL_COUNT DMFs to orders table
ALTER TABLE orders ADD DATA METRIC FUNCTION 
  SNOWFLAKE.CORE.NULL_COUNT ON (order_id),
  SNOWFLAKE.CORE.NULL_COUNT ON (customer_id),
  SNOWFLAKE.CORE.NULL_COUNT ON (order_date),
  SNOWFLAKE.CORE.NULL_COUNT ON (total_amount);

-- Add NULL_COUNT DMFs to order_items table
ALTER TABLE order_items ADD DATA METRIC FUNCTION 
  SNOWFLAKE.CORE.NULL_COUNT ON (order_item_id),
  SNOWFLAKE.CORE.NULL_COUNT ON (order_id),
  SNOWFLAKE.CORE.NULL_COUNT ON (product_id),
  SNOWFLAKE.CORE.NULL_COUNT ON (quantity),
  SNOWFLAKE.CORE.NULL_COUNT ON (unit_price);

-- Create view for DMF results (wraps table functions)
-- Note: SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS view may not exist in all accounts
-- This custom view uses the table function approach which works universally
CREATE OR REPLACE VIEW vw_dq_monitoring_results AS
SELECT * FROM TABLE(
  SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS(
    REF_ENTITY_NAME => 'automated_intelligence.raw.orders',
    REF_ENTITY_DOMAIN => 'table'
  )
)
UNION ALL
SELECT * FROM TABLE(
  SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS(
    REF_ENTITY_NAME => 'automated_intelligence.raw.order_items',
    REF_ENTITY_DOMAIN => 'table'
  )
);

-- Create alert tracking table
CREATE TABLE IF NOT EXISTS data_quality_alerts (
  alert_time TIMESTAMP_NTZ,
  issue_summary VARCHAR,
  PRIMARY KEY (alert_time)
);

-- Create alert to monitor data quality issues
CREATE OR REPLACE ALERT data_quality_alert
  WAREHOUSE = automated_intelligence_wh
  SCHEDULE = '5 MINUTE'
  IF (EXISTS (
    SELECT 1
    FROM vw_dq_monitoring_results
    WHERE 
      table_database = 'AUTOMATED_INTELLIGENCE'
      AND table_schema = 'RAW'
      AND table_name IN ('ORDERS', 'ORDER_ITEMS')
      AND metric_name = 'NULL_COUNT'
      AND value::INT > 0
      AND measurement_time >= DATEADD('MINUTE', -10, CURRENT_TIMESTAMP())
  ))
  THEN
    INSERT INTO data_quality_alerts (alert_time, issue_summary)
    SELECT 
      CURRENT_TIMESTAMP(),
      'Data Quality Issue: NULL values detected - check vw_dq_monitoring_results for details';

-- Resume alert (start monitoring)
ALTER ALERT data_quality_alert RESUME;


-- ============================================================================
-- STEP 6: AI/ML Infrastructure (Act 3 - Intelligence & Governance)
-- Purpose: Tables for AI SQL functions, semantic search, and Cortex Agent
-- ============================================================================

USE SCHEMA automated_intelligence.raw;
USE WAREHOUSE automated_intelligence_wh;

-- Product catalog with descriptions for semantic search
CREATE TABLE IF NOT EXISTS product_catalog (
  product_id INT PRIMARY KEY,
  product_name VARCHAR(100),
  product_category VARCHAR(50),
  description TEXT,
  features TEXT,
  price DECIMAL(10,2),
  stock_quantity INT
);

-- Customer reviews for sentiment analysis and AI_AGG
CREATE TABLE IF NOT EXISTS product_reviews (
  review_id INT AUTOINCREMENT PRIMARY KEY,
  product_id INT,
  customer_id INT,
  review_date DATE,
  rating INT,
  review_title VARCHAR(200),
  review_text TEXT,
  verified_purchase BOOLEAN
);

-- Customer support tickets for AI_COMPLETE and classification
CREATE TABLE IF NOT EXISTS support_tickets (
  ticket_id INT AUTOINCREMENT PRIMARY KEY,
  customer_id INT,
  ticket_date TIMESTAMP_NTZ,
  category VARCHAR(50),
  priority VARCHAR(20),
  subject VARCHAR(200),
  description TEXT,
  resolution TEXT,
  status VARCHAR(20)
);

-- Insert sample product catalog data (use MERGE to prevent duplicates)
MERGE INTO product_catalog t
USING (
  SELECT * FROM (VALUES
  (1001, 'Powder Skis', 'Skis', 'Premium powder skis designed for deep snow conditions. Featuring a wide waist and rockered tip for effortless floating in backcountry powder.', 'Wide waist (115mm), Rockered tip and tail, Carbon fiber construction, Lightweight design', 799.99, 15),
  (1002, 'All-Mountain Skis', 'Skis', 'Versatile all-mountain skis perfect for any terrain. Handles groomed runs, powder, and moguls with equal confidence.', 'Medium waist (88mm), Progressive sidecut, Titanal reinforcement, Durable construction', 649.99, 25),
  (1003, 'Freestyle Snowboard', 'Snowboards', 'Twin-tip freestyle snowboard for park and pipe. Perfect for tricks, jumps, and jibbing with a soft, playful flex.', 'True twin shape, Soft flex rating, Sintered base, Pop-optimized core', 549.99, 20),
  (1004, 'Freeride Snowboard', 'Snowboards', 'Directional freeride snowboard for charging hard in variable conditions. Stiff and stable for high-speed descents.', 'Directional shape, Stiff flex, Carbon stringers, Powder-friendly nose', 699.99, 12),
  (1005, 'Ski Boots', 'Boots', 'High-performance alpine ski boots with customizable fit. Four-buckle design with walk mode for comfort and power transmission.', '130 flex rating, GripWalk soles, Heat-moldable liner, Walk mode', 449.99, 30),
  (1006, 'Snowboard Boots', 'Boots', 'Comfortable snowboard boots with Boa lacing system. Quick entry and perfect fit adjustment for all-day riding.', 'Boa lacing system, Medium flex, Heat-moldable liner, Vibram outsole', 349.99, 35),
  (1007, 'Ski Poles', 'Accessories', 'Lightweight aluminum ski poles with ergonomic grips. Adjustable length for different terrain and snow conditions.', 'Aluminum construction, Adjustable length (105-135cm), Powder baskets, Padded straps', 79.99, 50),
  (1008, 'Ski Goggles', 'Accessories', 'Anti-fog ski goggles with interchangeable lenses. Superior optics and peripheral vision for all weather conditions.', 'Anti-fog coating, UV protection, Interchangeable lenses, Helmet compatible', 149.99, 40),
  (1009, 'Snowboard Bindings', 'Accessories', 'Responsive snowboard bindings with tool-free adjustment. Lightweight and compatible with all mounting systems.', 'Tool-free adjustment, Canted footbeds, Universal disk, Highback rotation', 249.99, 28),
  (1010, 'Ski Helmet', 'Accessories', 'Safety-certified ski helmet with integrated audio system. Lightweight construction with adjustable ventilation.', 'MIPS protection, Audio-ready, Adjustable vents, Goggle clip, Multiple sizes', 179.99, 45)
  ) AS s(product_id, product_name, product_category, description, features, price, stock_quantity)
) s
ON t.product_id = s.product_id
WHEN MATCHED THEN
  UPDATE SET
    product_name = s.product_name,
    product_category = s.product_category,
    description = s.description,
    features = s.features,
    price = s.price,
    stock_quantity = s.stock_quantity
WHEN NOT MATCHED THEN
  INSERT (product_id, product_name, product_category, description, features, price, stock_quantity)
  VALUES (s.product_id, s.product_name, s.product_category, s.description, s.features, s.price, s.stock_quantity);

-- Product reviews and support tickets can be generated via Snowpipe Streaming
-- No static inserts needed here

-- ============================================================================
-- STEP 7: Cortex Search Service (Act 3 - Intelligence & Governance)
-- Purpose: Semantic search over product catalog for Snowflake Intelligence
-- ============================================================================

-- Enable change tracking on product catalog for Cortex Search
ALTER TABLE product_catalog SET CHANGE_TRACKING = TRUE;

-- Create Cortex Search Service for semantic search over product descriptions
CREATE OR REPLACE CORTEX SEARCH SERVICE product_search_service
  ON description
  ATTRIBUTES product_name, product_category, features, price
  WAREHOUSE = automated_intelligence_wh
  TARGET_LAG = '1 hour'
  AS (
    SELECT
      product_id,
      product_name,
      product_category,
      description,
      features,
      price,
      stock_quantity
    FROM product_catalog
  );

-- Verify Cortex Search Service
SHOW CORTEX SEARCH SERVICES IN SCHEMA automated_intelligence.raw;


-- ============================================================================
-- STEP 8: Semantic View (Act 3 - Intelligence & Governance)
-- Purpose: SQL-based semantic layer for Cortex Analyst natural language queries
-- ============================================================================

USE SCHEMA automated_intelligence.semantic;

-- Create Semantic View for business analytics
-- Note: Semantic Views use SQL syntax (not YAML) and enable natural language queries
-- Clause order MUST be: TABLES → RELATIONSHIPS → FACTS → DIMENSIONS → METRICS
CREATE OR REPLACE SEMANTIC VIEW business_analytics_semantic
TABLES (
    orders AS automated_intelligence.raw.orders
        PRIMARY KEY (order_id)
        WITH SYNONYMS = ('sales', 'transactions', 'purchases')
        COMMENT = 'Customer orders with amounts and status',
    
    customers AS automated_intelligence.raw.customers
        PRIMARY KEY (customer_id)
        WITH SYNONYMS = ('buyers', 'clients', 'users')
        COMMENT = 'Customer master data with segments',
    
    items AS automated_intelligence.raw.order_items
        PRIMARY KEY (order_item_id)
        WITH SYNONYMS = ('line_items', 'order_details', 'products_ordered')
        COMMENT = 'Individual items within each order'
)
RELATIONSHIPS (
    orders (customer_id) REFERENCES customers,
    items (order_id) REFERENCES orders
)
FACTS (
    orders.total_amount AS total_amount
        WITH SYNONYMS = ('order_value', 'sale_amount', 'revenue')
        COMMENT = 'Total monetary value of the order',
    
    items.quantity AS quantity
        WITH SYNONYMS = ('qty', 'units', 'count')
        COMMENT = 'Number of units ordered',
    
    items.unit_price AS unit_price
        WITH SYNONYMS = ('price', 'cost', 'item_price')
        COMMENT = 'Price per unit',
    
    items.line_total AS line_total
        WITH SYNONYMS = ('item_total', 'line_amount', 'item_revenue')
        COMMENT = 'Total value of the line item (quantity * unit_price)'
)
DIMENSIONS (
    orders.order_status AS order_status
        WITH SYNONYMS = ('status', 'state')
        COMMENT = 'Current status of the order',
    
    orders.order_date AS order_date
        WITH SYNONYMS = ('date', 'purchase_date', 'transaction_date')
        COMMENT = 'Date when order was placed',
    
    customers.customer_segment AS customer_segment
        WITH SYNONYMS = ('segment', 'tier', 'category')
        COMMENT = 'Customer classification tier',
    
    customers.first_name AS first_name
        COMMENT = 'Customer first name',
    
    customers.last_name AS last_name
        COMMENT = 'Customer last name',
    
    items.product_category AS product_category
        WITH SYNONYMS = ('category', 'product_type', 'item_category')
        COMMENT = 'Product category classification'
)
METRICS (
    orders.total_revenue AS SUM(total_amount)
        WITH SYNONYMS = ('revenue', 'sales', 'total_sales')
        COMMENT = 'Sum of all order amounts',
    
    orders.order_count AS COUNT(DISTINCT orders.order_id)
        WITH SYNONYMS = ('number_of_orders', 'total_orders')
        COMMENT = 'Count of unique orders',
    
    customers.customer_count AS COUNT(DISTINCT customers.customer_id)
        WITH SYNONYMS = ('number_of_customers', 'total_customers')
        COMMENT = 'Count of unique customers',
    
    orders.average_order_value AS AVG(total_amount)
        WITH SYNONYMS = ('aov', 'avg_order', 'mean_order_value')
        COMMENT = 'Average monetary value per order',
    
    items.total_items_revenue AS SUM(line_total)
        WITH SYNONYMS = ('item_revenue', 'product_revenue', 'line_item_sales')
        COMMENT = 'Sum of all line item totals'
)
COMMENT = 'Semantic layer for natural language business analytics queries';

-- Verify Semantic View creation
SHOW SEMANTIC VIEWS IN SCHEMA automated_intelligence.semantic;
DESCRIBE SEMANTIC VIEW business_analytics_semantic;


-- ============================================================================
-- STEP 9: SQL Features Reference (Standalone Demo Scripts)
-- Purpose: Reference to advanced SQL feature demonstrations
-- ============================================================================
-- The following SQL features have dedicated demo scripts in the repository.
-- These demonstrate cutting-edge Snowflake capabilities with working examples.
--
-- AI SQL Functions:
--   - sql-features/ai-sql-demo/ai_filter_demo.sql (AI_FILTER, AI_CLASSIFY)
--
-- New SQL Syntax (2024-2025):
--   - sql-features/pipe_operator_demo.sql (Pipe operator ->> with $1)
--   - sql-features/union_by_name_demo.sql (UNION BY NAME for schema evolution)
--   - sql-features/time_series_gap_fill_demo.sql (RESAMPLE clause)
--   - sql-features/async_sql_demo.sql (ASYNC procedures)
--   - sql-features/create_or_alter_demo.sql (CREATE OR ALTER DDL)
--
-- Semantic Views:
--   - snowflake-intelligence/semantic_view_sql_demo.sql (Full SQL syntax demo)
--
-- Infrastructure Features:
--   - sql-features/gen2-warehouse/gen2_optima_demo.sql (Gen2 + Optima Indexing)
--   - sql-features/data-quality/dmf_expectations_demo.sql (Data Metric Functions)
--   - iceberg/partitioned_writes_demo.sql (Iceberg tables + v3 preview)
--
-- ML & AI:
--   - sql-features/ml-models/huggingface_import_demo.sql (HuggingFace models)
--   - snowflake-intelligence/cortex_analyst_routing_demo.sql (Multi-agent routing)
--
-- See DEMO_SCRIPT.md "SQL FEATURES & REFERENCE DEMOS" section for full details.
-- ============================================================================


-- ============================================================================
-- Setup Complete! Infrastructure ready for Ingestion to Intelligence.
-- 
-- Next Steps:
--   1. Run Snowpipe Streaming to ingest data (Act 1)
--   2. Follow DEMO_SCRIPT.md for the full journey
--   3. See component READMEs for detailed instructions
--   4. Explore SQL Features demos in sql-features/ directory
--
-- Demo Flow:
--   Act 1: Ingest & Stage      → Demos 1-2 (Streaming, Gen2, Dynamic Tables)
--   Act 2: Serve & Analyze     → Demos 3-4 (Interactive Tables, dbt, ML)
--   Act 3: Intelligence        → Demos 5-6 (Snowflake Intelligence, RBAC)
--   Bonus: Open Lakehouse      → Demos 7-8 (Postgres, Iceberg)
--   SQL Features Reference     → 13 standalone demos (AI SQL, Pipe Operator, etc.)
-- ============================================================================

TRUNCATE TABLE IF EXISTS automated_intelligence.raw.customers;
TRUNCATE TABLE IF EXISTS automated_intelligence.raw.orders;
TRUNCATE TABLE IF EXISTS automated_intelligence.raw.order_items;
TRUNCATE TABLE IF EXISTS automated_intelligence.raw.data_quality_alerts;

ALTER DYNAMIC TABLE automated_intelligence.dynamic_tables.enriched_orders REFRESH;
ALTER DYNAMIC TABLE automated_intelligence.dynamic_tables.enriched_order_items REFRESH;
ALTER DYNAMIC TABLE automated_intelligence.dynamic_tables.fact_orders REFRESH;
ALTER DYNAMIC TABLE automated_intelligence.dynamic_tables.daily_business_metrics REFRESH;
ALTER DYNAMIC TABLE automated_intelligence.dynamic_tables.product_performance_metrics REFRESH;

SELECT 'Raw Tables' AS category, 'customers' AS table_name, COUNT(*) AS row_count 
FROM automated_intelligence.raw.customers
UNION ALL
SELECT 'Raw Tables', 'orders', COUNT(*) 
FROM automated_intelligence.raw.orders
UNION ALL
SELECT 'Raw Tables', 'order_items', COUNT(*) 
FROM automated_intelligence.raw.order_items
UNION ALL
SELECT 'Raw Tables', 'data_quality_alerts', COUNT(*) 
FROM automated_intelligence.raw.data_quality_alerts
UNION ALL
SELECT 'Dynamic Tables', 'enriched_orders', COUNT(*) 
FROM automated_intelligence.dynamic_tables.enriched_orders
UNION ALL
SELECT 'Dynamic Tables', 'enriched_order_items', COUNT(*) 
FROM automated_intelligence.dynamic_tables.enriched_order_items
UNION ALL
SELECT 'Dynamic Tables', 'fact_orders', COUNT(*) 
FROM automated_intelligence.dynamic_tables.fact_orders
UNION ALL
SELECT 'Dynamic Tables', 'daily_business_metrics', COUNT(*) 
FROM automated_intelligence.dynamic_tables.daily_business_metrics
UNION ALL
SELECT 'Dynamic Tables', 'product_performance_metrics', COUNT(*) 
FROM automated_intelligence.dynamic_tables.product_performance_metrics
ORDER BY category, table_name;

-- ============================================================================
-- Create Stages
-- ============================================================================

-- Stage for Semantic Model Storage
-- This stage stores semantic model YAML files used by Cortex Analyst
-- for natural language to SQL translation.
CREATE STAGE IF NOT EXISTS automated_intelligence.raw.semantic_models
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for storing semantic model YAML files for Cortex Analyst';

-- Stage for Streamlit Dashboard
-- This stage stores Streamlit application files for THE_DASHBOARD
CREATE STAGE IF NOT EXISTS automated_intelligence.raw.the_dashboard_stage
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for Streamlit dashboard application files';

SHOW STAGES IN automated_intelligence.raw;

-- ============================================================================
-- Generate Initial Data
-- ============================================================================
-- Create customers for the system
-- Orders will be generated via Snowpipe Streaming (see optional setup below)
SET NUM_CUSTOMERS = 500000;

CALL automated_intelligence.raw.generate_customers($NUM_CUSTOMERS);

-- Note: Use Snowpipe Streaming to generate orders (see snowpipe-streaming-java or snowpipe-streaming-python)

-- ============================================================================
-- OPTIONAL SETUP SCRIPTS (Per-Act Configuration)
-- ============================================================================
-- Run these scripts based on which Acts you're demonstrating:
--
-- ACT 1: INGEST & STAGE
--   - snowpipe-streaming-java/setup_pipes.sql (Java SDK)
--   - snowpipe-streaming-python/recreate_pipes.sql (Python SDK)
--
-- ACT 2: SERVE & ANALYZE
--   - dbt-analytics/dbt_project.yml (dbt models)
--   - ml-training/ notebooks (GPU training)
--
-- ACT 3: INTELLIGENCE & GOVERNANCE
--   - security-and-governance/setup_west_coast_manager.sql (Row Access Policies)
--   - snowflake-intelligence/ (Cortex Agent configuration)
--
-- BONUS: OPEN LAKEHOUSE
--   - pg_lake/snowflake_export.sql (Iceberg export to S3)
--   - snowflake-postgres/ (Managed Postgres setup)
--   Requires: External volume 'aws_s3_ext_volume_snowflake' configured
--
-- See DEMO_SCRIPT.md for the complete Ingestion to Intelligence journey.
-- ============================================================================
