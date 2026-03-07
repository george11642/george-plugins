# Docker Reference

## Dockerfile Best Practices

### Multi-Stage Builds

Use multi-stage builds to keep final images small. Build dependencies stay in the build stage; only runtime artifacts reach the final image.

```dockerfile
# Stage 1: Build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --production=false
COPY . .
RUN npm run build

# Stage 2: Runtime
FROM node:20-alpine AS runtime
WORKDIR /app
RUN addgroup -g 1001 appgroup && adduser -u 1001 -G appgroup -D appuser
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./
USER appuser
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://localhost:3000/health || exit 1
CMD ["node", "dist/index.js"]
```

Why multi-stage: a Node.js build image is ~1GB. The runtime image with only production deps can be ~150MB. Smaller images = faster pulls, smaller attack surface.

### Layer Ordering

Order Dockerfile instructions from least to most frequently changing. Docker caches layers -- changing an early layer invalidates all subsequent layers.

```dockerfile
# GOOD: Dependencies change less often than source code
COPY package*.json ./
RUN npm ci
COPY . .

# BAD: Copying everything first busts the npm ci cache on every code change
COPY . .
RUN npm ci
```

### Image Optimization

| Technique | Impact | How |
|-----------|--------|-----|
| Alpine base images | 5MB vs 120MB | `FROM python:3.12-alpine` |
| Distroless images | Minimal attack surface | `FROM gcr.io/distroless/python3` |
| .dockerignore | Faster builds | Exclude `node_modules`, `.git`, `*.md` |
| Combine RUN commands | Fewer layers | `RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*` |
| Copy specific files | Better caching | `COPY src/ ./src/` instead of `COPY . .` |
| Pin versions | Reproducibility | `FROM node:20.11.0-alpine3.19` |

### Security

1. **Never run as root** -- add `USER nonroot` after creating the user
2. **Don't store secrets in images** -- use build args only for non-sensitive config; use runtime env vars or mounted secrets for credentials
3. **Scan images** -- `docker scout cves app:v1` or `trivy image app:v1`
4. **Use read-only filesystem** -- `docker run --read-only --tmpfs /tmp app:v1`
5. **Drop capabilities** -- `docker run --cap-drop=ALL --cap-add=NET_BIND_SERVICE app:v1`
6. **No `ADD` for remote URLs** -- use `COPY` + explicit `curl`/`wget`. `ADD` auto-extracts and fetches, which is unpredictable

### .dockerignore

```
.git
.gitignore
node_modules
npm-debug.log
Dockerfile
docker-compose*.yml
.env
*.md
.vscode
.idea
__pycache__
*.pyc
.pytest_cache
coverage/
dist/
```

## Docker Compose

### Production-Ready Compose File

```yaml
version: "3.9"

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
      target: runtime
    ports:
      - "8080:3000"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=${DATABASE_URL}
    depends_on:
      db:
        condition: service_healthy
    deploy:
      resources:
        limits:
          cpus: "1.0"
          memory: 512M
        reservations:
          cpus: "0.25"
          memory: 128M
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:3000/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s

  db:
    image: postgres:16-alpine
    volumes:
      - pgdata:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    command: redis-server --maxmemory 256mb --maxmemory-policy allkeys-lru
    volumes:
      - redisdata:/data

volumes:
  pgdata:
  redisdata:
```

### Compose Patterns

- **Use `depends_on` with health checks** -- not just service ordering but actual readiness
- **Named volumes for persistence** -- anonymous volumes get lost on `docker compose down`
- **Resource limits** -- prevent a single container from consuming all host resources
- **Override files** -- `docker-compose.override.yml` for local dev (auto-loaded), `docker-compose.prod.yml` for production: `docker compose -f docker-compose.yml -f docker-compose.prod.yml up`

## Container Networking

```bash
# Create a custom network for service discovery
docker network create app-net

# Containers on the same network resolve each other by name
docker run --network app-net --name api app:v1
docker run --network app-net --name web nginx:alpine
# web can reach api at http://api:3000
```

Why custom networks: the default bridge network requires `--link` (deprecated). Custom networks provide automatic DNS resolution between containers.

## Container Debugging

```bash
# Inspect container details
docker inspect <id> | jq '.[0].State'

# View resource usage
docker stats --no-stream

# Copy files out of container
docker cp <id>:/app/logs/error.log ./error.log

# Run a debug sidecar with network tools
docker run --rm -it --network container:<id> nicolaka/netshoot

# Check image layers and sizes
docker history app:v1 --human --no-trunc

# Export filesystem for analysis
docker export <id> | tar -tf - | head -50
```

## Registry Operations

```bash
# Tag and push
docker tag app:v1 registry.example.com/app:v1
docker push registry.example.com/app:v1

# AWS ECR login
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account>.dkr.ecr.us-east-1.amazonaws.com

# GCR login
gcloud auth configure-docker

# Prune old images (keep last 5)
docker images --format '{{.Repository}}:{{.Tag}}' | grep app | tail -n +6 | xargs docker rmi
```

## Common Gotchas

1. **PID 1 problem** -- use `tini` or `dumb-init` as entrypoint so signals propagate correctly to your app
2. **DNS resolution in Alpine** -- musl libc resolves DNS differently than glibc. If DNS fails, add `RUN apk add --no-cache libc6-compat`
3. **Build context too large** -- `.dockerignore` is not optional. Without it, `docker build` sends your entire directory (including `node_modules`, `.git`) to the daemon
4. **Layer caching in CI** -- use `--cache-from` or BuildKit cache mounts: `RUN --mount=type=cache,target=/root/.cache/pip pip install -r requirements.txt`
5. **Zombie processes** -- Node.js and Python don't handle child process reaping. Use `--init` flag or tini
