---
name: run-demo
description: "Set up and run the Automated Intelligence end-to-end demo. Walks through all 11 Snowflake capabilities: Snowpipe Streaming, Gen2 warehouses, Dynamic Tables, Interactive Tables, Cortex Search, Cortex Agent, Semantic Views, Row Access Policy, ML Model Registry, dbt analytics, and Streamlit dashboard. Use when: running the full demo, setting up the demo, walking through the platform, showcasing capabilities. Triggers: run demo, setup demo, demo walkthrough, show platform, end-to-end demo, start demo, run the demo, walk me through, showcase."
---

# Automated Intelligence — End-to-End Demo

Run the full Automated Intelligence data platform demo. Each section demonstrates a Snowflake capability with live queries. Sections are self-contained — you can skip or re-run any section.

## Connection & Context

- **Connection**: `dash-builder-si`
- **Database**: `AUTOMATED_INTELLIGENCE`
- **Role**: `AUTOMATED_INTELLIGENCE`
- **Always use fully qualified names**: `AUTOMATED_INTELLIGENCE.SCHEMA.TABLE`

## Workflow

Present each section's results clearly. Between sections, pause and wait for the presenter to say "next" or "continue" before advancing.

---

### Preflight: Verify Infrastructure

**Goal**: Confirm all components are operational before starting.

**Actions**:

1. **Check warehouses** — resume if suspended:
```sql
SHOW WAREHOUSES LIKE 'AUTOMATED_INTELLIGENCE%';
ALTER WAREHOUSE automated_intelligence_gen2_wh RESUME IF SUSPENDED;
ALTER WAREHOUSE automated_intelligence_interactive_wh RESUME IF SUSPENDED;
```

2. **Check schemas** (expect 10: RAW, STAGING, DYNAMIC_TABLES, INTERACTIVE, SEMANTIC, MODELS, DBT_STAGING, DBT_ANALYTICS, POSTGRES, PG_LAKE):
```sql
SHOW SCHEMAS IN DATABASE AUTOMATED_INTELLIGENCE;
```

3. **Check Dynamic Tables** (expect 5, all INCREMENTAL, ACTIVE):
```sql
SELECT name, target_lag, refresh_mode, scheduling_state
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLES())
WHERE SCHEMA_NAME = 'DYNAMIC_TABLES' ORDER BY name;
```

4. **Check tasks** — resume if suspended and Postgres demo is needed:
```sql
SHOW TASKS LIKE 'POSTGRES_SYNC_TASK' IN SCHEMA AUTOMATED_INTELLIGENCE.RAW;
SHOW TASKS LIKE 'PG_LAKE_REFRESH_TASK' IN SCHEMA AUTOMATED_INTELLIGENCE.PG_LAKE;
```

5. **Check data baseline**:
```sql
SELECT 'CUSTOMERS' as tbl, COUNT(*) as rows FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS
UNION ALL SELECT 'ORDERS', COUNT(*) FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS
UNION ALL SELECT 'ORDER_ITEMS', COUNT(*) FROM AUTOMATED_INTELLIGENCE.RAW.ORDER_ITEMS
UNION ALL SELECT 'PRODUCT_CATALOG', COUNT(*) FROM AUTOMATED_INTELLIGENCE.RAW.PRODUCT_CATALOG;
```

6. **Report status** — summarize health and any issues.

**⚠️ MANDATORY STOP**: Present preflight results. Wait for presenter to say "next" or "continue".

---

### Section 1: Real-Time Ingestion (Snowpipe Streaming)

**Goal**: Show data streaming into Snowflake in real-time.

**Actions**:

1. **Check current staging counts**:
```sql
CALL AUTOMATED_INTELLIGENCE.STAGING.GET_STAGING_COUNTS();
```

2. **Stream a small batch** (1,000 orders) via Python SDK:
```bash
cd /Users/ddesai/Apps/automated-intelligence/snowpipe-streaming-python && python src/automated_intelligence_streaming.py 1000 staging
```
Note: Data becomes visible after ~60 seconds (`max.client.lag`).

