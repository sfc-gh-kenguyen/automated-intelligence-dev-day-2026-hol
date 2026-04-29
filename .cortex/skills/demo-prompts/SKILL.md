---
name: demo-prompts
description: "Demo prompts for Cortex Code presentation — 7 prompts across L100/L200/L300 covering SQL, AI functions, Streamlit, code review, dbt pipelines, Cortex Agents, Semantic Views, and MCP. Use when: running demos, showing capabilities, presenting Cortex Code, walking through examples, showcasing features. Triggers: demo prompts, presentation, show demo, run demo, start demo, prompt, walkthrough, showcase, show me the demo, let's demo, demo time, demo-prompts."
---

# Cortex Code Demo Prompts

Run these prompts in order for a 10-15 minute demo. L100 (basic), L200 (intermediate), L300 (advanced).

## Project Root

**Always start from**: `/Users/ddesai/Apps/automated-intelligence`

## Connection & Database Context

**CRITICAL**: Always use the `AUTOMATED_INTELLIGENCE` database in all SQL queries.

### SQL Query Format Rules

**CORRECT** - Always use AUTOMATED_INTELLIGENCE.SCHEMA.TABLE format:
```sql
SELECT * FROM AUTOMATED_INTELLIGENCE.RAW.customers;
SELECT * FROM AUTOMATED_INTELLIGENCE.DBT_ANALYTICS.customer_lifetime_value;
```

**WRONG** - Never omit the database name:
```sql
-- NEVER DO THIS:
SELECT * FROM RAW.customers;
SELECT * FROM DBT_ANALYTICS.customer_lifetime_value;
```

Always use fully qualified names: `AUTOMATED_INTELLIGENCE.SCHEMA.TABLE`.

### Available Schemas & Tables

| Schema | Key Tables |
|--------|------------|
| `RAW` | `customers`, `orders`, `order_items`, `product_catalog`, `product_reviews`, `support_tickets` |
| `DYNAMIC_TABLES` | `enriched_orders`, `fact_orders`, `daily_business_metrics`, `product_performance_metrics` |
| `INTERACTIVE` | `customer_order_analytics`, `order_lookup` |
| `DBT_ANALYTICS` | `customer_lifetime_value`, `customer_segmentation`, `product_affinity`, `product_recommendations`, `monthly_cohorts` |
| `SEMANTIC` | `BUSINESS_ANALYTICS_SEMANTIC` (semantic view), `BUSINESS_INSIGHTS_AGENT`, `AI_BUSINESS_AGENT` (agents), `PRODUCT_REVIEWS_SEARCH`, `SUPPORT_TICKETS_SEARCH` (search services) |

### Reference SQL Files (DO NOT search - use these exact paths)

| Prompt | Reference File | What to Use |
|--------|---------------|-------------|
| 2 | `ai-sql-demo/ai_filter_demo.sql` | AI_FILTER + AI_CLASSIFY patterns |
| 3 | `streamlit-dashboard/shared.py` | Streamlit connection pattern |
| 4 | `snowpipe-streaming-python/src/automated_intelligence_streaming.py`, `snowpipe-streaming-python/src/snowpipe_streaming_manager.py` | Read both in parallel, then review |
| 5 | None — all context is in this skill | Generate directly from the project context below |
| 6 | None — all syntax is in this skill | Generate and execute directly |
| 7 | None — all syntax is in this skill | Generate and execute directly |

### Streamlit Connection Pattern (for Prompt 3)

**IMPORTANT**: Use `st.connection("snowflake")` for LOCAL development. The `get_active_session()` method ONLY works when deployed to Snowflake's native Streamlit environment.

**CRITICAL**: `st.connection("snowflake")` requires a `.streamlit/secrets.toml` in the working directory (the directory you `cd` into before running `streamlit run`). Create `demo-output/.streamlit/secrets.toml` with:
```toml
[connections.snowflake]
connection_name = "dash-builder-si"
```
Then launch with `cd demo-output && streamlit run clv_dashboard.py` (NOT from the project root).

**CORRECT - For local development (use this for demos):**
```python
import streamlit as st

# Connect to Snowflake (works locally via default connection)
conn = st.connection("snowflake")

# Query CLV data
df = conn.query("""
    SELECT customer_id, total_revenue, total_orders, 
           avg_order_value, value_tier, customer_status
    FROM AUTOMATED_INTELLIGENCE.DBT_ANALYTICS.customer_lifetime_value
    ORDER BY total_revenue DESC
""")
```

