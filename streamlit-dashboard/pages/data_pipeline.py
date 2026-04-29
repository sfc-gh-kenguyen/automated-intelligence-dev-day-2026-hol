import streamlit as st
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots
from shared import get_session, show_header, format_number
import time
import json
import logging

logger = logging.getLogger(__name__)

show_header()
st.subheader("🚀 Next-Gen Warehouse Performance")
st.divider()

session = get_session()

def disable_query_cache_with_retry(session, max_retries=3, delay_seconds=0.5):
    """
    Attempt to disable query result cache with retry logic.
    This handles transient 'ALTER SESSION not supported in stored procedure' errors.
    """
    for attempt in range(max_retries):
        try:
            session.sql("ALTER SESSION SET USE_CACHED_RESULT = FALSE").collect()
            return True
        except Exception as e:
            error_msg = str(e)
            if "ALTER_SESSION" in error_msg or "90236" in error_msg:
                if attempt < max_retries - 1:
                    logger.warning(f"ALTER SESSION attempt {attempt + 1} failed (transient error), retrying in {delay_seconds}s...")
                    time.sleep(delay_seconds)
                    continue
                else:
                    logger.warning(f"ALTER SESSION failed after {max_retries} attempts, continuing without disabling cache")
                    return False
            else:
                raise
    return False

# Initialize session state
if 'pipeline_results' not in st.session_state:
    st.session_state.pipeline_results = None
if 'merge_running' not in st.session_state:
    st.session_state.merge_running = False

# ============================================================================
# SECTION 1: Staging Tables Status
# ============================================================================

st.markdown("### 📊 Staging Tables Status")
st.text("Records pending MERGE and UPDATE to production (raw) tables.")

# Initialize counts with default values
counts = {'orders_staging': 0, 'order_items_staging': 0, 'total_pending': 0}

try:
    result = session.sql("CALL AUTOMATED_INTELLIGENCE.staging.get_staging_counts()").collect()
    counts_json = result[0][0]
    counts = json.loads(counts_json)
    
    col1, col2, col3 = st.columns(3)
    
    with col1:
        st.metric("Orders Staging", format_number(counts['orders_staging'], include_decimals=False))
    
    with col2:
        st.metric("Order Items Staging", format_number(counts['order_items_staging'], include_decimals=False))
    
    with col3:
        st.metric("Total Pending", format_number(counts['total_pending'], include_decimals=False), 
                 delta="Ready for MERGE" if counts['total_pending'] > 0 else None)

except Exception as e:
    st.error(f"❌ Error fetching staging counts: {str(e)}")
    # Keep default counts (zeros) if error occurs

st.divider()

# ============================================================================
# SECTION 2: Gen2 vs Gen1 MERGE and Update Benchmark
# ============================================================================

st.markdown("### ⚡ Data Transformation Pipeline")
st.caption("MERGE and UPDATE staging records to production with Gen 1 and Gen 2 warehouses comparison")

with st.expander(f"MERGE and UPDATE Operations Details"):
    # Operation descriptions
    st.text("Operations Performed")
    st.markdown("""
    **MERGE Operations:**
    - Deduplicate and merge orders from staging to production (raw.orders)
    - Deduplicate and merge order items from staging to production (raw.order_items)
    - Use ROW_NUMBER() window function to handle duplicates
    
    **UPDATE Operations:**
    - Apply discount adjustments to recent orders based on total_amount
        - Orders ≥ $1000: +5% discount (max 50%)
        - Orders ≥ $500: +2.5% discount (max 50%)
        - Only update orders from last 30 days
    """)

if counts['total_pending'] == 0:
    st.warning("⚠️ No records in staging tables. Stream data to staging tables first using Snowpipe Streaming.")

run_both = st.button("🔄 Run MERGE & UPDATE Test using Gen 1 and Gen 2 Warehouses", type="primary",
                    disabled=st.session_state.merge_running or counts['total_pending'] == 0)

