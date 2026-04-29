# Ingestion to Intelligence

## Overview

**Theme:** *From raw data to AI-powered insights—entirely within Snowflake.*

This demo suite executes a full-stack data lifecycle in **4 Acts**, culminating in conversational AI that understands your business. The journey flows from real-time ingestion through transformation, serving, and analytics—ending with Snowflake Intelligence where users simply ask questions in plain English.

### Act 1: Ingest & Stage
1. **Real-Time Ingestion**: Snowpipe Streaming (Python + Java SDKs)
2. **Transformation Pipeline**: Gen2 Warehouses + Dynamic Tables

### Act 2: Serve & Analyze
3. **High-Concurrency Serving**: Interactive Tables & Warehouses (GA)
4. **Analytics & ML**: dbt models + GPU-accelerated ML training

### Act 3: Intelligence & Governance
5. **Conversational AI**: Snowflake Intelligence with Cortex Agent
6. **Governed AI**: Row-based access control for transparent security

### Bonus: Open Lakehouse
7. **Hybrid OLTP/OLAP**: Snowflake Postgres for transactional workloads
8. **Iceberg Interoperability**: pg_lake demonstrates zero vendor lock-in

### Parallel / Bookends
- **Cortex Code** (Opener): AI-assisted development - "how we built this"
- **Streamlit Dashboard** (Continuous): Real-time monitoring alongside any demo

### Demo Flow
```
                     INGESTION ─────────────────────────────► INTELLIGENCE

┌─────────────────────────────────────────────────────────────────────┐
│  OPENER: CORTEX CODE (Optional, 5 min)                              │
│  AI-assisted development: "Let me show you how we built this"       │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│  ACT 1: INGEST & STAGE                                              │
├─────────────────────────────────────────────────────────────────────┤
│  DEMO 1: Real-Time Ingestion                                        │
│  Snowpipe Streaming (Python/Java SDK) → Linear horizontal scaling   │
├─────────────────────────────────────────────────────────────────────┤
│  DEMO 2: Transformation Pipeline                                    │
│  Gen2 Warehouses (MERGE + Optima Indexing) → Dynamic Tables         │
│  • Staging pattern with optimized DML                               │
│  • 3-tier incremental refresh pipeline                              │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│  ACT 2: SERVE & ANALYZE                                             │
├─────────────────────────────────────────────────────────────────────┤
│  DEMO 3: High-Concurrency Serving                                   │
│  Interactive Tables + Warehouses (GA since Dec 2025)                │
│  • Sub-100ms queries under high concurrency                         │
├─────────────────────────────────────────────────────────────────────┤
│  DEMO 4: Analytics & ML                                             │
│  dbt in Workspaces → GPU Training → Model Registry                  │
│  • CLV, segmentation, product affinity models                       │
│  • XGBoost recommendations with gpu_hist                            │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│  ACT 3: INTELLIGENCE & GOVERNANCE                                   │
├─────────────────────────────────────────────────────────────────────┤
│  DEMO 5: Conversational AI                                          │
│  Snowflake Intelligence (GA) + Cortex Agent                         │
│  • Analyst (text-to-SQL) + Search (semantic) + ML Tools             │
│  • AI SQL functions: AI_CLASSIFY, AI_REDACT, AI_TRANSCRIBE          │
├─────────────────────────────────────────────────────────────────────┤
│  DEMO 6: Governed AI                                                │
│  Row Access Policies → Transparent security                         │
│  • Same agent, different answers by role                            │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
                    ✅ INGESTION TO INTELLIGENCE COMPLETE
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│  BONUS: OPEN LAKEHOUSE (For architecture-focused audiences)         │
├─────────────────────────────────────────────────────────────────────┤
│  DEMO 7: Hybrid OLTP/OLAP                                           │
│  Snowflake Postgres (managed) → MERGE sync → Cortex Search          │
├─────────────────────────────────────────────────────────────────────┤
│  DEMO 8: Iceberg Interoperability                                   │
│  Snowflake → Iceberg on S3 → pg_lake (external Postgres)            │
│  • Zero vendor lock-in: Any Iceberg reader works                    │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  📺 STREAMLIT DASHBOARD (Parallel - run alongside any demo)         │
│  Real-time monitoring: ingestion metrics, pipeline health, ML       │
└─────────────────────────────────────────────────────────────────────┘
```

Each demo builds on shared infrastructure and can be run sequentially or independently after one-time setup.

---

## 🚀 One-Time Setup (Do This Once at the Beginning)

### Core Setup (Required for All Demos)

**STEP 1: Grant Required Privileges (Run as ACCOUNTADMIN)**

```sql
USE ROLE ACCOUNTADMIN;
GRANT CREATE SNOWFLAKE INTELLIGENCE ON ACCOUNT TO ROLE AUTOMATED_INTELLIGENCE;
```

**STEP 2: Run Core Infrastructure Setup**

```bash
# Core infrastructure (database, schemas, warehouse, tables, dynamic tables)
snow sql -f setup.sql -c <your-connection-name>

# What this creates:
# - Database: AUTOMATED_INTELLIGENCE
# - Schemas: RAW, STAGING, DYNAMIC_TABLES, INTERACTIVE, SEMANTIC, MODELS, DBT_STAGING, DBT_ANALYTICS
# - Warehouse: AUTOMATED_INTELLIGENCE_WH (SMALL, auto-suspend 60s)
# - Tables: customers, orders, order_items, product_catalog, support_tickets, product_reviews
# - Dynamic Tables: 5-tier pipeline (enriched → fact → metrics)
```

### Component-Specific Setup (Run Only What You Need)

```bash
# Demo 1: Snowpipe Streaming
# Requires RSA key generation and SDK setup
# See snowpipe-streaming-java/README.md or snowpipe-streaming-python/README.md

# Demo 2: Gen2 Warehouse Performance
snow sql -f gen2-warehouse/setup_staging_pipeline.sql -c <your-connection-name>
snow sql -f gen2-warehouse/setup_merge_procedures.sql -c <your-connection-name>

# Demo 3: Dynamic Tables
# (No additional setup - covered by core setup.sql)

# Demo 4: Interactive Tables
snow sql -f interactive/setup_interactive.sql -c <your-connection-name>

# Demo 5: DBT Analytics
cd dbt-analytics
pip install dbt-snowflake
dbt deps && dbt build
cd ..

# Demo 6: ML Training
# Deploy notebook to Snowflake Workspaces (see ml-training/README.md)

# Demo 7: Streamlit Dashboard
cd streamlit-dashboard
pip install streamlit snowflake-snowpark-python pandas
streamlit run streamlit_app.py --server.port 8501

# Demo 8: Snowflake Intelligence
# See snowflake-intelligence/README.md for setup

# Demo 9: Security & Governance
snow sql -f security-and-governance/setup_west_coast_manager.sql -c <your-connection-name>
```

**After core setup, pick the demos you want and run their specific setup scripts!**

### 🔄 Resetting Data Between Demo Runs

If you need to start fresh with new ingestion data:

```bash
# Truncate orders and downstream tables (keeps CUSTOMERS reference data)
snow sql -f truncate_tables.sql -c <your-connection-name>
```

This truncates:
- `RAW.ORDERS` and `RAW.ORDER_ITEMS` (source data)
- `INTERACTIVE.CUSTOMER_ORDER_ANALYTICS` and `INTERACTIVE.ORDER_LOOKUP` (downstream)
- Dynamic Tables will auto-refresh with new data

---

## 📋 Demo Selection Guide

Choose demos based on your audience:

| Act | Demo | Duration | Best For | Key Takeaway |
|-----|------|----------|----------|--------------|
| - | **Cortex Code (Opener)** | 5 min | Everyone | AI-assisted development |
| 1 | **1. Real-Time Ingestion** | 10-15 min | Data Engineers | Linear horizontal scaling |
| 1 | **2. Transformation Pipeline** | 20-25 min | Data Engineers, Architects | Gen2 + Dynamic Tables |
| 2 | **3. High-Concurrency Serving** | 10-15 min | App Developers | Sub-100ms queries (GA) |
| 2 | **4. Analytics & ML** | 20-25 min | Analytics/ML Engineers | dbt + GPU training |
| 3 | **5. Conversational AI** | 10-15 min | Business Users, Analysts | Natural language queries |
| 3 | **6. Governed AI** | 10-15 min | Security Teams | Row-level security with AI |
| Bonus | **7. Hybrid OLTP/OLAP** | 10-15 min | Architects | Snowflake Postgres |
| Bonus | **8. Iceberg Interop** | 10-15 min | Architects | Open lakehouse, no lock-in |
| - | **SQL Features** | 5-10 min each | Data Engineers, DBAs | Latest SQL capabilities |
| - | **Streamlit Dashboard** | Continuous | Everyone | Real-time monitoring |

### Audience-Based Selections

| Audience | Recommended | Duration |
|----------|-------------|----------|
| **Executives** | Acts 1-3 (Demos 1-6) | 60 min |
| **Data Engineers** | Acts 1-2 (Demos 1-4) | 55 min |
| **Business/Analysts** | Acts 2-3 (Demos 3-6) | 45 min |
| **ML Engineers** | Act 2 (Demos 3-4) | 35 min |
| **Architects** | Acts 1-3 + Bonus | 80 min |
| **Full Suite** | Everything | 90 min |

---

# ═══════════════════════════════════════════════════════════════════════════════
# ACT 1: INGEST & STAGE
# ═══════════════════════════════════════════════════════════════════════════════

# DEMO 1: Real-Time Ingestion (Snowpipe Streaming)