**WRONG - Only works when deployed to Snowflake Streamlit:**
```python
# DO NOT USE THIS FOR LOCAL DEMOS - will cause error:
# "SnowparkSessionException: No default Session is found"
from snowflake.snowpark.context import get_active_session
session = get_active_session()  # FAILS locally!
```

### Exact Column Names (use these exactly)

**RAW.customers:**
```
customer_id INT, first_name VARCHAR, last_name VARCHAR, email VARCHAR, phone VARCHAR, 
address VARCHAR, city VARCHAR, state VARCHAR(2), zip_code VARCHAR, registration_date DATE, 
customer_segment VARCHAR  -- NOTE: column is "customer_segment" NOT "segment"
```

**customer_segment values (CASE-SENSITIVE):** `'Premium'`, `'Standard'`, `'Basic'`

**RAW.orders:**
```
order_id VARCHAR, customer_id INT, order_date TIMESTAMP, order_status VARCHAR,  -- NOTE: "order_status" NOT "status"
total_amount DECIMAL, discount_percent DECIMAL, shipping_cost DECIMAL  -- NOTE: "discount_percent" NOT "discount_amount"
```

**order_status values (CASE-SENSITIVE):** `'Completed'`, `'Pending'`, `'Shipped'`, `'Cancelled'`, `'Processing'`
- Use `'Completed'` NOT `'completed'`
- Use `'Pending'` NOT `'pending'`

**RAW.order_items:**
```
order_item_id VARCHAR, order_id VARCHAR, product_id INT, product_name VARCHAR, 
product_category VARCHAR, quantity INT, unit_price DECIMAL, line_total DECIMAL
```

**product_category values (CASE-SENSITIVE):** `'Skis'`, `'Snowboards'`, `'Boots'`, `'Accessories'`

**product_name values:** `'Powder Skis'`, `'All-Mountain Skis'`, `'Freestyle Snowboard'`, `'Freeride Snowboard'`, `'Ski Boots'`, `'Snowboard Boots'`, `'Ski Poles'`, `'Ski Goggles'`, `'Snowboard Bindings'`, `'Ski Helmet'`

**state values:** `'CO'`, `'UT'`, `'WY'`, `'CA'`, `'WA'`, `'OR'`, `'MT'`, `'ID'`, `'NV'`, `'BC'`

**RAW.product_reviews:**
```
review_id INT, product_id INT, customer_id INT, review_date DATE, rating INT,
review_title VARCHAR, review_text VARCHAR
```

**RAW.support_tickets:**
```
ticket_id INT, customer_id INT, created_date TIMESTAMP, subject VARCHAR,
description VARCHAR, priority VARCHAR, status VARCHAR, resolution_date TIMESTAMP
```

**DBT_ANALYTICS.customer_lifetime_value:**
```
customer_id, total_revenue, total_orders, avg_order_value, customer_status, value_tier
```

**value_tier values (lowercase):** `'high_value'`, `'medium_value'`, `'low_value'`, `'no_purchases'`

**customer_status values (lowercase):** `'active'`, `'at_risk'`, `'churned'`, `'never_purchased'`

**DBT_ANALYTICS.customer_segmentation:**
```
customer_id, behavioral_segment, segment_priority, recommended_action
```

**behavioral_segment values (lowercase):** `'champions'`, `'loyal_customers'`, `'potential_loyalists'`, `'promising'`, `'at_risk'`, `'cant_lose_them'`, `'hibernating_high_value'`, `'lost'`, `'new_customers'`, `'needs_attention'`

## Prompt List

**Prompts can be run in any order**, except prompt 7 which depends on prompt 6.

| # | Persona | Level | Prompt | Working Directory | Dependencies |
|---|---------|-------|--------|-------------------|-------------|
| 1 | Data Analyst | L100 | Show me monthly revenue trends with month-over-month growth rates for the last 6 months | (root) | None |
| 2 | Data Scientist | L200 | Find product reviews that mention quality issues and classify whether the reviewer sounds frustrated, neutral, or appreciative | (root) | None |
| 3 | Developer | L200 | Generate a Streamlit dashboard that visualizes customer lifetime value metrics | `streamlit-dashboard/` | None |
| 4 | Developer | L200 | Help me review my Snowpipe Streaming Python code for exponential backoff | (root) | None |
| 5 | Analyst | L200 | Create a dbt pipeline for customer churn analysis and show me the DAG | (root) | None |
| 6 | AI/Analytics Engineer | L300 | Create a semantic layer over our orders, customers, and product tables with business metrics and natural language synonyms, then build a search service over product reviews, and wire both into an AI agent that answers business questions and searches reviews | (root) | None |
| 7 | Platform Engineer | L300 | Set up a gateway that lets external AI tools like Claude, Cursor, and GPT query our data and search reviews, then register it with Cursor | (root) | **Prompt 6** |

