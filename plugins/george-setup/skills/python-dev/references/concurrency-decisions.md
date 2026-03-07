# Concurrency and Parallelism Reference

## Decision Tree: Which Concurrency Model?

```
Is the task I/O-bound or CPU-bound?
│
├── I/O-bound (network, disk, database, external APIs)
│   │
│   ├── Can you use async libraries? (aiohttp, asyncpg, aioboto3, etc.)
│   │   ├── YES → asyncio (best performance, lowest overhead)
│   │   └── NO  → threading (legacy sync libraries like requests, psycopg2)
│   │
│   └── Volume: hundreds of concurrent connections → asyncio wins
│
└── CPU-bound (image processing, ML inference, crypto, compression)
    │
    ├── Single large task → multiprocessing.Process or ProcessPoolExecutor
    └── Many parallel tasks → multiprocessing.Pool or ProcessPoolExecutor
```

**Key constraint**: Python's GIL means threading does NOT speed up CPU work. For CPU-bound tasks you must use multiprocessing or an external process.

---

## asyncio

Best for: network I/O, database queries, file I/O, many concurrent connections.

### Core Patterns

```python
import asyncio

# Basic coroutine
async def fetch(url: str) -> str:
    async with aiohttp.ClientSession() as session:
        async with session.get(url) as resp:
            return await resp.text()

# Run from sync context
result = asyncio.run(fetch("https://example.com"))
```

### TaskGroup (Python 3.11+) — Preferred over gather

```python
import asyncio

async def main():
    async with asyncio.TaskGroup() as tg:
        task1 = tg.create_task(fetch("https://a.com"), name="fetch-a")
        task2 = tg.create_task(fetch("https://b.com"), name="fetch-b")
        task3 = tg.create_task(fetch("https://c.com"), name="fetch-c")
    # All tasks done here — exceptions are collected and re-raised as ExceptionGroup
    results = [task1.result(), task2.result(), task3.result()]
```

Why TaskGroup over `gather`: if any task raises, TaskGroup cancels all remaining tasks (structured concurrency). `gather` by default lets other tasks continue. TaskGroup also gives cleaner exception handling via ExceptionGroup.

### Named Tasks for Production Observability

```python
# Name tasks so they're identifiable in logs/profilers
async def process_batch(items):
    async with asyncio.TaskGroup() as tg:
        tasks = [
            tg.create_task(process_item(item), name=f"process-{item.id}")
            for item in items
        ]
    return [t.result() for t in tasks]

# Check running tasks
all_tasks = asyncio.all_tasks()
for task in all_tasks:
    print(task.get_name(), task.get_coro())
```

### ExceptionGroup Handling (Python 3.11+)

```python
try:
    async with asyncio.TaskGroup() as tg:
        tg.create_task(might_fail_with_value_error())
        tg.create_task(might_fail_with_type_error())
except* ValueError as eg:          # except* catches ExceptionGroup containing ValueError
    for exc in eg.exceptions:
        print(f"ValueError: {exc}")
except* TypeError as eg:
    for exc in eg.exceptions:
        print(f"TypeError: {exc}")
```

### asyncio.gather (legacy pattern — still valid for simple cases)

```python
# All tasks run concurrently, results in order
results = await asyncio.gather(fetch(url1), fetch(url2), fetch(url3))

# return_exceptions=True: don't raise, return exceptions as values
results = await asyncio.gather(*tasks, return_exceptions=True)
errors = [r for r in results if isinstance(r, Exception)]
```

### asynccontextmanager

```python
from contextlib import asynccontextmanager

@asynccontextmanager
async def managed_connection():
    conn = await create_connection()
    try:
        yield conn
    finally:
        await conn.close()

async def main():
    async with managed_connection() as conn:
        await conn.execute("SELECT 1")
```

### Common asyncio Pitfalls

```python
# WRONG: blocking call in async context — blocks the entire event loop
async def bad():
    import time
    time.sleep(5)           # blocks! use asyncio.sleep
    requests.get(url)       # blocks! use aiohttp or httpx

# RIGHT: run blocking code in thread pool
import asyncio
loop = asyncio.get_event_loop()
result = await loop.run_in_executor(None, blocking_function, arg1, arg2)

# Or with asyncio.to_thread (Python 3.9+)
result = await asyncio.to_thread(blocking_function, arg1, arg2)
```

### Timeouts

```python
# asyncio.timeout (Python 3.11+)
async with asyncio.timeout(5.0):
    result = await slow_operation()

# asyncio.wait_for (older style)
result = await asyncio.wait_for(slow_operation(), timeout=5.0)
```

---

## threading

Best for: legacy sync I/O libraries (requests, psycopg2), parallelizing existing sync code, producer-consumer patterns.

```python
import threading
from queue import Queue

# Basic thread
def worker(task):
    result = do_work(task)
    print(result)

t = threading.Thread(target=worker, args=(task,), daemon=True)
t.start()
t.join(timeout=30)
```

