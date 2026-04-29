# Interactive Tables & Warehouses - Performance Serving Layer

## Overview

This module demonstrates **Interactive Tables** and **Interactive Warehouses** - Snowflake's high-performance serving layer for customer-facing, low-latency queries under high concurrency.

### What This Demo Proves

1. **Real-Time Pipeline**: Data flows from ingestion → transformation → serving (all native Snowflake)
2. **High-Concurrency Performance**: Better query performance under concurrent load
3. **Complete Native Stack**: No external cache, API database, or ETL tools needed

**Note:** *Performance characteristics vary by account configuration, data volume, and concurrent load. Interactive Tables and Warehouses are designed for consistent low-latency queries under high concurrency.*

### Architecture Position

```
┌──────────────────────────────────────────────────────────────────┐
│  INGESTION LAYER                                                 │
│  Snowpipe Streaming → Real-time data ingestion                 │
└──────────────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────────────┐
│  TRANSFORMATION LAYER                                             │
│  Dynamic Tables (3 tiers) → Incremental transformations         │
└──────────────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────────────┐
│  SERVING LAYER (THIS MODULE)                                      │
│  Interactive Tables → Auto-refresh from Dynamic Tables          │
│  Interactive Warehouse → Low-latency queries under high load    │
└──────────────────────────────────────────────────────────────────┘
```

---

## 🚀 Quick Start

### Prerequisites

1. **Python environment**:
   ```bash
   cd /Users/ddesai/Apps/Snova/automated-intelligence/interactive
   python3 -m venv venv
   source venv/bin/activate
   pip install snowflake-connector-python
   ```

2. **Snowflake connection** configured (default: `dash-builder-si`)

3. **Interactive Tables setup** (run `setup_interactive.sql` once)

### Run the Demo

**Interactive Mode (with prompts)**:
```bash
./demo.sh
```

**Non-Interactive Mode (fastest)**:
```bash
./demo.sh --threads 150 --warehouse both
```

**With Real-Time Pipeline Demo**:
```bash
./demo.sh --enable-realtime --orders 50
```

---

## 📊 What's Included

### 1. Two Interactive Tables

#### `customer_order_analytics`
- **Purpose**: Customer portals ("My Orders" page)
- **Clustered by**: `customer_id`
- **Query pattern**: Point lookups by customer
- **Use cases**: Customer self-service, account dashboards

#### `order_lookup`
- **Purpose**: Support/operations dashboards
- **Clustered by**: `order_id`
- **Query pattern**: Point lookups by order ID
- **Use cases**: Support agent tools, order tracking APIs

### 2. Interactive Warehouse

**Name**: `automated_intelligence_interactive_wh`
- **Size**: XSMALL (supports <500GB working set)
- **Always-on**: Does not auto-suspend (by design)
- **Query timeout**: 5 seconds (enforced, cannot be increased)
- **Optimized for**: Selective queries with WHERE clauses

### 3. Demo Scripts

#### `demo.sh`
Master orchestration script that runs both load testing and optional real-time pipeline demo.

**Interactive Mode**:
- Prompts for thread count (default: 150)
- Prompts for warehouse selection (both/standard/interactive)
- Optionally includes real-time pipeline demo

**Non-Interactive Mode**:
- Use command-line arguments to skip prompts
- Faster execution for repeated demos

#### `load_test_interactive.py`
Concurrent load testing engine that simulates high user traffic.

**Features**:
- Thread pool executor for concurrent queries
- Random query generation (realistic workload)
- Detailed latency statistics (min/median/avg/P95/P99/max)
- Success/failure tracking

**Usage**:
```bash
python load_test_interactive.py --warehouse [standard|interactive] \
  --threads 150 --queries 500
```

#### `realtime_demo.py`
Real-time pipeline demonstration showing data ingestion to serving.

**Features**:
- Generates orders via stored procedure
- Monitors Dynamic Tables refresh
- Monitors Interactive Tables refresh
- Measures query latency on new data

