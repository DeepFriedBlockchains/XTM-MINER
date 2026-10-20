#!/data/data/com.termux/files/usr/bin/bash
# Test the real XMRig wrapper without using a wallet or contacting an external pool.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/bin/xtm-miner"
LAUNCHER="$ROOT/scripts/xtm-miner.sh"
LOCK_DIR="${PREFIX:-}/var/lib/xtm-miner/miner.lock"
LOOPBACK_POOL="127.0.0.1:1"
WRAPPER_PID=""
CHILD_PID=""
REFUSAL_LOG=""
LAUNCH_LOG=""
DUPLICATE_LOG=""

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

process_running() {
  local pid="$1" line rest state
  [[ "$pid" =~ ^[1-9][0-9]*$ && -r "/proc/$pid/stat" ]] || return 1
  IFS= read -r line < "/proc/$pid/stat" || return 1
  rest="${line##*) }"
  state="${rest%% *}"
  [[ "$state" != Z && "$state" != X ]]
}

stop_process() {
  local pid="$1" label="$2"
  process_running "$pid" || return 0
  echo "Cleanup: stopping $label PID $pid" >&2
  kill -TERM "$pid" 2>/dev/null || true
  for _ in {1..50}; do
    process_running "$pid" || return 0
    sleep 0.1
  done
  echo "Cleanup: $label PID $pid ignored TERM; sending KILL" >&2
  kill -KILL "$pid" 2>/dev/null || true
  for _ in {1..20}; do
    process_running "$pid" || return 0
    sleep 0.1
  done
  process_running "$pid" && echo "Cleanup warning: $label PID $pid is still present" >&2
}

cleanup() {
  local exit_status=$?
  trap - EXIT
  stop_process "$WRAPPER_PID" "launcher wrapper"
  stop_process "$CHILD_PID" "native child"
  [[ -z "$WRAPPER_PID" ]] || wait "$WRAPPER_PID" 2>/dev/null || true
  rm -f "${REFUSAL_LOG:-}" "${LAUNCH_LOG:-}" "${DUPLICATE_LOG:-}"
  exit "$exit_status"
}
trap cleanup EXIT

[[ "${PREFIX:-}" == /data/data/com.termux/files/usr ]] || fail "run inside the supported Termux installation; PREFIX=${PREFIX:-unset}"
[[ "$(uname -m)" == aarch64 ]] || fail "this ARM64 test requires aarch64; detected $(uname -m)"
[[ -x "$BIN" ]] || fail "built native binary missing: $BIN"
[[ -x "$LAUNCHER" ]] || fail "launcher missing: $LAUNCHER"
command -v python3 >/dev/null || fail "Python 3 is required by the launcher"

if [[ -d "$LOCK_DIR" ]]; then
  old_pid="$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
  fail "existing XTM-Miner lock at $LOCK_DIR (PID ${old_pid:-unknown}); inspect it before running this test"
fi

REFUSAL_LOG="$(mktemp "$PREFIX/tmp/xtm-native-start-refusal.XXXXXX.log")"
if XTM_WALLET=TARI_TEST_ADDRESS XTM_WORKER=nativecheck \
  "$LAUNCHER" --pool "$LOOPBACK_POOL" --no-tls >"$REFUSAL_LOG" 2>&1; then
  fail "launcher started without the required --start flag"
fi
grep -q 'mining does not start automatically' "$REFUSAL_LOG" || {
  cat "$REFUSAL_LOG" >&2
  fail "launcher refusal did not report the explicit-start gate"
}

# This is loopback only and uses a fake address. Port 1 has no local test pool;
# no public wallet or external pool traffic is used. The real engine will retry
# the unreachable local endpoint until the script signals it to stop.
LAUNCH_LOG="$(mktemp "$PREFIX/tmp/xtm-native-launch.XXXXXX.log")"
XTM_WALLET=TARI_TEST_ADDRESS XTM_WORKER=nativecheck \
  "$LAUNCHER" --start --pool "$LOOPBACK_POOL" --no-tls --threads 1 >"$LAUNCH_LOG" 2>&1 &
WRAPPER_PID=$!

for _ in {1..50}; do
  if [[ -r "$LOCK_DIR/pid" ]]; then
    candidate="$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
    if [[ "$candidate" =~ ^[1-9][0-9]*$ ]] && [[ "$candidate" != "$WRAPPER_PID" ]] && process_running "$candidate"; then
      CHILD_PID="$candidate"
      break
    fi
  fi
  if ! process_running "$WRAPPER_PID"; then
    cat "$LAUNCH_LOG" >&2
    fail "launcher exited before starting the native child"
  fi
  sleep 0.1
done
[[ -n "$CHILD_PID" ]] || {
  cat "$LAUNCH_LOG" >&2
  fail "native child PID was not recorded in the Termux-wide lock"
}

echo "PASS real native launcher started (wrapper PID $WRAPPER_PID, child PID $CHILD_PID)"

DUPLICATE_LOG="$(mktemp "$PREFIX/tmp/xtm-native-duplicate.XXXXXX.log")"
if XTM_WALLET=TARI_TEST_ADDRESS XTM_WORKER=nativecheck \
  "$LAUNCHER" --start --pool "$LOOPBACK_POOL" --no-tls --threads 1 >"$DUPLICATE_LOG" 2>&1; then
  fail "duplicate launcher invocation was allowed"
fi
grep -q 'another XTM-Miner instance is active' "$DUPLICATE_LOG" || {
  cat "$DUPLICATE_LOG" >&2
  fail "duplicate launcher invocation did not report the active lock"
}
echo "PASS duplicate launcher invocation refused"

# The wrapper runs as a background test job, so test TERM rather than claiming
# that background-job SIGINT emulates interactive Ctrl-C. A separate foreground
# phone step tests manual Ctrl-C before any production-pool run.
kill -TERM "$WRAPPER_PID"
for _ in {1..100}; do
  process_running "$WRAPPER_PID" || break
  sleep 0.1
done
process_running "$WRAPPER_PID" && {
  cat "$LAUNCH_LOG" >&2
  fail "launcher did not stop within 10 seconds after TERM"
}
if wait "$WRAPPER_PID"; then
  status=0
else
  status=$?
fi
WRAPPER_PID=""
[[ "$status" == 143 ]] || {
  cat "$LAUNCH_LOG" >&2
  fail "expected TERM exit status 143 from launcher, got $status"
}
! process_running "$CHILD_PID" || fail "native child process $CHILD_PID remains after TERM"
[[ ! -d "$LOCK_DIR" ]] || fail "Termux-wide lock remains after TERM: $LOCK_DIR"

echo "PASS TERM stopped the real native launcher and child; lock released"
echo "NOTE: This no-pool loopback test proves no hashing, pool connection, accepted share, or interactive Ctrl-C behavior."
