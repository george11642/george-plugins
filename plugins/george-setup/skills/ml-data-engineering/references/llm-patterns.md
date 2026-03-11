# LLM Patterns Reference

## RAG Architecture

### Overview

RAG (Retrieval-Augmented Generation) = vector search + LLM generation. Use when:
- Facts change frequently (fine-tuning bakes knowledge in)
- Source citations required
- Context window too small for all documents
- Cost prohibits fine-tuning

### End-to-End RAG Pipeline

```
Documents → Chunk → Embed → Store in vector DB
                                     ↓
Query → Embed → Search (top-k) → Retrieve chunks → Augment prompt → LLM → Answer
```

### Chunking Strategies

```python
from langchain.text_splitter import RecursiveCharacterTextSplitter, TokenTextSplitter

# 1. Fixed-size with overlap (baseline)
splitter = RecursiveCharacterTextSplitter(
    chunk_size=512,       # tokens or chars
    chunk_overlap=64,     # overlap prevents context loss at boundaries
    length_function=len,
)
chunks = splitter.split_text(document)

# 2. Token-based (aligns with model limits)
splitter = TokenTextSplitter(chunk_size=256, chunk_overlap=32)

# 3. Semantic chunking — split on semantic boundaries
# Split on paragraphs first, then merge small ones, split large ones
def semantic_chunk(text: str, max_tokens: int = 400) -> list[str]:
    paragraphs = text.split("\n\n")
    chunks, current = [], ""
    for para in paragraphs:
        if len(current) + len(para) < max_tokens * 4:  # ~4 chars/token
            current += "\n\n" + para
        else:
            if current:
                chunks.append(current.strip())
            current = para
    if current:
        chunks.append(current.strip())
    return chunks

# 4. Hierarchical (parent-child)
# Store large parent chunks, embed small child chunks
# Retrieve child → return parent for full context
```

### Embedding Strategies

```python
from sentence_transformers import SentenceTransformer
import numpy as np

# Local embedding (fast, free, good for most tasks)
model = SentenceTransformer("all-MiniLM-L6-v2")  # 384-dim, fast
# model = SentenceTransformer("all-mpnet-base-v2")  # 768-dim, better quality

def embed_batch(texts: list[str], batch_size: int = 64) -> np.ndarray:
    """Embed in batches to avoid OOM."""
    embeddings = []
    for i in range(0, len(texts), batch_size):
        batch = texts[i:i+batch_size]
        emb = model.encode(batch, normalize_embeddings=True, show_progress_bar=False)
        embeddings.append(emb)
    return np.vstack(embeddings)

# OpenAI embeddings (better quality, costs money)
from openai import OpenAI
client = OpenAI()

def embed_openai(texts: list[str], model: str = "text-embedding-3-small") -> list[list[float]]:
    """text-embedding-3-small: 1536-dim, cheap. text-embedding-3-large: 3072-dim, best quality."""
    response = client.embeddings.create(input=texts, model=model)
    return [item.embedding for item in response.data]
```

### Retrieval

```python
from typing import Any

def retrieve(
    query: str,
    vectorstore,
    top_k: int = 5,
    score_threshold: float = 0.7,
) -> list[dict]:
    """Retrieve and filter low-quality matches."""
    results = vectorstore.similarity_search_with_score(query, k=top_k * 2)
    filtered = [(doc, score) for doc, score in results if score >= score_threshold]
    return [{"content": doc.page_content, "metadata": doc.metadata, "score": score}
            for doc, score in filtered[:top_k]]


def augment_prompt(query: str, chunks: list[dict]) -> str:
    context = "\n\n---\n\n".join(c["content"] for c in chunks)
    return f"""Answer the question using only the provided context. If the context doesn't contain the answer, say "I don't know."

Context:
{context}

Question: {query}

Answer:"""
```

---

## Embedding Models Quick Reference

| Model | Dims | Speed | Quality | Cost |
|---|---|---|---|---|
| `all-MiniLM-L6-v2` | 384 | Very fast | Good | Free |
| `all-mpnet-base-v2` | 768 | Fast | Better | Free |
| `BAAI/bge-large-en-v1.5` | 1024 | Medium | Best open-source | Free |
| `text-embedding-3-small` | 1536 | API | Good | $0.02/1M tokens |
| `text-embedding-3-large` | 3072 | API | Best overall | $0.13/1M tokens |

---

## Fine-tuning Patterns

### When to Fine-tune vs Prompt

