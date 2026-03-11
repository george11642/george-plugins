# PEFT Fine-Tuning: LoRA, QLoRA, and Efficient LLM Adaptation

## When to Fine-Tune vs Prompt Engineering

Decision tree — always try in this order, stop when quality is sufficient:

```
1. Zero-shot prompting
   └── Quality sufficient? → DONE (cheapest)
   └── No → continue

2. Few-shot prompting (3-10 examples in context)
   └── Quality sufficient? → DONE
   └── No → continue

3. RAG (retrieval-augmented generation for knowledge tasks)
   └── Quality sufficient? → DONE
   └── No or it's a behavior/style/format problem → continue

4. Fine-tuning
   └── Use when: consistent output format, domain vocabulary,
       proprietary data patterns, latency/cost at scale
```

**Fine-tune when:**
- You need consistent structured output (JSON schemas, code with specific patterns)
- Domain-specific vocabulary the base model doesn't know (medical, legal, internal jargon)
- You have >500 high-quality examples and prompting isn't working
- Production cost or latency requires a smaller, specialized model
- Proprietary data that can't go in context windows

**Do not fine-tune when:**
- Prompting hasn't been thoroughly explored
- You have fewer than ~100 examples
- The task is general knowledge retrieval (use RAG)
- You need the model to stay updated (fine-tuned knowledge is frozen)

---

## LoRA (Low-Rank Adaptation)

### How LoRA Works

LoRA freezes the original model weights and adds trainable low-rank matrices to attention layers:

```
Original weight update: ΔW ∈ R^(d×d)  — too large to train
LoRA approximation:    ΔW ≈ A × B      where A ∈ R^(d×r), B ∈ R^(r×d), r << d
```

Only A and B are trained. If d=4096 and r=16:
- Full weight: 4096 × 4096 = 16.7M parameters
- LoRA: 4096 × 16 + 16 × 4096 = 131K parameters — **128x fewer trainable params**

### Key Hyperparameters

| Parameter | What it controls | Typical values |
|-----------|-----------------|----------------|
| `r` (rank) | Expressiveness of adaptation | 4, 8, 16, 32, 64 |
| `lora_alpha` | Scaling factor (alpha/r ≈ 1-2) | 16, 32 (set = r or 2*r) |
| `target_modules` | Which layers to apply LoRA to | q_proj, v_proj, k_proj, o_proj |
| `lora_dropout` | Regularization | 0.05-0.1 |
| `bias` | Whether to train biases | "none" (default) |

**Rank selection:**
- r=4: Minimal adaptation, fastest training, for simple style/format tasks
- r=8-16: Good balance for most tasks (recommended starting point)
- r=32-64: More expressive, for complex domain adaptation
- Higher rank ≠ always better — overfits faster on small datasets

### HuggingFace PEFT Setup

```python
# pip install peft transformers accelerate bitsandbytes trl

from transformers import AutoModelForCausalLM, AutoTokenizer, TrainingArguments
from peft import LoraConfig, get_peft_model, TaskType, PeftModel
import torch

model_name = "meta-llama/Llama-3.2-8B"

# Load base model
model = AutoModelForCausalLM.from_pretrained(
    model_name,
    torch_dtype=torch.bfloat16,  # bfloat16 saves memory vs float32
    device_map="auto",
)
tokenizer = AutoTokenizer.from_pretrained(model_name)
tokenizer.pad_token = tokenizer.eos_token  # LLMs often lack pad token

# Configure LoRA
lora_config = LoraConfig(
    task_type=TaskType.CAUSAL_LM,
    r=16,
    lora_alpha=32,               # scaling = lora_alpha / r = 2.0
    target_modules=[
        "q_proj", "v_proj", "k_proj", "o_proj",  # attention
        # optionally add: "gate_proj", "up_proj", "down_proj"  # MLP layers
    ],
    lora_dropout=0.05,
    bias="none",
)

# Wrap model with LoRA
model = get_peft_model(model, lora_config)
model.print_trainable_parameters()
# Example output: trainable params: 20,971,520 || all params: 8,051,232,768 || trainable%: 0.26%
```

