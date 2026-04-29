package com.snowflake.demo;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.ByteArrayInputStream;
import java.security.KeyFactory;
import java.security.PrivateKey;
import java.security.spec.PKCS8EncodedKeySpec;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;
import java.util.Properties;

/**
 * Reconciliation utilities for cleaning up orphaned records after Snowpipe Streaming ingestion.
 * Handles atomicity violations that may occur due to backpressure or other transient errors.
 */
public class ReconciliationManager {
    private static final Logger logger = LoggerFactory.getLogger(ReconciliationManager.class);
    private final ConfigManager config;

    public ReconciliationManager(ConfigManager config) {
        this.config = config;
    }

    /**
     * Create a Snowflake JDBC connection for running SQL queries.
     */
    private Connection getConnection() throws Exception {
        String privateKeyPem = config.getPrivateKey();
        
        // Remove header/footer and whitespace
        String privateKeyContent = privateKeyPem
            .replace("-----BEGIN PRIVATE KEY-----", "")
            .replace("-----END PRIVATE KEY-----", "")
            .replaceAll("\\s", "");
        
        // Decode base64
        byte[] keyBytes = Base64.getDecoder().decode(privateKeyContent);
        
        // Generate private key
        PKCS8EncodedKeySpec keySpec = new PKCS8EncodedKeySpec(keyBytes);
        KeyFactory keyFactory = KeyFactory.getInstance("RSA");
        PrivateKey privateKey = keyFactory.generatePrivate(keySpec);
        
        // Build connection URL
        String url = "jdbc:snowflake://%s.snowflakecomputing.com".formatted(
            config.getSnowflakeAccount()
        );
        
        // Set connection properties
        Properties props = new Properties();
        props.put("user", config.getSnowflakeUser());
        props.put("role", config.getRole());
        props.put("warehouse", config.getWarehouse());
        props.put("db", config.getDatabase());
        props.put("schema", config.getSchema());
        props.put("privateKey", privateKey);
        
        return DriverManager.getConnection(url, props);
    }