| Situation | Use |
|---|---|
| Consistent output format | Fine-tune |
| Domain-specific terminology | Fine-tune (or RAG) |
| Style/tone consistency | Fine-tune |
| New facts/knowledge | RAG (not fine-tune) |
| Few examples (<100) | Few-shot prompting |
| Latency critical | Fine-tune smaller model |
| Cost at scale | Fine-tune smaller model |

### LoRA (Low-Rank Adaptation)

```python
from peft import LoraConfig, get_peft_model, TaskType
from transformers import AutoModelForCausalLM, AutoTokenizer, TrainingArguments
from trl import SFTTrainer

model_name = "meta-llama/Llama-3.1-8B-Instruct"

tokenizer = AutoTokenizer.from_pretrained(model_name)
model = AutoModelForCausalLM.from_pretrained(
    model_name,
    load_in_4bit=True,          # QLoRA: 4-bit quantization
    torch_dtype="auto",
    device_map="auto",
)

lora_config = LoraConfig(
    r=16,                        # Rank — higher = more parameters, more capacity
    lora_alpha=32,               # Scale factor, usually 2x rank
    target_modules=["q_proj", "v_proj", "k_proj", "o_proj"],  # Which layers to adapt
    lora_dropout=0.05,
    bias="none",
    task_type=TaskType.CAUSAL_LM,
)
model = get_peft_model(model, lora_config)
model.print_trainable_parameters()  # Should be ~1-2% of total params

training_args = TrainingArguments(
    output_dir="./lora-output",
    num_train_epochs=3,
    per_device_train_batch_size=4,
    gradient_accumulation_steps=4,  # Effective batch = 16
    learning_rate=2e-4,
    fp16=True,
    logging_steps=10,
    save_strategy="epoch",
    warmup_ratio=0.03,
)

trainer = SFTTrainer(
    model=model,
    args=training_args,
    train_dataset=dataset,
    dataset_text_field="text",
    max_seq_length=2048,
)
trainer.train()
```

### LoRA vs QLoRA vs Full Fine-tuning

| Method | VRAM (7B model) | Quality | Speed |
|---|---|---|---|
| Full fine-tune | ~120 GB | Best | Slowest |
| LoRA (fp16) | ~20 GB | Near-full | Fast |
| QLoRA (4-bit) | ~8 GB | 95% of full | Medium |

QLoRA makes fine-tuning accessible on consumer GPUs (RTX 3090/4090).

---

## Prompt Engineering

### Few-Shot Prompting

```python
def few_shot_prompt(examples: list[dict], query: str) -> str:
    """examples: list of {"input": ..., "output": ...}"""
    shots = "\n\n".join(
        f"Input: {ex['input']}\nOutput: {ex['output']}"
        for ex in examples
    )
    return f"""{shots}

Input: {query}
Output:"""
```

### Chain-of-Thought

```python
# Add "Let's think step by step." or provide reasoning in examples
cot_prompt = """Classify the sentiment of the review. Think step by step.

Review: "The food was cold but the service was exceptional."
Reasoning: The food quality is negative (cold), but service is highly positive (exceptional). Two aspects, one negative and one positive. The service mention is emphasized with "exceptional."
Sentiment: Mixed (Negative food, Positive service)

Review: "{review}"
Reasoning:"""
```

### Structured Output

```python
from openai import OpenAI
from pydantic import BaseModel

client = OpenAI()

class ExtractedInfo(BaseModel):
    name: str
    age: int | None
    sentiment: str  # "positive", "negative", "neutral"
    key_topics: list[str]

# Use structured outputs (guaranteed valid JSON matching schema)
response = client.beta.chat.completions.parse(
    model="gpt-4o-mini",
    messages=[{"role": "user", "content": f"Extract info from: {text}"}],
    response_format=ExtractedInfo,
)
result = response.choices[0].message.parsed  # Already a Python object
```

---

## LLM Evaluation Metrics

### BLEU (Machine Translation / Text Generation)

```python
from nltk.translate.bleu_score import corpus_bleu, sentence_bleu

# BLEU measures n-gram overlap with references
references = [["the", "cat", "sat", "on", "mat"]]  # List of lists
hypothesis = ["the", "cat", "is", "on", "the", "mat"]
score = sentence_bleu(references, hypothesis)
# Range: 0-1. >0.4 is decent for MT. Less useful for open-ended generation.
```

### ROUGE (Summarization)

```python
from rouge_score import rouge_scorer

scorer = rouge_scorer.RougeScorer(["rouge1", "rouge2", "rougeL"], use_stemmer=True)
scores = scorer.score(reference_summary, generated_summary)
# rouge1: unigram overlap
# rouge2: bigram overlap
# rougeL: longest common subsequence
# Each has precision, recall, fmeasure
print(scores["rougeL"].fmeasure)
```

