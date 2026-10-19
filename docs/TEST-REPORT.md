# XTM-Miner test report

Updated 2026-10-19. This is a milestone report, not a claim that Android mining, pool acceptance, or APK integration has been validated.

## Passed in the Sandbox

**Pinned-source host build.** The bundled archive checksum is `2cb21d5a0b32c6c504f4b5481f1bd465626759791188f343d854fc6439ca9ce1`; its source pin is XMRig v6.26.0 at `b2ca72480c58d197e18c885d9fc1a0c8d517e60a`. The patched engine previously compiled as x86_64 Linux with TLS enabled. Environment recorded from that build: GCC 13.3.0, CMake 3.28.3, Ninja 1.11.1, OpenSSL 3.0.13, and libuv 1.48.0. GPU backends, hwloc, MSR tuning, benchmark, HTTP, and DMI were disabled. The engine reported XMRig 6.26.0.

**CMake prefix check.** A fresh host-only CMake configure using `-DXMRIG_DEPS=/usr -DCMAKE_PREFIX_PATH=/usr` succeeded and found OpenSSL and libuv under `/usr`. This confirms the explicit prefix settings work in the Linux host layout; it does not validate Termux's `$PREFIX` layout.

**TLS behavior.** Reran `tests/test_tls_verification.py` against the patched host binary. A CA-signed certificate with matching `localhost` hostname was accepted; a wrong hostname and an untrusted certificate were rejected. XMRig exited after SIGINT within the test's timeout. These were synthetic local TLS servers, not the Tari pool, and no pool work was hashed.

**Launcher behavior.** Reran `bash tests/test_launcher.sh` under host Bash. The mock test passed explicit-start gating, validation, `rx/0` and wallet/worker config, TLS-default configuration, fail-closed behavior when the CA bundle is unreadable, private mode-600 config cleanup, duplicate-session refusal from a second source copy sharing the same simulated Termux prefix, SIGINT/TERM forwarding, miner-process reaping, persistent lock cleanup, and no orphan mock process. This is a mock test, not Android process behavior or actual mining.

**RandomX memory source check.** The pinned XMRig source declares `RANDOMX_CACHE_MAX_SIZE=268435456` bytes (256 MiB) and `RANDOMX_DATASET_MAX_SIZE=2181038080` bytes (about 2.03 GiB). The launcher preflights 512 MiB system-reported `MemAvailable` for light mode and 3 GiB for opt-in fast mode. These values are resource heuristics; they do not predict Android per-process limits or prove allocation on a phone.

**Source and shell checks.** Bash syntax checks passed individually for the build, launch, test, and launcher-test scripts. The archive SHA-256 check passed. The TLS patch applied to a clean extraction of the exact pinned archive and the verification marker was present afterward. The build and test scripts correctly refused to proceed in the Sandbox when given a non-Termux `PREFIX`.

## Android/Termux tooling check

The active execution device is the Sandbox, and device enumeration showed no authorized Android phone. `adb`, `sdkmanager`, `avdmanager`, `emulator`, Gradle, and Android NDK compilers were absent. Ubuntu's package index listed an older `android-sdk` candidate but no `android-ndk` package. No Android SDK/NDK, emulator, or cross-compilation toolchain was installed. Android's official docs describe NDK installation through Android Studio's SDK Manager or `sdkmanager`; the official download page listed NDK r30 / `30.0.16248370` as current LTS on the check date [1] [2]. No SDK license terms were accepted on the user's behalf and no NDK archive was downloaded.

Termux's maintained `ca-certificates` package recipe installs its PEM bundle at `$TERMUX_PREFIX/etc/tls/cert.pem` [3]. The updated scripts use `$PREFIX/etc/tls/cert.pem` by default and direct XMRig's CMake dependency discovery to `$PREFIX`. Those paths and discovery settings have not yet been exercised in a real Termux runtime.

## Not run / not established

No ARM64 Android cross-compilation, Termux build, Termux smoke test, emulator test, APK build, install, or physical-device launch has run. The new `scripts/build-termux.sh` and `scripts/test-termux.sh` are prepared for the phone but their ARM64 execution remains pending.

No connection was made to the production pool. No public receiving address or pool credentials were used. Pool authentication, actual Tari RandomX work hashing, accepted shares, pool-side worker evidence, payouts, live TLS compatibility, and earnings are unverified. A successful build or login alone is not accepted-share evidence.

No physical measurements were collected for RSS, Android per-process memory limits, CPU or battery temperature, battery drain, screen-off behavior, lifecycle, cooldown, or stop reliability. No APK/JNI start/stop behavior exists. Do not claim device safety, background continuity, or universal compatibility.

## Diagnosed command/test issues

- A clean-source patch-check command initially checked the TLS marker after a dry-run only, so it exited before applying the patch. The corrected check applied the patch, then verified the marker; it passed.
- Earlier host configuration lacked libuv development headers; installing the host `libuv1-dev` package resolved that build prerequisite.
- The first compile found the TLS patch needed `<openssl/err.h>`; adding the include fixed the build.
- The launcher mock fixture originally placed its binary outside the wrapper's expected project root; the fixture was corrected.
- The TLS test listener initially bound only one address family while `localhost` resolved to IPv4 or IPv6. A dual-stack loopback listener fixed the test.

## References

[1]: https://developer.android.com/studio/projects/install-ndk "Android NDK installation instructions"
[2]: https://developer.android.com/ndk/downloads "Android NDK official downloads"
[3]: https://github.com/termux/termux-packages/blob/master/packages/ca-certificates/build.sh "Termux ca-certificates package recipe"
