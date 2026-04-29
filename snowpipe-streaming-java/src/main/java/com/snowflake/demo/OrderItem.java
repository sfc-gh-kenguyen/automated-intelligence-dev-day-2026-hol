package com.snowflake.demo;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.Map;

public class OrderItem {
    private String orderItemId;
    private String orderId;
    private int productId;
    private String productName;
    private String productCategory;
    private int quantity;
    private BigDecimal unitPrice;
    private BigDecimal lineTotal;

    public OrderItem(String orderItemId, String orderId, int productId, String productName,
                     String productCategory, int quantity, BigDecimal unitPrice, BigDecimal lineTotal) {
        this.orderItemId = orderItemId;
        this.orderId = orderId;
        this.productId = productId;
        this.productName = productName;
        this.productCategory = productCategory;
        this.quantity = quantity;
        this.unitPrice = unitPrice;
        this.lineTotal = lineTotal;
    }

    public Map<String, Object> toMap() {
        Map<String, Object> map = new HashMap<>();
        map.put("ORDER_ITEM_ID", orderItemId);
        map.put("ORDER_ID", orderId);
        map.put("PRODUCT_ID", productId);
        map.put("PRODUCT_NAME", productName);
        map.put("PRODUCT_CATEGORY", productCategory);
        map.put("QUANTITY", quantity);
        map.put("UNIT_PRICE", unitPrice);
        map.put("LINE_TOTAL", lineTotal);
        return map;
    }

    public String getOrderItemId() {
        return orderItemId;
    }

    public String getOrderId() {
        return orderId;
    }
}