### Dependency Rules

- **Prompt 7 → Prompt 6 (hard)**: The MCP server references the semantic view, search service, and agent created in prompt 6. If prompt 6 hasn't been run yet, **run prompt 6 first automatically** before prompt 7, and tell the audience: "This one builds on the agent we just created — let me set that up first."
- **All other prompts**: Fully independent. Can be run in any order, skipped, or repeated.

## Directory Mapping

Before executing each prompt, **automatically change to the correct directory**:

| Prompt | Directory | Full Path |
|--------|-----------|-----------|
| 1 | Project root | `/Users/ddesai/Apps/automated-intelligence` |
| 2 | Project root | `/Users/ddesai/Apps/automated-intelligence` |
| 3 | streamlit-dashboard | `/Users/ddesai/Apps/automated-intelligence/streamlit-dashboard` |
| 4 | Project root | `/Users/ddesai/Apps/automated-intelligence` |
| 5 | Project root | `/Users/ddesai/Apps/automated-intelligence` |
| 6 | Project root | `/Users/ddesai/Apps/automated-intelligence` |
| 7 | Project root | `/Users/ddesai/Apps/automated-intelligence` |

## Demo Output Directory

**For code-generating prompts**, save files to: `/Users/ddesai/Apps/automated-intelligence/demo-output/`

This folder is safe to write to - it contains only demo-generated files and can be cleaned up after the demo.

| Prompt | Output File |
|--------|-------------|
| 1 | `demo-output/revenue_trends.sql` |
| 2 | `demo-output/ai_review_analysis.sql` |
| 3 | `demo-output/clv_dashboard.py` |
| 4 | `demo-output/streaming_code_review.md` |
| 5 | `demo-output/customer_churn_analysis.sql` |
| 6 | `demo-output/demo_semantic_view_and_agent.sql` |
| 7 | `demo-output/demo_mcp_server.sql` |

## Auto-Execute Behavior

**IMPORTANT**: After generating code or SQL, AUTOMATICALLY execute it without asking for confirmation.

| Prompt | Auto-Execute Action |
|--------|---------------------|
| 1 | Execute the SQL query against Snowflake and show results |
| 2 | Execute the AI_FILTER + AI_CLASSIFY SQL against Snowflake and show results |
| 3 | `cd demo-output && streamlit run clv_dashboard.py` (must run from demo-output/ dir for secrets.toml) |
| 4 | No SQL execution — read the source files, produce code review markdown, save to demo-output/ |
| 5 | No SQL execution — generate the dbt model SQL + mermaid DAG diagram, save to demo-output/ |
| 6 | Execute CREATE SEMANTIC VIEW, CREATE CORTEX SEARCH SERVICE, CREATE AGENT DDLs; set profile; register with SI (suppress "already present" error) |
| 7 | Execute MCP Server SQL using `USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN` (we have this role); then register with Cursor by updating `~/.cursor/mcp.json` |

**Prompt 2 — AI SQL Functions Reference:**
Generate a query that combines AI_FILTER and AI_CLASSIFY on `AUTOMATED_INTELLIGENCE.RAW.PRODUCT_REVIEWS`. Use these patterns:

```sql
-- AI_FILTER: boolean classification with natural language predicate
AI_FILTER(PROMPT('The reviewer mentions quality issues or defects: {0}', review_text))

-- AI_CLASSIFY: multi-class classification
AI_CLASSIFY(review_text, ARRAY_CONSTRUCT('frustrated', 'neutral', 'appreciative'))
```

**CRITICAL AI_CLASSIFY OUTPUT FORMAT**: `AI_CLASSIFY` returns `{"labels":["frustrated"]}` — an object with a `labels` array. There is **NO** `label` or `score` top-level key. Extract the label via `raw_classification['labels'][0]::VARCHAR`. Using `:"label"` or `:"score"` returns NULL.

