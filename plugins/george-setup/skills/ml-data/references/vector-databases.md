# Vector Databases Reference

## Embedding Fundamentals

### Similarity Metrics

| Metric | Formula | When to use |
|---|---|---|
| Cosine similarity | `dot(a,b) / (|a| * |b|)` | Text, normalized embeddings (most common) |
| Dot product | `sum(a_i * b_i)` | When magnitude matters (recommendation scores) |
| L2 / Euclidean | `sqrt(sum((a_i - b_i)^2))` | When absolute distances matter |

**Rule**: If embeddings are L2-normalized (unit vectors), cosine similarity = dot product. Most embedding models produce normalized vectors — use dot product for speed.

```python
import numpy as np

def cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))

def normalize(vectors: np.ndarray) -> np.ndarray:
    norms = np.linalg.norm(vectors, axis=1, keepdims=True)
    return vectors / np.maximum(norms, 1e-12)

# Batch similarity
def top_k_similar(query: np.ndarray, corpus: np.ndarray, k: int = 5) -> list[tuple[int, float]]:
    """Returns list of (index, score) sorted by similarity descending."""
    query_norm = query / np.linalg.norm(query)
    corpus_norm = normalize(corpus)
    scores = corpus_norm @ query_norm
    top_k_idx = np.argsort(scores)[::-1][:k]
    return [(int(idx), float(scores[idx])) for idx in top_k_idx]
```

---

## pgvector (PostgreSQL)

### Setup

```sql
-- Enable extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Create table with embedding column
CREATE TABLE documents (
    id SERIAL PRIMARY KEY,
    content TEXT NOT NULL,
    metadata JSONB,
    embedding VECTOR(1536),  -- Match your embedding model's dimensions
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- IVFFlat index — faster but approximate
-- lists = sqrt(num_rows) is a good starting point
CREATE INDEX ON documents USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);

-- HNSW index — better recall, higher memory, recommended for most cases
CREATE INDEX ON documents USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);
```

### Querying

```sql
-- Nearest neighbor search (cosine distance = 1 - cosine_similarity)
SELECT id, content, 1 - (embedding <=> '[0.1, 0.2, ...]'::vector) AS similarity
FROM documents
ORDER BY embedding <=> '[0.1, 0.2, ...]'::vector
LIMIT 5;

-- <=> cosine distance
-- <-> L2 distance
-- <#> negative dot product (for normalized vectors, equivalent to cosine)

-- With metadata filter (pre-filter, then rank)
SELECT id, content, 1 - (embedding <=> $1::vector) AS similarity
FROM documents
WHERE metadata->>'category' = 'technical'
  AND created_at > NOW() - INTERVAL '30 days'
ORDER BY embedding <=> $1::vector
LIMIT 10;

-- HNSW with ef_search (higher = better recall, slower)
SET hnsw.ef_search = 100;  -- Default is 40
```

### Python Integration

```python
import psycopg2
import numpy as np
from pgvector.psycopg2 import register_vector

conn = psycopg2.connect("postgresql://user:pass@localhost/dbname")
register_vector(conn)  # Register vector type

def upsert_document(conn, content: str, embedding: np.ndarray, metadata: dict = None):
    with conn.cursor() as cur:
        cur.execute(
            "INSERT INTO documents (content, embedding, metadata) VALUES (%s, %s, %s) "
            "ON CONFLICT (id) DO UPDATE SET embedding = EXCLUDED.embedding",
            (content, embedding, psycopg2.extras.Json(metadata or {}))
        )
    conn.commit()

def search(conn, query_embedding: np.ndarray, k: int = 5, threshold: float = 0.7) -> list[dict]:
    with conn.cursor() as cur:
        cur.execute(
            "SELECT id, content, metadata, 1 - (embedding <=> %s) AS score "
            "FROM documents "
            "WHERE 1 - (embedding <=> %s) > %s "
            "ORDER BY embedding <=> %s "
            "LIMIT %s",
            (query_embedding, query_embedding, threshold, query_embedding, k)
        )
        rows = cur.fetchall()
    return [{"id": r[0], "content": r[1], "metadata": r[2], "score": r[3]} for r in rows]
```

