-- ============================================================================
-- Cortex Agent: Business Insights Agent
-- ============================================================================
-- Creates an agent using the CREATE AGENT API that routes across:
--   1. Text-to-SQL (Cortex Analyst) via semantic view
--   2. Multi-index Cortex Search over product reviews (Agent Search)
--   3. Multi-index Cortex Search over support tickets (Agent Search)
--
-- The agent automatically routes user questions to the right tool,
-- enabling "what happened → why" conversations that span structured
-- and unstructured data.
--
-- Prerequisites (created by setup.sql):
--   - DASH_AUTOMATED_INTELLIGENCE_DB.SEMANTIC.BUSINESS_ANALYTICS_SEMANTIC
--   - DASH_AUTOMATED_INTELLIGENCE_DB.RAW.PRODUCT_REVIEWS_SEARCH
--   - DASH_AUTOMATED_INTELLIGENCE_DB.RAW.SUPPORT_TICKETS_SEARCH
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE DASH_AUTOMATED_INTELLIGENCE_DB;
USE SCHEMA SEMANTIC;
USE WAREHOUSE HOL_WH;

CREATE OR REPLACE AGENT DASH_AUTOMATED_INTELLIGENCE_DB.SEMANTIC.BUSINESS_INSIGHTS_AGENT
  COMMENT = 'Multi-tool business insights agent with text-to-SQL and Agent Search'
FROM SPECIFICATION $$
instructions:
  orchestration: "You are a business insights assistant for an outdoor sports equipment company selling skis, snowboards, boots, and accessories. Route questions about revenue, orders, customers, segments, discounts, and business metrics to query_business_data. Route questions about product reviews, customer feedback, ratings, or sentiment to search_reviews. Route questions about support tickets, complaints, returns, or shipping issues to search_tickets. Route questions about product details, features, pricing, or catalog to search_products. When a user asks WHY something happened (e.g. revenue dropped), combine structured data from query_business_data with unstructured insights from search_reviews and search_tickets to provide a complete answer."
  response: "Be concise and data-driven. Always cite specific numbers from query results. When presenting search results, include relevant context like ratings, dates, and categories. Format currency values with $ and two decimal places. When combining multiple tool results, clearly connect the structured findings (what happened) with unstructured findings (why it happened)."
  sample_questions:
    - question: "Show me monthly revenue trend from June 2025 to April 2026"
    - question: "Revenue dropped in February — what caused it and what do reviews say?"
    - question: "Find reviews mentioning wrong size with a rating below 3"
    - question: "Why are customers returning ski boots?"
    - question: "What is our total revenue and customer count by state?"

tools:
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "query_business_data"
      description: "Query structured business data using natural language. Covers orders, revenue, customers, segments, products, discounts, shipping, and order status. Use for questions about metrics, trends, aggregations, comparisons, and any quantitative business analysis."
  - tool_spec:
      type: "cortex_search"
      name: "search_reviews"
      description: "Semantic search over product reviews from customers. Use for finding reviews about specific products, quality issues, sizing problems, customer sentiment, or product comparisons."
  - tool_spec:
      type: "cortex_search"
      name: "search_tickets"
      description: "Semantic search over customer support tickets. Use for finding tickets about returns, shipping delays, sizing issues, product defects, or any customer complaints."
  - tool_spec:
      type: "cortex_search"
      name: "search_products"
      description: "Search the product catalog for product details, descriptions, features, pricing, and categories. Use for questions about what products are available, product specs, or product comparisons."

tool_resources:
  query_business_data:
    semantic_view: "DASH_AUTOMATED_INTELLIGENCE_DB.SEMANTIC.BUSINESS_ANALYTICS_SEMANTIC"
    execution_environment:
      type: "warehouse"
      warehouse: "HOL_WH"
  search_reviews:
    search_service: "DASH_AUTOMATED_INTELLIGENCE_DB.RAW.PRODUCT_REVIEWS_SEARCH"
  search_tickets:
    search_service: "DASH_AUTOMATED_INTELLIGENCE_DB.RAW.SUPPORT_TICKETS_SEARCH"
  search_products:
    search_service: "DASH_AUTOMATED_INTELLIGENCE_DB.RAW.PRODUCT_SEARCH_SERVICE"
$$;

-- Verify Agent
SHOW AGENTS LIKE 'BUSINESS_INSIGHTS_AGENT' IN SCHEMA DASH_AUTOMATED_INTELLIGENCE_DB.SEMANTIC;

-- Make agent visible in Snowflake Intelligence
-- On fresh accounts (no SI object), agents auto-appear — no action needed.
-- If the account already has a SI object, uncomment the following:
-- ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT ADD AGENT DASH_AUTOMATED_INTELLIGENCE_DB.SEMANTIC.BUSINESS_INSIGHTS_AGENT;

-- ============================================================================
-- Sample Questions for the Agent
-- ============================================================================
--
-- "WHAT" questions (structured data via text-to-SQL):
--   "What was our total revenue in December 2025?"
--   "What are the top 5 product categories by order count?"
--   "What is the cancellation rate by month?"
--
-- "WHY" questions (unstructured search):
--   "Why are customers returning ski boots?"
--   "What are customers complaining about in February?"
--   "Show me support tickets about sizing issues"
--
-- "WHAT → WHY" multi-turn conversations:
--   User: "What happened to revenue in February vs January?"
--   Agent: Revenue dropped 38% ($78M → $32M). Cancellations spiked to 12%.
--   User: "Why did that happen?"
--   Agent: [searches reviews + tickets] Boot sizing complaints drove returns.
--          15 negative reviews mention "wrong size" and "tight fit".
--          40 support tickets filed for exchanges in Feb (vs 8 in Jan).
--
-- Multi-index search (keyword + semantic):
--   "Find reviews mentioning 'wrong size' with a rating below 3"
--   "Search for tickets about shipping delays during the holiday season"
--   "What do customers say about the Powder Skis quality?"
-- ============================================================================