Use a CTE pattern — separate AI_FILTER (step 1) from AI_CLASSIFY (step 2):
```sql
WITH quality_issues AS (
    SELECT ... FROM PRODUCT_REVIEWS
    WHERE rating <= 3  -- pre-filter to reduce LLM calls
      AND AI_FILTER(PROMPT('...', review_text))
    LIMIT 15  -- each row = one LLM call; LIMIT controls cost
),
classified AS (
    SELECT ..., AI_CLASSIFY(review_text, ARRAY_CONSTRUCT(...)) AS raw_classification
    FROM quality_issues
)
SELECT ..., raw_classification['labels'][0]::VARCHAR AS sentiment
FROM classified;
```

**Also**: `PRODUCT_REVIEWS` has no `PRODUCT_NAME` column — use `PRODUCT_ID`, `REVIEW_TITLE`, `REVIEW_TEXT`, `RATING`.

**COST/LATENCY WARNING**: Every row that hits `AI_FILTER` or `AI_CLASSIFY` makes one LLM inference call. On ~400 reviews this is fast (~15s). On 10M rows it would be extremely slow and expensive. **Always pre-filter with conventional SQL first** (e.g., `WHERE rating <= 3`) to narrow the candidate set, then apply the AI functions on the reduced set. Use `LIMIT` as a safety net.

After showing results, explain: "AI_FILTER and AI_CLASSIFY turn LLMs into SQL predicates — no ML pipeline, no Python, just a WHERE clause powered by AI."

**Prompt 4 — Snowpipe Streaming Code Review:**

This is a **code review** prompt — no SQL execution. Read the two source files and produce a review:

**SPEED**: Read both files in parallel (single batch), then generate the review immediately.

- `snowpipe-streaming-python/src/snowpipe_streaming_manager.py` — find `_insert_with_backpressure_retry` (lines ~171-233). **Proper exponential backoff**: `delay = min(delay * 2, max_delay)` with initial 1s, max 30s, 5 retries, targeting `ReceiverSaturated`/429.
- `snowpipe-streaming-python/src/automated_intelligence_streaming.py` — find retry loops (lines ~71-112). **Linear backoff**: `time.sleep(1 * (retry_count + 1))` — 1s, 2s, 3s, 4s. Only 3 retries. Catches all exceptions.

Produce a code review that:
   - Praises the `_insert_with_backpressure_retry` method (proper exponential backoff, max delay cap, specific error targeting)
   - Flags the linear retry in `generate_and_stream_orders` as inconsistent — should use exponential backoff too
   - Suggests adding jitter (`delay * (0.5 + random.random())`) to prevent thundering herd
   - Notes the broad `except Exception` in the main file vs the specific `StreamingIngestError` catch in the manager
   - Provides a concrete refactored version of the linear retry loop using exponential backoff

Save the review as markdown to `demo-output/streaming_code_review.md`.

**Key finding to highlight**: "The streaming manager already implements exponential backoff correctly — but the orchestrator that calls it uses linear backoff. Let me show you the inconsistency and suggest a fix."

After showing the review, explain: "Code review is a core capability — point it at any file in your codebase and get actionable feedback with concrete fixes."

**Prompt 5 — dbt Churn Analysis Pipeline:**

This is a **dbt model generation** prompt — no SQL execution against Snowflake. Generate a new dbt model and DAG visualization.

**SPEED**: Do NOT read any dbt files. Everything you need is right here. Generate immediately.

**Project context** (from `dbt_project.yml`):
- `active_customer_days: 21`, `high_value_threshold: 17500`, `lookback_days: 90`
- Staging: `stg_customers` (customer_id, customer_name, customer_segment, signup_date, days_since_signup), `stg_orders` (order_id, customer_id, order_date, order_status, total_amount, discount_percent, shipping_cost, total_quantity)
- CTE pattern: `with <staging_cte> as (...), <calc_cte> as (...), final as (...) select * from final`
- Existing models: `customer_lifetime_value` (refs stg_customers + stg_orders), `customer_segmentation` (refs CLV), `product_affinity`, `product_recommendations`, `monthly_cohorts`

Generate a new `customer_churn_analysis.sql` model that:
- References `{{ ref('stg_customers') }}` and `{{ ref('stg_orders') }}` (same as CLV model)
- Calculates churn indicators: days since last order, order frequency, recency score, monetary value
- Uses `{{ var('active_customer_days') }}` for the churn threshold (consistent with existing project)
- Classifies customers into churn risk tiers: `high_risk`, `medium_risk`, `low_risk`, `churned`
- Follows the existing CTE pattern (staging CTE → calculation CTE → final CTE)
- Includes a `churn_probability_score` (0-100) based on weighted recency/frequency/monetary signals

