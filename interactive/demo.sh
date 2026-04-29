#!/usr/bin/env bash
#
# Interactive Tables Demo Script
# ===============================
# Interactive demo for Snowflake Interactive Tables performance testing
#
# Usage:
#   ./demo.sh
#
# What this demonstrates:
#   • High-Concurrency Performance: Shows how warehouses handle many simultaneous queries
#   • Interactive warehouses maintain <100ms latency even with 100+ concurrent users
#   • Standard warehouses slow down under load (queuing, variable latency)
#   • Expected: 10-20x performance improvement (Standard P95: 1-2s vs Interactive P95: 80-120ms)
#

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONNECTION="${SNOWFLAKE_CONNECTION_NAME:-dash-builder-si}"

# Detect Python command
if command -v python &> /dev/null; then
    PYTHON_CMD=python
elif command -v python3 &> /dev/null; then
    PYTHON_CMD=python3
else
    echo "❌ Error: Python not found. Please install Python 3."
    exit 1
fi

# Default values (will prompt user if not set)
NUM_ORDERS=50
NUM_THREADS=150
NUM_QUERIES=100
WAREHOUSE_TYPE="both"
SKIP_REALTIME=true
SKIP_LOADTEST=false

# Check if running in non-interactive mode (all parameters provided via command line)
NON_INTERACTIVE=false
if [[ $# -gt 0 ]]; then
    NON_INTERACTIVE=true
fi

# Parse command line arguments (these override defaults)
while [[ $# -gt 0 ]]; do
    case $1 in
        --orders)
            NUM_ORDERS="$2"
            shift 2
            ;;
        --threads)
            NUM_THREADS="$2"
            shift 2
            ;;
        --warehouse)
            WAREHOUSE_TYPE="$2"
            if [[ ! "$WAREHOUSE_TYPE" =~ ^(standard|interactive|both)$ ]]; then
                echo "Error: --warehouse must be 'standard', 'interactive', or 'both'"
                exit 1
            fi
            shift 2
            ;;
        --enable-realtime)
            SKIP_REALTIME=false
            shift
            ;;
        --skip-loadtest)
            SKIP_LOADTEST=true
            shift
            ;;
        -h|--help)
            echo "Interactive Tables Demo Script"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "By default, this runs an interactive demo where you'll be prompted for parameters."
            echo "Or you can provide command line arguments to run non-interactively."
            echo ""
            echo "Options:"
            echo "  --orders N           Number of orders to generate (default: 50, only if --enable-realtime)"
            echo "  --threads N          Concurrent users to simulate (default: 150)"
            echo "  --warehouse TYPE     Test 'standard', 'interactive', or 'both' (default: both)"
            echo "  --enable-realtime    Enable real-time pipeline demo (disabled by default)"
            echo "  --skip-loadtest      Skip load testing demo"
            echo "  -h, --help           Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                                    # Interactive mode - prompts for input"
            echo "  $0 --threads 150                      # Non-interactive with custom threads"
            echo "  $0 --warehouse interactive            # Test only interactive warehouse"
            echo "  $0 --enable-realtime --orders 100     # Include real-time demo"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Interactive prompts (only if not running in non-interactive mode)
if [[ "$NON_INTERACTIVE" == false ]]; then
    echo "################################################################################"
    echo "# Interactive Tables Performance Demo"
    echo "################################################################################"
    echo ""
    echo "This demo shows how Interactive Tables handle high-concurrency workloads."
    echo ""
    
    # Prompt for threads
    read -p "Number of concurrent threads (default: $NUM_THREADS): " input_threads
    if [[ -n "$input_threads" ]]; then
        NUM_THREADS="$input_threads"
    fi
    
    # Prompt for warehouse type
    echo ""
    echo "Which warehouse to test?"
    echo "  1) Both (standard and interactive) - recommended"
    echo "  2) Interactive only"
    echo "  3) Standard only"
    read -p "Choice (default: 1): " warehouse_choice
    case $warehouse_choice in
        2) WAREHOUSE_TYPE="interactive" ;;
        3) WAREHOUSE_TYPE="standard" ;;
        *) WAREHOUSE_TYPE="both" ;;
    esac
    
    # Prompt for real-time demo
    echo ""
    read -p "Include real-time pipeline demo? (shows TARGET_LAG refresh) [y/N]: " -n 1 -r realtime_choice
    echo
    if [[ $realtime_choice =~ ^[Yy]$ ]]; then
        SKIP_REALTIME=false
        read -p "Number of orders to generate (default: $NUM_ORDERS): " input_orders
        if [[ -n "$input_orders" ]]; then
            NUM_ORDERS="$input_orders"
        fi
    fi
    
    echo ""
fi

