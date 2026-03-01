#!/usr/bin/env bash
#
# ios-sim-start.sh - Start or resume Docker-OSX container and boot iOS Simulator
# Usage: ios-sim-start.sh
#

set -euo pipefail

# Constants
readonly CONTAINER_NAME="macos-dev"
readonly IMAGE_NAME="macos-xcode:ventura-15.2"
readonly SSH_PORT="50922"
readonly VNC_PORT="5999"
readonly SSH_USER="user"
readonly SSH_PASS="alpine"
readonly SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5"
readonly MAX_SSH_WAIT=300
readonly MAX_SIM_WAIT=120

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

log_wait() {
  printf "[WAIT] %s\n" "$*" >&2
}

# SSH helper
ssh_exec() {
  if command -v sshpass &>/dev/null; then
    sshpass -p "$SSH_PASS" ssh $SSH_OPTS -p "$SSH_PORT" "${SSH_USER}@localhost" "$@"
  else
    log_info "sshpass not found, you may need to enter password: $SSH_PASS"
    ssh $SSH_OPTS -p "$SSH_PORT" "${SSH_USER}@localhost" "$@"
  fi
}

# Check if Docker is running
check_docker() {
  log_info "Checking Docker daemon..."
  if ! docker info &>/dev/null; then
    log_error "Docker daemon is not running"
    exit 1
  fi
  log_success "Docker is running"
}

# Start or resume container
start_container() {
  local container_status

  if docker inspect "$CONTAINER_NAME" &>/dev/null; then
    container_status=$(docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME")

    if [[ "$container_status" == "running" ]]; then
      log_success "Container '$CONTAINER_NAME' is already running"
      return 0
    fi

    log_info "Container '$CONTAINER_NAME' exists but is $container_status, starting it..."
    docker start "$CONTAINER_NAME"
    log_success "Container started"
  else
    log_info "Container '$CONTAINER_NAME' does not exist, creating new container..."
    docker run -d --name "$CONTAINER_NAME" --device /dev/kvm \
      -p "${SSH_PORT}:10022" -p "${VNC_PORT}:5999" \
      -e HEADLESS=true -e RAM=16 -e SMP=8 -e CORES=8 \
      -e EXTRA='-display none -vnc 0.0.0.0:99,password=on -usb -device usb-kbd -device usb-tablet' \
      "$IMAGE_NAME"
    log_success "Container created and started"
  fi
}

# Wait for SSH to become available
wait_for_ssh() {
  local elapsed=0

  log_wait "Waiting for SSH to become available (max ${MAX_SSH_WAIT}s)..."

  while (( elapsed < MAX_SSH_WAIT )); do
    if ssh_exec "echo ok" &>/dev/null; then
      log_success "SSH is available after ${elapsed}s"
      return 0
    fi

    sleep 10
    elapsed=$((elapsed + 10))
    log_wait "Still waiting... (${elapsed}s elapsed)"
  done

  log_error "SSH did not become available after ${MAX_SSH_WAIT}s"
  exit 1
}

# Boot iOS Simulator if not already booted
boot_simulator() {
  local booted_sims
  local first_sim_udid
  local sim_name

  log_info "Checking for booted simulators..."

  if booted_sims=$(ssh_exec "xcrun simctl list devices booted" 2>/dev/null) && [[ "$booted_sims" == *"Booted"* ]]; then
    log_success "Simulator is already booted"
    printf "%s\n" "$booted_sims"
    return 0
  fi

  log_info "No simulators booted, finding first available simulator..."

  first_sim_udid=$(ssh_exec "xcrun simctl list devices available --json | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -n 1" 2>/dev/null || true)

  if [[ -z "$first_sim_udid" ]]; then
    log_error "No available simulators found"
    exit 1
  fi

  log_info "Booting simulator: $first_sim_udid"
  ssh_exec "xcrun simctl boot $first_sim_udid"
  log_success "Simulator boot initiated"
}

# Wait for simulator to finish booting
wait_for_simulator() {
  local elapsed=0

  log_wait "Waiting for simulator to finish booting (max ${MAX_SIM_WAIT}s)..."

  while (( elapsed < MAX_SIM_WAIT )); do
    if ssh_exec "xcrun simctl list devices | grep -q Booted" 2>/dev/null; then
      log_success "Simulator booted after ${elapsed}s"
      return 0
    fi

    sleep 5
    elapsed=$((elapsed + 5))
  done

  log_error "Simulator did not boot after ${MAX_SIM_WAIT}s"
  exit 1
}

# Print summary information
print_summary() {
  local container_status
  local booted_sims

  container_status=$(docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME")
  booted_sims=$(ssh_exec "xcrun simctl list devices booted" 2>/dev/null || echo "Unable to fetch")

  printf "\n=== Summary ===\n"
  printf "Container: %s (status: %s)\n" "$CONTAINER_NAME" "$container_status"
  printf "SSH Port: %s (ssh -p %s %s@localhost)\n" "$SSH_PORT" "$SSH_PORT" "$SSH_USER"
  printf "VNC Port: %s (vnc://localhost:%s)\n" "$VNC_PORT" "$VNC_PORT"
  printf "Booted Simulators:\n%s\n" "$booted_sims"
}

# Main execution
main() {
  log_info "Starting iOS Simulator environment..."

  check_docker
  start_container
  wait_for_ssh
  boot_simulator
  wait_for_simulator
  print_summary

  log_success "iOS Simulator environment is ready"
}

main "$@"
