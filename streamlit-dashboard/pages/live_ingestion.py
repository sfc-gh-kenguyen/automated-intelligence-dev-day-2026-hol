import streamlit as st
import plotly.express as px
from shared import get_session, show_header, format_number

show_header()
st.subheader("📊 Live Ingestion")
st.divider()

session = get_session()

try:
    col_staging, col_production = st.columns(2)

    with col_staging:
        st.markdown("### 🔧 Staging")
        st.caption("Data lands here via Snowpipe Streaming")

        staging_orders = session.sql("SELECT COUNT(*) as cnt FROM DASH_AUTOMATED_INTELLIGENCE_DB.STAGING.ORDERS_STAGING").collect()
        staging_items = session.sql("SELECT COUNT(*) as cnt FROM DASH_AUTOMATED_INTELLIGENCE_DB.STAGING.ORDER_ITEMS_STAGING").collect()
        staging_revenue = session.sql("SELECT COALESCE(ROUND(SUM(total_amount), 2), 0) as val FROM DASH_AUTOMATED_INTELLIGENCE_DB.STAGING.ORDERS_STAGING").collect()

        st.metric("Orders", format_number(staging_orders[0]['CNT'], include_decimals=False))
        st.metric("Order Items", format_number(staging_items[0]['CNT'], include_decimals=False))
        st.metric("Revenue", f"${format_number(staging_revenue[0]['VAL'])}")

    with col_production:
        st.markdown("### 🚀 Production (RAW)")
        st.caption("Promoted via Gen2 Warehouse MERGE")

        prod_orders = session.sql("SELECT COUNT(*) as cnt FROM DASH_AUTOMATED_INTELLIGENCE_DB.RAW.ORDERS").collect()
        prod_items = session.sql("SELECT COUNT(*) as cnt FROM DASH_AUTOMATED_INTELLIGENCE_DB.RAW.ORDER_ITEMS").collect()
        prod_revenue = session.sql("SELECT COALESCE(ROUND(SUM(total_amount), 2), 0) as val FROM DASH_AUTOMATED_INTELLIGENCE_DB.RAW.ORDERS").collect()

        st.metric("Orders", format_number(prod_orders[0]['CNT'], include_decimals=False))
        st.metric("Order Items", format_number(prod_items[0]['CNT'], include_decimals=False))
        st.metric("Revenue", f"${format_number(prod_revenue[0]['VAL'])}")

    st.divider()
    st.info("💡 **Pipeline flow:** Snowpipe Streaming → Staging → Gen2 MERGE → Production (RAW) → Dynamic Tables → Interactive Tables")

    st.divider()
    st.markdown("### 📈 Production Ingestion Trend")

    trend_df = session.sql("""
        SELECT
            DATE_TRUNC('day', ORDER_DATE) as day,
            COUNT(*) as order_count
        FROM DASH_AUTOMATED_INTELLIGENCE_DB.RAW.ORDERS
        WHERE ORDER_DATE >= DATEADD('month', -3, CURRENT_TIMESTAMP())
        GROUP BY DATE_TRUNC('day', ORDER_DATE)
        ORDER BY day
    """).to_pandas()

    if not trend_df.empty:
        fig = px.area(trend_df, x="DAY", y="ORDER_COUNT", height=400)
        fig.update_xaxes(title="Date")
        fig.update_yaxes(title="Orders per Day")
        fig.update_layout(hovermode='x unified')
        st.plotly_chart(fig, use_container_width=True)
    else:
        st.warning("No recent order data available.")

except Exception as e:
    st.error(f"Unexpected error: {e}")
