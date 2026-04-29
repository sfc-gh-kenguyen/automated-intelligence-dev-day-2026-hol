-- ============================================================================
-- Cortex Agent Evaluations Demo (GA March 2026)
-- ============================================================================
-- Evaluate BUSINESS_INSIGHTS_AGENT against ground truth and reference-free
-- metrics. Uses SYSTEM$CREATE_EVALUATION_DATASET, EXECUTE_AI_EVALUATION,
-- and GET_AI_EVALUATION_DATA.
--
-- Prerequisites:
--   - BUSINESS_INSIGHTS_AGENT created (see create_agent.sql)
--   - Cortex Search services running (product reviews + support tickets)
--   - Semantic view or semantic model available for text-to-SQL
-- ============================================================================

USE ROLE AUTOMATED_INTELLIGENCE;
USE DATABASE AUTOMATED_INTELLIGENCE;
USE SCHEMA SEMANTIC;
USE WAREHOUSE AUTOMATED_INTELLIGENCE_WH;

-- ============================================================================
-- PART 1: Create Evaluation Source Table
-- ============================================================================
-- The table needs: VARCHAR query column + VARIANT ground truth column.
-- ground_truth_output key is used by the answer_correctness system metric.

CREATE OR REPLACE TABLE AUTOMATED_INTELLIGENCE.SEMANTIC.AGENT_EVAL_TABLE (
    input_query VARCHAR,
    ground_truth VARIANT
);

-- Insert test cases covering all three agent tools:
-- 1. cortex_analyst_text_to_sql (revenue, orders, metrics)
-- 2. search_reviews (product reviews semantic search)
-- 3. search_tickets (support tickets semantic search)

INSERT INTO AUTOMATED_INTELLIGENCE.SEMANTIC.AGENT_EVAL_TABLE
SELECT column1, PARSE_JSON(column2) FROM VALUES
    -- Text-to-SQL queries (should route to cortex_analyst_text_to_sql)
    ('What were total sales last month?',
     '{"ground_truth_output": "The agent should use the cortex_analyst_text_to_sql tool to query revenue or sales data. The response should contain a specific dollar amount for the previous calendar month."}'),

    ('Show me the top 5 products by revenue',
     '{"ground_truth_output": "The agent should use cortex_analyst_text_to_sql to generate SQL that ranks products by revenue. Results should list 5 products with their names and revenue figures, ordered descending."}'),

    ('How many orders were placed this quarter?',
     '{"ground_truth_output": "The agent should use cortex_analyst_text_to_sql to count orders within the current quarter date range. The response should contain a single count number."}'),

    ('What is the average order value by customer segment?',
     '{"ground_truth_output": "The agent should use cortex_analyst_text_to_sql to calculate average order value grouped by customer segment (Premium, Standard, Basic). Results should show segment names and their average values."}'),

    -- Product reviews search (should route to search_reviews)
    ('Find reviews about boot quality issues',
     '{"ground_truth_output": "The agent should use the search_reviews tool to find product reviews mentioning boots, quality problems, or defects. Results should include review text and ratings."}'),

    ('What are customers saying about ski equipment?',
     '{"ground_truth_output": "The agent should use search_reviews to find reviews related to ski equipment, skis, or skiing products. The response should summarize customer sentiment."}'),

    ('Show me negative reviews with ratings below 3',
     '{"ground_truth_output": "The agent should use search_reviews to find low-rated product reviews. Results should show reviews with ratings of 1 or 2 stars and include the review text."}'),

    -- Support tickets search (should route to search_tickets)
    ('Show me open shipping complaint tickets',
     '{"ground_truth_output": "The agent should use the search_tickets tool to find support tickets related to shipping delays, lost packages, or delivery complaints. Results should include ticket subject, category, and priority."}'),

    ('Find billing disputes from premium customers',
     '{"ground_truth_output": "The agent should use search_tickets to find support tickets about billing issues, overcharges, or payment disputes. Results should include ticket details."}'),

    ('What are the most common support issues this month?',
     '{"ground_truth_output": "The agent should use search_tickets to find recent support tickets and identify common categories or themes. The response should group or summarize ticket patterns."}');

-- Verify the data
SELECT input_query, ground_truth:ground_truth_output::VARCHAR AS expected_behavior
FROM AUTOMATED_INTELLIGENCE.SEMANTIC.AGENT_EVAL_TABLE;

-- ============================================================================
-- PART 2: Register as Evaluation Dataset
-- ============================================================================
-- SYSTEM$CREATE_EVALUATION_DATASET converts a table into a Snowflake Dataset
-- object that the evaluation framework can consume.

