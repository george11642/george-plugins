# HTTP and Networking in Shell Scripts

curl, wget, retry patterns, API integration, and network utilities.

---

## 1. curl Best Practices

### Core Flags

```bash
# The production-safe curl invocation
curl -fsSL "https://example.com/file"

# Flag breakdown:
# -f / --fail        Non-zero exit on HTTP 4xx/5xx (CRITICAL — without this,
#                    curl exits 0 even on 404!)
# -s / --silent      No progress meter or error messages
# -S / --show-error  But DO show errors (use with -s, otherwise silent hides errors)
# -L / --location    Follow redirects

# Add these for production reliability:
curl -fsSL \
    --retry 3 \                 # Retry up to 3 times on transient failures
    --retry-delay 2 \           # Wait 2s between retries
    --retry-all-errors \        # Retry on any error (not just network errors)
    --connect-timeout 10 \      # Give up connecting after 10s
    --max-time 60 \             # Total time limit 60s
    "https://api.example.com/data"
```

### Distinguishing Exit Codes from HTTP Status

```bash
# THE MOST COMMON MISTAKE: checking only exit code
response=$(curl -sS "https://api.example.com/data")
# $? is 0 even if server returned 404 or 500!

# CORRECT PATTERN: capture both HTTP status and response body
http_call() {
    local url="$1"
    local response http_status

    # -w writes the status code AFTER the body to stdout
    # -o /dev/fd/3 sends body to fd 3 (avoids mixing with status)
    exec 3>&1  # Save stdout to fd 3
    http_status=$(curl -sS \
        --connect-timeout 10 \
        --max-time 60 \
        -w "%{http_code}" \
        -o >(cat >&3) \
        "$url" 2>&1)
    exec 3>&-

    echo "$http_status"
}

# Simpler pattern using temp file:
api_get() {
    local url="$1"
    local body_file
    body_file=$(mktemp)
    trap "rm -f '$body_file'" RETURN

    local http_code
    http_code=$(curl -sS \
        --connect-timeout 10 \
        --max-time 60 \
        -w "%{http_code}" \
        -o "$body_file" \
        "$url")
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        log_error "curl failed with exit code $exit_code for $url"
        return $exit_code
    fi

    if [[ "$http_code" -lt 200 ]] || [[ "$http_code" -ge 300 ]]; then
        log_error "HTTP $http_code from $url: $(cat "$body_file")"
        return 1
    fi

    cat "$body_file"
}

# Usage:
body=$(api_get "https://api.example.com/users") || exit 1
echo "$body" | jq .
```

---

## 2. curl Exit Codes Reference

| Exit Code | Meaning |
|-----------|---------|
| 0 | Success |
| 1 | Unsupported protocol |
| 3 | URL malformed |
| 6 | Could not resolve host |
| 7 | Failed to connect to host |
| 22 | HTTP response >= 400 (with `-f` flag) |
| 23 | Write error |
| 28 | Operation timed out |
| 35 | SSL connect error |
| 52 | Empty reply from server |
| 56 | Network receive failure |

---

## 3. Authentication Headers

```bash
# Bearer token (OAuth2 / JWT)
curl -fsSL \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    "https://api.example.com/protected"

# API key in header
curl -fsSL \
    -H "X-API-Key: ${API_KEY}" \
    -H "Accept: application/json" \
    "https://api.example.com/data"

# Basic auth
curl -fsSL \
    -u "${USERNAME}:${PASSWORD}" \
    "https://api.example.com/admin"

# Or with header (avoids password in process list)
BASIC_AUTH=$(echo -n "${USERNAME}:${PASSWORD}" | base64)
curl -fsSL \
    -H "Authorization: Basic ${BASIC_AUTH}" \
    "https://api.example.com/admin"
```

---

## 4. JSON Requests and Responses

```bash
# POST JSON data
curl -fsSL \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{"name":"Alice","role":"admin"}' \
    "https://api.example.com/users"

# POST with JSON from variable (safe quoting)
payload=$(jq -n \
    --arg name "$USERNAME" \
    --arg email "$EMAIL" \
    '{"name":$name,"email":$email}')
curl -fsSL \
    -X POST \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "https://api.example.com/users"

# Parse JSON response with jq
get_user_id() {
    local username="$1"
    curl -fsSL \
        -H "Authorization: Bearer $TOKEN" \
        "https://api.example.com/users?name=$username" \
        | jq -r '.[0].id'
}

# Validate JSON before sending
validate_json() {
    echo "$1" | jq empty 2>/dev/null || { echo "ERROR: Invalid JSON" >&2; return 1; }
}
```

---

## 5. Download with Progress and Resume

