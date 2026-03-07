# Advanced RAG: Hybrid Retrieval, Reranking, and Production Pipelines

## Why Naive RAG Fails

Single-method retrieval is the most common cause of poor RAG quality in production:

- **Dense-only retrieval** fails on exact keyword matches, product codes, entity names, error messages
- **BM25-only retrieval** misses semantic similarity — paraphrases and synonyms are invisible to it
- **No reranking** means top-5 results have low precision; the LLM gets irrelevant context
- **Single-method retrieval misses 30-40% of relevant documents** that would be caught by a complementary method
- **Chunking without context** splits semantic units at arbitrary boundaries

Naive RAG pipeline: query → embed → ANN search → top-k → LLM. This works for demos but degrades in production.

---

## Hybrid Retrieval: BM25 + Dense

### Why combine both?

| Method | Strengths | Weaknesses |
|--------|-----------|------------|
| BM25 (sparse) | Exact match, product codes, rare terms, interpretable | No semantic understanding |
| Dense (vector) | Semantic similarity, paraphrase matching, cross-lingual | Poor on rare/unseen terms |
| Hybrid | Both advantages | Needs fusion strategy |

### BM25 Implementation (rank_bm25)

```python
from rank_bm25 import BM25Okapi
import numpy as np

def build_bm25_index(documents: list[str]) -> BM25Okapi:
    """Tokenize and build BM25 index."""
    tokenized = [doc.lower().split() for doc in documents]
    return BM25Okapi(tokenized)

def bm25_retrieve(index: BM25Okapi, query: str, documents: list[str], top_k: int = 100) -> list[tuple[int, float]]:
    """Return (doc_idx, score) pairs sorted by BM25 score."""
    tokenized_query = query.lower().split()
    scores = index.get_scores(tokenized_query)
    top_indices = np.argsort(scores)[::-1][:top_k]
    return [(int(i), float(scores[i])) for i in top_indices if scores[i] > 0]
```

### Dense Retrieval with sentence-transformers

```python
from sentence_transformers import SentenceTransformer
import numpy as np
import faiss

def build_dense_index(documents: list[str], model_name: str = "BAAI/bge-small-en-v1.5"):
    model = SentenceTransformer(model_name)
    embeddings = model.encode(documents, batch_size=64, show_progress_bar=True, normalize_embeddings=True)

    dim = embeddings.shape[1]
    index = faiss.IndexFlatIP(dim)  # Inner product = cosine similarity (with normalized embeddings)
    index.add(embeddings.astype(np.float32))
    return model, index

def dense_retrieve(model, index, query: str, top_k: int = 100) -> list[tuple[int, float]]:
    query_emb = model.encode([query], normalize_embeddings=True).astype(np.float32)
    scores, indices = index.search(query_emb, top_k)
    return [(int(i), float(s)) for i, s in zip(indices[0], scores[0]) if i != -1]
```

### Reciprocal Rank Fusion (RRF)

RRF formula: `score(d) = sum_over_rankers( 1 / (k + rank(d)) )`

- `k = 60` is the standard default (from the original Cormack et al. 2009 paper)
- Increase k to flatten the impact of top ranks (gives more weight to lower-ranked results)
- Decrease k to amplify the advantage of top-ranked results
- RRF is robust because it uses rank position, not raw scores (no need to normalize across different score scales)

```python
def reciprocal_rank_fusion(
    ranked_lists: list[list[tuple[int, float]]],
    k: int = 60
) -> list[tuple[int, float]]:
    """
    Merge multiple ranked lists using RRF.

    Args:
        ranked_lists: List of (doc_id, score) lists, each already sorted by relevance
        k: RRF constant (default 60)
    Returns:
        Fused ranking as (doc_id, rrf_score) sorted descending
    """
    rrf_scores: dict[int, float] = {}

    for ranked_list in ranked_lists:
        for rank, (doc_id, _) in enumerate(ranked_list, start=1):
            rrf_scores[doc_id] = rrf_scores.get(doc_id, 0.0) + 1.0 / (k + rank)

    return sorted(rrf_scores.items(), key=lambda x: x[1], reverse=True)
```

**When to tune k:**
- Tune k lower (20-30) when you want top BM25/dense hits to dominate
- Tune k higher (80-100) when you want breadth across all ranked lists
- Default k=60 works well for most production cases without tuning

---

## Reranking

Reranking takes a candidate set (e.g., top 100 from retrieval) and re-scores each document against the query using a more expensive cross-attention model.

### Cross-Encoder Reranker

Cross-encoders process (query, document) pairs jointly — much higher quality than bi-encoders but O(n) inference cost.

