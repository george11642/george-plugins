# ML Monitoring and Drift Detection

## Why Models Degrade in Production

Models degrade silently. Unlike software bugs, model degradation is gradual and often goes undetected until business impact is measurable.

### Types of Drift

| Type | Description | Example | Detection |
|------|-------------|---------|-----------|
| **Feature drift** | Input distribution changes | User age distribution shifts with new cohort | KS test, PSI |
| **Label drift** | Target distribution changes | Fraud patterns evolve, new fraud types emerge | Class distribution monitoring |
| **Concept drift** | P(Y\|X) changes — relationship between features and target changes | Economic downturn changes purchase behavior | Performance monitoring |
| **Training-serving skew** | Different feature transformations at train vs serve time | Different normalization, different null handling | Code audit, feature logging |

**Which is most dangerous?** Concept drift is hardest to detect because input distributions may look stable while model accuracy collapses.

---

## Feature Drift Detection

### Kolmogorov-Smirnov (KS) Test — Numerical Features

Tests whether two samples come from the same distribution (null hypothesis: same distribution).

```python
from scipy import stats
import numpy as np
import pandas as pd

def ks_drift_test(reference: pd.Series, current: pd.Series, threshold: float = 0.05) -> dict:
    """
    Compare current data distribution to reference (training) distribution.

    Returns:
        dict with statistic, p_value, and drift_detected flag
    """
    # Remove nulls before testing
    ref_clean = reference.dropna()
    cur_clean = current.dropna()

    if len(cur_clean) < 30:
        return {"error": "insufficient data", "drift_detected": False}

    statistic, p_value = stats.ks_2samp(ref_clean, cur_clean)

    return {
        "statistic": float(statistic),
        "p_value": float(p_value),
        "drift_detected": p_value < threshold,
        "severity": "high" if p_value < 0.01 else "medium" if p_value < 0.05 else "none"
    }

# Usage
reference_age = train_df["user_age"]
current_age = production_df["user_age"]
result = ks_drift_test(reference_age, current_age)
```

**Interpreting KS test:**
- Statistic: max distance between CDFs (0 = identical, 1 = completely different)
- p-value < 0.05: reject null hypothesis → drift detected
- Be careful with large samples: trivial differences become statistically significant. Combine with PSI for practical significance.

### Population Stability Index (PSI) — Industry Standard

PSI measures the shift in distribution between reference and current data. Widely used in credit risk and financial ML.

```
PSI = sum( (actual_% - expected_%) * ln(actual_% / expected_%) )
```

Interpretation:
- **PSI < 0.1**: No significant shift (stable)
- **0.1 <= PSI < 0.2**: Moderate shift (investigate)
- **PSI >= 0.2**: Significant shift (retrain likely needed)

```python
import numpy as np

def calculate_psi(reference: np.ndarray, current: np.ndarray, n_bins: int = 10) -> float:
    """
    Calculate Population Stability Index.

    Args:
        reference: Reference dataset values (training data)
        current: Current production data values
        n_bins: Number of bins for discretization
    Returns:
        PSI value
    """
    # Create bins based on reference distribution
    breakpoints = np.percentile(reference, np.linspace(0, 100, n_bins + 1))
    breakpoints = np.unique(breakpoints)  # remove duplicate edges

    def get_bin_proportions(data, breakpoints):
        counts, _ = np.histogram(data, bins=breakpoints)
        proportions = counts / len(data)
        # Replace zeros to avoid log(0)
        proportions = np.where(proportions == 0, 1e-6, proportions)
        return proportions

    ref_props = get_bin_proportions(reference, breakpoints)
    cur_props = get_bin_proportions(current, breakpoints)

    psi = np.sum((cur_props - ref_props) * np.log(cur_props / ref_props))
    return float(psi)

def psi_alert_level(psi: float) -> str:
    if psi < 0.1:
        return "stable"
    elif psi < 0.2:
        return "warn"
    else:
        return "critical"

# Monitor all numeric features
def monitor_features(reference_df: pd.DataFrame, current_df: pd.DataFrame,
                     numeric_cols: list[str]) -> pd.DataFrame:
    results = []
    for col in numeric_cols:
        psi = calculate_psi(reference_df[col].dropna().values,
                           current_df[col].dropna().values)
        ks = ks_drift_test(reference_df[col], current_df[col])
        results.append({
            "feature": col,
            "psi": psi,
            "psi_level": psi_alert_level(psi),
            "ks_p_value": ks["p_value"],
            "ks_drift": ks["drift_detected"]
        })
    return pd.DataFrame(results).sort_values("psi", ascending=False)
```

