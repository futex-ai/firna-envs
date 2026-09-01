# firna-envs

`firna-envs` is the public source of truth for the base environments that Firna
agents run in. Each environment is an auditable [E2B](https://e2b.dev/)
template definition rather than an opaque deployment setting.

This repository owns template definitions and release automation only. Runtime
selection, environment layering, and sandbox orchestration remain in the Firna
platform repository.

## Repository layout

Each environment lives under `envs/<name>/` and contains:

- `manifest.yaml` — template identity, immutable version, resources, and tool
  pins.
- `Dockerfile` — the complete base-image definition.
- `verify.sh` — the smoke test run inside the published template.
- `INVENTORY.md` — optional provenance notes for environments reconstructed
  from an earlier template.

Shared validation, build, and sandbox helpers live in `scripts/`. The manifest
contract is documented in [docs/manifest.md](./docs/manifest.md), and active
implementation work is indexed in [plans/README.md](./plans/README.md).

## Environment definitions

| Environment | Template | Purpose |
| --- | --- | --- |
| `general` | `firna-general-v3` | Debian-based command-line and build tools for everyday repository work |
| `browser` | `firna-browser-v11` | Google Chrome, a dynamically resizable screen stack, and the checksum-pinned Bowser CLI for browser automation |

The browser definition pins an exact versioned Chrome amd64 Debian-package URL
and the Bowser x86_64 Linux release archive by version and SHA-256. Its bundled
machine-readable Bowser contract is the single source for the expected driver
version, envelope version, and required kiosk-launch, history, and
live-inventory features. The release smoke validates that contract and performs
the corresponding browser operations before an immutable alias is promoted.
Every environment also pins gcsfuse and the Google repository key checksum so
Firna can mount the owning agent tree's durable drive at runtime.

The browser screen helper exposes `ensure`, versioned `capabilities`, and
bounded `resize <width> <height>` commands. Version 1 applies exact CSS-pixel
sizes from 320×240 through 3840×2160. A private-socket TigerVNC X server owns
the dynamic framebuffer; separate loopback-only x11vnc watch and control
bridges retain their existing permission split and announce RandR changes to
connected viewers. The helper records the exact PIDs it owns so release smokes
and runtime diagnostics validate those processes without ambiguous global
process matching.
Resize acknowledgments are emitted only after both VNC servers report the new
framebuffer geometry, so callers do not need to guess at RandR propagation
timing.

## Template identity and provenance

An environment named `<env>` at manifest version `<N>` is published as the
immutable E2B template `firna-<env>-v<N>`. The matching Git tag is
`<env>-v<N>`.

The tag, manifest, Dockerfile, and GitHub Actions release run form one
provenance chain. Normal releases never reassign a published final alias;
change the manifest version and publish a new tag instead. The workflow's
explicit recovery control is reserved for a final alias whose own release
smoke failed, and only reassigns it to a separately built and smoke-tested
template id.

## Validate and build locally

Install Docker, `yq`, `shellcheck`, and Python 3. Authenticate to the intended
E2B team by setting its API key only for the command that needs it.

Validate the repository before building:

```bash
git ls-files '*.sh' | xargs shellcheck
./scripts/validate_manifests.sh
```

Install the pinned Python SDK when inventorying or smoke-testing a published
template:

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

Activate the virtual environment, then build and smoke-test an immutable
template with an explicit Firna team API key:

```bash
source .venv/bin/activate
E2B_API_KEY=... ./scripts/build_template.sh general
E2B_API_KEY=... .venv/bin/python scripts/run_in_sandbox.py \
  firna-general-v3 envs/general/verify.sh
```

The build helper derives the template name and resources from the manifest and
refuses to rebuild a name already present in the selected E2B team.

## Release and audit

Pushing an `<env>-v<N>` tag publishes `firna-<env>-v<N>` to the separate
production and preview E2B teams, then boots a sandbox in each team and runs
the environment's `verify.sh`. Publishing is protected by the repository's
`release` environment, whose deployment policy accepts only version tags.

The release path builds a unique staging tag, smoke-tests that exact staged
template, then assigns the immutable template's `default` tag only after the
smoke succeeds. Promotion checks that the final alias resolves to the staged
template id. A rerun may reuse a final alias only after resolving its id and
still smoke-testing it; an incomplete staging build can never claim the final
name. A normal local build continues to reject an existing name so accidental
replacement is visible. The production and preview matrix runs one account at
a time so an in-progress template publication cannot be mistaken for a ready
immutable release.

If an existing final alias fails its release smoke, manually dispatch the same
tag with `recover_existing` enabled. That explicit recovery builds and smokes a
fresh staging identity before reassigning the final alias; leave the control
disabled for ordinary retries.

To audit a deployed template, start with its template name, remove the `firna-`
prefix to find the Git tag, and inspect that tag's manifest and Dockerfile. The
matching run in the repository's
[release workflow history](https://github.com/futex-ai/firna-envs/actions/workflows/release.yml)
records publication and smoke-test results for both teams.

## Deployment integration

Firna deployments consume these templates through the sandbox `profiles` map;
they do not build template sources at deployment time. See the platform
[system configuration guide](https://github.com/futex-ai/firna/blob/main/docs/configuration/system-config.md)
for the consuming configuration boundary.
