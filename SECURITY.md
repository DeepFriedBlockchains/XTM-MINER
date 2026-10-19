# Security policy

XTM-Miner is an independent, unfinished mining application. Do not use it with funds or a production wallet until a reviewed release exists. Mining requires only a public receiving address; the project will never request seed words, wallet passwords, or private keys.

Report suspected vulnerabilities privately to the repository owner before public disclosure. The project repository is public at `https://github.com/NightFantomProjects/XTM-MINER`; check whether GitHub private vulnerability reporting is enabled before using it. Do not post secrets, wallet material, or exploitable details in public issues or logs.

The application must start mining only after an explicit user action, provide a reliable Stop control, and display mining and network failures honestly. Never add hidden mining, remote executable downloads, telemetry, advertising, undisclosed developer fees, or unannounced payout destinations. Pool passwords, wallet addresses, logs, signing keys, and keystore passwords must not be committed or included in public exports.

TLS pool connections must verify the server certificate chain and hostname. Missing/untrusted CA roots or hostname mismatch must fail closed. Do not silently downgrade TLS to plaintext. Upstream XMRig's developer donation behavior must remain visible to users.

This policy will be revised before a public release to add supported-version and response-time commitments.
