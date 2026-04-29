import streamlit as st
import time
import random
import traceback
from concurrent.futures import ThreadPoolExecutor, as_completed
from shared import get_session, show_header

show_header()
st.subheader("⚡ Query Performance")
st.divider()
st.text("Interactive Tables + Interactive Warehouse vs Standard Tables + Standard Warehouse Comparison")
st.caption("Configure test parameters and run a performance comparison")

session = get_session()

# Initialize session state for test running status and results
if 'test_running' not in st.session_state:
    st.session_state.test_running = False
if 'test_results' not in st.session_state:
    st.session_state.test_results = None
if 'test_error' not in st.session_state:
    st.session_state.test_error = None

# Performance test parameters
col1, col2, col3 = st.columns(3)

with col1:
    num_queries = st.number_input("Number of queries", min_value=5, max_value=100, value=10, step=5, 
                                 disabled=st.session_state.test_running)

with col2:
    warehouse_option = st.selectbox("Select warehouse", 
                                    ["Both - Interactive & Standard", "Interactive Only", "Standard Only"],
                                    index=0,
                                    disabled=st.session_state.test_running)

with col3:
    concurrency = st.number_input("Concurrency level", min_value=1, max_value=500, value=100, step=1,
                                 disabled=st.session_state.test_running)

# Performance test button
run_test = st.button("🚀 Run Performance Test", type="primary", disabled=st.session_state.test_running)

if run_test and not st.session_state.test_running:
    st.session_state.test_running = True
    st.session_state.test_results = None
    st.session_state.test_error = None
    st.rerun()

if st.session_state.test_running:
    try:
        with st.spinner(f"Running {num_queries} queries with concurrency {concurrency}..."):
            interactive_query = """
            SELECT 
                CUSTOMER_ID,
                TOTAL_ORDERS as order_count,
                TOTAL_SPENT
            FROM AUTOMATED_INTELLIGENCE.INTERACTIVE.CUSTOMER_ORDER_ANALYTICS
            WHERE CUSTOMER_ID = {customer_id}
            """
            
            standard_query = """
            SELECT 
                c.customer_id,
                COUNT(o.order_id) as order_count,
                SUM(o.total_amount) as total_spent
            FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS c
            LEFT JOIN AUTOMATED_INTELLIGENCE.RAW.ORDERS o ON c.customer_id = o.customer_id
            WHERE c.customer_id = {customer_id}
            GROUP BY c.customer_id
            """
            
            def run_single_query(customer_id, query_template, use_interactive_wh=False):
                try:
                    actual_query = query_template.replace("{customer_id}", str(customer_id))
                    
                    if use_interactive_wh:
                        session.sql("USE WAREHOUSE automated_intelligence_interactive_wh").collect()
                    else:
                        session.sql("USE WAREHOUSE automated_intelligence_wh").collect()
                    
                    start = time.time()
                    results = session.sql(actual_query).collect()
                    duration = (time.time() - start) * 1000
                    
                    # Removed warning - all customer IDs now guaranteed to have orders
                    
                    return duration
                except Exception as e:
                    print(f"Failed for customer_id {customer_id}: {e}")
                    raise
            
            run_interactive = warehouse_option in ["Both - Interactive & Standard", "Interactive Only"]
            run_standard = warehouse_option in ["Both - Interactive & Standard", "Standard Only"]
            
            # Get a sample of actual customer IDs that have orders
            sample_customers = session.sql("""
                SELECT DISTINCT customer_id 
                FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS 
                ORDER BY RANDOM() 
                LIMIT 1000
            """).collect()
            available_customer_ids = [row[0] for row in sample_customers]
            
            if len(available_customer_ids) < num_queries:
                st.warning(f"⚠️ Only {len(available_customer_ids)} customers with orders found. Using those for testing.")
            
            results = {}
            queries_used = {}
            
            if run_interactive:
                queries_used['interactive'] = interactive_query
                interactive_results = []
                customer_ids = random.choices(available_customer_ids, k=min(num_queries, len(available_customer_ids)))
                
                # Run queries concurrently using ThreadPoolExecutor
                with ThreadPoolExecutor(max_workers=concurrency) as executor:
                    futures = [executor.submit(run_single_query, cid, interactive_query, True) 
                              for cid in customer_ids]
                    
                    for future in as_completed(futures):
                        interactive_results.append(future.result())
                
                results['Interactive Tables + Warehouse'] = interactive_results
            
            if run_standard:
                queries_used['standard'] = standard_query
                standard_results = []
                customer_ids = random.choices(available_customer_ids, k=min(num_queries, len(available_customer_ids)))
                
                # Run queries concurrently using ThreadPoolExecutor
                with ThreadPoolExecutor(max_workers=concurrency) as executor:
                    futures = [executor.submit(run_single_query, cid, standard_query, False) 
                              for cid in customer_ids]
                    
                    for future in as_completed(futures):
                        standard_results.append(future.result())
                
                results['Standard Tables + Warehouse'] = standard_results
            
            st.session_state.test_results = {
                'results': results,
                'num_queries': num_queries,
                'concurrency': concurrency,
                'queries': queries_used
            }
            
    except Exception as e:
        st.session_state.test_error = {
            'message': str(e),
            'traceback': traceback.format_exc()
        }
        st.session_state.test_results = None
    finally:
        session.sql("USE WAREHOUSE automated_intelligence_wh").collect()
        st.session_state.test_running = False
        st.rerun()

