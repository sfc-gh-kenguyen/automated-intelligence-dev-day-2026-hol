# dbt Analytics Deployment Guide for Snowflake

This guide outlines deployment best practices for running dbt projects on Snowflake following the official [dbt Projects on Snowflake](https://docs.snowflake.com/en/user-guide/data-engineering/dbt-projects-on-snowflake) documentation.

## Table of Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Deployment Options](#deployment-options)
- [Step-by-Step Deployment](#step-by-step-deployment)
- [Scheduling & Automation](#scheduling--automation)
- [Monitoring](#monitoring)
- [Best Practices](#best-practices)

## Overview

dbt Projects on Snowflake allows you to:
- Create **DBT PROJECT** objects (schema-level Snowflake objects)
- Execute dbt commands directly within Snowflake
- Schedule dbt runs using Snowflake tasks
- Monitor execution with native Snowflake observability

## Prerequisites

### 1. Snowflake Objects
Ensure the following exist:
```sql
-- Database and schemas
USE DATABASE automated_intelligence;
CREATE SCHEMA IF NOT EXISTS dbt_staging;
CREATE SCHEMA IF NOT EXISTS dbt_analytics;

-- Warehouse
CREATE WAREHOUSE IF NOT EXISTS automated_intelligence_wh;
```

### 2. Dependencies Setup
For packages that require external access (e.g., dbt-utils from dbt Package hub):

```sql
-- Create network rule for dbt dependencies
CREATE OR REPLACE NETWORK RULE dbt_network_rule
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = (
    'hub.getdbt.com',
    'codeload.github.com'
  );

-- Create external access integration
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION dbt_ext_access
  ALLOWED_NETWORK_RULES = (dbt_network_rule)
  ENABLED = TRUE;
```

### 3. Enable Logging & Monitoring (Recommended)
```sql
-- Enable observability for the schemas
ALTER SCHEMA automated_intelligence.dbt_staging SET LOG_LEVEL = 'INFO';
ALTER SCHEMA automated_intelligence.dbt_staging SET TRACE_LEVEL = 'ALWAYS';
ALTER SCHEMA automated_intelligence.dbt_staging SET METRIC_LEVEL = 'ALL';

ALTER SCHEMA automated_intelligence.dbt_analytics SET LOG_LEVEL = 'INFO';
ALTER SCHEMA automated_intelligence.dbt_analytics SET TRACE_LEVEL = 'ALWAYS';
ALTER SCHEMA automated_intelligence.dbt_analytics SET METRIC_LEVEL = 'ALL';
```

## Deployment Options

### Option 1: Deploy via Snowflake CLI (Recommended)

The Snowflake CLI provides a streamlined deployment workflow:

```bash
# Install Snowflake CLI (if not already installed)
# See: https://docs.snowflake.com/en/developer-guide/snowflake-cli/index

# Navigate to dbt project directory
cd dbt-analytics

# Deploy the dbt project object
snow dbt deploy automated_intelligence_dbt_project \
  --connection dash-builder-si \
  --force

# Execute dbt deps to install dependencies
snow dbt execute automated_intelligence_dbt_project \
  --connection dash-builder-si \
  --args "deps" \
  --external-access-integration dbt_ext_access

# Run the project
snow dbt execute automated_intelligence_dbt_project \
  --connection dash-builder-si \
  --args "run --target dev"
```

### Option 2: Deploy via SQL Commands

```sql
-- Step 1: Create an internal stage to hold dbt project files
CREATE OR REPLACE STAGE automated_intelligence.dbt_staging.dbt_project_stage;

-- Step 2: Upload files to stage (use SnowSQL or Snowflake CLI)
-- PUT file://dbt-analytics/* @automated_intelligence.dbt_staging.dbt_project_stage AUTO_COMPRESS=FALSE;

-- Step 3: Create the dbt project object
CREATE OR REPLACE DBT PROJECT automated_intelligence.dbt_staging.automated_intelligence_dbt_project
  FROM '@automated_intelligence.dbt_staging.dbt_project_stage'
  DEFAULT_TARGET = 'dev'
  EXTERNAL_ACCESS_INTEGRATIONS = (dbt_ext_access)
  COMMENT = 'Analytical layer with customer, product, and cohort analytics';

-- Step 4: Execute dbt deps
EXECUTE DBT PROJECT automated_intelligence.dbt_staging.automated_intelligence_dbt_project
  ARGS = 'deps'
  EXTERNAL_ACCESS_INTEGRATIONS = (dbt_ext_access);

-- Step 5: Run the project
EXECUTE DBT PROJECT automated_intelligence.dbt_staging.automated_intelligence_dbt_project
  ARGS = 'run --target dev';
```

### Option 3: Deploy via Snowsight Workspace

1. Create a Git-connected workspace:
   - Navigate to **Projects** > **Workspaces** in Snowsight
   - Create workspace from Git repository
   - Configure API integration and secrets (for private repos)

2. In the workspace:
   - Open your dbt project folder
   - Select **Connect** > **Deploy dbt project**
   - Choose database and schema
   - Enter project name: `automated_intelligence_dbt_project`
   - Select external access integration: `dbt_ext_access`
   - Click **Deploy**

3. Run commands from the workspace:
   - Select **Profile**: `dev` or `prod`
   - Run **Deps** command first
   - Run **Build** or **Run** command

## Step-by-Step Deployment

### Step 1: Install Dependencies

**Important:** Always run `dbt deps` before executing any other dbt commands.

Using Snowflake CLI:
```bash
snow dbt execute automated_intelligence_dbt_project \
  --connection dash-builder-si \
  --args "deps" \
  --external-access-integration dbt_ext_access
```

Using SQL:
```sql
EXECUTE DBT PROJECT automated_intelligence.staging.automated_intelligence_dbt_project
  ARGS = 'deps'
  EXTERNAL_ACCESS_INTEGRATIONS = (dbt_ext_access);
```

### Step 2: Compile and Validate

```bash
# Using CLI
snow dbt execute automated_intelligence_dbt_project \
  --connection dash-builder-si \
  --args "compile --target dev"
```

```sql
-- Using SQL
EXECUTE DBT PROJECT automated_intelligence.staging.automated_intelligence_dbt_project
  ARGS = 'compile --target dev';
```

### Step 3: Run Tests (Optional but Recommended)

```bash
snow dbt execute automated_intelligence_dbt_project \
  --connection dash-builder-si \
  --args "test --target dev"
```

### Step 4: Build or Run Models

```bash
# Build all models and tests
snow dbt execute automated_intelligence_dbt_project \
  --connection dash-builder-si \
  --args "build --target dev"

# Or just run models (no tests)
snow dbt execute automated_intelligence_dbt_project \
  --connection dash-builder-si \
  --args "run --target dev"
```

### Step 5: Verify Results

```sql
-- Check created tables
SHOW TABLES IN SCHEMA automated_intelligence.dbt_analytics;

-- Query results
SELECT * FROM automated_intelligence.dbt_analytics.customer_segmentation LIMIT 10;
SELECT * FROM automated_intelligence.dbt_analytics.customer_lifetime_value LIMIT 10;
SELECT * FROM automated_intelligence.dbt_analytics.product_recommendations LIMIT 10;
```

## Scheduling & Automation

### Create a Snowflake Task to Run dbt Daily

```sql
-- Create a task to run the dbt project daily at 2 AM
CREATE OR REPLACE TASK automated_intelligence.dbt_staging.dbt_daily_refresh
  WAREHOUSE = automated_intelligence_wh
  SCHEDULE = 'USING CRON 0 2 * * * America/Los_Angeles'
AS
  EXECUTE DBT PROJECT automated_intelligence.dbt_staging.automated_intelligence_dbt_project
    ARGS = 'run --target prod';

-- Start the task
ALTER TASK automated_intelligence.dbt_staging.dbt_daily_refresh RESUME;

-- Check task status
SHOW TASKS LIKE 'dbt_daily_refresh' IN SCHEMA automated_intelligence.dbt_staging;

-- View task execution history
SELECT *
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
  TASK_NAME => 'dbt_daily_refresh',
  SCHEDULED_TIME_RANGE_START => DATEADD(day, -7, CURRENT_TIMESTAMP())
))
ORDER BY SCHEDULED_TIME DESC;
```

### Advanced Task: Incremental Refresh with Dependencies

```sql
-- Task 1: Run dbt deps (if packages.yml changes)
CREATE OR REPLACE TASK automated_intelligence.dbt_staging.dbt_deps_task
  WAREHOUSE = automated_intelligence_wh
  SCHEDULE = 'USING CRON 0 1 * * * America/Los_Angeles'
AS
  EXECUTE DBT PROJECT automated_intelligence.dbt_staging.automated_intelligence_dbt_project
    ARGS = 'deps'
    EXTERNAL_ACCESS_INTEGRATIONS = (dbt_ext_access);

-- Task 2: Run dbt models (depends on deps task)
CREATE OR REPLACE TASK automated_intelligence.dbt_staging.dbt_run_task
  WAREHOUSE = automated_intelligence_wh
  AFTER automated_intelligence.dbt_staging.dbt_deps_task
AS
  EXECUTE DBT PROJECT automated_intelligence.dbt_staging.automated_intelligence_dbt_project
    ARGS = 'run --target prod';

-- Task 3: Run dbt tests (depends on run task)
CREATE OR REPLACE TASK automated_intelligence.dbt_staging.dbt_test_task
  WAREHOUSE = automated_intelligence_wh
  AFTER automated_intelligence.dbt_staging.dbt_run_task
AS
  EXECUTE DBT PROJECT automated_intelligence.dbt_staging.automated_intelligence_dbt_project
    ARGS = 'test --target prod';

-- Resume all tasks (in order)
ALTER TASK automated_intelligence.dbt_staging.dbt_deps_task RESUME;
ALTER TASK automated_intelligence.dbt_staging.dbt_run_task RESUME;
ALTER TASK automated_intelligence.dbt_staging.dbt_test_task RESUME;
```

## Monitoring

### View dbt Project Execution History

```sql
-- View recent dbt project runs
SELECT 
  project_name,
  execution_id,
  state,
  error_message,
  start_time,
  end_time,
  DATEDIFF(second, start_time, end_time) AS duration_seconds
FROM TABLE(INFORMATION_SCHEMA.DBT_PROJECT_EXECUTION_HISTORY(
  PROJECT_NAME => 'automated_intelligence_dbt_project',
  TIME_RANGE_START => DATEADD(day, -7, CURRENT_TIMESTAMP())
))
ORDER BY start_time DESC;
```

### View Logs and Traces

```sql
-- View event logs
SELECT 
  timestamp,
  record_type,
  record_attributes,
  value
FROM automated_intelligence.INFORMATION_SCHEMA.EVENT_TABLE
WHERE scope['name'] = 'automated_intelligence_dbt_project'
  AND timestamp > DATEADD(day, -1, CURRENT_TIMESTAMP())
ORDER BY timestamp DESC
LIMIT 100;
```

### View Model-Level Metrics

```sql
-- Query dbt artifacts for model-level details
-- (Available after executing dbt with proper logging enabled)
SELECT 
  model_name,
  status,
  execution_time,
  rows_affected
FROM <dbt_run_results_table>
WHERE run_id IN (
  SELECT MAX(execution_id) 
  FROM TABLE(INFORMATION_SCHEMA.DBT_PROJECT_EXECUTION_HISTORY())
);
```

## Best Practices

### 1. profiles.yml Configuration
✅ **Do:**
- Set `account: 'not needed'` and `user: 'not needed'` for Snowflake-native execution
- Use the current session's role, warehouse, database, and schema
- Define multiple targets (`dev`, `prod`) for different environments

❌ **Don't:**
- Don't hardcode account names or usernames (unnecessary in Snowflake)
- Don't store passwords or secrets in `profiles.yml`

### 2. Schema Design
✅ **Do:**
- Use separate schemas for staging (`staging`) and production (`analytics`)
- Materialize staging models as **views** (lightweight)
- Materialize marts as **tables** (optimized for queries)
- Use schema customization for organizing models

### 3. Dependencies
✅ **Do:**
- Always run `dbt deps` before deploying or running models
- Use `EXTERNAL_ACCESS_INTEGRATIONS` for external package downloads
- Lock package versions in `packages.yml`

### 4. Versioning
✅ **Do:**
- Each deployment creates a new version (`VERSION$1`, `VERSION$2`, etc.)
- Use `ALTER DBT PROJECT ... ADD VERSION` to update existing projects
- Reference specific versions: `snow://dbt/<db>.<schema>.<project>/versions/VERSION$2`

### 5. CI/CD Integration
✅ **Do:**
- Use `snow dbt deploy` in CI/CD pipelines
- Automate deployment on Git merges to main branch
- Run `dbt test` in CI before merging
- Use separate dbt project objects for dev/staging/prod

### 6. Performance
✅ **Do:**
- Use appropriate warehouse sizes for different environments
- Enable incremental models for large tables
- Add clustering keys to large analytical tables
- Monitor query performance and adjust accordingly

### 7. Security
✅ **Do:**
- Use role-based access control (RBAC) for dbt project objects
- Grant minimal necessary privileges to roles
- Use separate service accounts for production deployments
- Enable logging and tracing for audit trails

## Troubleshooting

### Issue: "dbt deps failed"
**Solution:** Ensure `EXTERNAL_ACCESS_INTEGRATIONS` is specified and network rules allow access to `hub.getdbt.com` and `codeload.github.com`.

### Issue: "Target schema does not exist"
**Solution:** Create the target schema before deploying:
```sql
CREATE SCHEMA IF NOT EXISTS automated_intelligence.dbt_analytics;
```

### Issue: "Version conflict"
**Solution:** Use `--force` flag with `snow dbt deploy` to recreate the project:
```bash
snow dbt deploy automated_intelligence_dbt_project --force
```

### Issue: "Insufficient privileges"
**Solution:** Ensure the role has necessary privileges:
```sql
GRANT USAGE ON DATABASE automated_intelligence TO ROLE snowflake_intelligence_admin;
GRANT USAGE ON SCHEMA automated_intelligence.dbt_staging TO ROLE snowflake_intelligence_admin;
GRANT CREATE TABLE ON SCHEMA automated_intelligence.dbt_analytics TO ROLE snowflake_intelligence_admin;
GRANT USAGE ON WAREHOUSE automated_intelligence_wh TO ROLE snowflake_intelligence_admin;
```

## Resources

- [dbt Projects on Snowflake Documentation](https://docs.snowflake.com/en/user-guide/data-engineering/dbt-projects-on-snowflake)
- [Snowflake CLI dbt Commands](https://docs.snowflake.com/en/developer-guide/snowflake-cli/command-reference/dbt-commands/overview)
- [dbt Core Documentation](https://docs.getdbt.com/)
- [Tutorial: Getting Started with dbt on Snowflake](https://docs.snowflake.com/en/user-guide/tutorials/dbt-projects-on-snowflake-getting-started-tutorial)
