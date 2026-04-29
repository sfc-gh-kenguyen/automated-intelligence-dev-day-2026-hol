-- ============================================================================
-- Snowflake: Setup External Access to Postgres
-- ============================================================================
-- Run this in Snowflake (Snowsight or CLI) to enable querying Postgres
-- from Snowflake SQL.
--
-- Prerequisites:
-- - ACCOUNTADMIN or role with CREATE INTEGRATION privileges
-- - Postgres instance running and accessible
-- ============================================================================

-- ============================================================================
-- Context: Database, Schema, Role
-- ============================================================================
USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
USE DATABASE AUTOMATED_INTELLIGENCE;
USE WAREHOUSE AUTOMATED_INTELLIGENCE_WH;

-- Create dedicated schema for Postgres integration objects
CREATE SCHEMA IF NOT EXISTS POSTGRES;
USE SCHEMA POSTGRES;

-- Step 1: Create a network rule for the Postgres host
-- Update the VALUE_LIST with your Postgres host:port
CREATE OR REPLACE NETWORK RULE postgres_network_rule
  TYPE = HOST_PORT
  MODE = EGRESS
  VALUE_LIST = ('o6gnp7eqn5awvivkqhk22xpoym.sfsenorthamerica-gen-ai-hol.us-west-2.aws.postgres.snowflake.app:5432');

-- Step 2: Create a secret for Postgres credentials
-- Update USERNAME and PASSWORD with your credentials
CREATE OR REPLACE SECRET postgres_secret
  TYPE = PASSWORD
  USERNAME = 'snowflake_admin'
  PASSWORD = '<YOUR_PASSWORD_HERE>';

-- Step 3: Create external access integration
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION postgres_external_access
  ALLOWED_NETWORK_RULES = (postgres_network_rule)
  ALLOWED_AUTHENTICATION_SECRETS = (postgres_secret)
  ENABLED = TRUE;

-- Verify the integration
SHOW EXTERNAL ACCESS INTEGRATIONS LIKE 'postgres%';
