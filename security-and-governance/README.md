# West Coast Manager - Region-Based RBAC Demo

Perfect demo for showcasing **Row-Based Access Control** with Snowflake Intelligence agents!

## The Setup

**Two Roles, Dramatically Different Views:**

| Role | States Visible | Revenue | Customers |
|------|---------------|---------|-----------|
| **AUTOMATED_INTELLIGENCE** | All 10 states (BC, CA, CO, ID, MT, NV, OR, UT, WA, WY) | $733M | 20,200 |
| **WEST_COAST_MANAGER** | Only 3 states (CA, OR, WA) | $224M | 6,115 |

**Key Insight:** Same Business Insights Agent, dramatically different answers!

## Files

| File | Description |
|------|-------------|
| `setup_west_coast_manager.sql` | Creates role and row access policy |
| `demo_west_coast_manager.ipynb` | Interactive demo notebook |
| `cleanup_west_coast_manager.sql` | Removes all demo artifacts |
| `README.md` | This file |

## Quick Start

### 1. Setup

```bash
snow sql -f setup_west_coast_manager.sql -c dash-builder-si
```

This creates:
- `west_coast_manager` role
- Row access policy on CUSTOMERS table (filters by state)
- Grants for agent access

### 2. Grant Role to Your User

```sql
GRANT ROLE west_coast_manager TO USER <your_username>;
```

### 3. Test with Notebook

```bash
jupyter notebook demo_west_coast_manager.ipynb
```

Shows side-by-side comparison of what each role sees.

### 4. Demo with Snowflake Intelligence (The Big Demo!)

Open **Snowflake Intelligence** in two browser tabs/windows:

**Tab 1 (Admin):**
```
Use role: AUTOMATED_INTELLIGENCE
Ask: "What's our total revenue?"
Result: ~$733M (all 10 states)
```

**Tab 2 (West Coast):**
```
Use role: WEST_COAST_MANAGER
Ask: "What's our total revenue?"
Result: ~$224M (CA, OR, WA only)
```

**🎯 Same question → Completely different answer → Perfect RBAC demo!**

### 5. Cleanup

```bash
snow sql -f cleanup_west_coast_manager.sql -c dash-builder-si
```

## Demo Script for Live Presentation

### Question 1: Total Revenue
```
Ask both roles: "What's our total revenue?"

Admin sees: $733M (100%)
West Coast sees: $224M (31%) ← 69% hidden!
```

### Question 2: Revenue by State
```
Ask both roles: "Show me revenue by state"

Admin sees: 10 states in chart
West Coast sees: 3 states only (CA, OR, WA)
```

### Question 3: Customer Count
```
Ask both roles: "How many customers do we have?"

Admin sees: 20,200 customers
West Coast sees: 6,115 customers
```

### Question 4: Top Performing States
```
Ask both roles: "What are our top 3 states by revenue?"

Admin sees: NV ($76M), OR ($75M), CA ($75M)
West Coast sees: OR ($75M), CA ($75M), WA ($73M)
           (Doesn't even know NV exists!)
```

## Why This Demo Works So Well

✅ **Realistic Business Scenario**: Regional managers are common in enterprise companies

✅ **Dramatic Difference**: 31% vs 100% is impossible to miss

✅ **Same Agent Code**: No changes to agent - security is transparent

✅ **Easy to Explain**: "West Coast Manager only sees their region" - everyone gets it

✅ **Works with Natural Language**: Demo works perfectly with conversational queries

✅ **Visual Impact**: Charts show completely different data for same question

## Technical Details

### Row Access Policy

```sql
CREATE OR REPLACE ROW ACCESS POLICY customers_region_policy
AS (state VARCHAR) RETURNS BOOLEAN ->
    CASE 
        WHEN CURRENT_ROLE() IN ('AUTOMATED_INTELLIGENCE', 'ACCOUNTADMIN') 
            THEN TRUE
        WHEN CURRENT_ROLE() = 'WEST_COAST_MANAGER' 
             AND state IN ('CA', 'OR', 'WA') 
            THEN TRUE
        ELSE FALSE
    END;
```

### How It Works

1. Policy is applied to CUSTOMERS table on the STATE column
2. When ORDERS joins to CUSTOMERS, the filter cascades
3. West Coast Manager queries automatically filter to CA/OR/WA
4. Other 7 states are completely invisible (not just masked - actually filtered out)
5. Works across ALL queries - JOINs, aggregations, agent queries, everything

### Data Distribution

```
All 10 States (Admin View):
├── NV: $76M (10.4%)
├── OR: $75M (10.3%)
├── CA: $75M (10.2%)
├── CO: $74M (10.1%)
├── UT: $73M (10.0%)
├── WA: $73M (10.0%)
├── WY: $73M (9.9%)
├── MT: $72M (9.9%)
├── BC: $72M (9.9%)
└── ID: $72M (9.8%)
Total: $733M

West Coast (Filtered View):
├── OR: $75M (33.6%)
├── CA: $75M (33.5%)
└── WA: $73M (32.9%)
Total: $224M (31% of all revenue)
```

## Example Queries

### As Admin (Sees Everything)

```sql
USE ROLE snowflake_intelligence_admin;

SELECT 
    c.state,
    COUNT(DISTINCT o.order_id) as orders,
    ROUND(SUM(o.total_amount), 2) as revenue
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
GROUP BY c.state
ORDER BY revenue DESC;

-- Returns 10 rows (all states)
```

