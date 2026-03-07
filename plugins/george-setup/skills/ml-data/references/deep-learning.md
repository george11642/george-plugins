# Deep Learning Reference

## PyTorch Fundamentals

### Tensors

```python
import torch

# Creation
x = torch.tensor([[1.0, 2.0], [3.0, 4.0]])
x = torch.zeros(3, 4)
x = torch.randn(3, 4)           # Normal distribution
x = torch.arange(0, 10, 0.5)   # Range with step

# Device management — always explicit
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
x = x.to(device)
# Or at creation:
x = torch.randn(3, 4, device=device)

# Shape operations
x.shape          # torch.Size([3, 4])
x.reshape(2, 6)  # Does NOT copy if possible
x.view(2, 6)     # Never copies — requires contiguous
x.permute(1, 0)  # Transpose (reorders dims without copy)
x.squeeze()      # Remove dims of size 1
x.unsqueeze(0)   # Add dim at index 0

# Type casting
x.float()   # float32
x.double()  # float64
x.long()    # int64 — needed for class indices
x.bool()

# Indexing — same as numpy
x[0]         # First row
x[:, 1]      # Second column
x[x > 0.5]  # Boolean mask
```

### Autograd

```python
# Requires grad for parameters, not data
w = torch.randn(3, 3, requires_grad=True)
x = torch.randn(3, 1)  # Input — no grad needed

y = w @ x
loss = y.sum()
loss.backward()  # Computes gradients

print(w.grad)    # dL/dw

# Stop gradient tracking
with torch.no_grad():
    predictions = model(x)  # No grad computation or storage

# Detach from graph (for logging/metrics)
loss_val = loss.detach().item()

# Zero gradients before backward (ALWAYS do this)
optimizer.zero_grad()
loss.backward()
optimizer.step()
```

---

## nn.Module — Building Blocks

```python
import torch.nn as nn

class MLP(nn.Module):
    def __init__(self, input_dim: int, hidden_dim: int, output_dim: int, dropout: float = 0.2):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(input_dim, hidden_dim),
            nn.BatchNorm1d(hidden_dim),
            nn.ReLU(),
            nn.Dropout(dropout),
            nn.Linear(hidden_dim, hidden_dim),
            nn.ReLU(),
            nn.Dropout(dropout),
            nn.Linear(hidden_dim, output_dim),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.net(x)

model = MLP(128, 256, 10).to(device)

# Inspect parameters
total_params = sum(p.numel() for p in model.parameters())
trainable_params = sum(p.numel() for p in model.parameters() if p.requires_grad)
print(f"Total: {total_params:,} | Trainable: {trainable_params:,}")

# Save / load
torch.save(model.state_dict(), "model.pt")
model.load_state_dict(torch.load("model.pt", map_location=device))
```

---

## Training Loop Boilerplate

