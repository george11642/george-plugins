# Model Serving: vLLM, BentoML, TorchServe, ONNX

## Framework Selection Guide

| Framework | Best for | Not for |
|-----------|----------|---------|
| **vLLM** | LLM inference at scale, OpenAI-compatible API | Non-LLM models, edge deployment |
| **Ollama** | Local LLM development, single-user | High-concurrency production |
| **TorchServe** | PyTorch model serving, multi-model, custom logic | Non-PyTorch models |
| **BentoML** | Framework-agnostic, cloud-native, complex pipelines | Simple single-model APIs |
| **ONNX Runtime** | Cross-framework, CPU optimization, edge | Dynamic control flow models |
| **Triton (NVIDIA)** | Multi-framework, high-GPU-throughput, batching | CPU-only, simple deployments |

**Decision rule:**
- Serving an LLM (7B+ parameters) → vLLM
- Serving a PyTorch classification/regression model → TorchServe or BentoML
- Need cross-framework or CPU optimization → ONNX Runtime
- Need cloud deployment with auto-scaling and batching → BentoML
- Local dev/prototyping LLMs → Ollama

---

## vLLM (Production LLM Serving)

vLLM uses **PagedAttention** to manage KV cache memory in non-contiguous blocks, enabling continuous batching and ~3-5x higher throughput vs naive PyTorch inference.

### Server Launch

```bash
# Install
pip install vllm

# Serve a model with OpenAI-compatible API
vllm serve meta-llama/Llama-3.2-8B-Instruct \
    --port 8000 \
    --tensor-parallel-size 1 \        # number of GPUs for tensor parallelism
    --max-model-len 8192 \
    --gpu-memory-utilization 0.90 \   # fraction of GPU memory to use
    --quantization awq                # awq | gptq | bitsandbytes | fp8

# For multi-GPU (tensor parallelism)
vllm serve meta-llama/Llama-3.1-70B-Instruct \
    --tensor-parallel-size 4 \
    --port 8000
```

### Python Client (OpenAI-compatible)

```python
from openai import AsyncOpenAI
import asyncio

client = AsyncOpenAI(
    base_url="http://localhost:8000/v1",
    api_key="not-needed",  # vLLM doesn't require auth by default
)

async def generate(prompt: str) -> str:
    response = await client.chat.completions.create(
        model="meta-llama/Llama-3.2-8B-Instruct",
        messages=[{"role": "user", "content": prompt}],
        max_tokens=512,
        temperature=0.7,
    )
    return response.choices[0].message.content

# Streaming response
async def stream_generate(prompt: str):
    stream = await client.chat.completions.create(
        model="meta-llama/Llama-3.2-8B-Instruct",
        messages=[{"role": "user", "content": prompt}],
        stream=True,
        max_tokens=512,
    )
    async for chunk in stream:
        if chunk.choices[0].delta.content:
            yield chunk.choices[0].delta.content
```

### Batch Inference with vLLM Python API

```python
from vllm import LLM, SamplingParams

llm = LLM(model="meta-llama/Llama-3.2-8B-Instruct", gpu_memory_utilization=0.9)
sampling_params = SamplingParams(temperature=0.8, top_p=0.95, max_tokens=256)

prompts = ["Tell me about machine learning.", "What is a transformer?"]
outputs = llm.generate(prompts, sampling_params)

for output in outputs:
    print(output.outputs[0].text)
```

### Quantization Options

| Method | Memory reduction | Quality loss | Speed |
|--------|-----------------|--------------|-------|
| AWQ | 4x | Minimal | Fast |
| GPTQ | 4x | Small | Medium |
| bitsandbytes | 4x (int8) / 8x (int4) | Small | Medium |
| FP8 | 2x | Negligible | Fastest |

```bash
# Using pre-quantized AWQ model
vllm serve TheBloke/Llama-2-7B-Chat-AWQ --quantization awq
```

---

## BentoML (Framework-Agnostic Serving)

BentoML provides a unified API for serving any model with production features: batching, async, containerization.

### Basic Service

```python
# service.py
import bentoml
import numpy as np
from pydantic import BaseModel

class ClassificationRequest(BaseModel):
    features: list[float]

class ClassificationResponse(BaseModel):
    label: str
    confidence: float

@bentoml.service(
    resources={"cpu": "2", "memory": "4Gi"},
    traffic={"timeout": 30},
)
class ClassifierService:

    def __init__(self):
        # Load model on startup
        self.model = bentoml.sklearn.load_model("iris_classifier:latest")
        self.label_map = {0: "setosa", 1: "versicolor", 2: "virginica"}

    @bentoml.api
    def predict(self, request: ClassificationRequest) -> ClassificationResponse:
        features = np.array([request.features])
        probas = self.model.predict_proba(features)[0]
        label_idx = int(np.argmax(probas))
        return ClassificationResponse(
            label=self.label_map[label_idx],
            confidence=float(probas[label_idx])
        )
```

