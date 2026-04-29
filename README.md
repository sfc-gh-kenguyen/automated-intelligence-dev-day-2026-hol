# Automated Intelligence

## 🎯 Overview

This demo suite executes a full-stack data lifecycle, starting with real-time ingestion via Snowpipe Streaming (Python/Java SDKs) and optimized DML operations on Gen2 Warehouses. It utilizes Dynamic Tables for incremental pipeline transformations and Interactive Warehouses to achieve low-latency query performance for high-concurrency serving. The workflow incorporates batch modeling via dbt in Snowflake Workspaces, GPU-accelerated ML training for recommendation engines, and Streamlit for live performance monitoring. The sequence culminates in Snowflake Intelligence, leveraging Cortex Agents for conversational analytics and data exploration—all secured by row-level access controls (RLAC) to ensure governed AI interactions.

1. **Snowpipe Streaming** - Real-time ingestion using Python or Java
2. **Gen2 Warehouse Performance** - Next-generation MERGE/UPDATE operations
3. **Dynamic Tables Pipeline** - Zero-maintenance incremental transformations
4. **Interactive Tables & Warehouses** - High-concurrency serving layer (sub-100ms queries)
5. **DBT Analytics** - Batch analytical models in Snowflake Workspaces (CLV, segmentation, cohorts)
6. **ML Training** - GPU-accelerated product recommendation model in Snowflake Workspaces
7. **Streamlit Dashboard** - Real-time monitoring of ingestion and performance
8. **Snowflake Intelligence** - AI-powered conversational analytics using Cortex Agent for intuitive data exploration
9. **Security & Governance** - Row-based access control for Cortex Agents
10. **Snowflake Postgres** - Hybrid OLTP/OLAP architecture with Postgres for transactional writes and Snowflake for analytics
11. **Workload Identity Federation** - Zero-secrets authentication from GitHub Actions, AWS, Kubernetes

All demos share the same foundation and work together to show an end-to-end data lifecycle on Snowflake.

---

## 🏗️ Demo Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│  DEMO 1: INGESTION LAYER                                         │
│  Snowpipe Streaming (Python/Java SDK) → Real-time ingestion     │
│  • Single to parallel instances for horizontal scaling          │
│  • High-scale ready: Linear horizontal scaling               │
│  • Sub-second latency from generation to queryable              │
└──────────────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────────────┐
│  DEMO 2: STAGING & DEDUPLICATION LAYER                           │
│  Gen2 Warehouses → Staging → MERGE/UPDATE → Raw tables          │
│  • Next-gen MERGE/UPDATE/DELETE performance                     │
│  • Production pattern: Snowpipe → Staging → Dedup → Raw        │
│  • Fair benchmarking with snapshot/restore                      │
│  • RESOURCE_CONSTRAINT = 'STANDARD_GEN_2'                       │
└──────────────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────────────┐
│  DEMO 3: INCREMENTAL TRANSFORMATION LAYER                        │
│  Dynamic Tables (5 tables, 3 tiers) → Zero-maintenance          │
│  • Tier 1 (Enrichment): 2 tables with 1-minute TARGET_LAG      │
│    - enriched_orders, enriched_order_items                      │
│  • Tier 2 (Integration): 1 table with DOWNSTREAM refresh       │
│    - fact_orders (joins enriched tables)                        │
│  • Tier 3 (Aggregation): 2 tables with DOWNSTREAM refresh      │
│    - daily_business_metrics, product_performance_metrics        │
│  • All tables: REFRESH_MODE = INCREMENTAL                       │
└──────────────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────────────┐
│  DEMO 4: HIGH-CONCURRENCY SERVING LAYER                          │
│  Interactive Tables + Interactive Warehouses                     │
│  • Low-latency queries under high concurrency                   │
│  • High concurrent user support with consistent performance     │
│  • 2 interactive tables: customer_order_analytics, order_lookup │
│  • No external cache needed (Redis, API database, etc.)         │
└──────────────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────────────┐
│  DEMO 5: BATCH ANALYTICAL LAYER                                  │
│  Snowflake Workspaces (dbt) → Daily/weekly batch processing     │
│  • 4 staging views in dbt_staging schema                        │
│  • 5 analytical marts in dbt_analytics schema                   │
│    - Customer: lifetime_value, segmentation (RFM-based)         │
│    - Product: affinity, recommendations (market basket)         │
│    - Cohort: monthly_cohorts (retention analysis)               │
└──────────────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────────────┐
│  DEMO 6: ML TRAINING LAYER                                       │
│  Snowflake Workspaces (Notebooks + GPU) → ML training           │
│  • XGBoost product recommendation model                         │
│  • GPU-accelerated training (tree_method='gpu_hist')            │
│  • Large-scale training data (millions of customer-product pairs)│
│  • Model Registry integration (version tracking)                │
└──────────────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────────────┐
│  DEMO 7: MONITORING & OBSERVABILITY LAYER                        │
│  Streamlit Dashboard → Real-time pipeline monitoring            │
│  • Live ingestion metrics (order/item counts, trends)           │
│  • Gen2 vs Gen1 warehouse performance testing                   │
│  • Dynamic Tables health & freshness checks                     │
│  • Interactive Tables query latency testing                     │
│  • ML model metrics & feature importance visualization          │
└──────────────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────────────┐
│  DEMO 8: SEMANTIC LAYER & AI INTERFACE                           │
│  Cortex Agent + Semantic Models → Natural language analytics    │
│  • Business terminology mapping (revenue, discount rate, etc.)  │
│  • Verified Query Repository (VQR) for accurate answers         │
│  • Multi-table joins (orders, customers, products)              │
│  • Date intelligence ("this month", "last quarter", "YTD")      │
└──────────────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────────────┐
│  DEMO 9: GOVERNANCE & SECURITY LAYER                             │
│  Row Access Policies → Transparent data filtering               │
│  • Role-based row-level security (RLAC)                         │
│  • Agent-compatible (same agent, different data views)          │
│  • Zero application code changes required                       │
│  • Policy-based governance (not query rewriting)                │
└──────────────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────────────┐
│  DEMO 10: HYBRID OLTP/OLAP LAYER (Snowflake Postgres)            │
│  Postgres (OLTP) → Snowflake (OLAP) → Cortex Search/Agent       │
│  • Product reviews & support tickets written to Postgres        │
│  • MERGE-based sync to Snowflake (5-minute scheduled task)      │
│  • Cortex Search for semantic search over synced data           │
│  • Natural language queries via Cortex Agent                    │
│  • pg_lake: Iceberg tables for external Postgres read access    │
└──────────────────────────────────────────────────────────────────┘
                          ↓