```python
from torch.utils.data import DataLoader, TensorDataset

def train_epoch(model, loader, optimizer, criterion, device, scaler=None):
    model.train()
    total_loss = 0.0
    for batch_x, batch_y in loader:
        batch_x, batch_y = batch_x.to(device), batch_y.to(device)
        optimizer.zero_grad()
        if scaler is not None:
            # Mixed precision
            with torch.cuda.amp.autocast():
                preds = model(batch_x)
                loss = criterion(preds, batch_y)
            scaler.scale(loss).backward()
            scaler.unscale_(optimizer)
            torch.nn.utils.clip_grad_norm_(model.parameters(), max_norm=1.0)
            scaler.step(optimizer)
            scaler.update()
        else:
            preds = model(batch_x)
            loss = criterion(preds, batch_y)
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), max_norm=1.0)
            optimizer.step()
        total_loss += loss.item() * batch_x.size(0)
    return total_loss / len(loader.dataset)


@torch.no_grad()
def eval_epoch(model, loader, criterion, device):
    model.eval()
    total_loss = 0.0
    all_preds, all_labels = [], []
    for batch_x, batch_y in loader:
        batch_x, batch_y = batch_x.to(device), batch_y.to(device)
        preds = model(batch_x)
        loss = criterion(preds, batch_y)
        total_loss += loss.item() * batch_x.size(0)
        all_preds.append(preds.cpu())
        all_labels.append(batch_y.cpu())
    return total_loss / len(loader.dataset), torch.cat(all_preds), torch.cat(all_labels)


def fit(model, train_loader, val_loader, epochs=50, lr=1e-3, patience=5):
    optimizer = torch.optim.AdamW(model.parameters(), lr=lr, weight_decay=1e-4)
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=epochs)
    criterion = nn.CrossEntropyLoss()
    scaler = torch.cuda.amp.GradScaler() if device.type == "cuda" else None

    best_val_loss = float("inf")
    patience_counter = 0

    for epoch in range(epochs):
        train_loss = train_epoch(model, train_loader, optimizer, criterion, device, scaler)
        val_loss, preds, labels = eval_epoch(model, val_loader, criterion, device)
        scheduler.step()

        print(f"Epoch {epoch+1:3d} | train={train_loss:.4f} | val={val_loss:.4f} | lr={scheduler.get_last_lr()[0]:.2e}")

        if val_loss < best_val_loss:
            best_val_loss = val_loss
            patience_counter = 0
            torch.save(model.state_dict(), "best_model.pt")
        else:
            patience_counter += 1
            if patience_counter >= patience:
                print(f"Early stopping at epoch {epoch+1}")
                break

    model.load_state_dict(torch.load("best_model.pt", map_location=device))
    return model
```

---

## CNNs

```python
class ConvBlock(nn.Module):
    """Conv → BN → ReLU with optional residual."""
    def __init__(self, in_ch, out_ch, kernel=3, stride=1, padding=1):
        super().__init__()
        self.conv = nn.Conv2d(in_ch, out_ch, kernel, stride, padding, bias=False)
        self.bn = nn.BatchNorm2d(out_ch)
        self.act = nn.ReLU(inplace=True)

    def forward(self, x):
        return self.act(self.bn(self.conv(x)))


class SimpleCNN(nn.Module):
    def __init__(self, num_classes=10):
        super().__init__()
        self.features = nn.Sequential(
            ConvBlock(3, 32),
            ConvBlock(32, 32),
            nn.MaxPool2d(2, 2),          # HW halved
            nn.Dropout2d(0.25),
            ConvBlock(32, 64),
            ConvBlock(64, 64),
            nn.MaxPool2d(2, 2),
            nn.Dropout2d(0.25),
        )
        self.classifier = nn.Sequential(
            nn.AdaptiveAvgPool2d((1, 1)),  # Global average pooling — removes HW dependency
            nn.Flatten(),
            nn.Linear(64, 128),
            nn.ReLU(),
            nn.Dropout(0.5),
            nn.Linear(128, num_classes),
        )

    def forward(self, x):
        return self.classifier(self.features(x))
```

### Common Layer Reference

| Layer | When to use |
|---|---|
| `Conv2d(in, out, kernel, stride, padding)` | Feature extraction from images |
| `BatchNorm2d(channels)` | After conv, before activation — stabilizes training |
| `MaxPool2d(2, 2)` | Downsample, translation invariance |
| `AdaptiveAvgPool2d((1,1))` | Global pooling — removes fixed spatial size requirement |
| `Dropout2d(p)` | Drops entire channels — stronger than Dropout for conv layers |
| `GroupNorm(groups, channels)` | When batch size is too small for BatchNorm (e.g., detection) |

---

## Transformers

### Scaled Dot-Product Attention

```python
import math

def scaled_dot_product_attention(Q, K, V, mask=None):
    """
    Q: (batch, heads, seq, d_k)
    K: (batch, heads, seq, d_k)
    V: (batch, heads, seq, d_v)
    """
    d_k = Q.size(-1)
    scores = torch.matmul(Q, K.transpose(-2, -1)) / math.sqrt(d_k)
    if mask is not None:
        scores = scores.masked_fill(mask == 0, -1e9)
    weights = torch.softmax(scores, dim=-1)
    return torch.matmul(weights, V), weights
```

### Multi-Head Attention

