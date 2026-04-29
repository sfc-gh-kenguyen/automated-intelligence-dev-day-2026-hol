-- ============================================================================
-- New Snowflake Features Demo (2025-2026)
-- ============================================================================
-- This demo covers three GA features:
--   PART 1-3: CHECK Constraints (GA April 2026)
--   PART 4-6: AI_COMPLETE Document Intelligence (GA April 2026)
--   PART 7-9: AI Functions GA (AI_CLASSIFY, AI_EMBED, AI_SIMILARITY - Nov 2025)
--
-- Each section includes practical examples using AUTOMATED_INTELLIGENCE
-- database objects.
-- ============================================================================

USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
USE DATABASE AUTOMATED_INTELLIGENCE;
USE WAREHOUSE AUTOMATED_INTELLIGENCE_WH;

-- ============================================================================
-- ============================================================================
--
--  CHECK CONSTRAINTS (GA April 2026)
--
--  Standard SQL CHECK constraints enforced on INSERT/UPDATE for regular
--  Snowflake tables. Ensures data quality at the database layer.
--
-- ============================================================================
-- ============================================================================

-- ============================================================================
-- PART 1: Inline CHECK Constraints
-- ============================================================================

-- Create a table with inline CHECK constraints on individual columns
CREATE OR REPLACE TABLE AUTOMATED_INTELLIGENCE.RAW.VALIDATED_ORDERS (
    order_id NUMBER NOT NULL,
    customer_id NUMBER NOT NULL,
    order_date DATE NOT NULL,
    total_amount NUMBER(12,2) CHECK (total_amount >= 0),
    discount_percent NUMBER(5,2) CHECK (discount_percent BETWEEN 0 AND 100),
    order_status VARCHAR(20) CHECK (order_status IN ('PENDING','PROCESSING','SHIPPED','DELIVERED','CANCELLED')),
    quantity NUMBER CHECK (quantity > 0)
);

-- Insert valid data
INSERT INTO AUTOMATED_INTELLIGENCE.RAW.VALIDATED_ORDERS
VALUES
    (1, 101, '2026-04-01', 249.99, 10.00, 'PENDING', 3),
    (2, 102, '2026-04-02', 89.50, 0.00, 'SHIPPED', 1),
    (3, 103, '2026-04-03', 1500.00, 15.00, 'PROCESSING', 5);

-- Verify the data
SELECT * FROM AUTOMATED_INTELLIGENCE.RAW.VALIDATED_ORDERS;

-- ============================================================================
-- PART 2: Constraint Violations and Named Constraints
-- ============================================================================

-- Demonstrate a CHECK violation: negative total_amount
-- This INSERT should fail because total_amount < 0
INSERT INTO AUTOMATED_INTELLIGENCE.RAW.VALIDATED_ORDERS
VALUES (4, 104, '2026-04-04', -50.00, 5.00, 'PENDING', 2);

-- Demonstrate a CHECK violation: invalid order_status
-- This INSERT should fail because 'UNKNOWN' is not in the allowed list
INSERT INTO AUTOMATED_INTELLIGENCE.RAW.VALIDATED_ORDERS
VALUES (5, 105, '2026-04-05', 100.00, 5.00, 'UNKNOWN', 1);

-- Demonstrate a CHECK violation: quantity must be > 0
-- This INSERT should fail because quantity is 0
INSERT INTO AUTOMATED_INTELLIGENCE.RAW.VALIDATED_ORDERS
VALUES (6, 106, '2026-04-06', 75.00, 0.00, 'PENDING', 0);

-- Add a named CHECK constraint after table creation
ALTER TABLE AUTOMATED_INTELLIGENCE.RAW.VALIDATED_ORDERS
  ADD CONSTRAINT chk_reasonable_total CHECK (total_amount < 1000000);

-- Verify: this should fail (total exceeds 1M)
INSERT INTO AUTOMATED_INTELLIGENCE.RAW.VALIDATED_ORDERS
VALUES (7, 107, '2026-04-07', 1500000.00, 0.00, 'PENDING', 1);

