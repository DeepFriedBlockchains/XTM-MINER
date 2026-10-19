# Third-party notices

## XMRig

XTM-Miner uses the XMRig CPU mining engine, pinned at v6.26.0 (`b2ca72480c58d197e18c885d9fc1a0c8d517e60a`): https://github.com/xmrig/xmrig/tree/b2ca72480c58d197e18c885d9fc1a0c8d517e60a

XMRig is licensed under GNU General Public License version 3 or (at your option) any later version. Its upstream README describes a default 1% developer donation; this project preserves that behavior and adds no project fee or donation destination. The project patch in `patches/0001-xmrig-stratum-tls-ca-host-verify.patch` modifies the upstream Stratum TLS implementation and is distributed under the upstream license. The complete pinned upstream source snapshot is `vendor/xmrig-v6.26.0.tar.gz`; its checksum is recorded alongside it and in `DEPENDENCIES.md`. The license text is included at `LICENSES/XMRig-GPL-3.0-or-later.txt`. Before distributing a binary, recheck the license obligations and provide the applicable notices, complete corresponding source (including the patch), and build scripts as required by the license.

## Tari protocol references

Tari's protocol code and mining RFC are used as technical references; no Tari protocol source code is copied into this milestone. The Tari repository is BSD-3-Clause licensed. Tari trademarks and names are not used to imply endorsement.

## Other dependencies

Build and test tools (Termux packages, CMake, Ninja, OpenSSL, libuv, Python) are used as installed system dependencies and are not vendored in this milestone. Record exact versions in the build report before a distributable release.
