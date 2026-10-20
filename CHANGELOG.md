# Changelog

All notable changes to XTM-Miner will be recorded here. This project is not yet at a release stage.

## Unreleased — feasibility milestone

- Documented direct Tari RxT / XTM-RX pool route with XMRig `rx/0`.
- Pinned upstream XMRig v6.26.0 and added a narrowly scoped TLS CA/hostname verification patch.
- Added Termux ARM64 build and explicit-start wrapper scripts with conservative defaults and RandomX memory prechecks.
- Added local launcher and TLS regression tests.
- Made the Termux OpenSSL CLI optional for ordinary smoke tests; only `--tls-local` requires Termux's `openssl-tool` subpackage.
- Added a no-pool native lifecycle test that uses a fake address and unreachable loopback endpoint to test real launcher start, duplicate-lock refusal, bounded TERM stop, and cleanup before live pool testing. Manual foreground Ctrl-C is a separate phone gate.
- Added a no-miner, no-network interactive signal probe to isolate Termux CTRL+C delivery after the first manual launcher Ctrl-C attempt restarted the session. Its follow-up diagnostic found no orphan miner process or XTM-Miner lock.
- Hardened launcher thread and port numeric parsing against impractically long values and Bash octal interpretation of leading-zero ports.
- Patched engine and TLS/launcher checks passed on x86_64 Linux. User-provided logs show successful ARM64 Termux build, ordinary smoke tests, local TLS certificate checks, and real native launcher TERM lifecycle testing on a Pixel 9a. No manual foreground Ctrl-C result, live pool accepted share, or standalone APK is verified.