### Chi-Squared Test — Categorical Features

```python
from scipy.stats import chi2_contingency

def chi2_drift_test(reference: pd.Series, current: pd.Series) -> dict:
    """Test categorical feature drift using chi-squared test."""
    # Get all categories from both distributions
    all_categories = set(reference.unique()) | set(current.unique())

    ref_counts = reference.value_counts()
    cur_counts = current.value_counts()

    # Align to same categories (fill 0 for missing)
    ref_aligned = np.array([ref_counts.get(cat, 0) for cat in all_categories])
    cur_aligned = np.array([cur_counts.get(cat, 0) for cat in all_categories])

    # Chi-squared test requires expected frequency > 5 in most cells
    contingency = np.vstack([ref_aligned, cur_aligned])
    chi2, p_value, dof, expected = chi2_contingency(contingency)

    # Check for new categories (not in training)
    new_categories = set(current.unique()) - set(reference.unique())

    return {
        "chi2_statistic": float(chi2),
        "p_value": float(p_value),
        "drift_detected": p_value < 0.05,
        "new_categories": list(new_categories),
        "new_category_alert": len(new_categories) > 0
    }
```

---

## Prediction Drift

Monitor model outputs — often detects concept drift before feature drift.

```python
import numpy as np
from collections import deque

class PredictionDriftMonitor:
    """Rolling window prediction distribution monitor."""

    def __init__(self, reference_predictions: np.ndarray, window_size: int = 1000):
        self.reference = reference_predictions
        self.window = deque(maxlen=window_size)

        # Compute reference statistics
        self.ref_mean = float(np.mean(reference_predictions))
        self.ref_std = float(np.std(reference_predictions))

    def add_prediction(self, prediction: float):
        self.window.append(prediction)

    def get_drift_report(self) -> dict:
        if len(self.window) < 100:
            return {"status": "insufficient_data"}

        current = np.array(self.window)
        current_mean = float(np.mean(current))
        current_std = float(np.std(current))

        # Mean shift in standard deviation units
        mean_shift = abs(current_mean - self.ref_mean) / (self.ref_std + 1e-8)

        # KS test on prediction distribution
        ks_stat, ks_p = stats.ks_2samp(self.reference, current)

        return {
            "current_mean": current_mean,
            "reference_mean": self.ref_mean,
            "mean_shift_stddevs": mean_shift,
            "ks_p_value": float(ks_p),
            "alert": mean_shift > 2.0 or ks_p < 0.05
        }
```

---

## Evidently AI (Production Monitoring Framework)

Evidently provides pre-built drift detection, data quality checks, and dashboards.

```python
# pip install evidently

import pandas as pd
from evidently.report import Report
from evidently.metric_preset import DataDriftPreset, DataQualityPreset
from evidently.test_suite import TestSuite
from evidently.test_preset import DataDriftTestPreset

reference_data = pd.read_parquet("reference_data.parquet")
current_data = pd.read_parquet("current_batch.parquet")

# Generate data drift report (interactive HTML)
report = Report(metrics=[DataDriftPreset()])
report.run(reference_data=reference_data, current_data=current_data)
report.save_html("drift_report.html")

# Programmatic test suite for CI/CD
test_suite = TestSuite(tests=[DataDriftTestPreset()])
test_suite.run(reference_data=reference_data, current_data=current_data)

result = test_suite.as_dict()
if not result["summary"]["all_passed"]:
    failed_tests = [t for t in result["tests"] if t["status"] == "FAIL"]
    for test in failed_tests:
        print(f"FAILED: {test['name']} - {test['description']}")
```

