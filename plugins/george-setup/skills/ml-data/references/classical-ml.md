# Classical ML Reference

## The Scikit-learn Pipeline Pattern

Always use pipelines. They prevent data leakage by fitting transformers only on training data.

```python
from sklearn.pipeline import Pipeline
from sklearn.compose import ColumnTransformer
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.impute import SimpleImputer

# Define preprocessing per column type
numeric_features = ["age", "income", "tenure"]
categorical_features = ["city", "plan_type"]

preprocessor = ColumnTransformer([
    ("num", Pipeline([
        ("imputer", SimpleImputer(strategy="median")),
        ("scaler", StandardScaler()),
    ]), numeric_features),
    ("cat", Pipeline([
        ("imputer", SimpleImputer(strategy="constant", fill_value="missing")),
        ("encoder", OneHotEncoder(handle_unknown="ignore", sparse_output=False)),
    ]), categorical_features),
])

# Full pipeline — preprocessing + model as single unit
pipe = Pipeline([
    ("preprocess", preprocessor),
    ("model", LogisticRegression(random_state=42, max_iter=1000)),
])
```

## Feature Engineering

### Numeric Features
```python
# Log transform — compress skewed distributions (revenue, counts)
df["log_revenue"] = np.log1p(df["revenue"])  # log1p handles zeros

# Binning — when relationship is non-linear
df["age_group"] = pd.cut(df["age"], bins=[0, 18, 35, 55, 100], labels=["youth", "young", "mid", "senior"])

# Interaction features — when two features combine meaningfully
df["price_per_sqft"] = df["price"] / df["sqft"]

# Rolling aggregates — for time series features
df["revenue_7d_avg"] = df.groupby("user_id")["revenue"].transform(
    lambda x: x.rolling(7, min_periods=1).mean()
)
```

### Categorical Features
```python
# Target encoding — powerful but prone to leakage, use with CV
from sklearn.preprocessing import TargetEncoder
encoder = TargetEncoder(smooth="auto")  # auto smoothing prevents overfitting

# Frequency encoding — simple, leakage-free
freq = df["city"].value_counts(normalize=True)
df["city_freq"] = df["city"].map(freq)

# Hash encoding — for high-cardinality features (>100 categories)
from sklearn.feature_extraction import FeatureHasher
hasher = FeatureHasher(n_features=32, input_type="string")
```

### Date Features
```python
# Extract components — models can't use raw datetimes
df["hour"] = df["ts"].dt.hour
df["day_of_week"] = df["ts"].dt.dayofweek
df["is_weekend"] = df["ts"].dt.dayofweek >= 5
df["month_sin"] = np.sin(2 * np.pi * df["ts"].dt.month / 12)  # cyclical encoding
df["month_cos"] = np.cos(2 * np.pi * df["ts"].dt.month / 12)
```

## Cross-Validation

### Standard Patterns
```python
from sklearn.model_selection import cross_val_score, StratifiedKFold

# Stratified — preserves class distribution in each fold
cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
scores = cross_val_score(pipe, X, y, cv=cv, scoring="f1_macro")
print(f"F1: {scores.mean():.3f} +/- {scores.std():.3f}")
```

### Time Series — Never Shuffle
```python
from sklearn.model_selection import TimeSeriesSplit

# Expanding window — train on past, test on future
tscv = TimeSeriesSplit(n_splits=5)
for train_idx, test_idx in tscv.split(X):
    assert train_idx.max() < test_idx.min()  # sanity check: no future leakage
```

### Nested CV — Unbiased Model Selection
```python
from sklearn.model_selection import cross_val_score, GridSearchCV

# Outer loop: estimate generalization performance
# Inner loop: tune hyperparameters
inner_cv = StratifiedKFold(n_splits=3, shuffle=True, random_state=42)
outer_cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)

grid = GridSearchCV(pipe, param_grid, cv=inner_cv, scoring="f1_macro")
nested_scores = cross_val_score(grid, X, y, cv=outer_cv, scoring="f1_macro")
```

## Hyperparameter Tuning

