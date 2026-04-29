---
name: demo-quick
description: "Rapid-fire platform showcase — one query per feature, no setup, no ceremony. Shows Automated Intelligence end-to-end in ~5 minutes. Use when: quick demo, fast demo, rapid demo, lightning demo, 5 minute demo, speed run, show me everything fast, quick walkthrough. Triggers: quick demo, fast demo, rapid, lightning, speed run, quick, show everything, 5 minute, rapid fire, demo-quick."
---

# Rapid-Fire Platform Showcase

Seven shots. One query each. No setup, no staging, no benchmarking ceremony. Just results.

## Connection & Context

- **Connection**: `dash-builder-si`
- **Database**: `AUTOMATED_INTELLIGENCE`
- **Role**: `AUTOMATED_INTELLIGENCE`
- **Always fully qualify**: `AUTOMATED_INTELLIGENCE.SCHEMA.TABLE`

## Column Reference

- **customers**: `customer_id`, `first_name`, `last_name`, `state`, `customer_segment` (`'Premium'`, `'Standard'`, `'Basic'`)
- **orders**: `order_id` (VARCHAR), `customer_id`, `order_date`, `order_status` (`'Completed'`, `'Shipped'`, `'Processing'`, `'Pending'`, `'Cancelled'`), `total_amount`, `discount_percent`, `shipping_cost`
- **order_items**: `order_item_id`, `order_id`, `product_id`, `product_name`, `product_category` (`'Skis'`, `'Snowboards'`, `'Boots'`, `'Accessories'`), `quantity`, `unit_price`, `line_total`
- **customer_lifetime_value**: `customer_id`, `total_revenue`, `total_orders`, `avg_order_value`, `value_tier` (`'high_value'`, `'medium_value'`, `'low_value'`), `customer_status` (`'active'`, `'at_risk'`, `'churned'`)

## How It Works

1. Show the shot list below
2. Auto-execute each shot's SQL, show the result, give a one-liner interpretation
3. User says **"next"** to advance, **"shot 4"** to jump, **"done"** to stop
4. After each shot, redisplay the shot list with ~~strikethrough~~ on completed shots and **bold** on the next one
5. No files written. No code generated. Pure SQL showcase.

## Shot List

| # | Feature | What It Proves |
|---|---------|---------------|
| 1 | Pipeline Proof | Data flows through all layers end-to-end |
| 2 | Dynamic Tables | Zero-orchestrator incremental pipeline |
| 3 | Interactive Tables | Sub-100ms point lookups for APIs |
| 4 | Cortex Agent | Natural language → SQL → results |
| 5 | Cortex Search | Semantic search over unstructured data |
| 6 | Row Access Policy | Same query, different role, filtered results |
| 7 | dbt Analytics | CLV tiers + product co-purchase pairs |

---

## Shot 1: Pipeline Proof

One query proves data flows from raw ingestion through every layer.

```sql
SELECT 'RAW.CUSTOMERS' as layer, COUNT(*) as rows FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS
UNION ALL SELECT 'RAW.ORDERS', COUNT(*) FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS
UNION ALL SELECT 'RAW.ORDER_ITEMS', COUNT(*) FROM AUTOMATED_INTELLIGENCE.RAW.ORDER_ITEMS
UNION ALL SELECT 'DT.ENRICHED_ORDERS', COUNT(*) FROM AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES.ENRICHED_ORDERS
UNION ALL SELECT 'DT.FACT_ORDERS', COUNT(*) FROM AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES.FACT_ORDERS
UNION ALL SELECT 'DT.DAILY_METRICS', COUNT(*) FROM AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES.DAILY_BUSINESS_METRICS
UNION ALL SELECT 'INTERACTIVE.ANALYTICS', COUNT(*) FROM AUTOMATED_INTELLIGENCE.INTERACTIVE.CUSTOMER_ORDER_ANALYTICS
UNION ALL SELECT 'DBT.CLV', COUNT(*) FROM AUTOMATED_INTELLIGENCE.DBT_ANALYTICS.CUSTOMER_LIFETIME_VALUE;
```

**One-liner**: Data enters RAW via Snowpipe Streaming, flows through Dynamic Tables, lands in Interactive and dbt — no orchestrator, no DAG.

---

## Shot 2: Dynamic Tables

Show refresh history proving incremental processing.

```sql
SELECT name, refresh_action, state,
       DATEDIFF('second', refresh_start_time, refresh_end_time) as seconds
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
    NAME_PREFIX => 'AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES'))
WHERE state = 'SUCCEEDED'
ORDER BY data_timestamp DESC LIMIT 8;
```

