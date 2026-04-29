---
name: demo
description: "Interactive step-by-step demo controller for the Automated Intelligence suite. Walks through any combination of 8 demos + SQL features organized by Act. Menu-driven with audience presets. Use when: running a demo, presenting features, interactive walkthrough, step by step demo, show a specific feature, audience demo. Triggers: demo, interactive demo, step by step, walkthrough, present, show me demo, run demo interactively, demo menu, audience demo, act 1, act 2, act 3, demo 1, demo 2, demo 3, demo 4, demo 5, demo 6, demo 7, demo 8."
---

# Automated Intelligence — Interactive Demo Controller

An interactive, menu-driven demo for the full Ingestion-to-Intelligence platform. Pick any demo, run it step by step, skip around freely.

## Connection & Context

- **Connection**: `dash-builder-si`
- **Database**: `AUTOMATED_INTELLIGENCE`
- **Role**: `AUTOMATED_INTELLIGENCE` (switch to `WEST_COAST_MANAGER` for Demo 6)
- **Always use fully qualified names**: `AUTOMATED_INTELLIGENCE.SCHEMA.TABLE`

## Workflow

### Step 1: Show the Demo Menu

Present this menu and ask which demo (or audience preset) to run:

```
INGESTION TO INTELLIGENCE — Demo Menu
======================================

  PREFLIGHT  — Verify all infrastructure is healthy

  ACT 1: INGEST & STAGE
    Demo 1 — Snowpipe Streaming (10-15 min)
    Demo 2 — Gen2 MERGE + Dynamic Tables (20-25 min)

  ACT 2: SERVE & ANALYZE
    Demo 3 — Interactive Tables (10-15 min)
    Demo 4 — dbt Analytics + ML Training (20-25 min)

  ACT 3: INTELLIGENCE & GOVERNANCE
    Demo 5 — Cortex Agent + Search (10-15 min)
    Demo 6 — Row Access Policy / Governed AI (10-15 min)

  BONUS: OPEN LAKEHOUSE
    Demo 7 — Snowflake Postgres (10-15 min)
    Demo 8 — Iceberg / pg_lake (10-15 min)

  EXTRAS
    SQL Features — 13 standalone SQL demos
    Streamlit Dashboard — Real-time monitoring

  AUDIENCE PRESETS
    Executives    → Demos 1-6 (60 min)
    Data Engineers → Demos 1-4 (55 min)
    ML Engineers  → Demos 3-4 (35 min)
    Architects    → Demos 1-8 (80 min)
    Quick (15 min)→ Demos 1 + 5

Pick a demo number, preset, or "preflight" to start.
```

### Step 2: Run the Selected Demo

Follow the step-by-step instructions for the chosen demo below. Between each step:
1. Execute the SQL and present results clearly
2. Show the **talking point** for that step
3. **Wait** for the presenter to say "next", "continue", or "skip" before advancing
4. After each demo completes, return to the menu

When the presenter says "next step" or "continue" — advance one step. When they say "next demo" — skip to the next demo number. When they say "menu" or "back" — show the menu again.

---

## PREFLIGHT

Run these checks and report status:

```sql
-- 1. Warehouses
SHOW WAREHOUSES LIKE 'AUTOMATED_INTELLIGENCE%';
ALTER WAREHOUSE automated_intelligence_wh RESUME IF SUSPENDED;

-- 2. Schemas (expect 10)
SELECT SCHEMA_NAME FROM AUTOMATED_INTELLIGENCE.INFORMATION_SCHEMA.SCHEMATA
WHERE SCHEMA_NAME NOT IN ('INFORMATION_SCHEMA', 'PUBLIC') ORDER BY SCHEMA_NAME;

-- 3. Dynamic Tables (expect 5, all ACTIVE)
SELECT name, target_lag, refresh_mode, scheduling_state
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLES())
WHERE SCHEMA_NAME = 'DYNAMIC_TABLES' ORDER BY name;

-- 4. Data baseline
SELECT 'CUSTOMERS' as tbl, COUNT(*) as rows FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS
UNION ALL SELECT 'ORDERS', COUNT(*) FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS
UNION ALL SELECT 'ORDER_ITEMS', COUNT(*) FROM AUTOMATED_INTELLIGENCE.RAW.ORDER_ITEMS
UNION ALL SELECT 'PRODUCT_CATALOG', COUNT(*) FROM AUTOMATED_INTELLIGENCE.RAW.PRODUCT_CATALOG;
```