## Overview
Demonstrates high-performance real-time data ingestion using Snowpipe Streaming, capable of scaling to massive volumes through parallel processing. Available in both **Java** and **Python** implementations with identical functionality.

## Architecture Highlights

**Scaling characteristics:**
- Single instance: Demonstrates basic ingestion pattern
- Parallel instances: Shows linear horizontal scaling capability
- Each instance operates independently with unique channels
- Production-ready: Supports massive-scale ingestion with sufficient parallelization

**Note:** *Actual performance varies by Snowflake region, warehouse size, network latency, and data volume. Focus on demonstrating scaling patterns rather than absolute numbers.*

## Implementation Options

### Option 1: Python Implementation (Recommended for Quick Start)

```bash
cd snowpipe-streaming-python

# Single instance demo (10K orders)
python src/automated_intelligence_streaming.py 10000

# Parallel demo (1M orders across 5 instances)
python src/parallel_streaming_orchestrator.py 1000000 5

# Large scale demo (10M orders across 10 instances)
python src/parallel_streaming_orchestrator.py 10000000 10
```

**Python Setup:**
```bash
pip install -r requirements.txt
cp profile.json.template profile.json
# Edit profile.json with your credentials
```

### Option 2: Java Implementation

```bash
cd snowpipe-streaming-java

# Build
mvn clean install

# Single instance demo (10K orders)
java -jar target/automated-intelligence-streaming-1.0.0.jar 10000

# Parallel demo (1M orders across 5 instances)
java ParallelStreamingOrchestrator 1000000 5
```

## Key Demo Points

**Talking points:**
> "We're streaming data directly into Snowflake with sub-second latency. This architecture scales horizontally - each instance operates independently with unique channels, enabling linear scaling by adding more parallel instances.
>
> Both Python and Java implementations deliver identical functionality and business logic. The Python SDK is Rust-backed for high performance, while offering simpler deployment and integration with Python data tools."

**Note for presenters:** *Performance numbers will vary by environment. Focus on demonstrating the scaling pattern (1 instance → 5 instances → 10 instances) rather than claiming specific throughput numbers.*

### Monitoring

```sql
-- Check channel status
SELECT 
    CHANNEL_NAME,
    PIPE_NAME,
    TABLE_NAME,
    LAST_COMMITTED_TIME,
    STATUS
FROM SNOWFLAKE.ACCOUNT_USAGE.SNOWPIPE_STREAMING_CHANNEL_HISTORY
WHERE TABLE_DATABASE = 'AUTOMATED_INTELLIGENCE'
  AND TABLE_SCHEMA = 'RAW'
ORDER BY LAST_COMMITTED_TIME DESC;

-- Verify data ingestion
SELECT 'orders' AS table_name, COUNT(*) AS row_count FROM RAW.ORDERS
UNION ALL
SELECT 'order_items', COUNT(*) FROM RAW.ORDER_ITEMS;
```

**Key Architecture Points:**

**Horizontal Scaling:**
- Each parallel instance operates independently
- Linear scaling: 2x instances ≈ 2x throughput
- Success rate: Exactly-once delivery guarantees
- Customer partitioning: No conflicts with proper ID range distribution

**Note:** *Absolute throughput varies by Snowflake account configuration. The value is demonstrating how parallelization scales linearly.*

**Closing:**
> "Snowpipe Streaming provides exactly-once delivery guarantees, automatic offset management, and linear horizontal scaling. No external streaming infrastructure needed - it's native to Snowflake. Choose Python for rapid development and integration with data science tools, or Java for enterprise JVM environments. Both deliver identical performance and functionality."

**See:** 
- Python: `snowpipe-streaming-python/README.md`
- Java: `snowpipe-streaming-java/README.md`

---

# DEMO 2: Transformation Pipeline (Gen2 + Dynamic Tables)

This demo combines Gen2 Warehouse performance and Dynamic Tables into a unified transformation story.

## Part A: Gen2 Warehouse Performance

## Overview
Demonstrates performance improvements on MERGE/UPDATE/DELETE operations using Gen2 warehouses with a production-ready staging pattern.

## Architecture

```
Snowpipe Streaming (low latency)
       ↓
staging.* tables (append-only)
       ↓
Gen2 MERGE/UPDATE (deduplicate, upsert, enrich)
       ↓
raw.* tables (production)
```

## Demo Flow

### Step 1: Stream Data to Staging Tables

```bash
cd snowpipe-streaming-python
python src/automated_intelligence_streaming.py --config config_staging.properties --num-orders 50000
```

**What to say:**
> "We're streaming 50,000 orders directly to staging tables using Snowpipe Streaming. This append-only staging pattern enables high-throughput ingestion without blocking production queries."

### Step 2: Verify Staging Data

```sql
-- Check staging data volumes
SELECT 'staging.orders' AS table_name, COUNT(*) AS row_count 
FROM AUTOMATED_INTELLIGENCE.STAGING.ORDERS_STAGING
UNION ALL
SELECT 'staging.order_items', COUNT(*) 
FROM AUTOMATED_INTELLIGENCE.STAGING.ORDER_ITEMS_STAGING;
```

### Step 3: Run Gen2 vs Gen1 Performance Test

**Option A: Via Streamlit Dashboard (Recommended)**

```bash
cd streamlit-dashboard
streamlit run streamlit_app.py --server.port 8501
# Navigate to "Next-Gen Warehouse Performance" page
# Click "Run MERGE Test using Gen 1 and Gen 2"
```

**Option B: Via SQL**

```sql
-- Create snapshot for fair comparison
CALL AUTOMATED_INTELLIGENCE.STAGING.SNAPSHOT_STAGING_DATA();

-- Test Gen1 warehouse
USE WAREHOUSE AUTOMATED_INTELLIGENCE_WH;
CALL AUTOMATED_INTELLIGENCE.STAGING.MERGE_STAGING_TO_RAW();

-- Restore staging data to same state
CALL AUTOMATED_INTELLIGENCE.STAGING.RESTORE_STAGING_DATA();

-- Test Gen2 warehouse
USE WAREHOUSE AUTOMATED_INTELLIGENCE_GEN2_WH;
CALL AUTOMATED_INTELLIGENCE.STAGING.MERGE_STAGING_TO_RAW();
```

### Step 4: Compare Performance Results

```sql
-- Query warehouse query history
SELECT 
    WAREHOUSE_NAME,
    QUERY_TYPE,
    EXECUTION_TIME,
    ROWS_INSERTED,
    ROWS_UPDATED,
    ROWS_DELETED
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY())
WHERE QUERY_TEXT LIKE '%MERGE_STAGING_TO_RAW%'
ORDER BY START_TIME DESC
LIMIT 10;
```

**What to say:**
> "Gen2 warehouses provide performance improvements on MERGE/UPDATE operations compared to Gen1. The snapshot/restore mechanism ensures fair comparison - both warehouses operate on identical data state. 
>
> Key operations we're testing:
> - **MERGE**: Deduplicates using ROW_NUMBER(), then upserts to production (MATCHED → UPDATE, NOT MATCHED → INSERT)
> - **UPDATE**: Applies business logic like discount adjustments based on order amounts
>
> This staging pattern is production-ready and can be automated with Snowflake TASK for continuous pipeline execution."

**Note for presenters:** *Performance improvement percentages vary by workload characteristics, data volume, and query patterns. Focus on demonstrating the staging pattern and Gen2 capabilities rather than claiming specific percentage improvements.*

## Key Insights

**Performance:**
- Gen2 uses `RESOURCE_CONSTRAINT = 'STANDARD_GEN_2'` for optimized DML
- **Optima Indexing**: Gen2 warehouses automatically create and maintain indexes for point lookup queries at no additional cost
- Performance characteristics vary by workload and data volume

**Architecture Benefits:**
- Staging pattern enables high-throughput ingestion without blocking production
- Snapshot/restore ensures fair benchmarking
- Production-ready: Can automate with TASK for continuous pipeline

**See:** `gen2-warehouse/README.md` for detailed setup, verification, and automation with TASK

---

## Part B: Dynamic Tables Pipeline

## Overview
Showcases Snowflake Dynamic Tables with incremental refresh, automatic dependency management, and real-time data propagation through a 3-tier pipeline.

---

## Pre-Demo Review (Optional - Show Current State)

### Step 1: Show the Current Database Structure
```sql
-- Show all schemas in the database
SHOW SCHEMAS IN DATABASE automated_intelligence;
```

**What to say**: 
> "We have a clean structure with two main schemas: RAW for our source data, and DYNAMIC_TABLES for our entire pipeline."

### Step 2: Show Existing Dynamic Tables
```sql
-- Display all dynamic tables with key metadata
SHOW DYNAMIC TABLES IN DATABASE automated_intelligence;
```

**What to say**: 
> "Here are our 5 dynamic tables organized in 3 tiers:
> - Tier 1: enriched_orders and enriched_order_items (1-minute target lag)
> - Tier 2: fact_orders (DOWNSTREAM lag - waits for dependencies)
> - Tier 3: daily_business_metrics and product_performance_metrics (DOWNSTREAM lag)
> 
> Notice the 'refresh_mode' column shows INCREMENTAL for all tables - this means they only process changes, not the entire dataset."