┌──────────────────────────────────────────────────────────────────┐
│  DEMO 11: WORKLOAD IDENTITY FEDERATION                           │
│  GitHub Actions → Snowflake (Zero Secrets)                       │
│  • OIDC-based authentication (no passwords stored)               │
│  • SERVICE user type with WORKLOAD_IDENTITY                      │
│  • Short-lived tokens (10 min expiry)                            │
│  • Supports: GitHub Actions, AWS IAM, EKS, AKS, GKE              │
└──────────────────────────────────────────────────────────────────┘
```

---

## 📋 Prerequisites

Before starting, ensure you have:

### 1. Snowflake Account Requirements
- **Account**: Snowflake Enterprise or higher
- **Cloud Provider**: AWS, Azure, or GCP (check feature availability by region)
- **Role**: `ACCOUNTADMIN` or custom role with necessary privileges:
  - CREATE DATABASE, CREATE SCHEMA, CREATE WAREHOUSE
  - CREATE TABLE, CREATE DYNAMIC TABLE, CREATE PROCEDURE
  - CREATE STREAMLIT, CREATE MODEL, CREATE NOTEBOOK
  - CREATE SNOWFLAKE INTELLIGENCE ON ACCOUNT
  - USAGE on DATABASE, SCHEMA, WAREHOUSE
- **Features**: Ensure these features are enabled:
  - Dynamic Tables
  - Interactive Warehouses (preview - select AWS regions)
  - Gen2 Warehouses (check region availability)
  - Snowflake ML (for model registry and Ray)
  - Snowpipe Streaming SDK
  - Cortex AI (Analyst, Agent, Search)

### 2. Tools & Software
- **Snowflake CLI**: Latest version for deployment
  ```bash
  # Install via pip
  pip install snowflake-cli-labs
  
  # Verify installation
  snow --version
  ```
- **Python**: 3.8 or higher (for Snowpipe Streaming, Streamlit, DBT)
- **Java**: JDK 11 or higher (optional - only for Java Snowpipe Streaming)
- **Git**: For cloning and version control

### 3. Credentials & Authentication
- **Snowflake Connection**: Configure using Snowflake CLI
  ```bash
  # Add a new connection
  snow connection add
  
  # Or use existing connection
  snow connection list
  ```
- **RSA Key Pair**: Required for Snowpipe Streaming (both Python and Java)
  - Generate key pair in PEM format (unencrypted)
  - Upload public key to Snowflake user account
  - See `snowpipe-streaming-python/README.md` for detailed instructions

### 4. Regional Feature Availability
Verify these features are available in your Snowflake region:
- **Interactive Warehouses**: Generally Available (select AWS regions)
- **Gen2 Warehouses**: [Check availability](https://docs.snowflake.com/en/user-guide/warehouses-gen2#region-availability)
- **Container Runtime** (for Ray): Required for ML training notebooks

---

## 🚀 Quick Start - One-Time Setup

### Core Setup (Required for All Demos)

**STEP 1: Grant Required Privileges (Run as ACCOUNTADMIN)**

First, grant the required Snowflake Intelligence privilege:

```sql
USE ROLE ACCOUNTADMIN;
GRANT CREATE SNOWFLAKE INTELLIGENCE ON ACCOUNT TO ROLE AUTOMATED_INTELLIGENCE;
```

**STEP 2: Run Core Infrastructure Setup**

Run this script **once** to set up shared infrastructure:

```bash
# Core infrastructure (database, schemas, warehouse, tables, dynamic tables)
snow sql -f setup.sql -c <your-connection-name>

# What this creates:
# - Database: AUTOMATED_INTELLIGENCE
# - Schemas: RAW, STAGING, DYNAMIC_TABLES, INTERACTIVE, SEMANTIC, MODELS, DBT_STAGING, DBT_ANALYTICS
# - Warehouse: AUTOMATED_INTELLIGENCE_WH (SMALL, auto-suspend 60s)
# - Tables: customers, orders, order_items, product_catalog, support_tickets, product_reviews
# - Stored procedures: generate_orders(), generate_customers()
# - Dynamic Tables: 5-tier pipeline (enriched → fact → metrics)
# - Staging procedures: merge_staging_to_raw(), enrich_raw_data()
```

**Important Notes:**
- **Why ACCOUNTADMIN?** The `CREATE SNOWFLAKE INTELLIGENCE ON ACCOUNT` privilege is an account-level privilege that controls who can create Snowflake Intelligence objects (Agents, Analysts). This ensures proper governance over AI capabilities through security controls, controlled rollout, and layered permissions (USAGE/ALTER for object access after creation).
- Replace `<your-connection-name>` with your Snowflake connection name
- This script includes a **WIPE SLATE** section that drops all existing objects
- Review the script before running if you have existing data
- The setup creates `dbt_staging` and `dbt_analytics` schemas for DBT models

### Optional: Analytical Layer Setup (DBT)

For batch analytical models (CLV, segmentation, cohorts):

```bash
cd dbt-analytics

# Install dbt-snowflake
pip install dbt-snowflake

# Install dependencies
dbt deps

# Test connection
dbt debug

# Build all models (creates tables in dbt_staging and dbt_analytics schemas)
dbt build

# Expected output: 4 staging views + 5 marts tables = 9 models
```

See `dbt-analytics/README.md` and `dbt-analytics/DEPLOYMENT.md` for detailed setup and production deployment.

### Optional: ML Training Setup

For GPU-accelerated product recommendation model in Snowflake Workspaces:

```bash
cd ml-training

# Option 1: Upload to Snowflake Workspaces
# 1. Open Snowsight > Projects > Workspaces
# 2. Create or select a workspace
# 3. Upload product_recommendation_gpu_workspace.ipynb
# 4. Attach GPU compute pool
# 5. Run all cells

# Option 2: Local development (requires GPU)
jupyter notebook product_recommendation_gpu_workspace.ipynb
```

**Prerequisites:**
- Snowflake Workspaces with GPU compute pool
- Interactive Tables populated (for training data)
- Medium or Large warehouse for data loading

See `ml-training/README.md` for detailed setup and usage.

### Optional: Snowflake Intelligence Setup

For natural language queries and semantic search:

See `snowflake-intelligence/README.md` for Cortex Agent, Cortex Search, and semantic model setup.

### Component-Specific Setup (Run Only What You Need)

Each demo has its own setup. Run only the ones you plan to use:

```bash
# Demo 1: Gen2 Warehouse Performance
snow sql -f gen2-warehouse/setup_staging_pipeline.sql -c <your-connection-name>
snow sql -f gen2-warehouse/setup_merge_procedures.sql -c <your-connection-name>
# See gen2-warehouse/README.md for details

# Demo 2: Dynamic Tables
# (No additional setup - covered by core setup.sql)

# Demo 3: Interactive Tables
snow sql -f interactive/setup_interactive.sql -c <your-connection-name>
# See interactive/README.md for details

# Demo 4: Snowpipe Streaming
# Requires RSA key generation and SDK setup
# See snowpipe-streaming-java/README.md or snowpipe-streaming-python/README.md

# Demo 5: DBT Analytics
cd dbt-analytics
dbt build  # Or use native deployment (see dbt-analytics/DEPLOYMENT.md)

# Demo 6: ML Training
# Deploy notebook to Snowflake Workspaces (see ml-training/README.md)
# Or upload to Workspaces with GPU compute pool

# Demo 7: Streamlit Dashboard
cd streamlit-dashboard
streamlit run streamlit_app.py --server.port 8501
# See streamlit-dashboard/README.md for Python environment setup and deployment

# Demo 8: Snowflake Intelligence
# See snowflake-intelligence/README.md for setup

# Demo 9: Security & Governance
snow sql -f security-and-governance/setup_west_coast_manager.sql -c <your-connection-name>
# See security-and-governance/README.md for details
```

**After core setup, pick the demos you want and run their specific setup scripts!**

---

## 📋 Demo Selection Guide

Choose demos based on your audience and time:

| Demo | Duration | Best For | Key Takeaway |
|------|----------|----------|--------------|
| **1. Snowpipe Streaming** | 10-15 min | Real-time Engineers | High-scale ingestion |
| **2. Gen2 Warehouse Performance** | 10-15 min | Data Engineers, Performance Teams | Faster MERGE/UPDATE operations |
| **3. Dynamic Tables** | 15-20 min | Data Engineers, Architects | Zero-maintenance pipelines |
| **4. Interactive Tables** | 10-15 min | App Developers, Performance Engineers | Low-latency serving |
| **5. DBT Analytics** | 10-15 min | Analytics Engineers | Batch analytical models |
| **6. ML Training** | 10-15 min | ML Engineers, Data Scientists | GPU-accelerated model training |
| **7. Streamlit Dashboard** | Continuous | Everyone | Real-time pipeline monitoring |
| **8. Snowflake Intelligence** | 10-15 min | Business Users, Analysts | Natural language queries |
| **9. Security & Governance** | 10-15 min | Security Teams, Compliance | Transparent row-level security |
| **10. Snowflake Postgres** | 10-15 min | Data Engineers, Architects | Hybrid OLTP/OLAP with Cortex Search |
| **Full Suite** | 90-120 min | Executive Demos, All-Hands | Complete end-to-end workflow |

---

## 📚 Demo Details



### DEMO 1: Snowpipe Streaming - High-Scale Ingestion

**What it demonstrates:**
- High-performance real-time ingestion
- Linear horizontal scaling (1 to 50+ parallel instances)
- Python AND Java implementations (identical functionality)

**Implementation Options:**

#### Option 1: Python (Recommended for Quick Start)
```bash
cd snowpipe-streaming-python

