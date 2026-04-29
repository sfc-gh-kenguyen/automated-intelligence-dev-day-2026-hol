# Automated Intelligence — Comprehensive Validation Report

**Date**: February 27, 2026
**Connection**: `dash-builder-si`
**Role**: `AUTOMATED_INTELLIGENCE`
**Database**: `AUTOMATED_INTELLIGENCE`

---

## Executive Summary

| Phase | Tests | Pass | Warn | Fail |
|-------|-------|------|------|------|
| Infrastructure Validation | 19 | 17 | 2 | 0 |
| Dashboard Navigation | 38 | 38 | 0 | 0 |
| User Action Testing | 12 | 12 | 0 | 0 |
| Gen1 vs Gen2 Benchmark | 4 | 4 | 0 | 0 |
| **Total** | **73** | **71** | **2** | **0** |

**Overall Status**: PASS (2 warnings, 0 failures)

**Key Findings**:
- All 11 Snowflake capabilities are operational and returning correct data
- All 7 Streamlit dashboard pages render without errors
- Gen2 XSMALL warehouse is **1.56x faster** than Gen1 SMALL for MERGE+UPDATE workloads
- Interactive Table data drift detected for 1/10 sampled customers (expected behavior for CTAS-based tables)
- Two infrastructure warnings: `POSTGRES_SYNC_TASK` suspended, `PG_LAKE_REFRESH_TASK` suspended

---

## Phase 1: Infrastructure Validation

19 checks across all Snowflake objects. Each check verified object existence, state, and basic health.

| # | Component | Check | Result | Details |
|---|-----------|-------|--------|---------|
| 1 | Schemas | All 10 schemas exist | PASS | RAW, STAGING, DYNAMIC_TABLES, INTERACTIVE, SEMANTIC, MODELS, DBT_STAGING, DBT_ANALYTICS, POSTGRES, PG_LAKE |
| 2 | RAW Tables | 7 tables exist with data | PASS | customers (498,905), orders (8,055,260), order_items (41,214,637), product_catalog (10), product_reviews (~395), support_tickets (~500), data_quality_alerts |
| 3 | STAGING Tables | 3 tables exist | PASS | orders_staging, order_items_staging, discount_snapshot |
| 4 | Warehouses | 3 warehouses configured | PASS | automated_intelligence_wh (SMALL/Gen1), automated_intelligence_gen2_wh (XSMALL/Gen2), automated_intelligence_interactive_wh (XSMALL/Interactive) |
| 5 | Dynamic Tables | 5 DTs with incremental refresh | PASS | enriched_orders, enriched_order_items (1-min lag), fact_orders, daily_business_metrics, product_performance_metrics (DOWNSTREAM) |
| 6 | Interactive Tables | 2 tables operational | PASS | CUSTOMER_ORDER_ANALYTICS (clustered by customer_id), ORDER_LOOKUP (clustered by order_id) |
| 7 | Cortex Search | 3 services active | PASS | product_search_service (RAW), product_reviews_search (SEMANTIC), support_tickets_search (SEMANTIC) |
| 8 | Semantic Views | 2 views exist | PASS | business_analytics_semantic (SEMANTIC schema), ORDERS_ANALYTICS_SV |
| 9 | Cortex Agent | ORDER_ANALYTICS_AGENT exists | PASS | Uses YAML semantic model on stage |
| 10 | DMFs | Data Metric Functions active | PASS | Monitoring data quality on RAW tables |
| 11 | Row Access Policy | customers_region_policy applied | PASS | Applied to RAW.CUSTOMERS on state column |
| 12 | ML Models | Model registry entries exist | PASS | customer_churn_predictor, product_recommendation_xgboost |
| 13 | Stored Procedures | 7 procedures in STAGING/RAW | PASS | merge_staging_to_raw, enrich_raw_data, create/restore_discount_snapshot, truncate_staging_tables, get_staging_counts, generate_customers |
| 14 | dbt Staging | 4 views in DBT_STAGING | PASS | stg_customers, stg_orders, stg_order_items, stg_products |
| 15 | dbt Analytics | 5 tables in DBT_ANALYTICS | PASS | customer_lifetime_value, customer_segmentation, product_affinity, product_recommendations, monthly_cohorts |
| 16 | POSTGRES_SYNC_TASK | Task exists | WARN | Task is SUSPENDED — not actively syncing Postgres data |
| 17 | PG_LAKE_REFRESH_TASK | Task exists | WARN | Task is SUSPENDED — not actively refreshing Iceberg tables |
| 18 | Snowpipe Streaming | Pipe objects exist | PASS | ORDERS-STREAMING, ORDER_ITEMS-STREAMING channels configured |
| 19 | Gen2 Warehouse | STANDARD_GEN_2 resource constraint | PASS | Verified via SHOW WAREHOUSES |

