# Dependency pins and attribution

| Component | Pin / source | License and notes |
|---|---|---|
| XMRig | Tag `v6.26.0`, commit `b2ca72480c58d197e18c885d9fc1a0c8d517e60a`; bundled source archive SHA-256 `2cb21d5a0b32c6c504f4b5481f1bd465626759791188f343d854fc6439ca9ce1` | GPL-3.0-or-later. Default upstream developer donation is 1%; this project adds no fee or donation destination. |
| Tari protocol reference | Tari source; compatibility-specific commit `e82e5ffa6948fa6b3efe0d56900f5ae61b503a0c` | BSD-3-Clause; the commit adjusted Tari RandomX proof-of-work formatting for XMRig-compatible processing. |
| Pool configuration reference | Kryptex XTM-RX operator pages, checked 2026-10-19 | Endpoint and pool terms are operator-controlled and can change. |
| Termux build, test, and unpack packages | `cmake`, `ninja`, `clang` (provides `clang++`), `openssl` (TLS libraries), `libuv`, `ca-certificates`, `python`, `patch`, `coreutils`, `tar`, `unzip`; `make` is optional convenience. `openssl-tool` is optional for the `openssl` CLI used only by `--tls-local` | Use package versions available from the installed Termux repository and record them with phone build evidence. CMake uses Ninja; Python supports the local test harness; `unzip` unpacks the phone test archive. Build discovery is explicitly pointed at `$PREFIX`. Termux's package recipe defines `openssl-tool` as a subpackage that includes `bin` [3]. |
| Termux CA bundle | `$PREFIX/etc/tls/cert.pem` | Termux's maintained `ca-certificates` package recipe installs the PEM bundle at `$TERMUX_PREFIX/etc/tls/cert.pem` [1]. The build and launcher fail closed if the configured bundle is unreadable. |
| Android NDK | Not installed or pinned for this milestone | Android's official page listed NDK r30 / version `30.0.16248370` as current LTS on 2026-10-19 [2]. No Android SDK/NDK or `sdkmanager` was present in the Sandbox, and no SDK license terms were accepted. This is not the Termux package toolchain. |

The exact upstream XMRig source is bundled at `vendor/xmrig-v6.26.0.tar.gz`; the build script verifies its SHA-256 before extraction. It is an upstream source pin, not a Tari fork. XTM-Miner carries one narrowly scoped Stratum TLS patch in `patches/`, requiring CA-chain and hostname verification. The source archive contains XMRig's GPL license. Do not distribute a modified XMRig binary without the applicable notices and corresponding source/build scripts; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

The Termux build is an on-device ARM64 build and uses Termux's current package set. The script passes `-DXMRIG_DEPS="$PREFIX"` and `-DCMAKE_PREFIX_PATH="$PREFIX"` because the pinned CMake finders search for OpenSSL and libuv; discovery still requires confirmation on the physical phone. For a future standalone APK, pin and record the NDK, SDK platform/build-tools, JDK, Gradle/Android Gradle Plugin, CMake, and any packaged CA/TLS dependencies before implementation.

See [docs/ANDROID-TERMUX-TOOLCHAIN.md](docs/ANDROID-TERMUX-TOOLCHAIN.md) for the current Android-tooling check.

## References

[1]: https://github.com/termux/termux-packages/blob/master/packages/ca-certificates/build.sh "Termux ca-certificates package recipe"
[2]: https://developer.android.com/ndk/downloads "Android NDK official downloads"
[3]: https://raw.githubusercontent.com/termux/termux-packages/master/packages/openssl/openssl-tool.subpackage.sh "Termux OpenSSL command-line subpackage recipe"