**Usage**:
```bash
python realtime_demo.py --generate-orders 50
python realtime_demo.py --monitor-pipeline
```

---

## 🎯 Expected Results

### High-Concurrency Performance

Based on 21.3M orders in dataset with 150 concurrent threads:

| Metric | Standard WH | Interactive WH | **Improvement** |
|--------|-------------|----------------|-----------------|
| **P95 Latency** | 6,897 ms (6.9s) | 2,119 ms (2.1s) | **3.3x faster** |
| **Median** | 4,254 ms (4.3s) | 945 ms (0.95s) | **4.5x faster** |
| **Average** | 4,221 ms (4.2s) | 1,083 ms (1.1s) | **3.9x faster** |
| **Consistency** | Variable (queuing) | Predictable | ✓ |

**Key Insight**: Interactive warehouses maintain consistent low median latency even under high concurrent load, while standard warehouses show increased query times under load.

### Real-Time Pipeline Performance

| Stage | Duration | Purpose |
|-------|----------|---------|
| Order generation | 10-30 seconds | Generate new orders via stored procedure |
| Dynamic Tables refresh | Varies (based on TARGET_LAG) | Transform raw data into aggregates |
| Interactive Tables refresh | ~5 minutes | Auto-refresh serving layer |
| Query latency | 50-100ms | Customer-facing queries |

---

## 💡 Production Use Cases

### 1. Customer Portals
```sql
-- "My Orders" page
SELECT * FROM customer_order_analytics
WHERE customer_id = ? 
ORDER BY order_date DESC
LIMIT 20;
```
**Expected**: Low latency, perfect for web/mobile apps

### 2. Support Dashboards
```sql
-- Order lookup for support agents
SELECT * FROM order_lookup
WHERE order_id = ?;
```
**Expected**: Very low latency, instant results

### 3. Public APIs
```sql
-- RESTful API endpoint: GET /orders/{order_id}
SELECT 
  order_id, customer_name, order_status, final_revenue
FROM order_lookup
WHERE order_id = ?;
```
**Expected**: Low latency, handles high QPS

### 4. Real-Time Monitoring
```sql
-- High-value orders in last hour
SELECT * FROM order_lookup
WHERE order_date >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
  AND final_revenue > 1000
ORDER BY order_date DESC;
```
**Expected**: Fast response, dashboard-ready

---

## 🎬 Demo Flow & Talking Points

### Opening (30 seconds)
> "Today I'll show you how Snowflake Interactive Tables enable **real-time serving** at scale with **no external systems**. We'll stress-test with 150 concurrent users and demonstrate query performance patterns."

### Load Testing Demo (3-5 minutes)

**Standard Warehouse Test**:
```bash
python load_test_interactive.py --warehouse standard --threads 150 --queries 500
```
> "We're simulating 150 users hitting our API simultaneously. Standard warehouses struggle with queuing and variable latency - notice the P95 is 6-7 seconds."

**Interactive Warehouse Test**:
```bash
python load_test_interactive.py --warehouse interactive --threads 150 --queries 500
```
> "Same workload on Interactive warehouse: P95 drops to 2 seconds, median under 1 second. That's **3-4x faster under load** - and this is with 21 million orders in the dataset!"

### Real-Time Pipeline Demo (Optional, 10-15 minutes)

```bash
python realtime_demo.py --generate-orders 50
```
> "Watch as we generate 50 new orders, and they appear in our serving layer within 5 minutes. Once there, we can query them in under 100 milliseconds - fast enough for customer-facing applications."

### Closing (30 seconds)
> "This is a complete native Snowflake pipeline. No Redis for caching, no separate API database, no complex ETL to sync data. Just Snowflake, from ingestion to serving, with production-ready performance."

---

## 🏗️ Technical Deep Dive

### Why Interactive Tables?