```python
from sentence_transformers import CrossEncoder

def build_reranker(model_name: str = "cross-encoder/ms-marco-MiniLM-L-6-v2") -> CrossEncoder:
    """
    ms-marco-MiniLM-L-6-v2: fast, good quality, small (22M params)
    ms-marco-MiniLM-L-12-v2: slower, better quality
    BAAI/bge-reranker-v2-m3: multilingual, state-of-art quality
    """
    return CrossEncoder(model_name, max_length=512)

def rerank(
    reranker: CrossEncoder,
    query: str,
    documents: list[str],
    candidate_ids: list[int],
    top_k: int = 10
) -> list[tuple[int, float]]:
    """Rerank candidate documents, return top_k."""
    pairs = [(query, documents[i]) for i in candidate_ids]
    scores = reranker.predict(pairs, show_progress_bar=False)
    ranked = sorted(zip(candidate_ids, scores), key=lambda x: x[1], reverse=True)
    return ranked[:top_k]
```

**Quality improvement:** Cross-encoder reranking over hybrid retrieval yields ~48% improvement in NDCG@10 vs single-method dense retrieval (BEIR benchmark average).

### ColBERT Late Interaction

ColBERT computes per-token embeddings and uses MaxSim for scoring — much faster than cross-encoders at comparable quality.

```python
# Using ragatouille (ColBERT wrapper)
from ragatouille import RAGPretrainedModel

rag = RAGPretrainedModel.from_pretrained("colbert-ir/colbertv2.0")
rag.index(collection=documents, index_name="my_index", max_document_length=256)
results = rag.search(query="...", k=10)
```

**ColBERT vs cross-encoder tradeoff:**
- ColBERT: ~2-5x faster than cross-encoder at similar quality, needs pre-indexing
- Cross-encoder: No pre-indexing, easier to deploy, slightly better quality on small sets
- Production recommendation: Use cross-encoder for <10k docs, ColBERT for >100k docs

### Cost vs Quality Tradeoff

| Stage | Model | Latency | Quality |
|-------|-------|---------|---------|
| BM25 | rank_bm25 | <10ms | Baseline |
| Dense | bge-small-en | 20-50ms | +25% recall |
| Cross-encoder rerank | MiniLM-L-6 | 100-200ms | +48% NDCG@10 |
| Cross-encoder rerank | bge-reranker-v2-m3 | 200-500ms | +52% NDCG@10 |

---

## Three-Stage Pipeline (Production Standard 2025)

This is the de facto standard for production RAG systems:

```
Stage 1: BM25 keyword retrieval     → ~1000 candidates  (fast, ~5ms)
Stage 2: Dense semantic retrieval   → ~100 candidates   (medium, ~50ms)
       [RRF fusion of Stage 1+2]
Stage 3: Cross-encoder reranker     → ~10 for LLM       (slow, ~150ms)
```

**Why three stages instead of two?**
- Stage 1 ensures exact-match coverage (product codes, names, IDs)
- Stage 2 adds semantic coverage (paraphrases, synonyms)
- Stage 3 precision is critical — LLM context window is limited (8-32k tokens)
- Going from 100 candidates to top-10 with a reranker costs ~150ms but 10x improves LLM answer quality

### Complete Three-Stage Pipeline Implementation

```python
from rank_bm25 import BM25Okapi
from sentence_transformers import SentenceTransformer, CrossEncoder
import faiss
import numpy as np
from dataclasses import dataclass

@dataclass
class RetrievalResult:
    doc_id: int
    text: str
    score: float
    stage: str

class ThreeStageRAG:
    def __init__(
        self,
        documents: list[str],
        dense_model: str = "BAAI/bge-small-en-v1.5",
        reranker_model: str = "cross-encoder/ms-marco-MiniLM-L-6-v2",
    ):
        self.documents = documents

        # Stage 1: BM25
        tokenized = [doc.lower().split() for doc in documents]
        self.bm25 = BM25Okapi(tokenized)

        # Stage 2: Dense
        self.dense_model = SentenceTransformer(dense_model)
        embeddings = self.dense_model.encode(
            documents, batch_size=64, normalize_embeddings=True
        ).astype(np.float32)
        self.faiss_index = faiss.IndexFlatIP(embeddings.shape[1])
        self.faiss_index.add(embeddings)

        # Stage 3: Reranker
        self.reranker = CrossEncoder(reranker_model, max_length=512)

    def retrieve(
        self,
        query: str,
        bm25_top_k: int = 100,
        dense_top_k: int = 100,
        rerank_top_k: int = 10,
        rrf_k: int = 60,
    ) -> list[RetrievalResult]:
        # Stage 1: BM25
        bm25_scores = self.bm25.get_scores(query.lower().split())
        bm25_ranked = [(i, float(bm25_scores[i]))
                       for i in np.argsort(bm25_scores)[::-1][:bm25_top_k]
                       if bm25_scores[i] > 0]

        # Stage 2: Dense
        q_emb = self.dense_model.encode([query], normalize_embeddings=True).astype(np.float32)
        dense_scores, dense_indices = self.faiss_index.search(q_emb, dense_top_k)
        dense_ranked = [(int(i), float(s))
                        for i, s in zip(dense_indices[0], dense_scores[0]) if i != -1]

        # RRF fusion
        rrf_scores: dict[int, float] = {}
        for ranked_list in [bm25_ranked, dense_ranked]:
            for rank, (doc_id, _) in enumerate(ranked_list, start=1):
                rrf_scores[doc_id] = rrf_scores.get(doc_id, 0.0) + 1.0 / (rrf_k + rank)

        fused = sorted(rrf_scores.items(), key=lambda x: x[1], reverse=True)
        candidate_ids = [doc_id for doc_id, _ in fused[:100]]

        # Stage 3: Rerank
        pairs = [(query, self.documents[i]) for i in candidate_ids]
        rerank_scores = self.reranker.predict(pairs)
        final_ranked = sorted(
            zip(candidate_ids, rerank_scores), key=lambda x: x[1], reverse=True
        )[:rerank_top_k]

        return [
            RetrievalResult(doc_id=doc_id, text=self.documents[doc_id],
                          score=score, stage="reranked")
            for doc_id, score in final_ranked
        ]
```