Summarize health. Flag any issues. Wait for presenter before continuing.

---

## DEMO 1: Snowpipe Streaming

**Theme**: Real-time ingestion, sub-60s latency, linear horizontal scaling.

**Step 1** — Show current data:
```sql
SELECT 'RAW.ORDERS' as tbl, COUNT(*) as rows FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS
UNION ALL SELECT 'RAW.ORDER_ITEMS', COUNT(*) FROM AUTOMATED_INTELLIGENCE.RAW.ORDER_ITEMS;
```

**Step 2** — Stream 1,000 orders (Python SDK):
```bash
cd /Users/ddesai/Apps/automated-intelligence/snowpipe-streaming-python && python src/automated_intelligence_streaming.py 1000
```
> **Say**: "We're streaming orders directly into Snowflake. No Kafka, no S3 landing zone. The Python SDK is Rust-backed for high performance — we've benchmarked 34K orders/sec across 10 parallel instances."

**Step 3** — Verify data arrived (wait ~60s for `max.client.lag`):
```sql
SELECT 'RAW.ORDERS' as tbl, COUNT(*) as rows FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS
UNION ALL SELECT 'RAW.ORDER_ITEMS', COUNT(*) FROM AUTOMATED_INTELLIGENCE.RAW.ORDER_ITEMS;
```

**Step 4** — Check channel history:
```sql
SELECT CHANNEL_NAME, TABLE_NAME, LAST_COMMITTED_TIME, STATUS
FROM SNOWFLAKE.ACCOUNT_USAGE.SNOWPIPE_STREAMING_CHANNEL_HISTORY
WHERE TABLE_DATABASE = 'AUTOMATED_INTELLIGENCE' AND TABLE_SCHEMA = 'RAW'
ORDER BY LAST_COMMITTED_TIME DESC LIMIT 5;
```
> **Say**: "Each parallel instance gets unique channels. Exactly-once delivery, automatic offset management. Pick Python or Java — identical functionality."

---

## DEMO 2: Gen2 MERGE + Dynamic Tables

### Part A: Gen2 Performance

**Step 1** — Stream to staging:
```bash
cd /Users/ddesai/Apps/automated-intelligence/snowpipe-streaming-python && python src/automated_intelligence_streaming.py 5000 staging
```

**Step 2** — Verify staging data:
```sql
CALL AUTOMATED_INTELLIGENCE.STAGING.GET_STAGING_COUNTS();
```

**Step 3** — Snapshot for fair comparison:
```sql
CALL AUTOMATED_INTELLIGENCE.STAGING.CREATE_DISCOUNT_SNAPSHOT();
```

**Step 4** — Timed Gen1 run:
```sql
USE WAREHOUSE automated_intelligence_wh;
ALTER SESSION SET USE_CACHED_RESULT = FALSE;
CALL AUTOMATED_INTELLIGENCE.STAGING.MERGE_STAGING_TO_RAW(TRUE);
```

**Step 5** — Restore + Timed Gen2 run:
```sql
CALL AUTOMATED_INTELLIGENCE.STAGING.RESTORE_DISCOUNT_SNAPSHOT();
USE WAREHOUSE automated_intelligence_gen2_wh;
CALL AUTOMATED_INTELLIGENCE.STAGING.MERGE_STAGING_TO_RAW(TRUE);
```
> **Say**: "Same SQL, different engine. Gen2 XSMALL beats Gen1 SMALL. Factor in the 1.35x credit multiplier and you still save money because the job finishes faster on smaller compute."

**Step 6** — Clean up:
```sql
CALL AUTOMATED_INTELLIGENCE.STAGING.TRUNCATE_STAGING_TABLES();
USE WAREHOUSE automated_intelligence_wh;
ALTER SESSION SET USE_CACHED_RESULT = TRUE;
```

### Part B: Dynamic Tables

