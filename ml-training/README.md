# Ray ML Training for Customer Churn Prediction

This folder contains a Snowflake Notebook that demonstrates distributed ML model training using **Ray on Snowflake**.

## 📁 Contents

- **`customer_churn_training.ipynb`** - Jupyter notebook for training customer churn prediction model using Ray distributed training

## 🎯 What It Does

This notebook trains an XGBoost classifier to predict customer churn using Ray distributed training on Snowflake:

1. **Ray Cluster**: Initializes and scales Ray cluster to 4 nodes for distributed computing
2. **Data Loading**: Loads customer analytics from Interactive Tables using Snowpark DataFrames
3. **Feature Engineering**: Creates features using Snowpark DataFrame operations
4. **Distributed Training**: Trains XGBoost model with sklearn on Ray cluster (distributed across multiple nodes)
5. **Model Registry**: Saves trained model with preprocessing pipeline to Snowflake Model Registry
6. **Evaluation**: Provides performance metrics (ROC-AUC, confusion matrix, feature importance)

## 🚀 How to Use

### Prerequisites

1. **Snowflake Account** with ML capabilities enabled
2. **Data Setup**: Run the pipeline setup to create `AUTOMATED_INTELLIGENCE.INTERACTIVE.CUSTOMER_ORDER_ANALYTICS` table
3. **Notebook Runtime**: Create a Snowflake Notebook with ML Runtime (CPU or GPU)

### Step 1: Deploy Notebook to Snowflake

```bash
# From the ray-ml-training directory
snow notebook create customer_churn_training \
  --database AUTOMATED_INTELLIGENCE \
  --schema MODELS \
  --file customer_churn_training.ipynb
```

Or use Snowsight UI:
1. Navigate to **Projects > Notebooks**
2. Click **+ Notebook**
3. Select **Import .ipynb file**
4. Upload `customer_churn_training.ipynb`
5. Choose ML Runtime

### Step 2: Run the Notebook

1. Open the notebook in Snowsight
2. Select a warehouse with sufficient compute (Medium or Large recommended)
3. Run all cells sequentially
4. Monitor Ray cluster in the Ray Dashboard (link provided in output)

### Step 3: View Results in Streamlit

After training completes:
1. Navigate to the Streamlit dashboard
2. Click on **🤖 ML Insights** page
3. View model metrics, feature importance, and churn predictions

## 📊 Model Details

### Features Used

| Feature | Description |
|---------|-------------|
| `TOTAL_ORDERS` | Total number of orders placed by customer |
| `TOTAL_SPENT` | Total amount spent by customer |
| `AVG_ORDER_VALUE` | Average order value |
| `CUSTOMER_TENURE_DAYS` | Days between first and last order |
| `order_frequency` | Orders per day (derived) |
| `revenue_per_order` | Total spent divided by total orders (derived) |

**Important:** The model intentionally excludes `days_since_last_order` to prevent data leakage. This feature directly reveals the target variable (churn is defined by days since last order), which would result in artificially perfect performance (ROC-AUC = 1.0) but fail to generalize to real predictions.

**Note:** `tenure_weeks` was removed as it's perfectly correlated with `CUSTOMER_TENURE_DAYS` (tenure_weeks = tenure_days / 7), providing no additional information.

### Churn Definition

A customer is considered **churned** if they haven't ordered in **7+ days**.

**Note:** The 7-day threshold is used for demo purposes to ensure balanced training data with the current dataset. In production environments, this would typically be 30-90 days depending on your business model and customer ordering patterns.

### Model Architecture

- **Algorithm**: XGBoost Classifier (sklearn)
- **Training Framework**: Ray distributed training on Snowflake
- **Features**: 6 customer behavior metrics (frequency, monetary, tenure)
- **Target**: Binary classification (churned vs active)
- **Data Leakage Prevention**: Excludes recency features that directly reveal the target
- **Class Imbalance**: Uses `scale_pos_weight` to handle 27:1 imbalance ratio
- **Processing**: Distributed across Ray cluster nodes

## 🔧 Configuration

