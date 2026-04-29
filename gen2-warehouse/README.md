# Gen2 Warehouse Setup

This directory contains setup scripts for **Demo 1: Gen2 Warehouse Performance**.

## Purpose

Sets up the staging pipeline and MERGE procedures needed to demonstrate Gen2 warehouse performance characteristics for MERGE/UPDATE operations.

**Note:** *Performance improvements vary by workload characteristics, data volume, and query patterns. Gen2 warehouses are optimized for MERGE/UPDATE/DELETE operations.*

## Files

- `setup_staging_pipeline.sql` - Creates staging schema, tables, and Gen2 warehouse
- `setup_merge_procedures.sql` - Creates MERGE/UPDATE procedures with benchmarking

## Setup Instructions

```bash
# Run both scripts in order
snow sql -f gen2-warehouse/setup_staging_pipeline.sql -c dash-builder-si
snow sql -f gen2-warehouse/setup_merge_procedures.sql -c dash-builder-si
```

## Prerequisites

- Core setup must be completed first (`setup.sql`)
- Snowpipe Streaming configured to load data into staging tables

## What Gets Created

**Staging Schema:**
- `staging.orders_staging` - Append-only staging table for orders
- `staging.order_items_staging` - Append-only staging table for order items
- `staging.customers_staging` - Append-only staging table for customers

**Gen2 Warehouse:**
- `automated_intelligence_gen2_wh` - Gen2 warehouse with `RESOURCE_CONSTRAINT = 'STANDARD_GEN_2'`
- **Optima Indexing**: Gen2 warehouses automatically create and maintain indexes for point lookup queries at no additional cost

**Stored Procedures:**
- `merge_orders_gen1()` - MERGE orders using Gen1 warehouse
- `merge_orders_gen2()` - MERGE orders using Gen2 warehouse
- `merge_order_items_gen1()` - MERGE order_items using Gen1 warehouse
- `merge_order_items_gen2()` - MERGE order_items using Gen2 warehouse

## Usage

After setup, use the Streamlit dashboard to run Gen1 vs Gen2 comparison tests.

## Optima Indexing (Automatic Performance)

Gen2 warehouses include **Optima Indexing**, which automatically builds and maintains indexes behind the scenes to speed up point lookup queries. Key benefits:

- **Automatic**: Snowflake analyzes your workload and creates indexes on frequently queried columns
- **Free**: Snowflake covers all build and maintenance costs - no additional charges
- **Transparent**: No user configuration required

### Monitor Optima Performance
```sql
-- View index usage in query insights
SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_INSIGHT
WHERE WAREHOUSE_NAME = 'AUTOMATED_INTELLIGENCE_GEN2_WH'
ORDER BY START_TIME DESC;

-- Check Performance Explorer Dashboard in Snowsight for visual analysis
```

See main project README for full demo instructions.