3. **Show data arriving** — poll staging counts:
```sql
CALL AUTOMATED_INTELLIGENCE.STAGING.GET_STAGING_COUNTS();
-- Expected: ~1,000 orders, ~3,000-4,000 order items in staging
```

4. **Talking points**:
   - Snowpipe Streaming SDK (Python/Java) — no external Kafka or message queue
   - High-performance Rust-core architecture — up to 10 GB/s per table
   - RSA key-pair authentication, parallel channels for scaling
   - Data lands in STAGING, ready for Gen2 MERGE pipeline

**⚠️ MANDATORY STOP**: Wait for "next" or "continue".

---

### Section 2: Gen2 Pipeline (MERGE Performance)

**Goal**: Show Gen2 warehouse advantage over Gen1 for MERGE/UPDATE operations.

**Actions**:

1. **Verify staging has data**:
```sql
CALL AUTOMATED_INTELLIGENCE.STAGING.GET_STAGING_COUNTS();
-- If staging is empty, either stream data first (Section 1) or restore via Time Travel:
-- INSERT INTO AUTOMATED_INTELLIGENCE.STAGING.ORDERS_STAGING
--   SELECT * FROM AUTOMATED_INTELLIGENCE.STAGING.ORDERS_STAGING AT(OFFSET => -1800);
-- INSERT INTO AUTOMATED_INTELLIGENCE.STAGING.ORDER_ITEMS_STAGING
--   SELECT * FROM AUTOMATED_INTELLIGENCE.STAGING.ORDER_ITEMS_STAGING AT(OFFSET => -1800);
```

2. **Create discount snapshot** (preserves pre-merge state for fair comparison):
```sql
CALL AUTOMATED_INTELLIGENCE.STAGING.CREATE_DISCOUNT_SNAPSHOT();
```

3. **Warm both warehouses** (compile procedures, untimed):
```sql
-- Gen1 warmup
USE WAREHOUSE automated_intelligence_wh;
ALTER SESSION SET USE_CACHED_RESULT = FALSE;
CALL AUTOMATED_INTELLIGENCE.STAGING.MERGE_STAGING_TO_RAW(TRUE);
CALL AUTOMATED_INTELLIGENCE.STAGING.ENRICH_RAW_DATA(TRUE);

-- Restore snapshot for Gen2 warmup
CALL AUTOMATED_INTELLIGENCE.STAGING.RESTORE_DISCOUNT_SNAPSHOT();

-- Gen2 warmup
USE WAREHOUSE automated_intelligence_gen2_wh;
ALTER SESSION SET USE_CACHED_RESULT = FALSE;
CALL AUTOMATED_INTELLIGENCE.STAGING.MERGE_STAGING_TO_RAW(TRUE);
CALL AUTOMATED_INTELLIGENCE.STAGING.ENRICH_RAW_DATA(TRUE);
```

4. **Timed Gen1 run**:
```sql
CALL AUTOMATED_INTELLIGENCE.STAGING.RESTORE_DISCOUNT_SNAPSHOT();
USE WAREHOUSE automated_intelligence_wh;
ALTER SESSION SET USE_CACHED_RESULT = FALSE;
CALL AUTOMATED_INTELLIGENCE.STAGING.MERGE_STAGING_TO_RAW(TRUE);
-- Capture: total_duration_ms from JSON result
CALL AUTOMATED_INTELLIGENCE.STAGING.ENRICH_RAW_DATA(TRUE);
-- Capture: duration_ms from JSON result
```

5. **Timed Gen2 run**:
```sql
CALL AUTOMATED_INTELLIGENCE.STAGING.RESTORE_DISCOUNT_SNAPSHOT();
USE WAREHOUSE automated_intelligence_gen2_wh;
ALTER SESSION SET USE_CACHED_RESULT = FALSE;
CALL AUTOMATED_INTELLIGENCE.STAGING.MERGE_STAGING_TO_RAW(TRUE);
-- Capture: total_duration_ms from JSON result
CALL AUTOMATED_INTELLIGENCE.STAGING.ENRICH_RAW_DATA(TRUE);
-- Capture: duration_ms from JSON result
```

