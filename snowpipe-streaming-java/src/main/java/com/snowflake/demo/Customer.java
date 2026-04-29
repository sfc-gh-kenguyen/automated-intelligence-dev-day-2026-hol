package com.snowflake.demo;

import java.util.HashMap;
import java.util.Map;

public class Customer {
    private int customerId;
    private String firstName;
    private String lastName;
    private String email;
    private String phone;
    private String address;
    private String city;
    private String state;
    private String zipCode;
    private String registrationDate;
    private String customerSegment;

    public Customer(int customerId, String firstName, String lastName, String email,
                    String phone, String address, String city, String state,
                    String zipCode, String registrationDate, String customerSegment) {
        this.customerId = customerId;
        this.firstName = firstName;
        this.lastName = lastName;
        this.email = email;
        this.phone = phone;
        this.address = address;
        this.city = city;
        this.state = state;
        this.zipCode = zipCode;
        this.registrationDate = registrationDate;
        this.customerSegment = customerSegment;
    }

    public Map<String, Object> toMap() {
        Map<String, Object> map = new HashMap<>();
        map.put("CUSTOMER_ID", customerId);
        map.put("FIRST_NAME", firstName);
        map.put("LAST_NAME", lastName);
        map.put("EMAIL", email);
        map.put("PHONE", phone);
        map.put("ADDRESS", address);
        map.put("CITY", city);
        map.put("STATE", state);
        map.put("ZIP_CODE", zipCode);
        map.put("REGISTRATION_DATE", registrationDate);
        map.put("CUSTOMER_SEGMENT", customerSegment);
        return map;
    }

    public int getCustomerId() {
        return customerId;
    }

    public String getCustomerSegment() {
        return customerSegment;
    }
}