---

## Pinecone

```python
from pinecone import Pinecone, ServerlessSpec
import numpy as np

pc = Pinecone(api_key="YOUR_API_KEY")

# Create index
pc.create_index(
    name="my-index",
    dimension=1536,
    metric="cosine",  # "cosine", "euclidean", "dotproduct"
    spec=ServerlessSpec(cloud="aws", region="us-east-1"),
)
index = pc.Index("my-index")

# Upsert vectors (batch for efficiency)
def upsert_batch(vectors: list[dict], batch_size: int = 100):
    """vectors: list of {"id": str, "values": list[float], "metadata": dict}"""
    for i in range(0, len(vectors), batch_size):
        batch = vectors[i:i+batch_size]
        index.upsert(vectors=batch)

# Query
def query(embedding: list[float], top_k: int = 5, filter: dict = None, namespace: str = "") -> list[dict]:
    results = index.query(
        vector=embedding,
        top_k=top_k,
        include_metadata=True,
        filter=filter,      # e.g., {"category": {"$eq": "tech"}}
        namespace=namespace,
    )
    return [{"id": m.id, "score": m.score, "metadata": m.metadata} for m in results.matches]

# Namespaces — isolate data (tenant separation, dataset versions)
index.upsert(vectors=batch, namespace="tenant_abc")
index.query(vector=emb, top_k=5, namespace="tenant_abc")

# Delete
index.delete(ids=["doc_1", "doc_2"])
index.delete(filter={"category": "outdated"})  # Filter delete

# Stats
stats = index.describe_index_stats()
print(f"Total vectors: {stats.total_vector_count}")
```

---

## Chroma (Local / Self-Hosted)

```python
import chromadb
from chromadb.config import Settings

# In-memory (testing/prototyping)
client = chromadb.Client()

# Persistent (local)
client = chromadb.PersistentClient(path="./chroma_db")

# Remote server
client = chromadb.HttpClient(host="localhost", port=8000)

# Collection
collection = client.get_or_create_collection(
    name="documents",
    metadata={"hnsw:space": "cosine"},  # Distance metric
)

# Add documents (Chroma can auto-embed if you provide embedding function)
collection.add(
    ids=["doc_1", "doc_2", "doc_3"],
    documents=["Text content 1", "Text content 2", "Text content 3"],
    embeddings=[[0.1, 0.2, ...], [0.3, 0.4, ...], [0.5, 0.6, ...]],
    metadatas=[{"source": "wiki"}, {"source": "book"}, {"source": "news"}],
)

# Query
results = collection.query(
    query_embeddings=[query_embedding],
    n_results=5,
    where={"source": "wiki"},                          # Metadata filter
    where_document={"$contains": "machine learning"},  # Document content filter
    include=["documents", "metadatas", "distances"],
)

# Update and delete
collection.update(ids=["doc_1"], documents=["Updated text"], embeddings=[new_embedding])
collection.delete(ids=["doc_1"])
collection.delete(where={"source": "outdated"})
```

---

## FAISS (Facebook AI Similarity Search)

FAISS is a library, not a database. Use when you need in-process vector search without network overhead. Best for read-heavy workloads or when you're building your own service.

