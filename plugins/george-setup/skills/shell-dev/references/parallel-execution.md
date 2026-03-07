# Parallel Execution in Shell Scripts

xargs -P, GNU parallel, job control, process pools, and error propagation.

---

## 1. xargs -P for Parallel Batch Processing

`xargs -P N` runs up to N processes simultaneously.

```bash
# Basic: process files in parallel with 4 workers
find . -name "*.jpg" | xargs -P 4 -I{} convert {} {}.thumb.jpg

# -P 0 uses as many processes as possible (one per input)
echo "file1 file2 file3" | tr ' ' '\n' | xargs -P 0 -I{} process_file {}

# Process with multiple arguments per call (-n flag)
# -n 1: one argument per invocation (default with -I{})
# -n 5: pass up to 5 arguments at once (batch mode)
cat urls.txt | xargs -P 8 -n 1 curl -fsSL -O

# Use with find for parallel file processing
find /data -name "*.log" -print0 | xargs -0 -P $(nproc) -I{} gzip {}

# Compress files in parallel using all CPU cores
find . -name "*.txt" -print0 | xargs -0 -P "$(nproc)" gzip

# Parallel image resize
find ./images -name "*.png" | xargs -P 4 -I{} \
    bash -c 'convert "{}" -resize 800x600 "thumb_{}"'
```

### xargs with Shell Functions

```bash
# Functions are NOT exported to xargs subshells by default
# Must export with -f or use bash -c
process_item() {
    local item="$1"
    echo "Processing: $item"
    sleep 1
}
export -f process_item   # REQUIRED for xargs to see it

echo "a b c d e" | tr ' ' '\n' | xargs -P 4 -I{} bash -c 'process_item "$@"' _ {}
```

---

## 2. GNU Parallel Basic Syntax

GNU `parallel` is a superset of `xargs -P` with much richer features.

```bash
# Install: apt install parallel / brew install parallel

# Basic: same as xargs -P 4
cat urls.txt | parallel -j4 curl -fsSL -O {}

# Run a function on each line of input
parallel echo "Processing: {}" ::: file1 file2 file3

# Specify input with :::
parallel gzip ::: file1.txt file2.txt file3.txt

# Multiple input sources (combinatoric)
parallel echo {1} {2} ::: A B C ::: 1 2 3
# Runs: A 1, A 2, A 3, B 1, B 2, B 3, C 1, C 2, C 3

# From file with ::::
parallel process_file :::: input_list.txt

# Limit parallelism (50% of CPU cores)
parallel -j 50% my_command ::: input1 input2 input3

# Use all CPU cores
parallel -j $(nproc) compress_file ::: *.txt
```

---

## 3. GNU Parallel Advanced Options

```bash
# --keep-order (-k): output in input order (not completion order)
seq 1 10 | parallel -k -j4 'sleep $((RANDOM % 3)); echo {}'

# --progress: show progress bar
find . -name "*.jpg" | parallel --progress -j8 convert {} thumb_{}

# --eta: show estimated time to completion
seq 1 100 | parallel --eta -j4 'sleep 0.1; echo {}'

# --joblog: write job completion log (useful for resuming)
parallel --joblog /tmp/jobs.log -j4 process {} ::: input*
# Resume failed/incomplete jobs:
parallel --resume --joblog /tmp/jobs.log -j4 process {} ::: input*

# --results: save each job's stdout/stderr to files
parallel --results /tmp/results/ -j4 my_command {} ::: input1 input2 input3
# Creates: /tmp/results/1/stdout, /tmp/results/1/stderr, etc.

# --timeout: kill jobs that take too long
parallel --timeout 30 'curl -fsSL {}' ::: "${urls[@]}"

# --delay: minimum delay between job starts (rate limiting)
parallel --delay 0.5 -j4 api_call {} ::: "${ids[@]}"

# --pipe: parallelize stream processing (split stdin to multiple workers)
cat bigfile.txt | parallel --pipe -j4 --block 10M sort | sort -m
```

---

## 4. GNU Parallel --semaphore for Shared Resources

```bash
# Semaphore: limit concurrent access to a shared resource
# Useful when multiple parallel pipelines share a database, API, etc.

# Acquire semaphore (max 3 concurrent)
sem --id "db-writes" -j3 db_write_command "$item"

# In a loop:
for item in "${items[@]}"; do
    sem --id "my-sem" -j5 process_item "$item"
done
sem --wait --id "my-sem"   # Wait for all semaphore jobs to complete

# Combining parallel + semaphore: parallelize but limit DB writes
parallel -j20 'sem --id db -j3 db_insert {}' ::: "${all_items[@]}"
sem --wait --id db
```