**The Problem**:
- Dynamic Tables: Optimized for complex transformations, but not for high QPS
- Customer Portals: Need <500ms response for "My Orders" queries
- Support Tools: Need <1s response for order lookups
- Public APIs: Need to handle 100+ queries/second with low latency

**The Solution**:
Interactive Tables + Interactive Warehouses provide:
- ✅ **Low-latency queries** under concurrent load
- ✅ **High concurrency** (100+ QPS)
- ✅ **Automatic refresh** from Dynamic Tables (5-minute lag)
- ✅ **No external tools** (no Redis, no separate API database)

### Interactive Warehouse Characteristics
- **Always-on**: No auto-suspend (by design)
- **5-second timeout**: Queries must complete quickly
- **Local SSD caching**: Hot data in cache for fast access
- **Multi-cluster support**: Scale out (but no auto-scaling)

### Interactive Table Characteristics
- **Clustered storage**: Optimized for point lookups
- **Auto-refresh**: TARGET_LAG parameter (5 min minimum)
- **Limited DML**: Only INSERT OVERWRITE supported
- **No policies**: No masking, row access, or aggregation policies

### Query Best Practices

✅ **Good for Interactive Tables**:
```sql
-- Point lookups
WHERE customer_id = 5000

-- Selective filters
WHERE order_id = 15000 AND status = 'Completed'

-- Recent time windows
WHERE order_date >= CURRENT_DATE - 7

-- Simple aggregations on filtered data
WHERE customer_id = 5000 GROUP BY status
```

❌ **Not ideal for Interactive Tables**:
```sql
-- Full table scans
SELECT * FROM orders

-- Complex joins (fact-to-fact)
FROM orders o JOIN sales s ON ...

-- Large time ranges
WHERE order_date >= CURRENT_DATE - 365

-- Compute-heavy operations
WHERE REGEXP_LIKE(description, '...')
```

### Warehouse Sizing Guide

Based on **working data set** (frequently queried portion):

| Working Set | Warehouse Size |
|-------------|----------------|
| < 500 GB | XSMALL |
| 500 GB - 1 TB | SMALL |
| 1 TB - 2 TB | MEDIUM |
| 2 TB - 4 TB | LARGE |
| 4 TB - 8 TB | XLARGE |
| 8 TB - 16 TB | 2XLARGE |
| > 16 TB | 3XLARGE |

**Note**: Working set ≠ table size. It's the portion you query frequently (e.g., last 7 days of orders).

---

## ⚠️ Important Limitations

