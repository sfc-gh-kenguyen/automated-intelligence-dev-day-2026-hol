# Snowflake Intelligence Setup

This directory contains setup scripts for **Snowflake Intelligence** features: Cortex Analyst, Cortex Agent, and Cortex Search.

**Status**: Generally Available (GA as of Build 2025)

## Prerequisites

**Required:** Core setup must be completed first (includes semantic model stage creation)
```bash
snow sql -f setup.sql -c dash-builder-si
```

## Files

- `business_insights_semantic_model.yaml` - Semantic model definition for Cortex Analyst (uses logical table names for verified queries)
- `create_agent.sql` - Creates Cortex Agent in `AUTOMATED_INTELLIGENCE.SEMANTIC` schema for natural language queries
- `create_postgres_search_services.sql` - Creates Cortex Search services for Postgres-synced data (product reviews & support tickets)

## Setup Instructions

### 1. Upload Semantic Model
```bash
snow stage copy snowflake-intelligence/business_insights_semantic_model.yaml \
  @automated_intelligence.raw.semantic_models/ --overwrite -c dash-builder-si
```

### 2. Create Cortex Agent
```bash
snow sql -f snowflake-intelligence/create_agent.sql -c dash-builder-si
```

### 3. Create Cortex Search Service
```bash
snow sql -f snowflake-intelligence/create_cortex_search.sql -c dash-builder-si
```

## What Gets Created

### Semantic Model Stage
- **Stage**: `automated_intelligence.raw.semantic_models`
- Stores YAML semantic model files for Cortex Analyst
- **Note**: Verified queries use logical table names (e.g., `orders`, `daily_business_metrics`) instead of physical table names

### Cortex Agent
- **Agent**: `automated_intelligence.semantic.order_analytics_agent`
- Created in the `SEMANTIC` schema using `AUTOMATED_INTELLIGENCE` role
- Enables natural language queries over order data
- Uses semantic model for context-aware SQL generation
- Requires `CREATE SNOWFLAKE INTELLIGENCE ON ACCOUNT` privilege

### Cortex Search Services
- **Service**: `automated_intelligence.semantic.product_reviews_search`
  - Enables semantic search over product reviews synced from Postgres
  - Search by review text with attributes: product_id, customer_id, rating, review_title, review_date
- **Service**: `automated_intelligence.semantic.support_tickets_search`
  - Enables semantic search over support tickets synced from Postgres
  - Search by description with attributes: customer_id, category, priority, subject, status, ticket_date

## Verification

### Verify Stage
```sql
LIST @automated_intelligence.raw.semantic_models;
```

### Test Cortex Agent
```sql
USE ROLE AUTOMATED_INTELLIGENCE;
USE DATABASE automated_intelligence;
USE SCHEMA semantic;

-- Ask questions in natural language
SELECT SNOWFLAKE.CORTEX.COMPLETE(
  'order_analytics_agent',
  'What were the top 5 products by revenue last month?'
);

-- Test discount analysis (now working with updated semantic model)
SELECT SNOWFLAKE.CORTEX.COMPLETE(
  'order_analytics_agent',
  'What is the impact of discounts on revenue?'
);
```

### Test Cortex Search (Product Reviews)
```sql
SELECT PARSE_JSON(
  SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'automated_intelligence.semantic.product_reviews_search',
    '{
      "query": "quality issues with boots",
      "columns": ["review_title", "review_text", "rating"],
      "limit": 5
    }'
  )
)['results'] AS search_results;
```

### Test Cortex Search (Support Tickets)
```sql
SELECT PARSE_JSON(
  SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'automated_intelligence.semantic.support_tickets_search',
    '{
      "query": "shipping delays and refund",
      "columns": ["subject", "description", "category", "priority"],
      "limit": 5
    }'
  )
)['results'] AS search_results;
```

## Advanced: Custom ML Tools for Cortex Agents

### Adding Trained ML Models as Agent Tools

You can extend Cortex Agents with custom ML models deployed as stored procedures. This enables natural language access to ML-powered insights.

**Example: Product Recommendations**

After training the product recommendation model (see `ml-training/`), deploy it as a stored procedure:

```bash
cd ml-training
snow sql -c dash-builder-si -f product_recommendations_sproc.sql
```

**Agent Tool Definition:**

```yaml
tools:
  - type: function
    function:
      name: get_product_recommendations
      description: "Get personalized product recommendations for customers in a specific segment using ML predictions"
      parameters:
        type: object
        properties:
          n_customers:
            type: integer
            description: "Number of customers to generate recommendations for"
          n_products:
            type: integer
            description: "Number of product recommendations per customer"
          segment:
            type: string
            enum: ["LOW_ENGAGEMENT", "HIGH_VALUE_INACTIVE", "NEW_CUSTOMERS", "AT_RISK", "HIGH_VALUE_ACTIVE"]
            description: "Customer segment to target"
        required: ["segment"]
      implementation:
        type: sql
        sql: "CALL AUTOMATED_INTELLIGENCE.MODELS.GET_PRODUCT_RECOMMENDATIONS(:n_customers, :n_products, :segment)"
```