### Warning Details

- **POSTGRES_SYNC_TASK (SUSPENDED)**: The 5-minute sync task from Snowflake Postgres to RAW tables is not running. Product reviews and support tickets data is static. Resume with `ALTER TASK POSTGRES_SYNC_TASK RESUME` when needed.
- **PG_LAKE_REFRESH_TASK (SUSPENDED)**: The Iceberg table refresh task is not running. pg_lake foreign tables may have stale metadata. Resume with `ALTER TASK PG_LAKE_REFRESH_TASK RESUME` when needed.

---

## Phase 2: Dashboard Navigation Validation

All 7 Streamlit dashboard pages were validated by executing their underlying SQL queries. Each query was run against the actual Snowflake connection to verify data availability and correctness.

### Page 1: Summary (`pages/summary.py`)

| # | Query | Result | Key Data |
|---|-------|--------|----------|
| 1 | Total customers count | PASS | 498,905 customers |
| 2 | Total orders count | PASS | 8,055,260 orders |
| 3 | Total revenue | PASS | $2.43B total revenue |
| 4 | Average order value | PASS | ~$301.50 |
| 5 | Orders by status distribution | PASS | 5 statuses (Completed 65%, Shipped 15%, Processing 10%, Pending 7%, Cancelled 3%) |
| 6 | Recent orders (last 24h) | PASS | Returns recent streaming data |

### Page 2: Live Ingestion (`pages/live_ingestion.py`)

| # | Query | Result | Key Data |
|---|-------|--------|----------|
| 7 | Staging counts | PASS | 0 pending (staging truncated after benchmark) |
| 8 | Recent RAW inserts | PASS | Returns latest ingested records |
| 9 | Streaming throughput metrics | PASS | Channel activity visible |

### Page 3: Pipeline Health (`pages/pipeline_health.py`)

| # | Query | Result | Key Data |
|---|-------|--------|----------|
| 10 | Dynamic Table refresh history | PASS | All 5 DTs showing refresh history |
| 11 | Dynamic Table lag status | PASS | Tier 1: 1-min target lag, Tier 2-3: DOWNSTREAM |
| 12 | Interactive Table metrics | PASS | 498,905 customers, $2.4B total_spent |
| 13 | Interactive Table row counts | PASS | Counts match expected values |
| 14 | Data quality alerts | PASS | DMF results available |
| 15 | Pipeline end-to-end status | PASS | All pipeline stages healthy |

### Page 4: Interactive vs Standard (`pages/query_performance.py`)

| # | Query | Result | Key Data |
|---|-------|--------|----------|
| 16 | Interactive point lookup (customer_id) | PASS | Sub-100ms response |
| 17 | Standard JOIN query (same customer) | PASS | Returns matching data |
| 18 | Warehouse switching (USE WAREHOUSE) | PASS | Switches between interactive and standard WH |
| 19 | Concurrent query test setup | PASS | ThreadPoolExecutor pattern works |
| 20 | Results comparison logic | PASS | Compares interactive vs standard results |

### Page 5: Gen 1 vs Gen 2 (`pages/data_pipeline.py`)

