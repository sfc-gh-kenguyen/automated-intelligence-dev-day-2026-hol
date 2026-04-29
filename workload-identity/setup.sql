-- ============================================================================
-- GitHub Actions OIDC Setup for Snowflake
-- Run this as ACCOUNTADMIN
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- 1. Create SERVICE user for GitHub Actions (NO PASSWORD!)
CREATE OR REPLACE USER github_actions_dbt
WORKLOAD_IDENTITY = (
  TYPE = OIDC
  ISSUER = 'https://token.actions.githubusercontent.com'
  SUBJECT = 'repo:iamontheinet/automated-intelligence:ref:refs/heads/main'
)
TYPE = SERVICE
DEFAULT_ROLE = SNOWFLAKE_INTELLIGENCE_ADMIN
COMMENT = 'GitHub Actions OIDC authentication - zero secrets stored';

-- 2. Grant the role this user needs
GRANT ROLE SNOWFLAKE_INTELLIGENCE_ADMIN TO USER github_actions_dbt;

-- 3. (Optional) Create authentication policy to restrict to OIDC only
--    Skip this if you just want basic OIDC auth without extra restrictions
-- CREATE OR REPLACE AUTHENTICATION POLICY github_oidc_policy
-- WORKLOAD_IDENTITY_POLICY = (
--   ALLOWED_PROVIDERS = (OIDC)
--   ALLOWED_OIDC_ISSUERS = ('https://token.actions.githubusercontent.com')
-- );
-- ALTER USER github_actions_dbt SET AUTHENTICATION POLICY = github_oidc_policy;

-- 4. Verify setup
DESCRIBE USER github_actions_dbt;
SHOW USER WORKLOAD IDENTITY AUTHENTICATION METHODS FOR USER github_actions_dbt;

-- ============================================================================
-- Demo Script (show this during presentation)
-- ============================================================================
-- 
-- 1. Open GitHub repo → Settings → Secrets and variables → Actions
--    👉 Show: "No Snowflake credentials stored!"
--
-- 2. Go to Actions tab → "❄️ dbt CI (OIDC Demo)" → "Run workflow"
--    👉 Click the button
--
-- 3. Watch the workflow run (~15-20 seconds)
--    👉 Highlight: "🔐 Get OIDC Token (NO SECRETS!)" step
--
-- 4. Show the output:
--    ════════════════════════════════════════
--    🎯 LIVE DATA FROM SNOWFLAKE
--    ════════════════════════════════════════
--       Customers:    20,505
--       Total Revenue: $8,234,567.89
--       Avg Revenue:   $401.59
--    ════════════════════════════════════════
--    ✅ Authenticated via GitHub OIDC
--    ✅ Zero secrets stored in this repository!
--
-- ============================================================================
