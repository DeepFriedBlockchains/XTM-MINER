#!/data/data/com.termux/files/usr/bin/bash
# Stop the XTM-Miner child recorded in this Termux installation's private lock.
# Refuses an absent or unexpected lock process and uses a Linux pidfd to bind
# identity, TERM delivery, and exit waiting to the same process once opened.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/bin/xtm-miner"
LOCK_DIR="${PREFIX:-}/var/lib/xtm-miner/miner.lock"
PID_FILE="$LOCK_DIR/pid"

fail() {
  echo "Error: $*" >&2
  exit 2
}

[[ "${PREFIX:-}" == /data/data/com.termux/files/usr ]] || fail "run this stop helper inside the supported Termux installation"
[[ -x "$BIN" ]] || fail "current project binary missing: $BIN"
command -v python3 >/dev/null 2>&1 || fail "Python 3 is required for safe pidfd-based stopping"
[[ -d "$LOCK_DIR" ]] || {
  echo "No active XTM-Miner lock found; nothing was stopped."
  exit 0
}
[[ -r "$PID_FILE" ]] || fail "incomplete lock at $LOCK_DIR; inspect it manually and do not remove it while a miner may be running"

PID="$(cat "$PID_FILE")"
[[ "$PID" =~ ^[1-9][0-9]*$ ]] || fail "invalid PID in lock; inspect $LOCK_DIR manually"

# pidfd_open creates a process handle. The Python code validates executable
# identity through that handle's still-live numeric PID, sends TERM via pidfd,
# and polls that same handle until the exact target exits. There is no numeric
# PID check-to-kill race. Fail closed if the Android kernel/Python lacks pidfd.
python3 - "$PID" "$BIN" <<'PY'
import errno
import os
import select
import signal
import sys

pid = int(sys.argv[1])
binary = sys.argv[2]

if not hasattr(os, "pidfd_open") or not hasattr(signal, "pidfd_send_signal"):
    raise SystemExit("Error: this Python build lacks pidfd support; refusing an unsafe numeric-PID stop")
try:
    pidfd = os.pidfd_open(pid, 0)
except OSError as exc:
    raise SystemExit(f"Error: cannot open pidfd for lock PID {pid}: {exc}; refusing to signal it")
try:
    try:
        if not os.path.samefile(f"/proc/{pid}/exe", binary):
            raise SystemExit(f"Error: lock PID {pid} is not this project's XTM-Miner binary; refusing to signal it")
    except FileNotFoundError:
        raise SystemExit(f"Error: lock PID {pid} exited before identity validation; refusing to signal it")

    print(f"Requesting TERM stop for XTM-Miner PID {pid} through pidfd.")
    try:
        signal.pidfd_send_signal(pidfd, signal.SIGTERM)
    except OSError as exc:
        raise SystemExit(f"Error: pidfd TERM request failed for PID {pid}: {exc}")

    poller = select.poll()
    poller.register(pidfd, select.POLLIN)
    if not poller.poll(10_000):
        raise SystemExit(f"Error: XTM-Miner PID {pid} did not exit within 10 seconds; do not start another instance")
    print(f"Native child PID {pid} exited after TERM.")
finally:
    os.close(pidfd)
PY

for _ in {1..30}; do
  [[ ! -d "$LOCK_DIR" ]] && {
    echo "PASS: native child stopped and launcher released the lock."
    exit 0
  }
  sleep 0.1
done

fail "native child stopped, but lock remains at $LOCK_DIR; inspect it before another start"
