# Workload Identity Federation Demo

Authenticate to Snowflake from GitHub Actions **without storing any secrets**.

## How It Works

```
┌─────────────────────┐                      ┌─────────────────────┐
│   GitHub Actions    │  ── OIDC Token ──▶   │     Snowflake       │
│   Workflow Runner   │     (short-lived)    │   SERVICE User      │
└─────────────────────┘                      └─────────────────────┘
         │                                            │
         │ • Issuer: token.actions.githubusercontent.com
         │ • Subject: repo:iamontheinet/automated-intelligence:ref:refs/heads/main
         │ • No secrets stored anywhere!
         ▼                                            ▼
    GitHub vouches                              Snowflake validates
    for the workflow                            and grants access
```

## Why This Matters

| Old Way (Secrets) | New Way (OIDC) |
|-------------------|----------------|
| Store password in GitHub Secrets | No secrets stored |
| Credentials can leak | Nothing to leak |
| Manual rotation required | Tokens auto-expire (10 min) |
| Same creds for all workflows | Each run gets unique token |

## Setup

### 1. Create Snowflake SERVICE User (run as ACCOUNTADMIN)

```sql
-- See: workload-identity/setup.sql
CREATE OR REPLACE USER github_actions_dbt
WORKLOAD_IDENTITY = (
  TYPE = OIDC
  ISSUER = 'https://token.actions.githubusercontent.com'
  SUBJECT = 'repo:iamontheinet/automated-intelligence:ref:refs/heads/main'
)
TYPE = SERVICE
DEFAULT_ROLE = SNOWFLAKE_INTELLIGENCE_ADMIN;

GRANT ROLE SNOWFLAKE_INTELLIGENCE_ADMIN TO USER github_actions_dbt;
```

### 2. Push the workflow file

The workflow is at `.github/workflows/dbt-oidc-demo.yml`

### 3. Run the demo

1. Go to GitHub → Actions → "❄️ Snowflake OIDC Demo (Zero Secrets)"
2. Click "Run workflow"
3. Watch the magic happen!

## 30-Second Demo Script

| Time | Action | Highlight |
|------|--------|-----------|
| 0-5s | GitHub → Settings → Secrets | **"No Snowflake credentials stored!"** |
| 5-10s | Actions → Run workflow | Click the button |
| 10-20s | Watch workflow execute | OIDC token → Snowflake query |
| 20-30s | Show output | **"20K customers, $8M revenue, zero secrets!"** |

## Files

| File | Location | Purpose |
|------|----------|---------|
| `setup.sql` | `workload-identity/` | Snowflake SERVICE user setup |
| `dbt-oidc-demo.yml` | `.github/workflows/` | GitHub Actions workflow |

## Example Output

```
🔐 Connecting to Snowflake via OIDC...
   (Zero secrets stored in this repository!)

✅ Authenticated as: GITHUB_ACTIONS_DBT
✅ Using role: SNOWFLAKE_INTELLIGENCE_ADMIN

==================================================
🎯 LIVE DATA FROM SNOWFLAKE
==================================================
   Customers:     20,505
   Total Revenue: $8,234,567.89
   Avg Revenue:   $401.59
==================================================

✅ GitHub Actions authenticated via OIDC
✅ No passwords, keys, or secrets stored!
✅ Token auto-expires in 10 minutes
```

## Supported Platforms

This demo uses GitHub Actions OIDC. The same pattern works with:

| Platform | Type | Configuration |
|----------|------|---------------|
| GitHub Actions | OIDC | `ISSUER = 'https://token.actions.githubusercontent.com'` |
| AWS (EC2, Lambda, ECS) | AWS | `TYPE = AWS`, `ARN = 'arn:aws:iam::...'` |
| EKS | OIDC | `ISSUER = 'https://oidc.eks.<region>.amazonaws.com/id/<id>'` |
| AKS | OIDC | `ISSUER = 'https://<region>.oic.prod-aks.azure.com/...'` |
| GKE | OIDC | `ISSUER = 'https://container.googleapis.com/v1/projects/...'` |

See `.snowflake/cortex/skills/workload-identity-federation/SKILL.md` for full documentation.

## Known Limitations

### dbt-snowflake

As of January 2026, **dbt-snowflake does not support Workload Identity Federation**. The adapter's `auth_args()` method does not pass `workload_identity_provider` to the Snowflake connector.

**Workarounds:**
- Use Python connector directly (as shown in this demo)
- Use key-pair authentication for dbt CI/CD
- Wait for dbt-snowflake to add WIF support

**What works:**
- ✅ Python `snowflake-connector-python` with `authenticator='WORKLOAD_IDENTITY'`
- ✅ JDBC, Go, .NET, Node.js, ODBC drivers
- ❌ dbt-snowflake (profiles.yml doesn't support `workload_identity_provider`)

## Troubleshooting

**"User not found"**
- Verify the SERVICE user was created
- Check `DESCRIBE USER github_actions_dbt`

**"Invalid OIDC token"**
- Verify ISSUER matches exactly: `https://token.actions.githubusercontent.com`
- Verify SUBJECT matches: `repo:iamontheinet/automated-intelligence:ref:refs/heads/main`
- Check you're on the `main` branch

**"Role not authorized"**
- Ensure role was granted: `GRANT ROLE ... TO USER github_actions_dbt`

**"workload_identity_provider must be set"**
- You're using dbt-snowflake, which doesn't support WIF yet
- Use Python connector directly instead