6. **Compare results** — calculate speedup: `gen1_total / gen2_total`. Present a comparison table.

7. **Clean up**:
```sql
CALL AUTOMATED_INTELLIGENCE.STAGING.TRUNCATE_STAGING_TABLES();
USE WAREHOUSE automated_intelligence_wh;
ALTER SESSION SET USE_CACHED_RESULT = TRUE;
```

8. **Talking points**:
   - Gen2 XSMALL vs Gen1 SMALL — smaller warehouse, faster results
   - Optimized for MERGE/UPDATE/DELETE (DML-heavy workloads)
   - `RESOURCE_CONSTRAINT = 'STANDARD_GEN_2'` — one-line change
   - Optima Indexing — automatic, no configuration
   - 1.35x credit multiplier offset by speed gains = net cost savings

**⚠️ MANDATORY STOP**: Wait for "next" or "continue".

---

### Section 3: Dynamic Tables (Incremental Transformation)

**Goal**: Show 3-tier incremental pipeline with automatic refresh.

**Actions**:

1. **Show DT pipeline status**:
```sql
SELECT name, target_lag, refresh_mode, scheduling_state,
       data_timestamp, last_completed_refresh_state
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLES())
WHERE SCHEMA_NAME = 'DYNAMIC_TABLES'
ORDER BY name;
```

2. **Show data flowing through tiers**:
```sql
-- Tier 1: Enriched (1-min lag)
SELECT COUNT(*) as enriched_orders FROM AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES.ENRICHED_ORDERS;

-- Tier 2: Facts (DOWNSTREAM)
SELECT COUNT(*) as fact_orders FROM AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES.FACT_ORDERS;

-- Tier 3: Metrics (DOWNSTREAM)
SELECT * FROM AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES.DAILY_BUSINESS_METRICS
ORDER BY metric_date DESC LIMIT 5;

SELECT * FROM AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES.PRODUCT_PERFORMANCE_METRICS
LIMIT 10;
```

3. **Show refresh history**:
```sql
SELECT name, state, refresh_trigger,
       DATEDIFF('second', refresh_start_time, refresh_end_time) as refresh_seconds
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY())
WHERE SCHEMA_NAME = 'DYNAMIC_TABLES'
ORDER BY refresh_start_time DESC
LIMIT 10;
```

4. **Talking points**:
   - Declarative SQL — write the query, Snowflake handles refresh
   - Incremental mode — only changed rows reprocessed
   - 3-tier pattern: enriched → fact → metrics
   - DOWNSTREAM lag — child tables refresh automatically after parent
   - No orchestrator, no scheduler, no DAG — just SQL

**⚠️ MANDATORY STOP**: Wait for "next" or "continue".

---

### Section 4: Interactive Tables (Sub-100ms Lookups)

**Goal**: Compare Interactive Table point lookups vs standard warehouse JOINs.

**Actions**:

1. **Pick a random customer**:
```sql
SELECT customer_id FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS
ORDER BY RANDOM() LIMIT 1;
```

2. **Interactive Table lookup** (use the customer_id from above):
```sql
USE WAREHOUSE automated_intelligence_interactive_wh;
SELECT customer_id, first_name, last_name, customer_segment,
       total_orders, total_spent, avg_order_value
FROM AUTOMATED_INTELLIGENCE.INTERACTIVE.CUSTOMER_ORDER_ANALYTICS
WHERE customer_id = <CUSTOMER_ID>;
-- Note the sub-100ms response time
```

3. **Same query on standard warehouse**:
```sql
USE WAREHOUSE automated_intelligence_wh;
SELECT c.customer_id, c.first_name, c.last_name, c.customer_segment,
       COUNT(o.order_id) as total_orders,
       ROUND(SUM(o.total_amount), 2) as total_spent,
       ROUND(AVG(o.total_amount), 2) as avg_order_value
FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS c
JOIN AUTOMATED_INTELLIGENCE.RAW.ORDERS o ON c.customer_id = o.customer_id
WHERE c.customer_id = <CUSTOMER_ID>
GROUP BY c.customer_id, c.first_name, c.last_name, c.customer_segment;
```

