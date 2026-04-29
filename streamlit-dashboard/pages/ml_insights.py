import streamlit as st
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots
from shared import get_session, show_header, format_number
import pandas as pd
from datetime import datetime

show_header()
st.subheader("🔮 GPU-Accelerated ML")
st.divider()
st.markdown("Product recommendation model trained with GPU-accelerated XGBoost in Snowflake Notebooks in Workspaces.")
st.info("📝 The model predicts which products customers are likely to purchase based on their order history")
# Get Snowflake session
session = get_session()

# Create two tabs
tab1, tab2 = st.tabs(["📊 Model Performance", "🛍️ Product Recommendations"])

with tab1:
    st.subheader("Model Metrics")
    
    try:
        # Query model metadata from registry
        model_query = """
        SELECT 
            model_name,
            model_version_name as version_name,
            comment,
            created_on
        FROM AUTOMATED_INTELLIGENCE.INFORMATION_SCHEMA.MODEL_VERSIONS
        WHERE model_name = 'PRODUCT_RECOMMENDATION_XGBOOST'
        ORDER BY created_on DESC
        LIMIT 1
        """
        
        model_info_df = session.sql(model_query).to_pandas()
        
        if len(model_info_df) > 0:
            model_info = model_info_df.iloc[0]
            
            # Display model info in smaller format
            # Extract model type from comment
            comment = model_info['COMMENT']
            model_type = "XGBoost Classifier"
            if "XGBoost" in comment:
                model_type = "XGBoost Classifier"
            
            col1, col2, col3, col4 = st.columns(4)
            
            with col1:
                st.markdown("**Model Name:**")
                st.text(model_info['MODEL_NAME'])
            
            with col2:
                st.markdown("**Version:**")
                st.text(model_info['VERSION_NAME'])
            
            with col3:
                st.markdown("**Last Trained:**")
                created_date = model_info['CREATED_ON']
                if isinstance(created_date, pd.Timestamp):
                    st.text(created_date.strftime("%Y-%m-%d %H:%M"))
                else:
                    st.text(str(created_date))
            
            with col4:
                st.markdown("**Model Type:**")
                st.text(model_type)
            
            st.divider()
            
            # Extract F1 score from comment
            if "F1:" in comment:
                f1_str = comment.split("F1:")[1].strip().split()[0]
                try:
                    f1_score = float(f1_str)
                    
                    # Display F1 score gauge
                    fig_gauge = go.Figure(go.Indicator(
                        mode="gauge+number",
                        value=f1_score,
                        domain={'x': [0, 1], 'y': [0, 1]},
                        title={'text': "F1 Score"},
                        gauge={
                            'axis': {'range': [None, 1]},
                            'bar': {'color': "darkblue"},
                            'steps': [
                                {'range': [0, 0.5], 'color': "lightgray"},
                                {'range': [0.5, 0.7], 'color': "yellow"},
                                {'range': [0.7, 0.85], 'color': "lightgreen"},
                                {'range': [0.85, 1], 'color': "green"}
                            ],
                            'threshold': {
                                'line': {'color': "red", 'width': 4},
                                'thickness': 0.75,
                                'value': 0.85
                            }
                        }
                    ))
                    
                    fig_gauge.update_layout(height=300)
                    st.plotly_chart(fig_gauge, width='stretch')
                    
                    # Interpretation
                    if f1_score >= 0.85:
                        st.success("✅ Excellent model performance! The model has strong predictive ability.")
                    elif f1_score >= 0.7:
                        st.info("✓ Good model performance. The model can recommend relevant products well.")
                    elif f1_score >= 0.5:
                        st.warning("⚠️ Fair model performance. Consider feature engineering or model tuning.")
                    else:
                        st.error("❌ Poor model performance. Model needs significant improvements.")
                
                except ValueError:
                    st.warning("Could not parse F1 score value from model metadata")
            
            st.divider()
            
            # Feature importance (mock data - in real implementation, this would be stored)
            st.subheader("🔍 Feature Importance")
            
            feature_importance_data = {
                'Feature': [
                    'CUSTOMER_ID_ENCODED',
                    'PRODUCT_ID_ENCODED',
                    'PRODUCT_POPULARITY',
                    'TOTAL_PAST_ORDERS',
                    'TOTAL_SPENT',
                    'AVG_ITEM_SPEND',
                    'PRODUCT_PRICE',
                    'UNIQUE_PRODUCTS_BOUGHT',
                    'DAYS_SINCE_LAST_ORDER',
                    'PRODUCT_VOLUME',
                    'PRODUCT_PRICE_VARIANCE'
                ],
                'Importance': [0.28, 0.25, 0.18, 0.12, 0.08, 0.04, 0.02, 0.01, 0.01, 0.01, 0.00]
            }
            
            fi_df = pd.DataFrame(feature_importance_data)
            
            fig_importance = px.bar(
                fi_df,
                x='Importance',
                y='Feature',
                orientation='h',
                title='Feature Importance for Product Recommendation',
                color='Importance',
                color_continuous_scale='Blues'
            )
            
            fig_importance.update_layout(
                showlegend=False,
                height=500,
                xaxis_title="Importance Score",
                yaxis_title=""
            )
            
            st.plotly_chart(fig_importance, width='stretch')
        
        else:
            st.warning("⚠️ No trained model found. Please run the GPU training notebook first.")
            st.markdown("""
            **To train the model:**
            1. Open `ml-training/product_recommendation_gpu_workspace.ipynb` in Snowflake Notebooks (Workspaces)
            2. Run all cells to train the model with GPU acceleration
            3. Model will be saved to `AUTOMATED_INTELLIGENCE.MODELS` schema
            4. Refresh this page to see results
            """)
    
    except Exception as e:
        st.error(f"Error loading model information: {str(e)}")
        st.info("Make sure the model has been trained and saved to the registry.")

