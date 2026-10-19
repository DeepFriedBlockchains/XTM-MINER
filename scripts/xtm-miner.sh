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
  --password VALUE         Pool password/options (default: x); avoid shell history
  --randomx-mode MODE      light or fast (default: light, lower memory/slower)
  --tls                    Use TLS with CA-chain and hostname verification (default)
  --no-tls                 Explicit plaintext opt-out for a pool you trust
  --help                   Show this help

Credentials can alternatively be supplied through XTM_WALLET, XTM_WORKER,
XTM_THREADS, and XTM_PASSWORD. Wallet and password values are not written to
project files by this script. Start mining only if you understand the heat,
power, and pool risks. XMRig's upstream 1% developer donation remains enabled.
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
[[ -x "$BIN" ]] || fail "binary missing; first run scripts/build-termux.sh"
[[ -n "$WALLET" ]] || fail "provide a public Tari payout address with --wallet or XTM_WALLET"
[[ "$WALLET" != *[[:space:]/]* ]] || fail "wallet address must not contain whitespace or '/'"
[[ "$WORKER" =~ ^[A-Za-z0-9]{1,24}$ ]] || fail "worker must be 1-24 ASCII letters/digits"
[[ "$THREADS" =~ ^[1-9][0-9]*$ ]] || fail "threads must be a positive integer"
CPUS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)"
(( THREADS <= CPUS )) || fail "threads ($THREADS) exceeds available CPUs ($CPUS)"
[[ "$POOL" =~ ^[A-Za-z0-9.-]+:[0-9]{1,5}$ ]] || fail "pool must be hostname:port"
PORT="${POOL##*:}"
(( PORT >= 1 && PORT <= 65535 )) || fail "invalid pool port"
[[ "$RANDOMX_MODE" == light || "$RANDOMX_MODE" == fast ]] || fail "RandomX mode must be light or fast"
[[ -n "$PASSWORD" && "$PASSWORD" != *$'\n'* ]] || fail "invalid pool password"

# Refuse to initialize RandomX below conservative free-memory thresholds.
# The fast dataset requires about 2.3 GiB plus operating headroom; light mode
# still needs a 256 MiB cache, so reserve at least 384 MiB for it.
MEM_AVAILABLE_KB=""
while read -r mem_key mem_value _; do
  if [[ "$mem_key" == MemAvailable: ]]; then MEM_AVAILABLE_KB="$mem_value"; break; fi
done < /proc/meminfo
[[ "$MEM_AVAILABLE_KB" =~ ^[0-9]+$ ]] || fail "cannot read available memory from /proc/meminfo"
if [[ "$RANDOMX_MODE" == light ]]; then
  (( MEM_AVAILABLE_KB >= 393216 )) || fail "less than 384 MiB available; refusing RandomX light-mode allocation"
else
  (( MEM_AVAILABLE_KB >= 2560000 )) || fail "less than 2.5 GiB available; refusing RandomX fast-mode allocation"
fi

if [[ "$TLS" == 1 ]]; then
  [[ -r "${SSL_CERT_FILE:-${PREFIX:-/nonexistent}/etc/tls/cert.pem}" ]] || fail "TLS CA bundle unavailable; install ca-certificates or set SSL_CERT_FILE"
  [[ -n "${PREFIX:-}" ]] || fail "TLS mining is currently supported only when launched from Termux"
fi

# The process inherits no secrets in command arguments. File is private and removed on exit.
CONFIG="$(mktemp "${TMPDIR:-$PREFIX/tmp}/xtm-miner.XXXXXX.json")"
chmod 600 "$CONFIG"
cleanup() { rm -f "$CONFIG"; }
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP
python3 - "$CONFIG" "$POOL" "$WALLET/$WORKER" "$PASSWORD" "$THREADS" "$RANDOMX_MODE" "$TLS" <<'PY'
import json, sys
path, pool, user, password, threads, mode, tls = sys.argv[1:]
config = {
    "autosave": False,
    "background": False,
    "colors": False,
    "donate-level": 1,
    "cpu": {"enabled": True, "huge-pages": False, "priority": 1},
    "opencl": False,
    "cuda": False,
    "randomx": {"mode": mode, "1gb-pages": False, "rdmsr": False, "wrmsr": False},
    "pools": [{
        "algo": "rx/0", "url": pool, "user": user, "pass": password,
        "keepalive": True, "tls": tls == "1", "sni": tls == "1", "enabled": True
    }],
    "print-time": 30,
    "syslog": False
}
with open(path, "w", encoding="utf-8") as f:
    json.dump(config, f)
    f.write("\n")
PY
unset XTM_PASSWORD
export SSL_CERT_FILE="${SSL_CERT_FILE:-$PREFIX/etc/tls/cert.pem}"
echo "Starting XTM-Miner: Tari RandomX rx/0, pool=$POOL, worker=$WORKER, threads=$THREADS, mode=$RANDOMX_MODE, TLS=$TLS"
[[ "$TLS" == 1 ]] || echo "WARNING: this pool connection is unencrypted."
echo "Press Ctrl-C to stop. Do not infer accepted shares from connection/authentication alone."
"$BIN" --config="$CONFIG" --threads="$THREADS"