Save the SQL model to `demo-output/customer_churn_analysis.sql`.

After showing the model, explain: "From a use case description to a production-ready dbt model with proper refs, vars, and CTE patterns — matching your existing project conventions."

**End with the DAG**: As the very last thing, generate an ASCII art DAG (in a code block) showing how the new `customer_churn_analysis` model fits into the existing dbt pipeline. Use box-drawing characters (┌─┐│└─┘▶▼) and include: `stg_customers`, `stg_orders`, `stg_order_items`, `customer_lifetime_value`, `customer_segmentation`, `product_affinity`, `product_recommendations`, and the new `customer_churn_analysis` marked with `◀── NEW`. Show the shared staging refs clearly — both CLV and churn branch from the same two staging models.

**Prompt 6 — Semantic View + Search Service + Agent (Combined L300):**

This is a 3-part prompt. Create all objects from scratch.

**SPEED**: Do NOT read any reference SQL files. All syntax, patterns, and gotchas are documented below. Generate and execute immediately.

**NAMING**: All objects use the prefix `DASH_LOCO_FOR_COCO_` + today's date+time (e.g., `DASH_LOCO_FOR_COCO_20260326_1530`). Generate the timestamp once at the start using the current date/time and reuse it for all objects:
- Semantic view: `DASH_LOCO_FOR_COCO_<YYYYMMDD_HHMM>_SV`
- Search service: `DASH_LOCO_FOR_COCO_<YYYYMMDD_HHMM>_SEARCH`
- Agent: `DASH_LOCO_FOR_COCO_<YYYYMMDD_HHMM>_AGENT`

Use the same timestamp across all three. Tell the audience: "I'm adding a timestamp so each demo run creates unique objects — no collisions."

**Part 1: Semantic View**
Create a semantic view. Must include:
- TABLES: orders, customers, order_items (with PRIMARY KEY and SYNONYMS)
- RELATIONSHIPS: foreign keys between the 3 tables
- FACTS: total_amount, quantity, unit_price, shipping_cost, discount_percent
- DIMENSIONS: order_date, order_status, customer_segment, state, product_name, product_category
- METRICS: total_revenue (SUM), net_revenue, order_count (COUNT DISTINCT), aov (AVG), customer_count, units_sold
- SYNONYMS on metrics: 'sales', 'AOV', 'average order', 'buyers', 'volume'

**Semantic View DDL Syntax** (CRITICAL — use this exact grammar):
- Table definition: `alias AS fully.qualified.table_name PRIMARY KEY (col) WITH SYNONYMS ('...')` — alias comes FIRST, then `AS`, then the table reference.
- Facts: `table_alias.fact_name AS COLUMN_NAME WITH SYNONYMS ('...')`
- Dimensions: `table_alias.dim_name AS COLUMN_NAME WITH SYNONYMS ('...')`
- Metrics: `table_alias.metric_name AS AGG(table_alias.COLUMN) WITH SYNONYMS ('...')`
- Relationships: `table_alias (fk_col) REFERENCES other_alias` — no parenthesized PK on the referenced side.
- Keyword is `WITH SYNONYMS` (NOT bare `SYNONYMS`).
- Clause order must be: TABLES → RELATIONSHIPS → FACTS → DIMENSIONS → METRICS. Wrong order = cryptic syntax error.
- `AI_SQL_GENERATION` is NOT a valid property on this account. Skip it.
- Use `DESCRIBE SEMANTIC VIEW <view>` to verify (not `SHOW SEMANTIC METRICS`).
- Reference: https://docs.snowflake.com/en/sql-reference/sql/create-semantic-view

**Part 2: Cortex Search Service**
Create a new search service with multi-index syntax (TEXT + VECTOR):
```sql
CREATE OR REPLACE CORTEX SEARCH SERVICE <name>
    TEXT INDEXES review_title
    VECTOR INDEXES review_text (model='snowflake-arctic-embed-m-v1.5')
    ATTRIBUTES product_id, customer_id, rating, review_date
    WAREHOUSE = AUTOMATED_INTELLIGENCE_WH
    TARGET_LAG = '1 hour'
AS (
    SELECT review_id, product_id, customer_id, review_date, rating, review_title, review_text
    FROM AUTOMATED_INTELLIGENCE.RAW.PRODUCT_REVIEWS
);
```