### Step 3: Show Current Data Volumes
```sql
-- Check current row counts across all tables
SELECT 'RAW: customers' AS layer_table, COUNT(*) AS row_count 
FROM automated_intelligence.raw.customers
UNION ALL
SELECT 'RAW: orders', COUNT(*) 
FROM automated_intelligence.raw.orders
UNION ALL
SELECT 'RAW: order_items', COUNT(*) 
FROM automated_intelligence.raw.order_items
UNION ALL
SELECT 'TIER 1: enriched_orders', COUNT(*) 
FROM automated_intelligence.dynamic_tables.enriched_orders
UNION ALL
SELECT 'TIER 2: fact_orders', COUNT(*) 
FROM automated_intelligence.dynamic_tables.fact_orders
UNION ALL
SELECT 'TIER 3: daily_metrics', COUNT(*) 
FROM automated_intelligence.dynamic_tables.daily_business_metrics;
```

**What to say**: 
> "Currently, we have 50,100 orders and 300,100 order items in our raw tables. The dynamic tables are all synchronized with this data."

---

## Main Demo - Demonstrating Incremental Refresh

### Step 4: Query Current Refresh History (Baseline)
```sql
-- Check the most recent refresh operations
SELECT 
    name,
    refresh_action,
    refresh_trigger,
    state,
    data_timestamp,
    query_id
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
    NAME_PREFIX => 'AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES'
))
ORDER BY data_timestamp DESC
LIMIT 20;
```

**What to say**: 
> "Let's look at the refresh history. The 'refresh_action' column shows whether each refresh was INCREMENTAL or FULL. Since these tables were just created, you'll see the initial refresh operations here. Now let's see incremental refresh in action."

### Step 5: Capture Current Daily Metrics (Before Insert)
```sql
-- Show current daily metrics to compare after
SELECT 
    order_date_only,
    total_orders,
    unique_customers,
    total_revenue,
    total_final_revenue,
    avg_order_value
FROM automated_intelligence.dynamic_tables.daily_business_metrics
ORDER BY order_date_only DESC
LIMIT 5;
```

**What to say**: 
> "Here's our current daily business metrics. Pay attention to today's date - we'll see this update after we insert new orders."

### Step 6: Insert New Orders Using Stored Procedure
```sql
-- ⚠️ generate_orders() procedure removed
-- Use Snowpipe Streaming to generate orders
-- See: snowpipe-streaming-java/ or snowpipe-streaming-python/

-- For demo purposes: check existing orders
SELECT COUNT(*) FROM automated_intelligence.raw.orders;
```

**What to say**: 
> "The generate_orders stored procedure has been removed. In production, we now use Snowpipe Streaming for realistic continuous order ingestion. For this demo, we'll work with existing orders in the system, or you can run the Snowpipe Streaming application to generate new data in real-time."

### Step 7: Verify New Data in Raw Tables
```sql
-- Confirm the new orders are in the raw table
SELECT 
    'orders' AS table_name,
    COUNT(*) AS total_rows,
    MAX(order_date) AS latest_order_date
FROM automated_intelligence.raw.orders
UNION ALL
SELECT 
    'order_items',
    COUNT(*),
    NULL
FROM automated_intelligence.raw.order_items;
```

**What to say**: 
> "Perfect! We now have 50,600 orders (up from 50,100). The latest order_date shows these were just created. Now let's manually refresh each tier to see incremental refresh in action.
>
> **Important note about DOWNSTREAM lag**: In production, when Tier 1's **scheduled refresh** runs (every ~1 minute), Snowflake automatically triggers Tier 2 and Tier 3 (which have DOWNSTREAM lag). However, **manual refreshes do NOT trigger DOWNSTREAM dependencies** - that's why we need to manually refresh each tier in this demo. The automatic cascade only works with scheduled refreshes, not manual ones. So we're simulating what would happen automatically in production by manually stepping through each tier!"

### Step 8: Manually Refresh Tier 1 Dynamic Tables
```sql
-- Refresh the first tier (enrichment layer)
-- NOTE: In production, this happens automatically every ~1 minute
ALTER DYNAMIC TABLE automated_intelligence.dynamic_tables.enriched_orders REFRESH;
ALTER DYNAMIC TABLE automated_intelligence.dynamic_tables.enriched_order_items REFRESH;
```

**What to say**: 
> "I'm manually refreshing the Tier 1 tables for demo purposes. In production, these would automatically refresh every ~1 minute based on their target lag setting. Because they use incremental refresh, they'll only process the 500 new orders, not all 50,600. 
>
> Note that this manual refresh does NOT automatically trigger Tier 2 and Tier 3 - manual refreshes don't cascade to DOWNSTREAM dependencies. Only scheduled refreshes cascade automatically!"

### Step 9: Manually Refresh Tier 2 Dynamic Table
```sql
-- Refresh the integration layer
-- NOTE: In production, this automatically refreshes when Tier 1 completes (DOWNSTREAM lag)
ALTER DYNAMIC TABLE automated_intelligence.dynamic_tables.fact_orders REFRESH;
```

**What to say**: 
> "Manually refreshing Tier 2 now. In production, when Tier 1 completes its **scheduled refresh**, the DOWNSTREAM target lag means Snowflake automatically triggers Tier 2. But manual refreshes don't cascade - I need to explicitly refresh this tier. This is simulating what would happen automatically in production!"

### Step 10: Manually Refresh Tier 3 Dynamic Tables
```sql
-- Refresh the aggregation layer
-- NOTE: In production, these automatically refresh when Tier 2 completes (DOWNSTREAM lag)
ALTER DYNAMIC TABLE automated_intelligence.dynamic_tables.daily_business_metrics REFRESH;
ALTER DYNAMIC TABLE automated_intelligence.dynamic_tables.product_performance_metrics REFRESH;
```

**What to say**: 
> "Finally, manually refreshing our Tier 3 aggregation tables. In production, these also have DOWNSTREAM lag, so they automatically refresh when Tier 2 completes its **scheduled refresh**. The key point: **scheduled refreshes cascade automatically through DOWNSTREAM dependencies, but manual refreshes do not**. That's why we're manually triggering each tier - to simulate the automatic production flow in a way we can demonstrate step-by-step!"

---

## Validation & Results

### Step 11: Query Refresh History to Show Incremental Refresh
```sql
-- Show the refresh operations we just triggered
SELECT 
    name,
    refresh_action,
    refresh_trigger,
    state,
    data_timestamp,
    refresh_start_time,
    refresh_end_time,
    DATEDIFF('second', refresh_start_time, refresh_end_time) AS duration_seconds
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
    NAME_PREFIX => 'AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES'
))
ORDER BY data_timestamp DESC
LIMIT 20;
```

**What to say**: 
> "**This is the key insight!** Look at the 'refresh_action' column - all our refreshes show INCREMENTAL. This means each dynamic table only processed the 500 new orders, not the entire dataset of 50,600+ orders. 
> 
> The 'duration_seconds' shows how fast these refreshes completed. Incremental refresh is exponentially faster as your data grows - instead of reprocessing terabytes, you only process megabytes of changes."

### Step 12: Verify Data Propagation - Check Row Counts
```sql
-- Confirm all tables now have the updated data
SELECT 'RAW: orders' AS layer_table, COUNT(*) AS row_count 
FROM automated_intelligence.raw.orders
UNION ALL
SELECT 'TIER 1: enriched_orders', COUNT(*) 
FROM automated_intelligence.dynamic_tables.enriched_orders
UNION ALL
SELECT 'TIER 2: fact_orders', COUNT(*) 
FROM automated_intelligence.dynamic_tables.fact_orders
UNION ALL
SELECT 'TIER 3: daily_metrics', COUNT(*) 
FROM automated_intelligence.dynamic_tables.daily_business_metrics;
```

**What to say**: 
> "Perfect data lineage! The 500 new orders have propagated through all three tiers. Notice the fact_orders count increased by ~3,000 rows (500 orders × ~6 items each)."

### Step 13: Query Updated Daily Metrics (After Insert)
```sql
-- Show the updated daily metrics
SELECT 
    order_date_only,
    total_orders,
    unique_customers,
    total_revenue,
    total_final_revenue,
    avg_order_value
FROM automated_intelligence.dynamic_tables.daily_business_metrics
ORDER BY order_date_only DESC
LIMIT 5;
```

**What to say**: 
> "Look at today's date - the metrics have updated to include our 500 new orders. The aggregations happened automatically as part of the incremental refresh."

### Step 14: Show Product Performance Updates
```sql
-- Display updated product category metrics
SELECT 
    product_category,
    orders_count,
    items_sold,
    total_quantity_sold,
    total_revenue,
    ROUND(avg_unit_price, 2) AS avg_unit_price
FROM automated_intelligence.dynamic_tables.product_performance_metrics
ORDER BY total_revenue DESC;
```

**What to say**: 
> "Our product performance metrics are also up-to-date. These aggregations would be expensive to compute on-demand over millions of rows, but with dynamic tables, they're pre-computed and incrementally maintained."

---

## Advanced Features Demo (Optional)

### Step 15: Show Dynamic Table Dependency Graph
```sql
-- Show the dependency chain and configuration
SHOW DYNAMIC TABLES IN DATABASE automated_intelligence;
```

**Alternative SQL query (if you want formatted output):**
```sql
-- Query to show key properties
SELECT 
    name,
    target_lag_sec,
    target_lag_type,
    latest_data_timestamp,
    last_completed_refresh_state,
    scheduling_state
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLES())
WHERE database_name = 'AUTOMATED_INTELLIGENCE'
ORDER BY 
    CASE 
        WHEN target_lag_type = 'DOWNSTREAM' THEN 2
        ELSE 1
    END,
    name;
```

**What to say**: 
> "Snowflake automatically manages the dependency graph. Tables with time-based target lag (12 hours) refresh independently. Tables with DOWNSTREAM lag wait for their dependencies, ensuring data consistency."

