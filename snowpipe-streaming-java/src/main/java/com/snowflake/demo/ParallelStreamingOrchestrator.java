package com.snowflake.demo;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.*;

public class ParallelStreamingOrchestrator {
    private static final Logger logger = LoggerFactory.getLogger(ParallelStreamingOrchestrator.class);

    public static void main(String[] args) {
        if (args.length < 2) {
            System.err.println("Usage: java ParallelStreamingOrchestrator <total_orders> <num_parallel_instances>");
            System.err.println("Example: java ParallelStreamingOrchestrator 1000000 5");
            System.exit(1);
        }

        int totalOrders = Integer.parseInt(args[0]);
        int numInstances = Integer.parseInt(args[1]);

        logger.info("=== Parallel Streaming Orchestrator ===");
        logger.info("Total orders to generate: {}", totalOrders);
        logger.info("Number of parallel instances: {}", numInstances);

        ConfigManager config = null;
        ExecutorService executorService = Executors.newFixedThreadPool(numInstances);
        List<Future<StreamingResult>> futures = new ArrayList<>();

        try {
            config = new ConfigManager("config.properties", "profile.json");
            int maxCustomerId = getMaxCustomerId(config);
            
            logger.info("Total customers available: {}", maxCustomerId);
            
            int ordersPerInstance = totalOrders / numInstances;
            int customerRangeSize = maxCustomerId / numInstances;

            for (int i = 0; i < numInstances; i++) {
                int instanceId = i;
                int ordersForThisInstance = (i == numInstances - 1) 
                    ? totalOrders - (ordersPerInstance * i) 
                    : ordersPerInstance;
                
                int customerIdStart = (i * customerRangeSize) + 1;
                int customerIdEnd = (i == numInstances - 1) 
                    ? maxCustomerId 
                    : (i + 1) * customerRangeSize;

                logger.info("Instance {}: {} orders, customer IDs {}-{}", 
                           instanceId, ordersForThisInstance, customerIdStart, customerIdEnd);

                final ConfigManager finalConfig = config;
                Callable<StreamingResult> task = () -> {
                    return runStreamingInstance(instanceId, ordersForThisInstance, 
                                               customerIdStart, customerIdEnd, finalConfig);
                };
                
                futures.add(executorService.submit(task));
            }

            logger.info("All {} instances submitted. Waiting for completion...", numInstances);

            int totalOrdersGenerated = 0;
            int successfulInstances = 0;
            int failedInstances = 0;

            for (int i = 0; i < futures.size(); i++) {
                try {
                    StreamingResult result = futures.get(i).get();
                    if (result.success) {
                        totalOrdersGenerated += result.ordersGenerated;
                        successfulInstances++;
                        logger.info("Instance {} completed: {} orders in {} ms", 
                                   result.instanceId, result.ordersGenerated, result.durationMs);
                    } else {
                        failedInstances++;
                        logger.error("Instance {} failed with {} orders generated before failure", 
                                   result.instanceId, result.ordersGenerated);
                    }
                } catch (Exception e) {
                    failedInstances++;
                    logger.error("Instance {} failed with exception: {}", i, e.getMessage(), e);
                }
            }

            logger.info("=== Parallel Streaming Completed ===");
            logger.info("Successful instances: {}/{}", successfulInstances, numInstances);
            logger.info("Failed instances: {}", failedInstances);
            logger.info("Total orders generated: {}", totalOrdersGenerated);

            // Always run reconciliation to clean up any orphaned records
            // (Even "failed" instances may have inserted partial data before failing)
            logger.info("\n" + "=".repeat(60));
            logger.info("Starting post-ingestion reconciliation...");
            logger.info("=".repeat(60));
            
            try {
                ReconciliationManager reconciliationManager = new ReconciliationManager(config);
                Map<String, Long> reconciliationStats = reconciliationManager.reconcileAndCleanup();
                
                // Report if any inconsistencies were found
                if (reconciliationStats.get("orphanedOrdersFound") > 0 || 
                    reconciliationStats.get("orphanedItemsFound") > 0 ||
                    reconciliationStats.get("duplicateOrdersFound") > 0) {
                    logger.warn(
                        "⚠️  Data inconsistencies detected and cleaned: {} orphaned orders, {} orphaned order_items, {} duplicate orders",
                        "%,d".formatted(reconciliationStats.get("orphanedOrdersDeleted")),
                        "%,d".formatted(reconciliationStats.get("orphanedItemsDeleted")),
                        "%,d".formatted(reconciliationStats.get("duplicateOrdersDeleted"))
                    );
                } else {
                    logger.info("✅ No data inconsistencies found - ingestion was atomic");
                }
            } catch (Exception e) {
                logger.error("Reconciliation failed: {}", e.getMessage(), e);
                logger.warn("⚠️  Reconciliation failed but ingestion completed. Manual cleanup may be needed.");
            }
            
            logger.info("=".repeat(60) + "\n");

            if (failedInstances > 0) {
                System.exit(1);
            }

        } catch (Exception e) {
            logger.error("Orchestrator error", e);
            System.exit(1);
        } finally {
            executorService.shutdown();
            try {
                if (!executorService.awaitTermination(60, TimeUnit.SECONDS)) {
                    executorService.shutdownNow();
                }
            } catch (InterruptedException e) {
                executorService.shutdownNow();
            }
        }
    }

