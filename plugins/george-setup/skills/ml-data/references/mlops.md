# MLOps Reference

## Experiment Tracking with MLflow

### Setup

```python
import mlflow
import mlflow.sklearn
import mlflow.pytorch

# Local tracking (default)
mlflow.set_tracking_uri("./mlruns")  # or "sqlite:///mlflow.db"

# Remote tracking server
mlflow.set_tracking_uri("http://mlflow-server:5000")

mlflow.set_experiment("my-experiment")  # Creates if not exists
```

### Logging Runs

```python
with mlflow.start_run(run_name="experiment-v1"):
    # Log hyperparameters
    mlflow.log_params({
        "learning_rate": 1e-3,
        "batch_size": 32,
        "epochs": 50,
        "model": "resnet50",
        "optimizer": "adamw",
    })

    # Log metrics (per step for time series)
    for epoch in range(epochs):
        train_loss, val_loss = train_and_eval(...)
        mlflow.log_metrics({
            "train_loss": train_loss,
            "val_loss": val_loss,
            "val_accuracy": val_acc,
        }, step=epoch)

    # Log artifacts (files)
    mlflow.log_artifact("confusion_matrix.png")
    mlflow.log_artifact("feature_importance.csv")

    # Log model
    mlflow.sklearn.log_model(
        sk_model=model,
        artifact_path="model",
        registered_model_name="my-classifier",  # Registers in Model Registry
    )

    # Log tags
    mlflow.set_tags({
        "data_version": "v2",
        "author": "george",
        "git_commit": subprocess.check_output(["git", "rev-parse", "HEAD"]).decode().strip(),
    })
```

### Querying Runs

```python
import mlflow
from mlflow.tracking import MlflowClient

client = MlflowClient()

# Search runs with filters
runs = mlflow.search_runs(
    experiment_names=["my-experiment"],
    filter_string="metrics.val_accuracy > 0.9 AND params.model = 'resnet50'",
    order_by=["metrics.val_accuracy DESC"],
    max_results=10,
)
print(runs[["run_id", "metrics.val_accuracy", "params.learning_rate"]])

# Load best model
best_run = runs.iloc[0]
model = mlflow.sklearn.load_model(f"runs:/{best_run.run_id}/model")
```

### Model Registry

```python
client = MlflowClient()

# Transition model stages
client.transition_model_version_stage(
    name="my-classifier",
    version=3,
    stage="Production",  # None → Staging → Production → Archived
)

# Load production model
model = mlflow.pyfunc.load_model("models:/my-classifier/Production")
```

---

## Weights & Biases (W&B)

```python
import wandb

wandb.init(
    project="my-project",
    name="experiment-v1",
    config={
        "learning_rate": 1e-3,
        "batch_size": 32,
        "epochs": 50,
    },
    tags=["baseline", "resnet50"],
)

for epoch in range(config.epochs):
    metrics = train_epoch(...)
    wandb.log({"train_loss": metrics["loss"], "val_accuracy": metrics["acc"]}, step=epoch)

wandb.save("model.pt")  # Upload artifact
wandb.finish()

# Sweeps (hyperparameter search)
sweep_config = {
    "method": "bayes",
    "metric": {"name": "val_accuracy", "goal": "maximize"},
    "parameters": {
        "learning_rate": {"min": 1e-5, "max": 1e-2, "distribution": "log_uniform_values"},
        "batch_size": {"values": [16, 32, 64]},
        "dropout": {"min": 0.1, "max": 0.5},
    },
}
sweep_id = wandb.sweep(sweep_config, project="my-project")
wandb.agent(sweep_id, function=train_fn, count=50)
```

---

## Model Serving

### FastAPI + Uvicorn (Lightweight, Any Model)

```python
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import torch
import numpy as np
from typing import Union
import uvicorn

app = FastAPI(title="Model API", version="1.0")

# Load once at startup
model = None

@app.on_event("startup")
async def load_model():
    global model
    model = torch.load("model.pt", map_location="cpu")
    model.eval()

class PredictRequest(BaseModel):
    features: list[float]
    return_probabilities: bool = False

class PredictResponse(BaseModel):
    prediction: Union[int, float]
    probabilities: list[float] | None = None
    model_version: str = "1.0.0"

@app.post("/predict", response_model=PredictResponse)
async def predict(request: PredictRequest):
    try:
        x = torch.tensor([request.features], dtype=torch.float32)
        with torch.no_grad():
            logits = model(x)
            probs = torch.softmax(logits, dim=-1).numpy()[0].tolist()
            pred = int(np.argmax(probs))
        return PredictResponse(
            prediction=pred,
            probabilities=probs if request.return_probabilities else None,
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health():
    return {"status": "healthy", "model_loaded": model is not None}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080, workers=4)
```

