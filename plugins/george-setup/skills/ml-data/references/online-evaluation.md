# Online Evaluation: A/B Testing, Canary Rollouts, and Production Model Validation

## Offline vs Online Evaluation

Offline evaluation (on a held-out test set) is necessary but not sufficient for production ML decisions.

| Dimension | Offline | Online |
|-----------|---------|--------|
| **Data** | Historical holdout set | Real production traffic |
| **Metrics** | AUROC, F1, RMSE | Revenue, engagement, conversion |
| **Speed** | Instant | Days to weeks |
| **Risk** | None | Real users affected |
| **Validity** | May not reflect production distribution | Reflects actual user behavior |
| **Use for** | Iteration, debugging, rejecting bad models | Final deployment decisions |

**The gap problem:** A model with better AUROC in offline eval can have worse business outcomes in production due to:
- Covariate shift (production data ≠ training distribution)
- Feedback loops (model predictions affect future training data)
- Measurement issues (proxy metric ≠ true objective)
- System effects (model latency degrades user experience)

**Rule:** Never skip online evaluation before full deployment, even if offline metrics look great.

---

## A/B Test Setup for Model Deployments

### Traffic Splitting

```python
import hashlib

def get_experiment_variant(user_id: str, experiment_id: str, traffic_split: float = 0.5) -> str:
    """
    Deterministic, consistent assignment: same user always gets same variant.

    Args:
        user_id: Unique user identifier
        experiment_id: Unique experiment ID (different ID = independent experiment)
        traffic_split: Fraction of users to assign to variant B
    Returns:
        "control" or "treatment"
    """
    # Hash user_id + experiment_id to avoid correlation across experiments
    hash_input = f"{user_id}:{experiment_id}".encode("utf-8")
    hash_value = int(hashlib.sha256(hash_input).hexdigest(), 16)
    bucket = hash_value % 100  # bucket 0-99

    return "treatment" if bucket < (traffic_split * 100) else "control"

# Example: 10/90 split for initial rollout
variant = get_experiment_variant("user_123", "model_v2_experiment", traffic_split=0.10)
```

**Key properties:**
- **Deterministic**: Same user always gets same variant (no re-assignment mid-experiment)
- **Independent**: Different experiment_id prevents correlation between concurrent experiments
- **Configurable**: `traffic_split` controls ratio without code changes

### Logging for Analysis

Every prediction should be logged with sufficient context for later analysis:

```python
import uuid
import time
import json
from dataclasses import dataclass, asdict
from typing import Optional

@dataclass
class PredictionLog:
    log_id: str
    timestamp: float
    user_id: str
    experiment_id: str
    variant: str               # "control" or "treatment"
    model_version: str
    features: dict
    prediction: float
    confidence: float
    outcome: Optional[float]   # filled in later when ground truth is available
    outcome_timestamp: Optional[float]

def log_prediction(
    user_id: str,
    experiment_id: str,
    model_version: str,
    features: dict,
    prediction: float,
    confidence: float,
) -> str:
    variant = get_experiment_variant(user_id, experiment_id)
    log_id = str(uuid.uuid4())

    log = PredictionLog(
        log_id=log_id,
        timestamp=time.time(),
        user_id=user_id,
        experiment_id=experiment_id,
        variant=variant,
        model_version=model_version,
        features=features,
        prediction=prediction,
        confidence=confidence,
        outcome=None,
        outcome_timestamp=None,
    )

    # Send to data warehouse (Kafka, BigQuery, Snowflake, etc.)
    send_to_event_stream(asdict(log))
    return log_id

def log_outcome(log_id: str, outcome: float):
    """Called later when ground truth is available (e.g., purchase happened)."""
    update_event_store(log_id, {"outcome": outcome, "outcome_timestamp": time.time()})
```

### Sample Size Calculation

Calculate required sample size before starting the experiment:

```python
from scipy import stats
import numpy as np

def calculate_sample_size(
    baseline_rate: float,         # current conversion rate (e.g., 0.05 = 5%)
    minimum_detectable_effect: float,  # smallest improvement worth detecting (e.g., 0.01 = 1pp)
    alpha: float = 0.05,          # false positive rate (Type I error)
    power: float = 0.80,          # 1 - false negative rate (1 - Type II error)
) -> int:
    """
    Calculate required sample size per variant for a two-sided proportions test.

    Example: If baseline_rate=0.05 and MDE=0.01, you want to detect 5% → 6% (20% relative lift).
    """
    effect_size = minimum_detectable_effect / np.sqrt(
        baseline_rate * (1 - baseline_rate)
    )
    z_alpha = stats.norm.ppf(1 - alpha / 2)  # two-sided
    z_beta = stats.norm.ppf(power)
    n = ((z_alpha + z_beta) / effect_size) ** 2
    return int(np.ceil(n))

# Example
n = calculate_sample_size(
    baseline_rate=0.05,           # 5% baseline conversion
    minimum_detectable_effect=0.005,  # detect +0.5pp improvement
    alpha=0.05,
    power=0.80,
)
print(f"Required sample size: {n:,} per variant")  # → ~7,300 per variant
print(f"Total experiment duration at 1000 users/day: {2*n/1000:.0f} days")
```

