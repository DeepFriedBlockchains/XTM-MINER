# Changelog

All notable changes to XTM-Miner will be recorded here. This project is not yet at a release stage.

## Unreleased — feasibility milestone

- Documented direct Tari RxT / XTM-RX pool route with XMRig `rx/0`.
- Pinned upstream XMRig v6.26.0 and added a narrowly scoped TLS CA/hostname verification patch.
- Added Termux ARM64 build and explicit-start wrapper scripts with conservative defaults and RandomX memory prechecks.
- Added local launcher and TLS regression tests.
- Made the Termux OpenSSL CLI optional for ordinary smoke tests; only `--tls-local` requires Termux's `openssl-tool` subpackage.
- Patched engine and TLS/launcher checks passed on x86_64 Linux. User-provided logs show a successful ARM64 Termux native build on a Pixel 9a; the Termux smoke test is pending the OpenSSL CLI prerequisite fix. No live pool accepted share or standalone APK is verified.
