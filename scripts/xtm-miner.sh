#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/bin/xtm-miner"
POOL="xtm-rx.kryptex.network:7038"
WALLET="${XTM_WALLET:-}"
WORKER="${XTM_WORKER:-android01}"
THREADS="${XTM_THREADS:-1}"
PASSWORD="${XTM_PASSWORD:-x}"
TLS=1
START=0
RANDOMX_MODE=light

usage() {
  cat <<'USAGE'
XTM-Miner Termux launcher

Usage: scripts/xtm-miner.sh --start --wallet PUBLIC_TARI_ADDRESS [options]

Required:
  --start                  Explicitly confirm that mining should begin
  --wallet ADDRESS         Public Tari payout address (never a seed phrase)
Options:
  --pool HOST:PORT         Pool endpoint (default: XTM-RX Kryptex global)
  --worker NAME            Worker name; letters and digits only (default: android01)
  --threads N              Mining threads, 1..available CPUs (default: 1)
  --password VALUE         Pool password/options (default: x; avoid shell history)
  --randomx-mode MODE      light or fast (default: light, lower memory/slower)
  --tls                    Use TLS with CA-chain and hostname verification (default)
  --no-tls                 Explicit plaintext opt-out for a pool you trust
  --help                   Show this help

Credentials can alternatively be supplied through XTM_WALLET, XTM_WORKER,
XTM_THREADS, and XTM_PASSWORD. Wallet/password values are not written to project
files or passed as Python command-line arguments. Start only if you understand
the heat, power, and pool risks. XMRig's upstream 1% developer donation remains.
USAGE
}
fail() { echo "Error: $*" >&2; exit 2; }

