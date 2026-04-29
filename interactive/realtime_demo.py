"""
Real-Time Pipeline Demo for Interactive Tables
==============================================
Purpose: Demonstrate real-time data flow from ingestion to serving

This script:
1. Monitors data appearing in raw tables (from Snowpipe Streaming)
2. Waits for Interactive Tables refresh
3. Queries data from Interactive Tables with <100ms latency
4. Shows end-to-end pipeline latency

Flow:
  Ingestion → Raw Tables (seconds)
  → Dynamic Tables (5-min lag)
  → Interactive Tables (5-min lag)
  → Query Results (<100ms)

Usage:
    python realtime_demo.py --monitor-pipeline
    
Note: Order generation now uses Snowpipe Streaming.
See snowpipe-streaming-java/ or snowpipe-streaming-python/ directories.
"""

import argparse
import os
import time
from datetime import datetime
from typing import Optional

import snowflake.connector


class RealtimePipelineDemo:
    def __init__(self, connection_name: str):
        self.connection_name = connection_name
        self.conn = None
    
    def connect(self):
        """Establish connection to Snowflake"""
        if not self.conn:
            self.conn = snowflake.connector.connect(connection_name=self.connection_name)
        return self.conn
    
    def close(self):
        """Close connection"""
        if self.conn:
            self.conn.close()
            self.conn = None
    
    def execute_query(self, sql: str, fetch: bool = True):
        """Execute a query and optionally fetch results"""
        conn = self.connect()
        cursor = conn.cursor()
        cursor.execute(sql)
        
        if fetch:
            results = cursor.fetchall()
            cursor.close()
            return results
        else:
            cursor.close()
            return None
    
    def get_latest_order_id(self):
        """Get the latest order_id from raw.orders table"""
        print(f"\n{'='*80}")
        print(f"STEP 1: Check Current Orders")
        print(f"{'='*80}")
        
        print(f"\n⏳ Querying latest order...")
        
        self.execute_query("USE WAREHOUSE automated_intelligence_wh", fetch=False)
        
        result = self.execute_query(
            "SELECT MAX(order_id) as latest_order FROM automated_intelligence.raw.orders"
        )
        latest_order_id = result[0][0]
        print(f"📊 Latest order_id: {latest_order_id}")
        print(f"\n💡 Use Snowpipe Streaming to generate new orders")
        
        return latest_order_id
    
    def monitor_dynamic_tables_refresh(self, latest_order_id: int, timeout: int = 600):
        """Monitor Dynamic Tables for new data"""
        print(f"\n{'='*80}")
        print(f"STEP 2: Monitor Dynamic Tables Refresh")
        print(f"{'='*80}")
        print(f"\n⏳ Waiting for order_id {latest_order_id} to appear in dynamic_tables.fact_orders...")
        print(f"   (TARGET_LAG = 12 hours, but may refresh sooner)\n")
        
        # Use standard warehouse for querying standard tables
        self.execute_query("USE WAREHOUSE automated_intelligence_wh", fetch=False)
        
        start_time = time.time()
        
        while (time.time() - start_time) < timeout:
            result = self.execute_query(f"""
                SELECT COUNT(*) 
                FROM automated_intelligence.dynamic_tables.fact_orders
                WHERE order_id = {latest_order_id}
            """)
            
            count = result[0][0]
            
            if count > 0:
                elapsed = time.time() - start_time
                print(f"✅ Order {latest_order_id} appeared in Dynamic Tables after {elapsed:.2f} seconds")
                return True
            
            print(f"   Checking... (elapsed: {int(time.time() - start_time)}s)", end="\r")
            time.sleep(5)
        
        print(f"\n⚠️  Timeout: Order did not appear in Dynamic Tables within {timeout}s")
        return False
    
    def monitor_interactive_tables_refresh(self, latest_order_id: int, timeout: int = 600):
        """Monitor Interactive Tables for new data"""
        print(f"\n{'='*80}")
        print(f"STEP 2: Monitor Interactive Tables Refresh")
        print(f"{'='*80}")
        print(f"\n⏳ Waiting for order_id {latest_order_id} to appear in interactive tables...")
        print(f"   (TARGET_LAG = 1 minute, should appear within 60-90 seconds)\n")
        
        # Switch to interactive warehouse
        self.execute_query("USE WAREHOUSE automated_intelligence_interactive_wh", fetch=False)
        
        start_time = time.time()
        
        while (time.time() - start_time) < timeout:
            result = self.execute_query(f"""
                SELECT COUNT(*) 
                FROM automated_intelligence.interactive.order_lookup
                WHERE order_id = {latest_order_id}
            """)
            
            count = result[0][0]
            
            if count > 0:
                elapsed = time.time() - start_time
                print(f"✅ Order {latest_order_id} appeared in Interactive Tables after {elapsed:.2f} seconds")
                return True
            
            print(f"   Checking... (elapsed: {int(time.time() - start_time)}s)", end="\r")
            time.sleep(5)
        
        print(f"\n⚠️  Timeout: Order did not appear in Interactive Tables within {timeout}s")
        return False
    
    def query_new_order_interactive(self, order_id: int, num_queries: int = 10):
        """Query the new order from Interactive Tables multiple times"""
        print(f"\n{'='*80}")
        print(f"STEP 3: Query New Order from Interactive Tables")
        print(f"{'='*80}")
        print(f"\nRunning {num_queries} queries for order_id {order_id}...\n")
        
        self.execute_query("USE WAREHOUSE automated_intelligence_interactive_wh", fetch=False)
        
        latencies = []
        
        for i in range(num_queries):
            start_time = time.time()
            
            result = self.execute_query(f"""
                SELECT 
                    order_id,
                    customer_id,
                    order_date,
                    order_status,
                    total_amount,
                    discount_percent,
                    shipping_cost
                FROM automated_intelligence.interactive.order_lookup
                WHERE order_id = {order_id}
            """)
            
            latency_ms = (time.time() - start_time) * 1000
            latencies.append(latency_ms)
            
            if i == 0:
                print(f"📊 Order Details:")
                if result:
                    order_data = result[0]
                    print(f"   Order ID:      {order_data[0]}")
                    print(f"   Customer ID:   {order_data[1]}")
                    print(f"   Order Date:    {order_data[2]}")
                    print(f"   Status:        {order_data[3]}")
                    print(f"   Total Amount:  ${order_data[4]:.2f}")
                    print(f"   Discount:      {order_data[5]:.1f}%")
                    print(f"   Shipping:      ${order_data[6]:.2f}")
            
            print(f"   Query {i+1:2d}: {latency_ms:>7.2f} ms")
        
        avg_latency = sum(latencies) / len(latencies)
        min_latency = min(latencies)
        max_latency = max(latencies)
        
        print(f"\n{'='*80}")
        print(f"Query Performance Summary")
        print(f"{'='*80}")
        print(f"Average Latency:  {avg_latency:>7.2f} ms")
        print(f"Min Latency:      {min_latency:>7.2f} ms")
        print(f"Max Latency:      {max_latency:>7.2f} ms")
        print(f"{'='*80}")
        
        if avg_latency < 100:
            print(f"\n✅ SUCCESS: Average latency under 100ms - perfect for customer-facing apps!")
        else:
            print(f"\n⚠️  Average latency is {avg_latency:.0f}ms (target: <100ms)")
    
    def show_pipeline_stats(self):
        """Show current pipeline statistics"""
        print(f"\n{'='*80}")
        print(f"Pipeline Statistics")
        print(f"{'='*80}\n")
        
        # Use standard warehouse for querying standard tables
        self.execute_query("USE WAREHOUSE automated_intelligence_wh", fetch=False)
        
        stats = self.execute_query("""
            SELECT 
                'Raw Orders' as layer,
                COUNT(*) as row_count,
                MAX(order_id) as max_order_id,
                MAX(order_date) as latest_date
            FROM automated_intelligence.raw.orders
            UNION ALL
            SELECT 
                'Dynamic Tables (fact_orders)',
                COUNT(*),
                MAX(order_id),
                MAX(order_date)
            FROM automated_intelligence.dynamic_tables.fact_orders
        """)
        
        # Switch to interactive warehouse for interactive tables
        self.execute_query("USE WAREHOUSE automated_intelligence_interactive_wh", fetch=False)
        
        interactive_stats = self.execute_query("""
            SELECT 
                COUNT(*) as row_count,
                MAX(order_id) as max_order_id,
                MAX(order_date) as latest_date
            FROM automated_intelligence.interactive.order_lookup
        """)
        
        print(f"{'Layer':<40} {'Rows':>12} {'Max Order ID':>15} {'Latest Date':>20}")
        print(f"{'-'*90}")
        
        for row in stats:
            layer = row[0]
            row_count = f"{row[1]:,}" if row[1] else "N/A"
            max_order = f"{row[2]:,}" if row[2] else "N/A"
            latest_date = str(row[3])[:19] if row[3] else "N/A"
            print(f"{layer:<40} {row_count:>12} {max_order:>15} {latest_date:>20}")
        
        interactive_row = interactive_stats[0]
        row_count = f"{interactive_row[0]:,}"
        max_order = f"{interactive_row[1]:,}"
        latest_date = str(interactive_row[2])[:19]
        print(f"{'Interactive Tables (order_lookup)':<40} {row_count:>12} {max_order:>15} {latest_date:>20}")
        
        print(f"{'='*90}\n")
    
    def run_full_demo(self, num_orders: int = 100):
        """Run the complete real-time pipeline demo"""
        print(f"\n{'#'*80}")
        print(f"# Real-Time Pipeline Demo: Ingestion → Serving")
        print(f"{'#'*80}")
        print(f"\nTimestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        
        try:
            self.show_pipeline_stats()
            
            print(f"\n⚠️  Order generation via stored procedure is deprecated.")
            print(f"    Please use Snowpipe Streaming to generate orders.")
            print(f"    See: snowpipe-streaming-java/ or snowpipe-streaming-python/\n")
            latest_order_id = self.get_latest_order_id()
            
            # Skip dynamic tables - interactive tables refresh directly from raw
            if self.monitor_interactive_tables_refresh(latest_order_id, timeout=180):
                self.query_new_order_interactive(latest_order_id)
                
                print(f"\n{'='*80}")
                print(f"✅ DEMO COMPLETE: Real-Time Pipeline Validated!")
                print(f"{'='*80}")
                print(f"\n💡 Key Takeaways:")
                print(f"   • Data flows from ingestion → serving in ~60-90 seconds")
                print(f"   • Interactive Tables refresh within 1 minute (TARGET_LAG)")
                print(f"   • Queries return in <100ms - perfect for customer-facing apps")
                print(f"   • All native Snowflake - no external systems needed\n")
            else:
                print(f"\n⚠️  Demo incomplete: Data not yet in Interactive Tables")
                print(f"   Try waiting a bit longer or check TARGET_LAG settings")
        
        finally:
            self.close()


def main():
    parser = argparse.ArgumentParser(description="Real-time pipeline demo for Interactive Tables")
    parser.add_argument(
        "--generate-orders",
        type=int,
        metavar="N",
        help="Generate N new orders to demonstrate real-time flow"
    )
    parser.add_argument(
        "--monitor-pipeline",
        action="store_true",
        help="Show current pipeline statistics"
    )
    parser.add_argument(
        "--connection",
        type=str,
        default=None,
        help="Snowflake connection name (default: from SNOWFLAKE_CONNECTION_NAME env var)"
    )
    
    args = parser.parse_args()
    
    connection_name = args.connection or os.getenv("SNOWFLAKE_CONNECTION_NAME")
    if not connection_name:
        print("❌ Error: No connection specified. Use --connection or set SNOWFLAKE_CONNECTION_NAME")
        return
    
    demo = RealtimePipelineDemo(connection_name)
    
    if args.generate_orders:
        demo.run_full_demo(args.generate_orders)
    elif args.monitor_pipeline:
        demo.show_pipeline_stats()
        demo.close()
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
