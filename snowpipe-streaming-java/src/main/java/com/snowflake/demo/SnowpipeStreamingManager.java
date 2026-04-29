package com.snowflake.demo;

import com.snowflake.ingest.streaming.SnowflakeStreamingIngestChannel;
import com.snowflake.ingest.streaming.SnowflakeStreamingIngestClient;
import com.snowflake.ingest.streaming.SnowflakeStreamingIngestClientFactory;
import com.snowflake.ingest.streaming.OpenChannelResult;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.security.KeyFactory;
import java.security.PrivateKey;
import java.security.spec.PKCS8EncodedKeySpec;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.Base64;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.stream.Collectors;

public class SnowpipeStreamingManager {
    private static final Logger logger = LoggerFactory.getLogger(SnowpipeStreamingManager.class);

    private final SnowflakeStreamingIngestClient ordersClient;
    private final SnowflakeStreamingIngestClient orderItemsClient;
    private final SnowflakeStreamingIngestChannel ordersChannel;
    private final SnowflakeStreamingIngestChannel orderItemsChannel;
    private final ConfigManager config;
    private final Properties connectionProps;
    private volatile String lastOrdersOffset;
    private volatile String lastOrderItemsOffset;

    public SnowpipeStreamingManager(ConfigManager config) throws Exception {
        this(config, -1);
    }

    public SnowpipeStreamingManager(ConfigManager config, int instanceId) throws Exception {
        this.config = config;

        this.connectionProps = new Properties();
        connectionProps.put("account", config.getSnowflakeAccount());
        connectionProps.put("user", config.getSnowflakeUser());
        connectionProps.put("url", config.getSnowflakeUrl());
        connectionProps.put("private_key", config.getPrivateKey());
        connectionProps.put("role", config.getRole());
        connectionProps.put("warehouse", config.getWarehouse());
        connectionProps.put("db", config.getDatabase());
        connectionProps.put("schema", config.getSchema());

        String channelSuffix = (instanceId >= 0) ? "_instance_" + instanceId : "";
        logger.info("Creating Snowflake Streaming clients and opening channels{}", 
                   instanceId >= 0 ? " for instance " + instanceId : "...");
        
        this.ordersClient = SnowflakeStreamingIngestClientFactory.builder(
                "ORDERS_CLIENT_" + java.util.UUID.randomUUID(),
                config.getDatabase(),
                config.getSchema(),
                config.getProperty("pipe.orders.name")
        )
                .setProperties(connectionProps)
                .build();
        
        this.orderItemsClient = SnowflakeStreamingIngestClientFactory.builder(
                "ORDER_ITEMS_CLIENT_" + java.util.UUID.randomUUID(),
                config.getDatabase(),
                config.getSchema(),
                config.getProperty("pipe.order_items.name")
        )
                .setProperties(connectionProps)
                .build();

        this.ordersChannel = openChannel(
                ordersClient,
                config.getProperty("channel.orders.name") + channelSuffix
        );

        this.orderItemsChannel = openChannel(
                orderItemsClient,
                config.getProperty("channel.order_items.name") + channelSuffix
        );

        logger.info("All clients and channels initialized successfully");
    }

    private SnowflakeStreamingIngestChannel openChannel(SnowflakeStreamingIngestClient client, String channelName) throws Exception {
        String initialOffset = "0";
        OpenChannelResult result = client.openChannel(channelName, initialOffset);
        SnowflakeStreamingIngestChannel channel = result.getChannel();
        
        String latestOffset = channel.getLatestCommittedOffsetToken();
        logger.info("Channel {} opened. Latest committed offset: {}", channelName, 
                    latestOffset != null ? latestOffset : "NULL (new channel)");
        
        return channel;
    }

    private PrivateKey parsePrivateKey(String privateKeyPEM) throws Exception {
        String privateKeyPEMClean = privateKeyPEM
            .replace("-----BEGIN PRIVATE KEY-----", "")
            .replace("-----END PRIVATE KEY-----", "")
            .replaceAll("\\s", "");
        
        byte[] encoded = Base64.getDecoder().decode(privateKeyPEMClean);
        PKCS8EncodedKeySpec keySpec = new PKCS8EncodedKeySpec(encoded);
        KeyFactory kf = KeyFactory.getInstance("RSA");
        return kf.generatePrivate(keySpec);
    }

