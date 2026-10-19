#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/scripts" "$TMP/bin" "$TMP/tmp" "$TMP/prefix/tmp"
cp "$ROOT/scripts/xtm-miner.sh" "$TMP/scripts/xtm-miner.sh"
cat > "$TMP/bin/xtm-miner" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
config="${1#--config=}"
[[ -r "$config" ]]
[[ "$(stat -c '%a' "$config")" == 600 ]]
python3 - "$config" <<'PY'
import json,os,sys
config=json.load(open(sys.argv[1]))
pool=config['pools'][0]
assert pool['algo']=='rx/0'
assert pool['url']=='127.0.0.1:5555'
assert pool['user']=='TARI_TEST_ADDRESS/phone01'
assert pool['pass']=='x'
expected_tls = os.environ.get('MOCK_EXPECT_TLS', '0') == '1'
assert pool['tls'] is expected_tls and pool['sni'] is expected_tls
assert config['randomx']['mode']=='light'
assert config['donate-level']==1
print('PASS generated config')
PY
if [[ "${MOCK_HOLD:-0}" == 1 ]]; then
  printf '%s\n' "$$" > "$MOCK_PID_FILE"
  exec python3 -c 'import time; time.sleep(600)'
fi
MOCK
chmod +x "$TMP/bin/xtm-miner"

if PREFIX="$TMP/prefix" TMPDIR="$TMP/tmp" bash "$TMP/scripts/xtm-miner.sh" --wallet TARI_TEST_ADDRESS >/dev/null 2>&1; then
  echo 'FAIL: mining launched without explicit --start' >&2; exit 1
fi
if PREFIX="$TMP/prefix" TMPDIR="$TMP/tmp" bash "$TMP/scripts/xtm-miner.sh" --start --wallet TARI_TEST_ADDRESS --worker 'bad worker' --no-tls >/dev/null 2>&1; then
  echo 'FAIL: invalid worker accepted' >&2; exit 1
fi
if PREFIX="$TMP/prefix" TMPDIR="$TMP/tmp" SSL_CERT_FILE="$TMP/missing-cert.pem" \
  XTM_WALLET=TARI_TEST_ADDRESS bash "$TMP/scripts/xtm-miner.sh" --start --pool 127.0.0.1:5555 >"$TMP/ca-error.log" 2>&1; then
  echo 'FAIL: TLS launched without a readable CA bundle' >&2; exit 1
fi
grep -q 'TLS CA bundle unavailable' "$TMP/ca-error.log" || {
  echo 'FAIL: missing CA bundle was not reported' >&2; cat "$TMP/ca-error.log" >&2; exit 1;
}
mkdir -p "$TMP/prefix/etc/tls"
: > "$TMP/prefix/etc/tls/cert.pem"
PREFIX="$TMP/prefix" TMPDIR="$TMP/tmp" MOCK_EXPECT_TLS=1 XTM_WALLET=TARI_TEST_ADDRESS XTM_WORKER=phone01 \
  bash "$TMP/scripts/xtm-miner.sh" --start --pool 127.0.0.1:5555 --tls >/dev/null
PREFIX="$TMP/prefix" TMPDIR="$TMP/tmp" XTM_WALLET=TARI_TEST_ADDRESS XTM_WORKER=phone01 \
  bash "$TMP/scripts/xtm-miner.sh" --start --no-tls --pool 127.0.0.1:5555 >/dev/null
if compgen -G "$TMP/prefix/tmp/xtm-miner.*.json" >/dev/null; then
  echo 'FAIL: private runtime config was not removed' >&2; exit 1
fi
[[ ! -e "$TMP/prefix/var/lib/xtm-miner/miner.lock" ]] || { echo 'FAIL: normal exit left the Termux-wide miner lock' >&2; exit 1; }

# Hold the mock process, prove a second invocation is refused, then signal the
# launcher and verify it forwards the signal and reaps the miner before cleanup.
PID_FILE="$TMP/mock-miner.pid"
PREFIX="$TMP/prefix" TMPDIR="$TMP/tmp" XTM_WALLET=TARI_TEST_ADDRESS XTM_WORKER=phone01 \
  MOCK_HOLD=1 MOCK_PID_FILE="$PID_FILE" \
  bash "$TMP/scripts/xtm-miner.sh" --start --no-tls --pool 127.0.0.1:5555 >"$TMP/launcher.log" 2>&1 &
