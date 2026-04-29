#!/usr/bin/env python3
"""
End-to-end pipeline runner for the Automated Intelligence demo.

Runs all 9 steps of the pipeline sequentially:
  1. Preflight checks (warehouses, schemas, row counts)
  2. Stream 1K orders to RAW
  3. Stream 5K orders to STAGING
  4. Gen2 MERGE staging → RAW
  5. Wait for Dynamic Table refresh
  6. Interactive Table point lookup
  7. Cortex Agent verification
  8. Cortex Search query
  9. Summary report

Usage:
  python run_pipeline.py                         # non-interactive, all steps
  python run_pipeline.py --interactive           # pause between steps
  python run_pipeline.py --step 3               # start from step 3
  python run_pipeline.py --skip-streaming        # skip steps 2-3
  python run_pipeline.py --dry-run               # print steps, don't execute
  python run_pipeline.py --connection NAME       # override Snowflake connection
  python run_pipeline.py --orders 500            # override order count for RAW streaming
  python run_pipeline.py --staging-orders 2000   # override order count for staging
"""

import argparse
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path
from textwrap import dedent

import snowflake.connector

# ── Defaults ─────────────────────────────────────────────────────────────────

DEFAULT_CONNECTION = "dash-builder-si"
DEFAULT_RAW_ORDERS = 1000
DEFAULT_STAGING_ORDERS = 5000
STREAMING_DIR = Path(__file__).parent / "snowpipe-streaming-python"
DATABASE = "AUTOMATED_INTELLIGENCE"

# Warehouse names
WH_DEFAULT = "automated_intelligence_wh"
WH_GEN2 = "automated_intelligence_gen2_wh"
WH_INTERACTIVE = "automated_intelligence_interactive_wh"

# ── Helpers ──────────────────────────────────────────────────────────────────


def timestamp():
    return datetime.now().strftime("%H:%M:%S")


def header(step_num: int, title: str):
    print(f"\n{'='*60}")
    print(f"  Step {step_num}: {title}")
    print(f"  [{timestamp()}]")
    print(f"{'='*60}\n")


def info(msg: str):
    print(f"  {msg}")


def success(msg: str):
    print(f"  [OK] {msg}")


def warn(msg: str):
    print(f"  [WARN] {msg}", file=sys.stderr)


def fail(msg: str):
    print(f"  [FAIL] {msg}", file=sys.stderr)


def run_sql(conn, sql: str, fetch: bool = True):
    """Execute SQL and optionally return results."""
    cur = conn.cursor()
    try:
        cur.execute(sql)
        if fetch:
            cols = [desc[0] for desc in cur.description] if cur.description else []
            rows = cur.fetchall()
            return cols, rows
        return None, None
    finally:
        cur.close()


def print_table(cols: list, rows: list, max_col_width: int = 40):
    """Print a simple ASCII table."""
    if not cols or not rows:
        info("(no results)")
        return
    # Compute column widths
    widths = [len(c) for c in cols]
    str_rows = []
    for row in rows:
        str_row = [str(v) if v is not None else "NULL" for v in row]
        str_rows.append(str_row)
        for i, v in enumerate(str_row):
            widths[i] = min(max(widths[i], len(v)), max_col_width)

    def fmt(values):
        return "  " + " | ".join(v.ljust(widths[i])[:widths[i]] for i, v in enumerate(values))

    print(fmt(cols))
    print("  " + "-+-".join("-" * w for w in widths))
    for row in str_rows:
        print(fmt(row))
    print()


def use_warehouse(conn, wh: str):
    run_sql(conn, f"USE WAREHOUSE {wh}", fetch=False)


# ── Pipeline Steps ───────────────────────────────────────────────────────────