# Single instance
python src/automated_intelligence_streaming.py <num-orders>

# Parallel instances
python src/parallel_streaming_orchestrator.py <total-orders> <num-instances>

# Large scale
python src/parallel_streaming_orchestrator.py <total-orders> <num-instances>
```

#### Option 2: Java
```bash
cd snowpipe-streaming-java

# Build
mvn clean install

# Single instance
java -jar target/automated-intelligence-streaming-1.0.0.jar <num-orders>

# Parallel instances
java ParallelStreamingOrchestrator <total-orders> <num-instances>
```

**Performance characteristics:**
- Single instance: Fast ingestion with low latency
- Parallel instances: Linear scaling for high throughput
- Large-scale: Horizontal scaling to handle massive volumes
- Massive-scale: Achievable with sufficient parallel instances

**See:** 
- Python: `snowpipe-streaming-python/README.md`
- Java: `snowpipe-streaming-java/README.md`

---

### DEMO 2: Gen2 Warehouse Performance - Next-Generation MERGE/UPDATE Operations

**What it demonstrates:**
- Performance improvements on MERGE/UPDATE/DELETE operations
- Production-ready staging pattern: Snowpipe Streaming → Staging → MERGE → Production
- Fair benchmarking with snapshot/restore mechanism (identical data state for Gen1 vs Gen2)
- Real-world data engineering pipeline with deduplication and enrichment

**Quick start:**
```bash
# 1. Stream data to staging tables
cd snowpipe-streaming-python
python src/automated_intelligence_streaming.py --config config_staging.properties --num-orders <desired-amount>

# 2. Run Gen2 vs Gen1 comparison test
cd ../streamlit-dashboard
streamlit run streamlit_app.py --server.port 8501
# Navigate to "Next-Gen Warehouse Performance" page
# Click "Run MERGE Test using Gen 1 and Gen 2"
```

**Architecture:**
```
Snowpipe Streaming (low latency)
       ↓
staging.* tables (append-only)
       ↓
Gen2 MERGE/UPDATE (deduplicate, upsert, enrich)
       ↓
raw.* tables (production)
```

**Expected results:**

Gen2 warehouses typically show performance improvements on MERGE/UPDATE operations compared to Gen1. Specific improvements vary based on workload characteristics, data volume, and query patterns.

**Key insights:**
- Gen2 uses `RESOURCE_CONSTRAINT = 'STANDARD_GEN_2'` for optimized MERGE/UPDATE/DELETE performance
- Staging pattern enables high-throughput ingestion without blocking production queries
- Snapshot/restore ensures fair comparison: both warehouses operate on identical data state
- Production-ready: Can automate with TASK for continuous pipeline

**MERGE operations:**
- Deduplicates using `ROW_NUMBER() OVER (PARTITION BY id ORDER BY inserted_at DESC)`
- Upserts to production tables (MATCHED → UPDATE, NOT MATCHED → INSERT)

**UPDATE operations:**
- Applies business logic (discount adjustments based on order total_amount)
- Only processes recent data (last 30 days) for efficiency

**See:** `gen2-warehouse/README.md` for detailed setup, verification, troubleshooting, and automation with TASK

---

### DEMO 3: Dynamic Tables Pipeline

**What it demonstrates:**
- Incremental refresh (only process changes, not full datasets)
- Automatic dependency management (DOWNSTREAM cascading)
- Zero-maintenance orchestration (set once, runs forever)

**Quick start:**
```sql
-- Generate new orders via Snowpipe Streaming
-- See: snowpipe-streaming-java/ or snowpipe-streaming-python/

-- Manually refresh each tier (production: automatic!)
ALTER DYNAMIC TABLE enriched_orders REFRESH;
ALTER DYNAMIC TABLE fact_orders REFRESH;
ALTER DYNAMIC TABLE daily_business_metrics REFRESH;

-- Verify incremental refresh
SELECT name, refresh_action, duration_seconds
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(...));
```

**Key insight:** All refreshes show `INCREMENTAL` - only new data processed, not entire dataset!

**See:** `DEMO_SCRIPT.md` (Demo 2) for complete step-by-step guide

---

### DEMO 4: Interactive Tables & Warehouses

**What it demonstrates:**
- Low query latency under high concurrency
- Performance improvement over standard warehouses
- Complete native stack (no Redis, no external API database)

**Quick start:**
```bash
cd interactive
./demo.sh --threads <concurrent-threads> --warehouse both
```

**Sample queries displayed:**
- CUSTOMER_LOOKUP: Point lookup by customer_id
- ORDER_LOOKUP: Point lookup by order_id  
- CUSTOMER_SUMMARY: Aggregation by customer_id

**Expected results:**

Interactive warehouses provide improved query performance under high concurrency compared to standard warehouses. Results vary based on workload patterns, query complexity, and data volume.

**See:** `interactive/README.md` for complete documentation

---

### DEMO 5: DBT Analytics - Batch Analytical Models

**What it demonstrates:**
- Batch-processed analytical models in Snowflake Workspaces complementing real-time Dynamic Tables
- Customer lifetime value and segmentation
- Product affinity and recommendations
- Monthly cohort retention analysis

**Quick start:**
```bash
cd dbt-analytics

# Local development
pip install dbt-snowflake
dbt deps
dbt debug  # Test connection
dbt build  # Build all models

# Snowflake native deployment
snow dbt deploy automated_intelligence_dbt_project \
  --connection <your-connection-name> \
  --force

snow dbt execute automated_intelligence_dbt_project \
  --connection <your-connection-name> \
  --args "build --target dev"
```

**Models created:**
- **Staging** (4 views in `dbt_staging` schema): stg_customers, stg_orders, stg_order_items, stg_products
- **Customer marts** (2 tables in `dbt_analytics` schema): customer_lifetime_value, customer_segmentation
- **Product marts** (2 tables): product_affinity, product_recommendations
- **Cohort marts** (1 table): monthly_cohorts

**Key insights:**
- Complements real-time Dynamic Tables with deep analytical queries
- RFM-based customer segmentation (Recency, Frequency, Monetary)
- Market basket analysis for product recommendations
- Cohort retention tracking for growth analysis

**Integration with real-time pipeline:**
| Layer | Technology | Refresh | Purpose |
|-------|-----------|---------|---------|
| Real-Time | Dynamic Tables | 1-min lag | Operational dashboards, live metrics |
| Analytical | dbt | Daily batch | Deep analytics, ML features, segmentation |

**See:** `dbt-analytics/README.md` for model details and `dbt-analytics/DEPLOYMENT.md` for production deployment

---

### DEMO 6: ML Training - GPU-Accelerated Product Recommendations

**What it demonstrates:**
- GPU-accelerated ML model training in Snowflake Workspaces
- XGBoost product recommendation model
- Snowflake Model Registry integration
- Large-scale training (millions of samples)

**Quick start:**
```bash
cd ml-training

