# Snowpipe Streaming for Automated Intelligence

This project implements real-time data ingestion using Snowflake's Snowpipe Streaming high-performance architecture. It enables continuous, low-latency streaming of orders and order items for existing customers in Snowflake.

## 🚀 High-Scale Architecture

**Optimized for massive scale**: This implementation supports horizontal scaling through:
- **Bulk batch generation**: Efficient batching per API call
- **Horizontal scaling**: Parallel instances with customer partitioning and unique channels
- **Throughput optimization**: Targets 10-16 MB compressed batches per Snowflake best practices
- **Production-ready**: Linear scaling with additional parallel instances

### Scaling Characteristics

**Note:** *Performance varies by Snowflake account region, warehouse size, network latency, and data volume. Use these examples to understand scaling patterns, not as performance guarantees.*

| Approach | Description | Key Benefit |
|----------|-------------|-------------|
| Single Instance | Basic ingestion pattern | Simple setup and testing |
| 5 Parallel Instances | Customer ID partitioning | ~5x throughput vs single |
| 10+ Parallel Instances | Extended partitioning | Linear scaling continues |
| 50+ Parallel Instances | Massive-scale deployment | Production-grade throughput |

**Scaling Pattern**: Each additional instance adds proportional throughput through independent channels and customer partitioning.

## Architecture

### Components

- **2 Streaming Channels per Instance**: One for orders, one for order_items
- **Unique Channel Names**: Parallel instances use `orders_channel_instance_N` to prevent conflicts
- **2 PIPE Objects**: Define ingestion logic and schema validation (shared across all channels)
- **Offset Token Tracking**: Ensures exactly-once delivery and resumability
- **ID Management**: Maintains sequential IDs compatible with stored procedure
- **Customer Partitioning**: Parallel instances work on separate customer ID ranges
- **Segment-Based Order Generation**: Orders are generated with segment-specific amounts, discounts, and item counts
  - Premium: $500-$3000 orders, 10% discount rate (5-10% off), 3-8 items/order
  - Standard: $100-$800 orders, 40% discount rate (5-20% off), 2-5 items/order
  - Basic: $20-$300 orders, 50% discount rate (10-30% off), 1-3 items/order

### Data Flow

```
Java Application (Single Instance)
    │
    ├─> Queries MAX(CUSTOMER_ID) from existing customers
    │
    ├─> Channel: orders_channel → PIPE: ORDERS_PIPE → Table: orders
    └─> Channel: order_items_channel → PIPE: ORDER_ITEMS_PIPE → Table: order_items

Java Application (Parallel - 5 Instances)
    │
    ├─> Orchestrator: Partitions customer ranges (1-4K, 4K-8K, 8K-12K, 12K-16K, 16K-20K)
    │
    ├─> Instance 0: orders_channel_instance_0 ──┐
    ├─> Instance 1: orders_channel_instance_1 ──┤
    ├─> Instance 2: orders_channel_instance_2 ──┼─> ORDERS_PIPE → Table: orders
    ├─> Instance 3: orders_channel_instance_3 ──┤
    └─> Instance 4: orders_channel_instance_4 ──┘
```

### Key Scaling Innovations

1. **Bulk Batch Generation**: Generate orders in memory → single `insertRows()` call
   - Reduces API call overhead significantly
   - More efficient network utilization

2. **Horizontal Scaling**: Multiple parallel instances with unique channels
   - Each instance gets unique channel names (`_instance_0`, `_instance_1`, etc.)
   - Prevents `STALE_CONTINUATION_TOKEN_SEQUENCER` conflicts
   - Linear scalability pattern: N instances ≈ N× throughput

3. **Customer Partitioning**: No data conflicts between instances
   - Each instance processes distinct customer ID ranges
   - Example: Instance 0 handles customers 1-4,000, Instance 1 handles 4,001-8,000, etc.

### Offset Token Strategy

- **Orders**: `order_<order_id>`
- **Order Items**: `item_<order_item_id>`

Offset tokens enable:
- Progress tracking per channel
- Resume from last committed position on failure
- Exactly-once delivery guarantees

## Prerequisites

### System Requirements

- Java 21 or later (required for current implementation)
- Maven 3.6+
- Network access to Snowflake
- Snowflake account with ACCOUNTADMIN or sufficient privileges

**SDK Version:** 1.1.2 (Jan 2026) - includes Azure/GCP GA support and bug fixes.