```python
import faiss
import numpy as np

d = 768  # Embedding dimension

# Flat (exact, brute-force) — use for <1M vectors or as ground truth
index_flat = faiss.IndexFlatL2(d)                    # L2 distance
index_flat_cos = faiss.IndexFlatIP(d)                # Inner product (cosine if normalized)

# Add vectors
vectors = np.random.randn(10000, d).astype(np.float32)
faiss.normalize_L2(vectors)  # Normalize for cosine similarity
index_flat_cos.add(vectors)

# Search
query = np.random.randn(1, d).astype(np.float32)
faiss.normalize_L2(query)
distances, indices = index_flat_cos.search(query, k=5)

# IVF (approximate, fast for >100k vectors)
# nlist = number of clusters, nprobe = clusters to search (higher = better recall, slower)
quantizer = faiss.IndexFlatIP(d)
index_ivf = faiss.IndexIVFFlat(quantizer, d, nlist=256, faiss.METRIC_INNER_PRODUCT)
index_ivf.train(vectors)  # MUST train IVF indexes
index_ivf.add(vectors)
index_ivf.nprobe = 16     # Search 16/256 clusters (6% coverage)
distances, indices = index_ivf.search(query, k=5)

# HNSW (fast approximate, no training needed)
index_hnsw = faiss.IndexHNSWFlat(d, 32)  # 32 = M parameter
index_hnsw.add(vectors)

# GPU (massive speedup for large indexes)
if faiss.get_num_gpus() > 0:
    res = faiss.StandardGpuResources()
    index_gpu = faiss.index_cpu_to_gpu(res, 0, index_flat_cos)

# Save/load
faiss.write_index(index_flat_cos, "index.faiss")
index = faiss.read_index("index.faiss")

# Map search results back to IDs (FAISS uses integer indices internally)
id_map = faiss.IndexIDMap(index_flat_cos)
ids = np.array([1001, 1002, ...], dtype=np.int64)
id_map.add_with_ids(vectors, ids)
```

### Index Selection Guide

| Index | Vectors | Recall | Memory | Speed | Training |
|---|---|---|---|---|---|
| `IndexFlatL2/IP` | <1M | 100% | High | Slow | None |
| `IndexIVFFlat` | 100k-10M | ~97% | Medium | Fast | Yes |
| `IndexHNSWFlat` | 100k-10M | ~99% | High | Very fast | None |
| `IndexIVFPQ` | >10M | ~90% | Very low | Very fast | Yes |

---

## Hybrid Retrieval (Dense + Sparse)

Dense (vector) retrieval finds semantically similar content. Sparse (BM25) retrieval finds exact keyword matches. Hybrid combines both — better recall for diverse query types.

```python
from rank_bm25 import BM25Okapi
import numpy as np
from sklearn.preprocessing import MinMaxScaler

class HybridRetriever:
    def __init__(self, documents: list[str], embeddings: np.ndarray):
        self.documents = documents
        self.embeddings = embeddings

        # BM25 (sparse)
        tokenized = [doc.lower().split() for doc in documents]
        self.bm25 = BM25Okapi(tokenized)

    def search(
        self,
        query: str,
        query_embedding: np.ndarray,
        top_k: int = 10,
        alpha: float = 0.5,  # 0=pure sparse, 1=pure dense
    ) -> list[dict]:
        # BM25 scores
        sparse_scores = np.array(self.bm25.get_scores(query.lower().split()))

        # Dense scores (cosine)
        query_norm = query_embedding / np.linalg.norm(query_embedding)
        corpus_norm = self.embeddings / np.linalg.norm(self.embeddings, axis=1, keepdims=True)
        dense_scores = corpus_norm @ query_norm

        # Normalize to [0, 1] and combine
        def safe_normalize(scores):
            if scores.max() == scores.min():
                return np.zeros_like(scores)
            return (scores - scores.min()) / (scores.max() - scores.min())

        combined = alpha * safe_normalize(dense_scores) + (1 - alpha) * safe_normalize(sparse_scores)
        top_indices = np.argsort(combined)[::-1][:top_k]
        return [{"doc": self.documents[i], "score": float(combined[i]), "idx": int(i)} for i in top_indices]
```

### Reciprocal Rank Fusion (RRF)

