#!/bin/bash

# Test the optimized single-instance bulk generation
# This tests the "Medium Term (100x improvement)" changes

echo "=== Testing Optimized Bulk Generation ==="
echo "Configuration: orders.batch.size=10000, max.client.lag=60"
echo ""

# JVM options for JDBC Arrow compatibility
JVM_OPTS="--add-opens=java.base/java.nio=ALL-UNNAMED"

# Test 1: 10K orders (1 batch)
echo "Test 1: Generating 10,000 orders (single batch)..."
time java $JVM_OPTS -jar target/automated-intelligence-streaming-1.0.0.jar 10000

echo ""
echo "Waiting 5 seconds for data to flush..."
sleep 5
echo ""

# Test 2: 100K orders (10 batches)
echo "Test 2: Generating 100,000 orders (10 batches of 10K each)..."
time java $JVM_OPTS -jar target/automated-intelligence-streaming-1.0.0.jar 100000

echo ""
echo "=== Tests Complete ==="
echo "Check Snowflake for row counts:"
echo "SELECT COUNT(*) FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS;"
echo "SELECT COUNT(*) FROM AUTOMATED_INTELLIGENCE.RAW.ORDER_ITEMS;"