-- ============================================================================
-- PART 3: Inspecting and Managing CHECK Constraints
-- ============================================================================

-- Show all CHECK constraints on the table
SHOW CHECK CONSTRAINTS IN TABLE AUTOMATED_INTELLIGENCE.RAW.VALIDATED_ORDERS;

-- Drop a named constraint
ALTER TABLE AUTOMATED_INTELLIGENCE.RAW.VALIDATED_ORDERS
  DROP CONSTRAINT chk_reasonable_total;

-- Confirm the constraint was removed
SHOW CHECK CONSTRAINTS IN TABLE AUTOMATED_INTELLIGENCE.RAW.VALIDATED_ORDERS;

-- Now the previously blocked insert succeeds
INSERT INTO AUTOMATED_INTELLIGENCE.RAW.VALIDATED_ORDERS
VALUES (7, 107, '2026-04-07', 1500000.00, 0.00, 'PENDING', 1);

SELECT * FROM AUTOMATED_INTELLIGENCE.RAW.VALIDATED_ORDERS ORDER BY order_id;


-- ============================================================================
-- ============================================================================
--
--  AI_COMPLETE DOCUMENT INTELLIGENCE (GA April 2026)
--
--  Process PDFs and Word documents directly from Snowflake stages using
--  AI_COMPLETE with file references. No need to extract text first --
--  the model reads the document natively.
--
-- ============================================================================
-- ============================================================================

-- ============================================================================
-- PART 4: Single Document Processing
-- ============================================================================

-- Summarize a PDF from an internal stage
SELECT SNOWFLAKE.CORTEX.AI_COMPLETE(
    'claude-3-5-sonnet',
    'Summarize the key findings from this document',
    FILE_REFERENCE => BUILD_STAGE_FILE_URL(
        '@AUTOMATED_INTELLIGENCE.RAW.SEMANTIC_MODELS',
        'sample_report.pdf'
    )
) AS doc_summary;

-- Extract structured data from a document as JSON
SELECT SNOWFLAKE.CORTEX.AI_COMPLETE(
    'claude-3-5-sonnet',
    'Extract all dollar amounts and dates from this invoice. Return as a JSON array with keys: amount, date, description.',
    FILE_REFERENCE => BUILD_STAGE_FILE_URL(
        '@AUTOMATED_INTELLIGENCE.RAW.SEMANTIC_MODELS',
        'invoice.pdf'
    )
) AS extracted_data;

-- ============================================================================
-- PART 5: Document Classification (Batch)
-- ============================================================================

-- Classify all PDFs on a stage by document type
SELECT
    relative_path,
    SNOWFLAKE.CORTEX.AI_COMPLETE(
        'claude-3-5-sonnet',
        'Classify this document as one of: invoice, contract, report, or correspondence. Return only the category name.',
        FILE_REFERENCE => BUILD_STAGE_FILE_URL(
            '@AUTOMATED_INTELLIGENCE.RAW.SEMANTIC_MODELS',
            relative_path
        )
    ) AS doc_type
FROM DIRECTORY(@AUTOMATED_INTELLIGENCE.RAW.SEMANTIC_MODELS)
WHERE relative_path LIKE '%.pdf';

-- ============================================================================
-- PART 6: Multi-Turn Document Q&A
-- ============================================================================

-- Ask a specific question about a document
SELECT SNOWFLAKE.CORTEX.AI_COMPLETE(
    'claude-3-5-sonnet',
    'What are the top 3 risks or concerns mentioned in this document? List them as bullet points.',
    FILE_REFERENCE => BUILD_STAGE_FILE_URL(
        '@AUTOMATED_INTELLIGENCE.RAW.SEMANTIC_MODELS',
        'sample_report.pdf'
    )
) AS risk_analysis;

