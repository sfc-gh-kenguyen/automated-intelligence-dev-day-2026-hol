# Agent Guidelines — automated-intelligence

## What This Repo Is

Multi-domain demo monorepo showcasing Snowflake features. Each subdirectory is an independent demo -- they do NOT share code or dependencies.

**Org:** iamontheinet (private repo)

## Architecture

```
setup.sql                      ← Root DDL: creates base objects (AUTOMATED_INTELLIGENCE DB, schemas, etc.)
setup/                         ← Additional setup scripts
ai-sql-demo/                   ← AI SQL features demo
data-quality/                  ← DMF and data quality demos
dbt-analytics/                 ← dbt project
gen2-warehouse/                ← Gen2 warehouse benchmarks
iceberg/                       ← Iceberg tables demo
interactive/                   ← Interactive warehouse demo
ml-models/                     ← ML model registry demos
ml-training/                   ← ML training demos
monitoring/                    ← Monitoring and observability
pg_lake/                       ← Postgres pg_lake demos
security-and-governance/       ← Governance, masking, classification
snowflake-intelligence/        ← Snowflake Intelligence demos
snowflake-mcp-server/          ← MCP server demo
snowflake-postgres/            ← Snowflake Postgres demos
snowpipe-streaming-java/       ← Java Snowpipe streaming
snowpipe-streaming-python/     ← Python Snowpipe streaming
sql-features/                  ← SQL feature demos
streamlit-dashboard/           ← Streamlit apps
talk/                          ← Presentation materials
tests/                         ← Test scripts
workload-identity/             ← Workload identity demos
```

## Critical Rules

1. **Each subdirectory is independent.** No cross-subdir imports, shared utils, or common dependencies. Do not refactor to share code between them.
2. **The Demo Guide kit at `~/Desktop/sfguide-ai-demos-with-cortex-code/` is the canonical demo source.** It has zero dependency on this repo. Do not create cross-references.
3. **Connection:** `dash-builder-si` for local development.
4. **Databases vary by demo:** `AUTOMATED_INTELLIGENCE`, `DASH_DB`, and others depending on the subdirectory.

## When Adding a New Demo

- Create a new subdirectory at the root level
- Include its own setup SQL, README, and any dependencies
- Do not modify `setup.sql` at root unless the new demo needs shared base objects
- Keep it self-contained -- someone should be able to run just that subdirectory