### Optuna — Bayesian Optimization
Optuna is more efficient than grid search. It prunes bad trials early.
```python
import optuna

def objective(trial):
    params = {
        "model__n_estimators": trial.suggest_int("n_estimators", 100, 1000),
        "model__max_depth": trial.suggest_int("max_depth", 3, 12),
        "model__learning_rate": trial.suggest_float("lr", 1e-3, 0.3, log=True),
        "model__subsample": trial.suggest_float("subsample", 0.6, 1.0),
    }
    pipe.set_params(**params)
    scores = cross_val_score(pipe, X, y, cv=5, scoring="f1_macro")
    return scores.mean()

study = optuna.create_study(direction="maximize")
study.optimize(objective, n_trials=100)
best_params = study.best_params
```

## Model Selection Guide

| Problem | First try | If that's not enough |
|---------|-----------|---------------------|
| Binary classification | LogisticRegression | LightGBM / XGBoost |
| Multi-class | LogisticRegression(multi_class="multinomial") | LightGBM |
| Regression | Ridge / Lasso | LightGBM / XGBoost |
| Ranking | LightGBM (lambdarank) | XGBoost (rank:pairwise) |
| Anomaly detection | IsolationForest | Local Outlier Factor |
| Clustering | KMeans → DBSCAN | HDBSCAN for varying density |
| Dimensionality reduction | PCA | UMAP for visualization |

## Gradient Boosting — The Tabular ML King

```python
import lightgbm as lgb

# LightGBM handles categoricals natively — no encoding needed
lgb_pipe = Pipeline([
    ("preprocess", preprocessor),
    ("model", lgb.LGBMClassifier(
        n_estimators=500,
        learning_rate=0.05,
        max_depth=7,
        num_leaves=31,           # 2^max_depth - 1 is a good default
        min_child_samples=20,    # regularization: min samples per leaf
        subsample=0.8,           # row subsampling
        colsample_bytree=0.8,   # feature subsampling
        random_state=42,
        n_jobs=-1,
        verbose=-1,
    )),
])
```

## Evaluation Metrics

### Classification
```python
from sklearn.metrics import classification_report, roc_auc_score, average_precision_score

# Always look at per-class metrics, not just accuracy
print(classification_report(y_true, y_pred))

# For imbalanced classes, prefer AUROC or average precision over accuracy
auroc = roc_auc_score(y_true, y_prob)
ap = average_precision_score(y_true, y_prob)  # better than AUROC for severe imbalance
```

### Regression
```python
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score

mae = mean_absolute_error(y_true, y_pred)       # interpretable, robust to outliers
rmse = mean_squared_error(y_true, y_pred) ** 0.5  # penalizes large errors
r2 = r2_score(y_true, y_pred)                    # proportion of variance explained
```

## Handling Imbalanced Classes

```python
# Option 1: Class weights — tell the model minorities matter more
pipe = Pipeline([
    ("preprocess", preprocessor),
    ("model", LogisticRegression(class_weight="balanced", random_state=42)),
])

# Option 2: SMOTE — synthetic oversampling (use with caution, only on training set)
from imblearn.pipeline import Pipeline as ImbPipeline
from imblearn.over_sampling import SMOTE

pipe = ImbPipeline([
    ("preprocess", preprocessor),
    ("smote", SMOTE(random_state=42)),  # only applied during fit, not predict
    ("model", LogisticRegression(random_state=42)),
])

# Option 3: Threshold tuning — adjust decision threshold post-training
from sklearn.metrics import precision_recall_curve
precisions, recalls, thresholds = precision_recall_curve(y_true, y_prob)
# Pick threshold that gives desired precision-recall tradeoff
```

## Common Gotchas

1. **Data leakage via preprocessing** — Fit scalers/encoders on train only. Pipelines prevent this automatically.
2. **Target leakage** — Feature derived from target (e.g., "was_refunded" predicting "will_churn"). Audit feature sources.
3. **Correlated features** — Gradient boosting handles this; linear models don't. Use VIF or correlation matrix.
4. **Overfitting to validation** — If you tune 100 times on val set, you're overfitting to val. Use nested CV.
5. **Wrong metric** — Accuracy is misleading for imbalanced data. Match metric to business objective.