### Ray Cluster Scaling

The notebook scales to **4 nodes** (1 head + 3 workers) for demonstration:

```python
scale_cluster(expected_cluster_size=4)
```

For production, adjust based on data size:
- Small datasets (<100K rows): 1-2 nodes
- Medium datasets (100K-1M rows): 4-8 nodes
- Large datasets (>1M rows): 8+ nodes

### Model Hyperparameters

Default XGBoost configuration:

```python
XGBClassifier(
    n_estimators=100,
    max_depth=6,
    learning_rate=0.1,
    eval_metric='logloss'
)
```

Tune these based on your data characteristics and performance requirements.

## 📈 Expected Results

With typical e-commerce data and proper class imbalance handling:

- **ROC-AUC**: 0.90-0.96 (Excellent)
- **Churned Customer Recall**: 80-90% (catches most at-risk customers)
- **Overall Accuracy**: 90-95%
- **Training Time**: Varies by warehouse size and data volume
- **Top Feature**: Customer tenure (90% importance)

**Note:** High ROC-AUC with good recall indicates the model successfully balances precision and recall. Training happens on Ray cluster with distributed processing across multiple nodes.

## 🔄 Workflow Integration

```
┌─────────────────────┐
│  Snowpipe Streaming │
│   (Raw Data)        │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Dynamic Tables     │
│   (Transform)       │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Interactive Tables  │
│  (Aggregated Data)  │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Ray ML Training    │ ◄── YOU ARE HERE
│   (This Notebook)   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Model Registry     │
│  (Versioned Models) │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Streamlit Dashboard │
│   (Visualization)   │
└─────────────────────┘
```

## 🛠️ Troubleshooting

### Issue: Ray cluster won't scale

**Solution**: Check warehouse size and Container Runtime permissions
```sql
-- Verify Container Runtime is enabled
SHOW PARAMETERS LIKE 'ENABLE_CONTAINER_RUNTIME' IN ACCOUNT;

-- Should return: ENABLE_CONTAINER_RUNTIME = true
```

### Issue: Data not loading

**Solution**: Verify table exists and has data
```sql
SELECT COUNT(*) 
FROM AUTOMATED_INTELLIGENCE.INTERACTIVE.CUSTOMER_ORDER_ANALYTICS;

-- Should return > 0 rows
```

### Issue: Model not appearing in registry

**Solution**: Check schema permissions
```sql
-- Ensure MODELS schema exists
CREATE SCHEMA IF NOT EXISTS AUTOMATED_INTELLIGENCE.MODELS;

-- Grant necessary privileges
GRANT USAGE ON SCHEMA AUTOMATED_INTELLIGENCE.MODELS TO ROLE <your_role>;
GRANT CREATE MODEL ON SCHEMA AUTOMATED_INTELLIGENCE.MODELS TO ROLE <your_role>;
```

### Issue: Out of memory errors

**Solution**: 
1. Reduce cluster size (fewer nodes use less memory)
2. Use larger warehouse
3. Sample data for initial testing

## 📚 Learn More