    private static StreamingResult runStreamingInstance(
            int instanceId, 
            int numOrders, 
            int customerIdStart, 
            int customerIdEnd,
            ConfigManager config) {
        
        logger.info("Instance {} starting: {} orders, customers {}-{}", 
                   instanceId, numOrders, customerIdStart, customerIdEnd);
        
        long startTime = System.currentTimeMillis();
        SnowpipeStreamingManager streamingManager = null;
        int ordersGenerated = 0;
        
        try {
            streamingManager = new SnowpipeStreamingManager(config, instanceId);
            PartitionedStreamingApp app = new PartitionedStreamingApp(
                config, streamingManager, customerIdStart, customerIdEnd);
            
            ordersGenerated = app.generateAndStreamOrders(numOrders);
            
            // Wait for this instance's channels to flush before declaring success
            boolean flushed = streamingManager.waitForFlush(120, 2000);
            if (!flushed) {
                logger.warn("Instance {} channels did not fully flush within 120s", instanceId);
            }
            
            long duration = System.currentTimeMillis() - startTime;
            return new StreamingResult(instanceId, ordersGenerated, duration, true);
            
        } catch (Exception e) {
            logger.error("Instance {} error: {}", instanceId, e.getMessage(), e);
            long duration = System.currentTimeMillis() - startTime;
            return new StreamingResult(instanceId, ordersGenerated, duration, false);
        } finally {
            if (streamingManager != null) {
                streamingManager.close();
            }
        }
    }

    private static int getMaxCustomerId(ConfigManager config) throws Exception {
        SnowpipeStreamingManager tempManager = null;
        try {
            tempManager = new SnowpipeStreamingManager(config, -1);
            return tempManager.getMaxCustomerId();
        } finally {
            if (tempManager != null) {
                tempManager.close();
            }
        }
    }

    static class StreamingResult {
        int instanceId;
        int ordersGenerated;
        long durationMs;
        boolean success;

        StreamingResult(int instanceId, int ordersGenerated, long durationMs, boolean success) {
            this.instanceId = instanceId;
            this.ordersGenerated = ordersGenerated;
            this.durationMs = durationMs;
            this.success = success;
        }
    }
}

class PartitionedStreamingApp {
    private static final Logger logger = LoggerFactory.getLogger(PartitionedStreamingApp.class);

    private final ConfigManager config;
    private final SnowpipeStreamingManager streamingManager;
    private final int customerIdStart;
    private final int customerIdEnd;