```python
class MultiHeadAttention(nn.Module):
    def __init__(self, d_model: int, n_heads: int):
        super().__init__()
        assert d_model % n_heads == 0
        self.d_k = d_model // n_heads
        self.n_heads = n_heads
        self.W_q = nn.Linear(d_model, d_model)
        self.W_k = nn.Linear(d_model, d_model)
        self.W_v = nn.Linear(d_model, d_model)
        self.W_o = nn.Linear(d_model, d_model)

    def split_heads(self, x):
        B, T, D = x.shape
        return x.view(B, T, self.n_heads, self.d_k).transpose(1, 2)

    def forward(self, Q, K, V, mask=None):
        Q, K, V = self.split_heads(self.W_q(Q)), self.split_heads(self.W_k(K)), self.split_heads(self.W_v(V))
        x, _ = scaled_dot_product_attention(Q, K, V, mask)
        x = x.transpose(1, 2).contiguous().view(x.size(0), -1, self.n_heads * self.d_k)
        return self.W_o(x)
```

### Positional Encoding

```python
class PositionalEncoding(nn.Module):
    def __init__(self, d_model: int, max_len: int = 5000, dropout: float = 0.1):
        super().__init__()
        self.dropout = nn.Dropout(dropout)
        pe = torch.zeros(max_len, d_model)
        position = torch.arange(0, max_len).unsqueeze(1).float()
        div_term = torch.exp(torch.arange(0, d_model, 2).float() * (-math.log(10000.0) / d_model))
        pe[:, 0::2] = torch.sin(position * div_term)
        pe[:, 1::2] = torch.cos(position * div_term)
        self.register_buffer("pe", pe.unsqueeze(0))  # (1, max_len, d_model)

    def forward(self, x):
        return self.dropout(x + self.pe[:, :x.size(1)])
```

---

## Transfer Learning

### Freeze Base, Train Head

```python
import torchvision.models as models

# Load pretrained
backbone = models.resnet50(weights=models.ResNet50_Weights.IMAGENET1K_V2)

# Freeze all
for param in backbone.parameters():
    param.requires_grad = False

# Replace classifier head
backbone.fc = nn.Sequential(
    nn.Linear(backbone.fc.in_features, 256),
    nn.ReLU(),
    nn.Dropout(0.5),
    nn.Linear(256, num_classes),
)

# Only head parameters are trainable
optimizer = torch.optim.Adam(backbone.fc.parameters(), lr=1e-3)
```

### Progressive Unfreeze (Fine-tuning)

```python
def unfreeze_last_n_layers(model, n: int):
    """Unfreeze last n layers of a ResNet-style model."""
    layers = list(model.children())
    for layer in layers[-n:]:
        for param in layer.parameters():
            param.requires_grad = True

# Stage 1: Train head only (5 epochs)
fit(model, train_loader, val_loader, epochs=5, lr=1e-3)

# Stage 2: Unfreeze last block, lower LR
unfreeze_last_n_layers(backbone, 2)
optimizer = torch.optim.Adam([
    {"params": backbone.layer4.parameters(), "lr": 1e-4},
    {"params": backbone.fc.parameters(), "lr": 1e-3},
])

# Stage 3: Full fine-tune at very low LR
for param in backbone.parameters():
    param.requires_grad = True
optimizer = torch.optim.Adam(backbone.parameters(), lr=1e-5)
```

### HuggingFace BERT Fine-tuning

```python
from transformers import AutoTokenizer, AutoModelForSequenceClassification
import torch

model_name = "bert-base-uncased"
tokenizer = AutoTokenizer.from_pretrained(model_name)
model = AutoModelForSequenceClassification.from_pretrained(model_name, num_labels=2)
model = model.to(device)

# Tokenize
inputs = tokenizer(
    texts,
    padding=True,
    truncation=True,
    max_length=512,
    return_tensors="pt"
)

# Differential LR — transformer layers get lower LR than head
no_decay = ["bias", "LayerNorm.weight"]
optimizer_params = [
    {"params": [p for n, p in model.named_parameters() if not any(nd in n for nd in no_decay) and "classifier" not in n], "lr": 2e-5, "weight_decay": 0.01},
    {"params": [p for n, p in model.named_parameters() if any(nd in n for nd in no_decay) and "classifier" not in n], "lr": 2e-5, "weight_decay": 0.0},
    {"params": model.classifier.parameters(), "lr": 1e-4, "weight_decay": 0.01},
]
optimizer = torch.optim.AdamW(optimizer_params)
```

