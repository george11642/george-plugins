# Data Engineering Reference

## Pandas Patterns

### Reading Data Safely
```python
import pandas as pd

# Always specify dtypes — prevents silent type coercion bugs
df = pd.read_csv(
    "data.csv",
    dtype={"user_id": str, "amount": float, "category": "category"},
    parse_dates=["created_at"],
    na_values=["", "NULL", "N/A"],  # be explicit about what's null
)

# For large files, read in chunks to control memory
chunks = pd.read_csv("large.csv", chunksize=100_000)
result = pd.concat([process(chunk) for chunk in chunks])

# Parquet over CSV for production — typed, compressed, columnar
df.to_parquet("data.parquet", engine="pyarrow", compression="snappy")
df = pd.read_parquet("data.parquet", columns=["id", "value"])  # read only needed columns
```

### Method Chaining
Chain operations for readable, debuggable pipelines. Each step is independently testable.
```python
result = (
    df.pipe(validate_schema)        # fail fast on bad data
      .pipe(clean_nulls)            # handle missing values
      .assign(
          revenue=lambda d: d["qty"] * d["price"],
          month=lambda d: d["date"].dt.to_period("M"),
      )
      .query("revenue > 0")        # filter early to reduce data size
      .groupby("month")
      .agg(total=("revenue", "sum"), orders=("revenue", "count"))
      .reset_index()
)
```

### Memory Optimization
```python
# Downcast numeric types — reduces memory 50-75%
df["int_col"] = pd.to_numeric(df["int_col"], downcast="integer")
df["float_col"] = pd.to_numeric(df["float_col"], downcast="float")

# Use categoricals for low-cardinality strings
df["status"] = df["status"].astype("category")  # saves memory when <50% unique

# Check memory usage
df.info(memory_usage="deep")
```

## Polars — When Pandas Is Too Slow

Use Polars when: >1M rows, need parallel execution, want lazy evaluation.
```python
import polars as pl

# Lazy evaluation — Polars optimizes the query plan before executing
result = (
    pl.scan_parquet("data.parquet")
    .filter(pl.col("amount") > 0)
    .with_columns(
        revenue=pl.col("qty") * pl.col("price"),
        month=pl.col("date").dt.month(),
    )
    .group_by("month")
    .agg(
        pl.col("revenue").sum().alias("total"),
        pl.col("revenue").count().alias("orders"),
    )
    .sort("month")
    .collect()  # executes the optimized plan
)
```

Key differences from pandas: no index, no inplace mutations, expressions instead of apply, native multi-threading.

## ETL Patterns

### Extract-Transform-Load Pipeline
```python
def etl_pipeline(source_path: str, dest_path: str) -> None:
    """Idempotent ETL — safe to re-run without duplicates."""
    # Extract — read raw data, validate schema immediately
    raw = extract(source_path)
    validate_raw_schema(raw)  # fail here, not 3 steps later

    # Transform — pure functions, no side effects
    cleaned = clean(raw)
    featured = engineer_features(cleaned)
    validate_output_schema(featured)  # catch issues before writing

    # Load — atomic write with temp file rename
    temp_path = f"{dest_path}.tmp"
    featured.to_parquet(temp_path)
    os.rename(temp_path, dest_path)  # atomic on same filesystem
```

### Incremental Processing
```python
def process_incremental(source: str, state_path: str) -> pd.DataFrame:
    """Process only new data since last run. Track state with watermarks."""
    last_ts = load_watermark(state_path)  # last processed timestamp

    new_data = pd.read_parquet(
        source,
        filters=[("updated_at", ">", last_ts)],  # predicate pushdown
    )

    if new_data.empty:
        return pd.DataFrame()

    result = transform(new_data)
    save_watermark(state_path, new_data["updated_at"].max())
    return result
```

## Data Validation

### Pandera — Schema Validation
```python
import pandera as pa

schema = pa.DataFrameSchema({
    "user_id": pa.Column(str, nullable=False, unique=True),
    "age": pa.Column(int, pa.Check.in_range(0, 150)),
    "email": pa.Column(str, pa.Check.str_matches(r"^[\w.]+@[\w.]+$")),
    "revenue": pa.Column(float, pa.Check.ge(0)),
})

# Validate — raises SchemaError with details on failure
validated_df = schema.validate(df, lazy=True)  # lazy=True collects ALL errors
```

### Great Expectations — For Larger Teams
```python
import great_expectations as gx

context = gx.get_context()
validator = context.sources.pandas_default.read_dataframe(df)
validator.expect_column_values_to_not_be_null("user_id")
validator.expect_column_values_to_be_between("age", 0, 150)
validator.expect_column_values_to_be_unique("email")
result = validator.validate()
```

## Pipeline Orchestration

### When to use what:
- **Simple sequential tasks** → Makefile or shell script
- **DAGs with retries, scheduling** → Prefect or Dagster (Python-native)
- **Enterprise-scale, multi-team** → Airflow (heavier, more overhead)

### Prefect Example
```python
from prefect import flow, task

@task(retries=3, retry_delay_seconds=60)
def extract(source: str) -> pd.DataFrame:
    return pd.read_parquet(source)

@task
def transform(df: pd.DataFrame) -> pd.DataFrame:
    return df.pipe(clean).pipe(feature_engineer)

@task
def load(df: pd.DataFrame, dest: str) -> None:
    df.to_parquet(dest)

@flow(name="daily-etl")
def daily_pipeline(source: str, dest: str):
    raw = extract(source)
    processed = transform(raw)
    load(processed, dest)
```

## Common Gotchas

1. **SettingWithCopyWarning** — Use `.loc[]` for assignment or `.copy()` when slicing. Never chain `[][]` for assignment.
2. **Timezone-naive datetimes** — Always localize: `pd.to_datetime(col).dt.tz_localize("UTC")`. Mixing naive/aware causes silent bugs.
3. **Float equality** — Never compare floats with `==`. Use `np.isclose()` or round to fixed precision.
4. **Merge duplicates** — Always check for duplicates in join keys before merging. Use `validate="one_to_many"` parameter.
5. **apply() is slow** — Vectorize with numpy/pandas operations. `apply()` is a Python loop in disguise.