# Check if skipping both demos
if [[ "$SKIP_REALTIME" == true && "$SKIP_LOADTEST" == true ]]; then
    echo "Error: Cannot skip both demos"
    exit 1
fi

# Detect Python command
if command -v python &> /dev/null; then
    PYTHON_CMD=python
elif command -v python3 &> /dev/null; then
    PYTHON_CMD=python3
else
    echo "❌ Error: Python not found"
    exit 1
fi

# Check Python dependencies
$PYTHON_CMD -c "import snowflake.connector" 2>/dev/null || {
    echo "❌ Error: snowflake-connector-python not installed"
    echo "Run: pip install snowflake-connector-python"
    exit 1
}

# Display banner
if [[ "$NON_INTERACTIVE" == true ]]; then
    echo ""
    echo "################################################################################"
    echo "#                                                                              #"
    echo "#          Interactive Tables Demo                                            #"
    echo "#          High-Concurrency Performance Testing                               #"
    echo "#                                                                              #"
    echo "################################################################################"
    echo ""
    echo "Connection: $CONNECTION"
    echo ""
    echo "Demo Configuration:"
    echo "  • Concurrent users: $NUM_THREADS"
    echo "  • Warehouse(s) to test: $WAREHOUSE_TYPE"
    
    if [[ "$SKIP_REALTIME" == false ]]; then
        echo "  • Orders to generate: $NUM_ORDERS (includes ~4 order items each)"
        echo "  • Real-time demo: ENABLED"
    fi
    
    if [[ "$SKIP_LOADTEST" == false ]]; then
        echo "  • Load testing: ENABLED"
    fi
    
    echo ""
    read -p "Press Enter to start the demo..."
fi

# ============================================================================
# PART 1: Real-Time Pipeline Demo (Optional)
# ============================================================================
if [[ "$SKIP_REALTIME" == false ]]; then
    echo ""
    echo "################################################################################"
    echo "# PART 1: Real-Time Pipeline Demo"
    echo "################################################################################"
    echo ""
    echo "What this test does:"
    echo "  • Generate new orders in Snowflake (via stored procedure)"
    echo "  • Watch them appear in Interactive Tables (based on TARGET_LAG setting)"
    echo "  • Query the new data with <100ms latency"
    echo "  • Current TARGET_LAG: 1 minute (configurable)"
    echo ""
    
    if [[ "$NON_INTERACTIVE" == false ]]; then
        read -p "Generate $NUM_ORDERS new orders and watch the pipeline? [Y/n]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            echo "Skipping real-time demo..."
            SKIP_REALTIME=true
        fi
    fi
    
    if [[ "$SKIP_REALTIME" == false ]]; then
        SNOWFLAKE_CONNECTION_NAME="$CONNECTION" $PYTHON_CMD "$SCRIPT_DIR/realtime_demo.py" --generate-orders $NUM_ORDERS
    fi
    
    echo ""
    if [[ "$SKIP_LOADTEST" == false ]]; then
        read -p "Press Enter to continue to load testing..."
    fi
fi

