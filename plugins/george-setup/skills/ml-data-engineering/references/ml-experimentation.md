# ML Experimentation Reference

Adapted from the ab-test-setup archived skill for ML model comparison, hyperparameter studies, and evaluation design.

---

## Hypothesis Framework for ML

Before running any experiment, write a hypothesis. "Let's try dropout 0.5 and see" is not a hypothesis.

### Structure

```
Because [observation / prior data / theory],
we believe [change to model/data/training]
will cause [expected outcome + direction]
for [evaluation set / population].
We'll know this is true when [metric exceeds threshold / improves by X%].
```

### Examples

**Weak hypothesis:**
"Adding more layers might improve accuracy."

**Strong hypothesis:**
"Because our training curves show high bias (train accuracy 72%, val accuracy 70%), we believe adding a third hidden layer (256 → 256 → 128) will increase validation F1 from 0.71 to at least 0.75 on the held-out test set. We'll measure F1-macro on the fixed test split, with a minimum improvement of 0.02 over baseline."

**Strong hypothesis (data):**
"Because our EDA shows 40% missing values in the `age` column and mean imputation introduces distributional bias, we believe using MICE (multivariate imputation) will increase validation AUROC by ≥ 0.01 compared to mean imputation. We'll run 5-fold CV on the training set only and compare bootstrap confidence intervals."

---

## Sample Size Planning for Model Comparison

Before running model comparisons, determine whether you'll have statistical power to detect a meaningful difference.

### Effect Size for Classification (Cohen's h)

```python
import numpy as np
from scipy import stats

def cohens_h(p1: float, p2: float) -> float:
    """Cohen's h for comparing two proportions (accuracy, F1 can be treated as proportions)."""
    return 2 * np.arcsin(np.sqrt(p1)) - 2 * np.arcsin(np.sqrt(p2))

def required_samples_proportion(p1: float, p2: float, alpha: float = 0.05, power: float = 0.80) -> int:
    """
    Sample size needed to detect difference between two accuracy/proportion values.
    p1: baseline metric
    p2: expected improved metric
    """
    from statsmodels.stats.power import zt_ind_solve_power
    h = abs(cohens_h(p1, p2))
    if h == 0:
        return float("inf")
    n = zt_ind_solve_power(effect_size=h, alpha=alpha, power=power, alternative="two-sided")
    return int(np.ceil(n))

# Example: detect improvement from 0.80 to 0.83 accuracy
n = required_samples_proportion(0.80, 0.83)
print(f"Need {n} test samples per model to detect 0.80 → 0.83 with 80% power")
```

### Quick Sample Size Table

| Baseline Accuracy | +1% | +2% | +5% | +10% |
|---|---|---|---|---|
| 70% | 12,100 | 3,050 | 500 | 135 |
| 80% | 18,500 | 4,660 | 752 | 198 |
| 90% | 44,000 | 11,100 | 1,800 | 480 |
| 95% | 176,000 | 44,300 | 7,100 | 1,900 |

**Key insight**: At high baselines, tiny improvements are very hard to detect statistically. Collect a large test set or use paired tests.

---

## Statistical Tests for ML Comparison

### Paired t-test (Continuous Metrics, e.g., MSE, AUROC)

```python
from scipy import stats
import numpy as np

def paired_ttest(
    scores_a: np.ndarray,
    scores_b: np.ndarray,
    alpha: float = 0.05,
) -> dict:
    """
    Use when: comparing CV fold scores, bootstrap estimates.
    Assumes paired measurements (same fold / same sample).
    """
    diff = scores_b - scores_a
    t_stat, p_value = stats.ttest_rel(scores_a, scores_b)
    n = len(diff)
    se = diff.std(ddof=1) / np.sqrt(n)
    ci = stats.t.interval(1 - alpha, df=n - 1, loc=diff.mean(), scale=se)
    return {
        "mean_diff": float(diff.mean()),
        "ci_lower": float(ci[0]),
        "ci_upper": float(ci[1]),
        "t_statistic": float(t_stat),
        "p_value": float(p_value),
        "significant": p_value < alpha,
        "conclusion": "B better" if diff.mean() > 0 and p_value < alpha else
                      "A better" if diff.mean() < 0 and p_value < alpha else "No significant difference",
    }

# Example: compare 5-fold CV scores
scores_baseline = np.array([0.820, 0.815, 0.831, 0.818, 0.825])
scores_new_model = np.array([0.835, 0.829, 0.844, 0.832, 0.840])
result = paired_ttest(scores_baseline, scores_new_model)
print(f"Mean improvement: {result['mean_diff']:.4f} (95% CI: [{result['ci_lower']:.4f}, {result['ci_upper']:.4f}])")
print(f"p={result['p_value']:.4f}, significant={result['significant']}")
```

