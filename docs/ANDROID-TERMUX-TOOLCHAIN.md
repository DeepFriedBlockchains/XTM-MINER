# Android and Termux toolchain status

Updated 2026-10-20 after receiving ARM64 Termux build output from the phone.

## Termux dependency and CA paths

Termux's maintained `ca-certificates` package installs the PEM bundle at `$TERMUX_PREFIX/etc/tls/cert.pem` [1]. The build script defaults `SSL_CERT_FILE` to `$PREFIX/etc/tls/cert.pem` and fails if the bundle is unreadable. Termux's `libuv` package supplies the engine dependency [2]. The pinned XMRig CMake finder searches under `XMRIG_DEPS`; the Termux build passes both `-DXMRIG_DEPS="$PREFIX"` and `-DCMAKE_PREFIX_PATH="$PREFIX"`. User-provided phone build output confirms CMake found libuv and OpenSSL under Termux's `$PREFIX`.

## Sandbox Android tooling check

The active execution device for this agent is the Manus Sandbox, with no Android SDK/NDK, `adb`, emulator, `sdkmanager`, or `avdmanager`. No Android cross-build, emulator test, or APK test was performed. The user supplied Termux output showing a successful native ARM64 build on a Google Pixel 9a running Android 17/API 37, using Termux Google Play `2026.10.09`; this is user-shared phone evidence, not direct device-tool access.

Android's official documentation describes installing the NDK through Android Studio's SDK Manager or the `sdkmanager` command-line tool [3]. The official downloads page lists NDK r30, version `30.0.16248370`, as the current LTS at the time checked [4]. The download flow is presented with Android SDK license terms. No terms were accepted on the user's behalf and no NDK was downloaded. A cross-compiled Android binary would also not substitute for testing the native Termux build on the physical phone, and it would not prove APK/JNI integration.

## Next validation boundary

The native source now compiles on the user's ARM64 Termux phone. Next, complete the corrected local smoke tests and then demonstrate actual hashing, TLS pool connection, an accepted share, and physical Stop/no-orphan behavior using [PHONE-TESTING.md](../PHONE-TESTING.md) gate by gate. Only after those backend criteria have evidence should the project invest in a standalone test APK. The APK effort must pin and document its own SDK/NDK and Java/Gradle toolchain, and must validate start/stop without Termux.

## References

[1]: https://github.com/termux/termux-packages/blob/master/packages/ca-certificates/build.sh "Termux ca-certificates package recipe"
[2]: https://github.com/termux/termux-packages/blob/master/packages/libuv/build.sh "Termux libuv package recipe"
[3]: https://developer.android.com/studio/projects/install-ndk "Android NDK installation instructions"
[4]: https://developer.android.com/ndk/downloads "Android NDK official downloads"