### As West Coast Manager (Filtered)

```sql
USE ROLE west_coast_manager;

SELECT 
    c.state,
    COUNT(DISTINCT o.order_id) as orders,
    ROUND(SUM(o.total_amount), 2) as revenue
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
GROUP BY c.state
ORDER BY revenue DESC;

-- Returns 3 rows (CA, OR, WA only)
-- Doesn't see: BC, CO, ID, MT, NV, UT, WY
```

## Business Use Cases

This pattern applies to:

1. **Multi-Region Sales Organizations**: Regional VPs see only their territory
2. **Franchise Models**: Franchisees see only their locations
3. **Multi-Brand Companies**: Brand managers see only their brand data
4. **Compliance Requirements**: Data residency and privacy regulations
5. **Partner Networks**: Partners see only their referred customers
6. **Audit & Finance**: Different audit teams see different cost centers

## Agent Integration Benefits

🎯 **No Agent Changes**: Same agent serves all roles with different data views

🎯 **Transparent to Users**: West Coast Manager doesn't know other regions exist

🎯 **Natural Language Works**: "Show me revenue" automatically filtered

🎯 **Chart Generation**: Agent-generated charts show filtered data automatically

🎯 **Historical Queries**: Time-based queries respect regional filtering

🎯 **Audit Trail**: All queries logged with role/user for compliance

## Troubleshooting

### Issue: West Coast Manager sees all states
```sql
-- Check if policy is applied
SHOW ROW ACCESS POLICIES IN SCHEMA raw;

-- Verify policy is on customers table
SELECT * FROM TABLE(
    INFORMATION_SCHEMA.POLICY_REFERENCES(
        POLICY_NAME => 'AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS_REGION_POLICY'
    )
);

-- Test as west_coast_manager
USE ROLE west_coast_manager;
SELECT DISTINCT state FROM customers ORDER BY state;
-- Should only show: CA, OR, WA
```

### Issue: Agent not respecting filtering
```sql
-- Verify west_coast_manager has access to semantic view
USE ROLE west_coast_manager;
SELECT COUNT(*) FROM automated_intelligence.dynamic_tables.business_insights_semantic_view;

-- This should work but return filtered results when joined with customers
```

### Issue: Revenue numbers don't match
```sql
-- Compare direct query vs agent results
-- Admin should see ~$733M
-- West Coast should see ~$224M

USE ROLE snowflake_intelligence_admin;
SELECT SUM(total_amount) FROM orders o 
JOIN customers c ON o.customer_id = c.customer_id;

USE ROLE west_coast_manager;
SELECT SUM(total_amount) FROM orders o 
JOIN customers c ON o.customer_id = c.customer_id;
```

## Extending the Demo

### Add More Regions

```sql
-- Create Mountain Region Manager (CO, ID, MT, UT, WY)
CREATE ROLE mountain_region_manager;

CREATE OR REPLACE ROW ACCESS POLICY customers_region_policy
AS (state VARCHAR) RETURNS BOOLEAN ->
    CASE 
        WHEN CURRENT_ROLE() IN ('AUTOMATED_INTELLIGENCE', 'ACCOUNTADMIN') 
            THEN TRUE
        WHEN CURRENT_ROLE() = 'WEST_COAST_MANAGER' 
             AND state IN ('CA', 'OR', 'WA') THEN TRUE
        WHEN CURRENT_ROLE() = 'MOUNTAIN_REGION_MANAGER'
             AND state IN ('CO', 'ID', 'MT', 'UT', 'WY') THEN TRUE
        ELSE FALSE
    END;
```

### Add Time-Based Filtering

```sql
-- Limit west coast to last 90 days
CREATE OR REPLACE ROW ACCESS POLICY customers_region_time_policy
AS (state VARCHAR, order_date DATE) RETURNS BOOLEAN ->
    CASE 
        WHEN CURRENT_ROLE() IN ('AUTOMATED_INTELLIGENCE', 'ACCOUNTADMIN') 
            THEN TRUE
        WHEN CURRENT_ROLE() = 'WEST_COAST_MANAGER' 
             AND state IN ('CA', 'OR', 'WA')
             AND order_date >= DATEADD(day, -90, CURRENT_DATE()) 
            THEN TRUE
        ELSE FALSE
    END;
```

## Performance Notes

- Row access policies add minimal overhead (single predicate filter)
- Snowflake optimizes policy evaluation at query time
- Indexes on STATE column improve filter performance
- Policy is evaluated once per query, not per row

## Next Steps

After demonstrating region-based RBAC, consider:

1. **Column Masking**: Mask PII like email/phone for certain roles
2. **Dynamic Policies**: Use mapping tables for flexible region assignments
3. **Role Hierarchy**: Use `IS_ROLE_IN_SESSION()` for inherited permissions
4. **Multi-Dimensional**: Combine region + time + department filtering

## Resources

- [Snowflake Row Access Policies](https://docs.snowflake.com/en/user-guide/security-row-intro)
- [Snowflake Intelligence](https://docs.snowflake.com/en/user-guide/snowflake-intelligence)
- [Access Control Best Practices](https://docs.snowflake.com/en/user-guide/security-access-control-considerations)
