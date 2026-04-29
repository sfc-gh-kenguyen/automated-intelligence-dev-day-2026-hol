# Real-Time Data Pipeline Dashboard

A Streamlit dashboard that monitors Snowpipe Streaming ingestion and Interactive Tables performance in real-time.

## Features

### 📊 Live Ingestion Monitoring
- Real-time order volume tracking with segment-based analytics
- Ingestion rate (orders/hour)
- 24-hour trend visualization
- Recent orders sample view with discount tracking
- Order distribution by customer segment (Premium, Standard, Basic)

### ⚡ Query Performance Testing
- Interactive Tables performance benchmarking
- Real-time latency measurements (avg, min, max, P95)
- Query distribution visualization
- Popular query pattern analysis

### 🏥 Pipeline Health Monitoring
- Dynamic Tables status tracking
- Interactive Tables health checks
- Data freshness indicators
- End-to-end pipeline visibility
- Discount data availability tracking

### 💰 Business Analytics
- Revenue analysis with discount impact
- Segment-based order patterns
- Discount penetration metrics (now available after merge_staging_to_raw update)

## Quick Start

### Local Development

1. **Install dependencies:**
   ```bash
   cd streamlit-dashboard
   pip install streamlit snowflake-snowpark-python pandas
   ```

2. **Configure connection:**
   Create `.streamlit/secrets.toml`:
   ```toml
   [default]
   connection_name = "dash-builder-si"
   ```

3. **Run locally:**
   ```bash
   streamlit run streamlit_app.py --server.port 8501
   ```

4. **Open in browser:**
   http://localhost:8501

### Deploy to Snowflake

1. **Deploy using Snowflake CLI:**
   ```bash
   snow streamlit deploy the_dashboard --replace -c dash-builder-si
   ```
   
   Note: This uses the `snowflake.yml` project definition file to configure the app's database, schema, warehouse, and other settings.

2. **Get app URL:**
   ```bash
   snow streamlit get-url AUTOMATED_INTELLIGENCE.RAW.THE_DASHBOARD -c dash-builder-si
   ```

## Dashboard Tabs

### 1. Live Ingestion
Shows real-time data ingestion metrics:
- Total orders, order items, and customers
- Recent ingestion rate (last hour)
- 24-hour ingestion trend line chart
- Sample of most recent orders (advanced mode)

**Queries:**
- Row counts from RAW tables
- Hourly aggregation for trend visualization
- Recent orders filtered by timestamp

### 2. Query Performance
Interactive performance testing:
- Run on-demand performance tests (10 queries)
- Measures query latency against Interactive Tables
- Shows latency distribution chart
- Displays popular query patterns by order status

**Test queries:**
- Point lookups by customer_id
- Aggregations (COUNT, SUM)
- Random customer selection for realistic testing

### 3. Pipeline Health
End-to-end health monitoring:
- Dynamic Tables status (ACTIVE/INACTIVE)
- Last refresh timestamps
- Interactive Tables row counts
- Data freshness indicators

**Health checks:**
- Dynamic Tables scheduling state
- Interactive Tables population status
- Minutes since last data update
- Green/yellow/red status indicators

## Configuration

### Sidebar Controls
- **Refresh interval**: 1-30 seconds (local dev only)
- **Show advanced metrics**: Toggle detailed views
- **Auto-refresh**: Enabled for local development

### Connection
The app uses standard Snowpark connection pattern with the `AUTOMATED_INTELLIGENCE` role:
- **Snowflake deployment**: `get_active_session()` (automatic)
- **Local development**: `Session.builder.config('connection_name', 'default')`
- **Role**: Uses `AUTOMATED_INTELLIGENCE` role for all queries

## Use Cases

### During Snowpipe Streaming Demo
1. Start the dashboard before running ingestion
2. Run parallel streaming orchestrator:
   ```bash
   cd ../snowpipe-streaming-python
   python src/parallel_streaming_orchestrator.py 1000000 5
   ```
3. Watch live metrics update in dashboard
4. Show 24-hour trend chart filling in real-time
5. Observe segment-based order distribution (Premium, Standard, Basic)
6. Use "MERGE and UPDATE" button to move staging data to production
7. Check discount impact analysis after merge completes

### During Interactive Tables Demo
1. Open dashboard to show current data volume
2. Run load test:
   ```bash
   cd ../interactive
   ./demo.sh --threads 150 --warehouse both
   ```
