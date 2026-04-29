#!/usr/bin/env python3
"""
Export sampled demo data from the live AUTOMATED_INTELLIGENCE database.

Connects to Snowflake using the cortex CLI connection config and exports
a consistent sample of data suitable for running all 7 demo prompts.

Sampling strategy:
  - 5,000 customers (random sample from 500K)
  - All orders for those customers (~90K)
  - All order_items for those orders (~450K)
  - All product_catalog (10 rows)
  - All product_reviews (395 rows)
  - All support_tickets (500 rows)
  - CLV + segmentation for those customers (derived dbt tables)

Usage:
  python3 setup/02_export_data.py [--connection CONNECTION_NAME] [--sample-size N]

Requirements:
  pip install snowflake-connector-python
"""

import argparse
import csv
import os
import subprocess
import json
import sys
from pathlib import Path

DATA_DIR = Path(__file__).parent / "data"

# Tables to export with their queries
# Order matters: customers first (defines the sample), then dependents
SAMPLE_SIZE = 5000


def get_connection_params(connection_name: str) -> dict:
    """Get Snowflake connection parameters from cortex CLI config."""
    try:
        result = subprocess.run(
            ["cortex", "connections", "list"],
            capture_output=True, text=True, check=True
        )
        connections = json.loads(result.stdout)
        for conn in connections:
            if conn.get("name") == connection_name:
                return conn
        raise ValueError(f"Connection '{connection_name}' not found")
    except (subprocess.CalledProcessError, json.JSONDecodeError):
        # Fallback: try snowsql config or environment variables
        print(f"Could not read cortex CLI config. Trying snowflake-connector defaults...")
        return {"connection_name": connection_name}


def connect_snowflake(connection_name: str):
    """Connect to Snowflake using the named connection."""
    import snowflake.connector
    try:
        # Try using the connection name directly (snowflake-connector-python >= 3.0)
        conn = snowflake.connector.connect(connection_name=connection_name)
        print(f"Connected via connection: {connection_name}")
        return conn
    except Exception as e:
        print(f"Error connecting: {e}")
        print("Make sure snowflake-connector-python is installed and the connection is configured.")
        sys.exit(1)


def export_query_to_csv(cursor, query: str, filepath: Path, description: str) -> int:
    """Execute a query and write results to CSV. Returns row count."""
    print(f"  Exporting {description}...", end=" ", flush=True)
    cursor.execute(query)
    columns = [desc[0] for desc in cursor.description]

    row_count = 0
    with open(filepath, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(columns)
        while True:
            rows = cursor.fetchmany(10000)
            if not rows:
                break
            writer.writerow(row) if len(rows) == 1 else [writer.writerow(r) for r in rows]
            row_count += len(rows)

    size_mb = filepath.stat().st_size / (1024 * 1024)
    print(f"{row_count:,} rows ({size_mb:.1f} MB)")
    return row_count


def main():
    parser = argparse.ArgumentParser(description="Export sampled demo data from AUTOMATED_INTELLIGENCE")
    parser.add_argument("--connection", default="dash-builder-si",
                        help="Snowflake connection name (default: dash-builder-si)")
    parser.add_argument("--sample-size", type=int, default=SAMPLE_SIZE,
                        help=f"Number of customers to sample (default: {SAMPLE_SIZE})")
    args = parser.parse_args()

    # Create output directory
    DATA_DIR.mkdir(parents=True, exist_ok=True)

    conn = connect_snowflake(args.connection)
    cur = conn.cursor()

    print(f"\nExporting demo data (sample size: {args.sample_size:,} customers)")
    print(f"Output directory: {DATA_DIR}\n")

    # Set context
    cur.execute("USE DATABASE AUTOMATED_INTELLIGENCE")
    cur.execute("USE SCHEMA RAW")
    cur.execute("USE WAREHOUSE AUTOMATED_INTELLIGENCE_WH")

    # Step 1: Create a temp table with sampled customer IDs for consistency
    print("Step 1: Sampling customers...")
    cur.execute(f"""
        CREATE OR REPLACE TEMPORARY TABLE DEMO_SAMPLE_CUSTOMERS AS
        SELECT CUSTOMER_ID
        FROM RAW.CUSTOMERS
        SAMPLE ({args.sample_size} ROWS)
    """)
    actual_sample = cur.execute("SELECT COUNT(*) FROM DEMO_SAMPLE_CUSTOMERS").fetchone()[0]
    print(f"  Sampled {actual_sample:,} customers\n")

    # Step 2: Export tables
    print("Step 2: Exporting tables...")

    exports = [
        (
            "customers",
            """SELECT c.* FROM RAW.CUSTOMERS c
               INNER JOIN DEMO_SAMPLE_CUSTOMERS s ON c.CUSTOMER_ID = s.CUSTOMER_ID
               ORDER BY c.CUSTOMER_ID""",
            "customers"
        ),
        (
            "orders",
            """SELECT o.* FROM RAW.ORDERS o
               INNER JOIN DEMO_SAMPLE_CUSTOMERS s ON o.CUSTOMER_ID = s.CUSTOMER_ID
               ORDER BY o.ORDER_DATE""",
            "orders (for sampled customers)"
        ),
        (
            "order_items",
            """SELECT oi.* FROM RAW.ORDER_ITEMS oi
               INNER JOIN RAW.ORDERS o ON oi.ORDER_ID = o.ORDER_ID
               INNER JOIN DEMO_SAMPLE_CUSTOMERS s ON o.CUSTOMER_ID = s.CUSTOMER_ID
               ORDER BY oi.ORDER_ID, oi.ORDER_ITEM_ID""",
            "order_items (for sampled orders)"
        ),
        (
            "product_catalog",
            "SELECT * FROM RAW.PRODUCT_CATALOG ORDER BY PRODUCT_ID",
            "product_catalog (all)"
        ),
        (
            "product_reviews",
            "SELECT * FROM RAW.PRODUCT_REVIEWS ORDER BY REVIEW_ID",
            "product_reviews (all)"
        ),
        (
            "customer_lifetime_value",
            """SELECT clv.* FROM DBT_ANALYTICS.CUSTOMER_LIFETIME_VALUE clv
               INNER JOIN DEMO_SAMPLE_CUSTOMERS s ON clv.CUSTOMER_ID = s.CUSTOMER_ID
               ORDER BY clv.CUSTOMER_ID""",
            "customer_lifetime_value (dbt, for sampled customers)"
        ),
    ]

    totals = {}
    for filename, query, description in exports:
        filepath = DATA_DIR / f"{filename}.csv"
        count = export_query_to_csv(cur, query, filepath, description)
        totals[filename] = count

    # Cleanup
    cur.execute("DROP TABLE IF EXISTS DEMO_SAMPLE_CUSTOMERS")
    cur.close()
    conn.close()

    # Summary
    print("\n" + "=" * 60)
    print("Export complete!")
    print("=" * 60)
    total_rows = sum(totals.values())
    total_size = sum((DATA_DIR / f"{name}.csv").stat().st_size for name in totals) / (1024 * 1024)
    print(f"\nTotal: {total_rows:,} rows across {len(totals)} files ({total_size:.1f} MB)")
    print(f"\nFiles written to: {DATA_DIR}/")
    for name, count in totals.items():
        print(f"  {name}.csv: {count:,} rows")

    print(f"\nNext step: Run setup/03_load_data.sql to load this data into Snowflake.")


if __name__ == "__main__":
    main()
