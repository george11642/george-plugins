---
name: ml-data-engineering
description: Use for ML model training, inference serving (vLLM, TorchServe, ONNX), data pipelines, RAG/LLM systems, and MLOps. Covers classification, regression, neural networks, ETL, feature engineering, vector databases, model deployment, experiment tracking. PyTorch, scikit-learn, HuggingFace, MLflow, W&B, FAISS, pgvector, Chroma, LoRA, QLoRA, PEFT, DVC, Delta Lake, Spark, Feast, Evidently, data drift, A/B testing.
---

# ML & Data Engineering

Master skill for machine learning, data science, and data engineering. Routes to specialized references by task type.

## Task Router

| Task | Reference | When to use |
|------|-----------|-------------|
| Data pipelines, pandas, polars, ETL, validation | [references/data-engineering.md](references/data-engineering.md) | Data loading, cleaning, transformation, schema validation |
| Classification, regression, clustering | [references/classical-ml.md](references/classical-ml.md) | scikit-learn, feature engineering, model selection |
| Neural networks, GPU training, CNNs, transformers | [references/deep-learning.md](references/deep-learning.md) | PyTorch, transfer learning, training loops |
| RAG, embeddings, prompt engineering, LLM eval | [references/llm-patterns.md](references/llm-patterns.md) | LLM integration, chain-of-thought, few-shot |
| Model serving, experiment tracking, CI/CD for ML | [references/mlops.md](references/mlops.md) | MLflow, W&B, deployment pipelines |
| pgvector, Pinecone, Chroma, FAISS | [references/vector-databases.md](references/vector-databases.md) | Embedding storage and retrieval |
| Model comparison, statistical significance | [references/ml-experimentation.md](references/ml-experimentation.md) | Hypothesis testing, nested CV, reproducibility |
| Hybrid retrieval, reranking, HyDE, RAPTOR | [references/advanced-rag.md](references/advanced-rag.md) | Multi-vector RAG, agentic RAG |
| TorchServe, BentoML, vLLM, ONNX Runtime | [references/model-serving.md](references/model-serving.md) | Production inference, batching, GPU serving |
| Data drift, model monitoring, Evidently | [references/monitoring-drift.md](references/monitoring-drift.md) | PSI, concept drift, prediction distribution |
| LoRA, QLoRA, adapter tuning, HuggingFace PEFT | [references/peft-fine-tuning.md](references/peft-fine-tuning.md) | Parameter-efficient fine-tuning |
| DVC, Delta Lake, dataset lineage | [references/data-versioning.md](references/data-versioning.md) | Reproducible data pipelines |
| A/B testing, canary rollout, shadow mode | [references/online-evaluation.md](references/online-evaluation.md) | Traffic splitting, sequential testing |

## Decision Trees

**Classical ML vs Deep Learning**: Tabular <100k rows → classical (gradient boosting). Images/audio/video → deep learning. Text <10k examples → fine-tuned transformer or TF-IDF + classical. Text generation → LLM.

**Fine-tune vs Prompt**: Try prompting first. Fine-tune when: consistent format needed, domain knowledge, latency matters, cost at scale. RAG before fine-tuning for knowledge tasks.

**Framework**: Tabular → scikit-learn + XGBoost/LightGBM. Deep learning → PyTorch. LLM fine-tuning → HuggingFace + PEFT. LLM inference → vLLM or API.

## Core Principles

1. **Data quality > model complexity** — clean data with logistic regression beats dirty data with transformers
2. **Reproducibility** — pin seeds, pin versions, track experiments (MLflow/W&B)
3. **Start simple** — baseline with simple model, justify complexity with metrics
4. **Validate like production** — time-based splits for time series, stratified for imbalanced
5. **Version your data** — DVC, Delta Lake, or checksums
6. **Fail fast on data issues** — validate schemas at ingestion (pandera, Great Expectations)

## Anti-Patterns

| Anti-pattern | Fix |
|---|---|
| Training on test data | Strict train/val/test split before preprocessing |
| Data leakage | Fit scalers on train only |
| No baseline | Start with simple model |
| Ignoring class imbalance | Use F1/AUROC, stratified splits |
| Notebook spaghetti | Extract to .py modules |
| Deploying without monitoring | Track prediction distributions, drift |

## Layer 3 Skills

| Skill | Use when |
|-------|----------|
| `data-engineering` | ETL pipelines, data validation, pandas/polars |
| `classical-ml` | scikit-learn, feature engineering, model selection |
| `deep-learning` | PyTorch, neural networks, GPU training |
| `llm-patterns` | RAG, embeddings, prompt engineering |
| `mlops` | Experiment tracking, model deployment, CI/CD |
| `vector-databases` | Embedding storage, similarity search |
| `advanced-rag` | Hybrid retrieval, reranking, agentic RAG |
| `model-serving` | Production inference, TorchServe, vLLM |
| `monitoring-drift` | Data drift detection, model monitoring |
| `peft-fine-tuning` | LoRA, QLoRA, adapter tuning |
| `data-versioning` | DVC, Delta Lake, dataset lineage |
| `online-evaluation` | A/B testing, canary rollout, shadow mode |