### Evidently Column Mapping

```python
from evidently import ColumnMapping

column_mapping = ColumnMapping(
    target="churn",
    prediction="prediction",
    numerical_features=["age", "balance", "num_products"],
    categorical_features=["country", "has_credit_card"],
    datetime_features=["last_activity_date"]
)

report = Report(metrics=[DataDriftPreset()])
report.run(
    reference_data=reference_data,
    current_data=current_data,
    column_mapping=column_mapping
)
```

### Drift Detection Methods in Evidently

- **Small datasets (<1000)**: KS test (numerical), Chi-squared (categorical)
- **Large datasets (>1000)**: Wasserstein distance (numerical), JS divergence (categorical)
- **Default**: Evidently auto-selects based on sample size
- **Override**: `DataDriftPreset(stattest="psi")` or `stattest="ks"`, `"wasserstein"`, `"jensenshannon"`

---

## Training-Serving Skew

The most preventable form of model degradation. Ensure the same code path is used for feature computation in both training and serving.

```python
# feature_pipeline.py — shared between training and serving

import pandas as pd
import numpy as np
import joblib
from typing import Optional

class FeatureEngineer:
    """Same class used in training (fit+transform) and serving (transform only)."""

    def __init__(self):
        self.scaler_params: Optional[dict] = None
        self.category_mappings: Optional[dict] = None
        self.null_fill_values: Optional[dict] = None

    def fit(self, df: pd.DataFrame) -> "FeatureEngineer":
        """Compute parameters from training data only."""
        self.null_fill_values = {
            col: df[col].median() for col in df.select_dtypes("number").columns
        }
        self.scaler_params = {
            col: {"mean": df[col].mean(), "std": df[col].std()}
            for col in df.select_dtypes("number").columns
        }
        self.category_mappings = {
            col: {cat: i for i, cat in enumerate(df[col].unique())}
            for col in df.select_dtypes("object").columns
        }
        return self

    def transform(self, df: pd.DataFrame) -> pd.DataFrame:
        """Apply same transformation to training and production data."""
        df = df.copy()

        # Fill nulls with training medians
        for col, fill_val in self.null_fill_values.items():
            if col in df.columns:
                df[col] = df[col].fillna(fill_val)

        # Standardize with training mean/std
        for col, params in self.scaler_params.items():
            if col in df.columns:
                df[col] = (df[col] - params["mean"]) / (params["std"] + 1e-8)

        # Encode categories — unknown categories get -1
        for col, mapping in self.category_mappings.items():
            if col in df.columns:
                df[col] = df[col].map(mapping).fillna(-1).astype(int)

        return df

    def save(self, path: str):
        joblib.dump(self, path)

    @classmethod
    def load(cls, path: str) -> "FeatureEngineer":
        return joblib.load(path)
```

---

## Data Quality Monitoring

```python
import great_expectations as ge
from great_expectations.dataset import PandasDataset

def validate_production_batch(df: pd.DataFrame) -> dict:
    """Run data quality checks on production data batch."""
    ge_df = ge.from_pandas(df)

    results = {
        "passed": True,
        "failures": []
    }

    # Null rate checks
    for col in df.columns:
        null_rate = df[col].isnull().mean()
        if null_rate > 0.05:  # alert if >5% nulls
            results["failures"].append(f"{col}: null_rate={null_rate:.1%} (threshold 5%)")
            results["passed"] = False

    # Schema validation
    expected_dtypes = {"age": "float64", "category": "object", "amount": "float64"}
    for col, expected_dtype in expected_dtypes.items():
        if col in df.columns and str(df[col].dtype) != expected_dtype:
            results["failures"].append(f"{col}: dtype={df[col].dtype}, expected={expected_dtype}")
            results["passed"] = False

    # Value range checks
    if "age" in df.columns:
        out_of_range = ((df["age"] < 0) | (df["age"] > 120)).sum()
        if out_of_range > 0:
            results["failures"].append(f"age: {out_of_range} values out of range [0, 120]")
            results["passed"] = False

    # Cardinality check — new unseen categories
    if hasattr(validate_production_batch, "known_categories"):
        for col in df.select_dtypes("object").columns:
            new_cats = set(df[col].unique()) - validate_production_batch.known_categories.get(col, set())
            if new_cats:
                results["failures"].append(f"{col}: new categories not in training: {new_cats}")

    return results
```

