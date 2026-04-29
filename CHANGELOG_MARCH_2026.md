# Automated Intelligence - March 2026 Updates

Tracking document for all changes made based on Snowflake feature releases through March 20, 2026.

---

## Summary of Changes

| # | Priority | File(s) | Change | Status |
|---|----------|---------|--------|--------|
| 1 | CRITICAL | `snowflake-intelligence/create_agent.sql` (NEW) | Create agent using new `CREATE AGENT` API with tools | Done |
| 2 | HIGH | `snowflake-intelligence/cortex_agent_routing_demo.sql` (NEW) | Replace fictional routing demo with working agent routing | Done |
| 3 | HIGH | `snowflake-intelligence/create_postgres_search_services.sql`, `setup.sql` | Upgrade Cortex Search to multi-index syntax | Done |
| 4 | HIGH | `snowflake-intelligence/semantic_view_sql_demo.sql` | Update "Preview" label to "GA March 2026" | Done |
| 5 | MEDIUM | `setup.sql` | Gen2 warehouse: `RESOURCE_CONSTRAINT` → `GENERATION` | Done |
| 6 | MEDIUM | `setup.sql` | Fix stale Dynamic Tables comment | Done |
| 7 | MEDIUM | `security-and-governance/setup_west_coast_manager.sql` | Row access policy: `CURRENT_ROLE()` → `IS_ROLE_IN_SESSION()` | Done |
| 8 | LOW | `snowpipe-streaming-python/requirements.txt` | Pin correct SDK package names and versions | Done |

---

## Detailed Changes

### 1. CRITICAL: New Cortex Agent API (`create_agent.sql`)

**Why:** The old `CREATE CORTEX AGENT ... SEMANTIC_MODEL = '@stage/file.yaml'` syntax is deprecated.
The new `CREATE AGENT ... FROM SPECIFICATION $$ YAML $$` API supports multiple tool types
and natively routes across them. The agent SQL file was referenced in the README but never
existed — this creates it properly.

**What changed:**
- Created `snowflake-intelligence/create_agent.sql` with new API
- Agent wires up 3 tool types:
  - `cortex_analyst_text_to_sql` → `business_analytics_semantic` semantic view
  - `cortex_search` → `product_reviews_search` + `support_tickets_search`
  - `data_to_chart` → auto-visualization
- References semantic view (not YAML on stage) per new best practices

**Snowflake release:** CREATE AGENT API (GA, replaces CREATE CORTEX AGENT)

---

### 2. HIGH: Agent Routing Demo (replaces `cortex_analyst_routing_demo.sql`)

**Why:** The old file contained 100% placeholder/fictional code. `CORTEX ANALYST ROUTER`
never existed as a Snowflake object. The new Agent API handles routing natively — when an
agent has multiple tools, it automatically routes questions to the right tool.

**What changed:**
- Deleted `cortex_analyst_routing_demo.sql`
- Created `cortex_agent_routing_demo.sql` with working examples showing:
  - How the agent routes between text-to-SQL and search tools
  - Python SDK usage with the new agent API
  - Demo queries that exercise each tool type

**Snowflake release:** CREATE AGENT API (GA)

---

### 3. HIGH: Cortex Search Multi-Index Syntax

**Why:** The old `ON column` syntax creates a single text index. The new multi-index syntax
(GA March 12, 2026) supports separate TEXT and VECTOR indexes, scoring configuration, and
dynamic filters — significantly better search quality.

**What changed:**
- `create_postgres_search_services.sql`: Both search services updated to `TEXT INDEXES ... VECTOR INDEXES ...`
- `setup.sql` line 1035: `product_search_service` updated to multi-index syntax

**Snowflake release:** Cortex Search multi-index (GA March 12, 2026)

---

### 4. HIGH: Semantic View Standard SQL Querying — GA Label

**Why:** Standard SQL querying of semantic views went GA on March 2, 2026. The demo file
incorrectly labels it as "Preview Jan 2026".

**What changed:**
- `semantic_view_sql_demo.sql` line 116: "Preview Jan 2026" → "GA March 2026"

**Snowflake release:** Semantic view standard SQL querying (GA March 2, 2026)

---

### 5. MEDIUM: Gen2 Warehouse Syntax

**Why:** `RESOURCE_CONSTRAINT = 'STANDARD_GEN_2'` was the preview syntax. The GA syntax
(since July 2025) uses `GENERATION = '2'` — cleaner and documented as the standard.

**What changed:**
- `setup.sql` line 340: `RESOURCE_CONSTRAINT = 'STANDARD_GEN_2'` → `GENERATION = '2'`

**Snowflake release:** Gen2 Warehouses (GA July 2025)

---

### 6. MEDIUM: Dynamic Tables Stale Comment

**Why:** Comment at line 592 says "Target Lag: 12 hours" but the actual DDL uses
`TARGET_LAG = '1 minute'`. Misleading for anyone reading the code.

**What changed:**
- `setup.sql` line 592: Updated comment to match actual target lag

**Snowflake release:** N/A (documentation accuracy fix)

---

### 7. MEDIUM: Row Access Policy — `IS_ROLE_IN_SESSION()`

**Why:** `CURRENT_ROLE()` only checks the active primary role. `IS_ROLE_IN_SESSION()` checks
the full role hierarchy (including secondary roles), which is the recommended pattern for
row access policies. Without this, users who activate the role as a secondary role get
filtered out incorrectly.

**What changed:**
- `setup_west_coast_manager.sql` line 50-54: Replaced `CURRENT_ROLE() IN (...)` checks
  with `IS_ROLE_IN_SESSION(...)` calls

**Snowflake release:** IS_ROLE_IN_SESSION() (recommended best practice)

---

### 8. LOW: SDK Version Pins

**Why:** The Python Snowpipe Streaming requirements.txt references `snowpipe-streaming>=1.2.0`
which is not the correct PyPI package name. The actual package is `snowflake-ingest`.

**What changed:**
- `snowpipe-streaming-python/requirements.txt`: Updated package names and minimum versions

---

## Not Changed (and why)

| Item | Reason |
|------|--------|
| `setup_mcp_server.sql` | Already uses GENERIC tool type — current |
| Notebook references | Main README/Streamlit already say "Workspaces" |
| `business_insights_semantic_model.yaml` | Still valid; agent references semantic view instead |
| Iceberg features | Additive demos, not updates to existing code |
| Dynamic Tables new functions | Existing DTs work fine; MIN_BY/MAX_BY are additive |