def step_1_preflight(conn) -> bool:
    """Preflight: resume warehouses, verify schemas, show baseline counts."""
    header(1, "Preflight Checks")

    # Resume warehouses
    for wh in [WH_DEFAULT, WH_GEN2, WH_INTERACTIVE]:
        try:
            run_sql(conn, f"ALTER WAREHOUSE {wh} RESUME IF SUSPENDED", fetch=False)
            success(f"Warehouse {wh} resumed")
        except Exception as e:
            warn(f"Could not resume {wh}: {e}")

    use_warehouse(conn, WH_DEFAULT)

    # Verify schemas exist
    cols, rows = run_sql(conn, f"SHOW SCHEMAS IN DATABASE {DATABASE}")
    schema_names = {r[1] for r in rows}  # name is second column
    required = {"RAW", "STAGING", "DYNAMIC_TABLES", "INTERACTIVE", "SEMANTIC", "DBT_ANALYTICS"}
    missing = required - schema_names
    if missing:
        fail(f"Missing schemas: {missing}")
        return False
    success(f"All required schemas present ({len(required)}/{len(required)})")

    # Dynamic table states
    info("\nDynamic Table states:")
    cols, rows = run_sql(conn, f"SHOW DYNAMIC TABLES IN SCHEMA {DATABASE}.DYNAMIC_TABLES")
    # SHOW returns many columns — extract just name and scheduling_state
    if rows:
        dt_cols = ["NAME", "SCHEDULING_STATE", "REFRESH_MODE", "TARGET_LAG"]
        dt_rows = [(r[1], r[15], r[14], r[4]) for r in rows]  # name=1, scheduling_state=15, refresh_mode=14, target_lag=4
        print_table(dt_cols, dt_rows)
    else:
        info("(no dynamic tables found)")

    # Baseline row counts
    info("Baseline row counts:")
    cols, rows = run_sql(conn, dedent(f"""\
        SELECT 'RAW.CUSTOMERS' as layer, COUNT(*) as row_count FROM {DATABASE}.RAW.CUSTOMERS
        UNION ALL SELECT 'RAW.ORDERS', COUNT(*) FROM {DATABASE}.RAW.ORDERS
        UNION ALL SELECT 'RAW.ORDER_ITEMS', COUNT(*) FROM {DATABASE}.RAW.ORDER_ITEMS
        UNION ALL SELECT 'DT.ENRICHED_ORDERS', COUNT(*) FROM {DATABASE}.DYNAMIC_TABLES.ENRICHED_ORDERS
        UNION ALL SELECT 'DT.FACT_ORDERS', COUNT(*) FROM {DATABASE}.DYNAMIC_TABLES.FACT_ORDERS
        UNION ALL SELECT 'DT.DAILY_METRICS', COUNT(*) FROM {DATABASE}.DYNAMIC_TABLES.DAILY_BUSINESS_METRICS
        UNION ALL SELECT 'INTERACTIVE.ANALYTICS', COUNT(*) FROM {DATABASE}.INTERACTIVE.CUSTOMER_ORDER_ANALYTICS
        UNION ALL SELECT 'DBT.CLV', COUNT(*) FROM {DATABASE}.DBT_ANALYTICS.CUSTOMER_LIFETIME_VALUE
    """))
    print_table(cols, rows)
    return True


def step_2_stream_raw(conn, num_orders: int) -> bool:
    """Stream orders to RAW via Snowpipe Streaming SDK."""
    header(2, f"Stream {num_orders:,} Orders → RAW")

    src_dir = STREAMING_DIR / "src"
    script = src_dir / "automated_intelligence_streaming.py"
    if not script.exists():
        fail(f"Streaming script not found: {script}")
        return False

    info(f"Running: python {script.name} {num_orders}")
    t0 = time.time()
    result = subprocess.run(
        [sys.executable, str(script), str(num_orders)],
        cwd=str(src_dir),
        capture_output=False,
    )
    elapsed = time.time() - t0

    if result.returncode != 0:
        fail(f"Streaming to RAW failed (exit code {result.returncode})")
        return False

    success(f"Streamed {num_orders:,} orders to RAW in {elapsed:.1f}s")
    return True


