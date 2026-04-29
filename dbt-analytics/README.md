# DBT Analytics for Automated Intelligence

Complementary analytical layer using dbt (data build tool) for batch-processed analytical models on top of the real-time Dynamic Tables pipeline.

## Architecture

This dbt project provides **analytical marts** that complement (not duplicate) the real-time Dynamic Tables:

### Real-Time Tier (Dynamic Tables)
- `enriched_orders` - 1-minute lag enrichment
- `fact_orders` - Real-time aggregated facts
- `daily_business_metrics` - Real-time operational metrics

### Analytical Tier (dbt - batch/daily)
- **Staging Models** (views) - Lightweight transformations
- **Customer Marts** (tables) - Deep customer analytics
- **Product Marts** (tables) - Product intelligence
- **Cohort Marts** (tables) - Retention analysis

## Models

### Staging Layer (`models/staging/`)
Base views with minimal transformations:

- `stg_customers` - Customer master data with derived fields
- `stg_orders` - Orders with aggregated line items
- `stg_order_items` - Order items enriched with product data
- `stg_products` - Product catalog with margin calculations

### Customer Analytics (`models/marts/customer/`)

#### `customer_lifetime_value`
Calculates comprehensive customer value metrics:
- Total revenue, orders, average order value
- RFM scores (Recency, Frequency, Monetary)
- Customer status (active, at_risk, churned)
- Value tiers (high, medium, low)
- Estimated annual value projections

#### `customer_segmentation`
Groups customers into actionable segments:
- Behavioral segments (champions, loyal, at_risk, lost, etc.)
- Recommended marketing actions per segment
- Segment priority for resource allocation
- RFM-based classification

### Product Analytics (`models/marts/product/`)

#### `product_affinity`
Market basket analysis identifying product relationships:
- Products frequently purchased together
- Confidence scores (P(B|A))
- Lift scores (how much more likely than random)
- Support metrics (% of orders)
- Affinity strength classification

#### `product_recommendations`
Actionable product recommendations:
- Top 10 recommendations per product
- Bi-directional relationships (A→B and B→A)
- Cross-category indicators
- Confidence levels
- Recommendation messages for UI

### Cohort Analytics (`models/marts/cohort/`)

#### `monthly_cohorts`
Tracks customer cohorts by signup month:
- Retention rates over time
- Revenue per cohort
- Monthly churn rates
- Cumulative LTV estimates
- Cohort health classification

## Configuration

### Variables (`dbt_project.yml`)
```yaml
vars:
  lookback_days: 90              # Historical analysis window
  high_value_threshold: 1000     # High-value customer threshold
  active_customer_days: 90       # Active customer definition
```

### Materialization Strategy
- **Staging models**: Views (fast refresh, minimal storage)
- **Marts**: Tables (optimized for queries)

### Schema Layout
- `dbt_staging` - Staging layer views (dbt-managed)
- `dbt_analytics` - Analytical marts tables (dbt-managed)
- Clear separation from real-time schemas: `raw`, `staging`, `dynamic_tables`, `interactive`

## Setup