# Upload to Snowflake Workspaces:
# 1. Open Snowsight > Projects > Workspaces
# 2. Create or select workspace
# 3. Upload product_recommendation_gpu_workspace.ipynb
# 4. Attach GPU compute pool
# 5. Run all cells
```

**Model details:**
- **Use Case**: Predict which products customers are likely to purchase
- **Features**: Customer behavior metrics + product popularity metrics
- **Algorithm**: XGBoost with GPU acceleration (`tree_method='gpu_hist'`)
- **Training Data**: Millions of customer-product pairs
- **Model Complexity**: Deep XGBoost trees optimized for accuracy

**Expected results:**
- **Precision**: High accuracy on product recommendations
- **Recall**: Good coverage of products customers want
- **Training time**: Fast training on large datasets with GPU
- **Top features**: Customer purchase history and product popularity

**Key insights:**
- GPU acceleration significantly speeds up training on large datasets
- Model Registry enables version tracking and deployment
- Results visualized in Streamlit dashboard (ML Insights page)
- Production-ready: Schedule notebook runs for regular retraining

**See:** `ml-training/README.md` for detailed setup, configuration, and troubleshooting

### Deploying as Stored Procedure

After training, deploy the model as a stored procedure for application integration:

```bash
cd ml-training
snow sql -c <your-connection-name> -f product_recommendations_sproc.sql
```

**Usage:**
```sql
-- Get recommendations for low-engagement customers
CALL AUTOMATED_INTELLIGENCE.MODELS.GET_PRODUCT_RECOMMENDATIONS(2, 3, 'LOW_ENGAGEMENT');

-- Returns formatted string with customer-product recommendations and probabilities
```

**Integration with Cortex Agents:**
- Returns nicely formatted strings (not tables) for conversational AI
- Deterministic results for consistent recommendations
- Available segments: LOW_ENGAGEMENT, HIGH_VALUE_INACTIVE, NEW_CUSTOMERS, AT_RISK, HIGH_VALUE_ACTIVE

**See:** `ml-training/README.md` (Step 4) for complete deployment guide and Cortex Agent integration

---

### SQL Features & Reference Demos

Located in the `sql-features/`, `ai-sql-demo/`, `gen2-warehouse/`, `data-quality/`, `iceberg/`, `snowflake-intelligence/`, `ml-models/`, and `monitoring/` directories, these demos showcase the latest Snowflake SQL capabilities:

| Demo File | Feature | Description |
|-----------|---------|-------------|
| `ai-sql-demo/ai_filter_demo.sql` | AI SQL Functions | AI_FILTER and AI_CLASSIFY for intelligent data filtering |
| `snowflake-intelligence/semantic_view_sql_demo.sql` | Semantic Views | SQL-based semantic view creation (TABLES → RELATIONSHIPS → FACTS → DIMENSIONS → METRICS) |
| `gen2-warehouse/optima_indexing_demo.sql` | Optima Indexing | Automatic index creation for Gen2 warehouses |
| `sql-features/pipe_operator_demo.sql` | Pipe Operator (`->>`) | Functional SQL chaining with `$1` reference |
| `sql-features/union_by_name_demo.sql` | UNION BY NAME | Column name-based union (schema evolution friendly) |
| `sql-features/time_series_gap_filling_demo.sql` | Time Series Gap-Filling | RESAMPLE clause with INTERPOLATE_FFILL/BFILL/LINEAR |
| `sql-features/async_sql_demo.sql` | ASYNC SQL | Parallel query execution with `ASYNC()` and `AWAIT ALL` |
| `data-quality/data_quality_expectations_demo.sql` | Data Quality Expectations | Data Metric Functions for monitoring |
| `iceberg/partitioned_writes_demo.sql` | Iceberg Partitioned Writes + V3 Preview | CREATE ICEBERG TABLE with partition expressions, plus Iceberg v3 features (deletion vectors, row lineage, default values) |
| `snowflake-intelligence/cortex_analyst_routing_demo.sql` | Cortex Analyst Routing | Multi-semantic-model routing mode |
| `ml-models/huggingface_import_demo.sql` | HuggingFace Import | Import pre-trained models from HuggingFace Hub |
| `sql-features/create_or_alter_demo.sql` | CREATE OR ALTER DDL | Idempotent object management |
| `monitoring/performance_explorer_reference.sql` | Performance Explorer | Query performance analysis reference |

**Quick Start:**
```bash
# Run any demo file
snow sql -f sql-features/pipe_operator_demo.sql -c <your-connection-name>

# Or view in Snowsight worksheets
```

---

### DEMO 7: Streamlit Dashboard - Real-Time Monitoring

**What it demonstrates:**
- Real-time pipeline monitoring (live ingestion metrics)
- Interactive query performance testing
- Pipeline health status (Dynamic Tables, Interactive Tables, data freshness)

**Quick start:**
```bash
cd streamlit-dashboard

# Local development
pip install streamlit snowflake-snowpark-python pandas
streamlit run streamlit_app.py --server.port 8501

# Open browser
http://localhost:8501
```

**Dashboard features:**
- **Data Pipeline**: Gen2 warehouse performance testing and benchmarking
- **Live Ingestion**: Real-time order and item counts with trends
- **Pipeline Health**: Dynamic Tables status, data freshness
- **Query Performance**: On-demand latency testing with distribution charts
- **ML Insights**: Model metrics, feature importance, churn predictions

**Use cases:**
- Run dashboard during Snowpipe Streaming demos to show live ingestion
- Monitor pipeline health during presentations
- Test Interactive Tables performance in real-time
- Display current data volumes and trends

**Deploy to Snowflake:**
```bash
# Upload to stage
snow stage copy streamlit_app.py @AUTOMATED_INTELLIGENCE.RAW.THE_DASHBOARD_STAGE \
  --overwrite -c dash-builder-si

# Create app
CREATE STREAMLIT AUTOMATED_INTELLIGENCE.RAW.PIPELINE_DASHBOARD
  FROM '@AUTOMATED_INTELLIGENCE.RAW.THE_DASHBOARD_STAGE'
  MAIN_FILE = 'streamlit_app.py';

ALTER STREAMLIT AUTOMATED_INTELLIGENCE.RAW.PIPELINE_DASHBOARD 
  SET QUERY_WAREHOUSE = AUTOMATED_INTELLIGENCE_WH;
```

**See:** `streamlit-dashboard/README.md` for detailed documentation

---

### DEMO 8: Snowflake Intelligence - AI-Powered Conversational Analytics

**What it demonstrates:**
- Natural language queries with Cortex Agent
- Semantic model integration for business terminology
- Verified query repository (VQR) for accurate answers
- Multi-source data integration

**Quick start:**
```bash
cd snowflake-intelligence

# Upload semantic model to stage
snow stage copy business_insights_semantic_model.yaml \
  @AUTOMATED_INTELLIGENCE.RAW.SEMANTIC_MODELS \
  --overwrite -c <your-connection-name>

# Create Cortex Agent (run SQL)
CREATE OR REPLACE CORTEX AGENT AUTOMATED_INTELLIGENCE.SEMANTIC.ORDER_ANALYTICS_AGENT
  SEMANTIC_MODEL = '@AUTOMATED_INTELLIGENCE.RAW.SEMANTIC_MODELS/business_insights_semantic_model.yaml';
