#!/bin/bash
# Helper script to connect to Snowflake Postgres using postgres_config.json

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_FILE="$SCRIPT_DIR/postgres_config.json"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: postgres_config.json not found at $CONFIG_FILE"
    exit 1
fi

# Extract connection details using Python (more portable than jq)
read -r HOST PORT DATABASE USER PASSWORD <<< $(python3 -c "
import json
with open('$CONFIG_FILE') as f:
    config = json.load(f)
print(config['host'], config['port'], config['database'], config['user'], config['password'])
")

# Build connection string
CONNECTION_STRING="postgresql://${USER}:${PASSWORD}@${HOST}:${PORT}/${DATABASE}?sslmode=require"

# If arguments are provided, pass them to psql, otherwise open interactive session
if [ $# -eq 0 ]; then
    echo "Connecting to Snowflake Postgres..."
    psql "$CONNECTION_STRING"
else
    psql "$CONNECTION_STRING" "$@"
fi
