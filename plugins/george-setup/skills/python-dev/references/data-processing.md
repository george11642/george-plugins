# Data Processing Reference

## Pandas

The standard for tabular data manipulation. Best when: dataset fits in RAM, familiar API needed, wide ecosystem support.

### Read/Write

```python
import pandas as pd

# Read
df = pd.read_csv("data.csv", parse_dates=["created_at"], dtype={"id": "int32"})
df = pd.read_excel("data.xlsx", sheet_name="Sheet1", header=0)
df = pd.read_json("data.json", orient="records")
df = pd.read_parquet("data.parquet")  # fastest for large files

# Chunked reading (large files that don't fit in RAM)
for chunk in pd.read_csv("large.csv", chunksize=10_000):
    process(chunk)

# Write
df.to_csv("out.csv", index=False)
df.to_parquet("out.parquet", compression="snappy")  # use parquet for large data
df.to_excel("out.xlsx", index=False, sheet_name="Results")
```

### Selection and Filtering

```python
# Column selection
df[["col1", "col2"]]

# Row filtering (boolean indexing)
df[df["age"] > 30]
df[(df["age"] > 30) & (df["active"] == True)]
df[df["country"].isin(["US", "UK", "CA"])]

# loc: label-based (includes end)
df.loc[0:5, "name":"age"]
df.loc[df["active"] == True, ["name", "email"]]

# iloc: integer-based (excludes end)
df.iloc[0:5, 0:3]

# query: SQL-like string (readable for complex filters)
df.query("age > 30 and country == 'US'")
```

### GroupBy Aggregations

```python
# Basic aggregation
df.groupby("department")["salary"].agg(["mean", "median", "count", "std"])

# Multiple column groupby
result = df.groupby(["department", "level"]).agg(
    avg_salary=("salary", "mean"),
    headcount=("id", "count"),
    max_salary=("salary", "max"),
)

# transform: returns same-shape DataFrame (vs agg which collapses)
df["dept_avg"] = df.groupby("department")["salary"].transform("mean")
df["salary_vs_avg"] = df["salary"] / df["dept_avg"]

# apply: arbitrary function per group (slow — avoid if vectorized solution exists)
def normalize(group):
    return (group - group.mean()) / group.std()

df["normalized"] = df.groupby("department")["salary"].apply(normalize)
```

### Time Series

```python
df["date"] = pd.to_datetime(df["date"])
df = df.set_index("date").sort_index()

# Resample: aggregate by time period
daily = df.resample("D")["value"].sum()     # daily sum
monthly = df.resample("ME")["value"].mean()  # monthly mean (ME = month end)

# Rolling window
df["7d_avg"] = df["value"].rolling("7D").mean()
df["30d_sum"] = df["value"].rolling(30).sum()

# Shift and diff
df["prev_day"] = df["value"].shift(1)
df["daily_change"] = df["value"].diff(1)

# Date components
df["year"] = df.index.year
df["month"] = df.index.month
df["day_of_week"] = df.index.dayofweek  # 0=Monday
```

### Memory Optimization

```python
# Check memory
df.info(memory_usage="deep")
df.memory_usage(deep=True).sum() / 1024**2  # MB

# Downcast numerics
df["id"] = pd.to_numeric(df["id"], downcast="integer")   # int64 → int32/int16
df["price"] = pd.to_numeric(df["price"], downcast="float")  # float64 → float32

# Categories for low-cardinality strings (huge savings)
df["country"] = df["country"].astype("category")
df["status"] = df["status"].astype("category")

# Rule of thumb: if a string column has < 50% unique values → category
n_unique = df["status"].nunique()
if n_unique / len(df) < 0.5:
    df["status"] = df["status"].astype("category")
```

### Vectorization (Avoid .apply)

```python
# SLOW: apply with Python function
df["full_name"] = df.apply(lambda row: f"{row.first} {row.last}", axis=1)

# FAST: vectorized string operations
df["full_name"] = df["first"] + " " + df["last"]

# SLOW: apply for conditions
df["label"] = df["score"].apply(lambda x: "high" if x > 80 else "low")

# FAST: np.where
import numpy as np
df["label"] = np.where(df["score"] > 80, "high", "low")

# FAST: np.select for multiple conditions
conditions = [df["score"] > 80, df["score"] > 60, df["score"] > 40]
choices = ["A", "B", "C"]
df["grade"] = np.select(conditions, choices, default="D")
```

### Merge, Join, Concat

```python
# merge (like SQL JOIN)
result = pd.merge(df_left, df_right, on="id", how="inner")  # inner/left/right/outer
result = pd.merge(df_left, df_right, left_on="user_id", right_on="id", how="left")

# join (index-based merge)
result = df_left.join(df_right, on="id", how="left")

# concat (stack DataFrames)
result = pd.concat([df1, df2, df3], ignore_index=True)      # stack rows
result = pd.concat([df1, df2], axis=1)                       # stack columns
```

---

## Polars (High-Performance Alternative)

Use Polars when: dataset is large (>1GB), need multi-core parallelism, memory is constrained, or pandas is too slow.

**Key differences from pandas**:
- Multi-threaded by default (uses all CPU cores)
- Lazy evaluation via `.lazy()` / `.collect()` — query optimization
- Stricter typing (no mixed-type columns)
- Different API but similar concepts

