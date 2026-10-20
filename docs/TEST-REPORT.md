# XTM-Miner test report

Updated 2026-10-20. This is a milestone report, not a claim that mining, accepted pool work, or standalone APK integration has been validated.

## Passed in the Sandbox

**Pinned-source host build.** The bundled archive checksum is `2cb21d5a0b32c6c504f4b5481f1bd465626759791188f343d854fc6439ca9ce1`; its source pin is XMRig v6.26.0 at `b2ca72480c58d197e18c885d9fc1a0c8d517e60a`. The patched engine previously compiled as x86_64 Linux with TLS enabled. Environment recorded from that build: GCC 13.3.0, CMake 3.28.3, Ninja 1.11.1, OpenSSL 3.0.13, and libuv 1.48.0. GPU backends, hwloc, MSR tuning, benchmark, HTTP, and DMI were disabled. The engine reported XMRig 6.26.0.

**CMake prefix check.** A fresh host-only CMake configure using `-DXMRIG_DEPS=/usr -DCMAKE_PREFIX_PATH=/usr` succeeded and found OpenSSL and libuv under `/usr`. This confirms the prefix settings in the Linux host layout; it does not validate Termux's `$PREFIX` layout.

**TLS behavior.** Synthetic local TLS checks against the patched host binary accepted a CA-signed certificate with matching `localhost` hostname and rejected a wrong hostname and an untrusted certificate. XMRig exited after SIGINT within the test timeout. These were local test servers, not the Tari pool; no pool work was hashed.

**Launcher behavior.** Host mock tests passed explicit-start gating, input validation, `rx/0` and wallet/worker config, TLS-default configuration, fail-closed handling when the CA bundle is unreadable, private mode-600 config cleanup, duplicate-session refusal from a second source copy sharing the same simulated Termux prefix, SIGINT/TERM forwarding, child reaping, persistent lock cleanup, and no orphan mock process. These tests used a mock engine, not Android process behavior or actual mining.

**Source and shell checks.** Bash syntax checks passed individually for the build, launch, test, and launcher-test scripts. The archive SHA-256 check passed. The TLS patch applied to a clean extraction of the exact pinned archive and its verification marker was present. The build and test scripts refused to proceed in the Sandbox with a non-Termux `PREFIX`.

## User-provided physical phone evidence

The user reported a Google Pixel 9a running Android 17/API 37, ABI `arm64-v8a`, and Termux Google Play `2026.10.09` (`termux-tools` 3.0.9). The reported `PREFIX` was `/data/data/com.termux/files/usr`; both `uname -m` and `dpkg --print-architecture` reported `aarch64`. These are user-provided phone outputs, not direct device-tool observations by this Sandbox.

The user verified the ARM64 test ZIP's SHA-256 in shared storage and again after copying it into Termux's private home, then extracted it there. They installed the requested Termux packages. Their reported build used Clang 21.1.8, CMake 4.3.4, Ninja 1.13.2, OpenSSL 3.6.3, and libuv 1.52.1. CMake found both libuv and OpenSSL under `$PREFIX`; the source archive checksum passed, the TLS patch applied, and all 162 build tasks completed. The build script's `--version` check reported XMRig 6.26.0, built with Clang 21.1.8 and 64-bit AES, at `bin/xtm-miner`. Warnings included an unsupported optimization flag and upstream deprecated/unused-field warnings; no compile or link failure was reported. This establishes successful on-device ARM64 Termux compilation and version-command execution, not mining.

The first Termux smoke-test attempt stopped at its command preflight with `Missing openssl`. The user's output showed no `$PREFIX/bin/openssl` executable but did show `libssl.so` and `libcrypto.so` symlinks under `$PREFIX/lib`. Termux's current OpenSSL recipe defines `openssl-tool` as a subpackage that includes the `bin` directory [4]. The regular smoke test does not use the CLI, so `scripts/test-termux.sh` has been corrected to require `openssl` only when `--tls-local` is selected. That optional local-certificate test requires `openssl-tool`. The corrected script has not yet been installed or rerun on the phone.

## Not established

No production-pool connection was made. No public receiving address or pool credentials were used. Actual Tari RandomX job hashing, accepted shares, pool-side worker evidence, payouts, and live TLS compatibility remain unverified. A successful build, version check, or pool login alone is not accepted-share evidence.

No physical readings were reported for process RSS, Android memory limits, CPU or battery temperature, battery drain, screen-off behavior, lifecycle, cooldown, or stop reliability. The launcher has not yet been run against the native miner on the phone, so physical start/stop and orphan-process behavior remain unverified. No Android cross-build, emulator test, standalone APK/JNI build or install, dashboard, signing, or APK lifecycle test has run. Do not claim device safety, background continuity, or universal compatibility.

## Diagnosed command/test issues

- The first Termux smoke test required the `openssl` CLI even when only the ordinary smoke suite was requested. Termux separates that CLI into the `openssl-tool` subpackage [4]. The script now gates that prerequisite on `--tls-local`; the updated script still needs phone verification.
- A clean-source patch-check command initially checked the TLS marker after a dry-run only, so it exited before applying the patch. The corrected check applied the patch, then verified the marker; it passed.
- Earlier host configuration lacked libuv development headers; installing the host `libuv1-dev` package resolved that build prerequisite.
- The first compile found the TLS patch needed `<openssl/err.h>`; adding the include fixed the build.
- The launcher mock fixture originally placed its binary outside the wrapper's expected project root; the fixture was corrected.
- The TLS test listener initially bound only one address family while `localhost` resolved to IPv4 or IPv6. A dual-stack loopback listener fixed the test.

## References

[1]: https://developer.android.com/studio/projects/install-ndk "Android NDK installation instructions"
[2]: https://developer.android.com/ndk/downloads "Android NDK official downloads"
[3]: https://github.com/termux/termux-packages/blob/master/packages/ca-certificates/build.sh "Termux ca-certificates package recipe"
[4]: https://raw.githubusercontent.com/termux/termux-packages/master/packages/openssl/openssl-tool.subpackage.sh "Termux OpenSSL command-line subpackage recipe"