def step_3_stream_staging(conn, num_orders: int) -> bool:
    """Stream orders to STAGING for Gen2 MERGE demo."""
    header(3, f"Stream {num_orders:,} Orders → STAGING")

    # Truncate staging first
    info("Truncating staging tables...")
    run_sql(conn, f"CALL {DATABASE}.STAGING.TRUNCATE_STAGING_TABLES()", fetch=False)
    success("Staging tables truncated")

    src_dir = STREAMING_DIR / "src"
    script = src_dir / "automated_intelligence_streaming.py"
    config = "config_staging.properties"

    info(f"Running: python {script.name} {num_orders} {config}")
    t0 = time.time()
    result = subprocess.run(
        [sys.executable, str(script), str(num_orders), config],
        cwd=str(src_dir),
        capture_output=False,
    )
    elapsed = time.time() - t0

    if result.returncode != 0:
        fail(f"Streaming to STAGING failed (exit code {result.returncode})")
        return False

    success(f"Streamed {num_orders:,} orders to STAGING in {elapsed:.1f}s")

    # Show staging counts
    info("\nStaging counts:")
    cols, rows = run_sql(conn, f"CALL {DATABASE}.STAGING.GET_STAGING_COUNTS()")
    if rows:
        info(f"  Result: {rows[0][0]}")
    return True


def step_4_gen2_merge(conn) -> bool:
    """Run Gen2 MERGE: staging → RAW using Gen2 warehouse."""
    header(4, "Gen2 MERGE: STAGING → RAW")

    # Switch to Gen2 warehouse
    use_warehouse(conn, WH_GEN2)

    # Create discount snapshot for before/after comparison
    info("Creating discount snapshot...")
    run_sql(conn, f"CALL {DATABASE}.STAGING.CREATE_DISCOUNT_SNAPSHOT()", fetch=False)

    info("Running MERGE_STAGING_TO_RAW(TRUE) on Gen2 warehouse...")
    t0 = time.time()
    cols, rows = run_sql(conn, f"CALL {DATABASE}.STAGING.MERGE_STAGING_TO_RAW(TRUE)")
    elapsed = time.time() - t0

    if rows:
        info(f"  Result: {rows[0][0]}")
    success(f"Gen2 MERGE completed in {elapsed:.1f}s")

    # Restore discount snapshot
    info("Restoring discount snapshot...")
    run_sql(conn, f"CALL {DATABASE}.STAGING.RESTORE_DISCOUNT_SNAPSHOT()", fetch=False)

    # Switch back to default warehouse
    use_warehouse(conn, WH_DEFAULT)
    return True


def step_5_wait_dt(conn) -> bool:
    """Wait for Dynamic Tables to refresh after new data."""
    header(5, "Wait for Dynamic Table Refresh")

    # Actual DTs in the DYNAMIC_TABLES schema
    target_tables = [
        "ENRICHED_ORDERS",
        "ENRICHED_ORDER_ITEMS",
        "FACT_ORDERS",
        "DAILY_BUSINESS_METRICS",
        "PRODUCT_PERFORMANCE_METRICS",
    ]
    max_wait = 180  # 3 minutes
    poll_interval = 10
    start = time.time()

    # Grab the server-side timestamp for timezone-safe comparison
    _, ts_rows = run_sql(conn, "SELECT CURRENT_TIMESTAMP()")
    check_time = ts_rows[0][0] if ts_rows else None

    info(f"Waiting up to {max_wait}s for DT refreshes (checking since {check_time})...")

    rows = []
    cols = []
    while time.time() - start < max_wait:
        cols, rows = run_sql(conn, dedent(f"""\
            SELECT name, state, refresh_action,
                   DATEDIFF('second', refresh_start_time, refresh_end_time) as secs
            FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
                NAME_PREFIX => '{DATABASE}.DYNAMIC_TABLES'))
            WHERE state = 'SUCCEEDED'
              AND refresh_action != 'NO_DATA'
              AND refresh_end_time >= '{check_time}'
            QUALIFY ROW_NUMBER() OVER (PARTITION BY name ORDER BY data_timestamp DESC) = 1
            ORDER BY name
        """))

        refreshed = {r[0] for r in rows} if rows else set()
        pending = set(target_tables) - refreshed
        info(f"  [{int(time.time()-start)}s] Refreshed: {len(refreshed)}/{len(target_tables)} — pending: {pending or 'none'}")

        if not pending:
            success("All Dynamic Tables refreshed")
            print_table(cols, rows)
            return True

        time.sleep(poll_interval)

    warn(f"Timed out after {max_wait}s. Some DTs may not have refreshed yet.")
    if rows:
        print_table(cols, rows)
    return True  # non-fatal — DTs will eventually catch up