**One-liner**: INCREMENTAL refresh — only changed rows processed. As data grows to millions, refresh still takes seconds. No Airflow, no cron, just SQL.

---

## Shot 3: Interactive Tables

Pick a random customer, then do a sub-100ms lookup.

**Step A** — Get a customer:
```sql
SELECT customer_id FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS ORDER BY RANDOM() LIMIT 1;
```

**Step B** — Interactive Table lookup (substitute the customer_id from Step A):
```sql
USE WAREHOUSE automated_intelligence_interactive_wh;
SELECT customer_id, first_name, last_name, customer_segment,
       total_orders, total_spent, avg_order_value
FROM AUTOMATED_INTELLIGENCE.INTERACTIVE.CUSTOMER_ORDER_ANALYTICS
WHERE customer_id = <CUSTOMER_ID_FROM_STEP_A>;
```

Then switch back:
```sql
USE WAREHOUSE automated_intelligence_wh;
```

**One-liner**: Sub-50ms. That's your API response time. Interactive Tables are the serving layer — dashboards, apps, real-time lookups.

---

## Shot 4: Cortex Agent

Natural language to SQL to results.

```sql
SELECT SNOWFLAKE.CORTEX.AGENT(
  'AUTOMATED_INTELLIGENCE.SEMANTIC.BUSINESS_INSIGHTS_AGENT',
  'What are the top 5 states by total revenue?'
);
```

**One-liner**: Plain English → SQL → results. The semantic view maps business terms to columns. No prompt engineering needed.

---

## Shot 5: Cortex Search

Semantic search over product reviews.

```sql
SELECT * FROM TABLE(
  SNOWFLAKE.CORTEX.SEARCH(
    'AUTOMATED_INTELLIGENCE.SEMANTIC.PRODUCT_REVIEWS_SEARCH',
    'ski boot comfort issues', 5));
```

**One-liner**: Finds "fit problems" and "pressure points" even though we searched for "comfort issues." Vector search, auto-refreshes as new reviews arrive.

---

## Shot 6: Row Access Policy

Same query, two roles, different results.

**Step A** — Admin sees everything:
```sql
USE ROLE AUTOMATED_INTELLIGENCE;
SELECT state, COUNT(*) as customers, ROUND(SUM(o.total_amount), 2) as revenue
FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS c
JOIN AUTOMATED_INTELLIGENCE.RAW.ORDERS o ON c.customer_id = o.customer_id
GROUP BY state ORDER BY revenue DESC;
```

**Step B** — West Coast Manager sees only their territory:
```sql
USE ROLE WEST_COAST_MANAGER;
SELECT state, COUNT(*) as customers, ROUND(SUM(o.total_amount), 2) as revenue
FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS c
JOIN AUTOMATED_INTELLIGENCE.RAW.ORDERS o ON c.customer_id = o.customer_id
GROUP BY state ORDER BY revenue DESC;
```

**Step C** — Switch back:
```sql
USE ROLE AUTOMATED_INTELLIGENCE;
```

**One-liner**: Same query, same table — 10 states vs. 3 (CA, OR, WA). Security is invisible and cascades through JOINs, views, DTs, and AI agents.

---

## Shot 7: dbt Analytics

CLV tiers and product co-purchase pairs.

**Step A** — Customer Lifetime Value tiers:
```sql
SELECT value_tier, customer_status, COUNT(*) as customers,
       ROUND(AVG(total_revenue), 2) as avg_revenue
FROM AUTOMATED_INTELLIGENCE.DBT_ANALYTICS.CUSTOMER_LIFETIME_VALUE
GROUP BY value_tier, customer_status ORDER BY avg_revenue DESC;
```

**Step B** — Top co-purchased product pairs:
```sql
SELECT * FROM AUTOMATED_INTELLIGENCE.DBT_ANALYTICS.PRODUCT_AFFINITY
ORDER BY pair_count DESC LIMIT 10;
```

**One-liner**: RFM scoring feeds churn models. Market basket analysis drives recommendations. Powder Skis + Ski Boots is the top pair.

---

## Navigation

- **"next"** — advance to the next shot
- **"shot N"** — jump to shot N
- **"done"** or **"menu"** — stop and show final summary
- After each shot, redisplay the shot list with completed shots in ~~strikethrough~~ and the next shot in **bold**

## Wrap-Up

After all 7 shots (or when presenter says "done"), summarize:

> **Seven features. One platform. No stitching.**
> Ingestion → transformation → serving → intelligence → governance — all SQL, all Snowflake.