---

## MLOps Alerting Stack

### Prometheus Metrics (FastAPI example)

```python
from prometheus_client import Counter, Histogram, Gauge, start_http_server
import time

# Define metrics
prediction_latency = Histogram(
    "model_prediction_latency_seconds",
    "Prediction latency in seconds",
    buckets=[0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5]
)
prediction_confidence = Histogram(
    "model_prediction_confidence",
    "Model prediction confidence score",
    buckets=[0.1, 0.2, 0.3, 0.5, 0.7, 0.9, 0.95, 1.0]
)
prediction_errors = Counter("model_prediction_errors_total", "Total prediction errors")
model_version_gauge = Gauge("model_version_deployed", "Currently deployed model version")

# Instrument inference
def predict_with_metrics(features: dict) -> dict:
    start = time.time()
    try:
        result = model.predict(features)
        prediction_latency.observe(time.time() - start)
        prediction_confidence.observe(result["confidence"])
        return result
    except Exception as e:
        prediction_errors.inc()
        raise
```

### Alert Rules (Prometheus/Alertmanager)

```yaml
# alerts.yml
groups:
  - name: ml_model_alerts
    rules:
      - alert: ModelHighLatency
        expr: histogram_quantile(0.95, model_prediction_latency_seconds_bucket) > 0.5
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Model p95 latency > 500ms"

      - alert: ModelLowConfidence
        expr: histogram_quantile(0.50, model_prediction_confidence_bucket) < 0.6
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Model median confidence dropped below 0.6"

      - alert: ModelErrorRate
        expr: rate(model_prediction_errors_total[5m]) > 0.01
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Model error rate > 1%"
```

---

## Retraining Trigger Workflow

```
Monitoring pipeline runs hourly:
  1. Compute PSI for all features vs training distribution
  2. Compute KS test p-values for numerical features
  3. Monitor prediction confidence distribution
  4. Monitor labeled feedback (if available) → accuracy on recent samples

Trigger conditions:
  - PSI > 0.2 on any high-importance feature → CRITICAL retrain
  - PSI > 0.1 on 3+ features → WARN, schedule retrain in 48h
  - Model accuracy (on labeled feedback) drops >5% vs baseline → CRITICAL retrain
  - Confidence median drops >10% → Investigate, possible concept drift

Retrain pipeline (automated):
  1. Pull latest data (last 90 days rolling window)
  2. Run feature validation suite
  3. Train with same hyperparameters (or trigger HPO if accuracy is low)
  4. Run evaluation on holdout
  5. If new model beats baseline + 1% threshold → canary deploy
  6. Else → alert data science team for manual review
```

---

## Monitoring Checklist

- [ ] Feature drift: PSI computed weekly on all features vs training distribution
- [ ] Prediction drift: Output distribution monitored in real-time (rolling window)
- [ ] Data quality: Null rates, cardinality, range violations checked on each batch
- [ ] Training-serving skew: Same feature code path verified with unit tests
- [ ] Model accuracy: If ground truth is available (even with delay), track accuracy vs baseline
- [ ] Latency: p50, p95, p99 tracked and alerted
- [ ] Retraining pipeline: Automated, tested, documented

---

## Dependencies

```bash
pip install evidently scipy great-expectations prometheus-client pandas
```