    public int getMaxCustomerId() throws Exception {
        String jdbcUrl = config.getSnowflakeUrl().replace(":443", "").replace("https://", "jdbc:snowflake://");
        
        Properties jdbcProps = new Properties();
        jdbcProps.put("account", config.getSnowflakeAccount());
        jdbcProps.put("user", config.getSnowflakeUser());
        jdbcProps.put("role", config.getRole());
        jdbcProps.put("warehouse", config.getWarehouse());
        jdbcProps.put("db", config.getDatabase());
        jdbcProps.put("schema", config.getSchema());
        
        PrivateKey privateKey = parsePrivateKey(config.getPrivateKey());
        jdbcProps.put("privateKey", privateKey);
        
        int maxId = 1;
        try (Connection conn = DriverManager.getConnection(jdbcUrl, jdbcProps);
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery("SELECT MAX(CUSTOMER_ID) as MAX_ID FROM " + 
                                            config.getDatabase() + ".RAW.CUSTOMERS")) {
            if (rs.next()) {
                maxId = rs.getInt("MAX_ID");
            }
            logger.info("Max customer ID in database: {}", maxId);
        }
        
        return maxId;
    }

    public String getCustomerSegment(int customerId) {
        // For simplicity during high-volume streaming, randomly assign segments
        // to avoid frequent DB queries that could slow down ingestion
        String[] segments = {"Premium", "Standard", "Basic"};
        return segments[new java.util.Random().nextInt(segments.length)];
    }

    public void insertOrder(Order order) throws Exception {
        Map<String, Object> row = order.toMap();
        String offsetToken = "order_" + order.getOrderId();
        
        ordersChannel.appendRow(row, offsetToken);
        logger.debug("Order {} inserted with offset {}", order.getOrderId(), offsetToken);
    }

    public void insertOrders(List<Order> orders) throws Exception {
        if (orders.isEmpty()) {
            return;
        }
        
        String startOffset = "order_" + orders.getFirst().getOrderId();
        String endOffset = "order_" + orders.getLast().getOrderId();
        
        List<Map<String, Object>> rows = orders.stream()
                .map(Order::toMap)
                .collect(Collectors.toList());
        
        insertWithBackpressureRetry(ordersChannel, rows, startOffset, endOffset, "orders");
        this.lastOrdersOffset = endOffset;
        logger.debug("Inserted {} orders (offset range: {} to {})", 
                    orders.size(), startOffset, endOffset);
    }

    public void insertOrderItems(List<OrderItem> items) throws Exception {
        if (items.isEmpty()) {
            return;
        }
        
        String startOffset = "item_" + items.getFirst().getOrderItemId();
        String endOffset = "item_" + items.getLast().getOrderItemId();
        
        List<Map<String, Object>> rows = items.stream()
                .map(OrderItem::toMap)
                .collect(Collectors.toList());
        
        insertWithBackpressureRetry(orderItemsChannel, rows, startOffset, endOffset, "order_items");
        this.lastOrderItemsOffset = endOffset;
        logger.debug("Inserted {} order items (offset range: {} to {})", 
                    items.size(), startOffset, endOffset);
    }

    /**
     * Insert rows with exponential backoff retry for ReceiverSaturated errors.
     * 
     * @param channel The streaming channel to insert into
     * @param rows Data rows to insert
     * @param startOffset Starting offset token
     * @param endOffset Ending offset token
     * @param dataType Description of data type (for logging)
     */
    private void insertWithBackpressureRetry(
            SnowflakeStreamingIngestChannel channel,
            List<Map<String, Object>> rows,
            String startOffset,
            String endOffset,
            String dataType) throws Exception {
        
        int maxRetries = 10;
        double delay = 1.0;  // Initial delay in seconds
        double maxDelay = 30.0;
        
        for (int attempt = 0; attempt < maxRetries; attempt++) {
            try {
                channel.appendRows(rows, startOffset, endOffset);
                
                if (attempt > 0) {
                    logger.info("Successfully inserted {} {} after {} attempts",
                               rows.size(), dataType, attempt + 1);
                }
                return;
                
            } catch (Exception e) {
                String errorMsg = e.getMessage();
                
                // Check for ReceiverSaturated (HTTP 429) backpressure errors
                // The Java SDK wraps the error — message may contain "ReceiverSaturated",
                // "429", or "running full" depending on the SDK version
                if (errorMsg.contains("ReceiverSaturated") || errorMsg.contains("429") 
                        || errorMsg.contains("running full") || errorMsg.contains("cannot be accepted")) {
                    if (attempt < maxRetries - 1) {
                        logger.warn("Backpressure detected for {} (attempt {}/{}): " +
                                   "Channel buffers full. Retrying in {:.1f}s...",
                                   dataType, attempt + 1, maxRetries, delay);
                        Thread.sleep((long) (delay * 1000));
                        delay = Math.min(delay * 2, maxDelay);  // Exponential backoff
                        continue;
                    } else {
                        logger.error("Failed to insert {} {} after {} attempts: " +
                                    "Channel buffers remain saturated",
                                    rows.size(), dataType, maxRetries);
                        throw e;
                    }
                } else {
                    // Non-backpressure error, re-throw immediately
                    logger.error("Unexpected error inserting {}: {}", dataType, errorMsg);
                    throw e;
                }
            }
        }
    }

