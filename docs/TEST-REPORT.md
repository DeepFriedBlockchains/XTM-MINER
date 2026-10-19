# XTM-Miner test report

Updated 2026-10-19. This is a milestone report, not a claim that the Android product or mining route has been fully validated.

## Passed in the Sandbox

**Pinned-source host build.** Verified the bundled archive checksum (`2cb21d5a0b32c6c504f4b5481f1bd465626759791188f343d854fc6439ca9ce1`), extracted XMRig commit `b2ca72480c58d197e18c885d9fc1a0c8d517e60a`, applied the project TLS patch, and built it as x86_64 Linux. Environment: GCC 13.3.0, CMake 3.28.3, Ninja 1.11.1, OpenSSL 3.0.13, libuv 1.48.0. The output reported XMRig 6.26.0. Disabled hwloc, OpenCL, CUDA, MSR tuning, benchmark, HTTP, and DMI; TLS remained enabled.

Reproduction command after running the Termux script's source extraction and patch step:

```sh
cmake -S build/vendor-xmrig-v6.26.0 -B build/host -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DWITH_HWLOC=OFF -DWITH_OPENCL=OFF -DWITH_CUDA=OFF \
  -DWITH_MSR=OFF -DWITH_TLS=ON -DWITH_BENCHMARK=OFF \
  -DWITH_HTTP=OFF -DWITH_DMI=OFF
cmake --build build/host --parallel 2
```

**TLS behavior.** `tests/test_tls_verification.py` started the host binary against local-only TLS Stratum test servers. A test CA-signed certificate with a matching `localhost` name completed TLS; a certificate signed by that CA for the wrong name was rejected; and a self-signed, untrusted certificate was rejected. The process exited after SIGINT within the test's five-second stop window. The test used synthetic certificates and no Tari pool.

**Launcher behavior.** `tests/test_launcher.sh` uses a mock executable. It confirmed the launcher refuses to run without `--start`, rejects a worker name containing spaces, generates `rx/0` and the `wallet/worker` login, defaults to RandomX light mode, retains XMRig's 1% donation setting, creates a mode-600 transient config, and removes that config after exit. The check did not execute a real hashing loop.

**Static checks.** Bash syntax validation and `git diff --check` for the patch passed. The patch was applied and compiled from a clean pinned worktree.

## Not run / not established

No ARM64 Android or Termux build, install, or launch has run. The available device list contains only the Sandbox; there is no attached Android phone, Termux, Android SDK/NDK, or `adb` in this environment. No APK has been produced.

No connection was made to the production pool. No wallet address or pool credentials were used. Pool authentication, accepted shares, worker-side statistics, pool payouts, live TLS compatibility, and actual XTM earnings are all unverified. The local TLS server check is not mining evidence and does not verify the pool's current certificate or Stratum behavior.

There has been no physical test of sustained hashing, memory pressure, thermal behavior, battery usage, screen-off behavior, Android foreground notification Stop, process death, or duplicate-session prevention. No hashrate, share count, balance, or payout is reported.

## Diagnosed and corrected test/build failures

- The first host CMake configure lacked `libuv` development headers; the missing `libuv1-dev` package was installed and configuration then succeeded.
- The first compile found that the TLS patch needed `<openssl/err.h>` for OpenSSL's error-printer declaration. The include was added, and the patched engine compiled.
- The first launcher mock placed its binary outside the wrapper's expected project root; the test fixture was corrected and passed.
- The first TLS harness bound only one address family while this host resolved `localhost` to either IPv4 or IPv6. The test listener was changed to dual-stack loopback, after which all certificate checks passed.
- A generated patch initially contained terminal color escape codes. It was regenerated with color disabled, then applied to and compiled from a clean pinned worktree.

These corrections affect only test/build infrastructure and do not remove checks or features.