**Sample Conversational Queries:**
```
User: "Show me product recommendations for low engagement customers"
User: "Which products should I recommend to inactive high-value customers?"
User: "Get me 10 customers from the at-risk segment with their top 5 products"
```

**Agent Response Example:**
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
  2. Powder Skis (Skis)
     Purchase Probability: 76.5%

Total Customers: 2
Total Recommendations: 3

These recommendations are based on ML predictions trained on millions of 
customer-product interactions. The high probabilities indicate strong 
matches for targeted marketing campaigns.
```

**Key Benefits:**
- **Natural Language Access**: Users don't need to know stored procedure syntax
- **ML-Powered Insights**: Leverages trained models for intelligent recommendations
- **Formatted Output**: Returns human-readable strings perfect for conversational interfaces
- **Production-Ready**: Deterministic results suitable for business campaigns

**See:** `ml-training/README.md` for complete model training and deployment guide

---

## Use Cases

### Cortex Analyst & Agent
- Business users asking questions in natural language
- Ad-hoc analytics without writing SQL
- Semantic understanding of business metrics
- **ML-powered recommendations** through custom tools

### Cortex Search
- Product reviews search - find customer feedback by sentiment and content
- Support tickets search - discover issues and complaints
- Natural language queries in Snowflake Intelligence via Cortex Agent

## Cortex Agent Evaluations (GA March 2026)

Cortex Agent Evaluations let you systematically test and measure agent quality against ground truth and reference-free metrics.

### System Metrics

- **Answer correctness** -- compares agent response against ground truth (`ground_truth_output` key in VARIANT column)
- **Logical consistency** -- reference-free metric measuring consistency across agent instructions, planning, and tool calls (no ground truth needed)
- **Custom metrics** -- LLM judge prompts with `{{ground_truth}}` placeholder for domain-specific evaluation

### Quick Start

```sql
-- 1. Create evaluation source table (query + ground truth VARIANT)
CREATE OR REPLACE TABLE AUTOMATED_INTELLIGENCE.SEMANTIC.AGENT_EVAL_TABLE (
    input_query VARCHAR,
    ground_truth VARIANT
);

INSERT INTO AUTOMATED_INTELLIGENCE.SEMANTIC.AGENT_EVAL_TABLE
SELECT column1, PARSE_JSON(column2) FROM VALUES
    ('What were total sales last month?',
     '{"ground_truth_output": "The agent should use the cortex_analyst_text_to_sql tool to query revenue data and return a dollar amount for the previous month."}'),
    ('Find reviews about boot quality',
     '{"ground_truth_output": "The agent should use the search_reviews tool to find product reviews mentioning boots, quality issues, or defects."}'),
    ('Show me open shipping complaint tickets',
     '{"ground_truth_output": "The agent should use the search_tickets tool to find support tickets related to shipping delays, lost packages, or delivery complaints."}');

-- 2. Register as evaluation dataset
CALL SYSTEM$CREATE_EVALUATION_DATASET(
    'Cortex Agent',
    'AUTOMATED_INTELLIGENCE.SEMANTIC.AGENT_EVAL_TABLE',
    'AUTOMATED_INTELLIGENCE.SEMANTIC.BUSINESS_AGENT_EVALSET',
    OBJECT_CONSTRUCT('query_text', 'INPUT_QUERY', 'ground_truth', 'GROUND_TRUTH')
);

-- 3. Run evaluation (returns evaluation run ID)
SELECT EXECUTE_AI_EVALUATION('START', {
    'evaluation_name': 'business_agent_eval_run_1',
    'agent': 'AUTOMATED_INTELLIGENCE.SEMANTIC.BUSINESS_INSIGHTS_AGENT',
    'dataset': 'AUTOMATED_INTELLIGENCE.SEMANTIC.BUSINESS_AGENT_EVALSET',
    'metrics': ['answer_correctness', 'logical_consistency']
});

-- 4. Check evaluation status
SELECT EXECUTE_AI_EVALUATION('STATUS', {
    'evaluation_name': 'business_agent_eval_run_1'
});

-- 5. Retrieve evaluation results
SELECT * FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_EVALUATION_DATA(
    'business_agent_eval_run_1'
));
```

See `cortex_agent_evaluations_demo.sql` for the complete walkthrough.

### When to Evaluate

- After modifying agent specification (tools, models, instructions)
- After updating semantic views or search service data
- Before promoting agent changes to production
- As part of CI/CD pipelines via `snow sql -f`

## Related Demos
- **ML Training**: Train and deploy product recommendation model as custom agent tool
- **Streamlit Dashboard**: Integrates with Cortex Agent for natural language queries
- **Semantic View SQL Demo**: Standard SQL FROM clause queries on semantic views (GA March 2026)
