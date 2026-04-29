-- ============================================================================
-- CORTEX CODE DEMO — Data Load Script
--
-- Loads exported demo data from CSV files into the tables created by
-- 01_create_objects.sql. Uses internal stage + COPY INTO.
--
-- Prerequisites:
--   1. Run 01_create_objects.sql first
--   2. Run 02_export_data.py to generate CSVs in setup/data/
--   3. Upload CSVs to @RAW.DATA_LOAD_STAGE (see Step 1 below)
--
-- Generated: 2026-04-02
-- ============================================================================

USE ROLE COCO_DEMO_ROLE;
USE DATABASE AUTOMATED_INTELLIGENCE;
USE WAREHOUSE AUTOMATED_INTELLIGENCE_WH;


-- ============================================================================
-- STEP 1: UPLOAD CSV FILES TO STAGE
-- ============================================================================
-- Run these PUT commands from SnowSQL (PUT is a client-side command).
--
-- From the repo root directory:
--
--   PUT file://setup/data/customers.csv @RAW.DATA_LOAD_STAGE/customers/ AUTO_COMPRESS=TRUE OVERWRITE=TRUE;
--   PUT file://setup/data/orders.csv @RAW.DATA_LOAD_STAGE/orders/ AUTO_COMPRESS=TRUE OVERWRITE=TRUE;
--   PUT file://setup/data/order_items.csv @RAW.DATA_LOAD_STAGE/order_items/ AUTO_COMPRESS=TRUE OVERWRITE=TRUE;
--   PUT file://setup/data/product_reviews.csv @RAW.DATA_LOAD_STAGE/product_reviews/ AUTO_COMPRESS=TRUE OVERWRITE=TRUE;
--   PUT file://setup/data/customer_lifetime_value.csv @RAW.DATA_LOAD_STAGE/clv/ AUTO_COMPRESS=TRUE OVERWRITE=TRUE;


-- ============================================================================
-- STEP 2: FILE FORMAT
-- ============================================================================

CREATE OR REPLACE FILE FORMAT RAW.DEMO_CSV_FORMAT
  TYPE = 'CSV'
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  SKIP_HEADER = 1
  NULL_IF = ('', 'NULL', 'None')
  EMPTY_FIELD_AS_NULL = TRUE
  FIELD_DELIMITER = ','
  ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE;


-- ============================================================================
-- STEP 3: LOAD RAW TABLES
-- ============================================================================

-- Customers (5,000 rows) — used by P1, P3, P6
COPY INTO RAW.CUSTOMERS
  FROM @RAW.DATA_LOAD_STAGE/customers/
  FILE_FORMAT = RAW.DEMO_CSV_FORMAT
  PURGE = FALSE
  ON_ERROR = 'CONTINUE';

-- Orders (91K rows) — used by P1, P6
COPY INTO RAW.ORDERS
  FROM @RAW.DATA_LOAD_STAGE/orders/
  FILE_FORMAT = RAW.DEMO_CSV_FORMAT
  PURGE = FALSE
  ON_ERROR = 'CONTINUE';

-- Order Items (456K rows) — used by P6
COPY INTO RAW.ORDER_ITEMS
  FROM @RAW.DATA_LOAD_STAGE/order_items/
  FILE_FORMAT = RAW.DEMO_CSV_FORMAT
  PURGE = FALSE
  ON_ERROR = 'CONTINUE';

-- Product Reviews (395 rows) — used by P2, P6
COPY INTO RAW.PRODUCT_REVIEWS
  FROM @RAW.DATA_LOAD_STAGE/product_reviews/
  FILE_FORMAT = RAW.DEMO_CSV_FORMAT
  PURGE = FALSE
  ON_ERROR = 'CONTINUE';


-- ============================================================================
-- STEP 4: LOAD DBT_ANALYTICS TABLE (pre-computed)
-- ============================================================================
-- CLV table is a dbt-derived table. Loading it directly avoids requiring
-- the user to install and run dbt.

CREATE TABLE IF NOT EXISTS DBT_ANALYTICS.CUSTOMER_LIFETIME_VALUE (
    CUSTOMER_ID              NUMBER(38,0),
    CUSTOMER_NAME            VARCHAR,
    CUSTOMER_SEGMENT         VARCHAR,
    SIGNUP_DATE              DATE,
    DAYS_SINCE_SIGNUP        NUMBER(38,0),
    TOTAL_ORDERS             NUMBER(38,0),
    TOTAL_REVENUE            NUMBER(38,2),
    AVG_ORDER_VALUE          NUMBER(38,2),
    TOTAL_ITEMS_PURCHASED    NUMBER(38,0),
    FIRST_ORDER_DATE         DATE,
    LAST_ORDER_DATE          DATE,
    CUSTOMER_LIFESPAN_DAYS   NUMBER(38,0),
    DAYS_SINCE_LAST_ORDER    NUMBER(38,0),
    ESTIMATED_ANNUAL_VALUE   NUMBER(38,2),
    HISTORICAL_ANNUAL_VALUE  NUMBER(38,2),
    ORDERS_PER_MONTH         NUMBER(38,6),
    RECENCY_SCORE            NUMBER(38,0),
    FREQUENCY_SCORE          NUMBER(38,0),
    MONETARY_SCORE           NUMBER(38,0),
    RFM_SCORE                NUMBER(38,0),
    VALUE_TIER               VARCHAR,
    CUSTOMER_STATUS          VARCHAR
);

-- CLV (5,000 rows) — used by P3 (Streamlit dashboard)
COPY INTO DBT_ANALYTICS.CUSTOMER_LIFETIME_VALUE
  FROM @RAW.DATA_LOAD_STAGE/clv/
  FILE_FORMAT = RAW.DEMO_CSV_FORMAT
  PURGE = FALSE
  ON_ERROR = 'CONTINUE';


-- ============================================================================
-- STEP 5: VERIFY DATA
-- ============================================================================

SELECT TABLE_SCHEMA || '.' || TABLE_NAME AS TABLE_NAME, ROW_COUNT
FROM AUTOMATED_INTELLIGENCE.INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_SCHEMA, TABLE_NAME;

-- Expected row counts:
-- DBT_ANALYTICS.CUSTOMER_LIFETIME_VALUE:  ~5,000
-- RAW.CUSTOMERS:                          ~5,000
-- RAW.ORDER_ITEMS:                        ~456,000
-- RAW.ORDERS:                             ~91,000
-- RAW.PRODUCT_CATALOG:                    10
-- RAW.PRODUCT_REVIEWS:                    395

SELECT '03_load_data.sql completed successfully' AS STATUS;