CALL SYSTEM$CREATE_EVALUATION_DATASET(
    'Cortex Agent',
    'AUTOMATED_INTELLIGENCE.SEMANTIC.AGENT_EVAL_TABLE',
    'AUTOMATED_INTELLIGENCE.SEMANTIC.BUSINESS_AGENT_EVALSET',
    OBJECT_CONSTRUCT(
        'query_text', 'INPUT_QUERY',
        'ground_truth', 'GROUND_TRUTH'
    )
);

-- Confirm dataset was created
SHOW DATASETS IN SCHEMA AUTOMATED_INTELLIGENCE.SEMANTIC;

-- ============================================================================
-- PART 3: Run Evaluation with System Metrics
-- ============================================================================
-- Two system metrics available:
--   answer_correctness: compares response to ground_truth_output (needs ground truth)
--   logical_consistency: reference-free, checks planning/tool-call coherence

SELECT EXECUTE_AI_EVALUATION('START', {
    'evaluation_name': 'business_agent_eval_v1',
    'agent': 'AUTOMATED_INTELLIGENCE.SEMANTIC.BUSINESS_INSIGHTS_AGENT',
    'dataset': 'AUTOMATED_INTELLIGENCE.SEMANTIC.BUSINESS_AGENT_EVALSET',
    'metrics': ['answer_correctness', 'logical_consistency']
});

-- ============================================================================
-- PART 4: Monitor Evaluation Progress
-- ============================================================================

-- Check status (returns RUNNING, COMPLETED, or FAILED)
SELECT EXECUTE_AI_EVALUATION('STATUS', {
    'evaluation_name': 'business_agent_eval_v1'
});

-- ============================================================================
-- PART 5: Retrieve and Analyze Results
-- ============================================================================

-- Get full evaluation data including per-query scores
SELECT * FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_EVALUATION_DATA(
    'business_agent_eval_v1'
));

-- Analyze average scores by metric
/*
SELECT
    metric_name,
    AVG(score) AS avg_score,
    MIN(score) AS min_score,
    MAX(score) AS max_score,
    COUNT(*) AS num_queries
FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_EVALUATION_DATA(
    'business_agent_eval_v1'
))
GROUP BY metric_name;
*/

-- ============================================================================
-- PART 6: Custom Evaluation Metrics (YAML Config)
-- ============================================================================
-- Custom metrics use an LLM judge prompt. Upload a YAML config to a stage
-- and reference it when starting the evaluation.
--
-- Example YAML config (save as eval_config.yaml):
--
-- evaluation:
--   agent: AUTOMATED_INTELLIGENCE.SEMANTIC.BUSINESS_INSIGHTS_AGENT
--   dataset:
--     source_table: AUTOMATED_INTELLIGENCE.SEMANTIC.AGENT_EVAL_TABLE
--     column_mapping:
--       query_text: INPUT_QUERY
--       ground_truth: GROUND_TRUTH
--   metrics:
--     system:
--       - answer_correctness
--       - logical_consistency
--     custom:
--       - name: tool_selection_accuracy
--         prompt: |
--           Evaluate whether the agent selected the correct tool for the query.
--           The agent has these tools: cortex_analyst_text_to_sql (for data/SQL queries),
--           search_reviews (for product review lookups), search_tickets (for support ticket lookups).
--           
--           Query: {{input_query}}
--           Expected behavior: {{ground_truth}}
--           Agent response and tool calls: {{agent_response}}
--           
--           Score 1 if the correct tool was used, 0 otherwise.
--         scoring:
--           min: 0
--           max: 1

-- To use a YAML config:
-- PUT file://eval_config.yaml @AUTOMATED_INTELLIGENCE.RAW.SEMANTIC_MODELS/eval/;
--
-- SELECT EXECUTE_AI_EVALUATION('START', {
--     'evaluation_name': 'business_agent_eval_custom',
--     'config': '@AUTOMATED_INTELLIGENCE.RAW.SEMANTIC_MODELS/eval/eval_config.yaml'
-- });

-- ============================================================================
-- PART 7: Iterating on Agent Quality
-- ============================================================================
-- Typical evaluation workflow:
--
-- 1. Run baseline evaluation against current agent spec
-- 2. Modify agent (add/remove tools, update instructions, change model)
-- 3. Re-run evaluation with same dataset
-- 4. Compare scores between runs
-- 5. If scores improve, promote changes; if they regress, revert
--
-- For CI/CD integration:
--   snow sql -f snowflake-intelligence/cortex_agent_evaluations_demo.sql -c dash-builder-si

-- ============================================================================
-- Cleanup (optional)
-- ============================================================================
-- DROP TABLE IF EXISTS AUTOMATED_INTELLIGENCE.SEMANTIC.AGENT_EVAL_TABLE;
-- To drop the dataset, use Snowsight or the datasets API.

SELECT 'Cortex Agent Evaluations Demo Complete' AS status;
