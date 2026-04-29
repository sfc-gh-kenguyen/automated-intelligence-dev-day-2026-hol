/*
=============================================================================
SNOWFLAKE MANAGED MCP SERVER SETUP
=============================================================================
Creates an MCP server exposing Cortex Search, Cortex Analyst, ML models,
and SQL execution as tools for external AI agents.

Prerequisites:
- AUTOMATED_INTELLIGENCE.SEMANTIC.PRODUCT_REVIEWS_SEARCH (Cortex Search)
- AUTOMATED_INTELLIGENCE.SEMANTIC.SUPPORT_TICKETS_SEARCH (Cortex Search)
- AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES.BUSINESS_INSIGHTS_SEMANTIC_VIEW (Semantic View)
- AUTOMATED_INTELLIGENCE.MODELS.GET_PRODUCT_RECOMMENDATIONS (Stored Procedure)

Usage:
  snow sql -c <connection-name> -f setup_mcp_server.sql
=============================================================================
*/

USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
USE DATABASE AUTOMATED_INTELLIGENCE;
USE SCHEMA SEMANTIC;
USE WAREHOUSE AUTOMATED_INTELLIGENCE_WH;

CREATE OR REPLACE MCP SERVER AUTOMATED_INTELLIGENCE.SEMANTIC.AI_GATEWAY
FROM SPECIFICATION $$
  tools:
    - name: "product-reviews-search"
      type: "CORTEX_SEARCH_SERVICE_QUERY"
      identifier: "AUTOMATED_INTELLIGENCE.SEMANTIC.PRODUCT_REVIEWS_SEARCH"
      description: "Semantic search over product reviews. Use for finding reviews about specific products, quality issues, or customer sentiment."
      title: "Product Reviews Search"

    - name: "support-tickets-search"
      type: "CORTEX_SEARCH_SERVICE_QUERY"
      identifier: "AUTOMATED_INTELLIGENCE.SEMANTIC.SUPPORT_TICKETS_SEARCH"
      description: "Semantic search over support tickets. Use for finding tickets about shipping, returns, or customer issues."
      title: "Support Tickets Search"

    - name: "business-insights"
      type: "CORTEX_ANALYST_MESSAGE"
      identifier: "AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES.BUSINESS_INSIGHTS_SEMANTIC_VIEW"
      description: "Natural language queries for business metrics including revenue, orders, customers, and product performance."
      title: "Business Insights Analyst"

    - name: "product-recommendations"
      type: "GENERIC"
      identifier: "AUTOMATED_INTELLIGENCE.MODELS.GET_PRODUCT_RECOMMENDATIONS"
      description: "ML-powered product recommendations. Parameters: num_customers (int), num_products (int), segment (LOW_ENGAGEMENT|HIGH_VALUE_INACTIVE|NEW_CUSTOMERS|AT_RISK|HIGH_VALUE_ACTIVE)"
      title: "Product Recommendations"

    - name: "execute-sql"
      type: "SYSTEM_EXECUTE_SQL"
      description: "Execute ad-hoc SQL queries against the AUTOMATED_INTELLIGENCE database for custom analytics."
      title: "SQL Executor"
$$;

SHOW MCP SERVERS LIKE 'AI_GATEWAY' IN SCHEMA AUTOMATED_INTELLIGENCE.SEMANTIC;

DESCRIBE MCP SERVER AUTOMATED_INTELLIGENCE.SEMANTIC.AI_GATEWAY;