WRAPPER_PID=$!
for _ in {1..50}; do [[ -s "$PID_FILE" ]] && break; sleep 0.1; done
[[ -s "$PID_FILE" ]] || { echo 'FAIL: mock miner did not start' >&2; cat "$TMP/launcher.log" >&2; exit 1; }
MINER_PID="$(cat "$PID_FILE")"
mkdir -p "$TMP/other/scripts" "$TMP/other/bin"
cp "$TMP/scripts/xtm-miner.sh" "$TMP/other/scripts/xtm-miner.sh"
cp "$TMP/bin/xtm-miner" "$TMP/other/bin/xtm-miner"
if PREFIX="$TMP/prefix" TMPDIR="$TMP/tmp" XTM_WALLET=TARI_TEST_ADDRESS XTM_WORKER=phone01 \
  bash "$TMP/other/scripts/xtm-miner.sh" --start --no-tls --pool 127.0.0.1:5555 >"$TMP/duplicate.log" 2>&1; then
  echo 'FAIL: duplicate miner was allowed' >&2; exit 1
fi
grep -q 'another XTM-Miner instance is active' "$TMP/duplicate.log" || {
  echo 'FAIL: duplicate refusal did not explain the active lock' >&2; cat "$TMP/duplicate.log" >&2; exit 1;
}
kill -TERM "$WRAPPER_PID"
if wait "$WRAPPER_PID"; then
  echo 'FAIL: signalled launcher returned success' >&2; exit 1
else
  STATUS=$?
fi
[[ "$STATUS" == 143 ]] || { echo "FAIL: expected TERM status 143, got $STATUS" >&2; exit 1; }
if kill -0 "$MINER_PID" 2>/dev/null; then
  echo "FAIL: orphan mock miner remains (PID $MINER_PID)" >&2; exit 1
fi
[[ ! -e "$TMP/prefix/var/lib/xtm-miner/miner.lock" ]] || { echo 'FAIL: stop left the Termux-wide miner lock' >&2; exit 1; }
if compgen -G "$TMP/prefix/tmp/xtm-miner.*.json" >/dev/null; then
  echo 'FAIL: stop left the private runtime config' >&2; exit 1
fi
python3 - "$TMP" <<'PY'
import os, signal, subprocess, sys, time
from pathlib import Path
root = Path(sys.argv[1])
pid_file = root / "mock-miner-int.pid"
env = os.environ.copy()
env.update({"PREFIX": str(root / "prefix"), "TMPDIR": str(root / "tmp"),
            "XTM_WALLET": "TARI_TEST_ADDRESS", "XTM_WORKER": "phone01",
            "MOCK_HOLD": "1", "MOCK_PID_FILE": str(pid_file)})
proc = subprocess.Popen(["bash", str(root / "scripts/xtm-miner.sh"), "--start",
                         "--no-tls", "--pool", "127.0.0.1:5555"], cwd=root,
                        env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                        text=True)
deadline = time.time() + 5
while time.time() < deadline and not pid_file.exists():
    time.sleep(0.05)
if not pid_file.exists():
    output, _ = proc.communicate(timeout=5)
    raise AssertionError("mock miner did not start for SIGINT test\n" + output)
miner_pid = int(pid_file.read_text().strip())
proc.send_signal(signal.SIGINT)
try:
    output, _ = proc.communicate(timeout=15)
except subprocess.TimeoutExpired:
    proc.kill()
    proc.communicate()
    raise AssertionError("launcher did not finish its SIGINT shutdown")
if proc.returncode != 130:
    raise AssertionError(f"expected launcher SIGINT status 130, got {proc.returncode}\n{output}")
if Path(f"/proc/{miner_pid}/stat").exists():
    raise AssertionError(f"orphan mock miner remains after SIGINT (PID {miner_pid})")
if (root / "prefix/var/lib/xtm-miner/miner.lock").exists():
    raise AssertionError("miner lock remains after SIGINT")
if list((root / "prefix/tmp").glob("xtm-miner.*.json")):
    raise AssertionError("private config remains after SIGINT")
print("PASS SIGINT forwarding, child reaping, lock release and private-config cleanup")
PY
printf 'PASS explicit start, input validation, TLS config, 0600 config cleanup, duplicate refusal, TERM forwarding and no orphan\n'
