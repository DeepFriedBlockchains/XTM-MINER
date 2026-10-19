# Contributing

XTM-Miner is in an early feasibility stage. Contributions should preserve the project requirements in the shared brief, especially explicit user-start, truthful mining metrics, no hidden fees, safe secret handling, and license compliance.

Before changing the engine, identify the pinned XMRig revision and keep modifications minimal, documented, and testable. Do not change Tari's network, proof-of-work route, algorithm identifier, pool login, or payout behavior without primary-source evidence and an explicit decision entry. Never use a wallet seed phrase or private key in tests.

For changes, run `bash -n` on shell scripts, `tests/test_launcher.sh`, and when host build prerequisites are available, apply the patch to the pinned XMRig source and build it. Run `tests/test_tls_verification.py` against the patched binary for TLS changes. Record the environment and distinguish host, Termux, emulator, physical-device, and pool-share checks in `docs/TEST-REPORT.md`.

Do not publish releases, deploy, add fees/donations, or expose signing keys without explicit authorization. Include license and attribution changes for every dependency.
