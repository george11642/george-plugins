# Data Versioning: DVC, Delta Lake, and Reproducibility

## Why Version Data

Data versioning is as critical as code versioning for reproducible ML — yet most teams skip it until they're burned.

**Problems without data versioning:**
- Can't reproduce a model trained 3 months ago (data has been modified/augmented)
- Can't debug why model performance degraded — can't compare training datasets
- No audit trail for compliance ("what data trained the model in production?")
- Team members silently work with different versions of the same dataset
- "Works on my machine" applies to data, not just code

**What to version:**
- Raw datasets (before cleaning)
- Processed/feature-engineered datasets
- Train/val/test splits (exact splits, not just random seeds)
- Model checkpoints
- Evaluation results

---

## DVC (Data Version Control)

DVC uses Git to track data metadata (`.dvc` pointer files) while storing the actual data in a remote storage backend (S3, GCS, Azure Blob, SSH, etc.).

### Core Workflow

```bash
# Initialize DVC in a git repo
git init
dvc init
git add .dvc .dvcignore
git commit -m "Initialize DVC"

# Configure remote storage (S3 example)
dvc remote add -d myremote s3://my-bucket/ml-data
dvc remote modify myremote region us-east-1
git add .dvc/config
git commit -m "Configure DVC remote"

# Track a large dataset
dvc add data/raw/customers.csv          # creates data/raw/customers.csv.dvc
git add data/raw/customers.csv.dvc data/raw/.gitignore
git commit -m "Add customer dataset v1"

# Push data to remote storage
dvc push

# A colleague pulls both code and data
git pull
dvc pull                                # downloads data from remote
```

### The `.dvc` Pointer File

The `.dvc` file is tracked in git — it's tiny (~100 bytes) and records:
- MD5 hash of the data
- File path
- Remote storage location

```yaml
# data/raw/customers.csv.dvc
outs:
- md5: a1b2c3d4e5f6...
  size: 1234567890
  path: customers.csv
```

When you check out an older git commit and run `dvc checkout`, DVC restores the exact data version from cache.

### DVC Pipelines (dvc.yaml)

Define reproducible ML pipelines where each stage tracks its inputs, outputs, and parameters.

```yaml
# dvc.yaml
stages:
  prepare:
    cmd: python src/prepare.py
    deps:
      - src/prepare.py
      - data/raw/customers.csv
    params:
      - params.yaml:
          - prepare.test_size
          - prepare.random_seed
    outs:
      - data/processed/train.parquet
      - data/processed/val.parquet
      - data/processed/test.parquet

  train:
    cmd: python src/train.py
    deps:
      - src/train.py
      - data/processed/train.parquet
      - data/processed/val.parquet
    params:
      - params.yaml:
          - train.n_estimators
          - train.max_depth
          - train.learning_rate
    outs:
      - models/model.pkl
    metrics:
      - metrics/train_metrics.json:
          cache: false

  evaluate:
    cmd: python src/evaluate.py
    deps:
      - src/evaluate.py
      - models/model.pkl
      - data/processed/test.parquet
    metrics:
      - metrics/eval_metrics.json:
          cache: false
    plots:
      - metrics/confusion_matrix.csv
```

```yaml
# params.yaml
prepare:
  test_size: 0.2
  random_seed: 42
train:
  n_estimators: 100
  max_depth: 6
  learning_rate: 0.1
```

```bash
# Run full pipeline (skips up-to-date stages)
dvc repro

# Show what would run (dry run)
dvc repro --dry

# Compare metrics across git commits
dvc metrics diff HEAD~3 HEAD

# Show parameter diff
dvc params diff HEAD~3 HEAD
```

### Experiment Tracking with DVC

```bash
# Run an experiment with different params (doesn't modify params.yaml)
dvc exp run --set-param train.n_estimators=200

# Compare experiments
dvc exp show

# Promote best experiment to a branch
dvc exp branch exp-abc123 feature/better-model
```

### Git + DVC Workflow for Teams

```bash
# Workflow: push code to git, data to DVC remote simultaneously
git add src/ dvc.yaml params.yaml data/*.dvc
git commit -m "Experiment: increase n_estimators to 200"
git push origin feature/experiment
dvc push  # push any new data artifacts to remote

# Reviewer can reproduce your exact experiment:
git checkout feature/experiment
dvc pull          # get data artifacts
dvc repro         # reproduce full pipeline
dvc metrics show  # verify metrics match
```

---

## Delta Lake (ACID Transactions on Data Lakes)

Delta Lake adds ACID transactions, time travel, and schema enforcement on top of Parquet files in cloud storage. Essential for data lakes used in ML training.

### Core Operations

```python
# pip install delta-spark (with PySpark) or deltalake (standalone)
from deltalake import DeltaTable, write_deltalake
import pandas as pd

table_path = "s3://my-bucket/ml-data/features"

# Write initial data
df = pd.read_parquet("features_batch_1.parquet")
write_deltalake(table_path, df, mode="overwrite")

# Append new data (ACID — safe for concurrent writes)
new_batch = pd.read_parquet("features_batch_2.parquet")
write_deltalake(table_path, new_batch, mode="append")

# Read current version
dt = DeltaTable(table_path)
current_df = dt.to_pandas()

# Read specific version (time travel)
dt_v1 = DeltaTable(table_path, version=1)
v1_df = dt_v1.to_pandas()

# Read by timestamp
dt_yesterday = DeltaTable(table_path, timestamp="2025-01-01T00:00:00Z")
```

### PySpark Delta Lake (for large datasets)