---

## GPU Training

### Device Management

```python
# Best practice: single device setup at top of script
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"Using: {device} | CUDA version: {torch.version.cuda}")

# Check memory
if device.type == "cuda":
    print(torch.cuda.get_device_name(0))
    print(f"Memory: {torch.cuda.get_device_properties(0).total_memory / 1e9:.1f} GB")
```

### Mixed Precision (torch.cuda.amp)

```python
# Speeds up training 2-3x on modern GPUs, halves memory
scaler = torch.cuda.amp.GradScaler()

for batch_x, batch_y in train_loader:
    batch_x, batch_y = batch_x.to(device), batch_y.to(device)
    optimizer.zero_grad()

    with torch.cuda.amp.autocast():  # FP16 forward pass
        output = model(batch_x)
        loss = criterion(output, batch_y)

    scaler.scale(loss).backward()           # Scaled gradients
    scaler.unscale_(optimizer)
    torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
    scaler.step(optimizer)
    scaler.update()
```

### DataParallel (Multi-GPU, Simple)

```python
if torch.cuda.device_count() > 1:
    model = nn.DataParallel(model)
    # Access original model: model.module
model = model.to(device)
```

### DistributedDataParallel (Multi-GPU, Production)

```python
# Launch with: torchrun --nproc_per_node=4 train.py
import torch.distributed as dist
from torch.nn.parallel import DistributedDataParallel as DDP

def main():
    dist.init_process_group("nccl")
    rank = dist.get_rank()
    local_rank = int(os.environ["LOCAL_RANK"])
    torch.cuda.set_device(local_rank)
    device = torch.device(f"cuda:{local_rank}")

    model = MyModel().to(device)
    model = DDP(model, device_ids=[local_rank])

    sampler = torch.utils.data.DistributedSampler(dataset)
    loader = DataLoader(dataset, sampler=sampler, batch_size=32)

    for epoch in range(epochs):
        sampler.set_epoch(epoch)  # Required for proper shuffling
        train_epoch(model, loader, ...)

    dist.destroy_process_group()
```

---

## Callbacks and Checkpointing

```python
import os

class Checkpoint:
    def __init__(self, path: str, monitor: str = "val_loss", mode: str = "min"):
        self.path = path
        self.monitor = monitor
        self.best = float("inf") if mode == "min" else float("-inf")
        self.mode = mode
        os.makedirs(os.path.dirname(path), exist_ok=True)

    def __call__(self, metrics: dict, model, optimizer, epoch: int) -> bool:
        val = metrics[self.monitor]
        improved = val < self.best if self.mode == "min" else val > self.best
        if improved:
            self.best = val
            torch.save({
                "epoch": epoch,
                "model_state": model.state_dict(),
                "optimizer_state": optimizer.state_dict(),
                "metrics": metrics,
            }, self.path)
            return True
        return False


def load_checkpoint(path: str, model, optimizer=None):
    ckpt = torch.load(path, map_location=device)
    model.load_state_dict(ckpt["model_state"])
    if optimizer:
        optimizer.load_state_dict(ckpt["optimizer_state"])
    return ckpt["epoch"], ckpt["metrics"]
```

---

## Common Architectures — Usage Patterns

### ResNet (Image Classification)

```python
from torchvision.models import resnet50, ResNet50_Weights

model = resnet50(weights=ResNet50_Weights.IMAGENET1K_V2)
# Replace head for custom num_classes
model.fc = nn.Linear(model.fc.in_features, num_classes)
```

### Vision Transformer (ViT)

```python
from torchvision.models import vit_b_16, ViT_B_16_Weights

model = vit_b_16(weights=ViT_B_16_Weights.IMAGENET1K_V1)
model.heads.head = nn.Linear(model.heads.head.in_features, num_classes)
# ViT requires 224x224 input with IMAGENET1K_V1 weights
```

