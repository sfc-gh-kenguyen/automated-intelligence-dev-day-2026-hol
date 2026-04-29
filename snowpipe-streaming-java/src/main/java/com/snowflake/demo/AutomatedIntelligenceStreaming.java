package com.snowflake.demo;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

public class AutomatedIntelligenceStreaming {
    private static final Logger logger = LoggerFactory.getLogger(AutomatedIntelligenceStreaming.class);

    private final ConfigManager config;
    private final SnowpipeStreamingManager streamingManager;

    public AutomatedIntelligenceStreaming(ConfigManager config, SnowpipeStreamingManager streamingManager) {
        this.config = config;
        this.streamingManager = streamingManager;
    }

    public void generateAndStreamOrders(int numOrders) throws Exception {
        long startTime = System.currentTimeMillis();
        logger.info("Starting to generate and stream {} orders", "%,d".formatted(numOrders));

        int maxCustomerId = streamingManager.getMaxCustomerId();
        if (maxCustomerId == 0) {
            logger.error("No customers found in database. Please run generate_customers() stored procedure first to create customers.");
            throw new IllegalStateException("No customers available for order generation");
        }
        logger.info("Will generate orders for customer IDs in range 1-{}", "%,d".formatted(maxCustomerId));

        int batchSize = config.getIntProperty("orders.batch.size", 10000);
        logger.info("Using batch size: {} orders per insertRows call", "%,d".formatted(batchSize));
        
        int processedOrders = 0;
        int maxRetries = 3;
        
        while (processedOrders < numOrders) {
            int remainingOrders = numOrders - processedOrders;
            int currentBatchSize = Math.min(batchSize, remainingOrders);
            
            // Generate data once for this batch
            List<Order> orderBatch = new ArrayList<>(currentBatchSize);
            List<OrderItem> allOrderItems = new ArrayList<>();
            
            for (int i = 0; i < currentBatchSize; i++) {
                int customerId = DataGenerator.randomCustomerId(maxCustomerId);
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
                           "%,d".formatted(processedOrders), "%,d".formatted(numOrders), "%,d".formatted(allOrderItems.size()));
            }
        }

        long elapsedMs = System.currentTimeMillis() - startTime;
        logger.info("Successfully streamed {} orders in {} ms", "%,d".formatted(numOrders), "%,d".formatted(elapsedMs));
        printOffsetStatus();
    }

    private void printOffsetStatus() {
        logger.info("=== Offset Token Status ===");
        logger.info("Orders: {}", streamingManager.getLatestOrderOffset());
        logger.info("Order Items: {}", streamingManager.getLatestOrderItemOffset());
    }

    public static void main(String[] args) {
        logger.info("Starting Automated Intelligence Snowpipe Streaming");

        ConfigManager config = null;
        SnowpipeStreamingManager streamingManager = null;

        try {
            String configFile = args.length > 1 ? args[1] : "config_default.properties";
            String profileFile = args.length > 2 ? args[2] : "profile.json";
            
            config = new ConfigManager(configFile, profileFile);
            streamingManager = new SnowpipeStreamingManager(config);

            AutomatedIntelligenceStreaming app = new AutomatedIntelligenceStreaming(config, streamingManager);

            int numOrders = config.getIntProperty("num.orders.per.batch", 100);
            
            if (args.length > 0) {
                numOrders = Integer.parseInt(args[0]);
            }

            app.generateAndStreamOrders(numOrders);

            logger.info("Waiting for all channel data to flush to Snowflake...");
            boolean flushed = streamingManager.waitForFlush();
            if (!flushed) {
                logger.warn("Channel flush timed out after 120s. Reconciliation may report false orphans.");
            }

            // Run reconciliation to clean up any orphaned records
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

            logger.info("Application completed successfully");

        } catch (Exception e) {
            logger.error("Application error", e);
            System.exit(1);
        } finally {
            if (streamingManager != null) {
                streamingManager.close();
            }
        }
    }
}