---

## Sequential Testing (Peek Analysis)

**The peeking problem:** If you check p-values during the experiment and stop when p < 0.05, your true false positive rate is much higher than 5%. This is called "optional stopping" or "peeking."

**How bad is it?** With daily peeking over a 2-week experiment, a 5% alpha experiment has ~26% actual false positive rate.

### Always Valid Inference (mSPRT)

The mixture Sequential Probability Ratio Test (mSPRT) provides valid inference at any stopping point.

```python
import numpy as np
from scipy import stats

class SequentialTest:
    """
    Always-valid sequential A/B test.
    Can be checked at any time without inflating false positive rate.
    """

    def __init__(self, alpha: float = 0.05):
        self.alpha = alpha
        self.control_successes = 0
        self.control_n = 0
        self.treatment_successes = 0
        self.treatment_n = 0

    def add_observation(self, variant: str, outcome: bool):
        if variant == "control":
            self.control_n += 1
            self.control_successes += int(outcome)
        else:
            self.treatment_n += 1
            self.treatment_successes += int(outcome)

    def get_result(self) -> dict:
        if self.control_n < 30 or self.treatment_n < 30:
            return {"status": "insufficient_data", "can_stop": False}

        p_control = self.control_successes / self.control_n
        p_treatment = self.treatment_successes / self.treatment_n

        # Two-proportions z-test (valid for large samples)
        pooled_p = (self.control_successes + self.treatment_successes) / (self.control_n + self.treatment_n)
        se = np.sqrt(pooled_p * (1 - pooled_p) * (1/self.control_n + 1/self.treatment_n))
        z_stat = (p_treatment - p_control) / (se + 1e-10)
        p_value = 2 * (1 - stats.norm.cdf(abs(z_stat)))

        relative_lift = (p_treatment - p_control) / (p_control + 1e-10)

        # Confidence interval for lift
        ci_width = 1.96 * se
        ci_lower = (p_treatment - p_control) - ci_width
        ci_upper = (p_treatment - p_control) + ci_width

        return {
            "p_control": p_control,
            "p_treatment": p_treatment,
            "relative_lift": relative_lift,
            "p_value": p_value,
            "ci_95_lower": ci_lower,
            "ci_95_upper": ci_upper,
            "z_statistic": z_stat,
            "significant": p_value < self.alpha,
            "can_stop": p_value < self.alpha,
            "n_control": self.control_n,
            "n_treatment": self.treatment_n,
        }
```

---

## Guardrail Metrics

Guardrail metrics prevent winning on the primary metric while degrading important secondary metrics.

### Primary + Guardrail Pattern

```
Primary metric: The objective you're trying to improve (e.g., click-through rate)
Guardrail metrics: Constraints that must not degrade (e.g., revenue, latency, retention)

Decision rule:
  - SHIP if: primary metric improves significantly AND all guardrails pass
  - HOLD if: primary metric neutral but guardrails pass → more data or iteration
  - ROLLBACK if: any guardrail fails, regardless of primary metric
```

```python
from dataclasses import dataclass
from typing import Optional

@dataclass
class MetricResult:
    name: str
    control_value: float
    treatment_value: float
    relative_change: float
    p_value: float
    significant: bool
    direction: str  # "increase" or "decrease"

@dataclass
class ExperimentDecision:
    recommendation: str  # "ship", "hold", "rollback"
    reason: str
    primary_metric: MetricResult
    guardrail_results: list[MetricResult]

def make_experiment_decision(
    primary: MetricResult,
    guardrails: list[MetricResult],
    guardrail_degradation_threshold: float = -0.01,  # allow up to -1% degradation
) -> ExperimentDecision:
    """
    Make shipping decision based on primary metric and guardrails.

    Guardrail logic: guardrail FAILS if relative_change < threshold (i.e., degraded more than allowed).
    """
    failed_guardrails = [
        g for g in guardrails
        if g.relative_change < guardrail_degradation_threshold and g.significant
    ]

    if failed_guardrails:
        failed_names = [g.name for g in failed_guardrails]
        return ExperimentDecision(
            recommendation="rollback",
            reason=f"Guardrail(s) failed: {failed_names}",
            primary_metric=primary,
            guardrail_results=guardrails,
        )

    if primary.significant and primary.direction == "increase":
        return ExperimentDecision(
            recommendation="ship",
            reason=f"Primary metric improved {primary.relative_change:.1%} (p={primary.p_value:.3f})",
            primary_metric=primary,
            guardrail_results=guardrails,
        )

    return ExperimentDecision(
        recommendation="hold",
        reason="Primary metric not significantly improved. Collect more data or iterate.",
        primary_metric=primary,
        guardrail_results=guardrails,
    )
```