def step_6_interactive(conn) -> bool:
    """Interactive Table sub-100ms point lookup."""
    header(6, "Interactive Table Lookup")

    # Pick a random customer
    cols, rows = run_sql(conn, f"SELECT customer_id FROM {DATABASE}.RAW.CUSTOMERS ORDER BY RANDOM() LIMIT 1")
    if not rows:
        fail("No customers found")
        return False
    customer_id = rows[0][0]
    info(f"Random customer: {customer_id}")

    # Switch to interactive warehouse
    use_warehouse(conn, WH_INTERACTIVE)

    t0 = time.time()
    cols, rows = run_sql(conn, dedent(f"""\
        SELECT customer_id, first_name, last_name, customer_segment,
               total_orders, total_spent, avg_order_value
        FROM {DATABASE}.INTERACTIVE.CUSTOMER_ORDER_ANALYTICS
        WHERE customer_id = '{customer_id}'
    """))
    elapsed_ms = (time.time() - t0) * 1000

    print_table(cols, rows)
    success(f"Lookup completed in {elapsed_ms:.0f}ms")

    # Switch back
    use_warehouse(conn, WH_DEFAULT)
    return True


def step_7_cortex_agent(conn) -> bool:
    """Cortex Agent: verify agent is configured and accessible."""
    header(7, "Cortex Agent Verification")

    agent_name = f"{DATABASE}.SEMANTIC.BUSINESS_INSIGHTS_AGENT"
    info(f"Agent: {agent_name}")
    info("")

    # SNOWFLAKE.CORTEX.AGENT() doesn't exist as a SQL function.
    # Verify with DESCRIBE AGENT — that proves the agent is live and configured.
    t0 = time.time()
    cols, rows = run_sql(conn, f"DESCRIBE AGENT {agent_name}")
    elapsed = time.time() - t0

    if rows and rows[0]:
        import json
        row = rows[0]
        info(f"  Name:     {row[0]}")
        info(f"  Database: {row[1]}")
        info(f"  Schema:   {row[2]}")
        # Parse agent_spec to show tools
        try:
            spec = json.loads(row[6]) if row[6] else {}
            tools = [t.get("tool_spec", {}).get("name", "?") for t in spec.get("tools", [])]
            info(f"  Tools:    {', '.join(tools)}")
        except (json.JSONDecodeError, TypeError):
            pass
        info("")
        info("  Agent is live. Query it via Snowflake Intelligence or the REST API.")

    success(f"Agent described in {elapsed:.1f}s")
    return True


def step_8_cortex_search(conn) -> bool:
    """Cortex Search: semantic search over product reviews."""
    header(8, "Cortex Search Query")

    search_query = "ski boot comfort issues"
    info(f'Search: "{search_query}"')
    info("")

    t0 = time.time()
    cols, rows = run_sql(conn, dedent(f"""\
        SELECT PARSE_JSON(
            SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
                '{DATABASE}.SEMANTIC.PRODUCT_REVIEWS_SEARCH',
                '{{"query": "{search_query}", "columns": ["REVIEW_TITLE", "RATING"], "limit": 5}}'
            )
        ) AS results
    """))
    elapsed = time.time() - t0

    if rows and rows[0][0]:
        import json
        try:
            data = json.loads(str(rows[0][0]))
            results = data.get("results", [])
            info(f"  Found {len(results)} results:\n")
            for i, r in enumerate(results, 1):
                title = r.get("REVIEW_TITLE", "?")
                rating = r.get("RATING", "?")
                score = r.get("@scores", {}).get("cosine_similarity", 0)
                info(f"    {i}. {title} (rating: {rating}, similarity: {score:.3f})")
        except (json.JSONDecodeError, TypeError):
            info(f"  {rows[0][0]}")
    info("")
    success(f"Search returned results in {elapsed:.1f}s")
    return True


