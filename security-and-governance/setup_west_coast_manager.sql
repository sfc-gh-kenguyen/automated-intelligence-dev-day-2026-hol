-- ============================================================================
-- West Coast Manager - Region-Based Access Control
-- ============================================================================
-- This setup demonstrates region-based RBAC using the Business Insights Agent
-- Perfect for showing how the same agent gives different answers based on role
-- ============================================================================

USE ROLE AUTOMATED_INTELLIGENCE;
USE DATABASE AUTOMATED_INTELLIGENCE;
USE SCHEMA AUTOMATED_INTELLIGENCE.RAW;
USE WAREHOUSE AUTOMATED_INTELLIGENCE_WH;

-- ============================================================================
-- STEP 1: Create West Coast Manager Role
-- ============================================================================

CREATE ROLE IF NOT EXISTS west_coast_manager
    COMMENT = 'Regional manager with access limited to CA, OR, and WA states only';

-- Grant basic database and warehouse access
GRANT USAGE ON DATABASE AUTOMATED_INTELLIGENCE TO ROLE west_coast_manager;
GRANT USAGE ON SCHEMA AUTOMATED_INTELLIGENCE.RAW TO ROLE west_coast_manager;
GRANT USAGE ON SCHEMA AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES TO ROLE west_coast_manager;
GRANT USAGE ON WAREHOUSE AUTOMATED_INTELLIGENCE_WH TO ROLE west_coast_manager;

-- Grant SELECT on all relevant tables
GRANT SELECT ON TABLE AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS TO ROLE west_coast_manager;
GRANT SELECT ON TABLE AUTOMATED_INTELLIGENCE.RAW.ORDERS TO ROLE west_coast_manager;
GRANT SELECT ON TABLE AUTOMATED_INTELLIGENCE.RAW.ORDER_ITEMS TO ROLE west_coast_manager;
GRANT SELECT ON TABLE AUTOMATED_INTELLIGENCE.RAW.PRODUCT_CATALOG TO ROLE west_coast_manager;
GRANT SELECT ON TABLE AUTOMATED_INTELLIGENCE.RAW.PRODUCT_REVIEWS TO ROLE west_coast_manager;
GRANT SELECT ON TABLE AUTOMATED_INTELLIGENCE.RAW.SUPPORT_TICKETS TO ROLE west_coast_manager;

-- Grant access to dynamic tables (for Business Insights Agent)
GRANT SELECT ON AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES.DAILY_BUSINESS_METRICS TO ROLE west_coast_manager;
GRANT SELECT ON AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES.ENRICHED_ORDERS TO ROLE west_coast_manager;
GRANT SELECT ON AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES.ENRICHED_ORDER_ITEMS TO ROLE west_coast_manager;

-- ============================================================================
-- STEP 2: Create Row Access Policy for CUSTOMERS Table
-- ============================================================================
-- This policy filters customers by state
-- - Admin: sees ALL states (10 total)
-- - West Coast Manager: sees ONLY CA, OR, WA

-- Uses IS_ROLE_IN_SESSION() instead of CURRENT_ROLE() to support role hierarchy
-- and secondary roles. CURRENT_ROLE() only checks the active primary role.
CREATE OR REPLACE ROW ACCESS POLICY customers_region_policy
AS (state VARCHAR) RETURNS BOOLEAN ->
    CASE 
        -- Admin roles see everything (checks full role hierarchy)
        WHEN IS_ROLE_IN_SESSION('AUTOMATED_INTELLIGENCE') OR IS_ROLE_IN_SESSION('ACCOUNTADMIN') THEN TRUE
        -- West Coast Manager sees only their region
        WHEN IS_ROLE_IN_SESSION('WEST_COAST_MANAGER') 
             AND state IN ('CA', 'OR', 'WA') THEN TRUE
        ELSE FALSE
    END
COMMENT = 'Restricts west_coast_manager to CA, OR, and WA states only';

-- ============================================================================
-- STEP 3: Apply Row Access Policy to CUSTOMERS Table
-- ============================================================================

ALTER TABLE AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS 
    ADD ROW ACCESS POLICY customers_region_policy ON (state);

-- ============================================================================
-- STEP 4: Grant Agent Access to West Coast Manager
-- ============================================================================

