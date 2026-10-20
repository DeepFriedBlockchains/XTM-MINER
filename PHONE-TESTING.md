# ARM64 Termux phone test

This package builds the pinned XMRig source for **ARM64 Termux**. It is source and scripts, not an APK. The first command below only inspects the Termux installation and device architecture. Run that gate first and pause; do not install packages, build, or start mining until the result has been reviewed.

Never enter a seed phrase or private key. A public Tari receiving address is needed only for the later live-pool test. The launcher does not start mining without an explicit `--start` flag.

## Gate 1 — inspect Termux and architecture

Open the Termux app and run this read-only check:

```sh
printf 'PREFIX=%s\n' "${PREFIX:-unset}"
printf 'uname architecture='; uname -m
printf 'dpkg architecture='; dpkg --print-architecture 2>/dev/null || echo unavailable
if command -v getprop >/dev/null 2>&1; then
  printf 'Android ABI='; getprop ro.product.cpu.abi
  printf 'Android release='; getprop ro.build.version.release
  printf 'Android API='; getprop ro.build.version.sdk
else
  echo 'Android getprop unavailable'
fi
if command -v termux-info >/dev/null 2>&1; then
  termux-info
else
  echo 'termux-info unavailable'
fi
```

Expected for this package: `PREFIX=/data/data/com.termux/files/usr` and `uname -m=aarch64`. Send the complete output before moving to Gate 2. If it differs, stop; do not try the build on an unsupported architecture or a different Termux installation.

## Gate 2 — prepare and unpack the test source

Proceed only after Gate 1 is confirmed. In Termux, update its package index and install the build/test tools:

```sh
pkg update
pkg install cmake ninja clang make openssl libuv ca-certificates python patch coreutils tar unzip
```

The `openssl` package supplies the libraries used by the miner. Termux packages the `openssl` command-line utility separately as `openssl-tool` [1]. The ordinary smoke test does not need that command; install `openssl-tool` only if you choose to run the optional local TLS certificate test.

Download the supplied `xtm-miner-termux-arm64-test.zip` file to the phone's Downloads folder. Then run:

```sh
termux-setup-storage
mkdir -p "$HOME/xtm-miner-testing"
unzip -o "$HOME/storage/downloads/xtm-miner-termux-arm64-test.zip" -d "$HOME/xtm-miner-testing"
cd "$HOME/xtm-miner-testing/xtm-miner-termux-test"
```

`termux-setup-storage` may ask Android to grant shared-storage access. If you do not want to grant it, place the downloaded archive in Termux's private home using Android's file-sharing flow and adjust the archive path. Do not extract or build this project from shared storage; use the private `$HOME` directory shown above.

## Gate 3 — compile the pinned native engine

Keep Termux in the foreground and run:

```sh
cd "$HOME/xtm-miner-testing/xtm-miner-termux-test"
./scripts/build-termux.sh
```

The build verifies the bundled XMRig source archive checksum, applies the project's TLS certificate/hostname verification patch, and builds with one compile job by default. Do not increase `BUILD_JOBS` unless the phone has ample available memory and remains responsive. This setting is compile parallelism and is separate from mining threads. Stop if Android reports excessive heat, memory pressure, or instability; this test makes no safety or background-continuity promise. Send the full build result, including the first compiler error if it fails.

## Gate 4 — safe local checks (no Tari pool)

After the build result has been reviewed, run the smoke tests:

```sh
./scripts/test-termux.sh
```

This checks the pinned archive, Termux dependencies, the engine version/help, and launcher behavior with a mock miner. It does not connect to Tari or hash a pool job. An optional synthetic local TLS regression is:

```sh
./scripts/test-termux.sh --tls-local
```

That test uses local test certificates and no pool credentials. It requires the optional `openssl-tool` package for the `openssl` command. Stop and report the output before any production-pool test.

## Gate 5 — real native launcher lifecycle (no pool)

After the local checks pass, run the native lifecycle test:

```sh
./scripts/test-native-launcher.sh
```

This runs the **real compiled XMRig binary** through the launcher, but uses fake address text and `127.0.0.1:1`, an unreachable local loopback endpoint. It sends no traffic to a public pool, does not need a Tari wallet address, and cannot generate mining work. It verifies the required `--start` gate, starts the native child, verifies a duplicate invocation is refused by the Termux-wide lock, then sends TERM and checks that the child and lock are gone within a bounded wait. Its deliberate `--no-tls` use is restricted to this no-network loopback test; never use it for the live pool test. The next gate manually verifies foreground Ctrl-C. Send the complete output before proceeding.

## Gate 6 — interactive signal probe (no miner and no pool)