    public String getLatestOrderOffset() {
        return ordersChannel.getLatestCommittedOffsetToken();
    }

    public String getLatestOrderItemOffset() {
        return orderItemsChannel.getLatestCommittedOffsetToken();
    }

    /**
     * Wait until both channels have committed all in-flight data.
     * Polls each channel's latest committed offset token until it matches
     * the last offset we sent, confirming Snowflake has received everything.
     *
     * @param timeoutSeconds Maximum time to wait
     * @param pollIntervalMs Polling interval in milliseconds
     * @return true if both channels flushed within the timeout
     */
    public boolean waitForFlush(int timeoutSeconds, long pollIntervalMs) throws InterruptedException {
        logger.info("Waiting for all channels to flush in-flight data...");
        long start = System.currentTimeMillis();
        long timeoutMs = timeoutSeconds * 1000L;

        boolean ordersFlushed = (lastOrdersOffset == null);
        boolean itemsFlushed = (lastOrderItemsOffset == null);

        if (ordersFlushed && itemsFlushed) {
            logger.info("No data was sent — nothing to flush");
            return true;
        }

        while (System.currentTimeMillis() - start < timeoutMs) {
            if (!ordersFlushed) {
                String committed = ordersChannel.getLatestCommittedOffsetToken();
                if (lastOrdersOffset.equals(committed)) {
                    long elapsed = System.currentTimeMillis() - start;
                    logger.info("Channel orders flushed (offset {}) in {}ms", committed, elapsed);
                    ordersFlushed = true;
                }
            }

            if (!itemsFlushed) {
                String committed = orderItemsChannel.getLatestCommittedOffsetToken();
                if (lastOrderItemsOffset.equals(committed)) {
                    long elapsed = System.currentTimeMillis() - start;
                    logger.info("Channel order_items flushed (offset {}) in {}ms", committed, elapsed);
                    itemsFlushed = true;
                }
            }

            if (ordersFlushed && itemsFlushed) {
                long total = System.currentTimeMillis() - start;
                logger.info("All channels flushed in {}ms", total);
                return true;
            }

            Thread.sleep(pollIntervalMs);
        }

        // Timeout — log which channels are still pending
        if (!ordersFlushed) {
            String committed = ordersChannel.getLatestCommittedOffsetToken();
            logger.warn("Channel orders NOT flushed after {}s (expected: {}, committed: {})",
                        timeoutSeconds, lastOrdersOffset, committed);
        }
        if (!itemsFlushed) {
            String committed = orderItemsChannel.getLatestCommittedOffsetToken();
            logger.warn("Channel order_items NOT flushed after {}s (expected: {}, committed: {})",
                        timeoutSeconds, lastOrderItemsOffset, committed);
        }
        return false;
    }

    public boolean waitForFlush() throws InterruptedException {
        return waitForFlush(120, 2000);
    }

    public void close() {
        try {
            logger.info("Closing channels...");
            if (ordersChannel != null) ordersChannel.close();
            if (orderItemsChannel != null) orderItemsChannel.close();
            
            logger.info("Closing clients...");
            if (ordersClient != null) ordersClient.close();
            if (orderItemsClient != null) orderItemsClient.close();
            
            logger.info("Snowpipe Streaming manager closed successfully");
        } catch (Exception e) {
            logger.error("Error closing Snowpipe Streaming manager", e);
        }
    }
}
