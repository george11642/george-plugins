---
name: ml-data
description: Use this skill for machine learning, data science, and data engineering. Covers ML models (classification, regression, clustering, neural networks), ETL pipelines (Airflow, batch processing), feature engineering, model training, LLM/RAG/embedding systems, MLOps, experiment tracking, and data preprocessing with pandas/polars/numpy. Frameworks: PyTorch, TensorFlow, scikit-learn, HuggingFace, MLflow, Weights & Biases. Key terms: CNN, transformer, attention, transfer learning, LoRA, QLoRA, PEFT, RAG, hybrid RAG, BM25, reranking, ColBERT, RRF, pgvector, Pinecone, Chroma, FAISS, TorchServe, BentoML, vLLM, ONNX, data drift, PSI, Evidently, feature store, Feast, CI/CD for ML, guardrail metrics, A/B testing, canary rollout, shadow mode, Thompson sampling, nested cross-validation, McNemar test, bootstrap CI, GPU training, mixed precision, DataParallel, BERT, ResNet, ViT, GAN, VAE, diffusion models, BLEU, ROUGE, BERTScore, LLM-as-judge, prompt engineering, chain-of-thought, few-shot, DVC, Delta Lake, reproducibility. Not for: data visualization, general statistics, web scraping, or non-ML engineering.
---

# ML & Data Skill

## Task Router

| Domain | Reference | When to use |
|--------|-----------|-------------|
| Data Engineering | `references/data-engineering.md` | pandas, polars, ETL, pipelines, data validation, ingestion |
| Classical ML | `references/classical-ml.md` | scikit-learn, feature engineering, classification, regression, clustering |
| Deep Learning | `references/deep-learning.md` | PyTorch, neural networks, GPU training, transfer learning, CNNs, transformers |
| LLM Patterns | `references/llm-patterns.md` | RAG, embeddings, fine-tuning, prompt engineering, LLM evaluation |
| MLOps | `references/mlops.md` | Model serving, experiment tracking, CI/CD for ML, monitoring, drift detection |
| Vector Databases | `references/vector-databases.md` | pgvector, Pinecone, Chroma, FAISS, embedding storage & retrieval |
| ML Experimentation | `references/ml-experimentation.md` | hypothesis testing, model comparison, statistical significance, guardrail metrics, nested CV, reproducibility |
| Advanced RAG | `references/advanced-rag.md` | hybrid retrieval, reranking, multi-vector, HyDE, RAPTOR, long-context RAG, agentic RAG |
| Model Serving | `references/model-serving.md` | TorchServe, BentoML, vLLM, ONNX Runtime, production inference, batching, GPU serving |
| Monitoring & Drift | `references/monitoring-drift.md` | data drift, model monitoring, Evidently, PSI, concept drift, prediction distribution, alerting |
| PEFT & Fine-tuning | `references/peft-fine-tuning.md` | LoRA, QLoRA, PEFT, adapter tuning, HuggingFace PEFT, parameter-efficient fine-tuning |
| Data Versioning | `references/data-versioning.md` | DVC, Delta Lake, dataset lineage, reproducible data pipelines, data version control |
| Online Evaluation | `references/online-evaluation.md` | A/B testing, canary rollout, shadow mode, guardrail metrics, traffic splitting, sequential testing, Thompson sampling, online evaluation |

## Before Starting

Answer these questions before writing any code:

1. **What problem type?** Classification, regression, clustering, generation, retrieval, transformation?
2. **What data size?** Fits in memory (<10GB) → pandas/scikit-learn. Larger → polars/Spark/streaming.
3. **What deployment target?** Script, API, batch job, edge device, serverless?
4. **Do you need reproducibility?** Set random seeds, pin dependency versions, track experiments.
5. **Is there an existing model that solves this?** Check HuggingFace, pretrained models before training from scratch.

## Quick Reference

### Pandas Essentials
```python
# Read with explicit dtypes — never let pandas guess on production data
df = pd.read_csv("data.csv", dtype={"id": str, "value": float}, parse_dates=["ts"])

# Chain operations — readable, debuggable
result = (
    df.pipe(clean_nulls)
      .assign(feature=lambda d: d["a"] / d["b"])
      .query("feature > 0.5")
      .groupby("category")
      .agg(mean_val=("value", "mean"), count=("value", "size"))
)
```