```bash
# Download with progress bar (use when interactive)
curl -L --progress-bar -o "output.tar.gz" "https://example.com/large-file.tar.gz"

# Resume interrupted download (-C - = auto-detect offset)
curl -fsSL -C - -o "output.tar.gz" "https://example.com/large-file.tar.gz"

# Download with checksum verification
download_verified() {
    local url="$1"
    local output="$2"
    local expected_sha256="$3"

    log_info "Downloading $url"
    curl -fsSL --progress-bar -o "$output" "$url"

    log_info "Verifying checksum..."
    local actual_sha256
    actual_sha256=$(sha256sum "$output" | awk '{print $1}')

    if [[ "$actual_sha256" != "$expected_sha256" ]]; then
        log_error "Checksum mismatch!"
        log_error "Expected: $expected_sha256"
        log_error "Actual:   $actual_sha256"
        rm -f "$output"
        return 1
    fi
    log_info "Checksum OK"
}
```

---

## 6. Complete Functions: download_with_retry, api_call_with_backoff

```bash
# ─── download_with_retry ───────────────────────────────────────────────────────
download_with_retry() {
    local url="$1"
    local output="${2:--}"      # Default to stdout
    local max_attempts="${3:-3}"
    local attempt=1
    local wait=2

    while [[ $attempt -le $max_attempts ]]; do
        log_info "Download attempt $attempt/$max_attempts: $url"

        if [[ "$output" == "-" ]]; then
            curl -fsSL \
                --connect-timeout 15 \
                --max-time 300 \
                "$url" && return 0
        else
            curl -fsSL \
                --connect-timeout 15 \
                --max-time 300 \
                -C - \
                -o "$output" \
                "$url" && return 0
        fi

        local exit_code=$?
        log_warn "Download failed (curl exit: $exit_code), retrying in ${wait}s..."
        sleep "$wait"
        wait=$(( wait * 2 ))    # Exponential backoff: 2, 4, 8...
        (( attempt++ ))
    done

    log_error "Download failed after $max_attempts attempts: $url"
    return 1
}

# ─── api_call_with_backoff ─────────────────────────────────────────────────────
api_call_with_backoff() {
    local method="$1"       # GET | POST | PUT | DELETE | PATCH
    local url="$2"
    local data="${3:-}"     # Optional JSON body
    local max_attempts="${4:-5}"
    local base_wait="${5:-1}"

    local attempt=1
    local wait=$base_wait
    local response body_file http_code

    body_file=$(mktemp)
    trap "rm -f '$body_file'" RETURN

    while [[ $attempt -le $max_attempts ]]; do
        local curl_args=(
            -sS
            -X "$method"
            --connect-timeout 10
            --max-time 60
            -w "%{http_code}"
            -o "$body_file"
        )

        if [[ -n "$data" ]]; then
            curl_args+=(-H "Content-Type: application/json" -d "$data")
        fi

        [[ -n "${API_TOKEN:-}" ]] && curl_args+=(-H "Authorization: Bearer $API_TOKEN")

        http_code=$(curl "${curl_args[@]}" "$url" 2>/dev/null)
        local exit_code=$?

        # Network-level failure — always retry
        if [[ $exit_code -ne 0 ]]; then
            log_warn "API call attempt $attempt/$max_attempts failed (curl exit: $exit_code)"

        # 429 Too Many Requests — respect Retry-After if present, else backoff
        elif [[ "$http_code" == "429" ]]; then
            log_warn "API rate limited (429), attempt $attempt/$max_attempts"

        # 5xx Server errors — retry
        elif [[ "$http_code" -ge 500 ]]; then
            log_warn "API server error ($http_code), attempt $attempt/$max_attempts"

        # 4xx Client errors — do NOT retry (our fault)
        elif [[ "$http_code" -ge 400 ]]; then
            log_error "API client error ($http_code) from $url: $(cat "$body_file")"
            return 1

        # 2xx Success
        else
            cat "$body_file"
            return 0
        fi

        [[ $attempt -lt $max_attempts ]] || break
        log_info "Retrying in ${wait}s..."
        sleep "$wait"
        # Exponential backoff with jitter
        wait=$(( wait * 2 + RANDOM % 3 ))
        (( attempt++ ))
    done

    log_error "API call failed after $max_attempts attempts: $method $url"
    return 1
}

# Usage:
# api_call_with_backoff GET "https://api.example.com/users"
# api_call_with_backoff POST "https://api.example.com/users" '{"name":"Alice"}'
```

---

## 7. check_port Function

