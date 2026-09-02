# Environment manifest

Every `envs/<name>/manifest.yaml` file defines the stable identity and build
resources of one Firna base environment. The manifest is the source of truth
used by validation, local builds, and release automation.

## Schema

```yaml
name: general
version: 3
description: Default Firna base environment with durable-drive mount support
resources:
  cpu: 2
  memory_mb: 2048
gcsfuse:
  version: 3.11.2
  repository_key_sha256: 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
```

Browser environments also pin the bundled Bowser release:

```yaml
name: browser
version: 15
description: Browser automation base environment with a dynamically resizable screen stack and durable-drive mount support
resources:
  cpu: 2
  memory_mb: 4096
gcsfuse:
  version: 3.11.2
  repository_key_sha256: 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
chrome:
  version: 152.0.7977.64-1
  url: https://dl.google.com/linux/chrome/deb/pool/main/g/google-chrome-stable/google-chrome-stable_152.0.7977.64-1_amd64.deb
  sha256: 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
bowser:
  version: 0.3.0
  sha256: 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
  contract: contracts/browser-bowser.json
```

## Fields

### `name`

Required string. It must equal the environment directory name and contain only
lowercase letters, numbers, and hyphens. An environment at `envs/browser/`
therefore has `name: browser`.

### `version`

Required positive integer. It is part of the immutable template identity:
`name: browser` and `version: 2` produce `firna-browser-v2` and the release tag
`browser-v2`.

Never reuse a version after its template has been published. Increment the
version for every Dockerfile, manifest, inventory, or verification change that
alters the built environment.

### `description`

Required non-empty string describing the environment's user-visible purpose.

### `resources`

Required mapping. `cpu` is a positive integer CPU count. `memory_mb` is a
positive, even integer number of megabytes. These values are passed to the E2B
template build.

### `gcsfuse`

Required mapping for the runtime dependency that mounts an agent tree's
durable drive.

- `version` is the semantic gcsfuse Debian package version.
- `repository_key_sha256` is the lowercase, 64-character SHA-256 digest of the
  Google Cloud apt repository key downloaded by the Dockerfile.

Both values must match `GCSFUSE_VERSION` and `GOOGLE_CLOUD_APT_CHECKSUM` in the
environment Dockerfile. The package is installed at the exact declared
version, and the repository key is verified before it is trusted.

### `bowser`

Optional mapping for environments that bundle the Bowser CLI.

- `version` is the Bowser release version without a leading `v`.
- `sha256` is the lowercase, 64-character SHA-256 digest of the pinned
  `x86_64-unknown-linux-gnu` release archive.
- `contract` is a repository-relative path to the machine-readable runtime
  contract copied into the image. It defines the same Bowser version, the JSON
  envelope version, and every feature the environment promises.

Both values must match the `BOWSER_VERSION` and `BOWSER_SHA256` pins in the
environment Dockerfile, and the contract's Bowser version must match them. The
archive is verified before installation. The shared contract verifier consumes
the driver's real capability envelope during the release smoke; manifest
validation checks the contract schema and parity instead of searching shell
source for capability names.

### `chrome`

Optional mapping for environments that bundle Google Chrome.

- `version` is the four-part Chrome version plus its Debian package revision.
- `url` is the exact versioned amd64 Debian-package URL. Moving channels and
  aliases such as `stable_current` are not allowed.
- `sha256` is the lowercase, 64-character SHA-256 digest of the amd64 Debian
  package.

All values must match the `CHROME_VERSION`, `CHROME_URL`, and `CHROME_SHA256`
Dockerfile pins. The package checksum and embedded version are verified before
installation, and the versioned URL keeps the source immutable when Google's
stable channel moves.

## Directory contract

An environment directory contains exactly these required files:

```text
envs/<name>/
├── Dockerfile
├── manifest.yaml
└── verify.sh
```

`INVENTORY.md` may also be present to document provenance and intentional
differences from an earlier template. No other files or nested directories are
allowed. `verify.sh` must be executable, use Bash strict mode, and exercise all
tooling promised by the environment.

Run `./scripts/validate_manifests.sh` after every change.

Historical immutable tags are validated through the compatibility boundary
defined by the [release contract](./release.md); that mode does not relax the
schema for new manifests or ordinary publications.