### Prerequisites
1. Snowflake account with `AUTOMATED_INTELLIGENCE` role and necessary privileges
2. Database and schemas created (`dbt_staging`, `dbt_analytics`)
3. Raw data tables populated in `automated_intelligence.raw` schema with segment-based orders (Premium, Standard, Basic)
4. Snowflake CLI installed (for deployment) - [Installation Guide](https://docs.snowflake.com/en/developer-guide/snowflake-cli/index)

### Deployment Options

This dbt project follows [dbt Projects on Snowflake](https://docs.snowflake.com/en/user-guide/data-engineering/dbt-projects-on-snowflake) best practices and can be deployed as a **DBT PROJECT** object in Snowflake.

**See [DEPLOYMENT.md](DEPLOYMENT.md) for comprehensive deployment guide with:**
- Snowflake CLI deployment (recommended)
- SQL-based deployment
- Snowsight workspace deployment
- Scheduling with Snowflake tasks
- Monitoring and observability

### Quick Start (Local Development)

For local development and testing:

```bash
cd dbt-analytics

# Install dbt-snowflake (if not already installed)
pip install dbt-snowflake

# Install dependencies
dbt deps

# Test connection
dbt debug

# Run models
dbt run --target dev

# Run tests
dbt test
```

### Quick Start (Snowflake Native Deployment)

Deploy as a native Snowflake object:

```bash
cd dbt-analytics

# Deploy the dbt project object
snow dbt deploy automated_intelligence_dbt_project \
  --connection dash-builder-si \
  --force

# Install dependencies
snow dbt execute automated_intelligence_dbt_project \
  --connection dash-builder-si \
  --args "deps" \
  --external-access-integration dbt_ext_access

# Run the project
snow dbt execute automated_intelligence_dbt_project \
  --connection dash-builder-si \
  --args "build --target dev"
```

### Initial Build
```bash
# Build everything (local)
dbt build

# Build specific models (local)
dbt run --select stg_customers
dbt run --select customer_lifetime_value+

# Build by tag (local)
dbt run --select tag:customer
dbt run --select tag:product
```

For production deployment to Snowflake, see **[DEPLOYMENT.md](DEPLOYMENT.md)**.

## Usage

### Common Commands
```bash
# Run all models
dbt run

# Run specific mart
dbt run --select marts.customer

# Test data quality
dbt test

# Generate documentation
dbt docs generate
dbt docs serve

# Freshen specific model
dbt run --select customer_segmentation
```

### Querying Results
```sql
-- Customer segments
SELECT 
    behavioral_segment,
    COUNT(*) as customer_count,
    SUM(total_revenue) as segment_revenue
FROM automated_intelligence.dbt_analytics.customer_segmentation
GROUP BY behavioral_segment
ORDER BY segment_revenue DESC;

-- Product recommendations
SELECT 
    source_product_name,
    recommended_product_name,
    confidence,
    lift,
    recommendation_message
FROM automated_intelligence.dbt_analytics.product_recommendations
WHERE source_product_id = 'PROD_001'
ORDER BY recommendation_rank;

-- Cohort retention
SELECT 
    cohort_month,
    months_since_signup,
    retention_rate,
    cohort_health
FROM automated_intelligence.dbt_analytics.monthly_cohorts
WHERE cohort_month >= '2024-01-01'
ORDER BY cohort_month, months_since_signup;
```

## Development

### Adding New Models
1. Create SQL file in appropriate directory
2. Add tests in schema.yml
3. Update this README
4. Run `dbt run --select <model_name>`

### Testing
```bash
# Run all tests
dbt test

# Test specific model
dbt test --select customer_lifetime_value

# Test sources
dbt test --select source:*
```

## Scheduling

### Local/Traditional Deployment
See [DEPLOYMENT.md](DEPLOYMENT.md#scheduling--automation) for comprehensive scheduling options.

### Production Deployment with Snowflake Tasks

**Option 1: Simple Daily Refresh**
```sql
CREATE OR REPLACE TASK automated_intelligence.dbt_staging.dbt_daily_refresh
  WAREHOUSE = automated_intelligence_wh
  SCHEDULE = 'USING CRON 0 2 * * * America/Los_Angeles'
AS
  EXECUTE DBT PROJECT automated_intelligence.dbt_staging.automated_intelligence_dbt_project
    ARGS = 'run --target prod';

ALTER TASK automated_intelligence.dbt_staging.dbt_daily_refresh RESUME;
```

**Option 2: Orchestration Tool (Airflow/etc.)**
```python
from airflow.operators.bash import BashOperator

dbt_run = BashOperator(
    task_id='dbt_run',
    bash_command='cd /path/to/dbt-analytics && dbt run',
    dag=dag
)
```

## Integration with Real-Time Pipeline

The dbt models read from the same `raw` schema as Dynamic Tables but serve different purposes:

| Layer | Technology | Refresh | Purpose |
|-------|-----------|---------|---------|
| Real-Time | Dynamic Tables | 1-min lag | Operational dashboards, live metrics |
| Analytical | dbt | Daily batch | Deep analytics, ML features, segmentation |

Both layers can coexist and complement each other - use Dynamic Tables for up-to-the-minute metrics and dbt for complex analytical queries.

## Best Practices

1. **Incremental Models**: For large datasets, consider incremental materialization
2. **Testing**: Add tests for all primary keys and critical business logic
3. **Documentation**: Document all models, columns, and business logic
4. **Modularity**: Use CTEs and refs to keep SQL readable
5. **Performance**: Monitor query performance and add appropriate clustering keys

## Troubleshooting

### Common Issues

**Connection errors**:
```bash
# Verify connection
dbt debug

# Check profiles.yml location
echo $DBT_PROFILES_DIR
```

**Model failures**:
```bash
# Run with verbose logging
dbt run --select <model> --debug

# Compile SQL without running
dbt compile --select <model>
```

**Source not found**:
```bash
# Test source connections
dbt test --select source:*
```

## Resources

- [dbt Documentation](https://docs.getdbt.com/)
- [dbt Snowflake Profile](https://docs.getdbt.com/docs/core/connect-data-platform/snowflake-setup)
- [dbt Best Practices](https://docs.getdbt.com/guides/best-practices)
