# Snowflake Postgres Integration

This module sets up a **Hybrid OLTP/OLAP Architecture** using Snowflake Postgres for transactional workloads and Snowflake for analytics.

## Overview

Snowflake Postgres is a managed PostgreSQL service within Snowflake. This integration demonstrates:
- **OLTP Layer (Postgres)**: Handles transactional writes for product_reviews and support_tickets
- **OLAP Layer (Snowflake)**: Analytics, Cortex AI, and natural language queries
- **MERGE-based Sync**: Scheduled task syncs data from Postgres to Snowflake
- **Cortex Search**: Semantic search over synced data for AI-powered queries

## Setup

### 0. Configure Postgres Credentials

```bash
# Copy the template and fill in your credentials
cp postgres_config.json.template postgres_config.json
# Edit postgres_config.json with your host, user, and password
```

### 1. Create Postgres Tables

Connect to your Snowflake Postgres instance and run:

```bash
# Using psql
psql "postgres://user:pass@host:5432/postgres?sslmode=require" -f 01_create_postgres_tables.sql
```

### 2. Generate Sample Data

The scripts pull `customer_id` and `product_id` from Snowflake RAW tables to ensure data consistency.

```bash
pip install psycopg2-binary snowflake-connector-python

# Set Snowflake connection (defaults to dash-builder-si)
export SNOWFLAKE_CONNECTION_NAME=<your-connection>

python insert_product_reviews.py  # Generate ~395 product reviews
python insert_support_tickets.py  # Generate ~500 support tickets
```

### 3. Setup External Access in Snowflake

Run in Snowflake (update credentials in the script first):

```bash
snow sql -c <connection> -f 02_setup_external_access.sql
```

### 4. Create Query Functions

```bash
snow sql -c <connection> -f 03_create_query_functions.sql
```

### 5. Create Sync Task

```bash
snow sql -c <connection> -f 05_create_sync_task.sql
```

### 6. Query Postgres from Snowflake

See `04_example_queries.sql` for examples, or:

```sql
-- Simple count
CALL query_postgres('SELECT COUNT(*) FROM product_reviews');

-- Query as table
SELECT result FROM TABLE(pg_query('SELECT * FROM product_reviews LIMIT 10'));

-- Extract fields
SELECT 
    result:review_id::INT as review_id,
    result:rating::INT as rating,
    result:review_title::STRING as title
FROM TABLE(pg_query('SELECT * FROM product_reviews LIMIT 10'));
```

## Tables

| Table | Records | Purpose |
|-------|---------|---------|
| product_reviews | ~395 | Customer reviews (OLTP source) |
| support_tickets | ~500 | Support tickets (OLTP source) |

## Hybrid OLTP/OLAP Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    OLTP Layer (Postgres)                         │
│  ┌─────────────────────┐ ┌─────────────────────────────────┐    │
│  │   product_reviews   │ │       support_tickets           │    │
│  │   (transactional    │ │       (transactional            │    │
│  │    writes)          │ │        writes)                  │    │
│  └─────────────────────┘ └─────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                           │
                           │ MERGE-based Sync (5 min task)
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                    OLAP Layer (Snowflake)                        │
│  ┌─────────────────────┐ ┌─────────────────────────────────┐    │
│  │ RAW.PRODUCT_REVIEWS │ │    RAW.SUPPORT_TICKETS          │    │
│  └─────────────────────┘ └─────────────────────────────────┘    │
│                           │                                      │
│                           ▼                                      │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              Cortex Search Services (SEMANTIC)             │  │
│  │  • product_reviews_search - semantic search over reviews  │  │
│  │  • support_tickets_search - semantic search over tickets  │  │
│  └───────────────────────────────────────────────────────────┘  │
│                           │                                      │
│                           ▼                                      │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              Cortex Agent (Snowflake Intelligence)         │  │
│  │  Natural language queries over reviews and tickets        │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Files

| File | Description |
|------|-------------|
| `01_create_postgres_tables.sql` | DDL to create tables in Postgres |
| `02_setup_external_access.sql` | Snowflake network rule, secret, and integration |
| `03_create_query_functions.sql` | Snowflake stored procedure and UDTF |
| `04_example_queries.sql` | Example queries using the functions |
| `05_create_sync_task.sql` | MERGE-based sync procedure and scheduled task |
| `insert_product_reviews.py` | Generate product reviews (pulls IDs from Snowflake) |
| `insert_support_tickets.py` | Generate support tickets (pulls IDs from Snowflake) |

## Sync Mechanism

The sync uses MERGE operations (more realistic than DELETE+INSERT):

```sql
-- Sync procedure handles:
-- 1. MERGE: Insert new records, update existing ones
-- 2. DELETE: Remove records deleted from Postgres source

CALL POSTGRES.sync_postgres_to_snowflake();

-- Scheduled task runs every 5 minutes
ALTER TASK POSTGRES.postgres_sync_task RESUME;
```

## Cortex Search Integration

After sync, data is searchable via Cortex Search:

```sql
-- Search product reviews
SELECT PARSE_JSON(
    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'AUTOMATED_INTELLIGENCE.SEMANTIC.PRODUCT_REVIEWS_SEARCH',
        '{"query": "quality issues with boots", "columns": ["review_title", "review_text", "rating"], "limit": 5}'
    )
)['results'] AS results;

-- Search support tickets
SELECT PARSE_JSON(
    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'AUTOMATED_INTELLIGENCE.SEMANTIC.SUPPORT_TICKETS_SEARCH',
        '{"query": "shipping delays", "columns": ["subject", "description", "priority"], "limit": 5}'
    )
)['results'] AS results;
```

## Connection Details

```
Host: <your-postgres-host>.postgres.snowflake.app
Port: 5432
Database: postgres
SSL: Required
```