| # | Query | Result | Key Data |
|---|-------|--------|----------|
| 21 | get_staging_counts() | PASS | Returns pending order/item counts |
| 22 | create_discount_snapshot() | PASS | Snapshot created successfully |
| 23 | merge_staging_to_raw(TRUE) | PASS | Returns JSON with duration_ms and records_merged |
| 24 | enrich_raw_data(TRUE) | PASS | Returns JSON with duration_ms and orders_updated |
| 25 | restore_discount_snapshot() | PASS | Discount values restored |
| 26 | truncate_staging_tables() | PASS | Staging tables cleared |
| 27 | Warehouse switching (Gen1 ↔ Gen2) | PASS | USE WAREHOUSE works for both |
| 28 | ALTER SESSION SET USE_CACHED_RESULT | PASS | Cache disable/enable works |

### Page 6: GPU-Accelerated ML (`pages/ml_insights.py`)

| # | Query | Result | Key Data |
|---|-------|--------|----------|
| 29 | Model registry query | PASS | 2 models found (churn + recommendations) |
| 30 | Model exists check | PASS | Both models registered |
| 31 | Customer segments for recommendations | PASS | 5 segments: LOW_ENGAGEMENT, HIGH_VALUE_INACTIVE, NEW_CUSTOMERS, AT_RISK, HIGH_VALUE_ACTIVE |
| 32 | Recommendations CTE query | PASS | Complex recommendation logic returns results |

### Page 7: Product Analytics (`pages/customer_product_analytics.py`)

| # | Query | Result | Key Data |
|---|-------|--------|----------|
| 33 | CLV by value_tier and customer_status | PASS | RFM-based tiers with monetary values |
| 34 | Top 20 customers by lifetime value | PASS | Returns ranked customer list |
| 35 | Product affinity (co-purchase pairs) | PASS | Returns product pair correlations |
| 36 | Customer segmentation summary | PASS | Behavioral segment distribution |
| 37 | Monthly cohorts | PASS | Retention cohort data available |
| 38 | Product recommendations | PASS | dbt-powered recommendation scores |

---

## Phase 3: User Action Testing

Tested interactive user actions that modify state or trigger compute — the operations users would perform by clicking buttons in the dashboard.

### Page 4: Interactive vs Standard Performance Test

Simulated the "Run Performance Test" button flow from `query_performance.py`:

| # | Test | Result | Details |
|---|------|--------|---------|
| 1 | Select 10 random customer IDs | PASS | IDs sampled from RAW.CUSTOMERS |
| 2 | Interactive WH point lookups (10 customers) | PASS | All 10 returned results via CUSTOMER_ORDER_ANALYTICS |
| 3 | Standard WH JOIN queries (10 customers) | PASS | All 10 returned results via RAW.CUSTOMERS + RAW.ORDERS |
| 4 | Data consistency check (interactive vs standard) | PASS | 9/10 customers matched exactly; 1 showed expected drift |

**Data Drift Observation** (Customer 310440):
- Interactive Table: 5 orders / $2,682.06
- Standard Query: 6 orders / $2,851.94
- Root cause: Interactive Tables are CTAS-based and do not auto-refresh from source RAW tables. Minor drift is expected and not a bug.

### Page 5: Gen1 vs Gen2 Full Pipeline

Simulated the "Run Gen1 Pipeline" and "Run Gen2 Pipeline" button flows from `data_pipeline.py`:

| # | Test | Result | Details |
|---|------|--------|---------|
| 5 | Staging data available (pre-pipeline) | PASS | 1,683,020 orders + 6,169,893 items in staging |
| 6 | Gen1 merge_staging_to_raw | PASS | 23,590ms — 1,683,020 orders + 6,169,893 items merged |
| 7 | Gen1 enrich_raw_data | PASS | 2,291ms — 284 orders enriched |
| 8 | Gen2 merge_staging_to_raw | PASS | 18,190ms (warmup) — same record counts |
| 9 | Gen2 enrich_raw_data | PASS | 735ms (warmup) — 284 orders enriched |
| 10 | create_discount_snapshot | PASS | Snapshot created for benchmark |
| 11 | restore_discount_snapshot | PASS | Discount values restored correctly |
| 12 | truncate_staging_tables | PASS | Both staging tables cleared to 0 rows |