### BentoML (Production Model Serving)

```python
import bentoml
import numpy as np

# Save model to BentoML store
bentoml.sklearn.save_model("my_classifier", sklearn_model, signatures={"predict": {"batchable": True}})

# Define service
svc = bentoml.Service("classifier_service", runners=[
    bentoml.sklearn.get("my_classifier:latest").to_runner()
])

@svc.api(input=bentoml.io.NumpyNdarray(), output=bentoml.io.NumpyNdarray())
async def classify(input_data: np.ndarray) -> np.ndarray:
    return await runner.predict.async_run(input_data)

# bentoml serve service:svc --port 3000
# bentoml build  # Build Bento (deployable artifact)
# bentoml containerize classifier_service:latest  # Docker image
```

### ONNX Export (Cross-Platform Inference)

```python
import torch.onnx

# Export PyTorch model to ONNX
dummy_input = torch.randn(1, 3, 224, 224)
torch.onnx.export(
    model,
    dummy_input,
    "model.onnx",
    export_params=True,
    opset_version=17,
    input_names=["input"],
    output_names=["output"],
    dynamic_axes={"input": {0: "batch_size"}, "output": {0: "batch_size"}},
)

# ONNX Runtime inference (2-5x faster than PyTorch on CPU)
import onnxruntime as ort
import numpy as np

sess = ort.InferenceSession("model.onnx", providers=["CPUExecutionProvider"])
input_name = sess.get_inputs()[0].name
result = sess.run(None, {input_name: np.random.randn(1, 3, 224, 224).astype(np.float32)})
```

---

## CI/CD for ML

### GitHub Actions Pipeline

```yaml
# .github/workflows/ml-pipeline.yml
name: ML Training Pipeline

on:
  push:
    paths:
      - "src/**"
      - "configs/**"

jobs:
  train-and-evaluate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Install dependencies
        run: |
          pip install uv
          uv pip install -r requirements.txt --system

      - name: Validate data
        run: python scripts/validate_data.py --data-path data/processed/

      - name: Train model
        run: python src/train.py --config configs/train.yaml
        env:
          MLFLOW_TRACKING_URI: ${{ secrets.MLFLOW_URI }}
          MLFLOW_TRACKING_TOKEN: ${{ secrets.MLFLOW_TOKEN }}

      - name: Evaluate model
        run: python scripts/evaluate.py --threshold 0.85
        # Exits non-zero if accuracy < threshold → fails pipeline

      - name: Register model if improved
        run: python scripts/register_model.py --stage Staging
        env:
          MLFLOW_TRACKING_URI: ${{ secrets.MLFLOW_URI }}

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: model-artifacts
          path: artifacts/
```

### Evaluation Gate Script

```python
# scripts/evaluate.py
import mlflow
import sys
import argparse
from sklearn.metrics import accuracy_score, f1_score

parser = argparse.ArgumentParser()
parser.add_argument("--threshold", type=float, default=0.85)
args = parser.parse_args()

# Load latest run from current experiment
client = mlflow.tracking.MlflowClient()
run = client.search_runs(experiment_ids=["1"], order_by=["start_time DESC"], max_results=1)[0]
val_accuracy = run.data.metrics["val_accuracy"]

print(f"Val accuracy: {val_accuracy:.4f} (threshold: {args.threshold})")

if val_accuracy < args.threshold:
    print(f"FAILED: accuracy {val_accuracy:.4f} < threshold {args.threshold}")
    sys.exit(1)

print("PASSED: Model meets quality threshold")
```

---

## Model Monitoring

### Data Drift Detection

