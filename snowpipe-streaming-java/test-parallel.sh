#!/bin/bash

# Test the parallel/horizontal scaling implementation
# This tests the "Medium Term (100x improvement)" horizontal scaling

echo "=== Testing Parallel Horizontal Scaling ==="
echo ""

# JVM options for JDBC Arrow compatibility
JVM_OPTS="--add-opens=java.base/java.nio=ALL-UNNAMED"

# Test 1: 100K orders across 5 parallel instances
echo "Test 1: Generating 100,000 orders with 5 parallel instances..."
echo "Each instance: 20,000 orders with partitioned customer ranges"
echo ""

time java $JVM_OPTS -cp target/automated-intelligence-streaming-1.0.0.jar \
  com.snowflake.demo.ParallelStreamingOrchestrator 100000 5

echo ""
echo "Waiting 10 seconds for all data to flush..."
sleep 10
echo ""

echo "=== Test Complete ==="
echo "Check Snowflake for row counts:"
echo "SELECT COUNT(*) FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS;"
echo "SELECT COUNT(*) FROM AUTOMATED_INTELLIGENCE.RAW.ORDER_ITEMS;"
echo ""
echo "Next steps for higher scale:"
echo "- 1M orders: ./test-parallel.sh 1000000 10"
echo "- 10M orders: ./test-parallel.sh 10000000 20"
