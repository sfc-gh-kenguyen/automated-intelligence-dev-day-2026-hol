-- ============================================================================
-- Performance Explorer Reference Guide
-- ============================================================================
-- Performance Explorer is a Snowsight dashboard for analyzing SQL workload
-- performance, warehouse efficiency, and identifying optimization opportunities.
--
-- Available in Snowsight: Monitoring → Performance Explorer
-- ============================================================================

USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
USE DATABASE AUTOMATED_INTELLIGENCE;
USE WAREHOUSE AUTOMATED_INTELLIGENCE_WH;

-- ============================================================================
-- PART 1: Accessing Performance Explorer
-- ============================================================================

/*
NAVIGATION:
1. Open Snowsight (app.snowflake.com)
2. Click "Monitoring" in left navigation
3. Select "Performance Explorer"

VIEWS AVAILABLE:
- Query Performance: Individual query analysis
- Warehouse Performance: Compute utilization
- Table Performance: Storage and access patterns
- Cost Attribution: Credit consumption breakdown
*/

-- ============================================================================
-- PART 2: Key Metrics to Monitor
-- ============================================================================

/*
QUERY METRICS:
- Execution Time: Total query duration
- Queued Time: Time waiting for warehouse resources
- Compilation Time: SQL parsing and optimization
- Bytes Scanned: Data read from storage
- Rows Produced: Output row count
- Spillage: Disk spillage (memory pressure indicator)

WAREHOUSE METRICS:
- Credit Usage: Compute cost
- Query Concurrency: Simultaneous queries
- Queue Depth: Queries waiting
- Cache Hit Ratio: Micro-partition cache effectiveness

TABLE METRICS:
- Access Frequency: How often queried
- Scan Efficiency: Partition pruning effectiveness
- Clustering Depth: Data organization quality
*/

-- ============================================================================
-- PART 3: SQL Queries for Performance Analysis
-- ============================================================================

-- Top 10 slowest queries in last 24 hours
SELECT 
    query_id,
    query_text,
    user_name,
    warehouse_name,
    execution_time / 1000 AS execution_seconds,
    bytes_scanned / 1e9 AS gb_scanned,
    rows_produced,
    partitions_scanned,
    partitions_total,
    ROUND(partitions_scanned / NULLIF(partitions_total, 0) * 100, 2) AS partition_scan_pct
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
  AND execution_status = 'SUCCESS'
  AND query_type = 'SELECT'
ORDER BY execution_time DESC
LIMIT 10;

-- Warehouse utilization by hour
SELECT 
    DATE_TRUNC('hour', start_time) AS hour,
    warehouse_name,
    COUNT(*) AS query_count,
    AVG(execution_time) / 1000 AS avg_execution_seconds,
    SUM(credits_used_cloud_services) AS cloud_credits,
    MAX(query_load_percent) AS peak_load
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
  AND warehouse_name IS NOT NULL
GROUP BY 1, 2
ORDER BY 1 DESC, 3 DESC;

-- Tables with poor clustering (high average depth)
SELECT 
    table_name,
    clustering_key,
    total_partition_count,
    average_overlaps,
    average_depth
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS
WHERE average_depth > 5  -- Indicates poor clustering
  AND deleted IS NULL
ORDER BY average_depth DESC
LIMIT 20;

-- Queries with high spillage (memory pressure)
SELECT 
    query_id,
    query_text,
    warehouse_name,
    bytes_spilled_to_local_storage / 1e9 AS gb_spilled_local,
    bytes_spilled_to_remote_storage / 1e9 AS gb_spilled_remote,
    execution_time / 1000 AS execution_seconds
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
  AND (bytes_spilled_to_local_storage > 0 OR bytes_spilled_to_remote_storage > 0)
ORDER BY bytes_spilled_to_remote_storage DESC
LIMIT 20;

-- ============================================================================
-- PART 4: Optimization Opportunities
-- ============================================================================

-- Queries that would benefit from clustering
SELECT 
    qh.query_text,
    qh.partitions_scanned,
    qh.partitions_total,
    ROUND(qh.partitions_scanned / NULLIF(qh.partitions_total, 0) * 100, 2) AS scan_efficiency_pct,
    qh.execution_time / 1000 AS execution_seconds
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY qh
WHERE qh.start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
  AND qh.partitions_total > 100
  AND qh.partitions_scanned / NULLIF(qh.partitions_total, 0) > 0.5  -- >50% scan
  AND qh.execution_time > 10000  -- >10 seconds
ORDER BY qh.partitions_scanned DESC
LIMIT 20;

-- Warehouses with high queue times
SELECT 
    warehouse_name,
    COUNT(*) AS queued_query_count,
    AVG(queued_overload_time) / 1000 AS avg_queue_seconds,
    MAX(queued_overload_time) / 1000 AS max_queue_seconds
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
  AND queued_overload_time > 0
GROUP BY warehouse_name
ORDER BY avg_queue_seconds DESC;

-- ============================================================================
-- PART 5: Performance Insights View (New)
-- ============================================================================

-- Query insights with optimization recommendations
SELECT 
    query_id,
    insight_type,
    insight_message,
    estimated_impact_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_INSIGHT
WHERE query_start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY estimated_impact_credits DESC
LIMIT 20;

-- ============================================================================
-- PART 6: Creating Performance Monitoring Dashboard
-- ============================================================================

-- Create a view for daily performance summary
CREATE OR REPLACE VIEW AUTOMATED_INTELLIGENCE.RAW.daily_performance_summary AS
SELECT 
    DATE_TRUNC('day', start_time) AS report_date,
    warehouse_name,
    COUNT(*) AS total_queries,
    COUNT(CASE WHEN execution_status = 'SUCCESS' THEN 1 END) AS successful_queries,
    COUNT(CASE WHEN execution_status = 'FAIL' THEN 1 END) AS failed_queries,
    AVG(execution_time) / 1000 AS avg_execution_seconds,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY execution_time) / 1000 AS p95_execution_seconds,
    SUM(bytes_scanned) / 1e12 AS tb_scanned,
    SUM(credits_used_cloud_services) AS cloud_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
  AND warehouse_name IS NOT NULL
GROUP BY 1, 2
ORDER BY 1 DESC, 3 DESC;

-- Query the summary
SELECT * FROM AUTOMATED_INTELLIGENCE.RAW.daily_performance_summary
WHERE report_date >= DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY report_date DESC, total_queries DESC;

-- ============================================================================
-- PART 7: Best Practices
-- ============================================================================

/*
REGULAR MONITORING:
1. Check Performance Explorer weekly
2. Set up alerts for query timeouts
3. Monitor warehouse queue depths
4. Track clustering efficiency

OPTIMIZATION ACTIONS:
1. Add clustering keys to frequently filtered tables
2. Right-size warehouses based on utilization
3. Use result caching for repeated queries
4. Consider search optimization for point lookups

COST MANAGEMENT:
1. Review credit consumption by warehouse
2. Identify and optimize expensive queries
3. Use auto-suspend for dev/test warehouses
4. Consider resource monitors for budget control
*/

-- ============================================================================
-- Demo Complete
-- ============================================================================
SELECT '✅ Performance Explorer Reference Complete!' AS status;