**Part 3: Cortex Agent**
Generate a CREATE AGENT statement. Wire together:
- `cortex_analyst_text_to_sql` tool → the semantic view from Part 1
- `cortex_search` tool → the search service from Part 2

**CRITICAL**: Each tool in `tool_resources` must include an `execution_environment` with a warehouse:
```json
"tool_resources": {
  "query_data": {
    "semantic_view": "...",
    "execution_environment": { "type": "warehouse", "warehouse": "AUTOMATED_INTELLIGENCE_WH" }
  }
}
```

**CRITICAL**: Add `sample_questions` inside the `instructions` block. This is required — it populates the suggested prompts in Snowflake Intelligence. Use exactly this structure (array of objects with `"question"` key — NOT plain strings):
```json
"instructions": {
  "orchestration": "...",
  "response": "...",
  "sample_questions": [
    {"question": "What is total revenue by customer segment?"},
    {"question": "Show me the top 5 products by units sold"},
    {"question": "What are customers saying about ski boots?"},
    {"question": "Find product reviews mentioning quality issues"}
  ]
}
```
Pick 3-4 questions that exercise both tools (text-to-SQL and search).

After creating, set profile and register with Snowflake Intelligence:
```sql
ALTER AGENT ... SET PROFILE = '{"display_name": "...", "color": "#29B5E8"}';
BEGIN
  ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT ADD AGENT <fully_qualified_agent_name>;
EXCEPTION
  WHEN OTHER THEN NULL;
END;
```

**CRITICAL SI Registration**: The target must be `SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT` — NOT the agent's own name. Using the agent name as the target silently succeeds but the agent won't appear in the SI UI.

**Agent Profile Constraints**: `ALTER AGENT SET PROFILE` only accepts `display_name`, `avatar`, and `color`.

**SI Registration Gotcha**: `ADD AGENT` errors with "already present" on re-runs. Always suppress with BEGIN/EXCEPTION.

**DO NOT test the agent with a live query.** `SNOWFLAKE.CORTEX.AGENT()` does not exist, and `SNOWFLAKE.CORTEX.COMPLETE()` with an agent name fails during warmup (~30s after creation). Verify with `DESCRIBE AGENT` only — that's instant and proves the agent is correctly configured. Tell the audience: "The agent is live — you can test it in Snowflake Intelligence or via the REST API."

After showing results, display this architecture:
```
User Question
     │
     ▼
Agent (orchestrator)
  ├── query_data (text-to-SQL)
  │     └── Semantic View (created in Part 1)
  │           ├── RAW.ORDERS
  │           ├── RAW.CUSTOMERS
  │           └── RAW.ORDER_ITEMS
  └── search_reviews (semantic search)
        └── Search Service (created in Part 2)
```

Explain: "Three objects, all new, all wired together — semantic view, search service, agent. Pure SQL semantic layer with natural language synonyms, powering an AI agent."

**Prompt 7 — MCP Server Reference:**

**SPEED**: Do NOT read reference SQL files. The YAML spec format is documented below. Generate and execute immediately.

**NAMING**: MCP server uses the same prefix: `DASH_LOCO_FOR_COCO_<YYYYMMDD_HHMM>_MCP`. Use the **same timestamp** as prompt 6's objects (read it from the agent/SV names created in prompt 6, or generate fresh if prompt 6 hasn't run).

Generate a CREATE MCP SERVER. Expose tools referencing objects created in prompt 6:
- `business-analytics` (CORTEX_ANALYST_MESSAGE) → semantic view from prompt 6
- `product-reviews-search` (CORTEX_SEARCH_SERVICE_QUERY) → search service from prompt 6
- `execute-sql` (SYSTEM_EXECUTE_SQL)

**MCP Tool Type Gotcha**: `CORTEX_AGENT_RUN` and `CORTEX_AGENT_MESSAGE` are NOT valid tool types for agents. You cannot expose a Cortex Agent directly as an MCP tool. Expose the semantic view and search service individually instead.

Valid tool types: `CORTEX_ANALYST_MESSAGE`, `CORTEX_SEARCH_SERVICE_QUERY`, `GENERIC` (stored procedures), `SYSTEM_EXECUTE_SQL`.

