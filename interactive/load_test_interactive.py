"""
Interactive Tables Load Testing Script
======================================
Purpose: Demonstrate performance under high concurrency

This script simulates 50-100 concurrent users querying the system to show:
1. Standard warehouse: queuing, variable latency, P95 spikes
2. Interactive warehouse: consistent sub-100ms, no queuing

Usage:
    python load_test_interactive.py --warehouse standard --queries 100 --threads 50
    python load_test_interactive.py --warehouse interactive --queries 100 --threads 50
"""

import argparse
import os
import random
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from typing import List, Literal

import snowflake.connector


@dataclass
class QueryResult:
    query_id: int
    query_type: str
    duration_ms: float
    row_count: int
    success: bool
    error: str = None


class LoadTester:
    def __init__(self, warehouse_type: Literal["standard", "interactive"], connection_name: str):
        self.warehouse_type = warehouse_type
        self.connection_name = connection_name
        
        if warehouse_type == "standard":
            self.warehouse = "automated_intelligence_wh"
            self.schema_prefix = "raw"
        else:
            self.warehouse = "automated_intelligence_interactive_wh"
            self.schema_prefix = "interactive"
    
    def get_connection(self):
        """Create a new connection for each thread"""
        return snowflake.connector.connect(connection_name=self.connection_name)
    
    def execute_query(self, query_id: int, query_type: str, sql: str) -> QueryResult:
        """Execute a single query and measure performance"""
        conn = None
        try:
            conn = self.get_connection()
            cursor = conn.cursor()
            
            cursor.execute(f"USE WAREHOUSE {self.warehouse}")
            
            start_time = time.time()
            cursor.execute(sql)
            results = cursor.fetchall()
            end_time = time.time()
            
            duration_ms = (end_time - start_time) * 1000
            
            cursor.close()
            
            return QueryResult(
                query_id=query_id,
                query_type=query_type,
                duration_ms=duration_ms,
                row_count=len(results),
                success=True
            )
        
        except Exception as e:
            return QueryResult(
                query_id=query_id,
                query_type=query_type,
                duration_ms=-1,
                row_count=0,
                success=False,
                error=str(e)
            )
        
        finally:
            if conn:
                conn.close()
    
    def generate_customer_lookup_query(self) -> str:
        """Generate a random customer lookup query"""
        customer_id = random.randint(1, 20000)
        
        if self.warehouse_type == "standard":
            return f"""
            SELECT 
                customer_id,
                order_id,
                order_date,
                order_status,
                total_amount
            FROM automated_intelligence.raw.orders
            WHERE customer_id = {customer_id}
            ORDER BY order_date DESC
            LIMIT 10
            """
        else:
            return f"""
            SELECT 
                customer_id,
                order_id,
                order_date,
                order_status,
                total_amount
            FROM automated_intelligence.interactive.customer_order_analytics
            WHERE customer_id = {customer_id}
            ORDER BY order_date DESC
            LIMIT 10
            """
    
    def generate_order_lookup_query(self) -> str:
        """Generate a random order lookup query"""
        order_id = random.randint(1, 20000)
        
        if self.warehouse_type == "standard":
            return f"""
            SELECT 
                order_id,
                customer_id,
                order_date,
                order_status,
                total_amount
            FROM automated_intelligence.raw.orders
            WHERE order_id = {order_id}
            """
        else:
            return f"""
            SELECT 
                order_id,
                customer_id,
                order_date,
                order_status,
                total_amount
            FROM automated_intelligence.interactive.order_lookup
            WHERE order_id = {order_id}
            """
    
    def generate_customer_summary_query(self) -> str:
        """Generate a customer summary query"""
        customer_id = random.randint(1, 20000)
        
        if self.warehouse_type == "standard":
            return f"""
            SELECT 
                customer_id,
                COUNT(*) as order_count,
                SUM(total_amount) as total_spent,
                AVG(total_amount) as avg_order
            FROM automated_intelligence.raw.orders
            WHERE customer_id = {customer_id}
            GROUP BY customer_id
            """
        else:
            return f"""
            SELECT 
                customer_id,
                COUNT(*) as order_count,
                SUM(total_amount) as total_spent,
                AVG(total_amount) as avg_order
            FROM automated_intelligence.interactive.customer_order_analytics
            WHERE customer_id = {customer_id}
            GROUP BY customer_id
            """
    
    def run_load_test(self, num_queries: int, num_threads: int) -> List[QueryResult]:
        """Run concurrent load test"""
        results = []
        
        print(f"{self.warehouse_type.upper()} WAREHOUSE - {num_queries} queries @ {num_threads} threads")
        print(f"{'-'*80}")
        
        queries = []
        for i in range(num_queries):
            query_type_choice = random.random()
            if query_type_choice < 0.5:
                query_type = "customer_lookup"
                sql = self.generate_customer_lookup_query()
            elif query_type_choice < 0.8:
                query_type = "order_lookup"
                sql = self.generate_order_lookup_query()
            else:
                query_type = "customer_summary"
                sql = self.generate_customer_summary_query()
            
            queries.append((i + 1, query_type, sql))
        
        start_time = time.time()
        
        with ThreadPoolExecutor(max_workers=num_threads) as executor:
            futures = {
                executor.submit(self.execute_query, query_id, query_type, sql): query_id
                for query_id, query_type, sql in queries
            }
            
            completed = 0
            for future in as_completed(futures):
                result = future.result()
                results.append(result)
                completed += 1
                
                if completed % 25 == 0 or completed == num_queries:
                    print(f"  {completed}/{num_queries}...", end=' ')
        
        total_time = time.time() - start_time
        print(f"\n\nCompleted in {total_time:.1f}s")
        
        return results


def analyze_results(results: List[QueryResult], warehouse_type: str):
    """Analyze and print test results"""
    successful = [r for r in results if r.success]
    failed = [r for r in results if not r.success]
    
    if not successful:
        print("❌ All queries failed!")
        for result in failed[:5]:
            print(f"  Error: {result.error}")
        return
    
    durations = sorted([r.duration_ms for r in successful])
    
    min_latency = durations[0]
    max_latency = durations[-1]
    avg_latency = sum(durations) / len(durations)
    median_latency = durations[len(durations) // 2]
    p95_latency = durations[int(len(durations) * 0.95)]
    p99_latency = durations[int(len(durations) * 0.99)]
    
    print(f"\nRESULTS: {len(successful)}/{len(results)} success | P95: {p95_latency:.2f} ms | Median: {median_latency:.0f}ms | Avg: {avg_latency:.0f}ms")
    print(f"{'-'*80}\n")
    
    if failed:
        print(f"⚠️  {len(failed)} queries failed:")
        for result in failed[:3]:
            print(f"  #{result.query_id}: {result.error}")
        if len(failed) > 3:
            print(f"  ... and {len(failed) - 3} more")


def main():
    parser = argparse.ArgumentParser(description="Load test Interactive vs Standard warehouses")
    parser.add_argument(
        "--warehouse",
        choices=["standard", "interactive"],
        required=True,
        help="Warehouse type to test"
    )
    parser.add_argument(
        "--queries",
        type=int,
        default=100,
        help="Total number of queries to execute (default: 100)"
    )
    parser.add_argument(
        "--threads",
        type=int,
        default=50,
        help="Number of concurrent threads (default: 50)"
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
    
    tester = LoadTester(args.warehouse, connection_name)
    results = tester.run_load_test(args.queries, args.threads)
    analyze_results(results, args.warehouse)


if __name__ == "__main__":
    main()