```python
def reciprocal_rank_fusion(rankings: list[list[int]], k: int = 60) -> list[tuple[int, float]]:
    """
    Combine multiple ranked lists without score normalization.
    rankings: list of lists of document indices, ranked best to worst.
    k: constant (60 is standard, higher = less penalty for low ranks).
    """
    scores: dict[int, float] = {}
    for ranking in rankings:
        for rank, doc_id in enumerate(ranking):
            scores[doc_id] = scores.get(doc_id, 0) + 1.0 / (k + rank + 1)
    return sorted(scores.items(), key=lambda x: x[1], reverse=True)
```

---

## Chunking Strategies

```python
from typing import Generator

def chunk_fixed_size(text: str, chunk_size: int = 512, overlap: int = 64) -> list[str]:
    """Simple fixed-size chunks with overlap. Fast, predictable."""
    words = text.split()
    chunks = []
    for i in range(0, len(words), chunk_size - overlap):
        chunk = " ".join(words[i:i + chunk_size])
        if chunk:
            chunks.append(chunk)
    return chunks


def chunk_by_sentences(text: str, max_tokens: int = 300) -> list[str]:
    """Split by sentence boundaries, merge until max_tokens."""
    import re
    sentences = re.split(r"(?<=[.!?])\s+", text)
    chunks, current, current_len = [], [], 0
    for sent in sentences:
        sent_len = len(sent.split())
        if current_len + sent_len > max_tokens and current:
            chunks.append(" ".join(current))
            current, current_len = [], 0
        current.append(sent)
        current_len += sent_len
    if current:
        chunks.append(" ".join(current))
    return chunks


def chunk_markdown(text: str) -> list[str]:
    """Split markdown by headers — preserves document structure."""
    import re
    sections = re.split(r"\n(?=#{1,3} )", text)
    return [s.strip() for s in sections if s.strip()]


def chunk_with_metadata(
    text: str,
    source: str,
    chunk_fn,
    **chunk_kwargs,
) -> list[dict]:
    """Wrap any chunker with metadata."""
    chunks = chunk_fn(text, **chunk_kwargs)
    return [{"content": chunk, "source": source, "chunk_idx": i, "total_chunks": len(chunks)}
            for i, chunk in enumerate(chunks)]
```

---

## Metadata Filtering Best Practices

```python
# GOOD: Filter BEFORE vector search (reduces search space)
# Most vector DBs support pre-filtering natively

# GOOD: Use low-cardinality metadata for filters (category, language, status)
# BAD: Filter on high-cardinality fields (user_id with millions of users) — use namespaces

# GOOD: Store document IDs in metadata for deduplication
# GOOD: Store timestamps as unix int (filterable) not ISO strings (not filterable in most DBs)

# Pinecone filter examples
filter_examples = {
    # Exact match
    "category": {"$eq": "technical"},
    # In list
    "status": {"$in": ["published", "reviewed"]},
    # Range (numeric only)
    "created_at": {"$gte": 1700000000, "$lte": 1710000000},
    # Compound
    "$and": [
        {"language": {"$eq": "en"}},
        {"version": {"$gte": 2}},
    ],
}
```

---

## Scaling Considerations

### When to Shard

- Single index > 10M vectors at 1536 dims = ~60GB RAM → shard
- Pinecone/Weaviate handle sharding automatically
- pgvector: partition by category/tenant for large tables

### Approximate vs Exact Search

- Exact (FAISS Flat, pgvector without index): O(n) per query, guaranteed accuracy
- Approximate (HNSW, IVF): O(log n) per query, ~95-99% recall
- For production: approximate is always better unless recall must be 100%

### Embedding Cache Pattern

```python
import hashlib
from functools import lru_cache

@lru_cache(maxsize=10000)
def embed_cached(text: str) -> tuple:
    """Cache embeddings for repeated queries. Return tuple (hashable)."""
    embedding = embed_model.encode(text, normalize_embeddings=True)
    return tuple(embedding.tolist())

def embed_or_cache(text: str) -> np.ndarray:
    return np.array(embed_cached(text))
```