### Memory: LoRA vs Full Fine-Tuning

| Model | Full Fine-Tune | LoRA r=16 | QLoRA 4-bit |
|-------|---------------|-----------|-------------|
| 7B | ~60GB | ~14GB | ~5GB |
| 13B | ~110GB | ~26GB | ~10GB |
| 70B | ~600GB | ~140GB | ~48GB |

---

## QLoRA (Quantized LoRA)

QLoRA = 4-bit NF4 quantization of base model + LoRA adapters in full precision.

**Key innovations in QLoRA (Dettmers et al., 2023):**
1. **NF4 (4-bit NormalFloat)**: Optimal for normally-distributed weights
2. **Double quantization**: Quantize the quantization constants → saves additional ~0.4 bits/param
3. **Paged optimizers**: Use CPU RAM as overflow for GPU OOM spikes during backprop

**Quality:**
- QLoRA achieves ~97% of full fine-tuning quality on most benchmarks
- Slight quality reduction vs LoRA in full precision, but enables training much larger models on consumer GPUs

### QLoRA Setup with bitsandbytes

```python
from transformers import AutoModelForCausalLM, BitsAndBytesConfig
from peft import LoraConfig, get_peft_model, TaskType, prepare_model_for_kbit_training
import torch

# 4-bit quantization config
bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",       # NF4 is best for LLM weights
    bnb_4bit_compute_dtype=torch.bfloat16,  # compute in bfloat16, store in 4-bit
    bnb_4bit_use_double_quant=True,  # double quantization for extra memory savings
)

# Load quantized base model
model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Llama-3.2-8B",
    quantization_config=bnb_config,
    device_map="auto",
)

# CRITICAL: prepare model for k-bit training (handles gradient checkpointing setup)
model = prepare_model_for_kbit_training(model)

# Add LoRA adapters
lora_config = LoraConfig(
    task_type=TaskType.CAUSAL_LM,
    r=16,
    lora_alpha=32,
    target_modules=["q_proj", "v_proj", "k_proj", "o_proj"],
    lora_dropout=0.05,
    bias="none",
)
model = get_peft_model(model, lora_config)
```

---

## Training Setup with SFTTrainer

The TRL library's SFTTrainer handles dataset formatting, padding, and training loop details.

```python
from trl import SFTTrainer, SFTConfig
from datasets import Dataset
import pandas as pd

# Dataset format: instruction-input-output template
def format_instruction(example: dict) -> str:
    """Format example as instruction-following prompt."""
    if example.get("input"):
        return f"""### Instruction:
{example["instruction"]}

### Input:
{example["input"]}

### Response:
{example["output"]}"""
    else:
        return f"""### Instruction:
{example["instruction"]}

### Response:
{example["output"]}"""

# Load your dataset
df = pd.read_json("training_data.jsonl", lines=True)
dataset = Dataset.from_pandas(df)
dataset = dataset.map(lambda x: {"text": format_instruction(x)})

# Training configuration
training_args = SFTConfig(
    output_dir="./fine_tuned_model",
    num_train_epochs=3,
    per_device_train_batch_size=4,
    gradient_accumulation_steps=4,   # effective batch size = 4 * 4 = 16
    gradient_checkpointing=True,     # trades compute for memory (~30% memory reduction)
    learning_rate=2e-4,              # typical range: 1e-4 to 5e-4 for LoRA
    fp16=False,
    bf16=True,                       # use bf16 if A100/H100, fp16 if V100/T4
    max_grad_norm=0.3,               # gradient clipping — important for stability
    warmup_ratio=0.03,
    lr_scheduler_type="cosine",
    save_steps=500,
    eval_steps=500,
    logging_steps=50,
    max_seq_length=2048,             # truncate sequences longer than this
    dataset_text_field="text",
    packing=False,                   # packing=True: pack multiple short examples, faster but complex
    report_to="wandb",               # or "mlflow", "tensorboard", "none"
)

trainer = SFTTrainer(
    model=model,
    args=training_args,
    train_dataset=dataset,
    processing_class=tokenizer,
)

trainer.train()
trainer.save_model("./fine_tuned_model")
```

