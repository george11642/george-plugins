#!/usr/bin/env bash
#
# ios-sim-health.sh - Check health of iOS Simulator Docker-OSX environment
# Usage: ios-sim-health.sh
# Exit codes: 0 = all checks pass, 1 = one or more checks fail
#

set -euo pipefail

# Constants
readonly CONTAINER_NAME="macos-dev"
readonly SSH_PORT="50922"
readonly VNC_PORT="5999"
readonly SSH_USER="user"
readonly SSH_PASS="alpine"
readonly SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5"

# Global state
declare -i FAILED_CHECKS=0

# Logging functions
log_info() {
  printf "[INFO] %s\n" "$*" >&2
}

log_pass() {
  printf "[PASS] %s\n" "$*"
}

log_fail() {
  printf "[FAIL] %s\n" "$*"
  FAILED_CHECKS+=1
}

# SSH helper
ssh_exec() {
  if command -v sshpass &>/dev/null; then
    sshpass -p "$SSH_PASS" ssh $SSH_OPTS -p "$SSH_PORT" "${SSH_USER}@localhost" "$@" 2>/dev/null
  else
    ssh $SSH_OPTS -p "$SSH_PORT" "${SSH_USER}@localhost" "$@" 2>/dev/null
  fi
}

# Check 1: Docker daemon
check_docker() {
  log_info "Checking Docker daemon..."

  if docker info &>/dev/null; then
    log_pass "Docker daemon is running"
  else
    log_fail "Docker daemon is not running"
    return 1
  fi

  if docker inspect "$CONTAINER_NAME" &>/dev/null; then
    local container_status
    container_status=$(docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME")

    if [[ "$container_status" == "running" ]]; then
      log_pass "Container '$CONTAINER_NAME' is running"
    else
      log_fail "Container '$CONTAINER_NAME' exists but is not running (status: $container_status)"
      return 1
    fi
  else
    log_fail "Container '$CONTAINER_NAME' does not exist"
    return 1
  fi

  return 0
}

# Check 2: SSH connectivity
check_ssh() {
  log_info "Checking SSH connectivity..."

  if ssh_exec "echo ok" &>/dev/null; then
    log_pass "SSH connection successful on port $SSH_PORT"
    return 0
  else
    log_fail "Cannot connect to SSH on port $SSH_PORT"
    return 1
  fi
}

# Check 3: macOS version
check_macos() {
  log_info "Checking macOS version..."

  local macos_version
  if macos_version=$(ssh_exec "sw_vers -productVersion" 2>/dev/null); then
    log_pass "macOS version: $macos_version"
    return 0
  else
    log_fail "Cannot retrieve macOS version"
    return 1
  fi
}

# Check 4: Xcode
check_xcode() {
  log_info "Checking Xcode..."

  local xcode_version
  if xcode_version=$(ssh_exec "xcodebuild -version 2>/dev/null | head -n 1" 2>/dev/null); then
    log_pass "Xcode: $xcode_version"
    return 0
  else
    log_fail "Cannot retrieve Xcode version"
    return 1
  fi
}

# Check 5: Simulator
check_simulator() {
  log_info "Checking simulator status..."

  local booted_sims
  if booted_sims=$(ssh_exec "xcrun simctl list devices booted" 2>/dev/null); then
    if [[ "$booted_sims" == *"Booted"* ]]; then
      local sim_count
      sim_count=$(echo "$booted_sims" | grep -c "Booted" || echo "0")
      log_pass "Simulator: $sim_count device(s) booted"
      return 0
    else
      log_fail "Simulator: No devices booted"
      return 1
    fi
  else
    log_fail "Cannot query simulator status"
    return 1
  fi
}

# Check 6: VNC port
check_vnc() {
  log_info "Checking VNC port..."

  if command -v nc &>/dev/null; then
    if nc -z localhost "$VNC_PORT" &>/dev/null; then
      log_pass "VNC port $VNC_PORT is reachable"
      return 0
    else
      log_fail "VNC port $VNC_PORT is not reachable"
      return 1
    fi
  else
    log_fail "netcat (nc) not available, cannot check VNC port"
    return 1
  fi
}

# Check 7: Disk space
check_disk() {
  log_info "Checking VM disk space..."

  local disk_info
  if disk_info=$(ssh_exec "df -h / | tail -n 1" 2>/dev/null); then
    local used_pct
    used_pct=$(echo "$disk_info" | awk '{print $5}' | tr -d '%')

    if [[ -n "$used_pct" ]] && (( used_pct < 90 )); then
      log_pass "Disk space: $used_pct% used (healthy)"
      return 0
    else
      log_fail "Disk space: $used_pct% used (>90% threshold)"
      return 1
    fi
  else
    log_fail "Cannot retrieve disk space information"
    return 1
  fi
}

# Print summary table
print_summary() {
  printf "\n"
  printf "=== Health Check Summary ===\n"
  printf "Total checks: 7\n"
  printf "Failed checks: %d\n" "$FAILED_CHECKS"

  if (( FAILED_CHECKS == 0 )); then
    printf "Status: ALL SYSTEMS HEALTHY\n"
  else
    printf "Status: ISSUES DETECTED\n"
  fi
  printf "\n"
}

# Main execution
main() {
  log_info "Running health checks for iOS Simulator environment..."
  printf "\n"

  check_docker || true
  check_ssh || true
  check_macos || true
  check_xcode || true
  check_simulator || true
  check_vnc || true
  check_disk || true

  print_summary

  if (( FAILED_CHECKS > 0 )); then
    exit 1
  fi

  exit 0
}

main "$@"