```bash
# ─── check_port ────────────────────────────────────────────────────────────────
check_port() {
    local host="$1"
    local port="$2"
    local timeout="${3:-5}"

    # Method 1: bash /dev/tcp (no external tools needed)
    if (timeout "$timeout" bash -c "echo >/dev/tcp/$host/$port") 2>/dev/null; then
        return 0
    fi
    return 1
}

# Wait for a port to become available
wait_for_port() {
    local host="$1"
    local port="$2"
    local timeout="${3:-60}"
    local interval="${4:-2}"
    local elapsed=0

    log_info "Waiting for $host:$port (timeout: ${timeout}s)"
    while ! check_port "$host" "$port" 2; do
        if [[ $elapsed -ge $timeout ]]; then
            log_error "Timed out waiting for $host:$port after ${timeout}s"
            return 1
        fi
        sleep "$interval"
        elapsed=$(( elapsed + interval ))
        log_debug "Still waiting... ${elapsed}s elapsed"
    done
    log_info "$host:$port is ready (after ${elapsed}s)"
}

# netcat alternative (when nc is available)
check_port_nc() {
    local host="$1" port="$2" timeout="${3:-5}"
    nc -z -w "$timeout" "$host" "$port" 2>/dev/null
}

# curl-based health check
wait_for_http() {
    local url="$1"
    local timeout="${2:-60}"
    local interval="${3:-3}"
    local elapsed=0

    log_info "Waiting for HTTP $url"
    while ! curl -fsS --connect-timeout 3 --max-time 5 "$url" >/dev/null 2>&1; do
        if [[ $elapsed -ge $timeout ]]; then
            log_error "HTTP health check timed out: $url"
            return 1
        fi
        sleep "$interval"
        elapsed=$(( elapsed + interval ))
    done
    log_info "HTTP endpoint ready: $url (after ${elapsed}s)"
}
```

---

## 8. wget Patterns

```bash
# wget vs curl decision:
# - curl: API calls, custom headers, complex auth, scripting (preferred)
# - wget: recursive downloads, FTP, simpler resume syntax, no-progress output

# Basic download
wget -q -O output.tar.gz "https://example.com/file.tar.gz"

# Quiet with retry
wget -q --tries=3 --wait=2 -O output.tar.gz "https://example.com/file.tar.gz"

# Resume
wget -q -c -O output.tar.gz "https://example.com/large-file.tar.gz"

# Custom headers (less ergonomic than curl)
wget -q --header="Authorization: Bearer $TOKEN" -O - "https://api.example.com/data"

# Recursive download (spider a site)
wget -q -r -l 2 --no-parent "https://example.com/docs/"

# Check if URL exists (HEAD request)
wget -q --spider "https://example.com/file.tar.gz" 2>&1 && echo "exists" || echo "not found"
```

---

## 9. API Rate Limiting

```bash
# Simple fixed-rate throttle
API_CALLS=0
API_WINDOW_START=$(date +%s)
API_MAX_CALLS_PER_MINUTE=60

throttled_api_call() {
    local url="$1"
    local now
    now=$(date +%s)
    local elapsed=$(( now - API_WINDOW_START ))

    if [[ $elapsed -ge 60 ]]; then
        API_CALLS=0
        API_WINDOW_START=$now
    fi

    if [[ $API_CALLS -ge $API_MAX_CALLS_PER_MINUTE ]]; then
        local wait=$(( 60 - elapsed + 1 ))
        log_info "Rate limit: sleeping ${wait}s"
        sleep "$wait"
        API_CALLS=0
        API_WINDOW_START=$(date +%s)
    fi

    (( API_CALLS++ ))
    curl -fsSL -H "Authorization: Bearer $API_TOKEN" "$url"
}

# Leaky bucket rate limiter using sleep
RATE_LIMIT_DELAY=0.5   # seconds between calls

call_with_rate_limit() {
    curl -fsSL "$1"
    sleep "$RATE_LIMIT_DELAY"
}

# Process list of URLs respecting rate limit
while IFS= read -r url; do
    result=$(call_with_rate_limit "$url")
    echo "$result" >> results.json
done < urls.txt
```

---

## 10. curl Tips and Gotchas

```bash
# Verbose debug output (shows headers, TLS handshake, etc.)
curl -v "https://api.example.com/data" 2>&1 | head -50

# Write timing info to stderr
curl -w "\nTime: %{time_total}s  DNS: %{time_namelookup}s  Connect: %{time_connect}s\n" \
    -o /dev/null -s "https://api.example.com"

# Ignore SSL certificate errors (DEVELOPMENT ONLY — never in production)
curl -k "https://self-signed.example.com"   # --insecure

# Use specific TLS version
curl --tls-max 1.3 --tlsv1.2 "https://api.example.com"

# Store and send cookies
curl -c /tmp/cookies.txt -b /tmp/cookies.txt "https://example.com/login"

# Follow redirects and show final URL
curl -sS -L -w "\nFinal URL: %{url_effective}\n" -o /dev/null "https://t.co/shortlink"

# Pipe to jq for pretty JSON
curl -fsSL "https://api.github.com/repos/owner/repo" | jq '.stargazers_count'

# Test if URL returns expected HTTP status
check_http_status() {
    local url="$1" expected="${2:-200}"
    local actual
    actual=$(curl -sS -o /dev/null -w "%{http_code}" "$url")
    [[ "$actual" == "$expected" ]] || {
        echo "Expected HTTP $expected but got $actual for $url" >&2
        return 1
    }
}
```