### Step 16: Show Current State of All Dynamic Tables
```sql
-- Detailed status of each dynamic table
SELECT 
    name AS table_name,
    target_lag_type,
    target_lag_sec,
    latest_data_timestamp,
    last_completed_refresh_state,
    scheduling_state,
    mean_lag_sec,
    maximum_lag_sec
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLES())
WHERE database_name = 'AUTOMATED_INTELLIGENCE'
AND schema_name = 'DYNAMIC_TABLES'
ORDER BY name;
```

**What to say**: 
> "Here's the current state of our pipeline. All tables are ACTIVE and using INCREMENTAL refresh mode. The data_timestamp shows when each table was last refreshed."

---

## Demo Comparison: Incremental vs Full Refresh

### Step 17: Show the Efficiency of Incremental Refresh
```sql
-- Show the most recent refresh for each dynamic table
SELECT 
    name,
    refresh_action,
    refresh_trigger,
    state,
    DATEDIFF('second', refresh_start_time, refresh_end_time) AS duration_seconds,
    data_timestamp,
    statistics:numInsertedRows::INT AS rows_inserted,
    statistics:numDeletedRows::INT AS rows_deleted,
    CASE 
        WHEN refresh_action = 'INCREMENTAL' THEN 'Only processed changes'
        WHEN refresh_action = 'FULL' THEN 'Processed entire dataset'
        WHEN refresh_action = 'NO_DATA' THEN 'No changes detected'
    END AS refresh_description
FROM (
    SELECT 
        name,
        refresh_action,
        refresh_trigger,
        state,
        refresh_start_time,
        refresh_end_time,
        data_timestamp,
        statistics,
        ROW_NUMBER() OVER (PARTITION BY name ORDER BY data_timestamp DESC) AS rn
    FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
        NAME_PREFIX => 'AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES'
    ))
)
WHERE rn = 1
ORDER BY name;
```

**Alternative - Show refresh action distribution:**
```sql
-- Count refresh types across all dynamic tables
SELECT 
    name,
    refresh_action,
    COUNT(*) AS refresh_count,
    AVG(DATEDIFF('second', refresh_start_time, refresh_end_time)) AS avg_duration_sec,
    SUM(statistics:numInsertedRows::INT) AS total_rows_inserted
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
    NAME_PREFIX => 'AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES'
))
GROUP BY name, refresh_action
ORDER BY name, refresh_action;
```

**What to say**: 
> "Here you can see the refresh history for all our dynamic tables. Look at the key columns:
> - **refresh_action**: Shows INCREMENTAL when processing changes, or NO_DATA when no changes were detected
> - **rows_inserted/rows_deleted**: The actual row changes processed - notice how incremental refreshes only touch the changed rows
> - **duration_seconds**: Incremental refreshes are extremely fast because they only process deltas
> 
> The alternative query shows aggregated statistics across all refreshes. You'll see that we have INCREMENTAL refreshes that processed thousands of rows in just 1-2 seconds. This is the key to scaling - as your data grows to millions of rows, you still only process the changes.
> 
> **Important**: You'll mainly see NO_DATA and INCREMENTAL refreshes in the history. NO_DATA means the refresh ran but detected no changes to process. INCREMENTAL means changes were detected and processed efficiently. This demonstrates how dynamic tables are smart about only doing work when needed."

---

## Key Takeaways for Audience

**At the end of the demo, summarize:**

1. **Incremental Refresh**: Dynamic tables intelligently detect changes and only process deltas, not entire datasets
2. **Automatic Dependency Management**: The DOWNSTREAM target lag ensures proper refresh ordering without manual orchestration
3. **Declarative Pipelines**: No need to write complex DAGs or manage orchestration - just declare your transformations
4. **Real-time Insights**: Pre-computed aggregations are always fresh within the target lag window
5. **Cost Efficiency**: Pay only for the compute needed to process changes, not to reprocess everything
6. **Zero Manual Intervention**: In production, the entire pipeline is self-orchestrating - set the target lag once and it runs forever

### Production Deployment: Set It and Forget It

**Important clarification for the audience:**

> "Everything we manually refreshed today happens **automatically** in production - but only with **scheduled refreshes**, not manual ones. Here's the key distinction:
>
> **Manual Refresh (what we did in demo):**
> - Does NOT trigger DOWNSTREAM dependencies
> - Must manually refresh each tier
> - Only used for demos, testing, or emergency immediate updates
>
> **Scheduled Refresh (production behavior):**
> - DOES automatically trigger DOWNSTREAM dependencies
> - Entire cascade happens automatically
> - This is how production works!
>
> **What you configure once:**
> - Tier 1 tables: `TARGET_LAG = '1 minute'`
> - Tier 2 tables: `TARGET_LAG = DOWNSTREAM`
> - Tier 3 tables: `TARGET_LAG = DOWNSTREAM`
>
> **What happens automatically forever (scheduled refreshes):**
> 1. Every ~1 minute, Tier 1's **scheduled refresh** runs automatically
> 2. Snowflake detects Tier 2 depends on Tier 1 → automatically triggers Tier 2 refresh
> 3. Snowflake detects Tier 3 depends on Tier 2 → automatically triggers Tier 3 refresh
> 4. All refreshes use incremental mode → only process changes
> 5. Entire cascade completes in seconds/minutes, not hours
>
> **You never have to:**
> - Write orchestration code
> - Manage dependencies manually
> - Schedule jobs in external tools
> - Monitor for failures in the cascade
> - Manually trigger refreshes
>
> **You just deploy the DDL once, and the scheduled refreshes run forever!**"

---

# ═══════════════════════════════════════════════════════════════════════════════
# ACT 2: SERVE & ANALYZE
# ═══════════════════════════════════════════════════════════════════════════════

# DEMO 3: High-Concurrency Serving (Interactive Tables)

## Overview
Demonstrates Interactive Tables and Interactive Warehouses for customer-facing applications requiring consistent sub-100ms query latency under high concurrency (100+ concurrent users).

**Status**: Generally Available (GA since December 11, 2025) - Available in select AWS regions.

## Quick Start

```bash
cd interactive
./demo.sh
```

**What it demonstrates:**
- Real-time pipeline: Data flows from ingestion → transformation → serving (5-minute lag)
- High-concurrency: 10-20x faster queries under load (P95: 80-100ms vs 1-2s)
- Complete native stack: No external cache or API database needed

## Key Demo Points

### Part 1: Real-Time Pipeline (Optional)
```bash
# Generate orders and watch them flow through the pipeline
./demo.sh --enable-realtime --orders 50
```

**Talking points:**
> "We're generating new orders that will appear in our Interactive Tables within minutes. Once there, they're queryable with low latency - fast enough for customer-facing applications."

### Part 2: Concurrent Load Testing
```bash
# Test both warehouses for comparison
./demo.sh --threads 150 --warehouse both
```

**Talking points:**
> "We're simulating concurrent users hitting our API simultaneously - like a busy e-commerce site during peak hours. Interactive warehouses maintain consistent performance under high concurrent load. The key value is consistency and predictability."

### What to Demonstrate

Rather than specific numbers, focus on demonstrating:

| Aspect | What to Show |
|--------|--------------|
| **Consistency** | Run same query multiple times - Interactive shows more predictable latency |
| **Concurrency** | Increase thread count - Interactive handles load better |
| **Scaling** | Compare low vs high concurrency - Interactive maintains performance |

**Note for presenters:** *Actual latency numbers vary by account, region, warehouse size, and data volume. Focus on showing the performance pattern (consistency under load) rather than specific millisecond values.*

**Closing:**
> "This is a complete native Snowflake solution. No Redis for caching, no separate API database, no complex ETL to sync data. Just Snowflake, from ingestion to serving, with production-ready performance at scale."

**See:** `interactive/README.md` for detailed documentation

---

# DEMO 4: Analytics & ML (dbt + GPU Training)

This demo combines batch analytical modeling with GPU-accelerated ML training.

## Part A: dbt Analytics - Batch Analytical Models

## Overview
Demonstrates batch-processed analytical models in Snowflake Workspaces complementing real-time Dynamic Tables. Creates customer lifetime value, segmentation, product affinity, and cohort retention analysis.

## Quick Start

```bash
cd dbt-analytics

# Local development
pip install dbt-snowflake
dbt deps
dbt debug  # Test connection
dbt build  # Build all models

# Snowflake native deployment (alternative)
snow dbt deploy automated_intelligence_dbt_project \
  --connection <your-connection-name> \
  --force

snow dbt execute automated_intelligence_dbt_project \
  --connection <your-connection-name> \
  --args "build --target dev"
```

## Models Created

**Staging** (4 views in `dbt_staging` schema):
- `stg_customers`: Cleaned customer data
- `stg_orders`: Cleaned order data
- `stg_order_items`: Cleaned order item data
- `stg_products`: Cleaned product data

**Customer marts** (2 tables in `dbt_analytics` schema):
- `customer_lifetime_value`: Total revenue, order count, first/last order dates
- `customer_segmentation`: RFM-based segments (high_value, medium_value, low_value, at_risk)

**Product marts** (2 tables):
- `product_affinity`: Market basket analysis - which products are bought together
- `product_recommendations`: Product recommendation scores based on purchase patterns

**Cohort marts** (1 table):
- `monthly_cohorts`: Monthly cohort retention tracking for growth analysis

## Key Demo Points