# Run MERGE operations
if run_both:
    st.session_state.merge_running = True
    st.session_state.pipeline_results = {}
    
    warehouses_to_test = [
        ('Gen1', 'automated_intelligence_wh'),
        ('Gen2', 'automated_intelligence_gen2_wh')
    ]
    
    # Create snapshot of discount values before any tests
    with st.spinner("Creating data snapshot for fair comparison..."):
        try:
            session.sql("CALL AUTOMATED_INTELLIGENCE.staging.create_discount_snapshot()").collect()
        except Exception as e:
            st.error(f"❌ Error creating snapshot: {str(e)}")
            st.session_state.merge_running = False
            st.stop()
    
    # Resume and warm up BOTH warehouses
    with st.spinner("Warming up both warehouses..."):
        for label, warehouse in warehouses_to_test:
            try:
                session.sql(f"ALTER WAREHOUSE {warehouse} RESUME IF SUSPENDED").collect()
                st.info(f"✅ {label} warehouse resumed")
            except Exception as e:
                st.warning(f"⚠️ Could not resume {warehouse}: {str(e)}")
    
    # Run warmup round to compile stored procedures and prime caches
    with st.spinner("Running warmup round (not timed)..."):
        for label, warehouse in warehouses_to_test:
            try:
                session.sql("CALL AUTOMATED_INTELLIGENCE.staging.restore_discount_snapshot()").collect()
                session.sql(f"USE WAREHOUSE {warehouse}").collect()
                
                # Disable cache with retry logic (handles transient errors)
                disable_query_cache_with_retry(session)
                
                # Run actual workload once to compile stored procedures
                session.sql("CALL AUTOMATED_INTELLIGENCE.staging.merge_staging_to_raw()").collect()
                session.sql("CALL AUTOMATED_INTELLIGENCE.staging.enrich_raw_data()").collect()
                
                st.info(f"✅ {label} warmup complete (stored procedures compiled)")
            except Exception as e:
                st.warning(f"⚠️ Warmup failed for {warehouse}: {str(e)}")
    
    # Now run the actual timed tests - both starting from identical warm state
    for i, (label, warehouse) in enumerate(warehouses_to_test):
        with st.spinner(f"Running timed test with {label}..."):
            try:
                # Restore snapshot before each test
                session.sql("CALL AUTOMATED_INTELLIGENCE.staging.restore_discount_snapshot()").collect()
                
                # Set warehouse for this session
                session.sql(f"USE WAREHOUSE {warehouse}").collect()
                
                # Clear query result cache to ensure fair comparison (with retry logic)
                disable_query_cache_with_retry(session)
                
                # Run MERGE
                merge_start = time.time()
                merge_result = session.sql(
                    f"CALL AUTOMATED_INTELLIGENCE.staging.merge_staging_to_raw()"
                ).collect()
                merge_duration = time.time() - merge_start
                
                merge_json = merge_result[0][0]
                merge_data = json.loads(merge_json)
                
                # Run UPDATE enrichment
                update_start = time.time()
                update_result = session.sql(
                    f"CALL AUTOMATED_INTELLIGENCE.staging.enrich_raw_data()"
                ).collect()
                update_duration = time.time() - update_start
                
                update_json = update_result[0][0]
                update_data = json.loads(update_json)
                
                # Store results
                st.session_state.pipeline_results[label] = {
                    'merge': merge_data,
                    'update': update_data,
                    'total_ms': merge_data['total_duration_ms'] + update_data['duration_ms']
                }
                
            except Exception as e:
                st.error(f"❌ Error running {label} pipeline: {str(e)}")
                st.session_state.pipeline_results[label] = {'error': str(e)}
    
    # Truncate staging tables after successful MERGE
    if st.session_state.pipeline_results and not any('error' in r for r in st.session_state.pipeline_results.values()):
        try:
            session.sql("CALL AUTOMATED_INTELLIGENCE.staging.truncate_staging_tables()").collect()
        except Exception as e:
            st.warning(f"⚠️ Failed to truncate staging tables: {str(e)}")
    
    st.session_state.merge_running = False
    st.rerun()

# Display results
if st.session_state.pipeline_results:
    st.markdown("### 📈 Pipeline Performance Results")
    
    st.divider()
    
    results = st.session_state.pipeline_results
    
    # Create comparison table
    if len(results) > 1:
        st.markdown("#### 🏆 Gen1 vs Gen2 Comparison")
        
        gen1_total = results['Gen1']['total_ms']
        gen2_total = results['Gen2']['total_ms']
        speedup = gen1_total / gen2_total
        improvement_pct = ((gen1_total - gen2_total) / gen1_total) * 100
        
        # Determine if Gen2 is faster or slower
        if speedup > 1:
            speed_label = f"{speedup:.2f}x faster"
            delta_color = "normal"
        else:
            slowdown = gen2_total / gen1_total
            speed_label = f"{slowdown:.2f}x slower"
            delta_color = "inverse"
        
        col1, col2, col3 = st.columns(3)
        
        with col1:
            st.metric("Gen1 Total Time", f"{gen1_total:,.0f} ms")
        
        with col2:
            st.metric("Gen2 Total Time", f"{gen2_total:,.0f} ms", 
                     delta=speed_label, delta_color=delta_color)
        
        with col3:
            st.metric("Performance Gain", f"{improvement_pct:.1f}%", 
                     delta=f"{gen1_total - gen2_total:,.0f} ms saved")
        
        # Detailed breakdown chart
        st.markdown("#### 📊 Detailed Breakdown")
        
        categories = ['MERGE Orders', 'MERGE Order Items', 'UPDATE Enrichment']
        
        gen1_values = [
            results['Gen1']['merge']['orders']['duration_ms'],
            results['Gen1']['merge']['order_items']['duration_ms'],
            results['Gen1']['update']['duration_ms']
        ]
        
        gen2_values = [
            results['Gen2']['merge']['orders']['duration_ms'],
            results['Gen2']['merge']['order_items']['duration_ms'],
            results['Gen2']['update']['duration_ms']
        ]
        
        fig = go.Figure(data=[
            go.Bar(name='Gen1', x=categories, y=gen1_values, marker_color='#757575'),
            go.Bar(name='Gen2', x=categories, y=gen2_values, marker_color='#1976d2')
        ])
        
        fig.update_layout(
            barmode='group',
            yaxis_title='Duration (ms)',
            height=400,
            legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1)
        )
        
        st.plotly_chart(fig, width="stretch")
    
    # Individual results
    for label, data in results.items():
        if 'error' in data:
            st.error(f"❌ {label}: {data['error']}")
            continue
            
        with st.expander(f"🔍 {label} Warehouse Details"):
            col1, col2 = st.columns(2)
            
            with col1:
                st.markdown("**MERGE Operations:**")
                st.text(f"Orders merged: {format_number(data['merge']['orders']['records_merged'], include_decimals=False)}")
                st.text(f"Duration: {format_number(data['merge']['orders']['duration_ms'], include_decimals=False)} ms")
                st.text("")
                st.text(f"Order items merged: {format_number(data['merge']['order_items']['records_merged'], include_decimals=False)}")
                st.text(f"Duration: {format_number(data['merge']['order_items']['duration_ms'], include_decimals=False)} ms")
            
            with col2:
                st.markdown("**UPDATE Operations:**")
                st.text(f"Orders updated: {format_number(data['update']['orders_updated'], include_decimals=False)}")
                st.text(f"Duration: {format_number(data['update']['duration_ms'], include_decimals=False)} ms")

st.divider()

# ============================================================================
# SECTION 4: End of page
# ============================================================================

