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
import json,sys
config=json.load(open(sys.argv[1]))
pool=config['pools'][0]
assert pool['algo']=='rx/0'
assert pool['url']=='127.0.0.1:5555'
assert pool['user']=='TARI_TEST_ADDRESS/phone01'
assert pool['pass']=='x'
assert pool['tls'] is False and pool['sni'] is False
assert config['randomx']['mode']=='light'
assert config['donate-level']==1
print('PASS generated config')
PY
MOCK
chmod +x "$TMP/bin/xtm-miner"

if PREFIX="$TMP/prefix" TMPDIR="$TMP/tmp" bash "$TMP/scripts/xtm-miner.sh" --wallet TARI_TEST_ADDRESS >/dev/null 2>&1; then
  echo 'FAIL: mining launched without explicit --start' >&2; exit 1
fi
if PREFIX="$TMP/prefix" TMPDIR="$TMP/tmp" bash "$TMP/scripts/xtm-miner.sh" --start --wallet TARI_TEST_ADDRESS --worker 'bad worker' --no-tls >/dev/null 2>&1; then
  echo 'FAIL: invalid worker accepted' >&2; exit 1
fi
PREFIX="$TMP/prefix" TMPDIR="$TMP/tmp" XTM_WALLET=TARI_TEST_ADDRESS XTM_WORKER=phone01 \
  bash "$TMP/scripts/xtm-miner.sh" --start --no-tls --pool 127.0.0.1:5555 >/dev/null
if compgen -G "$TMP/tmp/xtm-miner.*.json" >/dev/null; then
  echo 'FAIL: private runtime config was not removed' >&2; exit 1
fi
printf 'PASS explicit-start gate, worker validation, private mode-600 config, and cleanup\n'
