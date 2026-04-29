-- ============================================================================
-- Cortex Agent - Multi-Tool Routing Demo
-- ============================================================================
-- Demonstrates how the CREATE AGENT API natively routes questions to the
-- right tool based on the user's intent. No separate "router" object needed.
--
-- The agent has 3 tools:
--   1. cortex_analyst_text_to_sql → structured data queries (revenue, orders)
--   2. cortex_search → product reviews (unstructured text search)
--   3. cortex_search → support tickets (unstructured text search)
--
-- The orchestration model analyzes each question and decides which tool(s)
-- to invoke. This replaces the old "routing mode" concept entirely.
-- ============================================================================

USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
USE DATABASE AUTOMATED_INTELLIGENCE;
USE WAREHOUSE AUTOMATED_INTELLIGENCE_WH;

-- ============================================================================
-- PART 1: View the Agent's Tool Configuration
-- ============================================================================

-- The agent was created in create_agent.sql with 3 tools.
-- Each tool has a type, name, and description that the orchestration model
-- uses for routing decisions.

DESCRIBE AGENT AUTOMATED_INTELLIGENCE.SEMANTIC.BUSINESS_INSIGHTS_AGENT;

-- ============================================================================
-- PART 2: How Routing Works
-- ============================================================================

/*
ROUTING IN THE NEW AGENT API:

The orchestration model reads each tool's description and matches it against
the user's question. No configuration needed — it's built into the agent.

Question: "What is total revenue by segment?"
  → Routes to: query_business_data (cortex_analyst_text_to_sql)
  → Reason: "revenue" and "segment" match structured data tool

Question: "What do customers think about ski boots?"
  → Routes to: search_reviews (cortex_search)
  → Reason: "customers think" signals sentiment/review search

Question: "Show me open shipping complaints"
  → Routes to: search_tickets (cortex_search)
  → Reason: "complaints" signals support ticket search

Question: "What's the revenue for our highest-rated product?"
  → Routes to: search_reviews THEN query_business_data
  → Reason: Multi-step — find highest-rated product, then query revenue

KEY INSIGHT: Tool descriptions drive routing quality. Write descriptions
that clearly scope what each tool handles, with specific keywords the
orchestration model can match on.
*/

-- ============================================================================
-- PART 3: Demo Queries — Text-to-SQL Routing
-- ============================================================================

-- These questions should route to the query_business_data tool,
-- which generates SQL against the business_analytics_semantic view.

-- Simple aggregation
-- "What is total revenue by customer segment?"

-- Time-series analysis
-- "Show monthly order counts for 2025"

-- Comparative analysis
-- "Compare average order value between Premium and Standard customers"

-- ============================================================================
-- PART 4: Demo Queries — Search Routing
-- ============================================================================

-- These questions should route to search_reviews or search_tickets.

-- Product review search
-- "Find reviews mentioning binding problems on snowboards"

-- Support ticket search
-- "What are the most common reasons for returns?"

-- Ticket status search
-- "Show me unresolved high-priority tickets from this week"

-- ============================================================================
-- PART 5: Demo Queries — Multi-Tool Routing
-- ============================================================================

-- These questions require the agent to use multiple tools and combine results.

-- Combine search + analytics
-- "What is the average order value for products with negative reviews?"

-- Cross-reference tickets and data
-- "Which product categories generate the most support tickets?"

-- ============================================================================
-- PART 6: Python SDK Usage
-- ============================================================================

/*
The Cortex Agent Python SDK handles routing transparently:

```python
from snowflake.core import Root

root = Root(session)
agent = root.databases["AUTOMATED_INTELLIGENCE"].schemas["SEMANTIC"].agents["BUSINESS_INSIGHTS_AGENT"]

# The agent routes automatically — no routing_mode flag needed
response = agent.run(
    messages=[{"role": "user", "content": "What is total revenue this month?"}]
)

# Response includes which tool was used
for event in response:
    if event.type == "tool_use":
        print(f"Routed to: {event.tool_name}")
    elif event.type == "text":
        print(event.text)
```

For streaming responses:

```python
for event in agent.run_stream(
    messages=[{"role": "user", "content": "Find reviews about ski helmet comfort"}]
):
    if event.type == "text":
        print(event.text, end="", flush=True)
```
*/

-- ============================================================================
-- PART 7: Best Practices for Multi-Tool Agents
-- ============================================================================

/*
1. TOOL DESCRIPTIONS:
   - Be specific about what each tool handles
   - Include keywords users are likely to use
   - Avoid overlap between tool descriptions

2. ORCHESTRATION INSTRUCTIONS:
   - Guide the model on when to use each tool
   - Specify fallback behavior for ambiguous questions
   - Define multi-tool workflows for complex queries

3. TOOL COUNT:
   - Keep it focused: 2-5 tools per agent works best
   - Split into multiple agents if you need 10+ tools
   - Each tool should cover a distinct domain

4. TESTING:
   - Test with questions that clearly map to each tool
   - Test ambiguous questions to verify routing decisions
   - Test multi-tool questions to verify synthesis
*/

-- ============================================================================
-- Demo Complete
-- ============================================================================
SELECT '✅ Cortex Agent Routing Demo Complete!' AS status;