### Interactive Warehouses
- ⚠️ **5-second query timeout** (cannot be increased)
- ⚠️ **Always-on billing** (no auto-suspend)
- Available in select AWS regions (see [Region Availability](https://docs.snowflake.com/en/user-guide/interactive.html#label-interactive-region-availability))
- ⚠️ **Cannot query standard tables** (only interactive tables)
- ⚠️ **No multi-cluster auto-scaling** (manual scaling only)

### Interactive Tables
- ⚠️ **Simple queries only** (avoid complex joins, window functions)
- ⚠️ **No DML** (INSERT OVERWRITE only)
- ⚠️ **No policies** (masking, row access, etc.)
- ⚠️ **No streams or replication**

---

## 💰 Cost Considerations

### Interactive Warehouses
- **Always-on billing**: No auto-suspend (by design)
- **Minimum billable period**: 1 hour (changed from 1 minute as of 2025)
- **Same credit rates**: XSMALL = 1 credit/hour

### Interactive Tables
- **Storage costs**: Same as standard tables
- **Larger size**: May be 1.5-2x due to indexes and encoding
- **No query costs**: Covered by warehouse compute

### ROI Calculation
If serving 100+ QPS customer-facing app:
- **Without Interactive Tables**: Need larger standard warehouse + app-layer cache (Redis)
- **With Interactive Tables**: Single XSMALL interactive warehouse (always-on)
- **Savings**: Simpler architecture, no external systems, lower ops cost

---

## 🔧 Troubleshooting

### Problem: Queries returning 0 rows
**Cause**: Not using interactive warehouse  
**Solution**: `USE WAREHOUSE automated_intelligence_interactive_wh`

### Problem: "Object not found" error
**Cause**: Table not added to interactive warehouse  
**Solution**: `ALTER WAREHOUSE interactive_wh ADD TABLES (table_name)`

### Problem: Data not appearing in Interactive Tables
**Cause**: Refresh hasn't occurred yet (5-min lag)  
**Solution**: Wait for TARGET_LAG period, check Dynamic Tables first

### Problem: P95 latency still high on interactive warehouse
**Cause**: Cache not warmed yet  
**Solution**: Run 20-30 queries to warm cache before benchmarking

### Problem: Concurrent queries failing
**Cause**: 5-second query timeout  
**Solution**: Simplify queries, ensure they're selective (point lookups)

### Problem: Load test shows minimal improvement
**Cause**: Data already cached in standard warehouse or insufficient load  
**Solution**: Increase concurrency to 100-150 threads to show queuing effects

### Problem: Queries timeout after 5 seconds
**Cause**: Query too complex for interactive warehouse  
**Solution**: Simplify query or move to Dynamic Tables layer

---

## 📁 Files

```
interactive/
├── demo.sh                           # Master demo orchestration script
├── load_test_interactive.py          # Concurrent load testing engine
├── realtime_demo.py                  # Real-time pipeline demo
├── setup_interactive.sql             # Initial setup (DDL)
├── demo_interactive_performance.sql  # Manual demo queries (legacy)
├── test_interactive_layer.sql        # Validation test suite
├── manual_refresh.sql                # Manual refresh commands
├── README.md                         # This file
└── venv/                             # Python virtual environment
```

---

## 🌍 Region Availability

**Status**: Generally Available (GA since December 11, 2025)

Available in select AWS regions. For the most current list, see the [official documentation](https://docs.snowflake.com/en/user-guide/interactive.html#label-interactive-region-availability).

Common regions include:
- `us-east-1` (N. Virginia)
- `us-west-2` (Oregon)
- `us-east-2` (Ohio)
- `ap-northeast-1` (Tokyo)
- `ap-southeast-2` (Sydney)
- `eu-central-1` (Frankfurt)
- `eu-west-1` (Ireland)

---

## 📊 Monitoring

### Check Interactive Table Status
```sql
SELECT 
  name,
  target_lag_sec,
  latest_data_timestamp,
  scheduling_state
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLES())
WHERE schema_name = 'INTERACTIVE';
```

### Check Warehouse Status
```sql
SHOW WAREHOUSES LIKE 'automated_intelligence_interactive_wh';
```

### View Refresh History
```sql
SELECT 
  name,
  refresh_action,
  state,
  data_timestamp
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
  NAME_PREFIX => 'AUTOMATED_INTELLIGENCE.INTERACTIVE'
))
ORDER BY data_timestamp DESC
LIMIT 20;
```

---

## 🎯 Key Takeaways

1. **Real-Time Pipeline**: 5-minute lag from ingestion to serving (all native)
2. **High Performance**: Better query performance under concurrent load
3. **Production-Ready**: Low latency suitable for customer-facing apps
4. **Simplified Stack**: No external cache/database needed
5. **Use Cases**: Customer portals, support dashboards, public APIs

---

## 📚 Learn More

- [Snowflake Interactive Tables Docs](https://docs.snowflake.com/user-guide/interactive)
- [CREATE INTERACTIVE TABLE](https://docs.snowflake.com/sql-reference/sql/create-interactive-table)
- [CREATE INTERACTIVE WAREHOUSE](https://docs.snowflake.com/sql-reference/sql/create-interactive-warehouse)

---

**Remember**: Interactive Tables are the serving layer that completes your end-to-end pipeline from ingestion to customer-facing queries! 🚀
