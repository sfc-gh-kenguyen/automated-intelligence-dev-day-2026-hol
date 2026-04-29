/*
=============================================================================
CLEANUP MCP SERVER
=============================================================================
Removes MCP server and OAuth integration.

Usage:
  snow sql -c <connection-name> -f cleanup.sql
=============================================================================
*/

USE ROLE ACCOUNTADMIN;

DROP MCP SERVER IF EXISTS AUTOMATED_INTELLIGENCE.SEMANTIC.AI_GATEWAY;

DROP SECURITY INTEGRATION IF EXISTS AUTOMATED_INTELLIGENCE_MCP_OAUTH;