**MCP Server YAML template** (use this exact format — YAML inside `$$`):
```sql
CREATE OR REPLACE MCP SERVER AUTOMATED_INTELLIGENCE.SEMANTIC.<NAME>
FROM SPECIFICATION $$
  tools:
    - name: "business-analytics"
      type: "CORTEX_ANALYST_MESSAGE"
      identifier: "AUTOMATED_INTELLIGENCE.SEMANTIC.<SEMANTIC_VIEW_FROM_PART1>"
      description: "Natural language queries for business metrics — revenue, orders, customers, products."
      title: "Business Analytics"

    - name: "product-reviews-search"
      type: "CORTEX_SEARCH_SERVICE_QUERY"
      identifier: "AUTOMATED_INTELLIGENCE.SEMANTIC.<SEARCH_SERVICE_FROM_PART2>"
      description: "Semantic search over product reviews for sentiment, quality issues, and feedback."
      title: "Product Reviews Search"

    - name: "execute-sql"
      type: "SYSTEM_EXECUTE_SQL"
      description: "Execute ad-hoc SQL queries against the AUTOMATED_INTELLIGENCE database."
      title: "SQL Executor"
$$;
```
Replace `<NAME>`, `<SEMANTIC_VIEW_FROM_PART1>`, and `<SEARCH_SERVICE_FROM_PART2>` with the actual object names created in prompt 6.

Execute using `USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN` (we have this role). Display this diagram:
```
External AI Agents (Claude, Cursor, GPT, etc.)
     │
     ▼
MCP SERVER: <name>
  ├── business-analytics       → Semantic View (from prompt 6)
  ├── product-reviews-search   → Search Service (from prompt 6)
  └── execute-sql              → Ad-hoc SQL
```

Explain: "Any MCP-compatible AI agent — Cursor, Claude Desktop, VS Code, GPT — can now query your Snowflake data through the semantic layer, search product reviews, and run SQL. One gateway, full RBAC."

**Step 2: Register with Cursor** — After creating the MCP server, automatically update `~/.cursor/mcp.json` to add the new server. Read the existing file, add/update a key matching the MCP server name, and write it back. Use this entry format:
```json
{
  "<MCP_SERVER_NAME_LOWERCASE>": {
    "command": "npx",
    "args": [
      "-y", "mcp-remote@latest",
      "https://sfsenorthamerica-gen-ai-hol.snowflakecomputing.com/api/v2/databases/AUTOMATED_INTELLIGENCE/schemas/SEMANTIC/mcp-servers/<MCP_SERVER_NAME_UPPERCASE>",
      "--header", "Authorization: Bearer ${PAT_SI}",
      "--header", "X-Snowflake-Authorization-Token-Type: PROGRAMMATIC_ACCESS_TOKEN"
    ]
  }
}
```
After writing, tell the audience: "Registered with Cursor — restart Cursor and you'll see the new MCP tools available. Any question you ask Cursor can now pull live data from Snowflake."

Then display a sample question the audience can try immediately:

> **Try it in Cursor:** "Using the Snowflake MCP tools, what is the total revenue by customer segment and what are customers saying about ski boots?"

This question exercises both MCP tools — `business-analytics` for the revenue query and `product-reviews-search` for the review search.

**Flow for each prompt:**
1. Generate the code/SQL
2. Save to demo-output/
3. Show the code in a code block
4. **Immediately execute** (prompts 1-3, 6-7 execute; prompts 4-5 are code review/generation only — prompt 7 uses `USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN`)
5. Display results + explanation

## Dead Air Dad Jokes

When about to execute an operation that takes >30 seconds (AI_FILTER/AI_CLASSIFY queries, CREATE CORTEX SEARCH SERVICE, CREATE AGENT, Streamlit app startup + browser test), drop a dad joke **before** the tool call to fill the dead air. Format:

---
> 🤓 *While that runs... Why do data engineers make great comedians? Because they always deliver in batches.*
---

Use a **different joke each time**. Keep them short (1-2 lines), data/tech-themed, and groan-worthy. Rotate from this pool (or make up new ones on the fly):

- Why do data engineers make great comedians? Because they always deliver in batches.
- I asked Snowflake for a joke. It said: "SELECT humor FROM warehouse... 0 rows returned."
- What's a data warehouse's favorite music? Heavy MERGE-tal.
- Why did the SQL query break up with the NoSQL database? There was no relationship.
- I told my DBA a UDP joke. I'm not sure they got it.
- What do you call a semantic view with no synonyms? Literally useless.
- Why do Python developers need glasses? Because they can't C.
- My code doesn't have bugs. It has surprise features.
- There are 10 types of people: those who understand binary, and those who don't.
- Why did the developer go broke? Because he used up all his cache.