while (($#)); do
  case "$1" in
    --start) START=1; shift ;;
    --wallet) (($# >= 2)) || fail "--wallet needs a value"; WALLET="$2"; shift 2 ;;
    --pool) (($# >= 2)) || fail "--pool needs a value"; POOL="$2"; shift 2 ;;
    --worker) (($# >= 2)) || fail "--worker needs a value"; WORKER="$2"; shift 2 ;;
    --threads) (($# >= 2)) || fail "--threads needs a value"; THREADS="$2"; shift 2 ;;
    --password) (($# >= 2)) || fail "--password needs a value"; PASSWORD="$2"; shift 2 ;;
    --randomx-mode) (($# >= 2)) || fail "--randomx-mode needs a value"; RANDOMX_MODE="$2"; shift 2 ;;
    --tls) TLS=1; shift ;;
    --no-tls) TLS=0; shift ;;
    --help|-h) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
done

[[ "$START" == 1 ]] || fail "mining does not start automatically; pass --start after reviewing the settings"
[[ -n "${PREFIX:-}" ]] || fail "run this launcher inside Termux so its temporary configuration stays in the private app directory"
[[ -x "$BIN" ]] || fail "binary missing; first run scripts/build-termux.sh"
command -v python3 >/dev/null 2>&1 || fail "Python 3 missing; run pkg install python before starting the miner"
[[ -n "$WALLET" ]] || fail "provide a public Tari payout address with --wallet or XTM_WALLET"
[[ "$WALLET" != *[[:space:]/]* ]] || fail "wallet address must not contain whitespace or '/'"
[[ "$WORKER" =~ ^[A-Za-z0-9]{1,24}$ ]] || fail "worker must be 1-24 ASCII letters/digits"
[[ "$THREADS" =~ ^[1-9][0-9]*$ ]] || fail "threads must be a positive integer"
[[ "${#THREADS}" -le 6 ]] || fail "threads value is unreasonably large"
THREADS_NUM=$((10#$THREADS))
CPUS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)"
[[ "$CPUS" =~ ^[1-9][0-9]*$ && "${#CPUS}" -le 6 ]] || CPUS=1
CPUS_NUM=$((10#$CPUS))
(( THREADS_NUM <= CPUS_NUM )) || fail "threads ($THREADS) exceeds available CPUs ($CPUS)"
[[ "$POOL" =~ ^[A-Za-z0-9.-]+:[0-9]{1,5}$ ]] || fail "pool must be hostname:port"
PORT="${POOL##*:}"
PORT_NUM=$((10#$PORT))
(( PORT_NUM >= 1 && PORT_NUM <= 65535 )) || fail "invalid pool port"
[[ "$RANDOMX_MODE" == light || "$RANDOMX_MODE" == fast ]] || fail "RandomX mode must be light or fast"
[[ -n "$PASSWORD" && "$PASSWORD" != *$'\n'* && "$PASSWORD" != *$'\r'* ]] || fail "invalid pool password"

# MemAvailable is a system-wide estimate, not an Android per-process guarantee.
# Light mode uses a 256 MiB cache; require 512 MiB available for additional runtime headroom.
# Fast mode also allocates a multi-GiB dataset; keep it opt-in and require 3 GiB available.
MEM_AVAILABLE_KIB=""
while read -r mem_key mem_value _; do
  if [[ "$mem_key" == MemAvailable: ]]; then MEM_AVAILABLE_KIB="$mem_value"; break; fi
done < /proc/meminfo
[[ "$MEM_AVAILABLE_KIB" =~ ^[0-9]+$ ]] || fail "cannot read available memory from /proc/meminfo"
if [[ "$RANDOMX_MODE" == light ]]; then
  (( MEM_AVAILABLE_KIB >= 524288 )) || fail "less than 512 MiB available; refusing RandomX light-mode allocation"
else
  (( MEM_AVAILABLE_KIB >= 3145728 )) || fail "less than 3 GiB available; refusing RandomX fast-mode allocation"
fi

if [[ "$TLS" == 1 ]]; then
  [[ -n "${PREFIX:-}" ]] || fail "TLS mining is supported only when launched from Termux"
  [[ -r "${SSL_CERT_FILE:-$PREFIX/etc/tls/cert.pem}" ]] || fail "TLS CA bundle unavailable; install ca-certificates or set SSL_CERT_FILE"
fi

# An atomic persistent, app-private lock prevents duplicate sessions across
# separate project copies in this Termux installation. Stale locks fail closed.
LOCK_PARENT="$PREFIX/var/lib/xtm-miner"
LOCK_DIR="$LOCK_PARENT/miner.lock"
mkdir -p "$LOCK_PARENT"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  OLD_PID="$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
  if [[ "$OLD_PID" =~ ^[1-9][0-9]*$ ]] && kill -0 "$OLD_PID" 2>/dev/null; then
    fail "another XTM-Miner instance is active (PID $OLD_PID)"
  fi
  fail "a stale or incomplete miner lock exists at $LOCK_DIR; verify no miner process is running before removing it"
fi
LOCK_HELD=1
printf '%s\n' "$$" > "$LOCK_DIR/pid"
CONFIG=""
MINER_PID=""
cleanup() {
  [[ -z "${CONFIG:-}" ]] || rm -f "$CONFIG"
  if [[ "${LOCK_HELD:-0}" == 1 ]]; then
    rm -f "$LOCK_DIR/pid"
    rmdir "$LOCK_DIR" 2>/dev/null || true
  fi
}
miner_is_running() {
  [[ -n "${MINER_PID:-}" && -r "/proc/$MINER_PID/stat" ]] || return 1
  local line rest state
  IFS= read -r line < "/proc/$MINER_PID/stat" || return 1
  rest="${line##*) }"
  state="${rest%% *}"
  [[ "$state" != Z && "$state" != X ]]
}
stop_miner() {
  local signal="$1" exit_code="$2" attempt
  trap '' INT TERM HUP
  if miner_is_running; then
    kill -s "$signal" "$MINER_PID" 2>/dev/null || true
    for ((attempt=0; attempt<10; attempt++)); do
      miner_is_running || break
      sleep 1
    done
    if miner_is_running; then
      echo "Miner did not stop after $signal; sending TERM." >&2
      kill -TERM "$MINER_PID" 2>/dev/null || true
      for ((attempt=0; attempt<3; attempt++)); do
        miner_is_running || break
        sleep 1
      done
    fi
    if miner_is_running; then
      echo "Miner ignored graceful signals; sending KILL as a last resort." >&2
      kill -KILL "$MINER_PID" 2>/dev/null || true
    fi
  fi
  if [[ -n "$MINER_PID" ]]; then wait "$MINER_PID" 2>/dev/null || true; fi
  MINER_PID=""
  exit "$exit_code"
}
trap cleanup EXIT
trap 'stop_miner INT 130' INT
trap 'stop_miner TERM 143' TERM
trap 'stop_miner HUP 129' HUP

CONFIG="$(mktemp "$PREFIX/tmp/xtm-miner.XXXXXX.json")"
chmod 600 "$CONFIG"

# Send credentials over stdin, not in the temporary Python process argument list.
printf '%s\0' "$POOL" "$WALLET/$WORKER" "$PASSWORD" "$THREADS" "$RANDOMX_MODE" "$TLS" |
python3 -c '
import json, sys
path = sys.argv[1]
fields = sys.stdin.buffer.read().split(b"\0")
if fields and fields[-1] == b"":
    fields.pop()
if len(fields) != 6:
    raise SystemExit("invalid private configuration input")
pool, user, password, threads, mode, tls = (field.decode("utf-8") for field in fields)
config = {
    "autosave": False,
    "background": False,
    "colors": False,
    "donate-level": 1,
    "cpu": {"enabled": True, "huge-pages": False, "priority": 1},
    "opencl": False,
    "cuda": False,
    "randomx": {"mode": mode, "1gb-pages": False, "rdmsr": False, "wrmsr": False},
    "pools": [{"algo": "rx/0", "url": pool, "user": user, "pass": password,
               "keepalive": True, "tls": tls == "1", "sni": tls == "1", "enabled": True}],
    "print-time": 30,
    "syslog": False
}
with open(path, "w", encoding="utf-8") as f:
    json.dump(config, f)
    f.write("\n")
' "$CONFIG"
unset XTM_WALLET XTM_PASSWORD
export SSL_CERT_FILE="${SSL_CERT_FILE:-$PREFIX/etc/tls/cert.pem}"
echo "Starting XTM-Miner: Tari RandomX rx/0, pool=$POOL, worker=$WORKER, threads=$THREADS, mode=$RANDOMX_MODE, TLS=$TLS"
[[ "$TLS" == 1 ]] || echo "WARNING: this pool connection is unencrypted."
echo "Press Ctrl-C to stop. Authentication is not evidence of an accepted share."
"$BIN" --config="$CONFIG" --threads="$THREADS" &
MINER_PID=$!
printf '%s\n' "$MINER_PID" > "$LOCK_DIR/pid"
echo "Miner process started (PID $MINER_PID)."
if wait "$MINER_PID"; then
  miner_status=0
else
  miner_status=$?
fi
MINER_PID=""
exit "$miner_status"