**Talking points:**
> "DBT complements our real-time Dynamic Tables with deep analytical queries that run on a daily or weekly batch schedule. While Dynamic Tables handle operational dashboards and live metrics with 1-minute refresh, DBT focuses on:
>
> - **Customer Lifetime Value**: Total revenue and order patterns per customer
> - **RFM Segmentation**: Recency, Frequency, Monetary analysis to identify high-value customers
> - **Product Affinity**: Market basket analysis to find products frequently bought together
> - **Cohort Analysis**: Track customer retention by signup month
>
> All models are built with dbt's testing framework - we have data quality tests on uniqueness, not-null constraints, and referential integrity."

### Show Model Results

```sql
-- Customer segmentation distribution
SELECT 
    segment,
    COUNT(*) AS customer_count,
    AVG(total_spent) AS avg_lifetime_value
FROM AUTOMATED_INTELLIGENCE.DBT_ANALYTICS.CUSTOMER_SEGMENTATION
GROUP BY segment
ORDER BY avg_lifetime_value DESC;

-- Top product affinities
SELECT 
    product_a,
    product_b,
    times_purchased_together,
    confidence
FROM AUTOMATED_INTELLIGENCE.DBT_ANALYTICS.PRODUCT_AFFINITY
ORDER BY times_purchased_together DESC
LIMIT 10;

-- Cohort retention
SELECT 
    cohort_month,
    customer_count,
    retained_1_month,
    retained_3_months,
    retention_rate_1_month
FROM AUTOMATED_INTELLIGENCE.DBT_ANALYTICS.MONTHLY_COHORTS
ORDER BY cohort_month DESC
LIMIT 6;
```

## Integration with Real-Time Pipeline

| Layer | Technology | Refresh | Purpose |
|-------|-----------|---------|---------|
| Real-Time | Dynamic Tables | 1-min lag | Operational dashboards, live metrics |
| Analytical | dbt | Daily batch | Deep analytics, ML features, segmentation |

**Closing:**
> "This is how modern data architectures work on Snowflake: Dynamic Tables for real-time operational needs, and dbt for deep analytical processing. Both run natively in Snowflake - no external orchestration needed."

**See:** `dbt-analytics/README.md` for model details and `dbt-analytics/DEPLOYMENT.md` for production deployment

---

## Part B: ML Training - GPU-Accelerated Product Recommendations

## Overview
Demonstrates GPU-accelerated ML model training in Snowflake Workspaces using XGBoost for product recommendations.

## Quick Start

```bash
cd ml-training

# Upload to Snowflake Workspaces:
# 1. Open Snowsight > Projects > Workspaces
# 2. Create or select workspace
# 3. Upload product_recommendation_gpu_workspace.ipynb
# 4. Attach GPU compute pool
# 5. Run all cells
```

## Model Details

**Use Case:** Predict which products customers are likely to purchase

**Features:**
- Customer behavior metrics (total orders, avg order value, recency)
- Product popularity metrics (total sales, avg rating, category)

**Algorithm:** XGBoost with GPU acceleration (`tree_method='gpu_hist'`)

**Training Data:** Millions of customer-product pairs from Interactive Tables

**Model Complexity:** Deep XGBoost trees optimized for accuracy

## Key Demo Points

**Talking points:**
> "We're training a product recommendation model directly in Snowflake using GPU acceleration. The model learns from millions of customer-product interactions stored in our Interactive Tables.
>
> **Key features:**
> - Customer purchase history (recency, frequency, monetary value)
> - Product popularity (sales volume, ratings, category trends)
> 
> **GPU Acceleration:** Training on large datasets is significantly faster with GPU. The `tree_method='gpu_hist'` parameter enables GPU-accelerated training in XGBoost.
>
> **Model Registry:** Once trained, the model is logged to Snowflake Model Registry for version tracking and deployment."

### Show Model Results

```sql
-- Check model in registry
SELECT 
    MODEL_NAME,
    VERSION_NAME,
    CREATED_ON,
    COMMENT
FROM INFORMATION_SCHEMA.MODEL_VERSIONS
WHERE MODEL_NAME = 'PRODUCT_RECOMMENDATION_MODEL'
ORDER BY CREATED_ON DESC;
```

**Expected Results:**
- **Precision**: High accuracy on product recommendations
- **Recall**: Good coverage of products customers want
- **Training time**: Fast training on large datasets with GPU
- **Top features**: Customer purchase history and product popularity

**Integration with Streamlit:**
> "The model metrics and feature importance are visualized in our Streamlit dashboard (ML Insights page). This gives business users visibility into what drives recommendations."

**Production-ready:** Schedule notebook runs for regular retraining as new data arrives.

**See:** `ml-training/README.md` for detailed setup, configuration, and troubleshooting

### Step 4: Deploy as Stored Procedure

After training, deploy the model as a stored procedure for application integration:

```bash
cd ml-training
snow sql -c <your-connection-name> -f product_recommendations_sproc.sql
```

**Test the stored procedure:**

```sql
-- Get recommendations for 2 low-engagement customers
CALL AUTOMATED_INTELLIGENCE.MODELS.GET_PRODUCT_RECOMMENDATIONS(2, 3, 'LOW_ENGAGEMENT');

-- Expected output: Formatted string with customer IDs, products, and purchase probabilities
```

**Key Talking Points:**
> "We've deployed the trained model as a stored procedure that can be called from applications, dashboards, or Cortex Agents.
>
> **Available Customer Segments:**
> - LOW_ENGAGEMENT (3-5 orders): Upsell opportunities
> - HIGH_VALUE_INACTIVE (high spenders, inactive 180+ days): Re-engagement
> - NEW_CUSTOMERS (1-2 orders): Build loyalty
> - AT_RISK (inactive 180+ days): Churn prevention
> - HIGH_VALUE_ACTIVE (active high spenders): Retention
>
> **Formatted Output:** Returns a nicely formatted string (not a table) that's perfect for Cortex Agents and conversational AI applications.
>
> **Deterministic Results:** The procedure ensures consistent recommendations by ordering customers deterministically, making it production-ready for reliable campaign targeting."

**Integration with Cortex Agents:**
```
Agent Tool Definition:
- Function: get_product_recommendations(n_customers, n_products, segment)
- Returns: Formatted recommendations with purchase probabilities
- Use Cases: Conversational product recommendations, targeted marketing campaigns
```

**See:** `ml-training/README.md` for detailed setup, configuration, and troubleshooting

---

# ═══════════════════════════════════════════════════════════════════════════════
# ACT 3: INTELLIGENCE & GOVERNANCE
# ═══════════════════════════════════════════════════════════════════════════════

# DEMO 5: Conversational AI (Snowflake Intelligence)

## Overview
Demonstrates natural language queries with Cortex Agent using semantic models for business terminology mapping and verified query repository (VQR) for accurate answers.

## Quick Start

```bash
cd snowflake-intelligence

# Upload semantic model to stage
snow stage copy business_insights_semantic_model.yaml \
  @AUTOMATED_INTELLIGENCE.RAW.SEMANTIC_MODELS \
  --overwrite -c <your-connection-name>

# Create Cortex Agent (run SQL)
CREATE OR REPLACE CORTEX AGENT AUTOMATED_INTELLIGENCE.SEMANTIC.ORDER_ANALYTICS_AGENT
  SEMANTIC_MODEL = '@AUTOMATED_INTELLIGENCE.RAW.SEMANTIC_MODELS/business_insights_semantic_model.yaml';
```

## Key Features

**Business Terminology:**
- Query with terms like "revenue", "discount rate", "premium customers"
- Semantic model maps business terms to SQL columns

**Verified Query Repository (VQR):**
- Pre-tested SQL patterns for common questions
- Ensures accuracy for frequently asked queries

**Multi-table Joins:**
- Automatic joins across orders, customers, products
- No need to specify table relationships

**Date Intelligence:**
- Handles "this month", "last quarter", "YTD" naturally
- Understands relative time references

## Sample Questions

```
1. "What is our total revenue by customer segment?"
2. "Show me discount impact on order volumes"
3. "Which products are most popular with premium customers?"
4. "What's our average order value trend over time?"
5. "How many orders did we have last month?"
6. "Show revenue by state for the west coast region"
```

## Key Demo Points

**Using the Agent:**

1. Navigate to Snowsight > AI & ML > Snowflake Intelligence
2. Select `ORDER_ANALYTICS_AGENT`
3. Ask questions in natural language
4. Review generated SQL and results

**Talking points:**
> "Snowflake Intelligence brings natural language queries to your data. Business users can ask questions without knowing SQL - the Cortex Agent understands business terminology and generates accurate SQL.
>
> **Semantic Model:** Maps business terms like 'revenue' to actual columns like `total_amount - discount_amount`
>
> **Verified Queries:** Pre-tested SQL patterns ensure accuracy for common questions
>
> **Multi-Source:** Agent can query across orders, customers, products, and metrics automatically
>
> This is how AI democratizes data access - anyone can explore data through conversation."

### Show Generated SQL

**Important:** When demoing, always show the generated SQL to the audience:
- Click "View SQL" in the Snowflake Intelligence UI
- Explain how the agent translated natural language to SQL
- Highlight semantic model mappings

**Closing:**
> "The agent respects all row access policies and security controls - we'll see this in action in the Security & Governance demo next."

**See:** `snowflake-intelligence/README.md` for detailed setup, semantic model customization, and troubleshooting

### Advanced: Custom ML Tools for Agents

**Powerful Feature: Extend agents with trained ML models as conversational tools**

After training the product recommendation model (DEMO 6), integrate it as a custom agent tool:

```bash
# Deploy model as stored procedure (if not done in DEMO 6)
cd ml-training
snow sql -c <your-connection-name> -f product_recommendations_sproc.sql
```

