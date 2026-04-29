package com.snowflake.demo;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.Map;

public class Order {
    private String orderId;
    private int customerId;
    private String orderDate;
    private String orderStatus;
    private BigDecimal totalAmount;
    private BigDecimal discountPercent;
    private BigDecimal shippingCost;

    public Order(String orderId, int customerId, String orderDate, String orderStatus,
                 BigDecimal totalAmount, BigDecimal discountPercent, BigDecimal shippingCost) {
        this.orderId = orderId;
        this.customerId = customerId;
        this.orderDate = orderDate;
        this.orderStatus = orderStatus;
        this.totalAmount = totalAmount;
        this.discountPercent = discountPercent;
        this.shippingCost = shippingCost;
    }

    public Map<String, Object> toMap() {
        Map<String, Object> map = new HashMap<>();
        map.put("ORDER_ID", orderId);
        map.put("CUSTOMER_ID", customerId);
        map.put("ORDER_DATE", orderDate);
        map.put("ORDER_STATUS", orderStatus);
        map.put("TOTAL_AMOUNT", totalAmount);
        map.put("DISCOUNT_PERCENT", discountPercent);
        map.put("SHIPPING_COST", shippingCost);
        return map;
    }

    public String getOrderId() {
        return orderId;
    }

    public int getCustomerId() {
        return customerId;
    }
}