---

## 5. Job Control: & wait wait -n

```bash
# Background all jobs and wait
for file in *.txt; do
    process_file "$file" &
done
wait   # Wait for ALL background jobs

# Capture PIDs for selective waiting
pids=()
for url in "${urls[@]}"; do
    curl -fsSL -O "$url" &
    pids+=($!)
done

# Wait for specific PID
wait "${pids[0]}"   # Wait for first download

# Wait for any job to complete (Bash 4.3+)
wait -n   # Returns exit code of the first job to finish

# Wait for all, check each exit code
all_ok=true
for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
        echo "Job $pid failed" >&2
        all_ok=false
    fi
done
$all_ok || exit 1
```

---

## 6. Process Pool Pattern (Bounded Parallelism)

Run exactly N jobs at a time without GNU parallel:

```bash
#!/bin/bash
# Process pool with bounded parallelism

WORKERS=4
PIDS=()

# Add a job to the pool; blocks if pool is full
pool_submit() {
    local cmd=("$@")

    # If pool is full, wait for one job to finish
    while [[ ${#PIDS[@]} -ge $WORKERS ]]; do
        local new_pids=()
        local pid
        for pid in "${PIDS[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                new_pids+=("$pid")   # Still running
            else
                wait "$pid" || echo "Job $pid failed" >&2
            fi
        done
        PIDS=("${new_pids[@]}")
        [[ ${#PIDS[@]} -ge $WORKERS ]] && sleep 0.1
    done

    # Start the job
    "${cmd[@]}" &
    PIDS+=($!)
}

# Wait for all remaining pool jobs
pool_drain() {
    local pid
    for pid in "${PIDS[@]}"; do
        wait "$pid" || echo "Job $pid failed" >&2
    done
    PIDS=()
}

# Usage:
for item in "${items[@]}"; do
    pool_submit process_item "$item"
done
pool_drain
echo "All done"
```

---

## 7. Error Propagation from Parallel Jobs

```bash
# Method 1: Collect all exit codes
run_parallel_with_errors() {
    local items=("$@")
    local pids=()
    local failed=()

    for item in "${items[@]}"; do
        process_item "$item" &
        pids+=($!)
    done

    for i in "${!pids[@]}"; do
        local pid="${pids[$i]}"
        local item="${items[$i]}"
        if ! wait "$pid"; then
            failed+=("$item (pid=$pid)")
        fi
    done

    if [[ ${#failed[@]} -gt 0 ]]; then
        echo "ERROR: ${#failed[@]} jobs failed:" >&2
        printf '  - %s\n' "${failed[@]}" >&2
        return 1
    fi
    return 0
}

# Method 2: Use a status directory
run_parallel_tracked() {
    local status_dir
    status_dir=$(mktemp -d)
    trap "rm -rf '$status_dir'" RETURN

    for item in "${items[@]}"; do
        (
            if process_item "$item"; then
                touch "$status_dir/ok_${item//\//_}"
            else
                touch "$status_dir/fail_${item//\//_}"
            fi
        ) &
    done
    wait

    local failures
    failures=$(find "$status_dir" -name "fail_*" | wc -l)
    if [[ $failures -gt 0 ]]; then
        echo "ERROR: $failures jobs failed" >&2
        return 1
    fi
}

# Method 3: GNU parallel exit code propagation
parallel --halt soon,fail=1 -j4 process_item ::: "${items[@]}"
# --halt soon,fail=1: stop after 1 failure, wait for running jobs
# --halt now,fail=1:  stop immediately (kill running jobs) on 1 failure
# --halt soon,fail=50%: stop when 50% have failed
```

---

## 8. parallel_map Function

A reusable parallel_map that mirrors functional map() semantics:

