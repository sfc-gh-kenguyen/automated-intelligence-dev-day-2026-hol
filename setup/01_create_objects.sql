-- ============================================================================
-- CORTEX CODE DEMO — Object Creation Script
-- 
-- Creates all Snowflake objects required to run the 7 demo prompts.
-- Idempotent: uses CREATE OR REPLACE / CREATE IF NOT EXISTS throughout.
--
-- Run as ACCOUNTADMIN first (Step 0), then as COCO_DEMO_ROLE (Step 1+).
--
-- Generated: 2026-04-02
-- ============================================================================


-- ============================================================================
-- STEP 0: ROLE & GRANTS (Run as ACCOUNTADMIN)
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- Create the demo role
CREATE ROLE IF NOT EXISTS COCO_DEMO_ROLE
  COMMENT = 'Role for running Cortex Code demo prompts — database, warehouse, AI agents, Snowflake Intelligence';

-- Grant account-level privileges
GRANT CREATE DATABASE ON ACCOUNT TO ROLE COCO_DEMO_ROLE;
GRANT CREATE WAREHOUSE ON ACCOUNT TO ROLE COCO_DEMO_ROLE;

-- Snowflake Intelligence: allows creating agents, semantic views, MCP servers
-- If this fails on your account, prompts 1-5 still work. Prompts 6-7 will
-- skip the SI registration step (agent/SV/search creation still succeeds).
GRANT CREATE SNOWFLAKE INTELLIGENCE ON ACCOUNT TO ROLE COCO_DEMO_ROLE;

-- Grant the role to current user
GRANT ROLE COCO_DEMO_ROLE TO USER CURRENT_USER();

-- Cortex AI functions require SNOWFLAKE.CORTEX_USER database role
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE COCO_DEMO_ROLE;


-- ============================================================================
-- STEP 1: INFRASTRUCTURE (Run as COCO_DEMO_ROLE)
-- ============================================================================

USE ROLE COCO_DEMO_ROLE;

-- Database
CREATE DATABASE IF NOT EXISTS AUTOMATED_INTELLIGENCE;
USE DATABASE AUTOMATED_INTELLIGENCE;

-- Schemas (only what the demo prompts need)
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS SEMANTIC;
CREATE SCHEMA IF NOT EXISTS DBT_ANALYTICS
  COMMENT = 'Schema for dbt analytical models';

-- Warehouse
CREATE WAREHOUSE IF NOT EXISTS AUTOMATED_INTELLIGENCE_WH
  WITH WAREHOUSE_SIZE = 'SMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Warehouse for Cortex Code demo';

USE WAREHOUSE AUTOMATED_INTELLIGENCE_WH;


-- ============================================================================
-- STEP 2: RAW TABLES
-- ============================================================================

USE SCHEMA RAW;

-- Prompt 1 (revenue trends), Prompt 3 (CLV dashboard), Prompt 6 (semantic view)
CREATE OR REPLACE TABLE CUSTOMERS (
    CUSTOMER_ID        INT PRIMARY KEY,
    FIRST_NAME         VARCHAR(50),
    LAST_NAME          VARCHAR(50),
    EMAIL              VARCHAR(100),
    PHONE              VARCHAR(20),
    ADDRESS            VARCHAR(200),
    CITY               VARCHAR(50),
    STATE              VARCHAR(2),
    ZIP_CODE           VARCHAR(10),
    REGISTRATION_DATE  DATE,
    CUSTOMER_SEGMENT   VARCHAR(20)
);

-- Prompt 1 (revenue trends), Prompt 6 (semantic view)
CREATE OR REPLACE TABLE ORDERS (
    ORDER_ID           VARCHAR(36) PRIMARY KEY,
    CUSTOMER_ID        INT,
    ORDER_DATE         TIMESTAMP,
    ORDER_STATUS       VARCHAR(20),
    TOTAL_AMOUNT       DECIMAL(10, 2),
    DISCOUNT_PERCENT   DECIMAL(5, 2),
    SHIPPING_COST      DECIMAL(8, 2)
);

-- Prompt 6 (semantic view)
CREATE OR REPLACE TABLE ORDER_ITEMS (
    ORDER_ITEM_ID      VARCHAR(36) PRIMARY KEY,
    ORDER_ID           VARCHAR(36),
    PRODUCT_ID         INT,
    PRODUCT_NAME       VARCHAR(100),
    PRODUCT_CATEGORY   VARCHAR(50),
    QUANTITY           INT,
    UNIT_PRICE         DECIMAL(10, 2),
    LINE_TOTAL         DECIMAL(12, 2)
);

-- Prompt 6 (search service reference data)
CREATE OR REPLACE TABLE PRODUCT_CATALOG (
    PRODUCT_ID         INT PRIMARY KEY,
    PRODUCT_NAME       VARCHAR(100),
    PRODUCT_CATEGORY   VARCHAR(50),
    DESCRIPTION        TEXT,
    FEATURES           TEXT,
    PRICE              DECIMAL(10, 2),
    STOCK_QUANTITY     INT
);

-- Prompt 2 (AI_FILTER/AI_CLASSIFY), Prompt 6 (search service)
CREATE OR REPLACE TABLE PRODUCT_REVIEWS (
    REVIEW_ID          INT PRIMARY KEY,
    PRODUCT_ID         INT,
    CUSTOMER_ID        INT,
    REVIEW_DATE        DATE,
    RATING             INT,
    REVIEW_TITLE       VARCHAR(200),
    REVIEW_TEXT        TEXT,
    VERIFIED_PURCHASE  BOOLEAN
);

-- Enable change tracking for Cortex Search (prompt 6)
ALTER TABLE PRODUCT_REVIEWS SET CHANGE_TRACKING = TRUE;

-- Stage for data loading
CREATE STAGE IF NOT EXISTS DATA_LOAD_STAGE
    COMMENT = 'Stage for loading demo CSV data';


-- ============================================================================
-- STEP 3: PRODUCT CATALOG DATA (static — always the same 10 products)
-- ============================================================================

MERGE INTO PRODUCT_CATALOG t
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
  ) AS s(PRODUCT_ID, PRODUCT_NAME, PRODUCT_CATEGORY, DESCRIPTION, FEATURES, PRICE, STOCK_QUANTITY)
) s
ON t.PRODUCT_ID = s.PRODUCT_ID
WHEN MATCHED THEN
  UPDATE SET
    PRODUCT_NAME = s.PRODUCT_NAME, PRODUCT_CATEGORY = s.PRODUCT_CATEGORY,
    DESCRIPTION = s.DESCRIPTION, FEATURES = s.FEATURES,
    PRICE = s.PRICE, STOCK_QUANTITY = s.STOCK_QUANTITY
WHEN NOT MATCHED THEN
  INSERT (PRODUCT_ID, PRODUCT_NAME, PRODUCT_CATEGORY, DESCRIPTION, FEATURES, PRICE, STOCK_QUANTITY)
  VALUES (s.PRODUCT_ID, s.PRODUCT_NAME, s.PRODUCT_CATEGORY, s.DESCRIPTION, s.FEATURES, s.PRICE, s.STOCK_QUANTITY);


-- ============================================================================
-- STEP 4: VERIFY SETUP
-- ============================================================================

SELECT 'Tables' AS OBJECT_TYPE, TABLE_SCHEMA, TABLE_NAME, ROW_COUNT
FROM AUTOMATED_INTELLIGENCE.INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_SCHEMA, TABLE_NAME;

SELECT '01_create_objects.sql completed successfully' AS STATUS;