---

## Metadata Filtering

Pre-filtering before retrieval dramatically improves precision by scoping the candidate set.

### When to apply metadata filters

- **Pre-filter**: Apply before retrieval to reduce search space (use when metadata is high-selectivity)
- **Post-filter**: Apply after retrieval (use when metadata is low-selectivity or uncertain)

### Pinecone filter syntax

```python
import pinecone

index = pinecone.Index("my-index")

# Pre-filter: only retrieve from documents after Jan 2024 in "finance" category
results = index.query(
    vector=query_embedding,
    top_k=20,
    filter={
        "date": {"$gte": "2024-01-01"},
        "category": {"$in": ["finance", "economics"]},
        "author": {"$eq": "smith"}
    },
    include_metadata=True
)
```

### Weaviate hybrid with filter

```python
import weaviate

client = weaviate.Client("http://localhost:8080")

result = (
    client.query
    .get("Document", ["text", "category", "date"])
    .with_hybrid(query=query_text, alpha=0.5)  # alpha=0: BM25 only, alpha=1: dense only
    .with_where({
        "path": ["category"],
        "operator": "Equal",
        "valueText": "finance"
    })
    .with_limit(20)
    .do()
)
```

---

## Query Expansion Techniques

### HyDE (Hypothetical Document Embeddings)

Generate a fake answer to the query, embed it, use that embedding for retrieval. Works because a "what a good answer looks like" embedding is closer to relevant docs than the raw question embedding.

```python
def hyde_retrieve(llm_client, model, faiss_index, documents, query: str, top_k: int = 20):
    # Generate hypothetical document
    response = llm_client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{
            "role": "user",
            "content": f"Write a detailed paragraph answering this question. Be specific and factual:\n\n{query}"
        }],
        max_tokens=200
    )
    hypothetical_doc = response.choices[0].message.content

    # Embed the hypothetical document (not the question)
    hyp_emb = model.encode([hypothetical_doc], normalize_embeddings=True).astype(np.float32)
    scores, indices = faiss_index.search(hyp_emb, top_k)
    return [(int(i), float(s)) for i, s in zip(indices[0], scores[0])]
```

### Multi-Query Retrieval

```python
def multi_query_retrieve(llm_client, retriever, query: str, n_queries: int = 5) -> list[int]:
    response = llm_client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{"role": "user", "content": f"""Generate {n_queries} different ways to ask this question.
Output one per line, no numbering:

{query}"""}]
    )
    variants = response.choices[0].message.content.strip().split("\n")

    # Retrieve for each variant, merge with RRF
    all_ranked = [retriever.bm25_retrieve(v, top_k=20) for v in [query] + variants]
    fused = reciprocal_rank_fusion(all_ranked, k=60)
    return [doc_id for doc_id, _ in fused[:50]]
```

---

## Production Failure Modes

| Failure | Symptom | Fix |
|---------|---------|-----|
| Chunking boundary splits | Answer spans two chunks, retrieved as neither | Use semantic chunking (split on sentence boundaries, not character count) |
| Embedding model domain mismatch | Retrieves semantically adjacent but wrong-domain docs | Fine-tune or use domain-specific embedding model |
| Stale index | New documents not retrieved | Set up incremental indexing + freshness monitoring |
| Context window overflow | LLM truncates or ignores late chunks | Limit chunks to 3-5, use reranker to pick best ones |
| Query too short/vague | BM25 returns nothing, dense returns generic | Add query expansion (HyDE or multi-query) |
| Metadata filter too aggressive | No candidates pass filter | Fall back to unfiltered retrieval if filtered result count < threshold |

---

## Dependencies

```bash
pip install rank-bm25 sentence-transformers faiss-cpu ragatouille
# For GPU:
pip install faiss-gpu
```