```

**Key features:**
- **Business terminology**: Query with terms like "revenue", "discount rate", "premium customers"
- **Verified queries**: Pre-tested SQL patterns for common questions
- **Multi-table joins**: Automatic joins across orders, customers, products
- **Date intelligence**: Handles "this month", "last quarter", "YTD" naturally

**Sample questions to ask the agent:**
```
- "What is our total revenue by customer segment?"
- "Show me discount impact on order volumes"
- "Which products are most popular with premium customers?"
- "What's our average order value trend over time?"
```

**Using the agent:**
1. Navigate to Snowsight > AI & ML > Snowflake Intelligence
2. Select `ORDER_ANALYTICS_AGENT`
3. Ask questions in natural language
4. Review generated SQL and results

**Important notes:**
- Semantic model uses **logical table names** in verified queries (e.g., `orders`, `daily_business_metrics`)
- Agent created in `SEMANTIC` schema with `AUTOMATED_INTELLIGENCE` role
- Requires `CREATE SNOWFLAKE INTELLIGENCE ON ACCOUNT` privilege

### Advanced: Custom ML Tools for Agents

**Extend Cortex Agents with trained ML models as custom tools:**

After training the product recommendation model (see DEMO 6), integrate it as a conversational tool:

```bash
# Deploy model as stored procedure
cd ml-training
snow sql -c <your-connection-name> -f product_recommendations_sproc.sql
```

**Sample conversational queries:**
```
User: "Show me product recommendations for low engagement customers"
User: "Which products should I recommend to inactive high-value customers?"
User: "Get 10 at-risk customers with their top 5 product recommendations"
```

**Agent response includes:**
- Customer IDs with their segment
- Top N product recommendations per customer
- Purchase probability for each recommendation
- Total summary (customers and recommendations count)

**Key benefits:**
- **Natural language access** to ML predictions
- **No SQL knowledge** required
- **Formatted output** perfect for business users
- **Production-ready** with deterministic results

**See:** `snowflake-intelligence/README.md` for detailed setup, semantic model customization, and troubleshooting

---

### DEMO 9: Security & Governance - Row-Based Access Control

**What it demonstrates:**
- Transparent row-level security with AI agents
- Same agent, dramatically different answers based on role
- Zero application code changes

**The setup:**

Different roles see different data based on row access policies:

| Role | States Visible | Revenue Visible | Customers Visible |
|------|---------------|-----------------|-------------------|
| **ADMIN** | All states | Full revenue | All customers |
| **WEST_COAST** | CA, OR, WA only | Regional revenue | Regional customers |

**Quick test:**
```sql
-- Window 1: Admin role
USE ROLE snowflake_intelligence_admin;
SELECT state, SUM(revenue) FROM orders GROUP BY state;
-- Shows: All states with full revenue data

-- Window 2: West Coast role
USE ROLE west_coast_manager;
SELECT state, SUM(revenue) FROM orders GROUP BY state;
-- Shows: Only CA, OR, WA states with regional revenue data
```

**Key insight:** West Coast Manager doesn't even know other states exist - filtered at database level!

**See:** `security-and-governance/README.md` for setup and agent demos

---

### DEMO 10: Snowflake Postgres - Hybrid OLTP/OLAP Architecture

**What it demonstrates:**
- Hybrid architecture: Postgres for OLTP (transactional writes), Snowflake for OLAP (analytics)
- MERGE-based sync from Postgres to Snowflake via scheduled task
- Iceberg export with automated incremental refresh (every 5 minutes)
- Cortex Search services for semantic search over synced data
- Natural language queries via Cortex Agent

**Architecture:**
```
┌─────────────────────┐      Sync task      ┌─────────────────────┐
│ SNOWFLAKE POSTGRES  │      (5 min)        │ SNOWFLAKE RAW       │
│ (managed OLTP)      │ ─────────────────►  │                     │
│                     │                     │ product_reviews     │
│ product_reviews     │                     │ support_tickets     │
│ support_tickets     │                     │                     │
└─────────────────────┘                     └──────────┬──────────┘
                                                       │
                                                       │ Sync task (5 min)
                                                       ▼
                                            ┌─────────────────────┐
                                            │ ICEBERG ON S3       │
                                            │ (open format)       │
                                            │                     │
                                            │ product_reviews     │
                                            │ support_tickets     │
                                            └──────────┬──────────┘
                                                       │
                                                       │ Reads directly
                                                       ▼
                                            ┌─────────────────────┐
                                            │ pg_lake             │
                                            │ (external Postgres) │
                                            └─────────────────────┘
```

**Quick start:**
```bash
# Setup Snowflake Postgres sync task
cd snowflake-postgres
snow sql -c dash-builder-si -f 05_create_sync_task.sql

# Setup pg_lake Iceberg tables and task
cd ../pg_lake
snow sql -c dash-builder-si -f snowflake_export.sql

# Start pg_lake (fetches latest Iceberg paths from Snowflake)
./setup.sh

# Run demo queries
PGPASSWORD=postgres psql -h localhost -p 5433 -U postgres -d postgres --pset pager=off -f demo_queries.sql
```

**Two automated tasks:**

| Task | Source → Target | Schedule |
|------|-----------------|----------|
| `POSTGRES_SYNC_TASK` | Snowflake Postgres → RAW | 5 min |
| `PG_LAKE_REFRESH_TASK` | RAW → Iceberg on S3 | 5 min |

**Verify task status:**
```sql
-- Check both tasks
SHOW TASKS LIKE 'POSTGRES_SYNC_TASK' IN SCHEMA AUTOMATED_INTELLIGENCE.POSTGRES;
SHOW TASKS LIKE 'PG_LAKE_REFRESH_TASK' IN SCHEMA AUTOMATED_INTELLIGENCE.PG_LAKE;

SELECT NAME, STATE, SCHEDULED_TIME FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE NAME IN ('POSTGRES_SYNC_TASK', 'PG_LAKE_REFRESH_TASK')
ORDER BY SCHEDULED_TIME DESC LIMIT 5;
```

**Test search services:**
```sql
-- Search product reviews
SELECT PARSE_JSON(
    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'AUTOMATED_INTELLIGENCE.SEMANTIC.PRODUCT_REVIEWS_SEARCH',
        '{"query": "quality issues with boots", "columns": ["review_title", "review_text", "rating"], "limit": 5}'
    )
)['results'] AS results;

-- Search support tickets
SELECT PARSE_JSON(
    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'AUTOMATED_INTELLIGENCE.SEMANTIC.SUPPORT_TICKETS_SEARCH',
        '{"query": "shipping delays", "columns": ["subject", "description", "priority"], "limit": 5}'
    )
)['results'] AS results;
```

**Key insights:**
- Postgres excels at OLTP (high-frequency transactional writes)
- Snowflake excels at OLAP (analytics, AI, complex queries)
- MERGE-based sync is production-realistic (vs DELETE+INSERT)
- Cortex Search enables semantic search without manual indexing

#### pg_lake: Open Lakehouse Interoperability

**The value prop:** Query Snowflake data from *any* Iceberg-compatible engine—Spark, Trino, DuckDB, or external Postgres—without ETL pipelines or data copies.

**How it works:**
1. `PG_LAKE_REFRESH_TASK` exports RAW tables to Iceberg format on S3
2. `setup.sh` dynamically queries Snowflake for latest Iceberg metadata paths
3. External Postgres (pg_lake) reads Iceberg tables directly from S3

**Why this matters:**
- **No vendor lock-in** — Data stored in open Iceberg format
- **Zero data movement** — External systems read directly from S3
- **Always fresh** — 5-minute automated refresh keeps Iceberg current
- **Any engine** — Spark, Trino, DuckDB, Postgres all read the same files

**pg_lake quick start:**
```bash
cd pg_lake

# Start external Postgres with Iceberg support
./setup.sh

# Query Snowflake data from external Postgres
PGPASSWORD=postgres psql -h localhost -p 5433 -U postgres -d postgres -c "
SELECT rating, COUNT(*) as count 
FROM product_reviews 
GROUP BY rating 
ORDER BY rating DESC;
"
```

**See:** `pg_lake/README.md` for detailed setup and architecture

---

## 🔄 Running Demos Sequentially

### Recommended Order
1. **Snowpipe Streaming** - Shows high-scale ingestion capability
2. **Gen2 Warehouse Performance** - Shows next-gen MERGE/UPDATE performance from staged data
3. **Dynamic Tables** - Shows foundational transformation pipeline
4. **Interactive Tables** - Shows performance serving layer
5. **DBT Analytics** - Shows batch analytical models (CLV, segmentation, cohorts)
6. **ML Training** - Shows GPU-accelerated model training for product recommendations
7. **Streamlit Dashboard** - Traditional BI/monitoring visualization
8. **Snowflake Intelligence** - Natural language queries via Cortex Agent
9. **Security & Governance** - Shows enterprise security with AI

### Notes for Sequential Execution
- ✅ All demos share same base database (`AUTOMATED_INTELLIGENCE`)
- ✅ Schemas: `RAW` (source data), `DYNAMIC_TABLES` (transformations), `SEMANTIC` (semantic layer), `INTERACTIVE` (serving)
- ✅ Data is additive - each demo adds more orders without breaking others
- ✅ No cleanup needed between demos
- ⚠️ For RBAC demo, switch roles to demonstrate filtering
- ⚠️ For Snowflake Intelligence, use AI & ML > Snowflake Intelligence UI

### Track Data Growth
After running all demos:

```sql
SELECT 
    'customers' AS table_name, 
    COUNT(*) AS row_count 
FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS
UNION ALL
SELECT 'orders', COUNT(*) FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS
UNION ALL
SELECT 'order_items', COUNT(*) FROM AUTOMATED_INTELLIGENCE.RAW.ORDER_ITEMS
UNION ALL
SELECT 'dynamic_table: daily_business_metrics', COUNT(*) 
FROM AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES.DAILY_BUSINESS_METRICS
UNION ALL
SELECT 'interactive: customer_order_analytics', COUNT(*) 
FROM AUTOMATED_INTELLIGENCE.INTERACTIVE.CUSTOMER_ORDER_ANALYTICS
UNION ALL
SELECT 'semantic_views', COUNT(*) 
FROM INFORMATION_SCHEMA.SEMANTIC_VIEWS 
WHERE SEMANTIC_VIEW_SCHEMA = 'SEMANTIC'
ORDER BY table_name;
```

**Current volumes after testing:**
- Customers: Growing dataset
- Orders: Multi-million order volume
- Order items: Multi-million item volume

---

## 🎯 Complete Demo Summary

After running all demos, you've demonstrated:

**Data Ingestion:**
- ✅ Snowpipe Streaming: Sub-second latency, massive-scale ready, Python or Java

**Data Transformation:**
- ✅ Gen2 Warehouses: Faster MERGE/UPDATE/DELETE operations
- ✅ Dynamic Tables: Incremental refresh, automatic dependencies, zero maintenance

**Data Serving:**
- ✅ Interactive Tables: Low-latency queries, high concurrency, no external cache

**Data Governance:**
- ✅ Row Access Policies: Transparent security, role-based filtering, agent-compatible

**ML & Analytics:**
- ✅ GPU Workspaces: GPU-accelerated model training, Model Registry integration
- ✅ DBT Analytics: Customer segmentation, product affinity, cohort analysis in Snowflake Workspaces

**AI-Powered Analytics:**
- ✅ Semantic Views: Business terminology mapping, verified queries, multi-source integration
- ✅ Cortex Agent: Natural language queries, intelligent orchestration, visualization
- ✅ Cortex Search: Semantic product discovery, description-based search

**Snowflake Capabilities Demonstrated:**
- ✅ Fully native stack - no external systems required
- ✅ Set-and-forget automation - minimal operational overhead
- ✅ Linear scalability - from thousands to millions of records
- ✅ Enterprise-grade security - built into Snowflake
- ✅ Natural language interface - business users query data without SQL

---

## 🤖 AI Observability (Optional Add-On)

### Evaluate AI-Powered Analytics Quality

Located in `agent-evaluation/`, this module provides comprehensive evaluation of RAG applications built on your streaming order data.

**What it does:**
- Creates EXTERNAL AGENT objects to track application versions
- Runs LLM-as-judge evaluations (Context Relevance, Groundedness, Answer Relevance, Correctness)
- Stores traces in `SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS`
- Visualizes results in Snowsight (AI & ML > Evaluations)

**Quick Start:**
```bash
cd agent-evaluation
./setup.sh
source venv/bin/activate
python evaluate_order_analytics.py
```

**See:** `agent-evaluation/README.md` for detailed documentation

---

## 🔧 Troubleshooting Common Issues

### Setup Issues

**Issue: Connection errors when running setup.sql**
```
Solution: Verify your Snowflake connection
- Check connection name: snow connection list
- Test connection: snow connection test -c <connection-name>
- Verify role has necessary privileges (see Prerequisites section)
```

**Issue: "Object already exists" errors during setup**
```
Solution: The setup.sql script includes a WIPE SLATE section
- Review what will be dropped (lines 19-112 in setup.sql)
- If you have existing data, back it up first
- The script drops and recreates all objects
```

**Issue: DBT schemas not created**
```
Solution: Ensure you're using the updated setup.sql
- setup.sql should create dbt_staging and dbt_analytics schemas (lines 128-129)
- Manually create if missing:
  CREATE SCHEMA IF NOT EXISTS automated_intelligence.dbt_staging;
  CREATE SCHEMA IF NOT EXISTS automated_intelligence.dbt_analytics;
```

### Snowpipe Streaming Issues

**Issue: JWT token authentication failures (Error 390144)**
```
Solution: Use Snowpipe Streaming SDK v1.0.2 (not v1.1.0)
- SDK v1.1.0 has a known JWT authentication bug
- Both Python and Java implementations require v1.0.2
- Python: pip install snowpipe-streaming==1.0.2
- Java: Update pom.xml to <snowpipe.streaming.version>1.0.2</snowpipe.streaming.version>
- See snowpipe-streaming-python/README.md or snowpipe-streaming-java/README.md for details
```

**Issue: RSA key authentication failures**
```
Solution: Verify RSA key pair setup
1. Check key format (must be PEM, unencrypted)
2. Verify public key uploaded to Snowflake user:
   DESC USER <username>;
   -- Check RSA_PUBLIC_KEY_FP field
