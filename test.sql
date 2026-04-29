-- ============================================================================
-- TEST: Validate HOL setup + Agent creation + Agent interactions
-- ============================================================================
-- Run after setup.sql completes successfully.
-- Creates the Business Insights Agent and tests sample questions.
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE DASH_AUTOMATED_INTELLIGENCE_DB;
USE WAREHOUSE HOL_WH;

-- ============================================================================
-- STEP 1: Create the Business Insights Agent
-- ============================================================================

USE SCHEMA SEMANTIC;

CREATE OR REPLACE AGENT DASH_AUTOMATED_INTELLIGENCE_DB.SEMANTIC.BUSINESS_INSIGHTS_AGENT
  COMMENT = 'Multi-tool business insights agent with text-to-SQL and Agent Search'
FROM SPECIFICATION $$
instructions:
  orchestration: "You are a business insights assistant for an outdoor sports equipment company selling skis, snowboards, boots, and accessories. Route questions about revenue, orders, customers, segments, discounts, and business metrics to query_business_data. Route questions about product reviews, customer feedback, ratings, or sentiment to search_reviews. Route questions about support tickets, complaints, returns, or shipping issues to search_tickets. When a user asks WHY something happened (e.g. revenue dropped), combine structured data from query_business_data with unstructured insights from search_reviews and search_tickets to provide a complete answer."
  response: "Be concise and data-driven. Always cite specific numbers from query results. When presenting search results, include relevant context like ratings, dates, and categories. Format currency values with $ and two decimal places. When combining multiple tool results, clearly connect the structured findings (what happened) with unstructured findings (why it happened)."
  sample_questions:
    - question: "What was our total revenue in December 2025 vs February 2026?"
    - question: "Why are customers returning ski boots?"
    - question: "Revenue dropped in February — what caused it and what do reviews say?"
    - question: "Find reviews mentioning wrong size with a rating below 3"
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
      type: "data_to_chart"
      name: "visualize"
      description: "Generate charts and visualizations from query results. Use when the user asks to see data visually, plot trends, or create charts."

tool_resources:
  query_business_data:
    semantic_view: "DASH_AUTOMATED_INTELLIGENCE_DB.SEMANTIC.BUSINESS_ANALYTICS_SEMANTIC"
  search_reviews:
    search_service: "DASH_AUTOMATED_INTELLIGENCE_DB.RAW.PRODUCT_REVIEWS_SEARCH"
  search_tickets:
    search_service: "DASH_AUTOMATED_INTELLIGENCE_DB.RAW.SUPPORT_TICKETS_SEARCH"
$$;

SHOW AGENTS LIKE 'BUSINESS_INSIGHTS_AGENT' IN SCHEMA DASH_AUTOMATED_INTELLIGENCE_DB.SEMANTIC;

-- ============================================================================
-- STEP 2: Test Agent with sample questions
-- ============================================================================

-- Q1: "What" question (text-to-SQL)
SELECT TRY_PARSE_JSON(
  SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
    'DASH_AUTOMATED_INTELLIGENCE_DB.SEMANTIC.BUSINESS_INSIGHTS_AGENT',
    $${ "messages": [{"role": "user", "content": [{"type": "text", "text": "What was our total revenue in December 2025 vs February 2026?"}]}], "stream": false }$$
  )
) AS q1_revenue_comparison;

-- Q2: "Why" question (search)
SELECT TRY_PARSE_JSON(
  SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
    'DASH_AUTOMATED_INTELLIGENCE_DB.SEMANTIC.BUSINESS_INSIGHTS_AGENT',
    $${ "messages": [{"role": "user", "content": [{"type": "text", "text": "Why are customers returning ski boots?"}]}], "stream": false }$$
  )
) AS q2_full_response;

-- Q3: "What → Why" question (multi-tool)
SELECT TRY_PARSE_JSON(
  SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
    'DASH_AUTOMATED_INTELLIGENCE_DB.SEMANTIC.BUSINESS_INSIGHTS_AGENT',
    $${ "messages": [{"role": "user", "content": [{"type": "text", "text": "Revenue dropped in February — what caused it and what do reviews say?"}]}], "stream": false }$$
  )
) AS q3_full_response;

-- Q4: Multi-index search
SELECT TRY_PARSE_JSON(
  SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
    'DASH_AUTOMATED_INTELLIGENCE_DB.SEMANTIC.BUSINESS_INSIGHTS_AGENT',
    $${ "messages": [{"role": "user", "content": [{"type": "text", "text": "Find reviews mentioning wrong size with a rating below 3"}]}], "stream": false }$$
  )
) AS q4_full_response;

-- Q5: RBAC demo question
SELECT TRY_PARSE_JSON(
  SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
    'DASH_AUTOMATED_INTELLIGENCE_DB.SEMANTIC.BUSINESS_INSIGHTS_AGENT',
    $${ "messages": [{"role": "user", "content": [{"type": "text", "text": "What is our total revenue and customer count by state?"}]}], "stream": false }$$
  )
) AS q5_full_response;
