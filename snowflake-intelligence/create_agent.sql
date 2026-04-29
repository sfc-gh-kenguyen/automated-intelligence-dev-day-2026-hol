-- ============================================================================
-- Cortex Agent: Business Insights Agent
-- ============================================================================
-- Creates an agent using the CREATE AGENT API that routes across:
--   1. Text-to-SQL (Cortex Analyst) via semantic view
--   2. Cortex Search over product reviews
--   3. Cortex Search over support tickets
--
-- The agent automatically routes user questions to the right tool.
--
-- Prerequisites:
--   - AUTOMATED_INTELLIGENCE.SEMANTIC.BUSINESS_ANALYTICS_SEMANTIC (Semantic View)
--   - AUTOMATED_INTELLIGENCE.SEMANTIC.PRODUCT_REVIEWS_SEARCH (Cortex Search)
--   - AUTOMATED_INTELLIGENCE.SEMANTIC.SUPPORT_TICKETS_SEARCH (Cortex Search)
--
-- Usage:
--   snow sql -c <connection-name> -f create_agent.sql
-- ============================================================================

USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
USE DATABASE AUTOMATED_INTELLIGENCE;
USE SCHEMA SEMANTIC;
USE WAREHOUSE AUTOMATED_INTELLIGENCE_WH;

-- ============================================================================
-- Create the Business Insights Agent
-- ============================================================================
-- This agent combines structured analytics (text-to-SQL) with unstructured
-- search (Cortex Search) so users can ask both data questions and semantic
-- search queries in one conversation.

CREATE OR REPLACE AGENT AUTOMATED_INTELLIGENCE.SEMANTIC.BUSINESS_INSIGHTS_AGENT
  COMMENT = 'Multi-tool business insights agent with text-to-SQL, semantic search, and charting'
  PROFILE = '{"display_name": "Business Insights Agent", "color": "blue"}'
FROM SPECIFICATION $spec$
{
  "models": {
    "orchestration": "auto"
  },
  "orchestration": {
    "budget": {
      "seconds": 900,
      "tokens": 400000
    }
  },
  "instructions": {
    "orchestration": "You are a business insights assistant for an outdoor sports equipment company. Route questions about revenue, orders, customers, and business metrics to the query_business_data tool. Route questions about product reviews, customer feedback, or sentiment to the search_reviews tool. Route questions about support tickets, issues, or complaints to the search_tickets tool. When a question spans multiple domains, use multiple tools and synthesize the results.",
    "response": "Be concise and data-driven. Always cite specific numbers from query results. When presenting search results, include relevant context like ratings, dates, and categories. Format currency values with $ and two decimal places."
  },
  "tools": [
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "query_business_data",
        "description": "Query structured business data using natural language. Covers orders, revenue, customers, products, discounts, and shipping. Use for questions about metrics, trends, aggregations, comparisons, and any quantitative business analysis."
      }
    },
    {
      "tool_spec": {
        "type": "cortex_search",
        "name": "search_reviews",
        "description": "Semantic search over product reviews from customers. Use for finding reviews about specific products, quality issues, customer sentiment, feature feedback, or product comparisons based on real customer experiences."
      }
    },
    {
      "tool_spec": {
        "type": "cortex_search",
        "name": "search_tickets",
        "description": "Semantic search over customer support tickets. Use for finding tickets about shipping problems, returns, product defects, billing issues, or any customer complaints and their resolutions."
      }
    },
    {
      "tool_spec": {
        "type": "data_to_chart",
        "name": "data_to_chart",
        "description": "Generates visualizations and charts from query results. Use when the user asks to see data visually, plot trends, or create charts."
      }
    }
  ],
  "tool_resources": {
    "query_business_data": {
      "execution_environment": {
        "query_timeout": 299,
        "type": "warehouse",
        "warehouse": ""
      },
      "semantic_view": "AUTOMATED_INTELLIGENCE.SEMANTIC.BUSINESS_ANALYTICS_SEMANTIC"
    },
    "search_reviews": {
      "execution_environment": {
        "query_timeout": 299,
        "type": "warehouse",
        "warehouse": ""
      },
      "search_service": "AUTOMATED_INTELLIGENCE.SEMANTIC.PRODUCT_REVIEWS_SEARCH"
    },
    "search_tickets": {
      "execution_environment": {
        "query_timeout": 299,
        "type": "warehouse",
        "warehouse": ""
      },
      "search_service": "AUTOMATED_INTELLIGENCE.SEMANTIC.SUPPORT_TICKETS_SEARCH"
    }
  }
}
$spec$;

-- ============================================================================
-- Verify Agent
-- ============================================================================

SHOW AGENTS LIKE 'BUSINESS_INSIGHTS_AGENT' IN SCHEMA AUTOMATED_INTELLIGENCE.SEMANTIC;

DESCRIBE AGENT AUTOMATED_INTELLIGENCE.SEMANTIC.BUSINESS_INSIGHTS_AGENT;

-- ============================================================================
-- Grant Access (Optional)
-- ============================================================================
-- Grant usage to other roles that need to interact with the agent

-- GRANT USAGE ON AGENT AUTOMATED_INTELLIGENCE.SEMANTIC.BUSINESS_INSIGHTS_AGENT
--     TO ROLE WEST_COAST_MANAGER;

-- ============================================================================
-- Test the Agent
-- ============================================================================
-- Run these queries in Snowflake Intelligence or via the REST API:
--
-- Text-to-SQL routing:
--   "What is the total revenue by customer segment this month?"
--   "Show me the top 5 products by order count"
--
-- Review search routing:
--   "What are customers saying about ski boots?"
--   "Find reviews mentioning quality issues"
--
-- Support ticket routing:
--   "Show me high priority shipping complaints"
--   "What are the most common support issues?"
--
-- Multi-tool routing:
--   "What is the average rating for our top-selling product?"
--   (Agent uses text-to-SQL to find top product, then search for reviews)