3. Use dashboard's "Run Performance Test" button
4. Compare P95 metrics with load test results

### Continuous Monitoring
- Leave dashboard running during presentations
- Auto-refresh keeps metrics current
- Health tab shows any pipeline issues
- Data freshness indicator catches stale data

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  Streamlit Dashboard (This App)                     │
│  • Queries Snowflake every N seconds               │
│  • Shows real-time metrics and trends              │
└─────────────────────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────┐
│  Data Sources                                       │
│  • RAW.ORDERS (Snowpipe Streaming)                 │
│  • RAW.ORDER_ITEMS (Snowpipe Streaming)            │
│  • DYNAMIC_TABLES.* (Transformations)              │
│  • INTERACTIVE.* (Serving Layer)                   │
└─────────────────────────────────────────────────────┘
```

## Performance Notes

- **Query execution**: All queries run through Snowpark session
- **Refresh rate**: Configurable 1-30 seconds (local only)
- **Auto-refresh**: Disabled in Snowflake deployment
- **Caching**: No caching - always shows fresh data
- **Connection**: Single session reused across reruns

## Troubleshooting

### Local Development

**Connection issues:**
```bash
# Check connection configuration
snow connection test -c dash-builder-si

# Verify warehouse is running
snow sql -q "SHOW WAREHOUSES" -c dash-builder-si
```

**Port already in use:**
```bash
# Find process using port 8501
lsof -i :8501

# Kill process if needed
kill -9 <PID>

# Or use different port
streamlit run streamlit_app.py --server.port 8502
```

### Snowflake Deployment

**App doesn't load:**
```sql
-- Check app status
SHOW STREAMLITS;
DESC STREAMLIT AUTOMATED_INTELLIGENCE.RAW.the_dashboard;

-- Verify warehouse is set
ALTER STREAMLIT AUTOMATED_INTELLIGENCE.RAW.the_dashboard 
  SET QUERY_WAREHOUSE = AUTOMATED_INTELLIGENCE_WH;
```

**Permission errors:**
```sql
-- Grant necessary permissions
GRANT USAGE ON DATABASE AUTOMATED_INTELLIGENCE TO ROLE <your_role>;
GRANT USAGE ON SCHEMA RAW, DYNAMIC_TABLES, INTERACTIVE TO ROLE <your_role>;
GRANT SELECT ON ALL TABLES IN SCHEMA RAW TO ROLE <your_role>;
GRANT SELECT ON ALL TABLES IN SCHEMA INTERACTIVE TO ROLE <your_role>;
```

**Dynamic Tables query fails:**
```sql
-- Requires MONITOR privilege
GRANT MONITOR ON DATABASE AUTOMATED_INTELLIGENCE TO ROLE <your_role>;
```

## Files

```
streamlit-dashboard/
├── streamlit_app.py      # Main dashboard application
├── environment.yml       # Python dependencies for Snowflake
├── README.md            # This file
└── .streamlit/
    └── secrets.toml     # Local connection config (not committed)
```

## Key Metrics Displayed

| Metric | Source | Refresh |
|--------|--------|---------|
| Total Orders | RAW.ORDERS | Real-time |
| Orders/Hour | Last 1 hour window | Real-time |
| Ingestion Trend | 24-hour aggregation | Real-time |
| Query Latency | On-demand test | Manual trigger |
| DT Status | INFORMATION_SCHEMA | Real-time |
| Data Freshness | MAX(ORDER_DATE) | Real-time |

## Integration with Other Demos

This dashboard complements all other demos:

1. **Demo 1 (Dynamic Tables)**: Shows DT refresh status and health
2. **Demo 2 (Interactive Tables)**: Tests query performance in real-time
3. **Demo 3 (Snowpipe Streaming)**: Monitors live ingestion metrics
4. **Demo 4 (Security)**: Can be extended with role-based filtering

## Next Steps

- **Add alerts**: Email/Slack notifications for pipeline issues
- **Historical tracking**: Store metrics in tables for trend analysis
- **Advanced charts**: Altair/Plotly for complex visualizations
- **Multi-warehouse**: Compare multiple warehouse performance
- **Cost tracking**: Show credit consumption by operation

---

**Demo-ready dashboard showing real-time data pipeline monitoring!** 🚀
