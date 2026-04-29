# Snowflake Managed MCP Server

Exposes Snowflake Cortex services, ML models, and SQL execution as tools for external AI agents via the Model Context Protocol (MCP).

## Tools Exposed

| Tool | Type | Description |
|------|------|-------------|
| `product-reviews-search` | Cortex Search | Semantic search over product reviews |
| `support-tickets-search` | Cortex Search | Semantic search over support tickets |
| `business-insights` | Cortex Analyst | Natural language queries for business metrics |
| `product-recommendations` | Stored Procedure | ML-powered recommendations by customer segment |
| `execute-sql` | SQL Execution | Ad-hoc SQL queries |
| `business-agent` | Cortex Agent | Routes to Business Insights Agent for complex queries |

## Setup

```bash
# 1. Create MCP server
snow sql -c <connection-name> -f setup_mcp_server.sql

# 2. Configure access control
snow sql -c <connection-name> -f setup_access_control.sql

# 3. (Optional) Setup OAuth for client authentication
snow sql -c <connection-name> -f setup_oauth.sql
```

## MCP Client Endpoint

```
https://<account_url>/api/v2/databases/AUTOMATED_INTELLIGENCE/schemas/SEMANTIC/mcp-servers/AI_GATEWAY
```

## Example: Tool Discovery

```json
POST /api/v2/databases/AUTOMATED_INTELLIGENCE/schemas/SEMANTIC/mcp-servers/AI_GATEWAY
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/list"
}
```

## Example: Search Product Reviews

```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/call",
  "params": {
    "name": "product-reviews-search",
    "arguments": {
      "query": "quality issues with boots",
      "limit": 5
    }
  }
}
```

## Example: Business Insights Query

```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "tools/call",
  "params": {
    "name": "business-insights",
    "arguments": {
      "message": "What is our total revenue by customer segment?"
    }
  }
}
```

## Example: Product Recommendations

```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "method": "tools/call",
  "params": {
    "name": "product-recommendations",
    "arguments": {
      "num_customers": 3,
      "num_products": 5,
      "segment": "LOW_ENGAGEMENT"
    }
  }
}
```

## Tool Types Reference

Snowflake MCP servers support these tool types (as of April 2026):

| Type | Purpose | Requires |
|------|---------|----------|
| `CORTEX_SEARCH_SERVICE_QUERY` | Semantic/keyword search over unstructured data | Cortex Search Service |
| `CORTEX_ANALYST_MESSAGE` | Natural language to SQL via semantic views | Semantic View (not YAML models) |
| `CORTEX_AGENT_RUN` | Route to a Cortex Agent for multi-tool orchestration | Cortex Agent object |
| `SYSTEM_EXECUTE_SQL` | Execute ad-hoc SQL queries | None (built-in) |
| `GENERIC` | Call custom UDFs or stored procedures as tools | UDF/SP + warehouse + input_schema |

### Example: Agent Tool

```yaml
tools:
  - name: "business-agent"
    type: "CORTEX_AGENT_RUN"
    identifier: "AUTOMATED_INTELLIGENCE.SEMANTIC.BUSINESS_INSIGHTS_AGENT"
    description: "Routes complex business questions to the Business Insights Agent"
    title: "Business Agent"
```

### Example: Custom Stored Procedure Tool

```yaml
tools:
  - name: "product-recommendations"
    type: "GENERIC"
    identifier: "AUTOMATED_INTELLIGENCE.RAW.GET_PRODUCT_RECOMMENDATIONS"
    description: "ML-powered product recommendations by customer segment"
    title: "Product Recommendations"
    config:
      type: "procedure"
      warehouse: "AUTOMATED_INTELLIGENCE_WH"
      input_schema:
        type: "object"
        properties:
          segment:
            description: "Customer segment (Premium, Standard, Basic)"
            type: "string"
          num_products:
            description: "Number of products to recommend"
            type: "number"
```

## Security

- RBAC applies to MCP server and individual tools
- Row access policies still filter data (e.g., WEST_COAST_MANAGER sees regional data only)
- OAuth recommended for production client authentication

## Client Setup

Snowflake's MCP server uses Streamable HTTP transport with PAT (Programmatic Access Token) authentication. Most MCP clients attempt OAuth dynamic client registration first, which Snowflake doesn't support. The workaround is to use `mcp-remote` as a stdio-to-HTTP bridge.

### Prerequisites

- A Snowflake PAT stored in the `PAT_SI` environment variable
- Node.js / npm installed (for `npx mcp-remote`)

### Cursor

Add to `~/.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "snowflake-ai-gateway": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-remote@latest",
        "https://<account_url>/api/v2/databases/AUTOMATED_INTELLIGENCE/schemas/SEMANTIC/mcp-servers/AI_GATEWAY",
        "--header",
        "Authorization: Bearer ${PAT_SI}",
        "--header",
        "X-Snowflake-Authorization-Token-Type: PROGRAMMATIC_ACCESS_TOKEN"
      ]
    }
  }
}
```

Launch Cursor from the terminal so it inherits `PAT_SI` from your shell environment.

### Claude Desktop

Add to `~/.claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "snowflake-ai-gateway": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-remote@latest",
        "https://<account_url>/api/v2/databases/AUTOMATED_INTELLIGENCE/schemas/SEMANTIC/mcp-servers/AI_GATEWAY",
        "--header",
        "Authorization: Bearer ${PAT_SI}",
        "--header",
        "X-Snowflake-Authorization-Token-Type: PROGRAMMATIC_ACCESS_TOKEN"
      ]
    }
  }
}
```

### curl (Direct Testing)

```bash
curl -s -X POST "https://<account_url>/api/v2/databases/AUTOMATED_INTELLIGENCE/schemas/SEMANTIC/mcp-servers/AI_GATEWAY" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $PAT_SI" \
  -H "X-Snowflake-Authorization-Token-Type: PROGRAMMATIC_ACCESS_TOKEN" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

### VS Code (Not Yet Working)

VS Code 1.112 with GitHub Copilot does not reliably discover HTTP-type MCP servers from `.vscode/mcp.json`. Tested configurations that failed: workspace `mcp.json`, `settings.json` with `"mcp"` key, user-level `mcp.json`, and the "MCP: Add Server" command. This may be resolved in a future VS Code update.

## Cleanup

```bash
snow sql -c <connection-name> -f cleanup.sql
```

## References

- [Snowflake MCP Server Docs](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-mcp)
- [MCP Quickstart](https://quickstarts.snowflake.com/guide/getting-started-with-snowflake-mcp-server/index.html)
