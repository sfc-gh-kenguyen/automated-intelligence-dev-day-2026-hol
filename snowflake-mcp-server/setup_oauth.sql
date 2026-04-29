/*
=============================================================================
OAUTH SECURITY INTEGRATION FOR MCP SERVER
=============================================================================
Creates OAuth security integration for MCP client authentication.

Usage:
  snow sql -c <connection-name> -f setup_oauth.sql
=============================================================================
*/

USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE SECURITY INTEGRATION AUTOMATED_INTELLIGENCE_MCP_OAUTH
  TYPE = OAUTH
  OAUTH_CLIENT = CUSTOM
  ENABLED = TRUE
  OAUTH_CLIENT_TYPE = 'CONFIDENTIAL'
  OAUTH_REDIRECT_URI = 'http://localhost:8080/callback';

SELECT SYSTEM$SHOW_OAUTH_CLIENT_SECRETS('AUTOMATED_INTELLIGENCE_MCP_OAUTH');