### McNemar's Test (Binary Classification, Per-Sample Comparison)

```python
from statsmodels.stats.contingency_tables import mcnemar
import numpy as np

def mcnemar_test(y_true: np.ndarray, preds_a: np.ndarray, preds_b: np.ndarray) -> dict:
    """
    Use when: comparing two classifiers on the SAME test set, item-by-item.
    Correct for correlated predictions (both see same samples).
    More powerful than independent t-test for classification.
    """
    correct_a = (preds_a == y_true)
    correct_b = (preds_b == y_true)
    # Contingency table
    # [both correct, a correct / b wrong]
    # [a wrong / b correct, both wrong]
    b = int(np.sum(correct_a & ~correct_b))  # A correct, B wrong
    c = int(np.sum(~correct_a & correct_b))  # B correct, A wrong
    table = np.array([[int(np.sum(correct_a & correct_b)), b],
                      [c, int(np.sum(~correct_a & ~correct_b))]])
    result = mcnemar(table, exact=True if min(b, c) < 25 else False)
    return {
        "b": b, "c": c,
        "statistic": float(result.statistic),
        "p_value": float(result.pvalue),
        "significant": result.pvalue < 0.05,
        "favors": "B" if c > b else "A" if b > c else "Neither",
    }
```

### Permutation Test (Non-parametric, Any Metric)

```python
def permutation_test(
    scores_a: np.ndarray,
    scores_b: np.ndarray,
    n_permutations: int = 10000,
    alternative: str = "two-sided",
    random_state: int = 42,
) -> dict:
    """
    No distributional assumptions. Works for any metric.
    Good when: small sample, non-normal distributions, custom metrics.
    """
    rng = np.random.default_rng(random_state)
    observed_diff = scores_b.mean() - scores_a.mean()
    combined = np.concatenate([scores_a, scores_b])
    n_a = len(scores_a)

    null_diffs = np.empty(n_permutations)
    for i in range(n_permutations):
        perm = rng.permutation(combined)
        null_diffs[i] = perm[n_a:].mean() - perm[:n_a].mean()

    if alternative == "two-sided":
        p_value = np.mean(np.abs(null_diffs) >= np.abs(observed_diff))
    elif alternative == "greater":
        p_value = np.mean(null_diffs >= observed_diff)
    else:
        p_value = np.mean(null_diffs <= observed_diff)

    return {
        "observed_diff": float(observed_diff),
        "p_value": float(p_value),
        "significant": p_value < 0.05,
        "n_permutations": n_permutations,
    }
```

---

## Guardrail Metrics

Every ML experiment needs guardrail metrics — things that must not get worse, even if the primary metric improves.

### Defining Guardrails

```python
@dataclasses.dataclass
class ExperimentGuardrails:
    """Thresholds that must not be breached, regardless of primary metric gain."""
    # Classification
    minority_class_recall_floor: float = 0.70   # Don't sacrifice minority class for overall accuracy
    false_positive_rate_ceiling: float = 0.10   # For high-stakes predictions
    # Performance
    inference_latency_p99_ms: float = 100.0     # 99th percentile latency
    # Fairness
    demographic_parity_diff_ceiling: float = 0.05  # Max allowed disparity between groups
    # Calibration
    brier_score_ceiling: float = 0.20

def check_guardrails(metrics: dict, guardrails: ExperimentGuardrails) -> list[str]:
    """Returns list of violated guardrails."""
    violations = []
    if metrics.get("recall_minority", 1.0) < guardrails.minority_class_recall_floor:
        violations.append(f"Minority recall {metrics['recall_minority']:.3f} < floor {guardrails.minority_class_recall_floor}")
    if metrics.get("latency_p99_ms", 0) > guardrails.inference_latency_p99_ms:
        violations.append(f"P99 latency {metrics['latency_p99_ms']:.1f}ms > ceiling {guardrails.inference_latency_p99_ms}ms")
    if metrics.get("brier_score", 0) > guardrails.brier_score_ceiling:
        violations.append(f"Brier score {metrics['brier_score']:.3f} > ceiling {guardrails.brier_score_ceiling}")
    return violations
```

