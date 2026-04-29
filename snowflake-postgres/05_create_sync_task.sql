-- ============================================================================
-- Snowflake: Create Postgres Sync Procedure and Task
-- ============================================================================
-- Run this in Snowflake after setting up external access and query functions
-- 
-- Creates:
-- - SYNC_POSTGRES_TO_SNOWFLAKE() - Procedure that MERGEs data from Postgres
-- - POSTGRES_SYNC_TASK - Scheduled task that runs every 5 minutes
-- ============================================================================

-- ============================================================================
-- Context: Database, Schema, Role
-- ============================================================================
USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
USE DATABASE AUTOMATED_INTELLIGENCE;
USE WAREHOUSE AUTOMATED_INTELLIGENCE_WH;
USE SCHEMA POSTGRES;

-- ============================================================================
-- Stored Procedure: SYNC_POSTGRES_TO_SNOWFLAKE
-- MERGEs product_reviews and support_tickets from Postgres to Snowflake
-- Handles INSERT, UPDATE, and DELETE operations
-- ============================================================================
CREATE OR REPLACE PROCEDURE sync_postgres_to_snowflake()
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    reviews_merged INT DEFAULT 0;
    reviews_deleted INT DEFAULT 0;
    tickets_merged INT DEFAULT 0;
    tickets_deleted INT DEFAULT 0;
BEGIN
    -- =========================================
    -- SYNC PRODUCT_REVIEWS
    -- =========================================
    
    -- MERGE: Insert new rows, update existing rows
    MERGE INTO RAW.PRODUCT_REVIEWS target
    USING (
        SELECT 
            result:review_id::INT AS review_id,
            result:product_id::INT AS product_id,
            result:customer_id::INT AS customer_id,
            result:review_date::DATE AS review_date,
            result:rating::INT AS rating,
            result:review_title::STRING AS review_title,
            result:review_text::STRING AS review_text,
            result:verified_purchase::BOOLEAN AS verified_purchase
        FROM TABLE(POSTGRES.pg_query('SELECT * FROM product_reviews'))
    ) source
    ON target.review_id = source.review_id
    WHEN MATCHED THEN UPDATE SET
        product_id = source.product_id,
        customer_id = source.customer_id,
        review_date = source.review_date,
        rating = source.rating,
        review_title = source.review_title,
        review_text = source.review_text,
        verified_purchase = source.verified_purchase
    WHEN NOT MATCHED THEN INSERT (
        review_id, product_id, customer_id, review_date, rating, review_title, review_text, verified_purchase
    ) VALUES (
        source.review_id, source.product_id, source.customer_id, source.review_date, 
        source.rating, source.review_title, source.review_text, source.verified_purchase
    );
    
    reviews_merged := SQLROWCOUNT;
    
    -- DELETE: Remove rows that no longer exist in Postgres
    DELETE FROM RAW.PRODUCT_REVIEWS 
    WHERE review_id NOT IN (
        SELECT result:review_id::INT FROM TABLE(POSTGRES.pg_query('SELECT review_id FROM product_reviews'))
    );
    
    reviews_deleted := SQLROWCOUNT;

    -- =========================================
    -- SYNC SUPPORT_TICKETS
    -- =========================================
    
    -- MERGE: Insert new rows, update existing rows
    MERGE INTO RAW.SUPPORT_TICKETS target
    USING (
        SELECT 
            result:ticket_id::INT AS ticket_id,
            result:customer_id::INT AS customer_id,
            result:ticket_date::TIMESTAMP AS ticket_date,
            result:category::STRING AS category,
            result:priority::STRING AS priority,
            result:subject::STRING AS subject,
            result:description::STRING AS description,
            result:resolution::STRING AS resolution,
            result:status::STRING AS status
        FROM TABLE(POSTGRES.pg_query('SELECT * FROM support_tickets'))
    ) source
    ON target.ticket_id = source.ticket_id
    WHEN MATCHED THEN UPDATE SET
        customer_id = source.customer_id,
        ticket_date = source.ticket_date,
        category = source.category,
        priority = source.priority,
        subject = source.subject,
        description = source.description,
        resolution = source.resolution,
        status = source.status
    WHEN NOT MATCHED THEN INSERT (
        ticket_id, customer_id, ticket_date, category, priority, subject, description, resolution, status
    ) VALUES (
        source.ticket_id, source.customer_id, source.ticket_date, source.category,
        source.priority, source.subject, source.description, source.resolution, source.status
    );
    
    tickets_merged := SQLROWCOUNT;
    
    -- DELETE: Remove rows that no longer exist in Postgres
    DELETE FROM RAW.SUPPORT_TICKETS 
    WHERE ticket_id NOT IN (
        SELECT result:ticket_id::INT FROM TABLE(POSTGRES.pg_query('SELECT ticket_id FROM support_tickets'))
    );
    
    tickets_deleted := SQLROWCOUNT;

    RETURN OBJECT_CONSTRUCT(
        'reviews_merged', reviews_merged,
        'reviews_deleted', reviews_deleted,
        'tickets_merged', tickets_merged,
        'tickets_deleted', tickets_deleted,
        'synced_at', CURRENT_TIMESTAMP()
    );
END;
$$;

-- ============================================================================
-- Task: POSTGRES_SYNC_TASK
-- Runs every 5 minutes to keep Snowflake in sync with Postgres
-- ============================================================================
CREATE OR REPLACE TASK postgres_sync_task
    WAREHOUSE = AUTOMATED_INTELLIGENCE_WH
    SCHEDULE = '5 MINUTE'
    COMMENT = 'Syncs product_reviews and support_tickets from Postgres to Snowflake'
AS
    CALL sync_postgres_to_snowflake();

-- Enable the task (tasks are created in suspended state by default)
ALTER TASK postgres_sync_task RESUME;

-- ============================================================================
-- Verify
-- ============================================================================
SHOW TASKS LIKE 'postgres_sync%';

-- Manual test
-- CALL sync_postgres_to_snowflake();

-- Check task history
-- SELECT * FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY()) 
-- WHERE NAME = 'POSTGRES_SYNC_TASK' ORDER BY SCHEDULED_TIME DESC LIMIT 10;