- [Ray on Snowflake Documentation](https://docs.snowflake.com/en/developer-guide/snowflake-ml/scale-application-ray)
- [Snowflake Model Registry](https://docs.snowflake.com/en/developer-guide/snowflake-ml/model-registry)
- [Container Runtime Guide](https://docs.snowflake.com/en/developer-guide/snowflake-ml/container-runtime)
- [Ray Documentation](https://docs.ray.io/)

## 🚀 Deployment: Product Recommendation Stored Procedure

After training the model, deploy it as a stored procedure for easy integration with applications and Cortex Agents.

### Step 4: Deploy Stored Procedure

```bash
# Deploy the stored procedure
snow sql -c dash-builder-si -f product_recommendations_sproc.sql
```

This creates:
- **Procedure**: `AUTOMATED_INTELLIGENCE.MODELS.GET_PRODUCT_RECOMMENDATIONS(N_CUSTOMERS, N_PRODUCTS, SEGMENT)`
- **Returns**: Formatted string with personalized product recommendations
- **Inference**: Uses SPCS service `GPU_XGBOOST_SERVICE!PREDICT_PROBA`

### Usage Examples

```sql
-- Get 3 recommendations for 2 low-engagement customers
CALL AUTOMATED_INTELLIGENCE.MODELS.GET_PRODUCT_RECOMMENDATIONS(2, 3, 'LOW_ENGAGEMENT');

-- Get 5 recommendations for 10 high-value inactive customers
CALL AUTOMATED_INTELLIGENCE.MODELS.GET_PRODUCT_RECOMMENDATIONS(10, 5, 'HIGH_VALUE_INACTIVE');

-- Get recommendations for new customers
CALL AUTOMATED_INTELLIGENCE.MODELS.GET_PRODUCT_RECOMMENDATIONS(5, 3, 'NEW_CUSTOMERS');
```

### Available Customer Segments

| Segment | Description | Use Case |
|---------|-------------|----------|
| `LOW_ENGAGEMENT` | 3-5 orders | Upsell opportunities |
| `HIGH_VALUE_INACTIVE` | High spenders inactive 180+ days | Re-engagement campaigns |
| `NEW_CUSTOMERS` | 1-2 orders | Build loyalty |
| `AT_RISK` | Inactive 180+ days | Churn prevention |
| `HIGH_VALUE_ACTIVE` | Active high spenders ($1000+) | Retention programs |
| `REGULAR` | All other customers | General promotions |

### Output Format

The stored procedure returns a nicely formatted string ideal for Cortex Agents:

```
Product Recommendations for Low Engagement (3-5 orders) Segment
======================================================================

Customer ID: 10045
----------------------------------------------------------------------
  1. Powder Skis (Skis)
     Purchase Probability: 97.1%

Customer ID: 115561
----------------------------------------------------------------------
  1. All-Mountain Skis (Skis)
     Purchase Probability: 90.9%
  2. Powder Skis (Skis)
     Purchase Probability: 76.5%

Total Customers: 2
Total Recommendations: 3
```

### Integration with Cortex Agents

Use this stored procedure as a tool in Cortex Agents:

**Agent Instructions:**
```
You are a Product Recommendation Assistant. You have access to:
GET_PRODUCT_RECOMMENDATIONS(n_customers, n_products, segment)

When users ask for recommendations:
1. Identify the target segment
2. Call the stored procedure
3. Present results with purchase probabilities
4. Explain business value
```

**Sample Prompts:**
- "Show me product recommendations for low engagement customers"
- "Which products should I recommend to inactive high-value customers?"
- "Get 10 customers from the at-risk segment with their top 5 products"

### Technical Details

**Approach**: Pure SQL feature engineering + Snowpark ML inference
- Avoids Snowpark DataFrame column reference issues
- Uses SQL CTEs for customer segmentation and feature calculation
- Snowpark only for ML model inference via `F.call_function()`
- Deterministic results (ordered by `DAYS_SINCE_LAST_ORDER DESC, CUSTOMER_ID ASC`)

## 🎓 Next Steps

1. **Experiment with Features**: Add more customer behavior metrics
2. **Hyperparameter Tuning**: Use Ray Tune for automated optimization
3. **Production Deployment**: Schedule notebook runs for regular retraining
4. **A/B Testing**: Compare multiple model versions using Model Registry
5. **Real-time Scoring**: Integrate stored procedure with applications
6. **Cortex Agent Integration**: Use stored procedure as a tool for conversational recommendations

## 💡 Tips

- **Start Small**: Test with 1-2 nodes before scaling to production
- **Monitor Costs**: Ray clusters consume warehouse credits - scale down when not training
- **Version Control**: Each training run creates a new model version - use meaningful version names
- **Feature Store**: Consider creating a feature store for reusable features across models
- **Stored Procedure**: Returns formatted strings for easy integration with Cortex Agents
- **Deterministic Results**: Stored procedure ensures consistent recommendations for the same parameters

---

Built with ❄️ Snowflake, 🐍 Python, and ⚡ Ray