---

## Holdout Set Sanctity

The test set is sacred. Touch it once, at the very end.

### Rules

1. **Split before any preprocessing.** Fit scalers, encoders, imputers on train only. Apply to val/test.
2. **Never use test set for model selection.** Use validation set or cross-validation.
3. **Never tune hyperparameters on test set.** Even implicitly (e.g., "let's try one more thing...").
4. **Touch test set exactly once** — when you're done and ready to report final results.
5. **Document the test set version** — if data changes, the test set changes, and previous results are incomparable.

```python
from sklearn.model_selection import train_test_split

# CORRECT split order
X, y = load_data()
X_trainval, X_test, y_trainval, y_test = train_test_split(
    X, y, test_size=0.15, random_state=42, stratify=y
)
X_train, X_val, y_train, y_val = train_test_split(
    X_trainval, y_trainval, test_size=0.15/0.85, random_state=42, stratify=y_trainval
)

# Fit preprocessor on train ONLY
scaler = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train)  # fit here
X_val_scaled = scaler.transform(X_val)           # only transform
X_test_scaled = scaler.transform(X_test)         # only transform

# Lock test set in a variable you don't touch during development
TEST_FEATURES = X_test_scaled.copy()
TEST_LABELS = y_test.copy()
# Don't use TEST_FEATURES or TEST_LABELS until final evaluation
```

---

## Peeking Problem in Hyperparameter Tuning

Evaluating on the validation set repeatedly during tuning causes the validation set to "leak" into model selection.

### The Problem

```python
# WRONG: Tune until val looks good
best_params = {}
best_val_score = 0
for lr in [1e-4, 1e-3, 1e-2]:
    for hidden in [64, 128, 256]:
        model = train(lr=lr, hidden=hidden)
        val_score = evaluate(model, val_set)
        if val_score > best_val_score:  # Picking best of 6 trials
            best_val_score = val_score  # This is an optimistic estimate
            best_params = {"lr": lr, "hidden": hidden}
# best_val_score is now BIASED — it's the best of 6, not an honest estimate
```

### The Fix: Nested Cross-Validation

```python
from sklearn.model_selection import cross_val_score, GridSearchCV, KFold

# Inner CV: hyperparameter selection
# Outer CV: unbiased performance estimate
outer_cv = KFold(n_splits=5, shuffle=True, random_state=42)
inner_cv = KFold(n_splits=3, shuffle=True, random_state=42)

param_grid = {"C": [0.1, 1.0, 10.0], "kernel": ["rbf", "linear"]}
model = SVC()
search = GridSearchCV(model, param_grid, cv=inner_cv, scoring="f1_macro", n_jobs=-1)

# Outer CV gives unbiased estimate of the best-selected model's performance
outer_scores = cross_val_score(search, X_train, y_train, cv=outer_cv, scoring="f1_macro")
print(f"Unbiased estimate: {outer_scores.mean():.4f} ± {outer_scores.std():.4f}")

# SEPARATE step: fit on all train data with best params for deployment
search.fit(X_train, y_train)
print(f"Best params: {search.best_params_}")
```

---

## Seeded Randomness (Reproducibility)

```python
import random
import numpy as np
import torch
import os

def seed_everything(seed: int = 42):
    """Set all random seeds for full reproducibility."""
    random.seed(seed)
    os.environ["PYTHONHASHSEED"] = str(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    torch.cuda.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)
    # Makes CUDA deterministic (slower)
    torch.backends.cudnn.deterministic = True
    torch.backends.cudnn.benchmark = False
    print(f"All seeds set to {seed}")

seed_everything(42)

# Also: use random_state= in all sklearn calls
# Use np.random.default_rng(seed) for new numpy random API
rng = np.random.default_rng(42)
```

