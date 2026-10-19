#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/bin/xtm-miner"
TLS_LOCAL=0
if (($#)); then
  [[ "$#" == 1 && "$1" == --tls-local ]] || {
    echo "Usage: scripts/test-termux.sh [--tls-local]" >&2
    exit 2
  }
  TLS_LOCAL=1
fi

[[ "${PREFIX:-}" == /data/data/com.termux/files/usr ]] || {
  echo "Run this script inside Termux; detected PREFIX=${PREFIX:-unset}" >&2
  exit 2
}
[[ "$(uname -m)" == aarch64 ]] || {
  echo "This test package targets ARM64 only; detected $(uname -m)" >&2
  exit 2
}
for cmd in bash cmake ninja clang clang++ tar sha256sum patch python3 openssl; do
  command -v "$cmd" >/dev/null || { echo "Missing $cmd; install the project Termux prerequisites first." >&2; exit 2; }
done
for header in "$PREFIX/include/uv.h" "$PREFIX/include/openssl/ssl.h"; do
  [[ -r "$header" ]] || { echo "Missing dependency header: $header" >&2; exit 3; }
done
for name in libuv libssl libcrypto; do
  [[ -e "$PREFIX/lib/$name.so" || -e "$PREFIX/lib/$name.a" ]] || {
    echo "Missing $name under $PREFIX/lib" >&2; exit 3;
  }
done
CA_FILE="${SSL_CERT_FILE:-$PREFIX/etc/tls/cert.pem}"
[[ -r "$CA_FILE" ]] || { echo "Missing readable CA bundle: $CA_FILE" >&2; exit 3; }

(
  cd "$ROOT/vendor"
  sha256sum -c xmrig-v6.26.0.tar.gz.sha256
)
for script in "$ROOT/scripts/build-termux.sh" "$ROOT/scripts/xtm-miner.sh" "$ROOT/scripts/test-termux.sh" "$ROOT/tests/test_launcher.sh"; do
  bash -n "$script"
done
bash "$ROOT/tests/test_launcher.sh"
[[ -x "$BIN" ]] || { echo "Built binary missing: $BIN; run scripts/build-termux.sh first." >&2; exit 4; }
VERSION="$("$BIN" --version 2>&1)"
printf '%s\n' "$VERSION"
[[ "$VERSION" == *"6.26.0"* ]] || { echo "Unexpected engine version; expected pinned XMRig 6.26.0." >&2; exit 4; }
"$BIN" --help >/dev/null

if [[ "$TLS_LOCAL" == 1 ]]; then
  python3 "$ROOT/tests/test_tls_verification.py" "$BIN"
else
  echo "SKIP: local TLS certificate regression test (optional; rerun with --tls-local)."
fi
printf 'PASS: Termux ARM64 preflight, pinned source checksum, binary version/help, and launcher mock tests.\n'
echo 'NOTE: No production pool connection, RandomX job hashing, accepted share, or earnings were tested.'
