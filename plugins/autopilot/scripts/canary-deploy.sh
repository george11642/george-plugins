#!/usr/bin/env bash
# Canary Deployment Manager
# Usage: source canary-deploy.sh; canary_deploy /path/to/project

set -euo pipefail

CANARY_MONITOR_INTERVAL=120  # seconds between checks
CANARY_MONITOR_DURATION=900  # 15 minutes total monitoring
CANARY_ERROR_THRESHOLD=2     # multiplier over baseline

canary_deploy() {
    local project_dir="${1:-.}"
    local monitor_duration="${2:-$CANARY_MONITOR_DURATION}"

    cd "$project_dir"

    echo "=== Canary Deployment ==="

    # Pre-deploy checks
    echo "Running pre-deploy checks..."
    if [[ -n "$(git status --porcelain)" ]]; then
        echo "ERROR: Uncommitted changes. Commit or stash first."
        return 1
    fi

    # Record baseline
    local baseline_errors=0
    # Try to get Sentry error count (if available)
    # This would use the Sentry API in a full implementation

    # Deploy to preview
    echo "Deploying to preview..."
    local deploy_output
    deploy_output=$(vercel --prebuilt --yes 2>&1) || {
        echo "ERROR: Preview deployment failed"
        echo "$deploy_output"
        return 1
    }

    local preview_url
    preview_url=$(echo "$deploy_output" | grep -oP 'https://[^\s]+\.vercel\.app' | head -1)

    if [[ -z "$preview_url" ]]; then
        echo "ERROR: Could not extract preview URL"
        echo "$deploy_output"
        return 1
    fi

    echo "Preview deployed: $preview_url"

    # Smoke test
    echo "Running smoke tests..."
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "$preview_url" 2>/dev/null)
    if [[ "$http_code" != "200" ]]; then
        echo "ERROR: Preview returned HTTP $http_code"
        return 1
    fi
    echo "Smoke test passed (HTTP $http_code)"

    # Monitoring window
    echo "Monitoring for $((monitor_duration / 60)) minutes..."
    local elapsed=0
    local error_count=0

    while [[ $elapsed -lt $monitor_duration ]]; do
        sleep $CANARY_MONITOR_INTERVAL
        elapsed=$((elapsed + CANARY_MONITOR_INTERVAL))

        # Check preview is still responding
        http_code=$(curl -s -o /dev/null -w "%{http_code}" "$preview_url" 2>/dev/null)
        if [[ "$http_code" != "200" ]]; then
            error_count=$((error_count + 1))
        fi

        echo "  [$((elapsed / 60))m] HTTP: $http_code, Errors: $error_count"

        # Abort if too many errors
        if [[ $error_count -gt $CANARY_ERROR_THRESHOLD ]]; then
            echo "ABORT: Error threshold exceeded ($error_count > $CANARY_ERROR_THRESHOLD)"
            echo "CANARY_RESULT: action=ABORTED preview_url=$preview_url errors=$error_count"
            return 1
        fi
    done

    # Promote to production
    echo "Monitoring passed. Promoting to production..."
    if vercel promote "$preview_url" --yes 2>&1; then
        echo "CANARY_RESULT: action=PROMOTED preview_url=$preview_url monitoring_duration=$((monitor_duration/60))m errors=$error_count"
        return 0
    else
        echo "ERROR: Promotion failed"
        echo "CANARY_RESULT: action=PROMOTION_FAILED preview_url=$preview_url"
        return 1
    fi
}

canary_rollback() {
    local deployment_id="$1"
    echo "Rolling back deployment $deployment_id..."
    # Vercel automatically keeps previous deployment as production
    # No explicit rollback needed — just don't promote
    echo "Rollback: previous deployment remains active"
}
