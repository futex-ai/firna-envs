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
version: 2
description: Browser automation base environment with durable-drive mount support
resources:
  cpu: 2
  memory_mb: 4096
gcsfuse:
  version: 3.11.2
  repository_key_sha256: 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
chrome:
  version: 151.0.7922.71-1
  sha256: 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
bowser:
  version: 0.2.0
  sha256: 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
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

Both values must match the `BOWSER_VERSION` and `BOWSER_SHA256` pins in the
environment Dockerfile. The archive is verified before installation.

### `chrome`

Optional mapping for environments that bundle Google Chrome.

- `version` is the four-part Chrome version plus its Debian package revision.
- `sha256` is the lowercase, 64-character SHA-256 digest of the amd64 Debian
  package.

Both values must match the `CHROME_VERSION` and `CHROME_SHA256` Dockerfile pins.
The package checksum and embedded version are verified before installation, so
the moving `current` download URL cannot silently change a build.

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
