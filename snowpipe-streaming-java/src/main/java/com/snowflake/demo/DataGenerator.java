package com.snowflake.demo;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;
import java.util.UUID;

public class DataGenerator {
    private static final Random random = new Random();
    private static final DateTimeFormatter DATE_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd");
    private static final DateTimeFormatter DATETIME_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    public static int randomCustomerId(int maxCustomerId) {
        if (maxCustomerId <= 0) {
            throw new IllegalArgumentException("Max customer ID must be positive");
        }
        return random.nextInt(maxCustomerId) + 1;
    }

    public static int randomCustomerIdInRange(int minCustomerId, int maxCustomerId) {
        if (minCustomerId <= 0 || maxCustomerId < minCustomerId) {
            throw new IllegalArgumentException("Invalid customer ID range: " + minCustomerId + "-" + maxCustomerId);
        }
        int range = maxCustomerId - minCustomerId + 1;
        return minCustomerId + random.nextInt(range);
    }

    private static final String[] FIRST_NAMES = {
        "John", "Sarah", "Michael", "Emily", "David", "Jessica", "Chris", "Ashley",
        "Matt", "Amanda", "Ryan", "Lauren", "Kevin", "Nicole", "Brian", "Rachel",
        "Tyler", "Megan", "Josh", "Katie"
    };

    private static final String[] LAST_NAMES = {
        "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis",
        "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson",
        "Thomas", "Taylor", "Moore", "Jackson", "Martin"
    };

    private static final String[] STREETS = {
        "Main St", "Oak Ave", "Maple Dr", "Cedar Ln", "Pine Rd", "Elm St",
        "Washington Blvd", "Lake View Dr", "Mountain Way", "Summit Trail"
    };

    private static final String[] CITIES = {
        "Denver", "Salt Lake City", "Boulder", "Aspen", "Park City", "Jackson",
        "Telluride", "Steamboat Springs", "Vail", "Breckenridge", "Mammoth Lakes",
        "Tahoe City", "Whistler", "Banff", "Portland"
    };

    private static final String[] STATES = {
        "CO", "UT", "WY", "CA", "WA", "OR", "MT", "ID", "NV", "BC"
    };

    private static final String[] SEGMENTS = {"Premium", "Standard", "Basic"};

    private static final String[] ORDER_STATUSES = {
        "Completed", "Pending", "Shipped", "Cancelled", "Processing"
    };

    private static final String[] PRODUCT_NAMES = {
        "Powder Skis", "All-Mountain Skis", "Freestyle Snowboard", "Freeride Snowboard",
        "Ski Boots", "Snowboard Boots", "Ski Poles", "Ski Goggles", "Snowboard Bindings", "Ski Helmet"
    };

    private static final String[] PRODUCT_CATEGORIES = {
        "Skis", "Skis", "Snowboards", "Snowboards",
        "Boots", "Boots", "Accessories", "Accessories", "Accessories", "Accessories"
    };

    public static Customer generateCustomer(int customerId) {
        String firstName = randomElement(FIRST_NAMES);
        String lastName = randomElement(LAST_NAMES);
        String email = "customer" + customerId + "@email.com";
        String phone = "555-%03d-%04d".formatted(random.nextInt(900) + 100, random.nextInt(9000) + 1000);
        String address = (random.nextInt(9900) + 100) + " " + randomElement(STREETS);
        String city = randomElement(CITIES);
        String state = randomElement(STATES);
        String zipCode = "%05d".formatted(random.nextInt(90000) + 10000);
        LocalDate regDate = LocalDate.now().minusDays(random.nextInt(1825) + 1);
        String customerSegment = randomElement(SEGMENTS);

        return new Customer(customerId, firstName, lastName, email, phone, address,
                city, state, zipCode, regDate.format(DATE_FORMATTER), customerSegment);
    }