**Step 7** — Show the 3-tier pipeline:
```sql
SELECT name, target_lag, refresh_mode, scheduling_state
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLES())
WHERE SCHEMA_NAME = 'DYNAMIC_TABLES' ORDER BY name;
```
> **Say**: "Five Dynamic Tables in 3 tiers. Tier 1 refreshes every minute — incremental, only changed rows. Tiers 2-3 use DOWNSTREAM lag — they auto-refresh when parents complete. No orchestrator. No DAG. Just SQL."

**Step 8** — Show data flowing through:
```sql
SELECT 'Tier 1: enriched_orders' as layer, COUNT(*) as rows
FROM AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES.ENRICHED_ORDERS
UNION ALL SELECT 'Tier 2: fact_orders', COUNT(*)
FROM AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES.FACT_ORDERS
UNION ALL SELECT 'Tier 3: daily_metrics', COUNT(*)
FROM AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES.DAILY_BUSINESS_METRICS;
```

**Step 9** — Show refresh history (prove incremental):
```sql
SELECT name, refresh_action, state,
       DATEDIFF('second', refresh_start_time, refresh_end_time) as seconds
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
    NAME_PREFIX => 'AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES'))
ORDER BY data_timestamp DESC LIMIT 10;
```
> **Say**: "Look at refresh_action: INCREMENTAL. Only changed rows processed. As data grows to millions, refresh still takes seconds."

---

## DEMO 3: Interactive Tables

**Step 1** — Pick a random customer:
```sql
SELECT customer_id FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS ORDER BY RANDOM() LIMIT 1;
```

**Step 2** — Interactive Table lookup (use customer_id from Step 1):
```sql
USE WAREHOUSE automated_intelligence_interactive_wh;
SELECT customer_id, first_name, last_name, customer_segment,
       total_orders, total_spent, avg_order_value
FROM AUTOMATED_INTELLIGENCE.INTERACTIVE.CUSTOMER_ORDER_ANALYTICS
WHERE customer_id = <CUSTOMER_ID>;
```
> **Say**: "Sub-50 milliseconds. That's your API response time. Interactive Tables are clustered by the lookup key and served from always-on compute."

**Step 3** — Same query on standard warehouse (for comparison):
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
> **Say**: "Same answer, 10-50x slower. Interactive Tables are your serving layer — APIs, dashboards, real-time apps. Standard warehouses are for analytics. Different tools, same platform."

**Step 4** — Reset warehouse:
```sql
USE WAREHOUSE automated_intelligence_wh;
```

---

## DEMO 4: dbt Analytics + ML

### Part A: dbt Analytics

**Step 1** — Customer Lifetime Value:
```sql
SELECT value_tier, customer_status, COUNT(*) as customers,
       ROUND(AVG(total_revenue), 2) as avg_revenue
FROM AUTOMATED_INTELLIGENCE.DBT_ANALYTICS.CUSTOMER_LIFETIME_VALUE
GROUP BY value_tier, customer_status ORDER BY avg_revenue DESC;
```
> **Say**: "RFM scoring — recency, frequency, monetary value. Every customer gets a tier and a status. This feeds the ML churn model and marketing campaigns."

**Step 2** — Product Affinity (co-purchase pairs):
```sql
SELECT * FROM AUTOMATED_INTELLIGENCE.DBT_ANALYTICS.PRODUCT_AFFINITY
ORDER BY pair_count DESC LIMIT 10;
```
> **Say**: "Market basket analysis via self-join on order items. Powder Skis + Ski Boots is the top pair. This drives the recommendation engine."

**Step 3** — Customer Segmentation:
```sql
SELECT behavioral_segment, COUNT(*) as customers, segment_priority
FROM AUTOMATED_INTELLIGENCE.DBT_ANALYTICS.CUSTOMER_SEGMENTATION
GROUP BY behavioral_segment, segment_priority ORDER BY segment_priority;
```

**Step 4** — Monthly Cohorts:
```sql
SELECT * FROM AUTOMATED_INTELLIGENCE.DBT_ANALYTICS.MONTHLY_COHORTS
ORDER BY cohort_month DESC LIMIT 6;
```

### Part B: ML Models

