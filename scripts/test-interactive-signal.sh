#!/data/data/com.termux/files/usr/bin/bash
# Probe interactive Ctrl-C delivery in Termux. Does not start XMRig or open sockets.
set -u

[[ "${PREFIX:-}" == /data/data/com.termux/files/usr ]] || {
  echo "Error: run this probe inside the supported Termux installation." >&2
  exit 2
}

LOG_DIR="$PREFIX/var/lib/xtm-miner"
LOG="$LOG_DIR/interactive-signal-probe.log"
mkdir -p "$LOG_DIR"
umask 077
: > "$LOG"

record() {
  printf '%s event=%s pid=%s ppid=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$$" "$PPID" >> "$LOG"
}

record READY
echo "Probe ready (PID $$). Press Termux CTRL, then C, once."
echo "No miner starts, no wallet is read, and no network connection is made."
echo "If the session returns or restarts, reopen Termux and read: $LOG"

trap 'record INT; echo "PASS: this probe received SIGINT; exiting 130."; exit 130' INT
trap 'record TERM; echo "Probe received TERM; exiting 143."; exit 143' TERM
trap 'record HUP; echo "Probe received HUP; exiting 129."; exit 129' HUP

while :; do
  sleep 1
done
