# Tari mining compatibility (checked 2026-10-19)

## Selected route

The first implementation targets Tari's standalone RandomX route, called RxT in Tari protocol materials and XTM-RX by the selected pool. This differs from Monero merge-mined RandomX (RxM): Tari's mining RFC describes RxT as Tari-only work with proof-of-work algorithm field value 2, while RxM is a distinct Monero-linked route [1]. Tari's XMRig-compatibility commit adjusts the RandomX proof-of-work input format so Tari RandomX work is XMRig-compatible [2].

The selected pool's current page labels the algorithm TariRx, recommends XMRig `rx/0`, and publishes `xtm-rx.kryptex.network:7038` as TCP SSL [3]. It accepts the payout address followed by `/` and a worker name, with vardiff by default [3] [4]. This direct route does not use a Monero wallet or local Tari merge-mining proxy.

The pool operator guide states payouts are automatic hourly after the pool threshold is reached [4]. At the time checked, the pool page displayed a 200 XTM minimum payout and 1% PROP/SOLO pool fee [3]. Pool terms can change. The page also describes a static difficulty password option for proxy configurations [3]. Do not show a pool balance or estimate in the app until a supported pool API is independently documented and integrated.

## Engine and address details

The selected engine is XMRig v6.26.0 at commit `b2ca72480c58d197e18c885d9fc1a0c8d517e60a`. XMRig documents `rx/0` as RandomX for Monero, while the selected pool supplies an XMRig command using `rx/0` against its Tari XTM-RX endpoint [5] [3]. Tari's compatibility change and the pool's concrete setup instructions support this direct route; neither proves that this project's binary has connected or obtained an accepted share [2] [3].

The payout login uses the pool's supported Tari public receiving address and a worker suffix, not a Monero address [3] [4]. The pool guide's worker-name rule is Latin letters or digits without spaces [4]. XTM-Miner does not copy the example address in the guide into defaults and never requests a seed phrase or private key.

The current Tari Wallet libraries document single and dual public address types and Emoji, Base58, and Hex serializations; their examples expose `to_base58()` for both forms [9]. The selected pool's instructions require `WALLET_ADDRESS/WORKER_NAME` but do not specify accepted alternate encodings [3] [4]. For the first integration, use a public mainnet receiving address copied as plain-text/Base58 from a Tari wallet; do not transform the string or use an emoji/hex form unless the pool confirms it accepts that representation. The launcher rejects whitespace and `/` in the address but deliberately does not impose a guessed length or character-class regex. Pool acceptance of the selected wallet's exact serialization remains pending the live test.

Tari's current standalone `minotari_miner` README says it currently supports SHA3 when connected to a Tari base node and wallet [6]. Tari Universe documents different current RandomX and pool mining configurations [7]. These modes must not be confused with the selected direct RxT/XTM-RX pool route.

## TLS requirement

The pool documents its selected endpoint as SSL/TCP [3]. Inspection of pinned XMRig v6.26.0's Stratum TLS source found that it checks a certificate fingerprint only if one is configured; the unmodified source does not enforce standard CA-chain and hostname verification [8]. XTM-Miner therefore carries a small patch requiring a trusted CA chain and matching pool hostname. Local synthetic-certificate tests passed for a valid chain and hostname and rejected an untrusted CA and a hostname mismatch. Those checks ran on x86_64 Linux only; Android/Termux trust-store behavior and the pool's current certificate remain unverified.

## References

[1]: https://rfc.tari.com/RFC-0131_Mining "Tari mining RFC"
[2]: https://github.com/tari-project/tari/commit/e82e5ffa6948fa6b3efe0d56900f5ae61b503a0c "Tari RandomX XMRig compatibility change"
[3]: https://pool.kryptex.com/xtm-rx "Kryptex Tari RandomX pool page"
[4]: https://pool.kryptex.com/articles/how-to-mine-tari-randomx-en "Kryptex Tari RandomX setup guide"
[5]: https://xmrig.com/docs/algorithms "XMRig algorithm documentation"
[6]: https://github.com/tari-project/tari/blob/development/applications/minotari_miner/README.md "Tari standalone miner README"
[7]: https://github.com/tari-project/universe/blob/main/CHANGELOG.md "Tari Universe changelog"
[8]: https://github.com/xmrig/xmrig/blob/v6.26.0/src/base/net/stratum/Tls.cpp "XMRig v6.26.0 Stratum TLS implementation"
[9]: https://github.com/tari-project/tari-wallet "Tari Wallet public address types and encodings"
