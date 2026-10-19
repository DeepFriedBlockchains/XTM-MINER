# Android and Termux toolchain status

Checked 2026-10-19 for the ARM64 Termux source milestone.

## Termux dependency and CA paths

Termux's maintained `ca-certificates` package installs the PEM bundle at `$TERMUX_PREFIX/etc/tls/cert.pem` [1]. The build script defaults `SSL_CERT_FILE` to `$PREFIX/etc/tls/cert.pem` and fails if the bundle is unreadable. Termux's `libuv` package supplies the engine dependency [2]. The pinned XMRig CMake finder searches under `XMRIG_DEPS`; the Termux build now passes both `-DXMRIG_DEPS="$PREFIX"` and `-DCMAKE_PREFIX_PATH="$PREFIX"` so CMake does not depend on a Linux host's default include/library paths. Actual discovery still needs confirmation from the phone build.

## Sandbox Android tooling check

The active device is the Manus Sandbox only. No authorized Android phone, Android SDK/NDK, `adb`, emulator, `sdkmanager`, or `avdmanager` was available. The Ubuntu package index offered an old `android-sdk` package but no `android-ndk` package. Therefore no ARM64 Android cross-build, Android emulator test, Termux build, installation, or APK test was performed.

Android's official documentation describes installing the NDK through Android Studio's SDK Manager or the `sdkmanager` command-line tool [3]. The official downloads page lists NDK r30, version `30.0.16248370`, as the current LTS at the time checked [4]. The download flow is presented with Android SDK license terms. No terms were accepted on the user's behalf and no NDK was downloaded. A cross-compiled Android binary would also not substitute for testing the native Termux build on the physical phone, and it would not prove APK/JNI integration.

## Next validation boundary

First validate the native build and launcher on an ARM64 Termux phone by following [PHONE-TESTING.md](../PHONE-TESTING.md) gate by gate. Only after actual engine execution, pool-accepted work, and Stop behavior are evidenced should the project invest in a standalone test APK. The APK effort must pin and document its own SDK/NDK and Java/Gradle toolchain, and must validate start/stop without Termux.

## References

[1]: https://github.com/termux/termux-packages/blob/master/packages/ca-certificates/build.sh "Termux ca-certificates package recipe"
[2]: https://github.com/termux/termux-packages/blob/master/packages/libuv/build.sh "Termux libuv package recipe"
[3]: https://developer.android.com/studio/projects/install-ndk "Android NDK installation instructions"
[4]: https://developer.android.com/ndk/downloads "Android NDK official downloads"
