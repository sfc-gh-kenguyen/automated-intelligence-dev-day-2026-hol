-- ============================================================================
-- Snowflake: Create Postgres Query Functions
-- ============================================================================
-- Run this in Snowflake after setting up external access (02_setup_external_access.sql)
-- 
-- Creates:
-- - QUERY_POSTGRES(sql) - Stored procedure returning VARIANT
-- - PG_QUERY(sql) - UDTF returning table of results
-- ============================================================================

-- ============================================================================
-- Context: Database, Schema, Role
-- ============================================================================
USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
USE DATABASE AUTOMATED_INTELLIGENCE;
USE WAREHOUSE AUTOMATED_INTELLIGENCE_WH;
USE SCHEMA POSTGRES;

-- ============================================================================
-- Stored Procedure: QUERY_POSTGRES
-- Returns query results as a VARIANT (JSON array)
-- ============================================================================
CREATE OR REPLACE PROCEDURE query_postgres(query_sql STRING)
RETURNS VARIANT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python', 'psycopg2')
HANDLER = 'run_query'
EXTERNAL_ACCESS_INTEGRATIONS = (postgres_external_access)
SECRETS = ('cred' = postgres_secret)
AS
$$
import _snowflake
import psycopg2
from datetime import date, datetime
from decimal import Decimal

def run_query(session, query_sql):
    # Get credentials from secret
    cred = _snowflake.get_username_password('cred')
    
    conn = psycopg2.connect(
        host='o6gnp7eqn5awvivkqhk22xpoym.sfsenorthamerica-gen-ai-hol.us-west-2.aws.postgres.snowflake.app',
        port=5432,
        database='postgres',
        user=cred.username,
        password=cred.password,
        sslmode='require'
    )
    
    cur = conn.cursor()
    cur.execute(query_sql)
    
    # Get column names
    columns = [desc[0] for desc in cur.description] if cur.description else []
    
    # Fetch results and convert to JSON-safe format
    results = []
    for row in cur.fetchall():
        row_dict = {}
        for col, val in zip(columns, row):
            if isinstance(val, (date, datetime)):
                row_dict[col] = val.isoformat()
            elif isinstance(val, Decimal):
                row_dict[col] = float(val)
            else:
                row_dict[col] = val
        results.append(row_dict)
    
    conn.close()
    return results
$$;

-- ============================================================================
-- UDTF: PG_QUERY
-- Returns query results as a table (one row per result)
-- ============================================================================
CREATE OR REPLACE FUNCTION pg_query(query_sql STRING)
RETURNS TABLE (result VARIANT)
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('psycopg2')
HANDLER = 'PgQuery'
EXTERNAL_ACCESS_INTEGRATIONS = (postgres_external_access)
SECRETS = ('cred' = postgres_secret)
AS
$$
import _snowflake
import psycopg2
from datetime import date, datetime
from decimal import Decimal

class PgQuery:
    def __init__(self):
        cred = _snowflake.get_username_password('cred')
        self.conn = psycopg2.connect(
            host='o6gnp7eqn5awvivkqhk22xpoym.sfsenorthamerica-gen-ai-hol.us-west-2.aws.postgres.snowflake.app',
            port=5432,
            database='postgres',
            user=cred.username,
            password=cred.password,
            sslmode='require'
        )
    
    def process(self, query_sql):
        cur = self.conn.cursor()
        cur.execute(query_sql)
        columns = [desc[0] for desc in cur.description] if cur.description else []
        for row in cur.fetchall():
            # Convert row to dict with JSON-safe values
            row_dict = {}
            for col, val in zip(columns, row):
                if isinstance(val, (date, datetime)):
                    row_dict[col] = val.isoformat()
                elif isinstance(val, Decimal):
                    row_dict[col] = float(val)
                else:
                    row_dict[col] = val
            yield (row_dict,)
    
    def end_partition(self):
        self.conn.close()
$$;

-- ============================================================================
-- Stored Procedure: PG_EXEC
-- Executes DDL/DML statements (no result set returned)
-- ============================================================================
CREATE OR REPLACE PROCEDURE pg_exec(sql_stmt STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python', 'psycopg2')
HANDLER = 'run_exec'
EXTERNAL_ACCESS_INTEGRATIONS = (postgres_external_access)
SECRETS = ('cred' = postgres_secret)
AS
$$
import _snowflake
import psycopg2

def run_exec(session, sql_stmt):
    cred = _snowflake.get_username_password('cred')
    conn = psycopg2.connect(
        host='o6gnp7eqn5awvivkqhk22xpoym.sfsenorthamerica-gen-ai-hol.us-west-2.aws.postgres.snowflake.app',
        port=5432,
        database='postgres',
        user=cred.username,
        password=cred.password,
        sslmode='require'
    )
    cur = conn.cursor()
    cur.execute(sql_stmt)
    conn.commit()
    conn.close()
    return 'OK'
$$;

-- ============================================================================
-- Verify functions created
-- ============================================================================
SHOW PROCEDURES LIKE 'query_postgres';
SHOW PROCEDURES LIKE 'pg_exec';
SHOW USER FUNCTIONS LIKE 'pg_query';