### Common Scikit-learn Pattern
```python
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import cross_val_score

# Always use pipelines — prevent data leakage by design
pipe = Pipeline([
    ("scaler", StandardScaler()),
    ("model", LogisticRegression(random_state=42)),
])
scores = cross_val_score(pipe, X, y, cv=5, scoring="f1_macro")
```

## Decision Trees

### Classical ML vs Deep Learning
- Tabular data with <100k rows → classical ML (gradient boosting wins most benchmarks)
- Tabular data with >1M rows + complex interactions → consider deep learning
- Images, audio, video → deep learning (pretrained models first)
- Text classification with <10k examples → fine-tuned transformer or even TF-IDF + classical
- Text generation → LLM (fine-tune or prompt)

### Which Framework?
- Tabular ML → scikit-learn + XGBoost/LightGBM
- Deep learning research → PyTorch
- Production serving at scale → PyTorch + TorchServe or ONNX Runtime
- LLM fine-tuning → HuggingFace Transformers + PEFT
- LLM inference → vLLM, Ollama, or API providers

### Fine-tune vs Prompt Engineering
- Try prompting first — it is cheaper, faster, and easier to iterate
- Fine-tune when: consistent output format needed, domain-specific knowledge, latency matters, cost at scale
- Use few-shot examples before fine-tuning — often sufficient
- RAG before fine-tuning for knowledge tasks — fine-tuning teaches style, not facts

## Core Principles

1. **Data quality > model complexity.** Clean data with logistic regression beats dirty data with transformers. Spend 80% of time on data.
2. **Reproducibility is non-negotiable.** Pin seeds (`random_state=42`, `torch.manual_seed`), pin versions (`pip freeze`), log parameters.
3. **Track every experiment.** Use MLflow, W&B, or even a CSV. Log: params, metrics, data version, code version.
4. **Start simple, add complexity only when measured.** Baseline with simple model first. Justify every layer of complexity with metrics.
5. **Validate like production.** Time-based splits for time series. Stratified splits for imbalanced classes. Never shuffle time series.
6. **Version your data.** DVC, Delta Lake, or even checksums. Model without data version is unreproducible.
7. **Fail fast on data issues.** Validate schemas at ingestion (pandera, Great Expectations). Catch problems before they propagate.

## Anti-Patterns

| Anti-pattern | Why it's dangerous | Fix |
|---|---|---|
| Training on test data | Overfitting, useless metrics | Strict train/val/test split before any preprocessing |
| Data leakage | Future info in features inflates metrics | Fit scalers/encoders on train only, apply to test |
| Premature GPU | Wastes time, harder to debug | Get pipeline working on CPU with small data first |
| No baseline | Can't tell if complex model adds value | Always start with simple model (mean predictor, logistic regression) |
| Overfitting to validation | Tuning until val looks good ≠ generalization | Hold out final test set, touch it once |
| Ignoring class imbalance | Accuracy is misleading (99% by predicting majority) | Use F1, AUROC, precision-recall; stratified splits; SMOTE with caution |
| Notebook spaghetti | Unreproducible, untestable | Extract functions to .py modules, use notebooks for exploration only |
| Giant monolithic pipeline | Hard to debug, slow iteration | Break into stages: ingest → validate → feature → train → evaluate |
| Deploying without monitoring | Silent model degradation | Track prediction distributions, feature drift, latency |

## Environment Setup

```bash
# Use uv for fast dependency management
uv venv .venv && source .venv/bin/activate
uv pip install pandas scikit-learn torch matplotlib jupyter

# Pin everything for reproducibility
uv pip freeze > requirements.txt
```

## Project Structure

```
project/
  data/raw/            # immutable raw data
  data/processed/      # cleaned, feature-engineered
  notebooks/           # exploration only
  src/
    data/              # loading, cleaning, validation
    features/          # feature engineering
    models/            # model definitions
    training/          # training loops, hyperparameter search
    evaluation/        # metrics, visualization
    serving/           # inference API
  configs/             # hyperparameters, data paths
  experiments/         # MLflow/W&B logs
  tests/               # unit + integration tests
```
