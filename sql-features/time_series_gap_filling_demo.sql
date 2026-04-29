-- ============================================================================
-- Time Series Gap-Filling Demo (RESAMPLE clause)
-- ============================================================================
-- Fill gaps in time-series data using the RESAMPLE clause and interpolation
-- functions. Released in Snowflake 9.26 (September 2025).
-- 
-- Key Components:
-- - RESAMPLE clause: Generates rows for missing time intervals
-- - INTERPOLATE_FFILL: Forward-fill (use last known value)
-- - INTERPOLATE_BFILL: Backward-fill (use next known value)
-- - INTERPOLATE_LINEAR: Linear interpolation between values
-- ============================================================================

USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
USE DATABASE AUTOMATED_INTELLIGENCE;
USE WAREHOUSE AUTOMATED_INTELLIGENCE_WH;

-- ============================================================================
-- PART 1: Setup - Create Sample Sensor Data
-- ============================================================================

-- Create a table with irregular time series data (gaps at 15, 45 minutes)
CREATE OR REPLACE TABLE time_series_demo.sensor_readings (
    observed TIMESTAMP,
    temperature FLOAT,
    humidity FLOAT,
    sensor_id VARCHAR
);

INSERT INTO time_series_demo.sensor_readings VALUES
    -- Sensor A - has gaps at 09:15 and 09:45
    ('2025-01-15 09:00:00', 68.0, 45.0, 'SENSOR_A'),
    ('2025-01-15 09:17:00', 70.2, 44.5, 'SENSOR_A'),  -- Irregular timing
    ('2025-01-15 09:30:00', 72.5, 43.0, 'SENSOR_A'),
    ('2025-01-15 10:00:00', 75.0, 41.0, 'SENSOR_A'),
    -- Sensor B - different gaps
    ('2025-01-15 09:00:00', 65.0, 50.0, 'SENSOR_B'),
    ('2025-01-15 09:30:00', 66.5, 48.0, 'SENSOR_B'),
    ('2025-01-15 09:45:00', 67.0, 47.0, 'SENSOR_B');

-- View the raw data (notice irregular intervals)
SELECT * FROM time_series_demo.sensor_readings ORDER BY sensor_id, observed;

-- ============================================================================
-- PART 2: Basic RESAMPLE - Fill Time Gaps
-- ============================================================================

-- RESAMPLE generates rows for missing 15-minute intervals
SELECT * 
FROM time_series_demo.sensor_readings
  RESAMPLE(
    USING observed                        -- Column with timestamps
    INCREMENT BY INTERVAL '15 minutes'    -- Desired interval
    PARTITION BY sensor_id                -- Generate gaps per sensor
  )
ORDER BY sensor_id, observed;

-- Note: Generated rows have NULL values for temperature and humidity

-- ============================================================================
-- PART 3: RESAMPLE with Interpolation Functions
-- ============================================================================

-- Combine RESAMPLE with interpolation to fill NULL values
SELECT 
    observed,
    temperature AS original_temp,
    -- Forward Fill: Use last known value
    INTERPOLATE_FFILL(temperature) OVER (
        PARTITION BY sensor_id ORDER BY observed
    ) AS temp_ffill,
    -- Backward Fill: Use next known value  
    INTERPOLATE_BFILL(temperature) OVER (
        PARTITION BY sensor_id ORDER BY observed
    ) AS temp_bfill,
    -- Linear Interpolation: Calculate intermediate value
    INTERPOLATE_LINEAR(temperature) OVER (
        PARTITION BY sensor_id ORDER BY observed
    ) AS temp_linear,
    sensor_id
FROM time_series_demo.sensor_readings
  RESAMPLE(
    USING observed
    INCREMENT BY INTERVAL '15 minutes'
    PARTITION BY sensor_id
  )
ORDER BY sensor_id, observed;

-- ============================================================================
-- PART 4: Using Metadata Columns
-- ============================================================================

-- Track which rows are generated vs original
SELECT 
    observed,
    temperature,
    INTERPOLATE_LINEAR(temperature) OVER (
        PARTITION BY sensor_id ORDER BY observed
    ) AS interpolated_temp,
    sensor_id,
    is_generated,
    bucket_start