### BERTScore (Semantic Similarity)

```python
from bert_score import score as bert_score

# Better than BLEU/ROUGE — captures semantic meaning not just surface overlap
P, R, F1 = bert_score(
    cands=generated_texts,
    refs=reference_texts,
    lang="en",
    model_type="microsoft/deberta-xlarge-mnli",  # Best model for English
)
print(f"BERTScore F1: {F1.mean():.4f}")
```

### LLM-as-Judge (Best for Complex Tasks)

```python
def llm_judge(question: str, answer: str, criteria: str) -> dict:
    """Use a stronger LLM to evaluate a weaker one."""
    prompt = f"""Evaluate the following answer on a scale of 1-5 for {criteria}.

Question: {question}
Answer: {answer}

Scoring rubric:
5 - Excellent: completely correct, well-reasoned, thorough
4 - Good: mostly correct with minor issues
3 - Adequate: partially correct or missing key points
2 - Poor: mostly incorrect or missing important aspects
1 - Unacceptable: completely wrong or harmful

Respond with JSON: {{"score": int, "reasoning": "str"}}"""

    response = client.chat.completions.create(
        model="gpt-4o",
        messages=[{"role": "user", "content": prompt}],
        response_format={"type": "json_object"},
    )
    return json.loads(response.choices[0].message.content)
```

---

## Streaming Responses

```python
from openai import OpenAI

client = OpenAI()

# OpenAI streaming
def stream_response(prompt: str):
    stream = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{"role": "user", "content": prompt}],
        stream=True,
    )
    full_response = ""
    for chunk in stream:
        if chunk.choices[0].delta.content:
            token = chunk.choices[0].delta.content
            print(token, end="", flush=True)
            full_response += token
    return full_response


# FastAPI streaming endpoint
from fastapi import FastAPI
from fastapi.responses import StreamingResponse

app = FastAPI()

@app.post("/chat")
async def chat_stream(prompt: str):
    async def generate():
        stream = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[{"role": "user", "content": prompt}],
            stream=True,
        )
        for chunk in stream:
            if chunk.choices[0].delta.content:
                yield f"data: {chunk.choices[0].delta.content}\n\n"
        yield "data: [DONE]\n\n"
    return StreamingResponse(generate(), media_type="text/event-stream")
```

---

## Cost Optimization

### Caching

```python
import hashlib
import json
from functools import lru_cache
import redis

r = redis.Redis()

def cached_llm_call(prompt: str, model: str = "gpt-4o-mini", ttl: int = 3600) -> str:
    """Cache identical prompts — huge savings for repeated queries."""
    key = hashlib.sha256(f"{model}:{prompt}".encode()).hexdigest()
    cached = r.get(key)
    if cached:
        return cached.decode()

    response = client.chat.completions.create(
        model=model,
        messages=[{"role": "user", "content": prompt}],
    )
    result = response.choices[0].message.content
    r.setex(key, ttl, result)
    return result
```

### Token Counting Before Sending

```python
import tiktoken

def count_tokens(text: str, model: str = "gpt-4o") -> int:
    enc = tiktoken.encoding_for_model(model)
    return len(enc.encode(text))

def truncate_to_limit(text: str, max_tokens: int, model: str = "gpt-4o") -> str:
    enc = tiktoken.encoding_for_model(model)
    tokens = enc.encode(text)
    if len(tokens) <= max_tokens:
        return text
    return enc.decode(tokens[:max_tokens])
```

### Model Selection Strategy

```python
def route_to_model(query: str) -> str:
    """Route simple queries to cheap models, complex to expensive."""
    token_count = count_tokens(query)
    # Simple routing heuristics
    if token_count < 100 and not any(kw in query.lower() for kw in ["analyze", "compare", "code", "explain"]):
        return "gpt-4o-mini"  # ~15x cheaper than gpt-4o
    return "gpt-4o"
```

---

## Tool Use / Function Calling