3. Ensure private key path in config is correct
4. Verify account identifier uses hyphens not underscores (e.g., gen-ai-hol, not gen_ai_hol)
5. Add role field to profile.json with appropriate role
6. See snowpipe-streaming-python/README.md for detailed setup
```

**Issue: "Channel not found" or connection errors**
```
Solution: Verify target tables exist
- Tables must exist before streaming
- Check table names in config match actual tables
- Verify role has INSERT privilege on target tables
```

### Gen2 Warehouse Issues

**Issue: Gen2 warehouse creation fails**
```
Solution: Check region availability
- Gen2 warehouses not available in all regions
- See: https://docs.snowflake.com/en/user-guide/warehouses-gen2#region-availability
- Use standard warehouse if Gen2 not available (performance gains won't apply)
```

**Issue: Snapshot/restore procedures fail**
```
Solution: Verify staging tables exist
- Run gen2-warehouse/setup_staging_pipeline.sql first
- Check tables: staging.orders_staging, staging.order_items_staging
- Verify staging.discount_snapshot table exists
```

### Interactive Warehouses Issues

**Issue: Interactive warehouse creation fails**
```
Solution: Check region availability
- Interactive warehouses are GA in select AWS regions only
- Check https://docs.snowflake.com/en/user-guide/interactive.html#label-interactive-region-availability
- Skip this demo if not available in your region
```

**Issue: Queries timeout at 5 seconds**
```
Solution: This is by design
- Interactive warehouses have fixed 5-second timeout
- Cannot be increased
- Optimize queries or use standard warehouses for complex queries
```

### ML Training Issues

**Issue: GPU compute pool not available**
```
Solution: Check workspace configuration
- Verify GPU compute pool is created and running
- Contact Snowflake support if GPU features not enabled
- Can run on CPU by changing tree_method to 'hist'
```

**Issue: Notebook fails to load data**
```
Solution: Verify execution context
- Ensure database and schema are set correctly
- Check warehouse is running and accessible
- Use fully qualified table names
```

**Issue: Model not appearing in registry**
```
Solution: Check schema permissions
- MODELS schema must exist (created by setup.sql)
- Grant CREATE MODEL privilege to your role
- Check model name: SELECT * FROM INFORMATION_SCHEMA.MODEL_VERSIONS;
```

### DBT Issues

**Issue: dbt deps fails**
```
Solution: Check internet connectivity and packages
- Verify packages.yml exists
- Try: dbt clean && dbt deps
- Check proxy settings if behind firewall
```

**Issue: "Relation does not exist" errors**
```
Solution: Verify source tables exist
- Run core setup.sql first
- Check: SELECT * FROM automated_intelligence.raw.orders LIMIT 1;
- Verify connection profile points to correct database
```

**Issue: All customers show as high_value**
```
Solution: Adjust thresholds in dbt_project.yml
- high_value_threshold: Configurable based on your data distribution
- active_customer_days: Configurable based on your business logic
- Rebuild models: dbt run --select customer_lifetime_value customer_segmentation
```

### Streamlit Dashboard Issues

**Issue: Connection errors in Streamlit**
```
Solution: Check environment variables or connection config
- If local: Ensure SNOWFLAKE_CONNECTION_NAME env var set
- If deployed: Verify connection in Snowsight
- Check warehouse exists and is accessible
```

**Issue: "Table does not exist" errors**
```
Solution: Verify all components are set up
- Run core setup.sql
- Run component-specific setup scripts
- Check table exists: SHOW TABLES IN automated_intelligence.raw;
```

**Issue: ML Insights page shows no models**
```
Solution: Train ML model first
- Deploy and run ml-training/customer_churn_training.ipynb
- Verify model exists: SELECT * FROM INFORMATION_SCHEMA.MODEL_VERSIONS;
- Model must be in AUTOMATED_INTELLIGENCE.MODELS schema
```

### Performance Issues

**Issue: Dynamic Tables not refreshing**
```
Solution: Check target lag and refresh schedule
- Verify lag: SELECT GET_DDL('TABLE', 'automated_intelligence.dynamic_tables.enriched_orders');
- Check last refresh: SELECT * FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(...));
- Manual refresh: ALTER DYNAMIC TABLE enriched_orders REFRESH;
```

**Issue: Queries running slow**
```
Solution: Multiple factors
- Check warehouse size (may need to scale up)
- Verify clustering keys on large tables
- Check query profile in Snowsight for bottlenecks
- For Interactive Tables, ensure using interactive warehouse
```

### Data Quality Issues

**Issue: Product categories don't match product names**
```
Solution: Old data may have this issue
- Fixed in setup.sql (lines 181-216)
- Generate fresh data: CALL automated_intelligence.raw.generate_orders(<num-orders>);
- New data will have consistent product relationships
```

**Issue: Referential integrity violations**
```
Solution: Fixed in current version
- Update to latest setup.sql
- Stored procedures now generate consistent data
- Verify: Run tests/test_data_quality.sql
```

### General Tips

1. **Check Snowflake CLI version**: `snow --version` (update if old)
2. **Verify role privileges**: Use ACCOUNTADMIN or role with full privileges
3. **Review object dependencies**: Use GET_DDL() to see object definitions
4. **Check query history**: SELECT * FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY()) for errors
5. **Monitor costs**: Review warehouse credit usage if running large-scale tests

For component-specific issues, see the README in each subdirectory.

---

## 📁 Project Structure

```
automated-intelligence/
├── setup.sql                   # Core setup script (run this first!)
│
├── tests/                      # Test notebooks and tutorials
│   ├── test_ai_functions.ipynb      # Interactive AI functions tutorial
│   ├── test_dynamic_tables.ipynb    # Dynamic Tables deep dive tutorial
│   ├── test_data_quality.sql        # Data quality validation
│   └── test_data_quality.ipynb      # Interactive DQ notebook
│
├── dbt-analytics/              # DBT analytical layer (batch processing)
│   ├── dbt_project.yml         # DBT project configuration
│   ├── profiles.yml            # Connection profile (uses env vars)
│   ├── models/
│   │   ├── staging/            # Staging views (stg_customers, stg_orders, etc.)
│   │   └── marts/              # Analytical marts
│   │       ├── customer/       # CLV, segmentation
│   │       ├── product/        # Affinity, recommendations
│   │       └── cohort/         # Retention analysis
│   └── README.md               # DBT setup and usage guide
│
├── snowflake-intelligence/     # Cortex AI & Analyst (component-specific setup)
│   ├── business_insights_semantic_model.yaml  # Semantic model definition
│   ├── semantic_view_sql_demo.sql             # SQL-based semantic view creation demo
│   ├── cortex_analyst_routing_demo.sql        # Cortex Analyst routing mode demo
│   ├── create_semantic_model_stage.sql        # Stage for semantic model YAML
│   ├── create_agent.sql                       # Cortex Agent for NL queries
│   └── create_cortex_search.sql               # Cortex Search for product discovery
│
├── gen2-warehouse/             # Gen2 Warehouse (component-specific setup)
│   ├── setup_staging_pipeline.sql    # Staging schema, tables, Gen2 WH
│   ├── setup_merge_procedures.sql    # MERGE/UPDATE procedures with benchmarking
│   ├── optima_indexing_demo.sql      # Optima automatic indexing demo
│   └── README.md               # Gen2 setup and demo instructions
│
├── sql-features/               # SQL Feature Demos (latest Snowflake capabilities)
│   ├── pipe_operator_demo.sql        # Pipe operator (->> with $1) demo
│   ├── union_by_name_demo.sql        # UNION BY NAME demo
│   ├── time_series_gap_filling_demo.sql  # RESAMPLE/interpolation demo
│   ├── async_sql_demo.sql            # ASYNC/AWAIT SQL demo
│   └── create_or_alter_demo.sql      # CREATE OR ALTER DDL demo
│
├── ai-sql-demo/                # AI SQL Functions
│   └── ai_filter_demo.sql            # AI_FILTER and AI_CLASSIFY demo
│
├── data-quality/               # Data Quality Features
│   └── data_quality_expectations_demo.sql  # Data Metric Functions demo
│
├── iceberg/                    # Iceberg Table Features
│   └── partitioned_writes_demo.sql   # Iceberg partitioned writes + v3 preview (deletion vectors, row lineage)
│
├── ml-models/                  # ML Model Features
│   └── huggingface_import_demo.sql   # HuggingFace model import demo
│
├── monitoring/                 # Observability & Performance
│   └── performance_explorer_reference.sql  # Performance Explorer reference
│
├── interactive/                # Demo 3: Interactive Tables (component-specific setup)
│   ├── setup_interactive.sql   # Interactive tables and warehouse
│   ├── demo.sh                 # Main demo script
│   ├── load_test_interactive.py
│   ├── realtime_demo.py
│   └── README.md
│
├── snowpipe-streaming-python/  # Demo 4: Python implementation (component-specific setup)
│   ├── src/
│   │   ├── automated_intelligence_streaming.py
│   │   ├── parallel_streaming_orchestrator.py
│   │   ├── models.py
│   │   └── data_generator.py
│   ├── config_default.properties     # Default config (RAW schema)
│   ├── config_staging.properties      # Staging target config
│   ├── profile_staging.json.template  # Staging credentials template
│   ├── requirements.txt
│   └── README.md               # SDK setup and configuration instructions
│
├── snowpipe-streaming-java/    # Demo 4: Java implementation (component-specific setup)
│   ├── src/
│   ├── config_default.properties     # Default config (RAW schema)
│   ├── config_staging.properties      # Staging target config
│   ├── pom.xml
│   └── README.md               # SDK setup and configuration instructions
│
├── security-and-governance/    # Demo 5: RBAC (component-specific setup)
│   ├── setup_west_coast_manager.sql
│   ├── cleanup_west_coast_manager.sql
│   └── README.md
│
├── streamlit-dashboard/        # Demo 6: Real-time monitoring (component-specific setup)
│   ├── streamlit_app.py        # Main dashboard app
│   ├── pages/
│   │   ├── 1_data_pipeline.py  # Gen2 warehouse performance page
│   │   ├── 2_live_ingestion.py
│   │   ├── 3_pipeline_health.py
│   │   ├── 4_query_performance.py
│   │   ├── 5_ml_insights.py
│   │   └── 6_summary.py
│   ├── environment.yml         # Snowflake dependencies
│   └── README.md               # Streamlit setup and deployment
│

