#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
TEST_ROOT="$TMP/project"
TEST_PREFIX="$TMP/prefix"
STOPPER="$TEST_ROOT/scripts/stop-termux.sh"
LOCK_DIR="$TEST_PREFIX/var/lib/xtm-miner/miner.lock"
CHILD_PID=""
OTHER_PID=""
CLEANER_PID=""

cleanup() {
  for pid in "$CHILD_PID" "$OTHER_PID" "$CLEANER_PID"; do
    [[ "$pid" =~ ^[1-9][0-9]*$ ]] || continue
    kill -TERM "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  done
  rm -rf "$TMP"
}
trap cleanup EXIT

mkdir -p "$TEST_ROOT/scripts" "$TEST_ROOT/bin" "$TEST_PREFIX/var/lib/xtm-miner"
# Transform only the Termux-prefix guard in an isolated test copy.
sed "s|/data/data/com.termux/files/usr|$TEST_PREFIX|g" \
  "$PROJECT_ROOT/scripts/stop-termux.sh" > "$STOPPER"
chmod 700 "$STOPPER"
ln -s "$(command -v sleep)" "$TEST_ROOT/bin/xtm-miner"

# A symlink remains a valid -ef identity test: both paths resolve to this exact
# running binary. A background cleaner represents the launcher's EXIT cleanup.
child_running() {
  local line rest state
  [[ -r "/proc/$CHILD_PID/stat" ]] || return 1
  IFS= read -r line < "/proc/$CHILD_PID/stat" || return 1
  rest="${line##*) }"
  state="${rest%% *}"
  [[ "$state" != Z && "$state" != X ]]
}
"$TEST_ROOT/bin/xtm-miner" 30 &
CHILD_PID=$!
mkdir "$LOCK_DIR"
printf '%s\n' "$CHILD_PID" > "$LOCK_DIR/pid"
(
  while child_running; do sleep 0.1; done
  rm -f "$LOCK_DIR/pid"
  rmdir "$LOCK_DIR"
) &
CLEANER_PID=$!

PREFIX="$TEST_PREFIX" bash "$STOPPER" > "$TMP/stop.log" 2>&1
wait "$CHILD_PID" 2>/dev/null || true
CHILD_PID=""
wait "$CLEANER_PID"
CLEANER_PID=""
grep -q 'PASS: native child stopped and launcher released the lock.' "$TMP/stop.log"
[[ ! -d "$LOCK_DIR" ]] || { echo 'FAIL: lock remains after stop helper test' >&2; exit 1; }

# A stale/reused lock must not be allowed to signal an unrelated executable.
"$(command -v tail)" -f /dev/null &
OTHER_PID=$!
mkdir "$LOCK_DIR"
printf '%s\n' "$OTHER_PID" > "$LOCK_DIR/pid"
if PREFIX="$TEST_PREFIX" bash "$STOPPER" > "$TMP/refusal.log" 2>&1; then
  echo 'FAIL: stop helper signaled an unexpected lock PID' >&2
  exit 1
fi
grep -q "lock PID $OTHER_PID is not this project's XTM-Miner binary" "$TMP/refusal.log" || {
  echo 'FAIL: unexpected-PID refusal was not reported' >&2
  cat "$TMP/refusal.log" >&2
  exit 1
}
kill -0 "$OTHER_PID" 2>/dev/null || { echo 'FAIL: unexpected process did not remain running' >&2; exit 1; }
kill -TERM "$OTHER_PID"
wait "$OTHER_PID" 2>/dev/null || true
OTHER_PID=""
rm -f "$LOCK_DIR/pid"
rmdir "$LOCK_DIR"

echo 'PASS stop helper validates process identity, stops the expected child, and refuses an unexpected PID'
