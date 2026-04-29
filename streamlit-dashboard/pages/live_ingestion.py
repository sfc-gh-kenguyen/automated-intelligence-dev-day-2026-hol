import streamlit as st
import plotly.express as px
from shared import get_session, show_header, format_number

show_header()
st.subheader("📊 Live Ingestion")
st.divider()

session = get_session()

def render_ingestion_dashboard(schema: str, orders_table: str, order_items_table: str):
    try:
        # All-time totals (same as Summary page)
        col1, col2, col3, col4, col5 = st.columns(5)

        alltime_orders_result = session.sql(f"SELECT COUNT(*) as cnt FROM AUTOMATED_INTELLIGENCE.{schema}.{orders_table}").collect()
        alltime_orders = alltime_orders_result[0]['CNT'] if alltime_orders_result else 0

        alltime_items_result = session.sql(f"SELECT COUNT(*) as cnt FROM AUTOMATED_INTELLIGENCE.{schema}.{order_items_table}").collect()
        alltime_items = alltime_items_result[0]['CNT'] if alltime_items_result else 0

        alltime_customers_result = session.sql("SELECT COUNT(*) as cnt FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS").collect()
        alltime_customers = alltime_customers_result[0]['CNT'] if alltime_customers_result else 0

        alltime_revenue_result = session.sql(f"SELECT ROUND(SUM(total_amount), 2) as total_revenue FROM AUTOMATED_INTELLIGENCE.{schema}.{orders_table}").collect()
        alltime_revenue = alltime_revenue_result[0]['TOTAL_REVENUE'] if alltime_revenue_result and alltime_revenue_result[0]['TOTAL_REVENUE'] is not None else 0

        alltime_products_result = session.sql(f"SELECT COUNT(DISTINCT product_id) as cnt FROM AUTOMATED_INTELLIGENCE.{schema}.{order_items_table}").collect()
        alltime_products = alltime_products_result[0]['CNT'] if alltime_products_result else 0

        col1.metric("Total Customers", format_number(alltime_customers, include_decimals=False))
        col2.metric("Total Orders", format_number(alltime_orders, include_decimals=False))
        col3.metric("Total Order Items", format_number(alltime_items, include_decimals=False))
        col4.metric("Total Products", format_number(alltime_products, include_decimals=False))
        col5.metric("Total Revenue", f"${format_number(alltime_revenue)}")

        st.divider()

        # Time-filtered section
        days = st.slider("Show data for last N days", 7, 30, 7, key=f"days_filter_{schema}")
        st.markdown(f"#### Last {days} Days")

        orders_count_query = f"""
        SELECT COUNT(*) as cnt FROM AUTOMATED_INTELLIGENCE.{schema}.{orders_table}
        WHERE ORDER_DATE >= DATEADD('day', -{days}, CURRENT_TIMESTAMP())
        """
        orders_result = session.sql(orders_count_query).collect()
        total_orders = orders_result[0]['CNT'] if orders_result else 0
        
        order_items_count_query = f"""
        SELECT COUNT(*) as cnt 
        FROM AUTOMATED_INTELLIGENCE.{schema}.{order_items_table} oi
        JOIN AUTOMATED_INTELLIGENCE.{schema}.{orders_table} o ON oi.order_id = o.order_id
        WHERE o.ORDER_DATE >= DATEADD('day', -{days}, CURRENT_TIMESTAMP())
        """
        items_result = session.sql(order_items_count_query).collect()
        total_items = items_result[0]['CNT'] if items_result else 0
        
        st.markdown(f"📊 Orders: **{format_number(total_orders, include_decimals=False)}**  |  📦 Order Items: **{format_number(total_items, include_decimals=False)}**")
        
        st.divider()
        
        st.markdown("#### 📈 Ingestion Trend")
        
        trend_query = f"""
        SELECT 
            DATE_TRUNC('hour', ORDER_DATE) as hour,
            COUNT(*) as order_count
        FROM AUTOMATED_INTELLIGENCE.{schema}.{orders_table}
        WHERE ORDER_DATE >= DATEADD('day', -{days}, CURRENT_TIMESTAMP())
        GROUP BY DATE_TRUNC('hour', ORDER_DATE)
        ORDER BY hour
        """
        
        trend_df = session.sql(trend_query).to_pandas()
        
        if not trend_df.empty:
            fig = px.line(trend_df, x="HOUR", y="ORDER_COUNT", height=400)
            fig.update_xaxes(title="Date/Time")
            fig.update_yaxes(title="Order Count")
            fig.update_layout(hovermode='x unified')
            st.plotly_chart(fig, width='stretch')
        else:
            fallback_query = f"""
            SELECT 
                DATE_TRUNC('day', ORDER_DATE) as day,
                COUNT(*) as order_count
            FROM AUTOMATED_INTELLIGENCE.{schema}.{orders_table}
            WHERE ORDER_DATE >= (SELECT MAX(ORDER_DATE) - INTERVAL '30 days' FROM AUTOMATED_INTELLIGENCE.{schema}.{orders_table})
            GROUP BY DATE_TRUNC('day', ORDER_DATE)
            ORDER BY day
            """
            fallback_df = session.sql(fallback_query).to_pandas()
            if not fallback_df.empty:
                st.warning(f"⚠️ No data available for the last {days} days. Showing all-time trend...")
                st.line_chart(fallback_df, x="DAY", y="ORDER_COUNT", height=300)
            else:
                st.warning("⚠️ No data available. Stream data first using Snowpipe Streaming.")
        
        st.divider()
        
        st.markdown("#### 🥧 Order Status Distribution")
        
        status_query = f"""
        SELECT 
            ORDER_STATUS,
            COUNT(*) as order_count
        FROM AUTOMATED_INTELLIGENCE.{schema}.{orders_table}
        WHERE ORDER_DATE >= DATEADD('day', -{days}, CURRENT_TIMESTAMP())
        GROUP BY ORDER_STATUS
        ORDER BY order_count DESC
        """
        
        status_df = session.sql(status_query).to_pandas()
        
        if status_df.empty:
            fallback_status_query = f"""
            SELECT 
                ORDER_STATUS,
                COUNT(*) as order_count
            FROM AUTOMATED_INTELLIGENCE.{schema}.{orders_table}
            GROUP BY ORDER_STATUS
            ORDER BY order_count DESC
            """
            status_df = session.sql(fallback_status_query).to_pandas()
            if not status_df.empty:
                st.warning(f"⚠️ No data available for the last {days} days. Showing all-time distribution...")
        
        if not status_df.empty:
            fig = px.pie(status_df, values='ORDER_COUNT', names='ORDER_STATUS', height=600)
            fig.update_traces(textposition='inside', textinfo='percent+label')
            st.plotly_chart(fig, width='stretch')
        else:
            st.info("No orders available")
        
        st.divider()
        
        st.markdown("#### 📊 Product Category Sales by Order Size")
        
        stacked_query = f"""
        SELECT 
            CASE
                WHEN o.total_amount < 100 THEN 'Small (<$100)'
                WHEN o.total_amount < 500 THEN 'Medium ($100-$500)'
                WHEN o.total_amount < 2000 THEN 'Large ($500-$2K)'
                ELSE 'Extra Large (>$2K)'
            END AS order_size,
            oi.product_category,
            SUM(oi.line_total) as revenue
        FROM AUTOMATED_INTELLIGENCE.{schema}.{orders_table} o
        JOIN AUTOMATED_INTELLIGENCE.{schema}.{order_items_table} oi ON o.order_id = oi.order_id
        WHERE o.ORDER_DATE >= DATEADD('day', -{days}, CURRENT_TIMESTAMP())
        GROUP BY order_size, oi.product_category
        ORDER BY 
            CASE order_size
                WHEN 'Small (<$100)' THEN 1
                WHEN 'Medium ($100-$500)' THEN 2
                WHEN 'Large ($500-$2K)' THEN 3
                WHEN 'Extra Large (>$2K)' THEN 4
            END,
            oi.product_category
        """
        
        stacked_df = session.sql(stacked_query).to_pandas()
        
        if stacked_df.empty:
            fallback_stacked_query = f"""
            SELECT 
                CASE
                    WHEN o.total_amount < 100 THEN 'Small (<$100)'
                    WHEN o.total_amount < 500 THEN 'Medium ($100-$500)'
                    WHEN o.total_amount < 2000 THEN 'Large ($500-$2K)'
                    ELSE 'Extra Large (>$2K)'
                END AS order_size,
                oi.product_category,
                SUM(oi.line_total) as revenue
            FROM AUTOMATED_INTELLIGENCE.{schema}.{orders_table} o
            JOIN AUTOMATED_INTELLIGENCE.{schema}.{order_items_table} oi ON o.order_id = oi.order_id
            GROUP BY order_size, oi.product_category
            ORDER BY 
                CASE order_size
                    WHEN 'Small (<$100)' THEN 1
                    WHEN 'Medium ($100-$500)' THEN 2
                    WHEN 'Large ($500-$2K)' THEN 3
                    WHEN 'Extra Large (>$2K)' THEN 4
                END,
                oi.product_category
            """
            stacked_df = session.sql(fallback_stacked_query).to_pandas()
            if not stacked_df.empty:
                st.warning(f"⚠️ No data available for the last {days} days. Showing all-time category sales...")
        
        if not stacked_df.empty:
            fig = px.bar(stacked_df, x='ORDER_SIZE', y='REVENUE', color='PRODUCT_CATEGORY',
                        labels={'ORDER_SIZE': 'Order Size', 'REVENUE': 'Revenue', 'PRODUCT_CATEGORY': 'Category'},
                        height=500,
                        barmode='stack')
            fig.update_layout(legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1))
            st.plotly_chart(fig, width='stretch')
        else:
            st.info("No data available")

    except Exception as e:
        st.error(str(e))

tab1, tab2 = st.tabs(["🚀 Production", "🔧 Staging"])

with tab1:
    render_ingestion_dashboard("RAW", "ORDERS", "ORDER_ITEMS")

with tab2:
    render_ingestion_dashboard("STAGING", "ORDERS_STAGING", "ORDER_ITEMS_STAGING")