---

## Multi-Armed Bandit (Alternative to Fixed A/B)

Use bandit algorithms when the cost of exploration (sending traffic to worse variant) is high and you want to dynamically shift traffic to the better option.

### Thompson Sampling

```python
import numpy as np

class ThompsonSamplingBandit:
    """
    Beta-Bernoulli Thompson Sampling for binary outcomes (click/no-click, convert/no-convert).

    Maintains Beta distribution per arm: Beta(successes + 1, failures + 1)
    Samples from each distribution and selects arm with highest sample.
    """

    def __init__(self, n_arms: int):
        self.n_arms = n_arms
        self.successes = np.ones(n_arms)   # Beta prior: 1 success, 1 failure
        self.failures = np.ones(n_arms)

    def select_arm(self) -> int:
        """Sample from each arm's Beta distribution, return arm with highest sample."""
        samples = np.random.beta(self.successes, self.failures)
        return int(np.argmax(samples))

    def update(self, arm: int, reward: float):
        """Update arm statistics with observed outcome (reward in [0,1])."""
        self.successes[arm] += reward
        self.failures[arm] += (1 - reward)

    def get_arm_stats(self) -> list[dict]:
        """Current estimated conversion rates and uncertainty."""
        results = []
        for i in range(self.n_arms):
            a, b = self.successes[i], self.failures[i]
            mean = a / (a + b)
            # 95% credible interval
            lower = np.percentile(np.random.beta(a, b, 10000), 2.5)
            upper = np.percentile(np.random.beta(a, b, 10000), 97.5)
            results.append({
                "arm": i,
                "estimated_rate": mean,
                "ci_95": (lower, upper),
                "n_trials": int(a + b - 2)  # subtract prior
            })
        return results

# When to use bandit vs A/B:
# A/B: Formal decision, single comparison, need statistical guarantees, regulated context
# Bandit: High volume, many arms (>4), short experimentation window, reward is immediate
```

---

## Shadow Mode (Safe Pre-Deployment)

Run the new model on production traffic without affecting results. Compare predictions and latency offline.

```python
import asyncio
import time
import logging
from typing import Any

logger = logging.getLogger(__name__)

class ShadowDeployment:
    """
    Route traffic to both production and shadow model.
    Return production result immediately; log shadow result for comparison.
    """

    def __init__(self, production_model, shadow_model, shadow_traffic_fraction: float = 1.0):
        self.production = production_model
        self.shadow = shadow_model
        self.shadow_traffic_fraction = shadow_traffic_fraction

    async def predict(self, features: dict, request_id: str) -> Any:
        # Always use production model for response
        start = time.time()
        production_result = self.production.predict(features)
        production_latency = time.time() - start

        # Shadow: run in background, never block production response
        if np.random.random() < self.shadow_traffic_fraction:
            asyncio.create_task(
                self._run_shadow(features, request_id, production_result, production_latency)
            )

        return production_result

    async def _run_shadow(self, features, request_id, production_result, production_latency):
        try:
            start = time.time()
            shadow_result = self.shadow.predict(features)
            shadow_latency = time.time() - start

            logger.info({
                "event": "shadow_comparison",
                "request_id": request_id,
                "production_result": production_result,
                "shadow_result": shadow_result,
                "production_latency_ms": production_latency * 1000,
                "shadow_latency_ms": shadow_latency * 1000,
                "prediction_match": production_result == shadow_result,
            })
        except Exception as e:
            logger.error(f"Shadow model error: {e}")  # never propagate shadow errors
```

**Shadow mode checklist:**
- Run for at least 24-48 hours to capture time-of-day patterns
- Ensure shadow model can handle production traffic rate
- Monitor shadow model latency (must not degrade production if synchronous)
- Compare prediction distributions, not just individual predictions
- Gate canary on shadow results looking reasonable