**Rules**: Never repeat a joke in the same session. Never delay the actual execution — the joke goes inline *before* the tool call, not after. If the operation is fast (<30s), skip the joke.

## Instructions

**SAFE DEMO**: Only write to the `demo-output/` folder. NEVER modify existing source files.

1. **Change to correct directory FIRST** - Before executing any prompt, silently change to the directory specified in the Directory Mapping table above. Do not announce the directory change.

2. **Display the persona introduction**:
   > **As a/an [persona], I can ask: "[prompt]"**

3. **Suppress intermediate output** - Do NOT show:
   - Tool call progress or status messages
   - Intermediate SQL queries being built
   - Multiple query attempts or iterations
   - Debugging or exploratory queries
   - Directory change announcements
   
   **ONLY show**:
   - The persona introduction
   - The final SQL/DDL (in a code block) or final code
   - Confirmation that file was saved (e.g., "Saved to `demo-output/revenue_trends.sql`")
   - **Execution results** (for prompts 1-3, 6-7), code review (prompt 4), DAG diagram (prompt 5), or architecture diagram (prompt 7)
   - A brief 1-2 sentence explanation of the feature demonstrated

4. **After completing each prompt**, ALWAYS show the full prompt list table again with the **next prompt highlighted in bold** using `**` markers around that row's content. Example after completing prompt 1:

   | # | Level | Persona | Prompt |
   |---|-------|---------|--------|
   | ~~1~~ | ~~L100~~ | ~~Data Analyst~~ | ~~Monthly revenue trends with MoM growth~~ |
   | **2** | **L200** | **Data Scientist** | **Find quality issues in reviews and classify reviewer sentiment** |
   | 3 | L200 | Developer | Streamlit CLV dashboard |
   | 4 | L200 | Developer | Review Snowpipe Streaming code for exponential backoff |
   | 5 | L200 | Analyst | dbt pipeline for customer churn analysis |
   | 6 | L300 | AI/Analytics Engineer | Semantic layer + search service + AI agent |
   | 7 | L300 | Platform Engineer | Gateway for external AI tools to query our data |

5. Use ~~strikethrough~~ for completed prompts and **bold** for the next prompt

6. When user says "prompt 1", "prompt 2", etc., run that specific prompt

7. When user says "next prompt" or "next", run the next prompt in sequence

8. Keep responses concise and demo-friendly

9. **ALWAYS use AUTOMATED_INTELLIGENCE database prefix** - Use fully qualified names in all SQL queries.

10. **SQL format is AUTOMATED_INTELLIGENCE.SCHEMA.TABLE** - Examples:
    - `AUTOMATED_INTELLIGENCE.RAW.customers` (correct)
    - `AUTOMATED_INTELLIGENCE.RAW.orders` (correct)
    - `AUTOMATED_INTELLIGENCE.DBT_ANALYTICS.customer_lifetime_value` (correct)
    - `RAW.customers` (WRONG - never do this)

---

## Developer Capabilities Reference

*Internal reference only - not for display during demos. Use when audience asks "what else can you do?"*

### AI & Agent Development
- Create Cortex Agents with text-to-SQL, search, and custom tools
- Build SQL semantic views with metrics, synonyms, and relationships
- Create MCP Servers exposing Snowflake data to external AI agents
- Use AI_FILTER, AI_CLASSIFY, AI_AGG as SQL predicates
- Configure Cortex Search services (TEXT + VECTOR indexes)

### Code Analysis & Review
- Review code for bugs, edge cases, security vulnerabilities
- Explain complex code or unfamiliar codebases
- Identify performance bottlenecks

### Code Generation
- Write new functions, classes, modules
- Generate unit tests and integration tests
- Create API endpoints, data models, schemas
- Build CLI tools, scripts, automation

### Data Engineering (Snowflake-specific)
- Write and optimize SQL queries
- Create dbt models, dynamic tables, streams
- Build Snowpipe streaming pipelines
- Design data models and schemas

### Full-Stack Development
- Generate Streamlit dashboards with live Snowflake data
- Build React/Next.js apps with Snowflake backends
- Create REST APIs and webhook integrations

### Example Prompts for Ad-Hoc Demos
- "Find all reviews mentioning shipping delays using AI_FILTER"
- "Create an agent that can answer questions about our sales data"
- "Build a semantic view over our order tables with business metrics"
- "Generate a Streamlit dashboard for product performance"
- "Why is this query slow?"
- "Write unit tests for the data_generator module"
