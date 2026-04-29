import streamlit as st
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots
from shared import get_session, show_header, format_number
import pandas as pd

show_header()
st.subheader("📊 Customers & Product Analytics")
st.divider()
st.markdown("Insights from dbt pipeline: Customer lifetime value, Segmentation, and Product Recommendations")

# Get Snowflake session
session = get_session()

# Create two tabs
tab1, tab2 = st.tabs(["👥 Customer", "🛒 Product"])

with tab1:
    st.subheader("Customer Lifetime Value & Segmentation")
    
    try:
        # Check if DBT_ANALYTICS schema exists
        schema_check = session.sql("""
            SELECT COUNT(*) as schema_exists 
            FROM AUTOMATED_INTELLIGENCE.INFORMATION_SCHEMA.SCHEMATA 
            WHERE SCHEMA_NAME = 'DBT_ANALYTICS'
        """).to_pandas()
        
        if schema_check.iloc[0]['SCHEMA_EXISTS'] == 0:
            st.info("📋 **dbt models not yet deployed**\n\nRun the following command to deploy dbt models:\n```\ndbt run --target dev\n```")
        else:
            # Query customer analytics from dbt marts
            clv_query = """
            SELECT 
                value_tier,
                customer_status,
                COUNT(*) as customer_count,
                AVG(total_revenue) as avg_revenue,
                AVG(total_orders) as avg_orders,
                AVG(rfm_score) as avg_rfm_score,
                SUM(total_revenue) as total_revenue_sum
            FROM AUTOMATED_INTELLIGENCE.DBT_ANALYTICS.CUSTOMER_LIFETIME_VALUE
            GROUP BY value_tier, customer_status
            ORDER BY customer_count DESC
            """
            
            clv_df = session.sql(clv_query).to_pandas()
            
            if len(clv_df) > 0:
                # Display key metrics
                col1, col2, col3, col4 = st.columns(4)
                
                total_customers = clv_df['CUSTOMER_COUNT'].sum()
                total_revenue = clv_df['TOTAL_REVENUE_SUM'].sum()
                avg_clv = total_revenue / total_customers if total_customers > 0 else 0
                
                with col1:
                    st.metric("Total Customers", format_number(total_customers, include_decimals=False))
                
                with col2:
                    st.metric("Total Revenue", f"${format_number(total_revenue)}")
                
                with col3:
                    st.metric("Avg CLV", f"${format_number(avg_clv)}")
                
                with col4:
                    active_customers = clv_df[clv_df['CUSTOMER_STATUS'] == 'active']['CUSTOMER_COUNT'].sum()
                    st.metric("Active Customers", format_number(active_customers, include_decimals=False))
                
                st.divider()
                
                # Visualization row 1: Value Tiers
                col1, col2 = st.columns(2)
                
                with col1:
                    st.markdown("**Customer Distribution by Value Tier**")
                    tier_summary = clv_df.groupby('VALUE_TIER')['CUSTOMER_COUNT'].sum().reset_index()
                    tier_summary = tier_summary.sort_values('CUSTOMER_COUNT', ascending=False)
                    
                    fig_tier = px.pie(
                        tier_summary,
                        values='CUSTOMER_COUNT',
                        names='VALUE_TIER',
                        color='VALUE_TIER',
                        color_discrete_map={
                            'high_value': '#1f77b4',
                            'medium_value': '#ff7f0e',
                            'low_value': '#2ca02c',
                            'no_purchases': '#d62728'
                        }
                    )
                    fig_tier.update_traces(textposition='inside', textinfo='percent+label')
                    st.plotly_chart(fig_tier, use_container_width=True)
                
                with col2:
                    st.markdown("**Customer Status Distribution**")
                    status_summary = clv_df.groupby('CUSTOMER_STATUS')['CUSTOMER_COUNT'].sum().reset_index()
                    status_summary = status_summary.sort_values('CUSTOMER_COUNT', ascending=False)
                    
                    fig_status = px.bar(
                        status_summary,
                        x='CUSTOMER_STATUS',
                        y='CUSTOMER_COUNT',
                        color='CUSTOMER_STATUS',
                        color_discrete_map={
                            'active': '#2ca02c',
                            'at_risk': '#ff7f0e',
                            'churned': '#d62728',
                            'never_purchased': '#7f7f7f'
                        }
                    )
                    fig_status.update_layout(showlegend=False, xaxis_title="Status", yaxis_title="Customers")
                    st.plotly_chart(fig_status, use_container_width=True)
                
                st.divider()
                
                # Visualization row 2: Revenue Analysis
                col1, col2 = st.columns(2)
                
                with col1:
                    st.markdown("**Revenue by Value Tier & Status**")
                    fig_revenue = px.sunburst(
                        clv_df,
                        path=['VALUE_TIER', 'CUSTOMER_STATUS'],
                        values='TOTAL_REVENUE_SUM',
                        color='TOTAL_REVENUE_SUM',
                        color_continuous_scale='Blues'
                    )
                    st.plotly_chart(fig_revenue, use_container_width=True)
                
                with col2:
                    st.markdown("**Average RFM Score by Segment**")
                    fig_rfm = px.scatter(
                        clv_df,
                        x='AVG_ORDERS',
                        y='AVG_REVENUE',
                        size='CUSTOMER_COUNT',
                        color='AVG_RFM_SCORE',
                        hover_data=['VALUE_TIER', 'CUSTOMER_STATUS'],
                        color_continuous_scale='Viridis',
                        labels={
                            'AVG_ORDERS': 'Avg Orders per Customer',
                            'AVG_REVENUE': 'Avg Revenue per Customer',
                            'AVG_RFM_SCORE': 'RFM Score'
                        }
                    )
                    st.plotly_chart(fig_rfm, use_container_width=True)
                
                st.divider()
                
                # Top customers table
                st.markdown("**Top 20 Customers by Lifetime Value**")
                top_customers_query = """
                SELECT 
                    customer_id,
                    customer_name,
                    total_revenue,
                    total_orders,
                    rfm_score,
                    value_tier,
                    customer_status,
                    days_since_last_order
                FROM AUTOMATED_INTELLIGENCE.DBT_ANALYTICS.CUSTOMER_LIFETIME_VALUE
                ORDER BY total_revenue DESC
                LIMIT 20
                """
                
                top_customers_df = session.sql(top_customers_query).to_pandas()
                st.dataframe(
                    top_customers_df,
                    use_container_width=True,
                    column_config={
                        "TOTAL_REVENUE": st.column_config.NumberColumn("Total Revenue", format="$%.2f"),
                        "RFM_SCORE": st.column_config.NumberColumn("RFM Score", format="%.1f"),
                        "TOTAL_ORDERS": st.column_config.NumberColumn("Total Orders"),
                        "DAYS_SINCE_LAST_ORDER": st.column_config.NumberColumn("Days Since Last Order")
                    }
                )
            else:
                st.warning("No customer lifetime value data available. Run dbt models first.")
            
    except Exception as e:
        st.error(f"Unexpected error: {str(e)}")

