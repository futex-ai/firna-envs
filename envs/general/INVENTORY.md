# General base inventory

This inventory was captured on 2026-08-03 with
[`scripts/inventory.sh`](../../scripts/inventory.sh) against the `base`
template available through both configured Firna runtime API keys. The two
captures were identical. Neither account resolved the configured legacy alias
`firna-general-v1`, so `base` is the recoverable baseline for this first
auditable definition.

## Recovered baseline

- Debian 12 (bookworm), `x86_64`.
- Default sandbox user `user` with home `/home/user`.
- 2 CPUs and a 512 MB class sandbox (478 MB visible inside the sandbox).
- 473 Debian packages.

The user-visible tools worth preserving were:

| Tool | Recovered version |
| --- | --- |
| Git | 2.39.5 |
| curl | 7.88.1 |
| wget | 1.21.3 |
| jq | 1.6 |
| Python | 3.11.6 |
| pip | 23.2.1 |
| Node.js | 20.9.0 |
| npm | 10.1.0 |

The source image for v2 is the matching E2B Debian base image, pinned to the
Linux x86_64 manifest digest
`sha256:197ad15124a51884aea5a629b96045cd8300bdbbb6df648647004fad99fc59ec`.
The pin preserves the recovered OS and core toolchain without relying on the
moving `latest` tag.

## Deliberate v2 changes

- Increase memory to 2 GB so package installation, compilation, and agent work
  have a practical baseline while retaining 2 CPUs.
- Ensure the recovered command-line tools are present and add `ripgrep`, ZIP
  utilities, `build-essential`, and `pkg-config` for common repository work.
- Keep the E2B-provided Node.js and Python installations from the pinned base
  image rather than replacing them with older distribution builds.

## Intentional omissions

Rust, Go, Java, and Docker were absent from the recovered template and remain
out of the general environment. They add substantial size and should belong in
a purpose-built environment when a product use case requires them.