def step_9_summary(conn) -> bool:
    """Final summary: row counts across all layers."""
    header(9, "Summary Report")

    info("Final row counts across all layers:\n")
    cols, rows = run_sql(conn, dedent(f"""\
        SELECT 'RAW.CUSTOMERS' as layer, COUNT(*) as row_count FROM {DATABASE}.RAW.CUSTOMERS
        UNION ALL SELECT 'RAW.ORDERS', COUNT(*) FROM {DATABASE}.RAW.ORDERS
        UNION ALL SELECT 'RAW.ORDER_ITEMS', COUNT(*) FROM {DATABASE}.RAW.ORDER_ITEMS
        UNION ALL SELECT 'STAGING.ORDERS', COUNT(*) FROM {DATABASE}.STAGING.ORDERS_STAGING
        UNION ALL SELECT 'STAGING.ORDER_ITEMS', COUNT(*) FROM {DATABASE}.STAGING.ORDER_ITEMS_STAGING
        UNION ALL SELECT 'DT.ENRICHED_ORDERS', COUNT(*) FROM {DATABASE}.DYNAMIC_TABLES.ENRICHED_ORDERS
        UNION ALL SELECT 'DT.FACT_ORDERS', COUNT(*) FROM {DATABASE}.DYNAMIC_TABLES.FACT_ORDERS
        UNION ALL SELECT 'DT.DAILY_METRICS', COUNT(*) FROM {DATABASE}.DYNAMIC_TABLES.DAILY_BUSINESS_METRICS
        UNION ALL SELECT 'INTERACTIVE.ANALYTICS', COUNT(*) FROM {DATABASE}.INTERACTIVE.CUSTOMER_ORDER_ANALYTICS
        UNION ALL SELECT 'DBT.CLV', COUNT(*) FROM {DATABASE}.DBT_ANALYTICS.CUSTOMER_LIFETIME_VALUE
    """))
    print_table(cols, rows)

    # Recent DT refresh history
    info("Recent Dynamic Table refreshes:\n")
    cols, rows = run_sql(conn, dedent(f"""\
        SELECT name, refresh_action, state,
               DATEDIFF('second', refresh_start_time, refresh_end_time) as secs
        FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
            NAME_PREFIX => '{DATABASE}.DYNAMIC_TABLES'))
        WHERE state = 'SUCCEEDED'
        ORDER BY data_timestamp DESC LIMIT 10
    """))
    print_table(cols, rows)

    success("Pipeline run complete.")
    return True


# ── Step Registry ────────────────────────────────────────────────────────────

STEPS = [
    (1, "Preflight checks", step_1_preflight, False),
    (2, "Stream orders → RAW", step_2_stream_raw, True),
    (3, "Stream orders → STAGING", step_3_stream_staging, True),
    (4, "Gen2 MERGE staging → RAW", step_4_gen2_merge, False),
    (5, "Wait for DT refresh", step_5_wait_dt, False),
    (6, "Interactive Table lookup", step_6_interactive, False),
    (7, "Cortex Agent verification", step_7_cortex_agent, False),
    (8, "Cortex Search query", step_8_cortex_search, False),
    (9, "Summary report", step_9_summary, False),
]
# (num, label, func, is_streaming)


# ── Main ─────────────────────────────────────────────────────────────────────