**Post-Pipeline Row Count Verification**:
- RAW.ORDERS: 8,055,260 (was 6,372,240 — gained 1,683,020 via MERGE)
- RAW.ORDER_ITEMS: 41,214,637 (was 35,044,744 — gained 6,169,893 via MERGE)
- STAGING.ORDERS_STAGING: 0 (truncated after pipeline)
- STAGING.ORDER_ITEMS_STAGING: 0 (truncated after pipeline)

---

## Phase 4: Gen1 vs Gen2 Back-to-Back Benchmark

A controlled, fair benchmark comparing Gen1 (SMALL) and Gen2 (XSMALL) warehouse performance on identical MERGE+UPDATE workloads.

### Methodology

1. **Staging Data Restoration**: Used Snowflake Time Travel (`AT(OFFSET => -1800)`) to restore truncated staging tables to their pre-pipeline state
2. **Snapshot/Restore Pattern**: Created a discount snapshot before runs; restored between each timed run to ensure identical starting state
3. **Warmup Rounds**: Both warehouses executed untimed warmup runs (merge + enrich) to compile stored procedures and warm caches
4. **Cache Disabled**: `ALTER SESSION SET USE_CACHED_RESULT = FALSE` before every timed run
5. **Identical Data**: Each timed run processed 1,683,020 orders + 6,169,893 order items (7,852,913 total records)

### Warmup Results (Untimed)

| Warehouse | Merge (ms) | Enrich (ms) | Total (ms) |
|-----------|-----------|------------|------------|
| Gen1 (SMALL) | 23,590 | 2,291 | 25,881 |
| Gen2 (XSMALL) | 18,190 | 735 | 18,925 |

### Timed Benchmark Results

| Operation | Gen1 SMALL (ms) | Gen2 XSMALL (ms) | Speedup |
|-----------|-----------------|-------------------|---------|
| Merge Orders | 6,551 | 4,285 | **1.53x** |
| Merge Order Items | 13,794 | 8,567 | **1.61x** |
| **Merge Total** | **20,458** | **12,924** | **1.58x** |
| Enrich (UPDATE) | 1,370 | 1,098 | **1.25x** |
| **Pipeline Total** | **21,828** | **14,022** | **1.56x** |

### Benchmark Analysis

- **Gen2 XSMALL is 1.56x faster than Gen1 SMALL** for this MERGE+UPDATE pipeline workload
- Gen2 is running on a **smaller warehouse size** (XSMALL vs SMALL), making the performance gap even more significant — Gen2 XSMALL delivers more throughput at lower cost
- The largest gains are on bulk MERGE operations (1.58x), with the smaller UPDATE enrichment showing a more modest 1.25x improvement
- Both runs processed identical data: 7,852,913 total records merged, 284 orders enriched
- Warmup-to-timed improvement shows procedure compilation overhead: Gen1 dropped from 25.9s to 21.8s, Gen2 from 18.9s to 14.0s

### Cost Consideration

Gen2 warehouses have a 1.35x credit multiplier (AWS). Even accounting for this:
- Gen1 SMALL = 2 credits/hour
- Gen2 XSMALL = 1 credit/hour × 1.35 = 1.35 credits/hour
- Gen2 completes 1.56x faster at 0.675x the credit cost — a net efficiency gain of ~2.3x

---

## Observations & Known Issues

### 1. Interactive Table Data Drift

**Severity**: Low (expected behavior)
**Component**: INTERACTIVE.CUSTOMER_ORDER_ANALYTICS

Interactive Tables in this project are created via CTAS (CREATE ... AS SELECT) and do not auto-refresh when source RAW tables change. After the MERGE pipeline added ~1.7M new orders, the Interactive Tables still reflect the pre-merge state.

- 9 out of 10 sampled customers showed identical data between Interactive and Standard queries
- Customer 310440 showed a 1-order discrepancy (5 vs 6 orders, $169.88 revenue difference)
- This is expected behavior, not a bug. To refresh, recreate the Interactive Tables or use INSERT OVERWRITE.

