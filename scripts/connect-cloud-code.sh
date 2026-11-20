#!/usr/bin/env bash
# Connect to the VPS as the cloud code user and (re)attach the Cloud Code
# session inside tmux. Requires that the cloude_code_vps role has already
# created the 'code' user on the target host.
set -euo pipefail

# Overridable via environment, e.g. VPS_HOST=203.0.113.10 ./scripts/connect-cloud-code.sh
VPS_HOST="${VPS_HOST:-}"                      # your VPS IP / hostname
VPS_USER="${VPS_USER:-code}"                  # the restricted cloud code user
TMUX_SESSION="${TMUX_SESSION:-cloude-code}"   # tmux session name

if [[ -z "${VPS_HOST}" ]]; then
  echo "VPS_HOST is not set. Export it, e.g.:" >&2
  echo "  VPS_HOST=203.0.113.10 $0" >&2
  exit 1
fi

# -t forces a TTY (needed for the interactive tmux session); new-session -A
# attaches to an existing session or creates a new one running Cloud Code.
exec ssh "${VPS_USER}@${VPS_HOST}" \
  -t "tmux new-session -A -s '${TMUX_SESSION}' cloude-code"