### Async API with Batching

```python
import bentoml
from bentoml import Runnable

@bentoml.service
class EmbeddingService:

    def __init__(self):
        from sentence_transformers import SentenceTransformer
        self.model = SentenceTransformer("BAAI/bge-small-en-v1.5")

    @bentoml.api(batchable=True, max_batch_size=32, max_latency_ms=100)
    async def embed(self, texts: list[str]) -> np.ndarray:
        """Automatically batches concurrent requests up to max_batch_size."""
        return self.model.encode(texts, normalize_embeddings=True)
```

### Save and Load Models

```python
import bentoml
from sklearn.ensemble import RandomForestClassifier

# Save a model to BentoML model store
clf = RandomForestClassifier(n_estimators=100)
clf.fit(X_train, y_train)

saved_model = bentoml.sklearn.save_model(
    "iris_classifier",
    clf,
    signatures={"predict": {"batchable": True}},
    metadata={"accuracy": 0.97, "training_data": "iris_v2"}
)
print(f"Model saved: {saved_model.tag}")

# Load model
model = bentoml.sklearn.load_model("iris_classifier:latest")
```

### Containerize and Deploy

```bash
# Build a Bento (self-contained deployable artifact)
bentoml build

# Containerize (creates Docker image)
bentoml containerize iris_classifier_service:latest

# Run locally
docker run -p 3000:3000 iris_classifier_service:latest

# Deploy to BentoCloud
bentoml deploy iris_classifier_service:latest --name production
```

---

## TorchServe (PyTorch Models)

TorchServe packages PyTorch models as `.mar` files and serves them with configurable batching, versioning, and metrics.

### Package a Model

```bash
# Install
pip install torchserve torch-model-archiver

# Archive model (creates model.mar)
torch-model-archiver \
    --model-name my_model \
    --version 1.0 \
    --model-file model.py \          # your nn.Module definition
    --serialized-file model.pt \     # torch.save() output
    --handler handler.py \           # custom handler (or use built-in: image_classifier)
    --export-path model_store/
```

### Custom Handler

```python
# handler.py
import torch
import json
from ts.torch_handler.base_handler import BaseHandler

class CustomHandler(BaseHandler):

    def initialize(self, context):
        """Load model on startup."""
        super().initialize(context)
        self.model.eval()
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.model = self.model.to(self.device)

    def preprocess(self, data):
        """Transform raw input to model input tensor."""
        inputs = []
        for row in data:
            payload = row.get("data") or row.get("body")
            if isinstance(payload, (bytes, bytearray)):
                payload = json.loads(payload)
            tensor = torch.tensor(payload["features"], dtype=torch.float32)
            inputs.append(tensor)
        return torch.stack(inputs).to(self.device)

    def inference(self, data):
        """Run model inference."""
        with torch.no_grad():
            return self.model(data)

    def postprocess(self, inference_output):
        """Transform model output to API response."""
        probas = torch.softmax(inference_output, dim=1)
        predictions = torch.argmax(probas, dim=1)
        return [
            {"prediction": int(pred), "confidence": float(prob.max())}
            for pred, prob in zip(predictions, probas)
        ]
```

### Start Server and Query

```bash
# Start TorchServe
torchserve --start --model-store model_store --models my_model=my_model.mar

# Query
curl -X POST http://localhost:8080/predictions/my_model \
    -H "Content-Type: application/json" \
    -d '{"features": [5.1, 3.5, 1.4, 0.2]}'

# Stop
torchserve --stop
```

### GPU Batching Configuration (config.properties)

```
# config.properties
default_workers_per_model=1
job_queue_size=1000
batch_size=8           # max batch size
max_batch_delay=100    # ms to wait to fill a batch
default_response_timeout=120
```

---

## ONNX Runtime (Cross-Framework Optimization)

Export PyTorch models to ONNX for optimized inference, especially on CPU (2-5x speedup with quantization).

### Export from PyTorch

```python
import torch
import torch.nn as nn

class MyModel(nn.Module):
    def __init__(self, input_dim: int, output_dim: int):
        super().__init__()
        self.layers = nn.Sequential(
            nn.Linear(input_dim, 128),
            nn.ReLU(),
            nn.Linear(128, output_dim)
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.layers(x)

model = MyModel(input_dim=10, output_dim=3)
model.eval()

# Export using new dynamo exporter (PyTorch 2.6+)
dummy_input = torch.randn(1, 10)
torch.onnx.export(
    model,
    (dummy_input,),
    "model.onnx",
    input_names=["features"],
    output_names=["logits"],
    dynamic_axes={"features": {0: "batch_size"}, "logits": {0: "batch_size"}},
    dynamo=False,  # set True for PyTorch 2.6+ dynamo exporter
    opset_version=17,
)
```