```python
from scipy.stats import ks_2samp, chi2_contingency
import numpy as np
import pandas as pd

def detect_feature_drift(
    reference: pd.DataFrame,
    current: pd.DataFrame,
    numerical_threshold: float = 0.05,
    categorical_threshold: float = 0.05,
) -> dict[str, dict]:
    """
    KS test for continuous features, Chi-squared for categorical.
    Returns dict of feature -> {drifted: bool, p_value: float, stat: float}
    """
    results = {}
    for col in reference.columns:
        if reference[col].dtype in (float, "float64", "float32"):
            stat, p_value = ks_2samp(reference[col].dropna(), current[col].dropna())
            results[col] = {"drifted": p_value < numerical_threshold, "p_value": p_value, "statistic": stat, "test": "ks"}
        else:
            # Chi-squared for categorical
            ref_counts = reference[col].value_counts()
            cur_counts = current[col].value_counts()
            all_cats = set(ref_counts.index) | set(cur_counts.index)
            observed = np.array([[ref_counts.get(c, 0) for c in all_cats],
                                  [cur_counts.get(c, 0) for c in all_cats]])
            stat, p_value, _, _ = chi2_contingency(observed)
            results[col] = {"drifted": p_value < categorical_threshold, "p_value": p_value, "statistic": stat, "test": "chi2"}
    return results


def detect_prediction_drift(
    reference_preds: np.ndarray,
    current_preds: np.ndarray,
    threshold: float = 0.05,
) -> dict:
    """Check if prediction distribution has shifted."""
    stat, p_value = ks_2samp(reference_preds, current_preds)
    return {
        "drifted": p_value < threshold,
        "p_value": p_value,
        "reference_mean": float(reference_preds.mean()),
        "current_mean": float(current_preds.mean()),
    }
```

### Performance Monitoring with Logging

```python
import logging
import time
from dataclasses import dataclass, asdict
import json

logger = logging.getLogger("model_monitor")

@dataclass
class PredictionLog:
    timestamp: float
    input_hash: str
    prediction: float | int
    confidence: float
    latency_ms: float
    model_version: str

def logged_predict(model, features, model_version: str = "1.0"):
    start = time.perf_counter()
    prediction, confidence = model.predict_with_confidence(features)
    latency_ms = (time.perf_counter() - start) * 1000

    log = PredictionLog(
        timestamp=time.time(),
        input_hash=hash(str(features)),
        prediction=prediction,
        confidence=confidence,
        latency_ms=latency_ms,
        model_version=model_version,
    )
    logger.info(json.dumps(asdict(log)))  # Ship to ELK/Datadog/CloudWatch
    return prediction
```

### Evidently AI (Production Drift Reports)

```python
from evidently.report import Report
from evidently.metrics import DatasetDriftMetric, DataDriftTable
from evidently.metric_preset import DataDriftPreset, TargetDriftPreset

report = Report(metrics=[DataDriftPreset(), TargetDriftPreset()])
report.run(reference_data=reference_df, current_data=current_df)
report.save_html("drift_report.html")

# Programmatic check
result = report.as_dict()
dataset_drift = result["metrics"][0]["result"]["dataset_drift"]
drifted_features = result["metrics"][0]["result"]["number_of_drifted_columns"]
print(f"Dataset drift detected: {dataset_drift} | Drifted features: {drifted_features}")
```

---

## Feature Stores (Feast)

```python
# feature_store.yaml
# project: my_project
# registry: data/registry.db
# provider: local
# online_store:
#   type: sqlite
#   path: data/online_store.db

from feast import FeatureStore, Entity, FeatureView, Field, FileSource
from feast.types import Float32, Int64
from datetime import timedelta

# Define feature view
customer_fv = FeatureView(
    name="customer_features",
    entities=["customer_id"],
    ttl=timedelta(days=1),
    source=FileSource(path="data/customer_features.parquet", timestamp_field="event_timestamp"),
    schema=[
        Field(name="age", dtype=Int64),
        Field(name="purchase_count_30d", dtype=Int64),
        Field(name="avg_order_value", dtype=Float32),
    ],
)

# Materialize (write to online store)
store = FeatureStore(repo_path=".")
store.materialize_incremental(end_date=datetime.now())

# Online retrieval (low latency, for real-time serving)
features = store.get_online_features(
    features=["customer_features:age", "customer_features:purchase_count_30d"],
    entity_rows=[{"customer_id": "user_123"}],
).to_dict()

# Historical retrieval (for training)
training_df = store.get_historical_features(
    entity_df=entity_df,  # DataFrame with entity keys + timestamps
    features=["customer_features:age", "customer_features:purchase_count_30d"],
).to_df()
```