### Snowflake Setup

1. **Database and Tables**: Run `setup.sql` to create the base infrastructure using role `AUTOMATED_INTELLIGENCE`
2. **Initial Customers**: Run `CALL generate_customers(500000);` to create customer data with Premium, Standard, and Basic segments
3. **PIPE Objects**: Run `setup_pipes.sql` to create streaming pipes (ORDERS_PIPE and ORDER_ITEMS_PIPE)

### Authentication Setup

Generate RSA key pair for key-pair authentication:

```bash
# Generate private key
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt

# Generate public key
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub

# Format public key for Snowflake (removes headers and newlines)
PUBK=$(cat ./rsa_key.pub | grep -v KEY- | tr -d '\012')
echo "ALTER USER YOUR_USER SET RSA_PUBLIC_KEY='$PUBK';"
```

Run the generated `ALTER USER` command in Snowflake.

## Configuration

### 1. Create `profile.json`

Copy `profile.json.template` to `profile.json` and fill in your details:

```bash
cp profile.json.template profile.json
```

Format your private key for JSON:

```bash
sed 's/$/\\n/' rsa_key.p8 | tr -d '\n'
```

Edit `profile.json`:

```json
{
  "user": "YOUR_SNOWFLAKE_USER",
  "account": "your_account_identifier",
  "url": "https://your_account_identifier.snowflakecomputing.com:443",
  "private_key": "-----BEGIN PRIVATE KEY-----\\n...\\n-----END PRIVATE KEY-----",
  "database": "AUTOMATED_INTELLIGENCE",
  "schema": "RAW",
  "warehouse": "AUTOMATED_INTELLIGENCE_WH",
  "role": "AUTOMATED_INTELLIGENCE"
}
```

