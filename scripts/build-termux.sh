#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE="$ROOT/vendor/xmrig-v6.26.0.tar.gz"
PATCH="$ROOT/patches/0001-xmrig-stratum-tls-ca-host-verify.patch"
SRC="$ROOT/build/vendor-xmrig-v6.26.0"
BUILD="$ROOT/build/termux"
SOURCE_SHA256="2cb21d5a0b32c6c504f4b5481f1bd465626759791188f343d854fc6439ca9ce1"
PIN="b2ca72480c58d197e18c885d9fc1a0c8d517e60a"

if [[ "${PREFIX:-}" != /data/data/com.termux/files/usr ]]; then
  echo "Run this script inside Termux on Android; detected PREFIX=${PREFIX:-unset}" >&2
  exit 2
fi
if [[ "$(uname -m)" != aarch64 ]]; then
  echo "This milestone targets ARM64 only; detected $(uname -m)" >&2
  exit 2
fi
for cmd in cmake ninja clang tar sha256sum patch; do
  command -v "$cmd" >/dev/null || { echo "Missing $cmd; install project build prerequisites first." >&2; exit 2; }
done
[[ -r "$ARCHIVE" ]] || { echo "Bundled XMRig source archive missing: $ARCHIVE" >&2; exit 3; }
read -r actual_sha _ < <(sha256sum "$ARCHIVE")
[[ "$actual_sha" == "$SOURCE_SHA256" ]] || { echo "Bundled XMRig source checksum mismatch" >&2; exit 3; }

# Recreate generated source from the checked-in immutable archive on each build.
rm -rf "$SRC"
mkdir -p "$SRC"
tar -xzf "$ARCHIVE" --strip-components=1 -C "$SRC"
[[ -f "$SRC/CMakeLists.txt" && -f "$SRC/LICENSE" ]] || { echo "Pinned XMRig source archive is incomplete" >&2; exit 3; }
echo "Building XMRig v6.26.0 source pin $PIN (archive SHA-256 verified)"
(
  cd "$SRC"
  patch --batch --forward --dry-run -p1 < "$PATCH"
  patch --batch --forward -p1 < "$PATCH"
)
if ! grep -q 'XTM_MINER_TLS_CA_HOST_VERIFY' "$SRC/src/base/net/stratum/Tls.cpp"; then
  echo "Required XTM-Miner TLS verification patch is missing; refusing to build." >&2
  exit 4
fi

export CC="${CC:-clang}"
export CXX="${CXX:-clang++}"
export SSL_CERT_FILE="${SSL_CERT_FILE:-$PREFIX/etc/tls/cert.pem}"
[[ -r "$SSL_CERT_FILE" ]] || { echo "Termux CA bundle not found at $SSL_CERT_FILE; install ca-certificates or set SSL_CERT_FILE." >&2; exit 5; }

cmake -S "$SRC" -B "$BUILD" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DWITH_HWLOC=OFF \
  -DWITH_OPENCL=OFF \
  -DWITH_CUDA=OFF \
  -DWITH_MSR=OFF \
  -DWITH_TLS=ON \
  -DWITH_BENCHMARK=OFF \
  -DWITH_HTTP=OFF \
  -DWITH_DMI=OFF
cmake --build "$BUILD" --parallel "${BUILD_JOBS:-2}"
mkdir -p "$ROOT/bin"
install -m 0755 "$BUILD/xmrig" "$ROOT/bin/xtm-miner"
"$ROOT/bin/xtm-miner" --version
printf '\nBuilt %s\n' "$ROOT/bin/xtm-miner"
