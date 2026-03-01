#!/usr/bin/env bash
# Cost Tracker — source this file to get cost tracking functions
# Usage: source ~/.claude/scripts/cost-tracker.sh

# Model pricing (per million tokens, USD)
declare -A COST_INPUT_PER_MTOK=(
    ["sonnet"]=3
    ["opus"]=15
    ["haiku"]=0.80
)
declare -A COST_OUTPUT_PER_MTOK=(
    ["sonnet"]=15
    ["opus"]=75
    ["haiku"]=4
)

cost_init() {
    local cost_file="${1:-.autopilot/costs.json}"
    if [[ ! -f "$cost_file" ]]; then
        mkdir -p "$(dirname "$cost_file")"
        cat > "$cost_file" << 'COSTSEOF'
{
    "iterations": [],
    "total_input_tokens": 0,
    "total_output_tokens": 0,
    "estimated_cost_usd": 0,
    "started_at": null,
    "model": "sonnet"
}
COSTSEOF
        python3 -c "
import json, datetime
d = json.load(open('$cost_file'))
d['started_at'] = datetime.datetime.now().isoformat()
json.dump(d, open('$cost_file', 'w'), indent=2)
" 2>/dev/null
    fi
}

cost_extract_tokens() {
    # Extract token counts from claude verbose/stream-json output
    local log_file="$1"
    local input_tokens=0
    local output_tokens=0

    if [[ -f "$log_file" ]]; then
        # Try stream-json format first
        input_tokens=$(grep -oP '"input_tokens":\s*\K\d+' "$log_file" 2>/dev/null | tail -1)
        output_tokens=$(grep -oP '"output_tokens":\s*\K\d+' "$log_file" 2>/dev/null | tail -1)

        # Fallback: try verbose text format
        if [[ -z "$input_tokens" || "$input_tokens" == "0" ]]; then
            input_tokens=$(grep -oP 'input tokens:\s*\K\d+' "$log_file" 2>/dev/null | tail -1)
        fi
        if [[ -z "$output_tokens" || "$output_tokens" == "0" ]]; then
            output_tokens=$(grep -oP 'output tokens:\s*\K\d+' "$log_file" 2>/dev/null | tail -1)
        fi
    fi

    echo "${input_tokens:-0} ${output_tokens:-0}"
}

cost_append() {
    local cost_file="$1"
    local label="$2"
    local input_tokens="${3:-0}"
    local output_tokens="${4:-0}"
    local model="${5:-sonnet}"

    [[ ! -f "$cost_file" ]] && cost_init "$cost_file"

    python3 -c "
import json, datetime
d = json.load(open('$cost_file'))
input_rate = ${COST_INPUT_PER_MTOK[$model]:-3}
output_rate = ${COST_OUTPUT_PER_MTOK[$model]:-15}
iteration_cost = ($input_tokens * input_rate + $output_tokens * output_rate) / 1000000
d['iterations'].append({
    'label': '$label',
    'timestamp': datetime.datetime.now().isoformat(),
    'input_tokens': $input_tokens,
    'output_tokens': $output_tokens,
    'model': '$model',
    'cost_usd': round(iteration_cost, 4)
})
d['total_input_tokens'] += $input_tokens
d['total_output_tokens'] += $output_tokens
d['estimated_cost_usd'] = round(d['estimated_cost_usd'] + iteration_cost, 4)
json.dump(d, open('$cost_file', 'w'), indent=2)
" 2>/dev/null
}

cost_total() {
    local cost_file="${1:-.autopilot/costs.json}"
    if [[ -f "$cost_file" ]]; then
        python3 -c "import json; print(json.load(open('$cost_file'))['estimated_cost_usd'])" 2>/dev/null
    else
        echo "0"
    fi
}

cost_report() {
    local cost_file="${1:-.autopilot/costs.json}"
    if [[ ! -f "$cost_file" ]]; then
        echo "No cost data found at $cost_file"
        return 1
    fi

    python3 -c "
import json
d = json.load(open('$cost_file'))
print(f\"=== Cost Report ===\")
print(f\"Total iterations: {len(d['iterations'])}\")
print(f\"Total input tokens: {d['total_input_tokens']:,}\")
print(f\"Total output tokens: {d['total_output_tokens']:,}\")
print(f\"Estimated cost: \${d['estimated_cost_usd']:.2f}\")
if d['iterations']:
    avg = d['estimated_cost_usd'] / len(d['iterations'])
    print(f\"Average cost per iteration: \${avg:.4f}\")
    print(f\"\nLast 5 iterations:\")
    for it in d['iterations'][-5:]:
        print(f\"  {it['label']}: \${it['cost_usd']:.4f} ({it['input_tokens']:,} in, {it['output_tokens']:,} out) [{it['model']}]\")
" 2>/dev/null
}

cost_check_budget() {
    local cost_file="$1"
    local budget_limit="$2"

    [[ -z "$budget_limit" ]] && return 0  # No limit = always pass

    local current_cost
    current_cost=$(cost_total "$cost_file")

    python3 -c "
import sys
current = float('${current_cost}')
limit = float('${budget_limit}')
if current >= limit:
    print(f'BUDGET EXCEEDED: \${current:.2f} spent of \${limit:.2f} limit', file=sys.stderr)
    sys.exit(1)
elif current >= limit * 0.8:
    print(f'BUDGET WARNING: \${current:.2f} of \${limit:.2f} ({current/limit*100:.0f}%)', file=sys.stderr)
    sys.exit(0)
" 2>/dev/null
}
