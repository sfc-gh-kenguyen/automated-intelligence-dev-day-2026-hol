-- ============================================================
-- Snowflake: Create Iceberg Tables for pg_lake
-- These tables export data to S3 in Iceberg format
-- ============================================================

USE DATABASE AUTOMATED_INTELLIGENCE;
USE WAREHOUSE AUTOMATED_INTELLIGENCE_WH;

-- Create schema for pg_lake Iceberg tables
CREATE SCHEMA IF NOT EXISTS PG_LAKE
  COMMENT = 'Iceberg tables for pg_lake demo - external Postgres access via S3';

USE SCHEMA PG_LAKE;

-- ------------------------------------------------------------
-- 1. Create Iceberg Tables from RAW data
-- ------------------------------------------------------------

-- Product Reviews Iceberg Table
CREATE OR REPLACE ICEBERG TABLE PRODUCT_REVIEWS
  CATALOG = 'SNOWFLAKE'
  EXTERNAL_VOLUME = 'aws_s3_ext_volume_snowflake'
  BASE_LOCATION = 'demos/pg_lake/product_reviews'
AS SELECT * FROM AUTOMATED_INTELLIGENCE.RAW.PRODUCT_REVIEWS;

-- Support Tickets Iceberg Table (with timestamp precision fix for Iceberg)
CREATE OR REPLACE ICEBERG TABLE SUPPORT_TICKETS
  CATALOG = 'SNOWFLAKE'
  EXTERNAL_VOLUME = 'aws_s3_ext_volume_snowflake'
  BASE_LOCATION = 'demos/pg_lake/support_tickets'
AS SELECT 
    TICKET_ID,
    CUSTOMER_ID,
    TICKET_DATE::TIMESTAMP_NTZ(6) AS TICKET_DATE,
    CATEGORY,
    PRIORITY,
    SUBJECT,
    DESCRIPTION,
    RESOLUTION,
    STATUS
FROM AUTOMATED_INTELLIGENCE.RAW.SUPPORT_TICKETS;

-- ------------------------------------------------------------
-- 2. Verify Tables
-- ------------------------------------------------------------

SELECT 'PRODUCT_REVIEWS' as table_name, COUNT(*) as row_count FROM PRODUCT_REVIEWS
UNION ALL
SELECT 'SUPPORT_TICKETS', COUNT(*) FROM SUPPORT_TICKETS;

-- ------------------------------------------------------------
-- 3. Get Iceberg Metadata Locations (for pg_lake foreign tables)
-- ------------------------------------------------------------

SELECT 
    'PRODUCT_REVIEWS' as table_name,
    PARSE_JSON(SYSTEM$GET_ICEBERG_TABLE_INFORMATION('AUTOMATED_INTELLIGENCE.PG_LAKE.PRODUCT_REVIEWS')):metadataLocation::STRING as metadata_location
UNION ALL
SELECT 
    'SUPPORT_TICKETS',
    PARSE_JSON(SYSTEM$GET_ICEBERG_TABLE_INFORMATION('AUTOMATED_INTELLIGENCE.PG_LAKE.SUPPORT_TICKETS')):metadataLocation::STRING;

-- ------------------------------------------------------------
-- 4. Create Task for Incremental Refresh (every 5 minutes)
-- ------------------------------------------------------------

CREATE OR REPLACE TASK PG_LAKE_REFRESH_TASK
  WAREHOUSE = AUTOMATED_INTELLIGENCE_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Incrementally refresh Iceberg tables for pg_lake every 5 minutes'
AS
BEGIN
  -- Merge product reviews (upsert based on review_id)
  MERGE INTO PG_LAKE.PRODUCT_REVIEWS tgt
  USING RAW.PRODUCT_REVIEWS src
  ON tgt.REVIEW_ID = src.REVIEW_ID
  WHEN MATCHED AND (
    tgt.RATING != src.RATING OR
    tgt.REVIEW_TITLE != src.REVIEW_TITLE OR
    tgt.REVIEW_TEXT != src.REVIEW_TEXT
  ) THEN UPDATE SET
    tgt.CUSTOMER_ID = src.CUSTOMER_ID,
    tgt.PRODUCT_ID = src.PRODUCT_ID,
    tgt.REVIEW_DATE = src.REVIEW_DATE,
    tgt.RATING = src.RATING,
    tgt.REVIEW_TITLE = src.REVIEW_TITLE,
    tgt.REVIEW_TEXT = src.REVIEW_TEXT
  WHEN NOT MATCHED THEN INSERT (
    REVIEW_ID, CUSTOMER_ID, PRODUCT_ID, REVIEW_DATE, RATING, REVIEW_TITLE, REVIEW_TEXT
  ) VALUES (
    src.REVIEW_ID, src.CUSTOMER_ID, src.PRODUCT_ID, src.REVIEW_DATE, src.RATING, src.REVIEW_TITLE, src.REVIEW_TEXT
  );

  -- Merge support tickets (upsert based on ticket_id)
  MERGE INTO PG_LAKE.SUPPORT_TICKETS tgt
  USING (
    SELECT 
      TICKET_ID, CUSTOMER_ID, TICKET_DATE::TIMESTAMP_NTZ(6) AS TICKET_DATE,
      CATEGORY, PRIORITY, SUBJECT, DESCRIPTION, RESOLUTION, STATUS
    FROM RAW.SUPPORT_TICKETS
  ) src
  ON tgt.TICKET_ID = src.TICKET_ID
  WHEN MATCHED AND (
    tgt.STATUS != src.STATUS OR
    tgt.RESOLUTION != src.RESOLUTION OR
    tgt.PRIORITY != src.PRIORITY
  ) THEN UPDATE SET
    tgt.CUSTOMER_ID = src.CUSTOMER_ID,
    tgt.TICKET_DATE = src.TICKET_DATE,
    tgt.CATEGORY = src.CATEGORY,
    tgt.PRIORITY = src.PRIORITY,
    tgt.SUBJECT = src.SUBJECT,
    tgt.DESCRIPTION = src.DESCRIPTION,
    tgt.RESOLUTION = src.RESOLUTION,
    tgt.STATUS = src.STATUS
  WHEN NOT MATCHED THEN INSERT (
    TICKET_ID, CUSTOMER_ID, TICKET_DATE, CATEGORY, PRIORITY, SUBJECT, DESCRIPTION, RESOLUTION, STATUS
  ) VALUES (
    src.TICKET_ID, src.CUSTOMER_ID, src.TICKET_DATE, src.CATEGORY, src.PRIORITY, src.SUBJECT, src.DESCRIPTION, src.RESOLUTION, src.STATUS
  );
END;

-- Start the task (run once to enable)
ALTER TASK PG_LAKE_REFRESH_TASK RESUME;

-- ------------------------------------------------------------
-- 5. Task Management Commands
-- ------------------------------------------------------------

-- Check task status:
-- SHOW TASKS LIKE 'PG_LAKE_REFRESH_TASK' IN SCHEMA PG_LAKE;

-- View task history:
-- SELECT * FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(TASK_NAME => 'PG_LAKE_REFRESH_TASK')) ORDER BY SCHEDULED_TIME DESC LIMIT 10;

-- Manually run the task:
-- EXECUTE TASK PG_LAKE_REFRESH_TASK;

-- Pause the task:
-- ALTER TASK PG_LAKE_REFRESH_TASK SUSPEND;

-- Resume the task:
-- ALTER TASK PG_LAKE_REFRESH_TASK RESUME;