GRANT USAGE ON DATABASE snowflake_intelligence TO ROLE west_coast_manager;
GRANT USAGE ON SCHEMA snowflake_intelligence.agents TO ROLE west_coast_manager;
GRANT USAGE ON AGENT snowflake_intelligence.agents.business_insights_agent TO ROLE west_coast_manager;

-- Grant access to semantic view
GRANT SELECT ON AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES.BUSINESS_INSIGHTS_SEMANTIC_VIEW TO ROLE west_coast_manager;

-- ============================================================================
-- STEP 5: Grant role to your user (OPTIONAL)
-- ============================================================================
GRANT ROLE west_coast_manager TO USER dash;

-- ============================================================================
-- Verification & Demo Queries
-- ============================================================================

SHOW ROLES LIKE 'WEST_COAST_MANAGER';
SHOW ROW ACCESS POLICIES IN SCHEMA AUTOMATED_INTELLIGENCE.RAW;

-- View policy details
SELECT * 
FROM TABLE(
    AUTOMATED_INTELLIGENCE.INFORMATION_SCHEMA.POLICY_REFERENCES(
        POLICY_NAME => 'AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS_REGION_POLICY'
    )
);

-- Show what tables west_coast_manager can access
SHOW GRANTS TO ROLE west_coast_manager;

-- ============================================================================
-- Demo Comparison Queries (Run these to see the difference!)
-- ============================================================================

-- As ADMIN - see all states
USE ROLE snowflake_intelligence_admin;

SELECT state, COUNT(*) as customers, COUNT(DISTINCT c.customer_id) as unique_customers
FROM CUSTOMERS c
GROUP BY state
ORDER BY state;
-- -- Result: 10 states

SELECT 
    c.state,
    COUNT(DISTINCT c.customer_id) as customer_count,
    COUNT(DISTINCT o.order_id) as order_count,
    ROUND(SUM(o.total_amount), 2) as total_revenue
FROM CUSTOMERS c
LEFT JOIN ORDERS o ON c.customer_id = o.customer_id
GROUP BY c.state
ORDER BY total_revenue DESC;

SELECT 
    customer_segment,
    state,
    COUNT(*) as customer_count
FROM CUSTOMERS
GROUP BY customer_segment, state
ORDER BY customer_segment, state;

SELECT 
    c.state,
    COUNT(DISTINCT st.ticket_id) as ticket_count,
    COUNT(DISTINCT CASE WHEN st.status = 'Open' THEN st.ticket_id END) as open_tickets,
    COUNT(DISTINCT CASE WHEN st.priority = 'High' THEN st.ticket_id END) as high_priority
FROM CUSTOMERS c
LEFT JOIN SUPPORT_TICKETS st ON c.customer_id = st.customer_id
GROUP BY c.state
ORDER BY ticket_count DESC;


-- As WEST COAST MANAGER - see only CA, OR, WA
USE ROLE west_coast_manager;

SELECT state, COUNT(*) as customers 
FROM CUSTOMERS c
GROUP BY state
ORDER BY state;
-- Result: Only 3 states (CA, OR, WA)

SELECT 
    state,
    COUNT(DISTINCT c.customer_id) as total_customers,
    COUNT(DISTINCT o.order_id) as total_orders,
    ROUND(SUM(o.total_amount), 2) as total_revenue
FROM CUSTOMERS c
LEFT JOIN ORDERS o ON c.customer_id = o.customer_id
GROUP BY c.state
ORDER BY total_revenue DESC;

SELECT 
    customer_segment,
    state,
    COUNT(*) as customer_count
FROM CUSTOMERS
GROUP BY customer_segment, state
ORDER BY customer_segment, state;

SELECT 
    c.state,
    COUNT(DISTINCT st.ticket_id) as ticket_count,
    COUNT(DISTINCT CASE WHEN st.status = 'Open' THEN st.ticket_id END) as open_tickets,
    COUNT(DISTINCT CASE WHEN st.priority = 'High' THEN st.ticket_id END) as high_priority
FROM CUSTOMERS c
LEFT JOIN SUPPORT_TICKETS st ON c.customer_id = st.customer_id
GROUP BY c.state
ORDER BY ticket_count DESC;