**Agent Tool Definition (example):**
```yaml
tools:
  - type: function
    function:
      name: get_product_recommendations
      description: "ML-powered product recommendations by segment"
      parameters:
        segment:
          type: string
          enum: ["LOW_ENGAGEMENT", "HIGH_VALUE_INACTIVE", "NEW_CUSTOMERS", "AT_RISK"]
      implementation:
        sql: "CALL AUTOMATED_INTELLIGENCE.MODELS.GET_PRODUCT_RECOMMENDATIONS(:n_customers, :n_products, :segment)"
```

**Demo Script:**

**Ask the agent:**
```
"Show me product recommendations for low engagement customers"
"Which products should I recommend to inactive high-value customers?"
"Get 10 at-risk customers with their top 5 product recommendations"
```

**Expected Response:**
```
Product Recommendations for Low Engagement (3-5 orders) Segment
======================================================================

Customer ID: 10045
----------------------------------------------------------------------
  1. Powder Skis (Skis)
     Purchase Probability: 97.1%

Customer ID: 115561
----------------------------------------------------------------------
  1. All-Mountain Skis (Skis)
     Purchase Probability: 90.9%

These recommendations are based on ML predictions from our trained XGBoost 
model, analyzing millions of customer-product interactions.
```

**Talking Points:**
> "This is where Snowflake Intelligence becomes truly powerful - we're not just querying data, we're calling trained ML models through natural language.
>
> **What Just Happened:**
> 1. User asked in plain English
> 2. Agent identified the need for ML predictions
> 3. Called our trained product recommendation model (deployed as stored procedure)
> 4. Returned formatted results with purchase probabilities
>
> **No Code Required:** Business users can access ML insights without knowing:
> - Stored procedure syntax
> - Model deployment details
> - Feature engineering
>
> **Production-Ready:** Same interface works for marketing campaigns, customer service, executive dashboards
>
> This is the future of AI-powered analytics - trained ML models accessible through conversation."

**See:** `snowflake-intelligence/README.md` for complete agent tool integration guide

---

# DEMO 6: Governed AI (Row-Based Access Control)

## Overview
Demonstrates row-based access control (RBAC) using Snowflake Intelligence with region-filtered data views. Same agent, dramatically different answers based on role.

## The Setup

**Two Roles, Dramatically Different Views:**

| Role | States Visible | Revenue | Customers |
|------|---------------|---------|-----------|
| **AUTOMATED_INTELLIGENCE** | All 10 states | $733M | 20,200 |
| **WEST_COAST_MANAGER** | Only CA, OR, WA | $224M | 6,115 |

## Live Demo Script

### Open Snowflake Intelligence in Two Browser Windows

**Window 1 (Admin Role):**
```sql
USE ROLE snowflake_intelligence_admin;
```

**Window 2 (West Coast Manager):**
```sql
USE ROLE west_coast_manager;
```

### Question 1: Total Revenue
**Ask both roles:** "What's our total revenue?"

- **Admin sees:** $733M (100%)
- **West Coast sees:** $224M (31%) ← 69% hidden!

### Question 2: Revenue by State
**Ask both roles:** "Show me revenue by state"

- **Admin sees:** 10 states in chart
- **West Coast sees:** 3 states only (CA, OR, WA)

### Question 3: Top Performing States
**Ask both roles:** "What are our top 3 states by revenue?"

- **Admin sees:** NV ($76M), OR ($75M), CA ($75M)
- **West Coast sees:** OR ($75M), CA ($75M), WA ($73M) - *Doesn't even know NV exists!*

## Key Talking Points

**Transparent Security:**
> "The row access policy is completely transparent to the agent and users. West Coast Manager doesn't know that other regions exist - they're automatically filtered out at the database level. No application code changes needed."

**Natural Language Works:**
> "The agent generates SQL that automatically respects the row access policy. When the West Coast Manager asks for 'total revenue,' they get their region's revenue - the policy filters data before the agent even sees it."

**Production Use Cases:**
- Multi-region sales organizations
- Franchise models
- Multi-brand companies
- Compliance requirements (data residency, privacy regulations)
- Partner networks

**Closing:**
> "This is Snowflake's governance model: security is built into the data platform, not the application layer. One agent serves all roles with appropriate data views, and you maintain a single source of truth."

**See:** `security-and-governance/README.md` for setup and SQL examples

---

# ═══════════════════════════════════════════════════════════════════════════════
# BONUS: OPEN LAKEHOUSE
# ═══════════════════════════════════════════════════════════════════════════════

# DEMO 7: Hybrid OLTP/OLAP (Snowflake Postgres)

## Overview
Demonstrates a Hybrid OLTP/OLAP architecture where Postgres handles transactional writes (product reviews, support tickets) and Snowflake handles analytics with Cortex Search and natural language queries.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    OLTP Layer (Snowflake Postgres)                   │
│  ┌─────────────────────┐ ┌─────────────────────────────────────┐    │
│  │   product_reviews   │ │         support_tickets             │    │
│  │   (transactional    │ │         (transactional              │    │
│  │    writes)          │ │          writes)                    │    │
│  └─────────────────────┘ └─────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
                           │
                           │ MERGE-based Sync (5 min scheduled task)
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    OLAP Layer (Snowflake)                            │
│  ┌─────────────────────┐ ┌─────────────────────────────────────┐    │
│  │ RAW.PRODUCT_REVIEWS │ │    RAW.SUPPORT_TICKETS              │    │
│  └─────────────────────┘ └─────────────────────────────────────┘    │
│                           │                                          │
│                           ▼                                          │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │              Cortex Search Services (SEMANTIC)               │    │
│  │  • product_reviews_search - semantic search over reviews    │    │
│  │  • support_tickets_search - semantic search over tickets    │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                           │                                          │
│                           ▼                                          │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │              Cortex Agent (Snowflake Intelligence)           │    │
│  │  Natural language queries: "What are customers saying about  │    │
│  │  Ski Boots?" or "Show me complaints about shipping"         │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

## Demo Flow

### Step 1: Show the Hybrid Architecture
```sql
-- Postgres has the transactional source
SELECT COUNT(*) AS postgres_reviews 
FROM TABLE(POSTGRES.pg_query('SELECT * FROM product_reviews'));

SELECT COUNT(*) AS postgres_tickets 
FROM TABLE(POSTGRES.pg_query('SELECT * FROM support_tickets'));

-- Snowflake has the synced analytics copy
SELECT COUNT(*) AS snowflake_reviews FROM RAW.PRODUCT_REVIEWS;
SELECT COUNT(*) AS snowflake_tickets FROM RAW.SUPPORT_TICKETS;
```

**What to say:**
> "This is a Hybrid OLTP/OLAP architecture. Postgres handles the transactional writes - when customers submit reviews or support tickets, those go directly to Postgres. Snowflake handles the analytics - the data is synced via a scheduled MERGE task every 5 minutes."

### Step 2: Show the MERGE-based Sync
```sql
-- Check sync task status
SHOW TASKS LIKE 'postgres_sync_task' IN SCHEMA POSTGRES;

-- Manually trigger sync (or wait for scheduled run)
CALL POSTGRES.sync_postgres_to_snowflake();
```

**What to say:**
> "The sync uses MERGE operations - not DELETE+INSERT. This is more realistic for production because it handles inserts, updates, and deletes efficiently. The task runs every 5 minutes, but you can adjust this based on your latency requirements."

### Step 3: Demonstrate Cortex Search
```sql
-- Search product reviews for quality issues
SELECT PARSE_JSON(
    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'AUTOMATED_INTELLIGENCE.SEMANTIC.PRODUCT_REVIEWS_SEARCH',
        '{"query": "quality issues with boots", 
          "columns": ["review_title", "review_text", "rating"], 
          "limit": 5}'
    )
)['results'] AS results;

-- Search support tickets for shipping complaints
SELECT PARSE_JSON(
    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'AUTOMATED_INTELLIGENCE.SEMANTIC.SUPPORT_TICKETS_SEARCH',
        '{"query": "shipping delays and refund", 
          "columns": ["subject", "description", "priority"], 
          "limit": 5}'
    )
)['results'] AS results;
```

**What to say:**
> "Once data is in Snowflake, Cortex Search enables semantic search. I can search for 'quality issues' and it finds reviews mentioning 'disappointed', 'wear and tear', 'cheap materials' - even though those exact words weren't in my query. This is vector-based semantic search, not keyword matching."

### Step 4: Natural Language Queries via Agent (Snowflake Intelligence UI)

Navigate to **AI & ML > Snowflake Intelligence** and ask:

```
"What are customers saying about Ski Boots?"
"Summarize recent complaints about shipping"
"Which products have the most negative feedback?"
"Find support tickets about returns"
```

**What to say:**
> "The Cortex Agent can use these search services as tools. When I ask 'What are customers saying about Ski Boots?', the agent automatically searches through product reviews and summarizes the sentiment. This is conversational AI over your transactional data."

## Key Talking Points

**Why Hybrid OLTP/OLAP?**
> "Postgres excels at high-frequency transactional writes - the kind of workload you get from customer-facing applications. Snowflake excels at analytics, AI, and complex queries. By combining them, you get the best of both worlds without compromising on either."

**Why MERGE-based Sync?**
> "MERGE is more production-realistic than DELETE+INSERT. It efficiently handles all three cases: new records (INSERT), updated records (UPDATE), and deleted records (DELETE). The sync task runs on a schedule - you can adjust the frequency based on your latency requirements."

**Why Cortex Search?**
> "Cortex Search enables semantic search without building your own vector database or embedding pipeline. It automatically indexes the data and provides similarity search. Combined with Cortex Agent, users can query this data in natural language."

## Data Characteristics