---

## Containerization for ML

### Dockerfile with CUDA

```dockerfile
# Multi-stage build for smaller production image
FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04 AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y python3.11 python3-pip && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir uv && \
    uv pip install --system -r requirements.txt

COPY src/ ./src/
COPY configs/ ./configs/
COPY artifacts/model.pt ./artifacts/

EXPOSE 8080
CMD ["uvicorn", "src.serving.app:app", "--host", "0.0.0.0", "--port", "8080", "--workers", "2"]
```

```dockerfile
# CPU-only serving (much smaller, no CUDA)
FROM python:3.11-slim AS base

WORKDIR /app
COPY requirements-serve.txt .
RUN pip install --no-cache-dir -r requirements-serve.txt

COPY src/serving/ ./src/serving/
COPY artifacts/model.onnx ./artifacts/  # ONNX for CPU serving

EXPOSE 8080
CMD ["uvicorn", "src.serving.app:app", "--host", "0.0.0.0", "--port", "8080"]
```

### Docker Compose for Local Dev

```yaml
# docker-compose.yml
services:
  mlflow:
    image: ghcr.io/mlflow/mlflow:v2.9.0
    ports:
      - "5000:5000"
    volumes:
      - mlflow_data:/mlruns
    command: mlflow server --host 0.0.0.0 --port 5000

  model-api:
    build: .
    ports:
      - "8080:8080"
    environment:
      - MLFLOW_TRACKING_URI=http://mlflow:5000
    depends_on:
      - mlflow
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]

volumes:
  mlflow_data:
```

---

## Model Versioning and A/B Deployment

### Traffic Splitting with Nginx

```nginx
upstream model_v1 {
    server model-v1:8080;
}
upstream model_v2 {
    server model-v2:8080 weight=10;  # 10% traffic
    server model-v1:8080 weight=90;  # 90% traffic
}

server {
    location /predict {
        proxy_pass http://model_v2;  # Weighted round-robin
    }
}
```

### Shadow Deployment Pattern

```python
import asyncio
import httpx
import logging

logger = logging.getLogger(__name__)

async def shadow_predict(request_data: dict, production_url: str, shadow_url: str) -> dict:
    """Send to production (return result) and shadow (log result, ignore) simultaneously."""
    async with httpx.AsyncClient() as client:
        prod_task = client.post(production_url, json=request_data)
        shadow_task = client.post(shadow_url, json=request_data)

        prod_response, shadow_response = await asyncio.gather(prod_task, shadow_task, return_exceptions=True)

        if isinstance(shadow_response, Exception):
            logger.warning(f"Shadow model failed: {shadow_response}")
        else:
            # Log shadow result for comparison, but don't return it
            logger.info({"prod": prod_response.json(), "shadow": shadow_response.json()})

        return prod_response.json()  # Always return production result
```

---

## Batch vs Real-Time Inference

| Aspect | Batch Inference | Real-Time Inference |
|---|---|---|
| Latency | Minutes to hours | <100ms |
| Throughput | Very high (millions/day) | Moderate (thousands/sec) |
| Cost | Low (spot instances, off-peak) | Higher (always-on) |
| Complexity | Simple | Requires serving infrastructure |
| Use cases | Nightly scoring, ETL enrichment | APIs, user-facing features |
| Tools | Spark, Ray, Airflow | FastAPI, TorchServe, Triton |

### Batch Inference with Ray

```python
import ray
from ray import data

@ray.remote
class ModelActor:
    def __init__(self, model_path: str):
        import torch
        self.model = torch.load(model_path)
        self.model.eval()

    def predict_batch(self, batch: dict) -> dict:
        import torch
        x = torch.tensor(batch["features"])
        with torch.no_grad():
            preds = self.model(x).numpy()
        return {"predictions": preds}

ray.init()
ds = ray.data.read_parquet("s3://bucket/features/")
predictions = ds.map_batches(
    ModelActor,
    fn_constructor_kwargs={"model_path": "model.pt"},
    batch_size=256,
    num_gpus=0.5,  # Fractional GPU allocation
    concurrency=4,
)
predictions.write_parquet("s3://bucket/predictions/")
```