**Step 5** — Show Model Registry:
```sql
SHOW MODELS IN SCHEMA AUTOMATED_INTELLIGENCE.MODELS;
```
> **Say**: "Two models: churn predictor (Ray cluster, CPU) and product recommendations (single GPU, XGBoost gpu_hist). Both in Snowflake Model Registry — versioned, tracked, deployable."

**Step 6** — Call recommendation stored procedure:
```sql
CALL AUTOMATED_INTELLIGENCE.MODELS.GET_PRODUCT_RECOMMENDATIONS(2, 3, 'LOW_ENGAGEMENT');
```
> **Say**: "The recommendation model runs as an SPCS service. This stored procedure wraps it for application integration. Five customer segments available: LOW_ENGAGEMENT, HIGH_VALUE_INACTIVE, NEW_CUSTOMERS, AT_RISK, HIGH_VALUE_ACTIVE."

---

## DEMO 5: Cortex Agent + Search

**Step 1** — Natural language query via Cortex Agent:
```sql
SELECT SNOWFLAKE.CORTEX.AGENT(
  'AUTOMATED_INTELLIGENCE.SEMANTIC.BUSINESS_INSIGHTS_AGENT',
  'What are the top 5 states by total revenue?'
);
```
> **Say**: "Plain English to SQL to results. The semantic view maps business terms to actual columns. No prompt engineering, no fine-tuning."

**Step 2** — Try another question:
```sql
SELECT SNOWFLAKE.CORTEX.AGENT(
  'AUTOMATED_INTELLIGENCE.SEMANTIC.BUSINESS_INSIGHTS_AGENT',
  'Show me revenue by customer segment with average order value'
);
```

**Step 3** — Cortex Search (product reviews):
```sql
SELECT * FROM TABLE(
  SNOWFLAKE.CORTEX.SEARCH(
    'AUTOMATED_INTELLIGENCE.SEMANTIC.PRODUCT_REVIEWS_SEARCH',
    'ski boot comfort issues', 5));
```
> **Say**: "Vector-based semantic search over product reviews. It finds 'fit problems' and 'pressure points' even though I searched for 'comfort issues'. Auto-refreshes as new reviews flow in."

**Step 4** — Cortex Search (support tickets):
```sql
SELECT * FROM TABLE(
  SNOWFLAKE.CORTEX.SEARCH(
    'AUTOMATED_INTELLIGENCE.SEMANTIC.SUPPORT_TICKETS_SEARCH',
    'shipping delay refund', 5));
```

---

## DEMO 6: Row Access Policy / Governed AI

**Step 1** — Full access (admin):
```sql
USE ROLE AUTOMATED_INTELLIGENCE;
SELECT state, COUNT(*) as customers, ROUND(SUM(o.total_amount), 2) as revenue
FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS c
JOIN AUTOMATED_INTELLIGENCE.RAW.ORDERS o ON c.customer_id = o.customer_id
GROUP BY state ORDER BY revenue DESC;
```
> **Say**: "Admin sees all 10 states — full revenue picture."

**Step 2** — Restricted access (West Coast):
```sql
USE ROLE WEST_COAST_MANAGER;
SELECT state, COUNT(*) as customers, ROUND(SUM(o.total_amount), 2) as revenue
FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS c
JOIN AUTOMATED_INTELLIGENCE.RAW.ORDERS o ON c.customer_id = o.customer_id
GROUP BY state ORDER BY revenue DESC;
```
> **Say**: "Same query, same table, same SQL. Three states: CA, OR, WA. The West Coast Manager doesn't even know other states exist. Security is invisible — and that's the point."

**Step 3** — Agent with restricted role (if time permits):
```sql
SELECT SNOWFLAKE.CORTEX.AGENT(
  'AUTOMATED_INTELLIGENCE.SEMANTIC.BUSINESS_INSIGHTS_AGENT',
  'What are the top 3 states by revenue?'
);
```
> **Say**: "Same agent, different answers. The row access policy cascades through JOINs, views, Dynamic Tables, and AI agents. Zero application code changes."

**Step 4** — Switch back:
```sql
USE ROLE AUTOMATED_INTELLIGENCE;
```

---

## DEMO 7: Snowflake Postgres