```python
import polars as pl

# Read
df = pl.read_csv("data.csv")
df = pl.read_parquet("data.parquet")

# Lazy (deferred execution, query planning)
lf = pl.scan_csv("large.csv")  # no data loaded yet
result = (
    lf
    .filter(pl.col("age") > 30)
    .groupby("department")
    .agg(pl.col("salary").mean().alias("avg_salary"))
    .sort("avg_salary", descending=True)
    .collect()  # execute here
)

# Expressions are the core of Polars (unlike pandas loc/apply)
df = df.with_columns([
    (pl.col("first") + " " + pl.col("last")).alias("full_name"),
    pl.col("salary").mean().over("department").alias("dept_avg"),
])

# GroupBy
df.groupby("department").agg([
    pl.col("salary").mean().alias("avg"),
    pl.col("id").count().alias("headcount"),
])
```

**When to switch from pandas to polars**:
- File > 1GB and you're hitting memory limits
- Processing time matters (Polars is typically 5–20x faster)
- You're starting fresh (migration cost is high)

---

## NumPy

The foundation of scientific Python. Use directly when you need: low-level array operations, custom math, or maximum performance.

```python
import numpy as np

# Array creation
arr = np.array([1, 2, 3, 4, 5])
zeros = np.zeros((100, 100))
ones = np.ones((50, 50), dtype=np.float32)
range_arr = np.arange(0, 100, 0.5)    # start, stop, step
linspace = np.linspace(0, 1, 100)     # 100 evenly spaced points

# Vectorized operations (no Python loops)
a = np.random.rand(1_000_000)
b = np.random.rand(1_000_000)
result = a * b + np.sin(a)            # element-wise, all in C

# Broadcasting: operations on different shapes
matrix = np.ones((3, 4))
row = np.array([1, 2, 3, 4])         # shape (4,)
result = matrix + row                 # broadcasts row across all matrix rows

# np.where: conditional element selection
result = np.where(a > 0.5, a * 2, 0)  # if > 0.5: double, else 0

# np.select: multiple conditions
conditions = [a > 0.8, a > 0.5, a > 0.2]
choices = [3, 2, 1]
result = np.select(conditions, choices, default=0)

# Aggregations
np.sum(arr), np.mean(arr), np.std(arr), np.percentile(arr, [25, 50, 75])

# Reshape
arr.reshape(10, 10)
arr.flatten()
np.stack([arr1, arr2], axis=0)  # stack along new axis

# Boolean indexing (same as pandas, but on ndarrays)
mask = arr > 0.5
arr[mask]                             # select elements where True
arr[mask] = 0                         # set elements where True
```

### einsum (matrix operations without explicit loops)

```python
# Dot product
np.einsum("i,i->", a, b)        # same as np.dot(a, b)

# Matrix multiply
np.einsum("ij,jk->ik", A, B)    # same as A @ B

# Batch matrix multiply
np.einsum("bij,bjk->bik", A, B) # batch of matrix multiplications

# Trace
np.einsum("ii->", A)             # same as np.trace(A)
```

---

## Data Validation

### Pydantic v2 for Pipeline Data

```python
from pydantic import BaseModel, field_validator, model_validator
from datetime import datetime

class SalesRecord(BaseModel):
    product_id: str
    quantity: int
    unit_price: float
    sale_date: datetime

    @field_validator("quantity")
    @classmethod
    def quantity_positive(cls, v: int) -> int:
        if v <= 0:
            raise ValueError("quantity must be positive")
        return v

    @model_validator(mode="after")
    def check_total_reasonable(self) -> "SalesRecord":
        total = self.quantity * self.unit_price
        if total > 1_000_000:
            raise ValueError(f"Suspiciously large total: {total}")
        return self

# Validate a list of records
records = [SalesRecord.model_validate(r) for r in raw_data]
```

### pandera for DataFrame Schema Validation

```python
import pandera as pa
from pandera import Column, DataFrameSchema, Check

schema = DataFrameSchema({
    "product_id": Column(str, nullable=False),
    "quantity": Column(int, Check.greater_than(0)),
    "unit_price": Column(float, Check.in_range(0, 10_000)),
    "sale_date": Column("datetime64[ns]"),
})

# Validate — raises SchemaError on failure
validated_df = schema.validate(df)

# Or as a decorator
@pa.check_input(schema)
def process_sales(df: pd.DataFrame) -> pd.DataFrame:
    ...
```

### Great Expectations (data quality at scale)

Use Great Expectations for: automated data quality checks in pipelines, data contracts between teams, profiling new datasets.

```python
import great_expectations as gx

context = gx.get_context()
datasource = context.sources.add_pandas("my_datasource")
data_asset = datasource.add_dataframe_asset("sales")

batch_request = data_asset.build_batch_request(dataframe=df)
validator = context.get_validator(batch_request=batch_request)

# Add expectations
validator.expect_column_values_to_not_be_null("product_id")
validator.expect_column_values_to_be_between("quantity", min_value=1)
validator.expect_column_values_to_be_of_type("sale_date", "datetime64")

# Run and get results
results = validator.validate()
print(results["success"])  # True/False
```
