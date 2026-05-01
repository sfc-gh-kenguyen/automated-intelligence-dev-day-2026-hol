import streamlit as st
import time
from pathlib import Path
from shared import IS_SIS, load_custom_css

APP_DIR = Path(__file__).parent

st.set_page_config(
    page_title="The Dash Board",
    page_icon=str(APP_DIR / "assets" / "dash_snowboard_512.png"),
    layout="wide",
    initial_sidebar_state="expanded"
)

# Load custom CSS
load_custom_css()

data_pipeline_page = st.Page("pages/summary.py", title="Data Pipeline", icon="🔄", url_path="data_pipeline")
pipeline_health_page = st.Page("pages/pipeline_health.py", title="Pipeline Health", icon="🏥", url_path="pipeline_health")
customer_product_analytics_page = st.Page("pages/customer_product_analytics.py", title="Product Analytics", icon="📈", url_path="customer_product_analytics")

pg = st.navigation([data_pipeline_page, pipeline_health_page, customer_product_analytics_page])

# Auto-refresh controls in sidebar
with st.sidebar:
    st.divider()
    st.header("⚙️ Settings")
    auto_refresh_enabled = st.checkbox("Enable auto-refresh", value=False)
    refresh_interval = st.slider("Refresh interval (seconds)", 10, 30, 15, disabled=not auto_refresh_enabled)

# Run the selected page
pg.run()

# Auto-refresh 
if auto_refresh_enabled and not st.session_state.get("merge_done", False):
    time.sleep(refresh_interval)
    st.rerun()