The first manual Ctrl-C attempt made the Termux session restart. Its post-restart diagnostic found no miner-like process and no XTM-Miner lock, but the log did not identify the cause. Before starting XMRig again, use `scripts/test-interactive-signal.sh`, which starts **no miner**, reads no wallet, and opens no socket. It persistently records whether the foreground script received a signal.

```sh
./scripts/test-interactive-signal.sh
```

When it displays `Probe ready`, send **Termux's CTRL key followed by C once**. Do not use Android Back. If the prompt returns normally, the probe should print `PASS`. If the session restarts, reopen Termux and read its private probe log. Send that output before proceeding.

## Gate 7 — manual foreground Ctrl-C with real launcher (no pool)

Only if Gate 6 shows that the simple probe received SIGINT normally, run this command in Termux. Wait until it prints a miner PID, then send **Termux CTRL followed by C once** in the same Termux session. It uses fake address text and only unreachable loopback `127.0.0.1:1`; it cannot contact a public pool or hash work.

```sh
XTM_WALLET=TARI_TEST_ADDRESS ./scripts/xtm-miner.sh --start --pool 127.0.0.1:1 --worker manualstop --threads 1 --no-tls
```

After Ctrl-C returns you to the prompt, run the process-and-lock check under Gate 9 below. Send both the launcher output and that check's output before proceeding.

## Gate 8 — live pool test (only when requested after Gates 1–7)

Do not run this until the ARM64 build and local checks have been reviewed. At that point, enter a **public Tari mainnet receiving address only** on the phone. Tari Wallet documents multiple address encodings; use the plain-text/Base58 receive-address form and do not transform it. The pool's instructions document `WALLET_ADDRESS/WORKER_NAME` but do not specify alternate encodings; exact address-format acceptance remains to be verified in the live test. The address is read without echo and is not included in the command history:

```sh
read -r -s -p 'Public Tari receiving address (never a seed phrase): ' XTM_WALLET
printf '\n'
export XTM_WALLET
set -o pipefail
./scripts/xtm-miner.sh --start --worker phone01 --threads 1 --tls 2>&1 | tee "$HOME/xtm-miner-live.log"
miner_status=${PIPESTATUS[0]}
unset XTM_WALLET
printf 'Miner exit status: %s\n' "$miner_status"
```

TLS is on by default, and the launcher requires the Termux CA bundle. Do not use `--no-tls` for this test. The configured first endpoint is `xtm-rx.kryptex.network:7038` with Tari `rx/0` work. A successful connection, authentication, or job announcement is **not** an accepted share. Wait for XMRig to report an accepted share and, where available, confirm it in the pool's worker view. If no accepted share arrives, report that honestly; do not infer one from hashrate or login success. Review the saved log locally and redact any address or other identifying details before sharing it.

The launcher prints the miner PID. While hashing, record the exact PID, `MemAvailable` from `/proc/meminfo`, and that PID's `VmRSS`/`VmHWM` from `/proc/PID/status` if readable. These are observations for that moment, not a guarantee about Android's per-app memory limit. Record battery temperature only if an installed, supported Android/Termux API returns it, and name it as a battery measurement. Record CPU temperature only if the device exposes a readable CPU sensor; otherwise write **unavailable**. Do not guess or substitute battery temperature for CPU temperature.

## Gate 9 — stop and verify no orphan

Press **Ctrl-C in the same Termux session** running the miner. Wait for the launcher to return. Then check:

```sh
if ps -A | grep -Eq '[x]tm-miner|[x]mrig'; then
  echo 'A miner-like process is still listed; do not restart.'
else
  echo 'No miner-like process listed.'
fi
LOCK_DIR="$PREFIX/var/lib/xtm-miner/miner.lock"
if test -d "$LOCK_DIR"; then
  echo 'Miner lock remains; inspect its PID and process before cleanup.'
  cat "$LOCK_DIR/pid" 2>/dev/null || true
else
  echo 'Miner lock released.'
fi
```

A stale lock is not proof that mining stopped. Inspect its PID and the process list before removing anything. If a miner process remains, record its PID and do not start another instance. Record the stop time, observed exit status, remaining process check, memory readings, temperature sensor/source or `unavailable`, and any errors.

The Termux test does not implement Android foreground-service controls, automatic thermal cooldown, charging-only policy, or APK lifecycle handling. A passed Termux test is not proof of APK integration. The later standalone APK test must separately demonstrate native start/stop without Termux before dashboard work proceeds.

## References

[1]: https://raw.githubusercontent.com/termux/termux-packages/master/packages/openssl/openssl-tool.subpackage.sh "Termux OpenSSL command-line subpackage recipe"
