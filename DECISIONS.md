# Decision log and handoff

Updated 2026-10-19.

## Decisions

- Select Tari standalone RxT / XTM-RX through a pool explicitly supporting XMRig `rx/0`; do not use Monero RxM or a Monero wallet for the first route.
- Pin XMRig v6.26.0 at `b2ca72480c58d197e18c885d9fc1a0c8d517e60a`. The selected pool publishes the `rx/0` invocation, and Tari's compatibility commit changed RandomX formatting for XMRig-compatible work.
- Use a public Tari payout address supplied by the tester when live pool validation is ready. Never request a seed phrase or private key. Do not hard-code a sample address.
- Require Stratum TLS CA-chain and hostname verification. Implemented a narrow patch in `patches/0001-xmrig-stratum-tls-ca-host-verify.patch`; use the OS/OpenSSL CA roots and fail closed when missing. TLS tests currently cover host Linux only.
- Termux defaults are one thread, RandomX light mode, no huge pages, and XMRig's upstream 1% donation. Fast mode requires a conservative 2.5 GiB free-memory precheck; light mode requires 384 MiB. These are allocations checks, not device safety guarantees.
- Keep work staged: establish ARM64 engine feasibility before APK UI work.

## Completed

- Read the full project brief and kickoff specification.
- Inspected Tari mainnet source/changelog, mining RFC, standalone miner README, XMRig algorithm docs, Kryptex XTM-RX pool/setup docs, and Tari's `e82e5ffa6948fa6b3efe0d56900f5ae61b503a0c` XMRig-compatibility commit.
- Recorded the pool route as direct Tari RxT / XTM-RX with `rx/0`, endpoint `xtm-rx.kryptex.network:7038` (TCP SSL), wallet/worker login, and no Monero wallet/proxy.
- Pinned XMRig v6.26.0 at `b2ca72480c58d197e18c885d9fc1a0c8d517e60a` and reviewed its license and donation behavior.
- Implemented the Termux build script, explicit-start launcher, strict input checks, private temporary config, resource defaults, and launcher tests.
- Implemented a project TLS patch requiring trusted CA and pool-host verification and prompt failure for TLS handshake errors.
- Bundled the exact XMRig v6.26.0 source archive with SHA-256 verification and GPL license file; built the patched source on sandbox x86_64 Linux with TLS enabled and MSR tuning disabled. See `docs/TEST-REPORT.md`.
- Local TLS regression test passed for a CA-signed certificate with matching hostname and rejected both a wrong hostname and an untrusted certificate.
- Launcher mock tests passed for explicit-start gating, invalid-worker rejection, `rx/0` config fields, mode-600 temp config, and cleanup. These are mock tests, not pool sessions.

## Blockers / unverified

- The connected GitHub account is `NightFantomProjects`; the public repository is `NightFantomProjects/XTM-MINER`. It was empty when inspected, and the ready source/report set is being added to it. No GitHub Release or tag is being created.
- No authorized physical Android device is available in this session. Sandbox has no Termux runtime, Android SDK/NDK, `adb`, or emulator. Therefore ARM64 Android compilation, install/launch, native hashing on phone, thermal/battery behavior, and Android lifecycle/Stop are unverified.
- No test payout address has been provided and no pool session was made. Pool authentication, valid work, accepted shares, pool-side worker evidence, and payouts are unverified.
- The direct pool's TLS endpoint is evidenced by its current public instructions, but the project patch has not yet been compiled or exercised on Termux/Android trust stores.
- The pinned XMRig source snapshot is bundled. No APK, JNI integration, dashboard, app service/notification, APK signing, installable Android artifact, or Android checksum exists yet.

## Next steps

1. Run the pinned Termux build on an ARM64 phone or provisioned ARM64 Termux environment, then verify the Termux OpenSSL trust path and XTM-RX pool TLS behavior.
2. If a physical device becomes available, use a user-supplied public payout address to test pool connection and wait for a genuine accepted share, with logs redacted.
3. Only after the ARM64 engine and stop behavior are demonstrated, evaluate JNI shared-library integration of the same pinned XMRig source for the standalone APK. Preserve GPL source/notice obligations and package verified CA roots for Android.
4. Implement lifecycle/foreground notification, thermal/battery controls and the dashboard only after native integration feasibility is established.
5. Build and verify APK only when Android toolchains/device checks are possible. Mark physical and pool acceptance criteria unverified until evidence exists.