---

## Reporting Results

### What to Report (Not Just p-value)

```python
from scipy import stats
import numpy as np

def report_comparison(name_a: str, scores_a: np.ndarray, name_b: str, scores_b: np.ndarray) -> str:
    """Generate a complete comparison report."""
    diff = scores_b - scores_a
    n = len(diff)
    mean_diff = diff.mean()
    se = diff.std(ddof=1) / np.sqrt(n)
    ci_95 = stats.t.interval(0.95, df=n-1, loc=mean_diff, scale=se)
    t_stat, p_value = stats.ttest_rel(scores_a, scores_b)

    # Cohen's d (effect size for paired comparison)
    cohens_d = mean_diff / diff.std(ddof=1)

    effect_label = ("negligible" if abs(cohens_d) < 0.2 else
                    "small" if abs(cohens_d) < 0.5 else
                    "medium" if abs(cohens_d) < 0.8 else "large")

    return f"""
Model Comparison: {name_a} vs {name_b}
{'='*50}
{name_a}: {scores_a.mean():.4f} ± {scores_a.std():.4f}
{name_b}: {scores_b.mean():.4f} ± {scores_b.std():.4f}

Mean difference: {mean_diff:+.4f}
95% CI: [{ci_95[0]:+.4f}, {ci_95[1]:+.4f}]
Cohen's d: {cohens_d:.3f} ({effect_label} effect)
p-value: {p_value:.4f} ({'significant' if p_value < 0.05 else 'not significant'})

Conclusion: {'B significantly outperforms A' if mean_diff > 0 and p_value < 0.05 else
             'A significantly outperforms B' if mean_diff < 0 and p_value < 0.05 else
             'No statistically significant difference detected'}
"""

# Always report: mean, std/CI, effect size, p-value, n (sample size)
# NEVER report just p < 0.05 without effect size
```

### Bootstrap Confidence Intervals (Non-parametric)

```python
def bootstrap_ci(
    y_true: np.ndarray,
    y_pred: np.ndarray,
    metric_fn,
    n_bootstrap: int = 10000,
    ci: float = 0.95,
    random_state: int = 42,
) -> tuple[float, float, float]:
    """
    Returns (point_estimate, lower_ci, upper_ci) for any metric.
    Use when test set is fixed (not CV) and you need uncertainty estimate.
    """
    rng = np.random.default_rng(random_state)
    n = len(y_true)
    point_estimate = metric_fn(y_true, y_pred)
    bootstrap_scores = []
    for _ in range(n_bootstrap):
        idx = rng.integers(0, n, size=n)
        bootstrap_scores.append(metric_fn(y_true[idx], y_pred[idx]))
    alpha = (1 - ci) / 2
    lower = np.percentile(bootstrap_scores, alpha * 100)
    upper = np.percentile(bootstrap_scores, (1 - alpha) * 100)
    return point_estimate, lower, upper

# Usage
from sklearn.metrics import f1_score
import functools
f1_macro = functools.partial(f1_score, average="macro")
estimate, lower, upper = bootstrap_ci(y_test, y_pred, f1_macro)
print(f"F1-macro: {estimate:.4f} (95% CI: [{lower:.4f}, {upper:.4f}])")
```

---

## Experiment Tracking Template

Minimum viable record for any ML experiment:

```markdown
## Experiment: [name] — [date]

**Hypothesis**: Because [X], we believe [Y] will cause [Z]. We'll know when [metric].

**Change**: [What was modified — model architecture / data / features / hyperparams]

**Baseline**: [Model / config / commit hash]

**Test conditions**:
- Dataset: [version, n_train, n_val, n_test]
- Random seed: 42
- CV: 5-fold stratified (or holdout test set)

**Primary metric**: [metric name]
- Baseline: [value ± std or CI]
- Experiment: [value ± std or CI]
- Difference: [+X%, 95% CI [lo, hi], p=Y]

**Secondary metrics**: [any other metrics tracked]

**Guardrail violations**: [None / list any violated guardrails]

**Conclusion**: [Adopt / Reject / Investigate further]
**Action**: [What to do next]
```