    public PartitionedStreamingApp(ConfigManager config, SnowpipeStreamingManager streamingManager,
                                   int customerIdStart, int customerIdEnd) {
        this.config = config;
        this.streamingManager = streamingManager;
        this.customerIdStart = customerIdStart;
        this.customerIdEnd = customerIdEnd;
    }

    public int generateAndStreamOrders(int numOrders) throws Exception {
        logger.info("Starting partitioned streaming: {} orders, customer range {}-{}", 
                   numOrders, customerIdStart, customerIdEnd);

        int batchSize = config.getIntProperty("orders.batch.size", 10000);
        logger.info("Using batch size: {} orders per insertRows call", batchSize);
        
        int processedOrders = 0;
        int maxRetries = 3;
        
        while (processedOrders < numOrders) {
            int remainingOrders = numOrders - processedOrders;
            int currentBatchSize = Math.min(batchSize, remainingOrders);
            
            // Generate data once for this batch
            List<Order> orderBatch = new ArrayList<>(currentBatchSize);
            List<OrderItem> allOrderItems = new ArrayList<>();
            
            for (int i = 0; i < currentBatchSize; i++) {
                int customerId = DataGenerator.randomCustomerIdInRange(customerIdStart, customerIdEnd);
                String customerSegment = streamingManager.getCustomerSegment(customerId);
                Order order = DataGenerator.generateOrder(customerId, customerSegment);
                orderBatch.add(order);
                
                int itemCount = DataGenerator.randomItemCount(customerSegment);
                List<OrderItem> orderItems = DataGenerator.generateOrderItems(order.getOrderId(), customerSegment, itemCount);
                allOrderItems.addAll(orderItems);
            }
            
            // Insert orders and items separately with individual retry logic
            // This prevents duplicate orders when items fail but orders succeed
            boolean ordersInserted = false;
            boolean itemsInserted = false;
            
            // Step 1: Insert orders with retry
            for (int retryCount = 0; retryCount <= maxRetries; retryCount++) {
                try {
                    streamingManager.insertOrders(orderBatch);
                    ordersInserted = true;
                    break;
                } catch (Exception e) {
                    if (retryCount >= maxRetries) {
                        logger.error("Failed to insert orders after {} attempts: {}", 
                                   maxRetries + 1, e.getMessage(), e);
                        throw e;
                    }
                    logger.warn("Orders insert failed (attempt {}/{}), retrying: {}", 
                               retryCount + 1, maxRetries + 1, e.getMessage());
                    Thread.sleep(1000L * (retryCount + 1));
                }
            }
            
            // Step 2: Brief pause before inserting items
            Thread.sleep(100);
            
            // Step 3: Insert order_items with retry
            for (int retryCount = 0; retryCount <= maxRetries; retryCount++) {
                try {
                    streamingManager.insertOrderItems(allOrderItems);
                    itemsInserted = true;
                    break;
                } catch (Exception e) {
                    if (retryCount >= maxRetries) {
                        logger.error("Failed to insert order_items after {} attempts: {}", 
                                   maxRetries + 1, e.getMessage(), e);
                        // Items failed but orders succeeded - reconciliation will clean this up
                        logger.warn("ATOMICITY VIOLATION: {} orders inserted but {} order_items failed. Reconciliation will clean up.",
                                   orderBatch.size(), allOrderItems.size());
                        throw e;
                    }
                    logger.warn("Order_items insert failed (attempt {}/{}), retrying: {}", 
                               retryCount + 1, maxRetries + 1, e.getMessage());
                    Thread.sleep(1000L * (retryCount + 1));
                }
            }
            
            // Both succeeded
            if (ordersInserted && itemsInserted) {
                processedOrders += currentBatchSize;
                logger.info("Progress: {}/{} orders streamed ({} order items)", 
                           processedOrders, numOrders, allOrderItems.size());
            }
        }

        logger.info("Successfully streamed {} orders (customer range: {}-{})", 
                   numOrders, customerIdStart, customerIdEnd);
        
        return processedOrders;
    }
}
