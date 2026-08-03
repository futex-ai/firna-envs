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

## Template identity and provenance

An environment named `<env>` at manifest version `<N>` is published as the
immutable E2B template `firna-<env>-v<N>`. The matching Git tag is
`<env>-v<N>`.

The tag, manifest, Dockerfile, and GitHub Actions release run form one
provenance chain. Published names are never rebuilt with different contents;
change the manifest version and publish a new tag instead.

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
  firna-general-v2 envs/general/verify.sh
```

The build helper derives the template name and resources from the manifest and
refuses to rebuild a name already present in the selected E2B team.

## Deployment integration

Firna deployments consume these templates through the sandbox `profiles` map;
they do not build template sources at deployment time. See the platform
[system configuration guide](https://github.com/futex-ai/firna/blob/main/docs/configuration/system-config.md)
for the consuming configuration boundary.