```python
from openai import OpenAI
import json

client = OpenAI()

tools = [
    {
        "type": "function",
        "function": {
            "name": "search_database",
            "description": "Search the product database for items matching a query",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {"type": "string", "description": "Search query"},
                    "max_results": {"type": "integer", "default": 5},
                    "category": {"type": "string", "enum": ["electronics", "clothing", "books"]},
                },
                "required": ["query"],
            },
        },
    }
]

def run_agent(user_message: str) -> str:
    messages = [{"role": "user", "content": user_message}]
    while True:
        response = client.chat.completions.create(
            model="gpt-4o",
            messages=messages,
            tools=tools,
        )
        msg = response.choices[0].message
        messages.append(msg)

        if msg.tool_calls:
            for tool_call in msg.tool_calls:
                args = json.loads(tool_call.function.arguments)
                result = search_database(**args)  # Your actual function
                messages.append({
                    "role": "tool",
                    "tool_call_id": tool_call.id,
                    "content": json.dumps(result),
                })
        else:
            return msg.content  # Final answer
```

---

## LangChain vs Raw API

| Aspect | LangChain | Raw API |
|---|---|---|
| Prototyping | Fast — batteries included | Slower |
| Production | Abstraction leaks, hard to debug | Full control |
| Performance | Overhead from abstractions | Minimal |
| Debugging | Difficult (many layers) | Straightforward |
| Vendor lock-in | Partially abstracted | Provider-specific |
| Recommendation | Prototype → raw API for production | Prefer for anything serious |

**When LangChain makes sense**: Complex multi-step chains, existing integrations (document loaders, vector store wrappers), rapid prototyping.

**When to use raw API**: Production systems, latency-sensitive paths, when you need full control over prompts.

---

## Anthropic Claude API Patterns

```python
import anthropic

client = anthropic.Anthropic()

# Basic message
message = client.messages.create(
    model="claude-opus-4-5",
    max_tokens=1024,
    messages=[{"role": "user", "content": "Explain transformers in 3 sentences."}],
)
print(message.content[0].text)

# System prompt
message = client.messages.create(
    model="claude-opus-4-5",
    max_tokens=2048,
    system="You are a data scientist. Always provide Python code examples.",
    messages=[{"role": "user", "content": "How do I normalize features?"}],
)

# Streaming
with client.messages.stream(
    model="claude-opus-4-5",
    max_tokens=1024,
    messages=[{"role": "user", "content": "Write a training loop."}],
) as stream:
    for text in stream.text_stream:
        print(text, end="", flush=True)
```

---

## LangGraph Agentic RAG (2026)

LangChain has shifted from LCEL chains to LangGraph for stateful agent workflows. `create_agent` replaces `create_react_agent`.

### Agentic RAG with LangGraph

```python
from langchain.chat_models import init_chat_model
from langchain.embeddings import init_embeddings
from langchain_core.vectorstores import InMemoryVectorStore
from langchain.agents import create_agent
from langchain.tools import tool
from langgraph.checkpoint.memory import InMemorySaver

# Set up vector store
embeddings = init_embeddings("openai:text-embedding-3-small")
vector_store = InMemoryVectorStore(embeddings)
vector_store.add_documents(documents)

@tool
def retrieve_context(query: str) -> str:
    """Retrieve information to help answer a query."""
    results = vector_store.similarity_search(query, k=3)
    return "\n\n".join(f"Source: {doc.metadata}\nContent: {doc.page_content}" for doc in results)

# Create agent with memory
model = init_chat_model("claude-sonnet-4-6")
checkpointer = InMemorySaver()
agent = create_agent(model, [retrieve_context], checkpointer=checkpointer)

# Invoke with thread for memory
config = {"configurable": {"thread_id": "session_1"}}
response = agent.invoke(
    {"messages": [{"role": "user", "content": "What is our leave policy?"}]},
    config,
)
```

### Custom LangGraph RAG Workflow

```python
from langgraph.graph import StateGraph, START, END
from langgraph.prebuilt import ToolNode, tools_condition

workflow = StateGraph(MessagesState)
workflow.add_node(generate_query_or_respond)
workflow.add_node("retrieve", ToolNode([retriever_tool]))
workflow.add_node(rewrite_question)
workflow.add_node(generate_answer)

workflow.add_edge(START, "generate_query_or_respond")
workflow.add_conditional_edges(
    "generate_query_or_respond",
    tools_condition,
    {"tools": "retrieve", END: END},
)
workflow.add_conditional_edges("retrieve", grade_documents)
workflow.add_edge("generate_answer", END)
workflow.add_edge("rewrite_question", "generate_query_or_respond")

graph = workflow.compile()
```

**Key changes in LangChain 2026**:
- `create_agent` replaces `create_react_agent` for tool-calling agents
- LangGraph is the preferred runtime for stateful, multi-step workflows
- `init_chat_model` and `init_embeddings` are the new unified model init APIs
- Search result citations use `type: "search_result"` content blocks with `citations.enabled`