4. **Compare latencies** — Interactive should be 10-50x faster for point lookups.

5. **Switch back**:
```sql
USE WAREHOUSE automated_intelligence_wh;
```

6. **Talking points**:
   - CLUSTER BY key enables sub-100ms lookups
   - 5-second hard query timeout — purpose-built for serving, not analytics
   - Always-on compute — no cold start, no resume delay
   - Ideal for APIs, dashboards, real-time applications

**⚠️ MANDATORY STOP**: Wait for "next" or "continue".

---

### Section 5: Cortex Intelligence (AI-Powered Analytics)

**Goal**: Show natural language queries, semantic search, and semantic views.

**Actions**:

1. **Cortex Agent** — natural language to SQL:
```sql
SELECT SNOWFLAKE.CORTEX.AGENT(
  'AUTOMATED_INTELLIGENCE.SEMANTIC.ORDER_ANALYTICS_AGENT',
  'What are the top 5 states by total revenue?'
);
```

2. **Cortex Search** — unstructured product review search:
```sql
SELECT *
FROM TABLE(
  SNOWFLAKE.CORTEX.SEARCH(
    'AUTOMATED_INTELLIGENCE.SEMANTIC.PRODUCT_REVIEWS_SEARCH',
    'ski boot comfort issues',
    5
  )
);
```

3. **Cortex Search** — support ticket search:
```sql
SELECT *
FROM TABLE(
  SNOWFLAKE.CORTEX.SEARCH(
    'AUTOMATED_INTELLIGENCE.SEMANTIC.SUPPORT_TICKETS_SEARCH',
    'shipping delay refund',
    5
  )
);
```

4. **Semantic View** — structured business analytics:
```sql
SELECT * FROM AUTOMATED_INTELLIGENCE.SEMANTIC.BUSINESS_ANALYTICS_SEMANTIC
LIMIT 10;
```

5. **Talking points**:
   - Cortex Agent: YAML semantic model → natural language → SQL → results
   - Cortex Search: vector search over unstructured text, auto-refreshing
   - Semantic Views: curated business definitions for reliable analytics
   - All three run inside Snowflake — no external LLM or vector DB

**⚠️ MANDATORY STOP**: Wait for "next" or "continue".

---

### Section 6: Security (Row Access Policy)

**Goal**: Show transparent row-level security — same queries, different results based on role.

**Actions**:

1. **Full access as AUTOMATED_INTELLIGENCE**:
```sql
USE ROLE AUTOMATED_INTELLIGENCE;
SELECT state, COUNT(*) as customers
FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS
GROUP BY state ORDER BY customers DESC;
-- Shows all 10 states
```

2. **Restricted access as WEST_COAST_MANAGER**:
```sql
USE ROLE WEST_COAST_MANAGER;
SELECT state, COUNT(*) as customers
FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS
GROUP BY state ORDER BY customers DESC;
-- Shows only CA, OR, WA
```

3. **Demonstrate cascade through JOINs**:
```sql
-- Still as WEST_COAST_MANAGER
SELECT c.state, COUNT(DISTINCT o.order_id) as orders, ROUND(SUM(o.total_amount), 2) as revenue
FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS c
JOIN AUTOMATED_INTELLIGENCE.RAW.ORDERS o ON c.customer_id = o.customer_id
GROUP BY c.state ORDER BY revenue DESC;
-- Only West Coast orders visible — policy cascades through JOINs
```

4. **Switch back**:
```sql
USE ROLE AUTOMATED_INTELLIGENCE;
```

5. **Talking points**:
   - Row Access Policy on CUSTOMERS table, `state` column
   - `CURRENT_ROLE()` check — zero application code changes
   - Cascades through JOINs, views, Dynamic Tables, and Cortex Agent
   - Same agent, same question, different answers per role
   - `ELSE FALSE` — secure default denies unmatched roles

**⚠️ MANDATORY STOP**: Wait for "next" or "continue".

---

### Section 7: ML & Analytics

