# Agent Guidelines — automated-intelligence-hol

## What This Repo Is

75-minute hands-on lab showcasing Snowflake's end-to-end data platform — from streaming ingestion to AI-powered analytics. Each subdirectory is an independent exercise.

## Architecture

```
setup.sql                      ← Root DDL: creates all shared infrastructure
ai-sql-demo/                   ← AI SQL functions (AI_FILTER, AI_CLASSIFY)
data-quality/                  ← Data Metric Functions (DMF) demo
dbt-analytics/                 ← dbt project (staging + mart models)
gen2-warehouse/                ← Gen2 warehouse + Optima Indexing
iceberg/                       ← Iceberg partitioned writes
interactive/                   ← Interactive Tables + warehouse
ml-models/                     ← HuggingFace model import
security-and-governance/       ← Row Access Policies (RBAC)
snowflake-intelligence/        ← Cortex Agent + Semantic View
snowpipe-streaming-python/     ← Python Snowpipe Streaming SDK
sql-features/                  ← SQL feature demos (pipe operator, UNION BY NAME, etc.)
streamlit-dashboard/           ← 7-page Streamlit in Snowflake app
tests/                         ← Validation notebooks
```

## Critical Rules

1. **Each subdirectory is independent.** No cross-subdir imports or shared dependencies.
2. **Database:** `DASH_AUTOMATED_INTELLIGENCE_DB` for all exercises.
3. **Role:** `AUTOMATED_INTELLIGENCE_ADMIN` (primary), `WEST_COAST_MANAGER` (RBAC demo).
4. **Warehouses:** `HOL_WH` (standard), `HOL_GEN2_WH` (Gen2), `HOL_INTERACTIVE_WH` (interactive).

## When Editing

- Run `setup.sql` first — it creates all shared objects (tables, dynamic tables, interactive tables, search services, semantic views)
- Component scripts in subdirectories extend the base setup (e.g., `create_agent.sql`, `setup_west_coast_manager.sql`)
- Do not modify `setup.sql` unless changing shared infrastructure