```python
from pyspark.sql import SparkSession

spark = (SparkSession.builder
    .appName("delta_example")
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension")
    .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog")
    .getOrCreate())

# Read
df = spark.read.format("delta").load("s3://my-bucket/features/")

# Time travel
df_v5 = (spark.read.format("delta")
    .option("versionAsOf", 5)
    .load("s3://my-bucket/features/"))

df_jan = (spark.read.format("delta")
    .option("timestampAsOf", "2025-01-01")
    .load("s3://my-bucket/features/"))

# Write with schema enforcement (schema mismatch raises error)
df_new.write.format("delta").mode("append").save("s3://my-bucket/features/")
```

### MERGE (Upserts / SCD Type 2)

```python
# Upsert: update existing records, insert new ones
from delta.tables import DeltaTable

delta_table = DeltaTable.forPath(spark, "s3://my-bucket/features/")
updates_df = spark.read.parquet("s3://my-bucket/daily_updates/")

(delta_table.alias("target")
    .merge(
        updates_df.alias("source"),
        "target.user_id = source.user_id"
    )
    .whenMatchedUpdateAll()    # update all columns when ID matches
    .whenNotMatchedInsertAll() # insert new rows
    .execute())
```

### Schema Evolution

```python
# Allow adding new columns without breaking existing reads
df_with_new_col.write.format("delta").mode("append").option("mergeSchema", "true").save(path)

# For breaking schema changes
df.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save(path)
```

### Maintenance

```bash
# Compact small files (improves read performance after many appends)
# PySpark:
delta_table.optimize().executeCompaction()

# Vacuum old files (removes files no longer referenced by any table version)
# WARNING: sets minimum retention (default 7 days). Do not set below 7 days.
delta_table.vacuum(retentionHours=168)  # 168 hours = 7 days

# View table history
delta_table.history().show()
```

---

## MLflow Artifacts (Simpler Alternative)

For smaller teams or simpler pipelines, MLflow artifact logging provides basic dataset versioning integrated with experiment tracking.

```python
import mlflow
import pandas as pd
import hashlib

mlflow.set_experiment("customer_churn")

with mlflow.start_run(run_name="training_run_v3"):
    # Log dataset as artifact
    train_df.to_parquet("/tmp/train_data.parquet")
    mlflow.log_artifact("/tmp/train_data.parquet", "datasets")

    # Log dataset metadata (new MLflow 2.0+ API)
    dataset = mlflow.data.from_pandas(
        train_df,
        name="customer_features_v3",
        targets="churn"
    )
    mlflow.log_input(dataset, context="training")

    # Compute and log data checksum
    data_hash = hashlib.md5(train_df.to_json().encode()).hexdigest()
    mlflow.log_param("data_hash", data_hash)
    mlflow.log_param("data_version", "v3")
    mlflow.log_param("n_train_samples", len(train_df))

    # ... training code ...

    mlflow.log_metric("accuracy", 0.94)
    mlflow.sklearn.log_model(model, "model")
```

---

## Data Lineage Tracking

For regulated industries or complex pipelines, track full lineage: what data produced what model.

### OpenLineage Integration

```python
from openlineage.client import OpenLineageClient
from openlineage.client.run import RunEvent, RunState, Run, Job
from openlineage.client.facet import (
    DataSourceDatasetFacet, SchemaDatasetFacet, SchemaField
)

client = OpenLineageClient.from_environment()  # reads OPENLINEAGE_URL from env

# Emit a "START" event when training begins
client.emit(RunEvent(
    eventType=RunState.START,
    eventTime="2025-01-01T10:00:00Z",
    run=Run(runId="training-run-abc123"),
    job=Job(namespace="ml-platform", name="train_churn_model"),
    inputs=[{
        "namespace": "s3://my-bucket",
        "name": "features/train_v3",
        "facets": {
            "dataSource": DataSourceDatasetFacet(
                name="s3://my-bucket/features/train_v3",
                uri="s3://my-bucket/features/train_v3"
            )
        }
    }],
    outputs=[{
        "namespace": "s3://my-bucket",
        "name": "models/churn_model_v3.pkl"
    }]
))
```

---

## Reproducibility Checklist

Before deploying any model, verify:

- [ ] **Data version recorded**: DVC hash, Delta Lake version number, or S3 URI with version ID stored in experiment metadata
- [ ] **Random seeds set**:
  ```python
  import random, numpy as np, torch
  SEED = 42
  random.seed(SEED)
  np.random.seed(SEED)
  torch.manual_seed(SEED)
  torch.cuda.manual_seed_all(SEED)
  torch.backends.cudnn.deterministic = True
  ```
- [ ] **Environment frozen**: `pip freeze > requirements.txt` or `conda env export > environment.yml`
- [ ] **Code version tagged**: `git tag v1.0.0 && git push origin v1.0.0`
- [ ] **Train/val/test splits saved as artifacts**: Not recomputed from scratch each run
- [ ] **Preprocessing parameters saved**: Scalers, encoders, imputer fill values as artifacts
- [ ] **Hyperparameters logged**: All hyperparameters in experiment tracking (MLflow, W&B, DVC)
- [ ] **Reproduce test**: Have a colleague reproduce the experiment cold from code + DVC data

---

## Dependencies

```bash
# DVC core + S3 support
pip install "dvc[s3]"
# Or Azure:
pip install "dvc[azure]"
# Or GCS:
pip install "dvc[gs]"

# Delta Lake (Python standalone, no Spark)
pip install deltalake

# Delta Lake with PySpark
pip install pyspark delta-spark

# MLflow
pip install mlflow
```
