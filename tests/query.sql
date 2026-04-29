USE DATABASE AUTOMATED_INTELLIGENCE;

-- ==========================================================
-- Snowflake Native
-- ==========================================================

-- RAW
USE SCHEMA RAW;
SELECT COUNT(*) FROM RAW.CUSTOMERS;
SELECT * FROM RAW.CUSTOMERS LIMIT 10;

SELECT COUNT(*) FROM RAW.ORDERS;
SELECT * FROM RAW.ORDERS LIMIT 10;

-- DBT
USE SCHEMA DBT_ANALYTICS;
SELECT * FROM DBT_ANALYTICS.CUSTOMER_LIFETIME_VALUE LIMIT 10;
SELECT * FROM DBT_ANALYTICS.PRODUCT_AFFINITY LIMIT 10;

-- ==========================================================
-- Snowflake Postgres 
-- ==========================================================
-- cd /Users/ddesai/Apps/automated-intelligence/snowflake-postgres
-- ./psql.sh -c "SELECT PRIORITY, SUBJECT, SUBSTRING(DESCRIPTION, 1, 120) FROM PUBLIC.SUPPORT_TICKETS ORDER BY RANDOM() LIMIT 10;"
-- ./psql.sh -c "SELECT REVIEW_TITLE, SUBSTRING(REVIEW_TEXT,1,120) FROM PUBLIC.PRODUCT_REVIEWS ORDER BY RANDOM() LIMIT 10;"

-- ==========================================================
-- Open format Iceberg tables for pg_lake
-- ==========================================================

USE SCHEMA PG_LAKE;
SELECT TABLE_SCHEMA, TABLE_NAME, IS_ICEBERG FROM INFORMATION_SCHEMA.TABLES WHERE table_schema = 'PG_LAKE';

SELECT GET_DDL('TABLE', 'AUTOMATED_INTELLIGENCE.PG_LAKE.SUPPORT_TICKETS');

SELECT * from AUTOMATED_INTELLIGENCE.PG_LAKE.SUPPORT_TICKETS;