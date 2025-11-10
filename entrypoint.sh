#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()         { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"; }
log_success() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"; }
log_error()   { echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"; }

log "Starting entrypoint script..."
log "Current user: $(whoami)"
log "Working dir: $(pwd)"

: "${BW_HOST:?BW_HOST environment variable is required}"
: "${BW_CLIENTID:?BW_CLIENTID environment variable is required}"
: "${BW_CLIENTSECRET:?BW_CLIENTSECRET environment variable is required}"
: "${BW_PASSWORD:?BW_PASSWORD environment variable is required}"

log "Testing connectivity to vaultwarden server: $BW_HOST"
if ! curl -s --connect-timeout 10 "$BW_HOST" >/dev/null; then
  log_warning "Cannot reach $BW_HOST (may be normal if it rejects unauthenticated GET)."
fi

log "Clearing any existing session..."
bw logout >/dev/null 2>&1 || true

log "Configuring Bitwarden CLI server: $BW_HOST"
set +e
config_output=$(bw config server "$BW_HOST" 2>&1)
config_result=$?
set -e
log "Config exit code: $config_result"
if [[ $config_result -ne 0 ]]; then
  log_error "Failed to set server:"
  log_error "$config_output"
  exit 1
fi
log_success "Server configuration complete."

log "Logging in with API key..."
max_retries=3
retry_count=0
while [[ $retry_count -lt $max_retries ]]; do
  [[ $retry_count -gt 0 ]] && sleep $((retry_count * retry_count * 5))
  set +e
  login_output=$(bw login --apikey 2>&1)
  login_result=$?
  set -e
  log "Login attempt $((retry_count+1)) exit code: $login_result"
  if [[ $login_result -eq 0 ]]; then
    log_success "Login successful."
    break
  fi
  if [[ "$login_output" == *"Rate limit exceeded"* ]]; then
    log_warning "Rate limited on attempt $((retry_count+1))."
    ((retry_count++))
  else
    log_error "Login failed:"
    log_error "$login_output"
    exit 1
  fi
done
if [[ $login_result -ne 0 ]]; then
  log_error "All login retries exhausted."
  exit 1
fi

log "Unlocking vault..."
set +e
unlock_output=$(bw unlock --passwordenv BW_PASSWORD --raw 2>&1)
unlock_result=$?
set -e
log "Unlock exit code: $unlock_result"
if [[ $unlock_result -ne 0 ]]; then
  log_error "Unlock failed:"
  log_error "$unlock_output"
  exit 1
fi
export BW_SESSION="$unlock_output"
if [[ -z "$BW_SESSION" ]]; then
  log_error "Empty session token after unlock."
  exit 1
fi
log_success "Vault unlocked (session length: ${#BW_SESSION})."

log "Syncing vault..."
bw sync --session "$BW_SESSION" >/dev/null 2>&1 || log_warning "Sync failed (continuing)."
log_success "Sync complete."

log "Starting bw serve on port 8087..."
exec bw serve --hostname 0.0.0.0 --port 8087 --session "$BW_SESSION"