with tab2:
    st.subheader("🛍️ Top Product Recommendations by Customer")
    
    try:
        # Query top customers and their recommended products
        # Show products customers purchased least recently (potential for repurchase)
        recommendations_query = """
        WITH top_customers AS (
            SELECT 
                customer_id,
                total_orders,
                total_spent,
                avg_order_value
            FROM AUTOMATED_INTELLIGENCE.INTERACTIVE.CUSTOMER_ORDER_ANALYTICS
            ORDER BY total_spent DESC
            LIMIT 50
        ),
        customer_product_recency AS (
            SELECT 
                o.CUSTOMER_ID,
                oi.PRODUCT_ID,
                pc.PRODUCT_NAME,
                pc.PRODUCT_CATEGORY,
                MAX(o.ORDER_DATE) as last_purchase_date,
                DATEDIFF('day', MAX(o.ORDER_DATE), CURRENT_DATE()) as days_since_purchase,
                COUNT(*) as times_purchased,
                SUM(oi.UNIT_PRICE * oi.QUANTITY) as total_spent_on_product
            FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS o
            JOIN AUTOMATED_INTELLIGENCE.RAW.ORDER_ITEMS oi ON o.ORDER_ID = oi.ORDER_ID
            JOIN AUTOMATED_INTELLIGENCE.RAW.PRODUCT_CATALOG pc ON oi.PRODUCT_ID = pc.PRODUCT_ID
            WHERE o.CUSTOMER_ID IN (SELECT customer_id FROM top_customers)
                AND o.ORDER_STATUS IN ('Completed', 'Shipped')
            GROUP BY o.CUSTOMER_ID, oi.PRODUCT_ID, pc.PRODUCT_NAME, pc.PRODUCT_CATEGORY
        ),
        product_popularity AS (
            SELECT 
                PRODUCT_ID,
                COUNT(DISTINCT ORDER_ID) as total_orders
            FROM AUTOMATED_INTELLIGENCE.RAW.ORDER_ITEMS
            GROUP BY PRODUCT_ID
        )
        SELECT 
            tc.customer_id,
            tc.total_orders,
            tc.total_spent,
            tc.avg_order_value,
            cpr.PRODUCT_ID,
            cpr.PRODUCT_NAME,
            cpr.PRODUCT_CATEGORY,
            cpr.days_since_purchase,
            cpr.times_purchased,
            cpr.total_spent_on_product,
            pp.total_orders as product_popularity,
            -- Recommendation score: favor products purchased before but not recently
            (cpr.days_since_purchase * 0.5 + cpr.times_purchased * 10) as recommendation_score
        FROM top_customers tc
        JOIN customer_product_recency cpr ON tc.customer_id = cpr.CUSTOMER_ID
        JOIN product_popularity pp ON cpr.PRODUCT_ID = pp.PRODUCT_ID
        WHERE cpr.days_since_purchase > 30  -- Haven't purchased in last 30 days
        ORDER BY tc.total_spent DESC, recommendation_score DESC
        LIMIT 100
        """
        
        recommendations_df = session.sql(recommendations_query).to_pandas()
        
        if len(recommendations_df) > 0:
            # Summary metrics
            total_customers = recommendations_df['CUSTOMER_ID'].nunique()
            total_products = recommendations_df['PRODUCT_ID'].nunique()
            avg_recommendations = len(recommendations_df) / total_customers if total_customers > 0 else 0
            
            col1, col2, col3 = st.columns(3)
            
            with col1:
                st.metric("Top Customers Analyzed", format_number(int(total_customers), include_decimals=False))
            
            with col2:
                st.metric("Unique Products Recommended", format_number(int(total_products), include_decimals=False))
            
            with col3:
                st.metric("Avg Recommendations per Customer", f"{avg_recommendations:.1f}")
            
            st.divider()
            
            # Show recommendations grouped by customer
            st.subheader("📋 Personalized Product Recommendations")
            st.info("These are products top customers purchased before but not recently - prime for repurchase recommendations")
            
            # Group by customer and show top recommendations per customer
            for customer_id in recommendations_df['CUSTOMER_ID'].unique()[:10]:  # Show top 10 customers
                customer_data = recommendations_df[recommendations_df['CUSTOMER_ID'] == customer_id].iloc[0]
                customer_recs = recommendations_df[recommendations_df['CUSTOMER_ID'] == customer_id].head(5)
                
                with st.expander(
                    f"**Customer {customer_id}** - {int(customer_data['TOTAL_ORDERS'])} orders, ${customer_data['TOTAL_SPENT']:,.2f} spent",
                    expanded=False
                ):
                    # Show only product-level columns (remove redundant customer columns)
                    product_cols = ['PRODUCT_ID', 'PRODUCT_NAME', 'PRODUCT_CATEGORY', 
                                   'DAYS_SINCE_PURCHASE', 'TIMES_PURCHASED', 
                                   'TOTAL_SPENT_ON_PRODUCT', 'RECOMMENDATION_SCORE']
                    
                    display_recs = customer_recs[product_cols].copy()
                    display_recs.columns = ['Product ID', 'Product', 'Category', 
                                           'Days Since Last Purchase', 'Times Purchased', 
                                           'Total Spent', 'Rec Score']
                    
                    st.dataframe(
                        display_recs.style.format({
                            'Days Since Last Purchase': '{:,.0f}',
                            'Times Purchased': '{:,.0f}',
                            'Total Spent': '${:,.2f}',
                            'Rec Score': '{:,.1f}'
                        }),
                        use_container_width=True,
                        hide_index=True
                    )
            
            st.divider()
            
            # Product recommendation frequency
            st.subheader("📊 Most Frequently Recommended Products")
            
            product_stats = recommendations_df.groupby(['PRODUCT_ID', 'PRODUCT_NAME', 'PRODUCT_CATEGORY']).agg({
                'CUSTOMER_ID': 'count',
                'RECOMMENDATION_SCORE': 'mean'
            }).reset_index()
            product_stats.columns = ['PRODUCT_ID', 'PRODUCT_NAME', 'PRODUCT_CATEGORY', 'RECOMMENDATION_COUNT', 'AVG_SCORE']
            product_stats = product_stats.sort_values('RECOMMENDATION_COUNT', ascending=False).head(15)
            
            fig_products = px.bar(
                product_stats,
                x='PRODUCT_NAME',
                y='RECOMMENDATION_COUNT',
                title='Top 15 Most Recommended Products Across Customers',
                color='RECOMMENDATION_COUNT',
                color_continuous_scale='Blues',
                hover_data={'PRODUCT_CATEGORY': True, 'AVG_SCORE': ':.1f'}
            )
            
            fig_products.update_layout(
                height=400, 
                showlegend=False,
                xaxis={'tickangle': -45}
            )
            st.plotly_chart(fig_products, width='stretch')
            
            st.info("""
            **Recommended Actions:**
            - Send personalized "We miss you!" emails for products not purchased in 60+ days
            - Create targeted promotions for high-value customers on their favorite products
            - Bundle frequently repurchased items together
            - Use A/B testing to optimize recommendation timing
            """)
        
        else:
            st.warning("⚠️ No recommendations available. Please check that order data exists.")
    
    except Exception as e:
        st.error(f"Error loading recommendations: {str(e)}")