**Important Configuration Notes:**
- **account**: Use hyphens, not underscores (e.g., `sfsenorthamerica-gen-ai-hol`, NOT `sfsenorthamerica-gen_ai_hol`)
- **role**: Must specify a valid role (SDK does not default to user's default role)
- **private_key**: Use `\\n` for newlines in JSON format
- **schema**: Use `RAW` for production, `STAGING` for staging environment

### 2. Configure `config_default.properties`

Adjust settings for optimal throughput:

```properties
# Latency Configuration (higher = better partition sizing)
max.client.lag=60

# Bulk Batch Generation (10K-50K for optimal throughput)
orders.batch.size=10000

# Legacy parameter (maintained for backward compatibility)
num.orders.per.batch=100
```

**Tuning Recommendations**:
- `orders.batch.size`: 10K-50K orders per batch (targets 10-16 MB compressed)
- `max.client.lag`: 60s for balanced latency/throughput (increase to 300s for batch-heavy workloads)
- Lower values = lower latency, higher values = better partition sizing & query performance

### Understanding Data Flush Behavior

Data doesn't appear in Snowflake tables immediately after calling `insertRows()`. Snowpipe Streaming uses intelligent buffering for optimal performance:

**Key Configuration:**
- **`max.client.lag=60`**: Buffers data for up to **60 seconds** before flushing to tables
  - Optimizes query performance through better file partitioning
  - Recommended default by Snowflake for production workloads

**Flush Triggers:**
Data is flushed to Snowflake when **any** of these conditions are met:
1. **Buffer size threshold** (~16 MB compressed data)
2. **Time threshold** (60 seconds elapsed since first record)
3. **Channel closed** (explicit close or application shutdown)

**Latency Trade-offs:**
- **Lower lag** (e.g., `max.client.lag=5`):
  - ✅ Faster data visibility (~5 seconds)
  - ❌ More frequent flushes = smaller files = slower downstream queries
  - Use for: Demos, real-time dashboards

- **Higher lag** (e.g., `max.client.lag=60`):
  - ✅ Better file sizes = faster queries
  - ✅ Better compression and throughput
  - ❌ Slower data visibility (~60 seconds)
  - Use for: Production workloads

**Example:** With `max.client.lag=60`, expect data to appear in tables within **~60 seconds** after ingestion starts. This is normal and optimal for production!

## Building

```bash
mvn clean install
```

This creates a shaded JAR with all dependencies at:
`target/automated-intelligence-streaming-1.0.0.jar`

## Running

### Quick Start: Bulk Generation (Optimized)

The application now supports **bulk batch generation** for high-throughput ingestion:

```bash
# Build the application
mvn clean package -DskipTests

# Generate 10,000 orders (single batch, ~5 seconds) - uses defaults
java --add-opens=java.base/java.nio=ALL-UNNAMED \
  -jar target/automated-intelligence-streaming-1.0.0.jar 10000

# Explicitly specify config files
java --add-opens=java.base/java.nio=ALL-UNNAMED \
  -jar target/automated-intelligence-streaming-1.0.0.jar 10000 config_default.properties profile.json

# Generate 100,000 orders (10 batches, ~1 minute)
java --add-opens=java.base/java.nio=ALL-UNNAMED \
  -jar target/automated-intelligence-streaming-1.0.0.jar 100000

# Use staging configuration
java --add-opens=java.base/java.nio=ALL-UNNAMED \
  -jar target/automated-intelligence-streaming-1.0.0.jar 100000 config_staging.properties profile_staging.json
```

**Note**: 
- The `--add-opens` JVM option is required for Java 11+ Arrow compatibility with JDBC.
- Supports command-line arguments: `<num_orders> [config_file] [profile_file]`
- Defaults: `config_default.properties` and `profile.json`

### Horizontal Scaling: Parallel Instances (Recommended for Scale)

For higher throughput, use **parallel instances** with customer partitioning:

```bash
# 50K orders across 5 parallel instances (~10 seconds) ✅ Validated
java --add-opens=java.base/java.nio=ALL-UNNAMED \
  -cp target/automated-intelligence-streaming-1.0.0.jar \
  com.snowflake.demo.ParallelStreamingOrchestrator 50000 5

# 100K orders across 5 instances (~20 seconds)
java --add-opens=java.base/java.nio=ALL-UNNAMED \
  -cp target/automated-intelligence-streaming-1.0.0.jar \
  com.snowflake.demo.ParallelStreamingOrchestrator 100000 5

# 1M orders across 10 instances (~2 minutes)
java --add-opens=java.base/java.nio=ALL-UNNAMED \
  -cp target/automated-intelligence-streaming-1.0.0.jar \
  com.snowflake.demo.ParallelStreamingOrchestrator 1000000 10

# 10M orders across 20 instances (~20 minutes)
java --add-opens=java.base/java.nio=ALL-UNNAMED \
  -cp target/automated-intelligence-streaming-1.0.0.jar \
  com.snowflake.demo.ParallelStreamingOrchestrator 10000000 20

# Or use test script
./test-parallel.sh
```

**How Parallel Scaling Works**:
1. Orchestrator queries total customers (e.g., 20,000)
2. Partitions customer ranges across N instances
3. Each instance creates unique channels (`orders_channel_instance_0`, etc.)
4. Instances run concurrently via thread pool
5. Results aggregated and reported

### Legacy Method: Maven Execution

For smaller batches or development:

```bash
# Generate 100 orders (default)
mvn exec:java -Dexec.mainClass="com.snowflake.demo.AutomatedIntelligenceStreaming"

# Generate 1000 orders
mvn exec:java -Dexec.mainClass="com.snowflake.demo.AutomatedIntelligenceStreaming" -Dexec.args="1000"
```

## Verification

### Check Data in Snowflake

```sql
USE DATABASE AUTOMATED_INTELLIGENCE;
USE SCHEMA RAW;

-- Count records
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items;

-- View recent data
SELECT * FROM customers ORDER BY customer_id DESC LIMIT 10;
SELECT * FROM orders ORDER BY order_id DESC LIMIT 10;
SELECT * FROM order_items ORDER BY order_item_id DESC LIMIT 10;
```

### Monitor Channels

```sql
-- View channel history (requires ACCOUNTADMIN or ACCOUNT_USAGE access)
SELECT 
    CHANNEL_NAME,
    PIPE_NAME,
    TABLE_NAME,
    CREATED_TIME,
    LAST_COMMITTED_TIME,
    OFFSET_TOKEN,
    STATUS
FROM SNOWFLAKE.ACCOUNT_USAGE.SNOWPIPE_STREAMING_CHANNEL_HISTORY
WHERE TABLE_DATABASE = 'AUTOMATED_INTELLIGENCE'
  AND TABLE_SCHEMA = 'RAW'
ORDER BY LAST_COMMITTED_TIME DESC;
```

## How It Works

### Data Generation

The application generates orders for existing customers with segment-based business logic:

1. **Query Customers**: Fetches MAX(CUSTOMER_ID) from the customers table
2. **Select Customer**: Randomly selects a customer ID from the existing range (1 to MAX_CUSTOMER_ID)
3. **Determine Segment**: Retrieves customer segment (Premium, Standard, Basic)
4. **Generate Order**: Creates an order with segment-specific:
   - **Premium**: $500-$3000 total, 10% chance of 5-10% discount
   - **Standard**: $100-$800 total, 40% chance of 5-20% discount
   - **Basic**: $20-$300 total, 50% chance of 10-30% discount
5. **Generate Order Items**: Creates 1-10 items per order (count varies by segment):
   - **Premium**: 3-8 items, $150-$500 unit prices
   - **Standard**: 2-5 items, $50-$250 unit prices
   - **Basic**: 1-3 items, $10-$100 unit prices

### Streaming Insertion

1. **Order Insert** → `appendRow()` with offset `order_<id>`
2. **Order Items Insert** → `appendRows()` with offsets `item_<id>`

Note: Customers are not streamed; orders reference existing customers in the database.

### Exactly-Once Delivery

- **ID Tracker**: Maintains counters initialized from latest offset tokens
- **Offset Tokens**: Unique per record, used for deduplication
- **Channel Reopening**: On restart, reads latest committed offset and resumes from next ID

### Error Handling

- **ON_ERROR = CONTINUE**: Pipes continue processing on errors
- **Response Validation**: Each insert checks for errors in response
- **Exception Propagation**: Errors stop processing and report failure

## Comparing with Stored Procedure

| Aspect | Stored Procedure | Snowpipe Streaming (Legacy) | Snowpipe Streaming (Optimized) |
|--------|------------------|-----------------------------|---------------------------------|
| **Latency** | Batch (on-demand) | Low latency | Low latency |
| **Batch Size** | Bulk inserts | Small batches | **Large batches** |
| **Throughput** | Limited by warehouse | Limited throughput | **High throughput with scaling** |
| **Horizontal Scaling** | No | No | **Yes (parallel instances)** |
| **Channel Management** | N/A | Single channel | **Unique channels per instance** |
| **Use Case** | Batch generation | Small-scale streaming | **Massive-scale streaming** |
| **Cost Model** | Warehouse compute | Throughput ($/GB) | Throughput ($/GB) |

**Note:** *Performance varies by account region, network latency, and concurrent load. Focus on demonstrating horizontal scaling patterns.*

### Key Improvements Explained

**Efficient Bulk Batching**:
- Large batches significantly reduce API overhead
- Single `insertRows()` call handles thousands of records
- Result: Much more efficient processing

**Linear Horizontal Scaling**:
- Each instance adds proportional throughput
- Multiple instances can work in parallel without conflicts
- Customer partitioning prevents data overlaps

## Best Practices

### Performance & Scalability

- **Bulk Batching**: Use 10K-50K orders per batch for optimal throughput
- **Batch Size Target**: Aim for 10-16 MB compressed per `insertRows()` call
- **Latency Tuning**: Set `max.client.lag=60s` (or higher) for better partition sizing
- **Horizontal Scaling**: Deploy multiple parallel instances with customer partitioning for massive-scale ingestion
- **Unique Channels**: Each parallel instance must use unique channel names (automatically handled by `ParallelStreamingOrchestrator`)
- **Channel Reuse**: Keep channels open during active streaming (don't close after each batch)
- **Customer Capacity**: Ensure sufficient existing customers (20K+ recommended) before streaming orders

### Scalability Guidelines

| Target Orders | Instances | Configuration | Notes |
|---------------|-----------|---------------|-------|
| 10K | 1 | Default | Basic testing |
| 50K | 5 | Parallel orchestrator | Validated pattern |
| 100K+ | 5+ | Parallel orchestrator | Scale as needed |
| Massive scale | 10-50+ | Parallel + cloud infra | Production deployment |

**Validation Notes**:
- 50K orders with 5 instances: Successful horizontal scaling pattern demonstrated
- No channel conflicts with instance-specific naming
- All instances completed successfully with unique channels

**Note:** *Actual throughput varies by Snowflake account region, warehouse configuration, and network conditions.*

### Reliability

- **Offset Tokens**: Always provide unique tokens for idempotency
- **Channel Lifecycle**: Keep channels open during active streaming
- **Error Monitoring**: Check response errors after each append
- **Progress Tracking**: Monitor via SNOWPIPE_STREAMING_CHANNEL_HISTORY view
- **Channel Naming**: Use `ParallelStreamingOrchestrator` to ensure unique channel names in parallel deployments

### Cost Optimization

- **Client Architecture**: Uses separate clients per PIPE as required by high-performance SDK v1.1.0
- **Appropriate Lag**: Higher lag = better file consolidation = lower query costs
- **Bulk Operations**: `insertRows()` is significantly more cost-effective than `insertRow()`
- **Combined Workloads**: Mixing batch and streaming reduces migration costs
- **Channel Cost**: Charged per active client, NOT per channel (multiple instances share cost efficiency)

## Troubleshooting

### "Channel not found" Error

- Verify PIPE objects exist: `SHOW PIPES IN SCHEMA RAW;`
- Check user has OPERATE privilege on pipes

### Authentication Failures

- Verify public key is set correctly in Snowflake
- Ensure private key format has `\\n` (escaped newlines) in JSON
- Check user has proper role assignments

### Data Not Appearing

- Wait 30+ seconds for default flush (or your `max.client.lag` setting)
- Check channel status for errors
- Verify tables exist and have correct schema

### Build Failures

- Ensure Java 11+ is installed: `java -version`
- Check Maven is configured: `mvn -version`
- Verify network access to Maven Central repository

### Runtime Errors: Arrow Memory Access

If you see `Failed to initialize MemoryUtil` error, you need JVM options:

```bash
# Always use this when running the JAR
java --add-opens=java.base/java.nio=ALL-UNNAMED -jar target/automated-intelligence-streaming-1.0.0.jar
```

This is automatically configured for Maven via `.mvn/jvm.config`, but required for direct JAR execution.

### No Customers Error

- Run `CALL generate_customers(500000);` to create customers
- Verify customers exist: `SELECT COUNT(*) FROM customers;`

## Architecture Differences: High-Performance vs Classic

This implementation uses **High-Performance Architecture**:

| Feature | High-Performance | Classic |
|---------|-----------------|---------|
| **SDK** | `snowpipe-streaming` | `snowflake-ingest-sdk` |
| **PIPE Object** | Required | Optional |
| **Schema Validation** | Server-side | Client-side |
| **Pricing** | Throughput-based | Compute + connections |
| **Transformations** | Supported (COPY syntax) | Not supported |
| **Max Throughput** | 10 GB/s per table | Lower |

## Project Structure

```
snowpipe-streaming/
├── pom.xml                                  # Maven build configuration
├── config_default.properties                # Default configuration (RAW schema)
├── config_staging.properties                # Staging environment configuration
├── profile.json.template                    # Snowflake connection template
├── profile.json                             # Your connection (git-ignored)
├── setup_pipes.sql                          # SQL to create PIPE objects
├── README.md                                # Complete guide with scaling architecture
├── test-bulk-generation.sh                  # Single-instance bulk test script
├── test-parallel.sh                         # Parallel horizontal scaling test script
├── .mvn/jvm.config                          # JVM options for Java 11+ compatibility
└── src/main/java/com/snowflake/demo/
    ├── AutomatedIntelligenceStreaming.java  # Main application (bulk batch generation)
    ├── ParallelStreamingOrchestrator.java   # Horizontal scaling orchestrator
    ├── SnowpipeStreamingManager.java        # Channel management (bulk operations, unique channels)
    ├── ConfigManager.java                    # Configuration loader
    ├── DataGenerator.java                    # Data generation logic (with partitioning)
    ├── Customer.java                         # Customer model
    ├── Order.java                            # Order model
    └── OrderItem.java                        # Order item model
```

## Next Steps

### Testing & Validation
1. **Start Small**: Test with 10K orders to validate setup
2. **Scale Gradually**: 10K → 50K ✅ → 100K → 1M → 10M → 100M → 1B
3. **Monitor Performance**: Use SNOWPIPE_STREAMING_CHANNEL_HISTORY view
4. **Tune Configuration**: Adjust `orders.batch.size` and `max.client.lag` based on results

### Production Deployment
1. **Cloud Infrastructure**: Deploy ParallelStreamingOrchestrator on Kubernetes/Docker
2. **Horizontal Scaling**: Start with 5-10 instances (validated), scale to 50+ for massive-scale deployments
3. **Monitoring**: Integrate with logging systems (CloudWatch, Datadog, etc.)
4. **Error Handling**: Add retries, dead letter queues, alerting
5. **Continuous Operation**: Schedule with Airflow, Kubernetes CronJobs, or similar

### Integration
1. **Real Event Sources**: Connect to Kafka, Kinesis, Cloud Pub/Sub, etc.
2. **CDC Pipelines**: Stream database changes in real-time
3. **IoT Data**: Ingest high-volume sensor/device data
4. **API Events**: Stream webhook events, user actions, etc.

### Performance Benchmarking
- Run `test-bulk-generation.sh` for single-instance baseline
- Run `test-parallel.sh` for horizontal scaling validation (50K orders validated)
- Use `ParallelStreamingOrchestrator` with custom parameters for larger scale tests

## Implementation Summary

### What Changed (Optimized Architecture)

1. **Bulk Batch Generation**
   - Added `insertOrders(List<Order>)` to batch large numbers of orders per API call
   - Refactored `AutomatedIntelligenceStreaming` to generate batches in memory
   - Significantly reduced API call overhead

2. **Horizontal Scaling Framework**
   - Created `ParallelStreamingOrchestrator` for multi-instance orchestration
   - Unique channel names per instance (`_instance_0`, `_instance_1`, etc.)
   - Customer partitioning prevents data conflicts
   - Validated: 5 parallel instances successfully demonstrated scaling pattern

3. **Configuration Optimization**
   - `orders.batch.size=10000` (bulk generation size)
   - `max.client.lag=60` (better partition sizing)
   - Targets 10-16 MB compressed per Snowflake best practices

4. **Key Files Modified**
   - `SnowpipeStreamingManager.java` - Bulk insertOrders, instance-specific channels
   - `AutomatedIntelligenceStreaming.java` - Bulk batch generation
   - `ParallelStreamingOrchestrator.java` - **NEW** parallel orchestrator
   - `DataGenerator.java` - Customer range partitioning
   - `config.properties` - Optimized settings

### Validation Results ✅

```
Test: 50,000 orders with 5 parallel instances
- Successful instances: 5/5
- Failed instances: 0
- Total time: ~10 seconds
- Throughput: ~5,000 orders/second
- Channel conflicts: 0 (unique naming working)
```

## Troubleshooting

### JWT Authentication Error (Error 390144)
```
Error: HTTP 401, error_code=390144, message=JWT token is invalid
```
**Solution**: This is a known bug in Snowpipe Streaming SDK v1.1.0. The `pom.xml` is configured to use v1.0.2. If you see this error:
```bash
mvn clean install  # Reinstall dependencies
```

### JVM Arrow Memory Error
```
Error: Failed to initialize MemoryUtil. You must start Java with --add-opens
```
**Solution**: Always include the JVM argument:
```bash
java --add-opens=java.base/java.nio=ALL-UNNAMED -jar target/automated-intelligence-streaming-1.0.0.jar
```

### Authentication Errors
- Verify private key format includes headers and uses `\\n` for newlines in JSON
- Ensure public key is assigned to user in Snowflake
- Check user has necessary permissions
- **Verify account identifier uses hyphens** (e.g., `gen-ai-hol`, NOT `gen_ai_hol`)
- **Ensure role field is present** in profile.json

### No Data Appearing
- Wait for max_client_lag duration (default 60 seconds)
- Check PIPE objects exist: `SHOW PIPES IN SCHEMA AUTOMATED_INTELLIGENCE.RAW;`
- Verify schema setting in profile.json matches your target tables
- Check warehouse is running

### Orphaned Records
If streaming fails mid-batch, you may have orphaned orders (orders without order_items). See ReconciliationManager class for cleanup utilities.

## References

- [Snowpipe Streaming Documentation](https://docs.snowflake.com/en/user-guide/data-load-snowpipe-streaming-overview)
- [High-Performance Architecture](https://docs.snowflake.com/en/user-guide/snowpipe-streaming-high-performance-overview)
- [Snowpipe Streaming SDK JavaDoc](https://javadoc.io/doc/com.snowflake/snowpipe-streaming/latest/index.html)
- [Key-Pair Authentication](https://docs.snowflake.com/en/user-guide/key-pair-auth)

## License

This project is part of the Automated Intelligence demo and follows Snowflake's documentation examples.