### EfficientNet (Best accuracy/param tradeoff)

```python
from torchvision.models import efficientnet_b0, EfficientNet_B0_Weights

model = efficientnet_b0(weights=EfficientNet_B0_Weights.IMAGENET1K_V1)
model.classifier[1] = nn.Linear(model.classifier[1].in_features, num_classes)
```

---

## Debugging

### NaN Losses

```python
# 1. Check inputs for NaN/Inf
assert not torch.isnan(batch_x).any(), "NaN in input"
assert not torch.isinf(batch_x).any(), "Inf in input"

# 2. Register backward hook to catch where NaN appears
def check_nan_hook(grad):
    if torch.isnan(grad).any():
        raise ValueError(f"NaN gradient detected: {grad.shape}")

for name, param in model.named_parameters():
    param.register_hook(lambda g, n=name: (print(f"NaN in {n}") if torch.isnan(g).any() else None))

# 3. Use anomaly detection (slow, for debugging only)
with torch.autograd.detect_anomaly():
    loss.backward()

# Common causes: log(0), division by zero, exploding gradients
# Fix: clip gradients, reduce LR, check loss function inputs
```

### Vanishing Gradients

```python
# Monitor gradient norms during training
def log_grad_norms(model):
    norms = {}
    for name, param in model.named_parameters():
        if param.grad is not None:
            norms[name] = param.grad.norm().item()
    return norms

# Signs: loss stops changing, gradients near zero in early layers
# Fixes: use ReLU/GELU (not sigmoid/tanh), residual connections,
#        batch norm, gradient clipping, lower LR, skip connections
```

### Overfit Diagnosis

```python
# Plot train vs val loss — classic overfit: val diverges from train
import matplotlib.pyplot as plt

plt.plot(train_losses, label="train")
plt.plot(val_losses, label="val")
plt.axvline(best_epoch, ls="--", color="r", label="best epoch")
plt.legend()

# Fixes for overfitting:
# 1. More data (augmentation if image)
# 2. Increase dropout
# 3. Add weight decay: AdamW(lr=1e-3, weight_decay=1e-2)
# 4. Reduce model capacity
# 5. Early stopping (done above)
# 6. Label smoothing: CrossEntropyLoss(label_smoothing=0.1)
```

### Data Augmentation (Images)

```python
from torchvision import transforms

train_transform = transforms.Compose([
    transforms.RandomResizedCrop(224),
    transforms.RandomHorizontalFlip(),
    transforms.ColorJitter(brightness=0.2, contrast=0.2, saturation=0.2),
    transforms.RandomRotation(15),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),  # ImageNet stats
])

val_transform = transforms.Compose([
    transforms.Resize(256),
    transforms.CenterCrop(224),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
])
# NEVER apply augmentation to val/test — only normalization
```

---

## Loss Functions Quick Reference

| Problem | Loss | Notes |
|---|---|---|
| Multi-class classification | `CrossEntropyLoss` | Expects raw logits, not softmax |
| Binary classification | `BCEWithLogitsLoss` | More stable than BCE + sigmoid |
| Multi-label | `BCEWithLogitsLoss` | Each output is independent binary |
| Regression | `MSELoss` or `L1Loss` | L1 more robust to outliers |
| Huber (regression) | `SmoothL1Loss` | L2 near 0, L1 far from 0 |
| Imbalanced classes | `CrossEntropyLoss(weight=class_weights)` | Weight = 1/class_freq |

---

## Optimizer Quick Reference

| Optimizer | When to use |
|---|---|
| `AdamW(lr=1e-3, weight_decay=1e-2)` | Default for most deep learning |
| `SGD(lr=0.1, momentum=0.9, weight_decay=1e-4)` | CNNs from scratch, often better final accuracy |
| `Adam(lr=2e-4)` | GANs, transformers |
| `RMSprop(lr=1e-3)` | RNNs |

LR schedule: CosineAnnealingLR is safe default. OneCycleLR often trains faster.