### ONNX Runtime Inference

```python
import onnxruntime as ort
import numpy as np

# Create session with optimization
session_options = ort.SessionOptions()
session_options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
session_options.intra_op_num_threads = 4

session = ort.InferenceSession(
    "model.onnx",
    sess_options=session_options,
    providers=["CUDAExecutionProvider", "CPUExecutionProvider"]  # GPU with CPU fallback
)

# Inference
input_data = np.random.randn(32, 10).astype(np.float32)
outputs = session.run(None, {"features": input_data})
logits = outputs[0]
```

### INT8 Quantization (CPU Speedup)

```python
from onnxruntime.quantization import quantize_dynamic, QuantType

# Dynamic quantization (no calibration data needed)
quantize_dynamic(
    model_input="model.onnx",
    model_output="model_int8.onnx",
    weight_type=QuantType.QInt8,
)

# Load quantized model — typically 2-4x faster on CPU, 4x smaller
session = ort.InferenceSession("model_int8.onnx")
```

**Performance benchmarks (typical):**
- PyTorch FP32 on CPU: 1x baseline
- ONNX Runtime FP32: 1.5-2x speedup
- ONNX Runtime INT8: 2-5x speedup vs PyTorch baseline
- GPU (CUDA EP): 10-50x vs CPU baseline

---

## Feature Store Integration (Online Serving)

Ensuring training-serving consistency: the same features used during training must be computed at inference time.

### Feast (Open-Source Feature Store)

```python
from feast import FeatureStore
import pandas as pd
from datetime import datetime

store = FeatureStore(repo_path="feature_repo/")

# Online retrieval at serving time — low latency (Redis backend)
entity_rows = [{"user_id": "user_123"}]
features = store.get_online_features(
    features=[
        "user_stats:total_purchases",
        "user_stats:avg_order_value",
        "user_stats:days_since_last_purchase",
    ],
    entity_rows=entity_rows,
).to_dict()

# Features are guaranteed to match training pipeline
prediction = model.predict([[
    features["total_purchases"][0],
    features["avg_order_value"][0],
    features["days_since_last_purchase"][0],
]])
```

### Training-Serving Consistency Pattern

```python
# WRONG: Different preprocessing in training vs serving
# Training: df["feature"] = df["value"] / df["value"].max()  # computed on full dataset
# Serving: feature = value / 1000  # hardcoded estimate — SKEW

# CORRECT: Same code path, same parameters
class FeatureTransformer:
    def fit(self, X):
        self.max_value = X["value"].max()
        return self

    def transform(self, X):
        return X["value"] / self.max_value  # same formula for train and serve

    def save(self, path):
        import joblib
        joblib.dump(self, path)

    @classmethod
    def load(cls, path):
        import joblib
        return joblib.load(path)

# Save during training, load during serving
transformer = FeatureTransformer().fit(train_df)
transformer.save("transformer.pkl")
```

---

## Batch vs Online Serving Decision Tree

```
Is response needed in real-time (<1 second)?
├── YES → Online serving (REST API, gRPC)
│         │
│         ├── Is it an LLM? → vLLM
│         ├── Is it a PyTorch model? → TorchServe or BentoML
│         ├── Is it a sklearn model? → BentoML or FastAPI + joblib
│         └── Need CPU optimization? → ONNX Runtime
│
└── NO → Batch serving
          │
          ├── Daily/hourly predictions on large datasets → Spark + MLflow
          ├── Small batches, simple models → pandas + sklearn + cron
          └── Complex pipelines with dependencies → Airflow DAG
```

---

## Production Checklist

- [ ] Health check endpoint (`/health`, `/ready`)
- [ ] Request logging with latency, model version, input hash
- [ ] Model versioning — never deploy without a version tag
- [ ] Graceful shutdown — drain in-flight requests before stopping
- [ ] Timeout configuration — set request timeout at load balancer and service level
- [ ] Resource limits — CPU/memory limits prevent OOM killing other services
- [ ] Warm-up — pre-load model weights before accepting traffic
- [ ] Metrics — expose Prometheus metrics (latency p50/p95/p99, error rate, batch size)

---

## Dependencies

```bash
pip install vllm bentoml torchserve torch-model-archiver onnxruntime feast
# GPU inference:
pip install vllm  # includes CUDA deps
pip install onnxruntime-gpu
```
