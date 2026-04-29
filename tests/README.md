# Tests & Tutorials

This directory contains test notebooks and SQL scripts for validating and learning about features in the automated intelligence platform.

## Files

### AI Functions Examples
- `test_ai_functions.ipynb` - Interactive notebook demonstrating Cortex AI functions

**Uses tables:** `product_reviews`, `support_tickets`, `product_catalog` (all created in `setup.sql`)

**Features demonstrated:**
- `SNOWFLAKE.CORTEX.AI_SENTIMENT()` - Sentiment analysis on product reviews
- `SNOWFLAKE.CORTEX.AI_AGG()` - Aggregate and summarize reviews
- `SNOWFLAKE.CORTEX.AI_COMPLETE()` - Generate content (marketing pitches, classifications)
- `SNOWFLAKE.CORTEX.AI_EXTRACT()` - Extract structured data from text
- `CORTEX.SEARCH_PREVIEW()` - Product search demonstrations

**Additional AI SQL functions available (Build 2025+):**
- `AI_REDACT()` - Redact sensitive PII data from documents
- `AI_TRANSCRIBE()` - Transcribe audio/video and translate between languages
- `AI_CLASSIFY()` - Classify text or images into user-defined categories
- `AI_EMBED()` - Generate embedding vectors for similarity search
- `AI_SIMILARITY()` - Calculate embedding similarity between inputs

### Dynamic Tables Deep Dive
- `test_dynamic_tables.ipynb` - Interactive tutorial on Dynamic Tables incremental refresh

**Demonstrates:**
- Step-by-step data flow through 3-tier pipeline
- Incremental refresh proof (only changed rows processed)
- Manual vs scheduled refresh behavior
- DOWNSTREAM dependency cascading
- Production deployment patterns

**Perfect for:** Understanding Dynamic Tables internals before deploying to production

### Data Quality Testing
- `test_data_quality.sql` - SQL-based data quality tests
- `test_data_quality.ipynb` - Interactive data quality validation notebook

**Tests:**
- Data Monitoring Framework (DMF) alerts
- Constraint validation
- Data quality rules
- Pipeline health checks

## Usage

### Run SQL Tests
```bash
# Data quality tests
snow sql -f tests/test_data_quality.sql -c dash-builder-si
```

### Run Notebooks
```bash
# Launch Jupyter
jupyter notebook tests/

# Open any .ipynb file
# - test_dynamic_tables.ipynb for Dynamic Tables tutorial
# - test_ai_functions.ipynb for AI functions
# - test_data_quality.ipynb for data quality checks
```

## Prerequisites

Core setup must be completed first:
```bash
snow sql -f setup.sql -c dash-builder-si
```

This creates all tables, functions, and infrastructure used in these tests.

## Note

⚠️ **These are supplementary learning materials** beyond what the Streamlit dashboard provides.

The dashboard shows:
- ✅ Dynamic Tables status and refresh history
- ✅ ML model performance
- ✅ Pipeline health monitoring

These examples show:
- 📚 AI functions not demonstrated in the dashboard
- 📚 Step-by-step Dynamic Tables mechanics
- 📚 Data quality validation techniques