FROM time_series_demo.sensor_readings
  RESAMPLE(
    USING observed
    INCREMENT BY INTERVAL '15 minutes'
    PARTITION BY sensor_id
    METADATA_COLUMNS 
        IS_GENERATED() AS is_generated,
        BUCKET_START() AS bucket_start
  )
ORDER BY sensor_id, observed;

-- Filter to only generated rows
SELECT * 
FROM time_series_demo.sensor_readings
  RESAMPLE(
    USING observed
    INCREMENT BY INTERVAL '15 minutes'
    PARTITION BY sensor_id
    METADATA_COLUMNS IS_GENERATED() AS is_generated
  )
WHERE is_generated = TRUE
ORDER BY sensor_id, observed;

-- ============================================================================
-- PART 5: Filter Out Non-Uniform Data
-- ============================================================================

-- Remove original rows that don't align to the uniform interval
SELECT * 
FROM time_series_demo.sensor_readings
  RESAMPLE(
    USING observed
    INCREMENT BY INTERVAL '15 minutes'
    PARTITION BY sensor_id
    METADATA_COLUMNS BUCKET_START() AS bucket_first_row
  )
WHERE observed = bucket_first_row  -- Only keep rows at bucket boundaries
ORDER BY sensor_id, observed;

-- ============================================================================
-- PART 6: Create Gap-Filled Table with CTAS
-- ============================================================================

-- Save uniformly-spaced time series to a new table
CREATE OR REPLACE TABLE time_series_demo.sensor_readings_uniform AS
SELECT 
    observed,
    INTERPOLATE_LINEAR(temperature) OVER (
        PARTITION BY sensor_id ORDER BY observed
    ) AS temperature,
    INTERPOLATE_LINEAR(humidity) OVER (
        PARTITION BY sensor_id ORDER BY observed
    ) AS humidity,
    sensor_id,
    is_generated
FROM time_series_demo.sensor_readings
  RESAMPLE(
    USING observed
    INCREMENT BY INTERVAL '15 minutes'
    PARTITION BY sensor_id
    METADATA_COLUMNS IS_GENERATED() AS is_generated
  )
ORDER BY sensor_id, observed;

-- Verify the result
SELECT * FROM time_series_demo.sensor_readings_uniform;

-- ============================================================================
-- PART 7: Real-World Example - Daily Order Metrics
-- ============================================================================

-- Create daily order summary with gap-filling
WITH daily_orders AS (
    SELECT 
        DATE_TRUNC('day', order_date)::TIMESTAMP AS order_day,
        COUNT(*) AS order_count,
        SUM(total_amount) AS daily_revenue
    FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS
    WHERE order_date >= '2025-01-01' AND order_date < '2025-02-01'
    GROUP BY order_day
)
SELECT 
    order_day,
    order_count,
    daily_revenue,
    -- Fill any missing days with 0
    COALESCE(order_count, 0) AS orders_filled,
    is_generated
FROM daily_orders
  RESAMPLE(
    USING order_day
    INCREMENT BY INTERVAL '1 day'
    METADATA_COLUMNS IS_GENERATED() AS is_generated
  )
ORDER BY order_day;

-- ============================================================================
-- Key Takeaways
-- ============================================================================

/*
1. RESAMPLE CLAUSE:
   - Goes in FROM clause, not after GROUP BY
   - USING: specify timestamp column
   - INCREMENT BY: desired interval
   - PARTITION BY: reset gaps per group

2. INTERPOLATION FUNCTIONS:
   - FFILL: Forward-fill (last observation carried forward)
   - BFILL: Backward-fill (next observation carried backward)
   - LINEAR: Linear interpolation between known values

3. METADATA COLUMNS:
   - IS_GENERATED(): Boolean, TRUE for generated rows
   - BUCKET_START(): Start time of the interval bucket

4. BEST PRACTICES:
   - Include filter columns in PARTITION BY to avoid NULL issues
   - Use BUCKET_START() to filter non-uniform original data
   - Consider which interpolation method suits your use case
*/

-- ============================================================================
-- Demo Complete
-- ============================================================================
SELECT '✅ Time Series Gap-Filling Demo Complete!' AS status;