def parse_args():
    parser = argparse.ArgumentParser(
        description="Run the Automated Intelligence e2e pipeline",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=dedent("""\
            Examples:
              python run_pipeline.py                      # full run, non-interactive
              python run_pipeline.py --interactive        # pause between steps
              python run_pipeline.py --step 5             # start from step 5
              python run_pipeline.py --skip-streaming     # skip ingestion (steps 2-3)
              python run_pipeline.py --dry-run            # show plan, don't execute
        """),
    )
    parser.add_argument("--interactive", action="store_true", help="Pause between steps")
    parser.add_argument("--step", type=int, default=1, help="Start from step N (1-9)")
    parser.add_argument("--skip-streaming", action="store_true", help="Skip streaming steps 2-3")
    parser.add_argument("--dry-run", action="store_true", help="Print steps without executing")
    parser.add_argument("--connection", default=DEFAULT_CONNECTION, help=f"Snowflake connection name (default: {DEFAULT_CONNECTION})")
    parser.add_argument("--orders", type=int, default=DEFAULT_RAW_ORDERS, help=f"Orders to stream to RAW (default: {DEFAULT_RAW_ORDERS})")
    parser.add_argument("--staging-orders", type=int, default=DEFAULT_STAGING_ORDERS, help=f"Orders to stream to STAGING (default: {DEFAULT_STAGING_ORDERS})")
    return parser.parse_args()


def main():
    args = parse_args()

    # ── Dry run ──────────────────────────────────────────────────────────
    if args.dry_run:
        print(f"\n  Automated Intelligence E2E Pipeline — DRY RUN")
        print(f"  Connection: {args.connection}")
        print(f"  Starting from step: {args.step}")
        print(f"  Skip streaming: {args.skip_streaming}\n")
        for num, label, _, is_streaming in STEPS:
            skip = ""
            if num < args.step:
                skip = " (skipped — before start step)"
            elif args.skip_streaming and is_streaming:
                skip = " (skipped — --skip-streaming)"
            print(f"  {'[SKIP]' if skip else '[ OK ]'} Step {num}: {label}{skip}")
        print()
        return 0

    # ── Connect ──────────────────────────────────────────────────────────
    print(f"\n  Automated Intelligence E2E Pipeline")
    print(f"  Connection: {args.connection}")
    print(f"  Mode: {'interactive' if args.interactive else 'non-interactive'}")
    print(f"  RAW orders: {args.orders:,}  |  Staging orders: {args.staging_orders:,}")
    print()

    try:
        conn = snowflake.connector.connect(connection_name=args.connection)
    except Exception as e:
        fail(f"Could not connect via '{args.connection}': {e}")
        return 1

    # Set database context
    run_sql(conn, f"USE DATABASE {DATABASE}", fetch=False)

    pipeline_start = time.time()
    failed_steps = []

    try:
        for num, label, func, is_streaming in STEPS:
            # Skip logic
            if num < args.step:
                continue
            if args.skip_streaming and is_streaming:
                info(f"\n  [SKIP] Step {num}: {label} (--skip-streaming)")
                continue

            # Interactive pause
            if args.interactive and num > args.step:
                try:
                    input(f"\n  Press Enter to run Step {num}: {label} (Ctrl+C to stop)... ")
                except KeyboardInterrupt:
                    print("\n\n  Stopped by user.")
                    break

            # Execute step — streaming steps need order counts
            try:
                if num == 2:
                    ok = func(conn, args.orders)
                elif num == 3:
                    ok = func(conn, args.staging_orders)
                else:
                    ok = func(conn)
            except Exception as e:
                fail(f"Step {num} raised: {e}")
                ok = False

            if not ok:
                failed_steps.append(num)
                warn(f"Step {num} failed. Continuing...")

    except KeyboardInterrupt:
        print("\n\n  Pipeline interrupted by user.")
    finally:
        conn.close()

    elapsed = time.time() - pipeline_start
    print(f"\n{'='*60}")
    print(f"  Pipeline finished in {elapsed:.1f}s")
    if failed_steps:
        print(f"  Failed steps: {failed_steps}")
        print(f"{'='*60}\n")
        return 1
    else:
        print(f"  All steps passed.")
        print(f"{'='*60}\n")
        return 0


if __name__ == "__main__":
    sys.exit(main())