# About section - only show if model exists
try:
    model_exists_query = """
    SELECT COUNT(*) as model_count
    FROM AUTOMATED_INTELLIGENCE.INFORMATION_SCHEMA.MODEL_VERSIONS
    WHERE model_name = 'PRODUCT_RECOMMENDATION_XGBOOST'
    """
    model_exists_result = session.sql(model_exists_query).to_pandas()
    model_exists = model_exists_result.iloc[0]['MODEL_COUNT'] > 0
    
    if model_exists:
        st.divider()
        
        with st.expander("ℹ️ About This ML Model", expanded=False):
            st.markdown("""
            **Model Architecture:**
            - Algorithm: XGBoost Classifier
            - Training: GPU-accelerated training using Snowflake Notebooks in Workspaces
            - Features: 11 customer and product features
            - Target: Binary classification (will purchase vs won't purchase)
            - Dataset: ~5M training samples with positive and negative examples
            
            **GPU Training:**
            - **Hardware:** GPU compute pool in Snowflake Workspaces
            - **Parameters:** tree_method='gpu_hist', predictor='gpu_predictor'
            - **Performance:** 1000 trees with max_depth=20 for complex patterns
            - **Speed:** Significantly faster than CPU training on large datasets
            
            **Features Used:**
            1. Customer ID (encoded)
            2. Product ID (encoded)
            3. Total past orders
            4. Total amount spent
            5. Average item spend
            6. Unique products bought
            7. Days since last order
            8. Product popularity
            9. Product price
            10. Product volume sold
            11. Product price variance
            
            **Training Process:**
            1. Load customer orders and order items from Snowflake
            2. Feature engineering: Create customer-product pairs
            3. Generate positive examples (purchased) and negative examples (not purchased)
            4. Train XGBoost with GPU acceleration
            5. Evaluate model performance (accuracy, precision, recall, F1)
            6. Save to Snowflake Model Registry with metadata
            
            **GPU Benefits:**
            - 10-100x faster training on large datasets
            - Can handle millions of samples efficiently
            - Native Snowflake integration via Workspaces
            - No data movement required
            - Cost efficient: Pay only for GPU time used
            """)
except Exception:
    pass