| Table | Records | Sentiment Distribution |
|-------|---------|------------------------|
| product_reviews | ~395 | 65% positive, 15% negative, 20% neutral |
| support_tickets | ~500 | 40% positive, 20% negative, 40% neutral |

**See:** `snowflake-postgres/README.md` for detailed setup and architecture

---

# DEMO 8: Iceberg Interoperability (pg_lake)

## Overview
Demonstrates true Open Lakehouse architecture where external systems query Snowflake data via Iceberg format - zero vendor lock-in.

**What is pg_lake?**
> An *external* PostgreSQL instance (not Snowflake Postgres) that reads Iceberg tables directly from S3. This demonstrates how ANY Iceberg-compatible system can access Snowflake data in open formats.

## Setup (one-time)
```bash
cd pg_lake

# Create Iceberg tables, stored procedure, and task in Snowflake
snow sql -c dash-builder-si -f snowflake_export.sql

# Start pg_lake with dynamic Iceberg path discovery
./setup.sh
```

**How it works:**

Two Snowflake Tasks automate the data flow:

| Task | Source → Target | Schedule |
|------|-----------------|----------|
| `POSTGRES_SYNC_TASK` | Snowflake Postgres → RAW tables | 5 min |
| `PG_LAKE_REFRESH_TASK` | RAW tables → Iceberg on S3 | 5 min |

The `setup.sh` script queries Snowflake for latest Iceberg metadata paths, then pg_lake foreign tables point to that metadata on S3.

**Demo Query from external Postgres:**
```bash
# Run demo queries
PGPASSWORD=postgres psql -h localhost -p 5433 -U postgres -d postgres --pset pager=off -f demo_queries.sql
```

```sql
-- Query Snowflake data from external Postgres via Iceberg
SELECT rating, COUNT(*) as count
FROM product_reviews
GROUP BY rating
ORDER BY rating DESC;

-- Verify row counts match Snowflake
SELECT 'product_reviews' as table_name, COUNT(*) FROM product_reviews
UNION ALL
SELECT 'support_tickets', COUNT(*) FROM support_tickets;
```

**Check task status in Snowflake:**
```sql
-- View both tasks
SHOW TASKS LIKE 'POSTGRES_SYNC_TASK' IN SCHEMA AUTOMATED_INTELLIGENCE.POSTGRES;
SHOW TASKS LIKE 'PG_LAKE_REFRESH_TASK' IN SCHEMA AUTOMATED_INTELLIGENCE.PG_LAKE;

-- View task history
SELECT NAME, STATE, SCHEDULED_TIME FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE NAME IN ('POSTGRES_SYNC_TASK', 'PG_LAKE_REFRESH_TASK')
ORDER BY SCHEDULED_TIME DESC LIMIT 5;
```

**What to say:**
> "This is true Open Lakehouse architecture with fully automated data pipelines:
>
> **Two Tasks, Full Automation:**
> - `POSTGRES_SYNC_TASK`: Syncs Snowflake Postgres → RAW tables (every 5 min)
> - `PG_LAKE_REFRESH_TASK`: Syncs RAW → Iceberg on S3 (every 5 min)
>
> **Dynamic path discovery:**
> - The setup script queries Snowflake for current Iceberg metadata paths
> - No hardcoded S3 paths to maintain
> - Just run `./setup.sh` to pick up the latest metadata
>
> **Key benefits:**
> - **Open Data Format:** Iceberg is an open table format - not locked into any vendor
> - **Multi-Engine Analytics:** Same data accessible from Snowflake, Spark, Trino, DuckDB, or any Iceberg-compatible system
> - **No ETL Required:** External systems read directly from S3
> - **True Lakehouse:** Open formats, universal access, governed by Snowflake"

**See:** `pg_lake/README.md` for external Postgres setup and architecture

---

# ═══════════════════════════════════════════════════════════════════════════════
# PARALLEL / BOOKENDS
# ═══════════════════════════════════════════════════════════════════════════════

# OPENER: Cortex Code (AI-Assisted Development)

**Duration:** 5 minutes | **When:** Start of any demo session

**Purpose:** Show how AI accelerates development - "Let me show you how we built this"

## Quick Demo

```bash
cortex -c <your-connection-name>
```

**Sample prompts:**
```
> Show me top 10 customers by total spend
> Create a dbt model for customer churn risk
> Explain what this query does: [paste SQL]
```

**What to say:**
> "Before we dive into the data pipeline, let me show you how we built it. Cortex Code is Snowflake's AI-powered development assistant. I can ask it questions in plain English and it generates production-ready SQL, understands my schema, and even creates dbt models."

---

# PARALLEL: Streamlit Dashboard (Real-Time Monitoring)

**Duration:** Continuous | **When:** Run alongside any demo

## Overview
Real-time pipeline monitoring, performance testing, and ML insights through an interactive Streamlit dashboard.

## Quick Start

```bash
cd streamlit-dashboard
pip install streamlit snowflake-snowpark-python pandas
streamlit run streamlit_app.py --server.port 8501
# Open http://localhost:8501
```

## Dashboard Pages

| Page | Use During | What It Shows |
|------|------------|---------------|
| **Data Pipeline** | Demo 2 (Gen2) | MERGE performance comparison |
| **Live Ingestion** | Demo 1 (Snowpipe) | Real-time order counts |
| **Pipeline Health** | Demo 2 (Dynamic Tables) | Refresh status, lag metrics |
| **Query Performance** | Demo 3 (Interactive) | Latency under concurrency |
| **ML Insights** | Demo 4 (ML Training) | Model metrics, feature importance |

**What to say:**
> "Keep this dashboard open throughout the demo. It provides real-time visibility into our entire data pipeline - you'll see orders appearing as they stream in, transformation health, and query performance metrics."

**See:** `streamlit-dashboard/README.md` for detailed documentation

---

# ═══════════════════════════════════════════════════════════════════════════════
# SQL FEATURES & REFERENCE DEMOS
# ═══════════════════════════════════════════════════════════════════════════════

# Additional SQL Feature Demos

These standalone SQL demos showcase the latest Snowflake SQL capabilities. Each demo is self-contained and can be run independently.

## Overview

| Demo | Feature | Key Syntax | Use Case |
|------|---------|------------|----------|
| **AI SQL Functions** | AI_FILTER, AI_CLASSIFY | `AI_FILTER(col, 'urgent')` | Intelligent data filtering without ML |
| **Semantic Views (SQL)** | SQL-based semantic views | `CREATE SEMANTIC VIEW ... TABLES ... FACTS ... DIMENSIONS` | Text-to-SQL with business terminology |
| **Optima Indexing** | Gen2 automatic indexing | `RESOURCE_CONSTRAINT = 'STANDARD_GEN_2'` | Point lookup optimization |
| **Pipe Operator** | Functional SQL chaining | `source ->> transform1 ->> transform2` | Readable data pipelines |
| **UNION BY NAME** | Schema-evolution-friendly unions | `SELECT ... UNION BY NAME SELECT ...` | Flexible data integration |
| **Time Series Gap-Filling** | RESAMPLE interpolation | `RESAMPLE ... INTERPOLATE_LINEAR()` | IoT/sensor data analysis |
| **ASYNC SQL** | Parallel query execution | `ASYNC (query)` + `AWAIT ALL` | Concurrent ETL operations |
| **Data Quality Expectations** | Data Metric Functions | `CREATE DATA METRIC FUNCTION` | Data quality monitoring |
| **Iceberg Partitioned Writes** | Native Iceberg support | `CREATE ICEBERG TABLE ... PARTITION BY` | Open lakehouse |
| **Cortex Analyst Routing** | Multi-model routing | `routing_mode => 'routing'` | Multi-domain analytics |
| **HuggingFace Import** | ML model import | `CREATE MODEL ... FROM HUGGINGFACE` | Pre-trained model deployment |
| **CREATE OR ALTER** | Idempotent DDL | `CREATE OR ALTER TABLE` | CI/CD-friendly migrations |
| **Performance Explorer** | Query analysis | Account Usage views | Performance optimization |

## File Locations

```
sql-features/
├── pipe_operator_demo.sql           # ->> operator with $1 reference
├── union_by_name_demo.sql           # UNION BY NAME
├── time_series_gap_filling_demo.sql # RESAMPLE and interpolation
├── async_sql_demo.sql               # ASYNC/AWAIT patterns
└── create_or_alter_demo.sql         # Idempotent DDL

ai-sql-demo/
└── ai_filter_demo.sql               # AI_FILTER and AI_CLASSIFY

data-quality/
└── data_quality_expectations_demo.sql   # Data Metric Functions

iceberg/
└── partitioned_writes_demo.sql      # Iceberg partitioning + v3 preview

snowflake-intelligence/
├── semantic_view_sql_demo.sql       # SQL-based semantic views
└── cortex_analyst_routing_demo.sql  # Multi-semantic-model routing

ml-models/
└── huggingface_import_demo.sql      # HuggingFace model import

gen2-warehouse/
└── optima_indexing_demo.sql         # Automatic indexing

monitoring/
└── performance_explorer_reference.sql   # Query performance analysis
```

## Running the Demos

```bash
# Run any demo file
snow sql -f sql-features/pipe_operator_demo.sql -c <your-connection-name>

# Or copy contents to Snowsight worksheet
```

## Demo Highlights

### AI SQL Functions
```sql
-- Filter reviews intelligently without ML training
SELECT * FROM product_reviews
WHERE AI_FILTER(review_text, 'customer is frustrated or disappointed');

-- Classify data into categories
SELECT product_name, AI_CLASSIFY(description, ARRAY['budget', 'premium', 'professional']) AS segment
FROM products;
```