**Goal**: Show ML Model Registry and dbt-powered analytics.

**Actions**:

1. **Model Registry** — show registered models:
```sql
SHOW MODELS IN SCHEMA AUTOMATED_INTELLIGENCE.MODELS;
```

2. **dbt Analytics — Customer Lifetime Value**:
```sql
SELECT value_tier, customer_status, COUNT(*) as customers,
       ROUND(AVG(total_revenue), 2) as avg_revenue,
       ROUND(AVG(total_orders), 2) as avg_orders
FROM AUTOMATED_INTELLIGENCE.DBT_ANALYTICS.CUSTOMER_LIFETIME_VALUE
GROUP BY value_tier, customer_status
ORDER BY avg_revenue DESC;
```

3. **dbt Analytics — Customer Segmentation**:
```sql
SELECT behavioral_segment, COUNT(*) as customers, segment_priority
FROM AUTOMATED_INTELLIGENCE.DBT_ANALYTICS.CUSTOMER_SEGMENTATION
GROUP BY behavioral_segment, segment_priority
ORDER BY segment_priority;
```

4. **dbt Analytics — Product Affinity** (co-purchase pairs):
```sql
SELECT * FROM AUTOMATED_INTELLIGENCE.DBT_ANALYTICS.PRODUCT_AFFINITY
ORDER BY pair_count DESC LIMIT 10;
```

5. **dbt Analytics — Monthly Cohorts**:
```sql
SELECT * FROM AUTOMATED_INTELLIGENCE.DBT_ANALYTICS.MONTHLY_COHORTS
ORDER BY cohort_month DESC LIMIT 10;
```

6. **Talking points**:
   - Model Registry: versioned ML models (churn + recommendations) with built-in inference
   - dbt: 4 staging views → 5 mart tables, deployed via `EXECUTE DBT PROJECT`
   - RFM scoring for CLV, behavioral segmentation, product co-purchase analysis
   - All transformations in SQL — no external compute needed

**⚠️ MANDATORY STOP**: Wait for "next" or "continue".

---

### Teardown

**Goal**: Clean up demo state.

**Actions**:

1. **Reset session**:
```sql
USE ROLE AUTOMATED_INTELLIGENCE;
USE WAREHOUSE automated_intelligence_wh;
ALTER SESSION SET USE_CACHED_RESULT = TRUE;
```

2. **Truncate staging** (if data was streamed):
```sql
CALL AUTOMATED_INTELLIGENCE.STAGING.TRUNCATE_STAGING_TABLES();
```

3. **Optionally suspend warehouses** to stop billing:
```sql
-- Only if not running another demo soon:
ALTER WAREHOUSE automated_intelligence_gen2_wh SUSPEND;
-- Interactive WH bills continuously — suspend if done for the day:
-- ALTER WAREHOUSE automated_intelligence_interactive_wh SUSPEND;
```

4. **Optionally suspend tasks**:
```sql
-- If Postgres sync is not needed:
-- ALTER TASK AUTOMATED_INTELLIGENCE.RAW.POSTGRES_SYNC_TASK SUSPEND;
-- ALTER TASK AUTOMATED_INTELLIGENCE.PG_LAKE.PG_LAKE_REFRESH_TASK SUSPEND;
```

---

## Stopping Points

- ✋ After Preflight — confirm infrastructure is healthy
- ✋ After each Section (1-7) — presenter controls pacing
- ✋ Before Teardown — confirm cleanup is desired

**Resume rule**: When presenter says "next", "continue", or "go", proceed to the next section without re-asking.

## Notes

- All procedures are in the **STAGING** schema: `AUTOMATED_INTELLIGENCE.STAGING.*`
- Interactive Table column is `TOTAL_SPENT` (not `TOTAL_REVENUE`)
- Gen2 benchmark requires staging data — stream first or restore via Time Travel
- WEST_COAST_MANAGER role must exist (created by `security-and-governance/setup_west_coast_manager.sql`)
- Dynamic Tables use scheduled refresh — manual `ALTER DYNAMIC TABLE ... REFRESH` does NOT cascade to DOWNSTREAM tables