### ThreadPoolExecutor

```python
from concurrent.futures import ThreadPoolExecutor, as_completed

def fetch_sync(url: str) -> str:
    return requests.get(url).text

urls = ["https://a.com", "https://b.com", "https://c.com"]

with ThreadPoolExecutor(max_workers=10) as executor:
    futures = {executor.submit(fetch_sync, url): url for url in urls}
    for future in as_completed(futures):
        url = futures[future]
        try:
            result = future.result()
        except Exception as e:
            print(f"{url} failed: {e}")
```

### Lock and RLock

```python
lock = threading.Lock()

def update_counter():
    with lock:           # auto-releases on exit/exception
        counter += 1

# RLock: re-entrant lock (same thread can acquire multiple times)
rlock = threading.RLock()
```

### Thread-Safe Queue (Producer-Consumer)

```python
from queue import Queue, Empty
import threading

q: Queue[str] = Queue(maxsize=100)

def producer():
    for item in data_source:
        q.put(item)           # blocks if full
    q.put(None)               # sentinel to signal done

def consumer():
    while True:
        item = q.get()
        if item is None:
            break
        process(item)
        q.task_done()

t_producer = threading.Thread(target=producer)
t_consumer = threading.Thread(target=consumer)
t_producer.start()
t_consumer.start()
t_producer.join()
t_consumer.join()
```

### Deadlock Prevention

- Always acquire locks in the same order across threads
- Use `with lock:` (not manual acquire/release) — releases on exception
- Prefer `Queue` over manual Lock+list for producer-consumer
- Use `threading.Semaphore` to limit concurrent access to a resource

---

## multiprocessing

Best for: CPU-bound work, bypassing GIL, parallel data processing.

```python
from multiprocessing import Pool, cpu_count

def cpu_intensive(x: int) -> int:
    return sum(i * i for i in range(x))

# Pool: managed worker processes
with Pool(processes=cpu_count()) as pool:
    results = pool.map(cpu_intensive, [1000000, 2000000, 3000000])
    # starmap for multiple args
    results = pool.starmap(func, [(a1, b1), (a2, b2)])
```

### ProcessPoolExecutor (concurrent.futures style)

```python
from concurrent.futures import ProcessPoolExecutor, as_completed

with ProcessPoolExecutor(max_workers=4) as executor:
    futures = [executor.submit(cpu_intensive, n) for n in range(10)]
    results = [f.result() for f in as_completed(futures)]
```

### Shared Memory (Python 3.8+)

```python
from multiprocessing import shared_memory
import numpy as np

# Create shared memory block
shm = shared_memory.SharedMemory(create=True, size=1024 * 1024 * 100)  # 100MB
arr = np.ndarray((1000000,), dtype=np.float64, buffer=shm.buf)

# In worker process
existing_shm = shared_memory.SharedMemory(name=shm.name)
arr = np.ndarray((1000000,), dtype=np.float64, buffer=existing_shm.buf)
```

### Multiprocessing Queue (IPC)

```python
from multiprocessing import Process, Queue

def worker(in_q: Queue, out_q: Queue):
    while True:
        item = in_q.get()
        if item is None:
            break
        out_q.put(process(item))

in_q, out_q = Queue(), Queue()
p = Process(target=worker, args=(in_q, out_q))
p.start()
```

### Gotchas

- Objects must be picklable (no lambdas, no open files, no locks)
- High startup cost per process — use Pool, not individual Process per task
- Shared state requires explicit mechanisms (Queue, Pipe, SharedMemory, Manager)
- On Windows: code must be under `if __name__ == "__main__":` guard

---

## concurrent.futures Summary

```python
from concurrent.futures import ThreadPoolExecutor, ProcessPoolExecutor, as_completed, wait, FIRST_COMPLETED

# ThreadPoolExecutor: I/O-bound sync code
# ProcessPoolExecutor: CPU-bound code

# map: blocking, maintains order, raises first exception
with ThreadPoolExecutor(max_workers=10) as ex:
    results = list(ex.map(func, items, timeout=30))

# as_completed: yields futures as they complete (not submission order)
with ProcessPoolExecutor() as ex:
    futures = [ex.submit(func, item) for item in items]
    for future in as_completed(futures):
        result = future.result()

# wait: wait for subset (FIRST_COMPLETED, ALL_COMPLETED, FIRST_EXCEPTION)
done, pending = wait(futures, return_when=FIRST_COMPLETED)
```

---

## When to Use trio vs asyncio

**asyncio**: standard library, wide ecosystem support (aiohttp, asyncpg, FastAPI, etc.). Use by default.

**trio**: stricter structured concurrency, better cancellation semantics, cleaner API. Use when:
- You're building a library that needs robust cancellation
- Your team finds asyncio's cancellation model confusing
- You want nurseries (trio's TaskGroup equivalent, available before Python 3.11)

**anyio**: compatibility layer that runs on both asyncio and trio. Use in library code that should work with either backend.