with tab2:
    st.subheader("Product Affinity & Recommendations")
    
    try:
        # Check if DBT_ANALYTICS schema exists
        schema_check = session.sql("""
            SELECT COUNT(*) as schema_exists 
            FROM AUTOMATED_INTELLIGENCE.INFORMATION_SCHEMA.SCHEMATA 
            WHERE SCHEMA_NAME = 'DBT_ANALYTICS'
        """).to_pandas()
        
        if schema_check.iloc[0]['SCHEMA_EXISTS'] == 0:
            st.info("📋 **dbt models not yet deployed**\n\nRun the following command to deploy dbt models:\n```\ndbt run --target dev\n```")
        else:
            # Query product affinity data
            affinity_query = """
            SELECT 
                product_a_name,
                product_a_category,
                product_b_name,
                product_b_category,
                times_bought_together,
                lift,
                confidence_a_to_b,
                affinity_strength,
                recommendation_priority
            FROM AUTOMATED_INTELLIGENCE.DBT_ANALYTICS.PRODUCT_AFFINITY
            ORDER BY lift DESC, times_bought_together DESC
            LIMIT 100
            """
            
            affinity_df = session.sql(affinity_query).to_pandas()
            
            if len(affinity_df) > 0:
                # Key metrics
                col1, col2, col3, col4 = st.columns(4)
                
                with col1:
                    total_pairs = len(affinity_df)
                    st.metric("Product Pairs", format_number(total_pairs, include_decimals=False))
                
                with col2:
                    strong_pairs = len(affinity_df[affinity_df['AFFINITY_STRENGTH'].isin(['very_strong', 'strong'])])
                    st.metric("Strong Affinities", format_number(strong_pairs, include_decimals=False))
                
                with col3:
                    avg_lift = affinity_df['LIFT'].mean()
                    st.metric("Avg Lift", f"{avg_lift:.2f}x")
                
                with col4:
                    cross_category = len(affinity_df[affinity_df['PRODUCT_A_CATEGORY'] != affinity_df['PRODUCT_B_CATEGORY']])
                    st.metric("Cross-Category Pairs", format_number(cross_category, include_decimals=False))
                
                st.divider()
                
                # Visualizations
                col1, col2 = st.columns(2)
                
                with col1:
                    st.markdown("**Affinity Strength Distribution**")
                    strength_counts = affinity_df['AFFINITY_STRENGTH'].value_counts().reset_index()
                    strength_counts.columns = ['Strength', 'Count']
                    
                    fig_strength = px.bar(
                        strength_counts,
                        x='Strength',
                        y='Count',
                        color='Strength',
                        color_discrete_map={
                            'very_strong': '#1f77b4',
                            'strong': '#2ca02c',
                            'moderate': '#ff7f0e',
                            'weak': '#d62728'
                        }
                    )
                    fig_strength.update_layout(showlegend=False)
                    st.plotly_chart(fig_strength, use_container_width=True)
                
                with col2:
                    st.markdown("**Top 10 Product Pairs by Lift**")
                    top_pairs = affinity_df.head(10).copy()
                    top_pairs['pair'] = top_pairs['PRODUCT_A_NAME'] + ' + ' + top_pairs['PRODUCT_B_NAME']
                    
                    fig_lift = px.bar(
                        top_pairs,
                        y='pair',
                        x='LIFT',
                        orientation='h',
                        color='LIFT',
                        color_continuous_scale='Blues'
                    )
                    fig_lift.update_layout(yaxis_title="", xaxis_title="Lift Score")
                    st.plotly_chart(fig_lift, use_container_width=True)
                
                st.divider()
                
                # Network visualization
                st.markdown("**Purchase Frequency Heatmap**")
                top_20_pairs = affinity_df.head(20)
                
                fig_freq = px.scatter(
                    top_20_pairs,
                    x='TIMES_BOUGHT_TOGETHER',
                    y='LIFT',
                    size='CONFIDENCE_A_TO_B',
                    color='AFFINITY_STRENGTH',
                    hover_data=['PRODUCT_A_NAME', 'PRODUCT_B_NAME'],
                    labels={
                        'TIMES_BOUGHT_TOGETHER': 'Times Bought Together',
                        'LIFT': 'Lift Score',
                        'CONFIDENCE_A_TO_B': 'Confidence'
                    },
                    color_discrete_map={
                        'very_strong': '#1f77b4',
                        'strong': '#2ca02c',
                        'moderate': '#ff7f0e',
                        'weak': '#d62728'
                    }
                )
                st.plotly_chart(fig_freq, use_container_width=True)
                
                st.divider()
                
                # Product recommendations table
                st.markdown("**Top Product Recommendations**")
                
                # Filter options
                col1, col2 = st.columns([1, 3])
                with col1:
                    min_strength = st.selectbox(
                        "Min Affinity Strength",
                        ['all', 'moderate', 'strong', 'very_strong'],
                        index=0
                    )
                
                filtered_df = affinity_df.copy()
                if min_strength != 'all':
                    strength_map = {
                        'moderate': ['moderate', 'strong', 'very_strong'],
                        'strong': ['strong', 'very_strong'],
                        'very_strong': ['very_strong']
                    }
                    filtered_df = filtered_df[filtered_df['AFFINITY_STRENGTH'].isin(strength_map[min_strength])]
                
                st.dataframe(
                    filtered_df.head(20),
                    use_container_width=True,
                    column_config={
                        "LIFT": st.column_config.NumberColumn("Lift", format="%.2f"),
                        "CONFIDENCE_A_TO_B": st.column_config.NumberColumn("Confidence", format="%.1%"),
                        "TIMES_BOUGHT_TOGETHER": st.column_config.NumberColumn("Times Bought Together")
                    }
                )
            else:
                st.warning("No product affinity data available. Run dbt models first.")
            
    except Exception as e:
        st.error(f"Error loading product analytics: {str(e)}")
        st.info("Make sure dbt models are deployed: `dbt run --target dev`")