├── README.md                   # This file - Overview and quick start
└── script.md                   # Complete demo guide with talking points
```

---

## 🧹 Cleanup (After All Demos)

If you want to reset for another demo session:

```sql
-- Optional: Drop and recreate everything
DROP DATABASE automated_intelligence CASCADE;
DROP ROW ACCESS POLICY IF EXISTS automated_intelligence.raw.customers_region_policy;
DROP ROLE IF EXISTS west_coast_manager;
```

Or keep the structure and just add more data:

```sql
-- Add more orders via Snowpipe Streaming
-- See: snowpipe-streaming-java/ or snowpipe-streaming-python/
```

---

## 📚 Additional Resources

### Setup & Configuration
- **Prerequisites**: Snowflake account requirements, tools, credentials (see Prerequisites section above)
- **Setup Scripts**: `setup.sql` (core infrastructure), component-specific scripts
- **Connection Guide**: Snowflake CLI configuration for your connection

### Demo Guides
- **DEMO_SCRIPT.md** - Complete demo guide with talking points for all demos
- **gen2-warehouse/README.md** - Gen2 warehouse performance demo and setup
- **interactive/README.md** - Interactive Tables deep dive
- **ml-training/README.md** - Ray ML training setup and usage
- **dbt-analytics/README.md** - DBT setup and model details
- **dbt-analytics/DEPLOYMENT.md** - Production DBT deployment guide
- **snowpipe-streaming-python/README.md** - Python implementation guide

- **snowpipe-streaming-java/README.md** - Java implementation guide
- **security-and-governance/README.md** - RBAC setup and examples
- **streamlit-dashboard/README.md** - Dashboard deployment and usage
- **snowflake-intelligence/README.md** - Cortex Agent, Analyst, Search setup

### Technical Documentation
- **Gen2 Warehouses**: SQL scripts for staging pipeline and MERGE procedures with benchmarking
- **Dynamic Tables**: SQL scripts and validation queries
- **Interactive Tables**: Performance benchmarks and best practices
- **Snowpipe Streaming**: Configuration, scaling patterns, troubleshooting
- **ML Training**: Ray cluster configuration, model hyperparameters, troubleshooting
- **DBT Analytics**: Model schemas, tests, materialization strategies

---

## ⚠️ Important Notes

### Dynamic Tables - Manual vs Scheduled Refresh

| Refresh Type | Cascades to DOWNSTREAM? | When Used |
|--------------|-------------------------|-----------|
| **Manual** | ❌ No - Must refresh each tier | Demos, testing, emergencies |
| **Scheduled** | ✅ Yes - Auto-cascades | Production (automatic) |

**In demos:** We manually refresh Tier 1 → Tier 2 → Tier 3 to show the flow step-by-step.

**In production:** Tier 1's scheduled refresh automatically triggers Tier 2 → Tier 3. Zero manual intervention!

### Dynamic Tables - Configuration & Data Freshness

#### 3-Tier Architecture

**Layer 1: Base Enrichment** (1 minute lag)
- `enriched_orders`: `TARGET_LAG = '1 minute'`
- `enriched_order_items`: `TARGET_LAG = '1 minute'`
- Reads from raw tables populated by Snowpipe Streaming

**Layer 2: Fact Tables** (Downstream)
- `fact_orders`: `TARGET_LAG = DOWNSTREAM`
- Refreshes immediately after Layer 1

**Layer 3: Metrics** (Downstream)
- `daily_business_metrics`: `TARGET_LAG = DOWNSTREAM`
- `product_performance_metrics`: `TARGET_LAG = DOWNSTREAM`
- Refreshes immediately after Layer 2

#### Data Freshness Flow
```
Snowpipe Streaming (sub-second)
    ↓
raw.orders, raw.order_items
    ↓ (1 minute lag)
enriched_orders, enriched_order_items
    ↓ (DOWNSTREAM = immediate)
fact_orders
    ↓ (DOWNSTREAM = immediate)
daily_business_metrics, product_performance_metrics
```

**Total end-to-end latency: ~1-2 minutes from ingestion to analytics**

#### Default Configuration: Real-Time (1 Minute)

⚡ **Automatically applied by setup.sql** - No additional steps needed!

**Benefits:**
- Dashboard updates within 1-2 minutes
- Ideal for live demos and operational monitoring
- Only Layer 1 actively polls (Layers 2-3 cascade automatically)

**Cost:**
- ~1,440 warehouse refreshes/day (60/hour × 24 hours)
- Warehouse active ~1 minute per refresh
- **720x more credits** than 12-hour batch processing

#### Alternative: Batch Processing (12 Hours)

For lower costs in production:
```sql
ALTER DYNAMIC TABLE enriched_orders SET TARGET_LAG = '12 hours';
ALTER DYNAMIC TABLE enriched_order_items SET TARGET_LAG = '12 hours';
-- Downstream tables automatically adjust (still DOWNSTREAM)
```

**Cost difference:** 2 refreshes/day vs 1,440 refreshes/day

#### When to Use Each Configuration

| Use Case | Recommended Lag |
|----------|----------------|
| Live operational dashboard | 1 minute |
| Real-time fraud detection | 1 minute |
| Customer service tools | 1 minute |
| Executive daily reports | 12 hours |
| Weekly business reviews | 12 hours |
| Cost optimization | 12 hours |

#### Verify Your Configuration
```bash
for table in enriched_orders enriched_order_items fact_orders daily_business_metrics product_performance_metrics; do
  echo "=== $table ==="
  snow sql -c dash-builder-si --role snowflake_intelligence_admin -q \
    "SELECT GET_DDL('TABLE', 'automated_intelligence.dynamic_tables.$table');" | grep target_lag
done
```

### Interactive Warehouses

- ⚠️ **5-second query timeout** (cannot be increased)
- ⚠️ **Always-on billing** (no auto-suspend by design)
- ✅ **Generally Available** (GA since Dec 2025, select AWS regions)

### Snowpipe Streaming

- Requires RSA key-pair authentication (PEM format)
- Python SDK is Rust-backed for high performance
- Both Python and Java deliver identical functionality and performance

### Gen2 Warehouses

- 10-40% performance improvements for MERGE/UPDATE/DELETE operations
- Create with `RESOURCE_CONSTRAINT = 'STANDARD_GEN_2'`
- Region availability: Check https://docs.snowflake.com/en/user-guide/warehouses-gen2#region-availability
- Snapshot/restore pattern ensures fair benchmarking (identical data state)

---

## 🎓 Learning Path

**New to the demos?** Follow this sequence:

1. **Start with setup** - Run all setup scripts once
2. **Demo 4: Snowpipe Streaming** - Scale ingestion to millions
3. **Demo 1: Gen2 Warehouse Performance** - See next-gen MERGE/UPDATE operations
4. **Demo 2: Dynamic Tables** - Understand the transformation layer
5. **Demo 3: Interactive Tables** - See the serving layer in action
6. **Demo 5: Security & Governance** - Lock down with row-level security
7. **Optional: AI Observability** - Evaluate AI analytics quality

**For executives:** Run the Full Suite (45-60 min) to show complete end-to-end capabilities.

**For technical teams:** Deep dive into specific demos based on their domain (data engineering, app development, security, etc.)

---

**Remember: After one-time setup, all demos work independently and can be run in any order!** 🚀