# ============================================================================
# PART 2: Concurrent Load Testing (Main Demo)
# ============================================================================
if [[ "$SKIP_LOADTEST" == false ]]; then
    echo ""
    echo "################################################################################"
    echo "# High-Concurrency Performance Testing"
    echo "################################################################################"
    echo ""
    echo "What this test does:"
    echo "  • Simulate concurrent users querying simultaneously (like a busy website)"
    echo "  • Compare standard vs interactive warehouse performance"
    echo "  • Measure query latency under high concurrency"
    echo ""
    echo "Current configuration for testing:"
    echo "  • Total queries: $NUM_QUERIES"
    echo "  • Concurrent threads: $NUM_THREADS"
    echo "  • Warehouse(s) to test: $WAREHOUSE_TYPE"
    echo ""
    
    # Display example queries
    echo "Example queries that will be executed:"
    echo "--------------------------------------------------------------------------------"
    echo ""
    echo "CUSTOMER_LOOKUP (50% of queries):"
    echo "  SELECT customer_id, order_id, order_date, order_status, total_amount"
    echo "  FROM [table] WHERE customer_id = <random_id>"
    echo "  ORDER BY order_date DESC LIMIT 10"
    echo ""
    echo "ORDER_LOOKUP (30% of queries):"
    echo "  SELECT order_id, customer_id, order_date, order_status, total_amount"
    echo "  FROM [table] WHERE order_id = <random_id>"
    echo ""
    echo "CUSTOMER_SUMMARY (20% of queries):"
    echo "  SELECT customer_id, COUNT(*), SUM(total_amount), AVG(total_amount)"
    echo "  FROM [table] WHERE customer_id = <random_id>"
    echo "  GROUP BY customer_id"
    echo ""
    echo "Tables used:"
    if [[ "$WAREHOUSE_TYPE" == "standard" ]]; then
        echo "  • automated_intelligence.raw.orders"
    elif [[ "$WAREHOUSE_TYPE" == "interactive" ]]; then
        echo "  • automated_intelligence.interactive.customer_order_analytics"
        echo "  • automated_intelligence.interactive.order_lookup"
    else
        echo "  • Standard: automated_intelligence.raw.orders"
        echo "  • Interactive: automated_intelligence.interactive.{customer_order_analytics, order_lookup}"
    fi
    echo "--------------------------------------------------------------------------------"
    echo ""
    
    # Variables to capture results
    STANDARD_P95=""
    INTERACTIVE_P95=""
    STANDARD_COMPLETE=0
    INTERACTIVE_COMPLETE=0
    
    # Clear cache for best results (suspend standard warehouse)
    if [[ "$WAREHOUSE_TYPE" == "standard" || "$WAREHOUSE_TYPE" == "both" ]]; then
        echo ""
        echo "🔄 Clearing cache (suspending standard warehouse)..."
        SNOWFLAKE_CONNECTION_NAME="$CONNECTION" snow sql -q "ALTER WAREHOUSE automated_intelligence_wh SUSPEND" >/dev/null 2>&1 || true
        sleep 2
        echo ""
    fi
    
    # Test standard warehouse
    if [[ "$WAREHOUSE_TYPE" == "standard" || "$WAREHOUSE_TYPE" == "both" ]]; then
        STANDARD_OUTPUT=$(SNOWFLAKE_CONNECTION_NAME="$CONNECTION" $PYTHON_CMD "$SCRIPT_DIR/load_test_interactive.py" \
            --warehouse standard \
            --queries $NUM_QUERIES \
            --threads $NUM_THREADS 2>&1)
        
        echo "$STANDARD_OUTPUT"
        
        # Extract P95 latency from output (format: "P95: 1807.89 ms")
        STANDARD_P95=$(echo "$STANDARD_OUTPUT" | grep "P95:" | sed -n 's/.*P95: \([0-9.]*\) ms.*/\1 ms/p')
        
        STANDARD_COMPLETE=1
    fi
    
    # Test interactive warehouse
    if [[ "$WAREHOUSE_TYPE" == "interactive" || "$WAREHOUSE_TYPE" == "both" ]]; then
        INTERACTIVE_OUTPUT=$(SNOWFLAKE_CONNECTION_NAME="$CONNECTION" $PYTHON_CMD "$SCRIPT_DIR/load_test_interactive.py" \
            --warehouse interactive \
            --queries $NUM_QUERIES \
            --threads $NUM_THREADS 2>&1)
        
        echo "$INTERACTIVE_OUTPUT"
        
        # Extract P95 latency from output (format: "P95: 318.21 ms")
        INTERACTIVE_P95=$(echo "$INTERACTIVE_OUTPUT" | grep "P95:" | sed -n 's/.*P95: \([0-9.]*\) ms.*/\1 ms/p')
        
        INTERACTIVE_COMPLETE=1
    fi
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "================================================================================"

if [[ $STANDARD_COMPLETE -eq 1 && $INTERACTIVE_COMPLETE -eq 1 ]]; then
    echo "COMPARISON"
    echo "================================================================================"
    echo "Standard P95:     $STANDARD_P95"
    echo "Interactive P95:  $INTERACTIVE_P95"
    
    # Calculate improvement if possible
    if [[ -n "$STANDARD_P95" && -n "$INTERACTIVE_P95" ]]; then
        STANDARD_VAL=$(echo "$STANDARD_P95" | awk '{print $1}')
        INTERACTIVE_VAL=$(echo "$INTERACTIVE_P95" | awk '{print $1}')
        
        if [[ -n "$STANDARD_VAL" && -n "$INTERACTIVE_VAL" ]] && command -v bc &> /dev/null; then
            IMPROVEMENT=$(echo "scale=1; $STANDARD_VAL / $INTERACTIVE_VAL" | bc 2>/dev/null || echo "N/A")
            if [[ "$IMPROVEMENT" != "N/A" ]]; then
                echo ""
                echo "🚀 Performance: ${IMPROVEMENT}x faster"
            fi
        fi
    fi
elif [[ $STANDARD_COMPLETE -eq 1 ]]; then
    echo "RESULTS"
    echo "================================================================================"
    echo "Standard warehouse P95: $STANDARD_P95"
elif [[ $INTERACTIVE_COMPLETE -eq 1 ]]; then
    echo "RESULTS"
    echo "================================================================================"
    echo "Interactive warehouse P95: $INTERACTIVE_P95"
fi

echo "================================================================================"
echo ""
