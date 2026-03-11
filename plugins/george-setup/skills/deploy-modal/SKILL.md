---
name: deploy-modal
description: "Use when deploying Modal workers, checking Modal logs, managing Modal secrets, or configuring GPU endpoints. Triggers on modal deploy, Modal worker, Modal app, Modal logs, Modal secret, modal run, Modal endpoint, keep_warm, cold start, Modal proxy token, wk- ws- token, 8-endpoint limit, Modal GPU, memory sizing, deploy_all.py, Modal Python worker."
---

# Deploy Modal

Check project CLAUDE.md for worker paths and deploy entry points.

## Commands
| Task | Command |
|------|---------|
| Deploy app | `modal deploy path/to/app.py` |
| List apps | `modal app list` |
| View logs | `modal app logs app-name` |
| Set secret | `modal secret create name KEY=value` |
| Run ad-hoc | `modal run path/to/script.py` |

## Gotchas
- **8-endpoint limit** — multi-route workers consolidate endpoints
- **Proxy auth tokens** (`wk-*`/`ws-*`) differ from CLI tokens (`ak-*`/`as-*`) — Convex env vars use proxy tokens
- **Memory sizing**: right-size per worker to reduce costs
- **Cold starts**: use `keep_warm=1` for latency-sensitive endpoints

## Worker Pattern
```python
app = modal.App("worker-name")
image = modal.Image.debian_slim().pip_install(...)

@app.function(image=image, memory=512)
@modal.web_endpoint(method="POST")
def endpoint(request: dict):
    ...
```