---

## Canary Rollout

Progressive traffic shifting with automated rollback.

```
Phase 1: Shadow (0% traffic, compare predictions only)
Phase 2: Canary 1% (catch obvious regressions)
Phase 3: Canary 5%
Phase 4: Canary 10%
Phase 5: Canary 25%
Phase 6: 50% (A/B test phase — collect sufficient data for statistical conclusions)
Phase 7: 100% (full rollout after primary + guardrails pass)
```

```python
from enum import Enum

class RolloutPhase(Enum):
    SHADOW = 0.0
    CANARY_1 = 0.01
    CANARY_5 = 0.05
    CANARY_10 = 0.10
    CANARY_25 = 0.25
    AB_TEST = 0.50
    FULL = 1.0

class CanaryController:

    def __init__(self, production_model, canary_model, prometheus_client):
        self.production = production_model
        self.canary = canary_model
        self.prometheus = prometheus_client
        self.current_phase = RolloutPhase.SHADOW
        self.phase_start_time = time.time()
        self.min_phase_duration_hours = 4

    def should_advance(self) -> tuple[bool, str]:
        """Check if ready to advance to next phase."""
        elapsed_hours = (time.time() - self.phase_start_time) / 3600
        if elapsed_hours < self.min_phase_duration_hours:
            return False, f"Need {self.min_phase_duration_hours - elapsed_hours:.1f} more hours"

        metrics = self._check_guardrails()
        if not metrics["all_passed"]:
            return False, f"Guardrail failure: {metrics['failures']}"

        return True, "Ready to advance"

    def _check_guardrails(self) -> dict:
        """Query Prometheus for canary vs production metrics."""
        canary_error_rate = self.prometheus.query(
            'rate(model_errors_total{model="canary"}[5m])'
        )
        prod_error_rate = self.prometheus.query(
            'rate(model_errors_total{model="production"}[5m])'
        )
        canary_p95_latency = self.prometheus.query(
            'histogram_quantile(0.95, model_latency_bucket{model="canary"})'
        )

        failures = []
        if canary_error_rate > prod_error_rate * 2:
            failures.append(f"Canary error rate {canary_error_rate:.2%} > 2x production {prod_error_rate:.2%}")
        if canary_p95_latency > 0.5:  # 500ms threshold
            failures.append(f"Canary p95 latency {canary_p95_latency*1000:.0f}ms > 500ms")

        return {"all_passed": len(failures) == 0, "failures": failures}

    def rollback(self, reason: str):
        """Immediately shift all traffic back to production model."""
        logger.critical(f"ROLLBACK: {reason}")
        self.current_phase = RolloutPhase.SHADOW
        self.phase_start_time = time.time()
        # In Kubernetes: kubectl rollout undo deployment/model-serving
```

---

## Experiment Analysis (Post-Experiment)

```python
import pandas as pd
from scipy import stats

def analyze_experiment(
    df: pd.DataFrame,  # columns: variant, outcome, timestamp
    primary_metric: str = "outcome",
    alpha: float = 0.05
) -> dict:
    """Full experiment analysis with lift, CI, and recommendation."""
    control = df[df["variant"] == "control"][primary_metric]
    treatment = df[df["variant"] == "treatment"][primary_metric]

    # T-test for continuous metrics, proportion test for binary
    if df[primary_metric].nunique() == 2:
        # Binary outcome (conversion)
        n_c, s_c = len(control), control.sum()
        n_t, s_t = len(treatment), treatment.sum()
        _, p_value = stats.proportions_ztest([s_c, s_t], [n_c, n_t])
        ctrl_rate, treat_rate = s_c / n_c, s_t / n_t
        relative_lift = (treat_rate - ctrl_rate) / ctrl_rate
    else:
        # Continuous outcome (revenue, time-on-site)
        t_stat, p_value = stats.ttest_ind(control, treatment)
        ctrl_rate, treat_rate = control.mean(), treatment.mean()
        relative_lift = (treat_rate - ctrl_rate) / ctrl_rate

    return {
        "control_mean": ctrl_rate,
        "treatment_mean": treat_rate,
        "relative_lift": relative_lift,
        "p_value": p_value,
        "statistically_significant": p_value < alpha,
        "n_control": len(control),
        "n_treatment": len(treatment),
        "recommendation": "ship" if p_value < alpha and relative_lift > 0 else "hold",
    }
```

---

## Dependencies

```bash
pip install scipy numpy pandas
# Metrics and monitoring
pip install prometheus-client grafana-api
```