**Step 1** — Show Postgres data via PG_QUERY UDTF:
```sql
SELECT COUNT(*) as postgres_reviews
FROM TABLE(AUTOMATED_INTELLIGENCE.RAW.PG_QUERY('SELECT * FROM product_reviews'));
SELECT COUNT(*) as snowflake_reviews FROM AUTOMATED_INTELLIGENCE.RAW.PRODUCT_REVIEWS;
```
> **Say**: "Postgres handles transactional writes — customer reviews, support tickets. Snowflake handles analytics. Data syncs via MERGE every 5 minutes."

**Step 2** — Check sync task:
```sql
SHOW TASKS LIKE 'POSTGRES_SYNC_TASK' IN SCHEMA AUTOMATED_INTELLIGENCE.RAW;
```

**Step 3** — Cortex Search over synced data:
```sql
SELECT * FROM TABLE(
  SNOWFLAKE.CORTEX.SEARCH(
    'AUTOMATED_INTELLIGENCE.SEMANTIC.PRODUCT_REVIEWS_SEARCH',
    'quality issues with boots', 5));
```
> **Say**: "Transactional data in Postgres becomes searchable via Cortex Search in Snowflake. No external vector DB. Write in Postgres, search in Snowflake."

---

## DEMO 8: Iceberg / pg_lake

**Step 1** — Show Iceberg tables:
```sql
SHOW ICEBERG TABLES IN SCHEMA AUTOMATED_INTELLIGENCE.PG_LAKE;
```

**Step 2** — Show refresh task:
```sql
SHOW TASKS LIKE 'PG_LAKE_REFRESH_TASK' IN SCHEMA AUTOMATED_INTELLIGENCE.PG_LAKE;
```

**Step 3** — Run pg_lake queries from external Postgres:
```bash
PGPASSWORD=postgres psql -h localhost -p 5433 -U postgres -d postgres --pset pager=off -c \
  "SELECT rating, COUNT(*) as count FROM product_reviews GROUP BY rating ORDER BY rating DESC;"
```
> **Say**: "This is an external Postgres reading Snowflake data via Iceberg on S3. Any Iceberg-compatible engine works — Spark, Trino, DuckDB. Zero vendor lock-in. Open formats, universal access, governed by Snowflake."

---

## SQL FEATURES (Extras)

Ask which SQL feature to demo. Available options:

| Feature | File |
|---------|------|
| AI_FILTER / AI_CLASSIFY | `ai-sql-demo/ai_filter_demo.sql` |
| Pipe Operator (`->>`) | `sql-features/pipe_operator_demo.sql` |
| UNION BY NAME | `sql-features/union_by_name_demo.sql` |
| Time Series Gap-Filling | `sql-features/time_series_gap_filling_demo.sql` |
| ASYNC SQL | `sql-features/async_sql_demo.sql` |
| CREATE OR ALTER | `sql-features/create_or_alter_demo.sql` |
| Semantic Views | `snowflake-intelligence/semantic_view_sql_demo.sql` |
| Optima Indexing | `gen2-warehouse/optima_indexing_demo.sql` |

Read the selected file and execute its SQL statements step by step.

---

## Stopping Points

- After every SQL execution — wait for "next" or "continue"
- After each demo completes — return to menu
- If presenter says "skip" — jump to next step or demo
- If presenter says "menu" or "back" — show the full menu

## Column Reference (for ad-hoc queries)

- **customers**: `customer_id`, `first_name`, `last_name`, `state`, `customer_segment` (values: `'Premium'`, `'Standard'`, `'Basic'`)
- **orders**: `order_id` (VARCHAR/UUID), `customer_id`, `order_date`, `order_status` (`'Completed'`, `'Shipped'`, `'Processing'`, `'Pending'`, `'Cancelled'`), `total_amount`, `discount_percent`, `shipping_cost`
- **order_items**: `order_item_id`, `order_id`, `product_id`, `product_name`, `product_category` (`'Skis'`, `'Snowboards'`, `'Boots'`, `'Accessories'`), `quantity`, `unit_price`, `line_total`
- **customer_lifetime_value**: `customer_id`, `total_revenue`, `total_orders`, `avg_order_value`, `value_tier` (`'high_value'`, `'medium_value'`, `'low_value'`), `customer_status` (`'active'`, `'at_risk'`, `'churned'`)
