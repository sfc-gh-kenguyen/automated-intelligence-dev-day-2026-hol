-- ============================================================================
-- CREATE OR ALTER - Simplified DDL Management
-- ============================================================================
-- CREATE OR ALTER syntax allows idempotent DDL operations that work
-- whether the object exists or not. Perfect for source control and CI/CD.
--
-- Available for most object types since 2025.
-- ============================================================================

USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
USE DATABASE AUTOMATED_INTELLIGENCE;
USE WAREHOUSE AUTOMATED_INTELLIGENCE_WH;

-- ============================================================================
-- PART 1: Basic CREATE OR ALTER Patterns
-- ============================================================================

-- Tables (ALTER modifies existing, CREATE creates new)
CREATE OR ALTER TABLE AUTOMATED_INTELLIGENCE.RAW.DEMO_TABLE (
    id INT PRIMARY KEY,
    name VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- Add a column - same statement works
CREATE OR ALTER TABLE AUTOMATED_INTELLIGENCE.RAW.DEMO_TABLE (
    id INT PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(200),  -- New column
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- Views
CREATE OR ALTER VIEW AUTOMATED_INTELLIGENCE.RAW.demo_view AS
SELECT id, name FROM AUTOMATED_INTELLIGENCE.RAW.DEMO_TABLE;

-- Stored Procedures
CREATE OR ALTER PROCEDURE AUTOMATED_INTELLIGENCE.RAW.demo_procedure()
RETURNS VARCHAR
LANGUAGE SQL
AS
BEGIN
    RETURN 'Hello from CREATE OR ALTER!';
END;

-- Functions
CREATE OR ALTER FUNCTION AUTOMATED_INTELLIGENCE.RAW.demo_function(x INT)
RETURNS INT
LANGUAGE SQL
AS
$$
    x * 2
$$;

-- ============================================================================
-- PART 2: Supported Object Types
-- ============================================================================

/*
CREATE OR ALTER supports:
- TABLES (standard, hybrid, Iceberg)
- VIEWS
- MATERIALIZED VIEWS
- STORED PROCEDURES
- USER DEFINED FUNCTIONS (UDFs)
- EXTERNAL FUNCTIONS
- STREAMS
- TASKS
- MASKING POLICIES
- ROW ACCESS POLICIES
- TAGS
- WAREHOUSES
- RESOURCE MONITORS
- STAGES
- FILE FORMATS
- SEQUENCES
- NETWORK POLICIES

Note: Dynamic Tables use CREATE OR REPLACE (different behavior)
*/

-- ============================================================================
-- PART 3: Benefits for CI/CD
-- ============================================================================

/*
OLD APPROACH (problematic):
1. DROP TABLE IF EXISTS my_table;
2. CREATE TABLE my_table (...);
Problem: Loses data, requires careful ordering

CREATE OR REPLACE (risky):
1. CREATE OR REPLACE TABLE my_table (...);
Problem: Drops and recreates, loses data

CREATE OR ALTER (recommended):
1. CREATE OR ALTER TABLE my_table (...);
Benefits:
- Creates if not exists
- Alters if exists
- Preserves data
- Idempotent (safe to run multiple times)
*/

-- ============================================================================
-- PART 4: dbt Integration
-- ============================================================================

/*
In dbt, you can use CREATE OR ALTER for incremental models and views
by creating a custom materialization or using Snowflake's native support.

Example dbt model with on_schema_change:

-- models/marts/customers.sql
{{ config(
    materialized='incremental',
    on_schema_change='append_new_columns'
) }}

SELECT
    customer_id,
    first_name,
    last_name,
    email,  -- new column added
    created_at
FROM {{ ref('stg_customers') }}

{% if is_incremental() %}
WHERE created_at > (SELECT MAX(created_at) FROM {{ this }})
{% endif %}

For full CREATE OR ALTER support, use the snowflake adapter's
native capabilities or custom macros.
*/

-- ============================================================================
-- PART 5: Example - Schema Migration Script
-- ============================================================================

-- This script can be run repeatedly - it's idempotent
-- V1: Initial schema
CREATE OR ALTER TABLE AUTOMATED_INTELLIGENCE.RAW.USER_EVENTS (
    event_id VARCHAR(36) PRIMARY KEY,
    user_id INT NOT NULL,
    event_type VARCHAR(50),
    event_time TIMESTAMP NOT NULL
);

-- V2: Add properties column
CREATE OR ALTER TABLE AUTOMATED_INTELLIGENCE.RAW.USER_EVENTS (
    event_id VARCHAR(36) PRIMARY KEY,
    user_id INT NOT NULL,
    event_type VARCHAR(50),
    event_properties VARIANT,  -- Added in V2
    event_time TIMESTAMP NOT NULL
);

-- V3: Add session tracking
CREATE OR ALTER TABLE AUTOMATED_INTELLIGENCE.RAW.USER_EVENTS (
    event_id VARCHAR(36) PRIMARY KEY,
    user_id INT NOT NULL,
    session_id VARCHAR(36),  -- Added in V3
    event_type VARCHAR(50),
    event_properties VARIANT,
    event_time TIMESTAMP NOT NULL
);

-- ============================================================================
-- PART 6: Comparison with CREATE OR REPLACE
-- ============================================================================

/*
| Scenario                  | CREATE OR REPLACE | CREATE OR ALTER |
|---------------------------|-------------------|-----------------|
| Object doesn't exist      | Creates           | Creates         |
| Object exists, same def   | Drops/Recreates   | No change       |
| Object exists, new col    | Drops/Recreates   | Adds column     |
| Object exists, remove col | Drops/Recreates   | Error*          |
| Preserves data            | NO                | YES             |
| Preserves grants          | NO                | YES             |
| Idempotent                | Partially         | YES             |

*For removing columns, use ALTER TABLE ... DROP COLUMN explicitly
*/

-- ============================================================================
-- Demo Complete
-- ============================================================================
SELECT '✅ CREATE OR ALTER Demo Complete!' AS status;

-- Cleanup
DROP TABLE IF EXISTS AUTOMATED_INTELLIGENCE.RAW.DEMO_TABLE;
DROP VIEW IF EXISTS AUTOMATED_INTELLIGENCE.RAW.demo_view;
DROP PROCEDURE IF EXISTS AUTOMATED_INTELLIGENCE.RAW.demo_procedure();
DROP FUNCTION IF EXISTS AUTOMATED_INTELLIGENCE.RAW.demo_function(INT);
