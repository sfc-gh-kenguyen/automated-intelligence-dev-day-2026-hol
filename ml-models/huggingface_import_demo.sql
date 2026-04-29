-- ============================================================================
-- Hugging Face Model Import Demo
-- ============================================================================
-- Import models from Hugging Face Hub directly into Snowflake's
-- Model Registry for inference and fine-tuning.
--
-- Available since 2025.
-- ============================================================================

USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
USE DATABASE AUTOMATED_INTELLIGENCE;
USE SCHEMA MODELS;
USE WAREHOUSE AUTOMATED_INTELLIGENCE_WH;

-- ============================================================================
-- PART 1: Create Model Registry Schema
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS AUTOMATED_INTELLIGENCE.MODELS;

-- ============================================================================
-- PART 2: Import Hugging Face Model (Python Procedure)
-- ============================================================================

-- Create a procedure to import HuggingFace models
CREATE OR REPLACE PROCEDURE AUTOMATED_INTELLIGENCE.MODELS.import_huggingface_model(
    model_name VARCHAR,
    hf_model_id VARCHAR,
    hf_token VARCHAR DEFAULT NULL
)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-ml-python', 'transformers', 'torch')
HANDLER = 'import_model'
AS
$$
def import_model(session, model_name: str, hf_model_id: str, hf_token: str = None):
    from snowflake.ml.registry import Registry
    from transformers import AutoModelForSequenceClassification, AutoTokenizer
    import os
    
    # Set HuggingFace token if provided
    if hf_token:
        os.environ['HF_TOKEN'] = hf_token
    
    try:
        # Download model and tokenizer from HuggingFace
        tokenizer = AutoTokenizer.from_pretrained(hf_model_id)
        model = AutoModelForSequenceClassification.from_pretrained(hf_model_id)
        
        # Create registry connection
        registry = Registry(session=session)
        
        # Log model to Snowflake registry
        mv = registry.log_model(
            model=model,
            model_name=model_name,
            version_name='v1',
            sample_input_data=None,
            comment=f'Imported from HuggingFace: {hf_model_id}'
        )
        
        return f'Model {model_name} imported successfully from {hf_model_id}'
    except Exception as e:
        return f'Error importing model: {str(e)}'
$$;

-- Example usage (uncomment to run):
-- CALL AUTOMATED_INTELLIGENCE.MODELS.import_huggingface_model(
--     'sentiment_classifier',
--     'distilbert-base-uncased-finetuned-sst-2-english'
-- );

-- ============================================================================
-- PART 3: Alternative - Direct Model Registry Import
-- ============================================================================

/*
-- Using Snowflake ML Python API directly

from snowflake.ml.registry import Registry
from snowflake.snowpark import Session

# Create session
session = Session.builder.configs(connection_params).create()

# Create registry
registry = Registry(session=session, database_name='AUTOMATED_INTELLIGENCE', schema_name='MODELS')

# Import model from HuggingFace
# Method 1: Using transformers
from transformers import pipeline
sentiment_pipeline = pipeline('sentiment-analysis', model='distilbert-base-uncased-finetuned-sst-2-english')

# Log to registry
mv = registry.log_model(
    model=sentiment_pipeline,
    model_name='sentiment_classifier',
    version_name='v1',
    conda_dependencies=['transformers', 'torch']
)
*/

-- ============================================================================
-- PART 4: View Registered Models
-- ============================================================================

-- Show models in registry
SHOW MODELS IN SCHEMA AUTOMATED_INTELLIGENCE.MODELS;

-- Show model versions
SHOW VERSIONS IN MODEL AUTOMATED_INTELLIGENCE.MODELS.sentiment_classifier;

-- Get model details
DESCRIBE MODEL AUTOMATED_INTELLIGENCE.MODELS.sentiment_classifier;

-- ============================================================================
-- PART 5: Use Imported Model for Inference
-- ============================================================================

/*
-- Create a UDF from the registered model

CREATE OR REPLACE FUNCTION AUTOMATED_INTELLIGENCE.MODELS.predict_sentiment(text VARCHAR)
RETURNS VARIANT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-ml-python')
HANDLER = 'predict'
AS
$$
def predict(text: str):
    from snowflake.ml.registry import Registry
    from snowflake.snowpark import Session
    
    # Get model from registry
    registry = Registry(session=Session.builder.getOrCreate())
    model = registry.get_model('sentiment_classifier').version('v1')
    
    # Run inference
    result = model.run({'text': text})
    return result
$$;

-- Use the function
SELECT 
    review_text,
    AUTOMATED_INTELLIGENCE.MODELS.predict_sentiment(review_text) AS sentiment
FROM AUTOMATED_INTELLIGENCE.RAW.PRODUCT_REVIEWS
LIMIT 10;
*/

-- ============================================================================
-- PART 6: Popular HuggingFace Models for Business Use Cases
-- ============================================================================

/*
RECOMMENDED MODELS:

1. SENTIMENT ANALYSIS:
   - distilbert-base-uncased-finetuned-sst-2-english
   - nlptown/bert-base-multilingual-uncased-sentiment
   
2. TEXT CLASSIFICATION:
   - facebook/bart-large-mnli (zero-shot)
   - typeform/distilbert-base-uncased-mnli

3. NAMED ENTITY RECOGNITION:
   - dslim/bert-base-NER
   - Jean-Baptiste/camembert-ner (French)

4. QUESTION ANSWERING:
   - deepset/roberta-base-squad2
   - distilbert-base-cased-distilled-squad

5. TEXT SUMMARIZATION:
   - facebook/bart-large-cnn
   - t5-small

6. EMBEDDINGS:
   - sentence-transformers/all-MiniLM-L6-v2
   - sentence-transformers/all-mpnet-base-v2
*/

-- ============================================================================
-- PART 7: Model Governance
-- ============================================================================

-- Add tags for governance
ALTER MODEL AUTOMATED_INTELLIGENCE.MODELS.sentiment_classifier
SET TAG governance.classification = 'ML_MODEL',
    governance.data_source = 'HUGGINGFACE';

-- Grant access
GRANT USAGE ON MODEL AUTOMATED_INTELLIGENCE.MODELS.sentiment_classifier
TO ROLE DATA_SCIENTIST;

-- ============================================================================
-- Demo Complete
-- ============================================================================
SELECT '✅ Hugging Face Model Import Demo Complete!' AS status;
