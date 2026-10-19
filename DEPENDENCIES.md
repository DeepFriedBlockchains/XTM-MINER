# Dependency pins and attribution

| Component | Pin | License / notes |
|---|---|---|
| XMRig | Tag `v6.26.0`, commit `b2ca72480c58d197e18c885d9fc1a0c8d517e60a`; bundled source archive SHA-256 `2cb21d5a0b32c6c504f4b5481f1bd465626759791188f343d854fc6439ca9ce1` | GPL-3.0-or-later. Default developer donation is 1%; XMRig documents this in its README. Our project adds no fee or donation destination. |
| Tari protocol reference | Tari `development` source; compatibility-specific commit `e82e5ffa6948fa6b3efe0d56900f5ae61b503a0c` | BSD-3-Clause; the commit adjusted Tari RandomX proof-of-work serialization for XMRig-compatible processing. |
| Pool configuration reference | Kryptex XTM-RX operator setup page, checked 2026-10-19 | Pool service, endpoint/terms subject to operator changes. |

The exact pinned XMRig source is bundled at `vendor/xmrig-v6.26.0.tar.gz`; the build script verifies the hash before extraction. It is an upstream source pin, not a Tari fork. XTM-Miner carries one narrowly scoped TLS verification patch in `patches/`, required because upstream does not perform CA-chain and hostname verification for Stratum. Do not distribute a modified XMRig binary without its GPL notices and corresponding source/build scripts. This repository includes the upstream LICENSE file inside the archive and notices for this milestone; release packaging still needs a final license review.

Toolchain targets are not yet validated or pinned for Android. The Termux build runs on-device and uses the installed Termux package set; record package versions in build evidence. The standalone APK will separately pin JDK, Gradle, Android SDK/NDK, CMake, and any vendored TLS/CA dependencies once integration feasibility is tested.
