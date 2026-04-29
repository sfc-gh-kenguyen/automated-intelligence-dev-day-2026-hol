import streamlit as st
import os

def format_number(num, include_decimals=True):
    """Format large numbers with K, M, B suffixes"""
    if num is None:
        return "0"
    
    num = float(num)
    
    if abs(num) >= 1_000_000_000:
        formatted = num / 1_000_000_000
        suffix = "B"
    elif abs(num) >= 1_000_000:
        formatted = num / 1_000_000
        suffix = "M"
    elif abs(num) >= 1_000:
        formatted = num / 1_000
        suffix = "K"
    else:
        return f"{num:,.0f}" if not include_decimals else f"{num:,.2f}"
    
    if include_decimals:
        return f"{formatted:.2f}{suffix}"
    else:
        return f"{formatted:.2f}{suffix}"

def is_streamlit_in_snowflake():
    """Detect if running in Streamlit in Snowflake"""
    return any([
        'SNOWFLAKE_HOME' in os.environ,
        'SNOWFLAKE_ACCOUNT' in os.environ
    ])

def get_session():
    """Get or create Snowflake session"""
    if 'session' not in st.session_state:
        conn = st.connection("snowflake")
        st.session_state.session = conn.session()
    return st.session_state.session

def load_custom_css():
    """Load custom CSS file"""
    import os
    css_path = os.path.join(os.path.dirname(__file__), "app.css")
    with open(css_path) as f:
        st.markdown(f"<style>{f.read()}</style>", unsafe_allow_html=True)

def show_header():
    """Display app header with logo and title"""
    # Load CSS first
    load_custom_css()
    
    if not IS_SIS:
        col1, col2 = st.columns([0.8, 12])
        with col1:
            st.markdown("<div class='logo-spacing'></div>", unsafe_allow_html=True)
            st.image("assets/dash_snowboard_512.png", width=80)
        with col2:
            st.markdown("<div class='title-spacing'></div>", unsafe_allow_html=True)
            st.title("The Dash Board")
        st.caption("Monitor data ingestion, pipeline health, and compare Interactive vs Standard table performance")
    else:
        st.title("🏂 The Dash Board")
        st.caption("Monitor data ingestion, pipeline health, and compare Interactive vs Standard table performance")

IS_SIS = is_streamlit_in_snowflake()
