#!/usr/bin/env bash
#
# ios-sim-stop.sh - Gracefully shut down iOS Simulator and Docker-OSX container
# Usage: ios-sim-stop.sh
#

set -euo pipefail

# Constants
readonly CONTAINER_NAME="macos-dev"
readonly SSH_PORT="50922"
readonly SSH_USER="user"
readonly SSH_PASS="alpine"
readonly SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5"
readonly SHUTDOWN_WAIT=10
readonly DOCKER_STOP_TIMEOUT=60

# Logging functions
log_info() {
  printf "[INFO] %s\n" "$*" >&2
}

log_success() {
  printf "[SUCCESS] %s\n" "$*" >&2
}

log_error() {
  printf "[ERROR] %s\n" "$*" >&2
}

log_warn() {
  printf "[WARN] %s\n" "$*" >&2
}

# SSH helper
ssh_exec() {
  if command -v sshpass &>/dev/null; then
    sshpass -p "$SSH_PASS" ssh $SSH_OPTS -p "$SSH_PORT" "${SSH_USER}@localhost" "$@" 2>/dev/null || true
  else
    ssh $SSH_OPTS -p "$SSH_PORT" "${SSH_USER}@localhost" "$@" 2>/dev/null || true
  fi
}

# Check if container exists
check_container() {
  if ! docker inspect "$CONTAINER_NAME" &>/dev/null; then
    log_error "Container '$CONTAINER_NAME' does not exist"
    exit 1
  fi

  local container_status
  container_status=$(docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME")

  if [[ "$container_status" != "running" ]]; then
    log_warn "Container '$CONTAINER_NAME' is not running (status: $container_status)"
    exit 0
  fi

  log_info "Container '$CONTAINER_NAME' is running"
}

# Shut down all simulators
shutdown_simulators() {
  log_info "Shutting down all simulators..."

  if ssh_exec "xcrun simctl shutdown all"; then
    log_success "Simulators shut down"
  else
    log_warn "Failed to shut down simulators (may already be stopped)"
  fi
}

# Initiate macOS shutdown
shutdown_macos() {
  log_info "Initiating macOS shutdown..."

  # This command may fail if SSH connection drops during shutdown
  ssh_exec "echo '$SSH_PASS' | sudo -S shutdown -h now" || log_warn "macOS shutdown command sent (connection may have dropped)"

  log_info "Waiting ${SHUTDOWN_WAIT}s for graceful shutdown..."
  sleep "$SHUTDOWN_WAIT"
}

# Stop Docker container
stop_container() {
  log_info "Stopping Docker container (timeout: ${DOCKER_STOP_TIMEOUT}s)..."

  if docker stop --time="$DOCKER_STOP_TIMEOUT" "$CONTAINER_NAME" &>/dev/null; then
    log_success "Container stopped successfully"
  else
    log_error "Failed to stop container"
    exit 1
  fi
}

# Print confirmation
print_confirmation() {
  local container_status
  container_status=$(docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME")

  printf "\n=== Shutdown Complete ===\n"
  printf "Container: %s (status: %s)\n" "$CONTAINER_NAME" "$container_status"
  printf "All simulators and the macOS VM have been shut down\n"
}

# Main execution
main() {
  log_info "Shutting down iOS Simulator environment..."

  check_container
  shutdown_simulators
  shutdown_macos
  stop_container
  print_confirmation

  log_success "iOS Simulator environment shutdown complete"
}

main "$@"
