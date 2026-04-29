-- ============================================================================
-- Product Recommendation Stored Procedure - Returns Formatted String
-- ============================================================================
-- This stored procedure generates personalized product recommendations
-- for customers in a specified segment using a trained XGBoost model 
-- deployed to Snowpark Container Services.
--
-- Returns: Nicely formatted string response (ideal for Cortex Agents)
-- ============================================================================

CREATE OR REPLACE PROCEDURE AUTOMATED_INTELLIGENCE.MODELS.GET_PRODUCT_RECOMMENDATIONS(
    N_CUSTOMERS NUMBER DEFAULT 3,
    N_PRODUCTS NUMBER DEFAULT 3,
    SEGMENT VARCHAR DEFAULT 'LOW_ENGAGEMENT'
)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python', 'pandas')
HANDLER = 'main'
AS
$$
import pandas as pd
import snowflake.snowpark as snowpark
import snowflake.snowpark.functions as F
from snowflake.snowpark.window import Window
from snowflake.snowpark.types import *

def get_product_recommendations(
    session: snowpark.Session, 
    n_customers: int = 3,
    n_products: int = 3,
    segment: str = 'LOW_ENGAGEMENT'
):
    try:
        query = f"""
        WITH customer_stats AS (
            SELECT 
                o.CUSTOMER_ID,
                COUNT(DISTINCT o.ORDER_ID) as TOTAL_ORDERS,
                SUM(oi.LINE_TOTAL) as TOTAL_SPENT,
                MAX(o.ORDER_DATE) as LAST_ORDER_DATE,
                DATEDIFF(day, MAX(o.ORDER_DATE), CURRENT_DATE()) as DAYS_SINCE_LAST_ORDER
            FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS o
            LEFT JOIN AUTOMATED_INTELLIGENCE.RAW.ORDER_ITEMS oi ON o.ORDER_ID = oi.ORDER_ID
            GROUP BY o.CUSTOMER_ID
        ),
        customer_segments AS (
            SELECT 
                CUSTOMER_ID,
                CASE 
                    WHEN DAYS_SINCE_LAST_ORDER > 180 AND TOTAL_SPENT > 500 THEN 'HIGH_VALUE_INACTIVE'
                    WHEN DAYS_SINCE_LAST_ORDER > 180 THEN 'AT_RISK'
                    WHEN TOTAL_ORDERS <= 2 THEN 'NEW_CUSTOMERS'
                    WHEN TOTAL_ORDERS <= 5 THEN 'LOW_ENGAGEMENT'
                    WHEN TOTAL_SPENT > 1000 THEN 'HIGH_VALUE_ACTIVE'
                    ELSE 'REGULAR'
                END as CUSTOMER_SEGMENT,
                DAYS_SINCE_LAST_ORDER
            FROM customer_stats
        ),
        target_customers AS (
            SELECT CUSTOMER_ID, CUSTOMER_SEGMENT
            FROM customer_segments
            WHERE CUSTOMER_SEGMENT = '{segment}'
            ORDER BY DAYS_SINCE_LAST_ORDER DESC, CUSTOMER_ID ASC
            LIMIT {n_customers}
        ),
        customer_features AS (
            SELECT 
                tc.CUSTOMER_ID,
                tc.CUSTOMER_SEGMENT,
                COUNT(DISTINCT o.ORDER_ID) as TOTAL_PAST_ORDERS,
                COALESCE(SUM(oi.LINE_TOTAL), 0) as TOTAL_SPENT,
                COALESCE(AVG(oi.LINE_TOTAL), 0) as AVG_ITEM_SPEND,
                COUNT(DISTINCT oi.PRODUCT_ID) as UNIQUE_PRODUCTS_BOUGHT,
                COALESCE(DATEDIFF(day, MAX(o.ORDER_DATE), CURRENT_DATE()), 9999) as DAYS_SINCE_LAST_ORDER
            FROM target_customers tc
            LEFT JOIN AUTOMATED_INTELLIGENCE.RAW.ORDERS o ON tc.CUSTOMER_ID = o.CUSTOMER_ID
            LEFT JOIN AUTOMATED_INTELLIGENCE.RAW.ORDER_ITEMS oi ON o.ORDER_ID = oi.ORDER_ID
            GROUP BY tc.CUSTOMER_ID, tc.CUSTOMER_SEGMENT
        ),
        product_features AS (
            SELECT 
                pc.PRODUCT_ID,
                pc.PRODUCT_NAME,
                pc.PRODUCT_CATEGORY,
                COALESCE(COUNT(DISTINCT oi.ORDER_ID), 0) as PRODUCT_POPULARITY,
                pc.PRICE as PRODUCT_PRICE,
                COALESCE(SUM(oi.QUANTITY), 0) as PRODUCT_VOLUME,
                COALESCE(STDDEV(oi.UNIT_PRICE), 0) as PRODUCT_PRICE_VARIANCE
            FROM AUTOMATED_INTELLIGENCE.RAW.PRODUCT_CATALOG pc
            LEFT JOIN AUTOMATED_INTELLIGENCE.RAW.ORDER_ITEMS oi ON pc.PRODUCT_ID = oi.PRODUCT_ID
            GROUP BY pc.PRODUCT_ID, pc.PRODUCT_NAME, pc.PRODUCT_CATEGORY, pc.PRICE
        ),
        already_purchased AS (
            SELECT 
                tc.CUSTOMER_ID,
                oi.PRODUCT_ID
            FROM target_customers tc
            JOIN AUTOMATED_INTELLIGENCE.RAW.ORDERS o ON tc.CUSTOMER_ID = o.CUSTOMER_ID
            JOIN AUTOMATED_INTELLIGENCE.RAW.ORDER_ITEMS oi ON o.ORDER_ID = oi.ORDER_ID
        ),
        feature_matrix AS (
            SELECT 
                cf.CUSTOMER_ID,
                cf.CUSTOMER_SEGMENT,
                pf.PRODUCT_ID,
                pf.PRODUCT_NAME,
                pf.PRODUCT_CATEGORY,
                (cf.CUSTOMER_ID % 10000) as CUSTOMER_ID_ENCODED,
                (pf.PRODUCT_ID % 10000) as PRODUCT_ID_ENCODED,
                cf.TOTAL_PAST_ORDERS,
                cf.TOTAL_SPENT,
                cf.AVG_ITEM_SPEND,
                cf.UNIQUE_PRODUCTS_BOUGHT,
                cf.DAYS_SINCE_LAST_ORDER,
                pf.PRODUCT_POPULARITY,
                pf.PRODUCT_PRICE,
                pf.PRODUCT_VOLUME,
                pf.PRODUCT_PRICE_VARIANCE
            FROM customer_features cf
            CROSS JOIN product_features pf
            LEFT JOIN already_purchased ap 
                ON cf.CUSTOMER_ID = ap.CUSTOMER_ID 
                AND pf.PRODUCT_ID = ap.PRODUCT_ID
            WHERE ap.PRODUCT_ID IS NULL
        )
        SELECT 
            CUSTOMER_ID,
            CUSTOMER_SEGMENT,
            PRODUCT_ID,
            PRODUCT_NAME,
            PRODUCT_CATEGORY,
            CUSTOMER_ID_ENCODED,
            PRODUCT_ID_ENCODED,
            TOTAL_PAST_ORDERS,
            TOTAL_SPENT,
            AVG_ITEM_SPEND,
            UNIQUE_PRODUCTS_BOUGHT,
            DAYS_SINCE_LAST_ORDER,
            PRODUCT_POPULARITY,
            PRODUCT_PRICE,
            PRODUCT_VOLUME,
            PRODUCT_PRICE_VARIANCE
        FROM feature_matrix
        """
        
        feature_matrix = session.sql(query)
        
        # Check if we have any results
        if feature_matrix.count() == 0:
            return f"No customers found in the '{segment}' segment."
        
        predictions_df = feature_matrix.with_column(
            "prediction_json",
            F.call_function(
                "AUTOMATED_INTELLIGENCE.MODELS.GPU_XGBOOST_SERVICE!PREDICT_PROBA",
                F.col("CUSTOMER_ID_ENCODED"),
                F.col("PRODUCT_ID_ENCODED"),
                F.col("TOTAL_PAST_ORDERS"),
                F.col("TOTAL_SPENT"),
                F.col("AVG_ITEM_SPEND"),
                F.col("UNIQUE_PRODUCTS_BOUGHT"),
                F.col("DAYS_SINCE_LAST_ORDER"),
                F.col("PRODUCT_POPULARITY"),
                F.col("PRODUCT_PRICE"),
                F.col("PRODUCT_VOLUME"),
                F.col("PRODUCT_PRICE_VARIANCE")
            )
        )
        
        predictions_with_proba = predictions_df.with_column(
            "PURCHASE_PROBABILITY",
            F.to_decimal(
                F.get(F.col("prediction_json"), F.lit("output_feature_1")),
                38, 
                10
            ).cast(DoubleType())
        )
        
        window_spec = Window.partition_by("CUSTOMER_ID").order_by(
            F.col("PURCHASE_PROBABILITY").desc()
        )
        
        ranked_predictions = predictions_with_proba.with_column(
            "RANK_WITHIN_CUSTOMER",
            F.row_number().over(window_spec)
        ).filter(
            F.col("RANK_WITHIN_CUSTOMER") <= n_products
        )
        
        result_df = ranked_predictions.select(
            F.col("CUSTOMER_ID"),
            F.col("CUSTOMER_SEGMENT"),
            F.col("PRODUCT_ID"),
            F.col("PRODUCT_NAME"),
            F.col("PRODUCT_CATEGORY"),
            F.col("PURCHASE_PROBABILITY"),
            F.col("RANK_WITHIN_CUSTOMER")
        ).sort(
            F.col("CUSTOMER_ID"),
            F.col("RANK_WITHIN_CUSTOMER")
        )
        
        # Convert to pandas for easier formatting
        results_pd = result_df.to_pandas()
        
        # Format as nice string
        segment_info = {
            'LOW_ENGAGEMENT': 'Low Engagement (3-5 orders)',
            'HIGH_VALUE_INACTIVE': 'High-Value Inactive (>$500, inactive 180+ days)',
            'NEW_CUSTOMERS': 'New Customers (1-2 orders)',
            'AT_RISK': 'At Risk (inactive 180+ days)',
            'HIGH_VALUE_ACTIVE': 'High-Value Active (>$1000)',
            'REGULAR': 'Regular Customers'
        }
        
        output = []
        output.append(f"Product Recommendations for {segment_info.get(segment, segment)} Segment")
        output.append(f"{'=' * 70}")
        output.append("")
        
        # Group by customer
        for customer_id, group in results_pd.groupby('CUSTOMER_ID'):
            output.append(f"Customer ID: {int(customer_id)}")
            output.append("-" * 70)
            
            for idx, row in group.iterrows():
                rank = int(row['RANK_WITHIN_CUSTOMER'])
                product_name = row['PRODUCT_NAME']
                category = row['PRODUCT_CATEGORY']
                probability = row['PURCHASE_PROBABILITY'] * 100
                
                output.append(f"  {rank}. {product_name} ({category})")
                output.append(f"     Purchase Probability: {probability:.1f}%")
            
            output.append("")
        
        output.append(f"Total Customers: {len(results_pd['CUSTOMER_ID'].unique())}")
        output.append(f"Total Recommendations: {len(results_pd)}")
        
        return "\n".join(output)
        
    except Exception as e:
        return f"ERROR: {str(e)}"

def main(
    session: snowpark.Session, 
    n_customers: int = 3,
    n_products: int = 3,
    segment: str = 'LOW_ENGAGEMENT'
):
    return get_product_recommendations(session, n_customers, n_products, segment)
$$;

-- ============================================================================
-- Test Examples
-- ============================================================================
-- CALL AUTOMATED_INTELLIGENCE.MODELS.GET_PRODUCT_RECOMMENDATIONS(3, 3, 'LOW_ENGAGEMENT');
-- CALL AUTOMATED_INTELLIGENCE.MODELS.GET_PRODUCT_RECOMMENDATIONS(5, 5, 'HIGH_VALUE_INACTIVE');