    public static Order generateOrder(int customerId, String customerSegment) {
        String orderId = UUID.randomUUID().toString();
        
        // Spread orders across different times of day (not just noon)
        int daysAgo = random.nextInt(365) + 1;
        int hour = random.nextInt(24);
        int minute = random.nextInt(60);
        int second = random.nextInt(60);
        LocalDateTime orderDate = LocalDateTime.now()
            .minusDays(daysAgo)
            .withHour(hour)
            .withMinute(minute)
            .withSecond(second);
        
        // Weight order statuses realistically (more completed, fewer cancelled)
        String orderStatus;
        double rand = random.nextDouble();
        if (rand < 0.65) {  // 65% completed
            orderStatus = "Completed";
        } else if (rand < 0.80) {  // 15% shipped
            orderStatus = "Shipped";
        } else if (rand < 0.90) {  // 10% processing
            orderStatus = "Processing";
        } else if (rand < 0.97) {  // 7% pending
            orderStatus = "Pending";
        } else {  // 3% cancelled
            orderStatus = "Cancelled";
        }
        
        // Segment-based order amounts
        BigDecimal totalAmount;
        BigDecimal discountPercent;
        
        switch (customerSegment) {
            case "Premium":
                // Premium: $500-$3000, rarely discounted (10% chance, 5-10% off)
                totalAmount = randomDecimal(500.0, 3000.0);
                discountPercent = random.nextInt(10) > 8 ?
                    new BigDecimal(random.nextInt(6) + 5) : BigDecimal.ZERO;
                break;
            case "Standard":
                // Standard: $100-$800, moderate discounts (40% chance, 5-20% off)
                totalAmount = randomDecimal(100.0, 800.0);
                discountPercent = random.nextInt(10) > 5 ?
                    new BigDecimal(random.nextInt(16) + 5) : BigDecimal.ZERO;
                break;
            default:  // Basic
                // Basic: $20-$300, frequent discounts (50% chance, 10-30% off)
                totalAmount = randomDecimal(20.0, 300.0);
                discountPercent = random.nextInt(10) > 4 ?
                    new BigDecimal(random.nextInt(21) + 10) : BigDecimal.ZERO;
                break;
        }
        
        BigDecimal shippingCost = randomDecimal(5.0, 50.0);

        return new Order(orderId, customerId, orderDate.format(DATETIME_FORMATTER),
                orderStatus, totalAmount, discountPercent, shippingCost);
    }

    public static List<OrderItem> generateOrderItems(String orderId, String customerSegment, int count) {
        List<OrderItem> items = new ArrayList<>();
        for (int i = 0; i < count; i++) {
            String orderItemId = UUID.randomUUID().toString();
            
            int productIndex = random.nextInt(PRODUCT_NAMES.length);
            int productId = 1001 + productIndex;
            String productName = PRODUCT_NAMES[productIndex];
            String productCategory = PRODUCT_CATEGORIES[productIndex];
            
            // Segment-based quantity
            int quantity;
            BigDecimal unitPrice;
            
            switch (customerSegment) {
                case "Premium":
                    quantity = random.nextInt(4) + 2;  // 2-5
                    unitPrice = randomDecimal(150.0, 500.0);
                    break;
                case "Standard":
                    quantity = random.nextInt(3) + 1;  // 1-3
                    unitPrice = randomDecimal(50.0, 250.0);
                    break;
                default:  // Basic
                    quantity = random.nextInt(2) + 1;  // 1-2
                    unitPrice = randomDecimal(10.0, 100.0);
                    break;
            }
            
            BigDecimal lineTotal = unitPrice.multiply(new BigDecimal(quantity)).setScale(2, RoundingMode.HALF_UP);

            items.add(new OrderItem(orderItemId, orderId, productId, productName,
                    productCategory, quantity, unitPrice, lineTotal));
        }
        return items;
    }

    private static <T> T randomElement(T[] array) {
        return array[random.nextInt(array.length)];
    }

    private static BigDecimal randomDecimal(double min, double max) {
        double value = min + (max - min) * random.nextDouble();
        return new BigDecimal(value).setScale(2, RoundingMode.HALF_UP);
    }

    public static int randomItemCount(String customerSegment) {
        switch (customerSegment) {
            case "Premium":
                return random.nextInt(6) + 3;  // 3-8 items
            case "Standard":
                return random.nextInt(4) + 2;  // 2-5 items
            default:  // Basic
                return random.nextInt(3) + 1;  // 1-3 items
        }
    }
}
