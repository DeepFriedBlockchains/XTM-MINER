# XTM-Miner

Independent Android CPU miner for Tari (XTM), in active development. This repository is **not yet a validated miner or APK**: physical-device behavior and live accepted shares remain unverified.

## Selected mining route

The first implementation targets Tari's **standalone Tari RandomX (RxT / XTM-RX)** route through a pool that explicitly accepts XMRig Stratum submissions. This is distinct from Monero RandomX merge mining (RxM). The selected Kryptex XTM-RX setup documents algorithm `rx/0`, endpoint `xtm-rx.kryptex.network:7038` over TCP SSL, and login `TARI_WALLET/WORKER`. Pool fees, payout thresholds and endpoints may change; confirm current terms on the operator's pages before use. The route does not use a Monero wallet or local Tari merge-mining proxy. See [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md).

## ARM64 Termux source milestone

The current deliverable builds upstream XMRig v6.26.0 (`b2ca72480c58d197e18c885d9fc1a0c8d517e60a`) from the checksum-pinned source archive in `vendor/`. The project applies a narrow patch to require Stratum TLS certificate-chain and hostname verification. The native Termux build requires an ARM64 Android device with Termux; it does not download executable source during the build.

After Gate 1 in [PHONE-TESTING.md](PHONE-TESTING.md) is reviewed, install Termux packages and build from the project directory:

```sh
pkg update
pkg install cmake ninja clang make openssl libuv ca-certificates python patch coreutils tar unzip
./scripts/build-termux.sh
./scripts/test-termux.sh
```

The build defaults to one compile job to reduce memory pressure. Set `BUILD_JOBS=2` only if the phone has adequate available memory. The test script checks the source checksum, dependencies, engine version/help, and launcher behavior with a mock. `./scripts/test-termux.sh --tls-local` additionally runs local synthetic-certificate checks; neither test connects to the production pool or proves hashing. Follow the phone guide gate by gate. Do not skip ahead to pool testing.

The launcher requires both a public Tari receiving address and an explicit `--start`. It defaults to one mining thread, RandomX light mode, verified TLS, no huge pages, and XMRig's upstream 1% developer donation. An atomic lock at `$PREFIX/var/lib/xtm-miner/miner.lock` refuses simultaneous XTM-Miner sessions across separate project copies in the same Termux installation. The launcher uses a private temporary config and forwards stop signals to the child miner. Light mode requires at least 512 MiB of system-reported `MemAvailable`; opt-in fast mode requires 3 GiB. These are conservative preflight heuristics, not Android per-process memory limits or device-safety guarantees. The wrapper adds no project fee and makes no profitability claim.

## Validation status

- Tari RxT/XTM-RX route, pool instructions, XMRig revision, and TLS patch rationale are documented in [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md).
- The pinned patched engine previously built on x86_64 Linux; local synthetic TLS tests accepted a trusted matching hostname and rejected an untrusted CA and a hostname mismatch. This is host testing only.
- The updated launcher mock test passed in the Sandbox for explicit-start gating, config contents and permissions, fail-closed CA handling, cleanup, duplicate-session refusal, SIGINT/TERM forwarding, and no orphan mock process.
- The ARM64 Termux build and `test-termux.sh` have not yet run on a phone.
- No production pool connection, authenticated worker, actual RandomX pool job, or accepted share has been tested.
- No Android cross-build or emulator test was available in the Sandbox. There is no attached Android phone, SDK/NDK, `adb`, or emulator; details are in [docs/ANDROID-TERMUX-TOOLCHAIN.md](docs/ANDROID-TERMUX-TOOLCHAIN.md).
- No standalone APK/JNI integration, thermal/battery behavior, Android lifecycle handling, or physical Stop test exists yet.

A build or pool login alone is not accepted-share evidence. See [docs/TEST-REPORT.md](docs/TEST-REPORT.md) and [DECISIONS.md](DECISIONS.md) for exact evidence and next steps.
