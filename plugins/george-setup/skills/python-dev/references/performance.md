# Python Performance Optimization

## Profiling Tools

### cProfile (CPU)

```bash
python -m cProfile -o output.prof script.py
python -m pstats output.prof   # Interactive analysis
```

```python
import cProfile, pstats
profiler = cProfile.Profile()
profiler.enable()
main()
profiler.disable()
stats = pstats.Stats(profiler)
stats.sort_stats(pstats.SortKey.CUMULATIVE)
stats.print_stats(10)
```

### line_profiler (Line-by-Line)

```bash
pip install line-profiler
kernprof -l -v script.py   # Use @profile decorator on functions
```

### memory_profiler

```python
from memory_profiler import profile

@profile
def memory_intensive():
    big_list = [i for i in range(1000000)]
    return sum(big_list)
```

### tracemalloc (Memory Leak Detection)

```python
import tracemalloc
tracemalloc.start()
snapshot1 = tracemalloc.take_snapshot()
# ... run code ...
snapshot2 = tracemalloc.take_snapshot()
for stat in snapshot2.compare_to(snapshot1, 'lineno')[:10]:
    print(stat)
```

### py-spy (Production Profiling)

```bash
py-spy record -o profile.svg -- python script.py
py-spy top --pid 12345   # Attach to running process
```

## Optimization Patterns

### Data Structures

```python
# O(1) lookup: dict/set instead of list
lookup = {item.id: item for item in items}  # Not: [i for i in items if i.id == target]

# Generators for memory efficiency
total = sum(x**2 for x in range(1_000_000))  # Not: sum([x**2 for x in range(1_000_000)])
```

### Comprehensions > Loops

```python
# Fast
result = [i**2 for i in range(n)]

# Slow
result = []
for i in range(n):
    result.append(i**2)
```

### String Operations

```python
# Fast
result = "".join(str(item) for item in items)

# Slow (quadratic)
result = ""
for item in items:
    result += str(item)
```

### Caching

```python
from functools import lru_cache

@lru_cache(maxsize=128)
def expensive_computation(n):
    return sum(i**2 for i in range(n))
```

### __slots__ for Memory

```python
class Point:
    __slots__ = ['x', 'y', 'z']
    def __init__(self, x, y, z):
        self.x, self.y, self.z = x, y, z
# ~40% less memory per instance vs regular class
```

### Local Variables

```python
# Faster: local variable access
def process():
    local_val = GLOBAL_VALUE
    for i in range(10000):
        total += local_val
```

## Parallelism

### CPU-Bound: multiprocessing

```python
from multiprocessing import Pool

with Pool(processes=4) as pool:
    results = pool.map(cpu_intensive_fn, data_chunks)
```

### I/O-Bound: asyncio

```python
async def fetch_all(urls):
    async with aiohttp.ClientSession() as session:
        return await asyncio.gather(*[fetch(session, u) for u in urls])
```

### NumPy for Numerics

```python
import numpy as np
# 10-100x faster than pure Python for array operations
result = np.arange(1_000_000) ** 2   # Vectorized
```

## Database Optimization

```python
# Batch inserts (10-100x faster)
cursor.executemany("INSERT INTO t (col) VALUES (?)", [(v,) for v in values])
conn.commit()  # Single commit

# Indexes for frequent queries
# CREATE INDEX idx_email ON users(email);

# SELECT only needed columns, not SELECT *
```

## Benchmarking

```python
import timeit
time = timeit.timeit("sum(range(1000000))", number=100)
print(f"Average: {time/100:.6f}s")

# pytest-benchmark
def test_performance(benchmark):
    result = benchmark(lambda: my_function(data))
```

## Performance Checklist

1. Profile before optimizing (cProfile/py-spy)
2. Focus on hot paths (most-called functions)
3. Use appropriate data structures (dict/set for lookups)
4. Prefer comprehensions and built-in functions
5. Cache expensive pure computations (lru_cache)
6. Use generators for large datasets
7. Batch I/O and database operations
8. multiprocessing for CPU-bound, asyncio for I/O-bound
9. NumPy for numerical operations
10. Benchmark before and after changes