### Flash Attention 2 (2x training speedup)

```python
# Requires: pip install flash-attn --no-build-isolation
model = AutoModelForCausalLM.from_pretrained(
    model_name,
    attn_implementation="flash_attention_2",  # significant speedup for long sequences
    torch_dtype=torch.bfloat16,
    device_map="auto",
)
```

---

## Adapter Merging

After training, you can optionally merge the LoRA adapter into the base model for faster inference (no adapter overhead).

```python
from peft import PeftModel

# Load base model (not quantized — merge requires full precision)
base_model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Llama-3.2-8B",
    torch_dtype=torch.float16,
    device_map="cpu",  # CPU for merge to avoid OOM
)

# Load and merge adapter
peft_model = PeftModel.from_pretrained(base_model, "./fine_tuned_model")
merged_model = peft_model.merge_and_unload()  # merge LoRA weights into base model

# Save merged model (can be served with vLLM directly)
merged_model.save_pretrained("./merged_model")
tokenizer.save_pretrained("./merged_model")
```

### Multi-LoRA Serving

For serving multiple task-specific adapters with a shared base model, use vLLM's multi-LoRA support:

```bash
vllm serve meta-llama/Llama-3.2-8B \
    --enable-lora \
    --lora-modules task1=/path/to/adapter1 task2=/path/to/adapter2 \
    --max-loras 4
```

```python
# Query specific adapter at runtime
client = AsyncOpenAI(base_url="http://localhost:8000/v1", api_key="x")
response = await client.chat.completions.create(
    model="task1",  # use adapter name as model ID
    messages=[{"role": "user", "content": "..."}]
)
```

---

## Common Issues and Fixes

### Catastrophic Forgetting

**Problem:** Model forgets general capabilities after fine-tuning on narrow dataset.

**Fixes:**
- Lower learning rate (1e-5 to 1e-4, not 5e-4)
- Add regularization via lora_dropout (0.1)
- Include diverse general examples in training data (mix 10-20% general with domain)
- Use fewer epochs (1-2 instead of 5+)

### Overfitting on Small Datasets

**Problem:** Training loss decreases but validation loss increases.

**Fixes:**
- Early stopping: `SFTConfig(load_best_model_at_end=True, metric_for_best_model="eval_loss")`
- Reduce rank (r=4 or r=8)
- Increase lora_dropout
- More gradient accumulation (larger effective batch size)
- Data augmentation (rephrase examples with GPT-4)

### Gradient Explosions

**Problem:** Loss becomes NaN or jumps wildly.

**Fixes:**
- Gradient clipping: `max_grad_norm=0.3` (already in config above)
- Lower learning rate
- Check for bad training examples (nulls, extremely long sequences)
- Use bf16 instead of fp16 (bf16 has wider dynamic range)

### OOM During Training

**Problem:** CUDA out of memory error.

**Fixes (in order of impact):**
1. Reduce `per_device_train_batch_size` to 1, increase `gradient_accumulation_steps`
2. Enable `gradient_checkpointing=True`
3. Reduce `max_seq_length`
4. Switch from LoRA to QLoRA (4-bit quantization)
5. Use Flash Attention 2

---

## Quick Reference: Target Modules by Architecture

```python
# LLaMA / Mistral / Qwen
target_modules = ["q_proj", "v_proj", "k_proj", "o_proj", "gate_proj", "up_proj", "down_proj"]

# Minimal (attention only, less memory):
target_modules = ["q_proj", "v_proj"]

# GPT-2 / Falcon
target_modules = ["c_attn", "c_proj"]

# BERT / RoBERTa (classification)
target_modules = ["query", "value"]

# T5 / Flan-T5
target_modules = ["q", "v"]
```

---

## Dependencies

```bash
pip install peft trl transformers accelerate bitsandbytes datasets
# For Flash Attention 2:
pip install flash-attn --no-build-isolation
# Experiment tracking:
pip install wandb mlflow
```
