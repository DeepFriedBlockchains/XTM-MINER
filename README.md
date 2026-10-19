# XTM-Miner

Independent Android CPU miner for Tari (XTM). This repository is in active development. It is **not yet a validated miner or APK**: live accepted shares and physical-device behavior remain unverified.

## Verified first mining route

The first implementation targets Tari's **standalone Tari RandomX (RxT / XTM-RX)** route through a pool that explicitly accepts XMRig Stratum submissions. This is distinct from Monero RandomX merge mining (RxM). The current Kryptex XTM-RX configuration documents algorithm `rx/0`, the pool `xtm-rx.kryptex.network:7038` as TCP SSL, login `TARI_WALLET/WORKER`, and vardiff. The pool page currently displays a 1% pool fee and a 200 XTM minimum payout; confirm these terms on the pool page before use because they can change. There is no Monero wallet or local Tari merge-mining proxy in this direct route.

Tari's own protocol source identifies RxT as a separate proof-of-work record (`pow_algo = 2`) and separately describes RxM. Tari's current miner README says its standalone miner currently supports SHA3; that is not this direct RxT pool route. Tari's RFC explains consensus, while the selected pool's instructions establish the practical Stratum endpoint and login details. See [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md).

## Termux ARM64 milestone

The first deliverable is an ARM64 Termux build of upstream XMRig with unnecessary GPU backends disabled. The source is pinned to XMRig tag `v6.26.0`, commit `b2ca72480c58d197e18c885d9fc1a0c8d517e60a`. A small patch enforces CA-chain and hostname verification for Stratum TLS; see [DEPENDENCIES.md](DEPENDENCIES.md) and `patches/`.

The exact upstream source snapshot is bundled at `vendor/xmrig-v6.26.0.tar.gz` and verified by SHA-256 before extraction. The build script compiles that snapshot plus the project TLS patch, without cloning or downloading executable code.

On an ARM64 Android device with Termux installed from a trusted source:

```sh
pkg update
pkg install cmake ninja clang make openssl libuv ca-certificates python patch coreutils tar
# Obtain this source tree, then:
./scripts/build-termux.sh
./scripts/xtm-miner.sh --help
```

Set credentials only in your local shell or private configuration. Do not commit wallet addresses, passwords, or logs containing them. Example invocation (replace placeholders):

```sh
./scripts/xtm-miner.sh \
  --wallet 'YOUR_PUBLIC_TARI_ADDRESS' \
  --worker 'phone01' \
  --threads 2 \
  --pool 'xtm-rx.kryptex.network:7038' \
  --tls \
  --start
```

The wrapper requires an explicit wallet and `--start` before launching the miner. It defaults to one thread and RandomX light mode, which reduces RandomX memory use to roughly 256 MiB but is substantially slower than fast mode. Fast mode is refused below 2.5 GiB of available memory; light mode is refused below 384 MiB. These are conservative allocation checks, not guarantees that a device will remain cool or responsive. The wrapper preserves XMRig's upstream 1% developer donation and adds no project fee. It makes no claim about profitability or device suitability.

## Current validation status

- Tari route, pool algorithm/login/endpoint, and XMRig upstream revision: checked against primary project/pool sources; documented.
- Patched XMRig source: compiled successfully for x86_64 Linux with OpenSSL 3.0.13 and libuv 1.48.0; local TLS checks passed for trusted/valid host, untrusted CA, and hostname mismatch.
- Launcher static/mock checks: passed; these are not actual mining or pool tests.
- Native compilation on ARM64 Android/Termux: not yet run.
- Pool authentication and accepted XTM share: not yet tested; requires an ARM64 device, a user-supplied public Tari receive address, and pool access.
- APK/JNI integration: not implemented.
- Physical thermal, battery, lifecycle, and Stop checks: not run.

See [DECISIONS.md](DECISIONS.md) for work state and blockers. Do not treat a successful build or pool login as accepted-share evidence.
