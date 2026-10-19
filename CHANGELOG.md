# Changelog

All notable changes to XTM-Miner will be recorded here. This project is not yet at a release stage.

## Unreleased — feasibility milestone

- Documented direct Tari RxT / XTM-RX pool route with XMRig `rx/0`.
- Pinned upstream XMRig v6.26.0 and added a narrowly scoped TLS CA/hostname verification patch.
- Added Termux ARM64 build and explicit-start wrapper scripts with conservative defaults and RandomX memory prechecks.
- Added local launcher and TLS regression tests.
- Patched engine built and TLS/launcher checks run on x86_64 Linux only. No Android APK, live pool acceptance, or physical device checks yet.