### Pipe Operator (`->>`)
```sql
-- Chain transformations functionally (uses $1 to reference previous result)
SELECT * FROM orders
  ->> WHERE $1.status = 'completed'
  ->> SELECT $1.customer_id, SUM($1.amount) AS total GROUP BY $1.customer_id
  ->> WHERE $1.total > 1000;
```

### Time Series Gap-Filling
```sql
-- Fill missing sensor readings with interpolation
SELECT * FROM sensor_data
  RESAMPLE (timestamp BY INTERVAL '1 hour')
    INTERPOLATE_LINEAR(temperature)
    INTERPOLATE_FFILL(status);
```

### ASYNC SQL (in stored procedures)
```sql
-- Run queries in parallel within stored procedures
LET q1 := ASYNC (SELECT COUNT(*) FROM orders);
LET q2 := ASYNC (SELECT COUNT(*) FROM customers);
LET q3 := ASYNC (SELECT COUNT(*) FROM products);
AWAIT ALL;  -- Wait for all to complete
```

### Semantic Views (SQL-based)
```sql
-- Create semantic view with proper clause order
CREATE SEMANTIC VIEW orders_analytics
  TABLES (orders, customers, products)
  RELATIONSHIPS (orders(customer_id) -> customers(customer_id))
  FACTS (orders: total_amount, quantity)
  DIMENSIONS (customers: segment, region; products: category)
  METRICS (revenue = SUM(total_amount));
```

## When to Use These Features

| Feature | Best For |
|---------|----------|
| AI SQL Functions | Ad-hoc filtering without training models |
| Semantic Views | Self-service analytics with business terms |
| Pipe Operator | Complex ETL with readable code |
| UNION BY NAME | Schema evolution, data lake integration |
| Time Series Gap-Filling | IoT, sensor data, time series analysis |
| ASYNC SQL | Parallel ETL, concurrent data processing |
| Data Quality | Monitoring data pipelines, SLAs |
| Iceberg Partitioning | Open lakehouse, external query engines |
| HuggingFace Import | NLP, computer vision, embeddings |
| CREATE OR ALTER | DevOps, CI/CD, infrastructure-as-code |

**See:** Individual demo files for complete examples with setup, execution, and cleanup.

---

## 🔄 Running Demos Sequentially

### Ingestion to Intelligence (Core Journey)

**Act 1: Ingest & Stage**
1. **Real-Time Ingestion** - Snowpipe Streaming (Python/Java)
2. **Transformation Pipeline** - Gen2 + Dynamic Tables

**Act 2: Serve & Analyze**
3. **High-Concurrency Serving** - Interactive Tables (GA)
4. **Analytics & ML** - dbt + GPU Training

**Act 3: Intelligence & Governance**
5. **Conversational AI** - Snowflake Intelligence
6. **Governed AI** - Row-based access control

✅ **Core journey complete at Demo 6**

**Bonus: Open Lakehouse** (for architecture audiences)
7. **Hybrid OLTP/OLAP** - Snowflake Postgres
8. **Iceberg Interoperability** - pg_lake

**Act 4: Open Lakehouse**
7. **Hybrid OLTP/OLAP** - Snowflake Postgres
8. **Iceberg Interoperability** - pg_lake (external Postgres)

### Notes for Sequential Execution
- ✅ All demos share same base database (`AUTOMATED_INTELLIGENCE`)
- ✅ Schemas: `RAW` (source data), `STAGING` (Gen2 staging), `DYNAMIC_TABLES` (transformations), `INTERACTIVE` (serving), `DBT_STAGING` (dbt staging), `DBT_ANALYTICS` (dbt marts), `SEMANTIC` (semantic layer)
- ✅ Data is additive - each demo adds more orders without breaking others
- ✅ No cleanup needed between demos
- ⚠️ For RBAC demo, switch roles to demonstrate filtering
- ⚠️ For Snowflake Intelligence, use AI & ML > Snowflake Intelligence UI

### Data Growth Tracking
After running all demos, check total data volumes:

```sql
SELECT 
    'customers' AS table_name, 
    COUNT(*) AS row_count 
FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS
UNION ALL
SELECT 'orders', COUNT(*) FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS
UNION ALL
SELECT 'order_items', COUNT(*) FROM AUTOMATED_INTELLIGENCE.RAW.ORDER_ITEMS
UNION ALL
SELECT 'dynamic_table: daily_business_metrics', COUNT(*) 
FROM AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES.DAILY_BUSINESS_METRICS
UNION ALL
SELECT 'interactive: customer_order_analytics', COUNT(*) 
FROM AUTOMATED_INTELLIGENCE.INTERACTIVE.CUSTOMER_ORDER_ANALYTICS
UNION ALL
SELECT 'dbt: customer_lifetime_value', COUNT(*) 
FROM AUTOMATED_INTELLIGENCE.DBT_ANALYTICS.CUSTOMER_LIFETIME_VALUE
ORDER BY table_name;
```

---

## 🎯 Ingestion to Intelligence: Complete

After running demos 1-6, you've demonstrated the full journey:

**Act 1 - Ingest & Stage:**
- ✅ Snowpipe Streaming: Sub-second latency, massive-scale ready
- ✅ Gen2 Warehouses: Faster MERGE/UPDATE + Optima Indexing
- ✅ Dynamic Tables: Incremental refresh, zero maintenance

**Act 2 - Serve & Analyze:**
- ✅ Interactive Tables (GA): Sub-100ms queries, high concurrency
- ✅ dbt Analytics: CLV, segmentation, product affinity
- ✅ GPU Training: XGBoost recommendations, Model Registry

**Act 3 - Intelligence & Governance:**
- ✅ Snowflake Intelligence (GA): Natural language queries
- ✅ Row Access Policies: Transparent security with AI

**Bonus - Open Lakehouse:**
- ✅ Snowflake Postgres: Hybrid OLTP/OLAP
- ✅ Iceberg: Zero vendor lock-in

**The Punchline:**
> *"From raw data streaming in, to business users asking questions in plain English—entirely within Snowflake. That's Ingestion to Intelligence."*

---

## 🧹 Cleanup (After All Demos)

If you want to reset for another demo session:

```sql
-- Optional: Drop and recreate everything
-- (Only run if you want to start fresh)
DROP DATABASE automated_intelligence CASCADE;

-- Remove row access policy
DROP ROW ACCESS POLICY IF EXISTS automated_intelligence.raw.customers_region_policy;

-- Remove roles
DROP ROLE IF EXISTS west_coast_manager;

-- Remove warehouses
DROP WAREHOUSE IF EXISTS automated_intelligence_wh;
DROP WAREHOUSE IF EXISTS automated_intelligence_gen2_wh;
DROP WAREHOUSE IF EXISTS interactive_wh;
```

Or keep the structure and just add more data:

```bash
# Add more orders via Snowpipe Streaming
# See: snowpipe-streaming-java/ or snowpipe-streaming-python/
```

---

## 📚 Additional Resources

### Setup & Configuration
- **Setup Scripts**: `setup/*.sql`
- **Connection Guide**: Snowflake CLI configuration for connections

### Demo Documentation
- **Main README**: `README.md` - Demo overview and quick start
- **This File**: `script.md` - Complete demo guide with talking points
- **Gen2 Warehouses**: `gen2-warehouse/README.md` - Performance testing and benchmarking
- **Interactive Tables**: `interactive/README.md` - Performance deep dive
- **Snowpipe Python**: `snowpipe-streaming-python/README.md`
- **Snowpipe Java**: `snowpipe-streaming-java/README.md`
- **DBT Analytics**: `dbt-analytics/README.md` and `dbt-analytics/DEPLOYMENT.md`
- **ML Training**: `ml-training/README.md` - GPU workspace setup
- **Streamlit Dashboard**: `streamlit-dashboard/README.md` - Deployment and features
- **Snowflake Intelligence**: `snowflake-intelligence/README.md` - Cortex Agent setup
- **RBAC Demo**: `security-and-governance/README.md`

### SQL Features & Reference Demos
- **AI SQL Functions**: `ai-sql-demo/ai_filter_demo.sql` - AI_FILTER, AI_CLASSIFY
- **Semantic Views**: `snowflake-intelligence/semantic_view_sql_demo.sql` - SQL-based creation
- **Pipe Operator**: `sql-features/pipe_operator_demo.sql` - `->>` chaining
- **UNION BY NAME**: `sql-features/union_by_name_demo.sql` - Schema evolution
- **Time Series**: `sql-features/time_series_gap_filling_demo.sql` - RESAMPLE, interpolation
- **ASYNC SQL**: `sql-features/async_sql_demo.sql` - Parallel query execution
- **Data Quality**: `data-quality/data_quality_expectations_demo.sql` - Metric functions
- **Iceberg**: `iceberg/partitioned_writes_demo.sql` - Partitioned tables + v3 preview (deletion vectors, row lineage, default values)
- **HuggingFace**: `ml-models/huggingface_import_demo.sql` - Model import
- **CREATE OR ALTER**: `sql-features/create_or_alter_demo.sql` - Idempotent DDL
- **Performance**: `monitoring/performance_explorer_reference.sql` - Query analysis

### Query Scripts
- **Dynamic Tables**: SQL scripts in `setup/` directory
- **Gen2 Performance**: `gen2-warehouse/setup_merge_procedures.sql`
- **Interactive Performance**: `interactive/demo_interactive_performance.sql`
- **Validation**: Various test and validation SQL files in each directory

---

**Remember: After one-time setup, all demos work independently and can be run in any order!** 🚀