```bash
#!/bin/bash
# parallel_map WORKERS FUNCTION ITEMS...
# Applies FUNCTION to each item with WORKERS parallel processes.
# Returns 0 if all succeed, 1 if any fail. Output order is NOT guaranteed.

parallel_map() {
    local workers="$1"
    local func="$2"
    shift 2
    local items=("$@")

    if [[ ${#items[@]} -eq 0 ]]; then
        return 0
    fi

    # Require the function to be exported
    if ! declare -f "$func" > /dev/null 2>&1; then
        echo "parallel_map: function '$func' not found" >&2
        return 1
    fi
    export -f "$func"

    # Use GNU parallel if available (best results)
    if command -v parallel &>/dev/null; then
        printf '%s\n' "${items[@]}" | parallel -j"$workers" "$func" {}
        return $?
    fi

    # Fallback: manual process pool
    local pids=()
    local failed=0

    for item in "${items[@]}"; do
        # Wait if pool is full
        while [[ ${#pids[@]} -ge $workers ]]; do
            local remaining=()
            local pid
            for pid in "${pids[@]}"; do
                if kill -0 "$pid" 2>/dev/null; then
                    remaining+=("$pid")
                else
                    wait "$pid" || (( failed++ ))
                fi
            done
            pids=("${remaining[@]}")
            [[ ${#pids[@]} -ge $workers ]] && sleep 0.05
        done

        "$func" "$item" &
        pids+=($!)
    done

    # Drain remaining
    local pid
    for pid in "${pids[@]}"; do
        wait "$pid" || (( failed++ ))
    done

    return $failed
}

# ─── Example Usage ─────────────────────────────────────────────────────────────

compress_file() {
    local file="$1"
    echo "Compressing: $file"
    gzip --best --keep "$file"
}
export -f compress_file

# Compress 100 files using 8 parallel workers
files=(*.log)
parallel_map 8 compress_file "${files[@]}" || echo "Some files failed to compress"

# Download multiple URLs in parallel
download_url() {
    local url="$1"
    local filename
    filename=$(basename "$url")
    curl -fsSL --retry 3 -o "/tmp/$filename" "$url" && echo "Downloaded: $filename"
}
export -f download_url

parallel_map 6 download_url "${urls[@]}"
```

---

## 9. xargs vs GNU Parallel Decision Tree

```
Need parallel execution?
├─ Input: stdin lines or file list?
│   ├─ Simple command, no shell features needed?
│   │   ├─ Need max N parallel: xargs -P N -I{} cmd {}
│   │   └─ Want all cores:      xargs -P $(nproc) cmd
│   │
│   └─ Need shell features (functions, logic, conditionals)?
│       ├─ Use parallel -j N 'shell_expression {}' ::: inputs
│       └─ Or: xargs -P N bash -c 'function_name "$@"' _ {}
│
├─ Need output in input order? → parallel -k (or --keep-order)
├─ Need progress reporting?    → parallel --progress
├─ Need to resume on failure?  → parallel --joblog FILE --resume
├─ Need rate limiting?         → parallel --delay N
├─ Need shared resource limit? → parallel + sem
│
├─ No GNU parallel available?
│   ├─ Simple: for loop with & and wait
│   ├─ Bounded: process pool pattern (see above)
│   └─ File-based: xargs -P
│
└─ Performance note:
    xargs: lower overhead per job, better for simple commands
    GNU parallel: richer features, slight overhead, better error handling
```

---

## 10. Throttling and Rate Limiting in Parallel Contexts

```bash
# Rate-limited parallel downloads (max 10/second)
rate_limited_download() {
    local url="$1"
    sem --id download-rate -j10 curl -fsSL -O "$url"
}
export -f rate_limited_download
parallel -j0 rate_limited_download ::: "${urls[@]}"

# Global sleep-based throttle between job submissions
submit_with_delay() {
    local delay="$1"  # seconds between submissions
    shift
    local items=("$@")
    for item in "${items[@]}"; do
        process_item "$item" &
        sleep "$delay"
    done
    wait
}

# Combine: 8 parallel workers, 0.5s submission delay
for item in "${items[@]}"; do
    pool_submit process_item "$item"
    sleep 0.1   # 10 submissions/second max
done
pool_drain
```

---

## 11. Practical Examples

```bash
# 1. Parallel SSH commands across a server list
while IFS= read -r host; do
    ssh -o StrictHostKeyChecking=no "$host" 'uptime' &
done < servers.txt
wait

# 2. Parallel test execution
find tests/ -name "test_*.sh" | parallel -j4 bash {}

# 3. Parallel checksum verification
sha256sum --check sums.txt | parallel -j8

# 4. Parallel log compression (last month's logs)
find /var/log -name "*.log" -mtime +30 | \
    parallel -j$(nproc) 'gzip -9 {} && echo "Compressed: {}"'

# 5. Build multiple Docker images in parallel
parallel -j4 'docker build -t myapp:{} contexts/{}' ::: dev staging prod

# 6. Parallel database exports
parallel -j3 'pg_dump mydb_{} > /backup/{}.sql' ::: users orders products
```