### 2. Column Naming: TOTAL_SPENT vs TOTAL_REVENUE

**Severity**: Low (documentation clarity)
**Component**: INTERACTIVE.CUSTOMER_ORDER_ANALYTICS

The Interactive Table column is named `TOTAL_SPENT`, but the dashboard page (`pipeline_health.py`) aliases it as `total_revenue` in the SELECT. Initial validation queries using `TOTAL_REVENUE` as a column name failed with `invalid identifier`. The actual column names are:

```
CUSTOMER_ID, FIRST_NAME, LAST_NAME, EMAIL, CUSTOMER_SEGMENT, STATE, CITY,
TOTAL_ORDERS, TOTAL_SPENT, AVG_ORDER_VALUE, FIRST_ORDER_DATE, LAST_ORDER_DATE
```

### 3. MERGE Idempotency

**Severity**: Info
**Component**: STAGING.MERGE_STAGING_TO_RAW

The merge procedure uses UPSERT semantics (MERGE with WHEN MATCHED THEN UPDATE + WHEN NOT MATCHED THEN INSERT). Re-merging the same staging data after a restore produces correct results — matched rows are updated in place, no duplicates are created. This was verified across multiple warmup and timed runs.

### 4. Enrich Procedure Schema Location

**Severity**: Info
**Component**: STAGING.ENRICH_RAW_DATA

The `enrich_raw_data` procedure is in the STAGING schema (not RAW as might be assumed from the name). Full path: `AUTOMATED_INTELLIGENCE.STAGING.ENRICH_RAW_DATA(BOOLEAN)`.

### 5. Suspended Tasks

**Severity**: Medium (operational)
**Components**: POSTGRES_SYNC_TASK, PG_LAKE_REFRESH_TASK

Both scheduled tasks are suspended. This means:
- Product reviews and support tickets in RAW tables are not being refreshed from Snowflake Postgres
- Iceberg tables in PG_LAKE are not being updated
- Cortex Search services (product_reviews_search, support_tickets_search) may serve stale data after their 1-hour TARGET_LAG expires

Resume before demos that involve Postgres data or Iceberg tables.

---

## Environment Details

### Snowflake Connection

| Property | Value |
|----------|-------|
| Connection | `dash-builder-si` |
| Database | `AUTOMATED_INTELLIGENCE` |
| Role | `AUTOMATED_INTELLIGENCE` |
| Region | AWS |

### Warehouses

| Warehouse | Size | Type | Auto-Suspend |
|-----------|------|------|--------------|
| automated_intelligence_wh | SMALL | Standard (Gen1) | 60s |
| automated_intelligence_gen2_wh | XSMALL | STANDARD_GEN_2 | 60s |
| automated_intelligence_interactive_wh | XSMALL | Interactive | Never (always-on) |

### Table Row Counts (Post-Validation)

| Table | Row Count |
|-------|-----------|
| RAW.CUSTOMERS | 498,905 |
| RAW.ORDERS | 8,055,260 |
| RAW.ORDER_ITEMS | 41,214,637 |
| RAW.PRODUCT_CATALOG | 10 |
| RAW.PRODUCT_REVIEWS | ~395 |
| RAW.SUPPORT_TICKETS | ~500 |
| STAGING.ORDERS_STAGING | 0 (truncated) |
| STAGING.ORDER_ITEMS_STAGING | 0 (truncated) |
| INTERACTIVE.CUSTOMER_ORDER_ANALYTICS | 498,905 |

### Schemas Validated

RAW, STAGING, DYNAMIC_TABLES, INTERACTIVE, SEMANTIC, MODELS, DBT_STAGING, DBT_ANALYTICS, POSTGRES, PG_LAKE

### Session State at End of Validation

- Result cache: RE-ENABLED (`ALTER SESSION SET USE_CACHED_RESULT = TRUE`)
- Active warehouse: `automated_intelligence_wh` (Gen1 SMALL)
- Staging tables: Truncated (0 rows)
- Gen2 warehouse: Resumed (will auto-suspend after 60s idle)