# Display error if one occurred
if st.session_state.test_error is not None:
    error_data = st.session_state.test_error
    st.error(f"❌ Error running performance test: {error_data['message']}")
    with st.expander("Show full error traceback"):
        st.code(error_data['traceback'])

# Display results if available
if st.session_state.test_results is not None:
    test_data = st.session_state.test_results
    results = test_data['results']
    num_queries = test_data['num_queries']
    concurrency = test_data['concurrency']
    queries_used = test_data.get('queries', {})
    
    st.success(f"✅ Performance test completed! ({num_queries} queries, concurrency: {concurrency})")
    
    st.divider()
    
    for test_name, test_results in results.items():
        st.markdown(f"#### {test_name}")
        
        avg_latency = sum(test_results) / len(test_results)
        min_latency = min(test_results)
        max_latency = max(test_results)
        p95_latency = sorted(test_results)[int(len(test_results) * 0.95)]
        
        col1, col2, col3, col4 = st.columns(4)
        
        # Avg Latency with blue text color
        with col1:
            st.markdown("**Avg Latency**")
            st.markdown(f'<p style="color: #1976d2; font-size: 36px; font-weight: 600; margin: 0; line-height: 1.2;">{avg_latency:.0f} ms</p>', unsafe_allow_html=True)
        
        col2.metric("Min Latency", f"{min_latency:.0f} ms")
        col3.metric("P95 Latency", f"{p95_latency:.0f} ms")
        col4.metric("Max Latency", f"{max_latency:.0f} ms")
        
        st.divider()
    
    if len(results) == 2:
        st.markdown("#### 📊 Performance Comparison")
        
        interactive_avg = sum(results['Interactive Tables + Warehouse']) / len(results['Interactive Tables + Warehouse'])
        standard_avg = sum(results['Standard Tables + Warehouse']) / len(results['Standard Tables + Warehouse'])
        speedup = standard_avg / interactive_avg
        
        if speedup > 1:
            st.success(f"#### 🏆 Interactive Tables + Interactive Warehouse is **{speedup:.2f}x faster** than Standard Tables + Standard Warehouse\n"
                      f"**Test Parameters:** {num_queries} queries | Concurrency: {concurrency}")
        else:
            st.success(f"#### 🏆 Standard Tables + Standard Warehouse is **{(1/speedup):.2f}x faster** than Interactive Tables + Interactive Warehouse\n"
                      f"**Test Parameters:** {num_queries} queries | Concurrency: {concurrency}")
    
    with st.expander("🔍 View Queries Used in Test"):
        if 'interactive' in queries_used:
            st.markdown("**Interactive Tables + Warehouse Query:**")
            st.code(queries_used['interactive'], language="sql")
            st.caption(f"Uses: AUTOMATED_INTELLIGENCE_INTERACTIVE_WH warehouse")
        
        if 'standard' in queries_used:
            st.markdown("**Standard Tables + Warehouse Query:**")
            st.code(queries_used['standard'], language="sql")
            st.caption(f"Uses: AUTOMATED_INTELLIGENCE_WH warehouse")
        
        st.info("💡 **Why Interactive Tables are faster:**\n"
               "- Pre-aggregated data (TOTAL_ORDERS, TOTAL_SPENT already computed)\n"
               "- No JOIN required (vs LEFT JOIN between CUSTOMERS and ORDERS)\n"
               "- Clustered by CUSTOMER_ID for fast lookups\n"
               "- Optimized warehouse for low-latency queries")