    /**
     * Check for orphaned records and clean them up.
     * Returns statistics about what was found and deleted.
     */
    public Map<String, Long> reconcileAndCleanup() {
        logger.info("Starting reconciliation and cleanup...");
        
        Map<String, Long> stats = new HashMap<>();
        stats.put("orphanedOrdersFound", 0L);
        stats.put("orphanedOrdersDeleted", 0L);
        stats.put("orphanedItemsFound", 0L);
        stats.put("orphanedItemsDeleted", 0L);
        stats.put("duplicateOrdersFound", 0L);
        stats.put("duplicateOrdersDeleted", 0L);
        stats.put("finalOrdersCount", 0L);
        stats.put("finalItemsCount", 0L);
        
        try (Connection conn = getConnection();
             Statement stmt = conn.createStatement()) {
            
            String database = config.getDatabase();
            String schema = config.getSchema();
            
            // Get table names based on schema
            String ordersTable = schema.equalsIgnoreCase("STAGING") ? "ORDERS_STAGING" : "ORDERS";
            String orderItemsTable = schema.equalsIgnoreCase("STAGING") ? "ORDER_ITEMS_STAGING" : "ORDER_ITEMS";
            
            // 1. Check and delete orphaned orders (orders without order_items)
            // Use a single operation to ensure count matches delete
            logger.info("Checking for orphaned orders...");
            String deleteOrphanedOrdersSql = (
                "DELETE FROM %s.%s.%s " +
                    "WHERE order_id IN (" +
                    "  SELECT DISTINCT o.order_id " +
                    "  FROM %s.%s.%s o " +
                    "  LEFT JOIN %s.%s.%s oi ON o.order_id = oi.order_id " +
                    "  WHERE oi.order_id IS NULL" +
                    ")").formatted(
                database, schema, ordersTable,
                database, schema, ordersTable,
                database, schema, orderItemsTable
            );
            
            int deletedOrders = stmt.executeUpdate(deleteOrphanedOrdersSql);
            stats.put("orphanedOrdersDeleted", (long) deletedOrders);
            stats.put("orphanedOrdersFound", (long) deletedOrders);
            
            if (deletedOrders > 0) {
                logger.warn("Found and deleted {} orphaned orders",
                    "%,d".formatted(deletedOrders));
            } else {
                logger.info("✓ No orphaned orders found");
            }
            
            // 2. Check and delete orphaned order_items (order_items without orders)
            // Use a single operation to ensure count matches delete
            logger.info("Checking for orphaned order_items...");
            String deleteOrphanedItemsSql = (
                "DELETE FROM %s.%s.%s " +
                    "WHERE order_id IN (" +
                    "  SELECT DISTINCT oi.order_id " +
                    "  FROM %s.%s.%s oi " +
                    "  LEFT JOIN %s.%s.%s o ON oi.order_id = o.order_id " +
                    "  WHERE o.order_id IS NULL" +
                    ")").formatted(
                database, schema, orderItemsTable,
                database, schema, orderItemsTable,
                database, schema, ordersTable
            );
            
            int deletedItems = stmt.executeUpdate(deleteOrphanedItemsSql);
            stats.put("orphanedItemsDeleted", (long) deletedItems);
            stats.put("orphanedItemsFound", (long) deletedItems);
            
            if (deletedItems > 0) {
                logger.warn("Found and deleted {} orphaned order_items",
                    "%,d".formatted(deletedItems));
            } else {
                logger.info("✓ No orphaned order_items found");
            }
            
            // 3. Check and delete duplicate orders (keeping only one copy)
            logger.info("Checking for duplicate order_ids...");
            // First, count duplicates
            String checkDuplicatesSql = (
                "SELECT COUNT(*) - COUNT(DISTINCT order_id) as duplicate_count " +
                    "FROM %s.%s.%s").formatted(
                database, schema, ordersTable
            );
            
            ResultSet rs = stmt.executeQuery(checkDuplicatesSql);
            if (rs.next()) {
                stats.put("duplicateOrdersFound", rs.getLong(1));
            }
            rs.close();
            
            if (stats.get("duplicateOrdersFound") > 0) {
                logger.warn("Found {} duplicate orders. Deleting duplicates...",
                    "%,d".formatted(stats.get("duplicateOrdersFound")));
                
                // Delete duplicates, keeping only the first occurrence of each order_id
                String deleteDuplicatesSql = (
                    "DELETE FROM %s.%s.%s " +
                        "WHERE (order_id, order_date, total_amount) IN (" +
                        "  SELECT order_id, order_date, total_amount " +
                        "  FROM (" +
                        "    SELECT " +
                        "      order_id, " +
                        "      order_date, " +
                        "      total_amount, " +
                        "      ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY order_date) as rn " +
                        "    FROM %s.%s.%s" +
                        "  ) " +
                        "  WHERE rn > 1" +
                        ")").formatted(
                    database, schema, ordersTable,
                    database, schema, ordersTable
                );
                
                int deletedDuplicates = stmt.executeUpdate(deleteDuplicatesSql);
                stats.put("duplicateOrdersDeleted", (long) deletedDuplicates);
                logger.info("Deleted {} duplicate order records",
                    "%,d".formatted(deletedDuplicates));
            } else {
                logger.info("✓ No duplicate orders found");
            }
            
            // 4. Get final counts
            rs = stmt.executeQuery("SELECT COUNT(*) FROM %s.%s.%s".formatted(
                database, schema, ordersTable));
            if (rs.next()) {
                stats.put("finalOrdersCount", rs.getLong(1));
            }
            rs.close();
            
            rs = stmt.executeQuery("SELECT COUNT(*) FROM %s.%s.%s".formatted(
                database, schema, orderItemsTable));
            if (rs.next()) {
                stats.put("finalItemsCount", rs.getLong(1));
            }
            rs.close();
            
            // Log summary
            logger.info("=== Reconciliation Summary ===");
            logger.info("Orphaned orders found: {}", "%,d".formatted(stats.get("orphanedOrdersFound")));
            logger.info("Orphaned orders deleted: {}", "%,d".formatted(stats.get("orphanedOrdersDeleted")));
            logger.info("Orphaned items found: {}", "%,d".formatted(stats.get("orphanedItemsFound")));
            logger.info("Orphaned items deleted: {}", "%,d".formatted(stats.get("orphanedItemsDeleted")));
            logger.info("Duplicate orders found: {}", "%,d".formatted(stats.get("duplicateOrdersFound")));
            logger.info("Duplicate orders deleted: {}", "%,d".formatted(stats.get("duplicateOrdersDeleted")));
            logger.info("Final orders count: {}", "%,d".formatted(stats.get("finalOrdersCount")));
            logger.info("Final order_items count: {}", "%,d".formatted(stats.get("finalItemsCount")));
            
            if (stats.get("orphanedOrdersFound") == 0 && 
                stats.get("orphanedItemsFound") == 0 && 
                stats.get("duplicateOrdersFound") == 0) {
                logger.info("✅ Data is consistent - no issues found");
            } else {
                logger.info("✅ Reconciliation completed - data is now consistent");
            }
            
        } catch (Exception e) {
            logger.error("Reconciliation failed", e);
            throw new RuntimeException("Reconciliation failed", e);
        }
        
        return stats;
    }
}