-- Compare information across the prompt and document
SELECT SNOWFLAKE.CORTEX.AI_COMPLETE(
    'claude-3-5-sonnet',
    'Does this document mention any deadlines or due dates? If so, list each deadline with the associated task or deliverable.',
    FILE_REFERENCE => BUILD_STAGE_FILE_URL(
        '@AUTOMATED_INTELLIGENCE.RAW.SEMANTIC_MODELS',
        'sample_report.pdf'
    )
) AS deadlines;


-- ============================================================================
-- ============================================================================
--
--  AI FUNCTIONS GA (November 2025)
--
--  Core AI functions reached General Availability in November 2025:
--    - AI_CLASSIFY: Classify text into user-defined categories
--    - AI_EMBED: Generate vector embeddings for text
--    - AI_SIMILARITY: Compute semantic similarity between text pairs
--    - AI_TRANSCRIBE: Transcribe audio files to text
--
-- ============================================================================
-- ============================================================================

-- ============================================================================
-- PART 7: AI_CLASSIFY - Text Classification
-- ============================================================================

-- Classify order notes into priority buckets
SELECT
    order_id,
    order_status,
    SNOWFLAKE.CORTEX.AI_CLASSIFY(
        order_status || ': ' || COALESCE(notes, ''),
        ['Urgent', 'Normal', 'Low Priority']
    ) AS priority_classification
FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS
LIMIT 10;

-- Classify customer segments using free-text descriptions
SELECT
    customer_id,
    first_name,
    last_name,
    customer_segment,
    SNOWFLAKE.CORTEX.AI_CLASSIFY(
        customer_segment,
        ['High Value', 'Growth Potential', 'At Risk', 'New Customer']
    ) AS ai_segment
FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS
LIMIT 10;

-- ============================================================================
-- PART 8: AI_EMBED - Vector Embeddings
-- ============================================================================

-- Generate embeddings for product names
SELECT
    product_name,
    SNOWFLAKE.CORTEX.AI_EMBED('e5-base-v2', product_name) AS name_embedding
FROM AUTOMATED_INTELLIGENCE.RAW.PRODUCT_CATALOG
LIMIT 5;

-- Store embeddings in a table for later similarity search
CREATE OR REPLACE TABLE AUTOMATED_INTELLIGENCE.RAW.PRODUCT_EMBEDDINGS AS
SELECT
    product_id,
    product_name,
    SNOWFLAKE.CORTEX.AI_EMBED('e5-base-v2', product_name) AS embedding
FROM AUTOMATED_INTELLIGENCE.RAW.PRODUCT_CATALOG;

-- ============================================================================
-- PART 9: AI_SIMILARITY - Semantic Similarity
-- ============================================================================

-- Find the most similar product pairs
SELECT
    a.product_name AS product_a,
    b.product_name AS product_b,
    SNOWFLAKE.CORTEX.AI_SIMILARITY(a.product_name, b.product_name) AS similarity_score
FROM AUTOMATED_INTELLIGENCE.RAW.PRODUCT_CATALOG a
CROSS JOIN AUTOMATED_INTELLIGENCE.RAW.PRODUCT_CATALOG b
WHERE a.product_id < b.product_id
ORDER BY similarity_score DESC
LIMIT 10;

-- Find products similar to a search term
SELECT
    product_name,
    SNOWFLAKE.CORTEX.AI_SIMILARITY(product_name, 'wireless headphones') AS relevance
FROM AUTOMATED_INTELLIGENCE.RAW.PRODUCT_CATALOG
ORDER BY relevance DESC
LIMIT 5;


-- ============================================================================
-- ============================================================================
--  CLEANUP
-- ============================================================================
-- ============================================================================

-- CHECK Constraints demo objects
DROP TABLE IF EXISTS AUTOMATED_INTELLIGENCE.RAW.VALIDATED_ORDERS;

-- AI_EMBED demo objects
DROP TABLE IF EXISTS AUTOMATED_INTELLIGENCE.RAW.PRODUCT_EMBEDDINGS;

-- ============================================================================
-- Demo Complete
-- ============================================================================
SELECT 'New Features 2025-2026 Demo Complete!' AS status;
