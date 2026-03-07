# Async Python Patterns

## Basics

```python
import asyncio

async def main():
    result = await fetch_data("https://api.example.com")
    print(result)

asyncio.run(main())  # Entry point (Python 3.7+)
```

## Concurrent Execution

```python
# gather - run multiple coroutines concurrently
async def fetch_all(user_ids):
    tasks = [fetch_user(uid) for uid in user_ids]
    return await asyncio.gather(*tasks)

# create_task - schedule background work
task = asyncio.create_task(background_work())
# ... do other things ...
result = await task
```

## Error Handling

```python
# Per-task error handling
async def safe_fetch(url):
    try:
        return await fetch(url)
    except Exception as e:
        return None

# Gather with exceptions
results = await asyncio.gather(*tasks, return_exceptions=True)
successful = [r for r in results if not isinstance(r, Exception)]
```

## Timeouts

```python
try:
    result = await asyncio.wait_for(slow_op(), timeout=5.0)
except asyncio.TimeoutError:
    print("Timed out")
```

## Rate Limiting with Semaphore

```python
semaphore = asyncio.Semaphore(5)  # Max 5 concurrent

async def rate_limited_call(url):
    async with semaphore:
        return await fetch(url)

results = await asyncio.gather(*[rate_limited_call(u) for u in urls])
```

## Async Context Managers

```python
class AsyncDB:
    async def __aenter__(self):
        self.conn = await connect()
        return self.conn

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        await self.conn.close()

async with AsyncDB() as conn:
    await conn.query("SELECT 1")
```

## Async Generators

```python
async def fetch_pages(url, max_pages) -> AsyncIterator[dict]:
    for page in range(1, max_pages + 1):
        data = await fetch(f"{url}?page={page}")
        yield data

async for page in fetch_pages("/api/items", 10):
    process(page)
```

## Producer-Consumer

```python
async def producer(queue, items):
    for item in items:
        await queue.put(item)
    await queue.put(None)  # Sentinel

async def consumer(queue):
    while (item := await queue.get()) is not None:
        await process(item)
        queue.task_done()

queue = asyncio.Queue(maxsize=10)
await asyncio.gather(producer(queue, data), consumer(queue))
```

## Locks

```python
lock = asyncio.Lock()
async with lock:
    # Critical section - only one coroutine at a time
    shared_resource.update(data)
```

## Running Blocking Code

```python
import concurrent.futures

async def run_blocking():
    loop = asyncio.get_event_loop()
    with concurrent.futures.ThreadPoolExecutor() as pool:
        result = await loop.run_in_executor(pool, blocking_function, arg)
    return result
```

## HTTP with aiohttp

```python
import aiohttp

async def fetch_urls(urls):
    connector = aiohttp.TCPConnector(limit=100, limit_per_host=10)
    async with aiohttp.ClientSession(connector=connector) as session:
        tasks = [session.get(url) for url in urls]
        responses = await asyncio.gather(*tasks)
        return [await r.json() for r in responses]
```

## Batch Processing

```python
async def batch_process(items, batch_size=10):
    for i in range(0, len(items), batch_size):
        batch = items[i:i + batch_size]
        await asyncio.gather(*[process(item) for item in batch])
```

## Common Pitfalls

1. **Forgetting await**: `result = async_fn()` returns coroutine, not result
2. **Blocking event loop**: Use `asyncio.sleep()` not `time.sleep()`
3. **Not handling CancelledError**: Always re-raise after cleanup
4. **Mixing sync/async**: Use `asyncio.run()` or `run_in_executor()` at boundaries
5. **No error handling in gather**: Use `return_exceptions=True` or wrap tasks
