# Gen2 Warehouse + Optima Indexing

## Purpose

Demonstrates Gen2 warehouse capabilities:
1. **MERGE performance** — Deduplicate and upsert from STAGING into RAW tables
2. **Optima Indexing** — Automatic partition pruning on point lookups (zero config)

## Prerequisites

- Core `setup.sql` already run (creates Gen2 warehouse + staging tables)
- Data streamed into STAGING tables via Snowpipe Streaming

## Usage

### MERGE from Staging to RAW

```sql
USE WAREHOUSE automated_intelligence_gen2_wh;

-- Run the MERGE procedure (returns timing info)
CALL dash_automated_intelligence_db.staging.merge_staging_to_raw(TRUE);
```

### Optima Indexing Demo

```sql
-- See optima_indexing_demo.sql for full walkthrough
USE WAREHOUSE automated_intelligence_gen2_wh;

-- Point lookup — check query profile for partitions_scanned vs partitions_total
SELECT customer_id, first_name, last_name, customer_segment
FROM dash_automated_intelligence_db.raw.customers
WHERE customer_id = 5000;
```

## Files

- `optima_indexing_demo.sql` — Optima Indexing demonstration with query history analysis

## Key Concepts

- Gen2 warehouses created with `GENERATION = '2'`
- Optima Indexing is automatic — no DDL, no configuration, no extra cost
- Best observed via query profile: look for low `partitions_scanned` vs high `partitions_total`
- MERGE procedures are defined in root `setup.sql` (STAGING schema)
