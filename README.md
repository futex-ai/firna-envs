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

Install Docker, `yq`, `shellcheck`, and the E2B CLI, then authenticate the CLI
to the intended E2B team.

Validate the repository before building:

```bash
git ls-files '*.sh' | xargs shellcheck
./scripts/validate_manifests.sh
```

To build an environment directly with the current E2B CLI, derive its
immutable identity from the manifest:

```bash
env_name=general
version="$(yq -r '.version' "envs/${env_name}/manifest.yaml")"
cpu="$(yq -r '.resources.cpu' "envs/${env_name}/manifest.yaml")"
memory="$(yq -r '.resources.memory_mb' "envs/${env_name}/manifest.yaml")"
e2b template create "firna-${env_name}-v${version}" \
  --path "envs/${env_name}" --dockerfile Dockerfile \
  --cpu-count "$cpu" --memory-mb "$memory"
```

The repository build helper introduced alongside the first environment wraps
the same operation and enforces the manifest contract.

## Deployment integration

Firna deployments consume these templates through the sandbox `profiles` map;
they do not build template sources at deployment time. See the platform
[system configuration guide](https://github.com/futex-ai/firna/blob/main/docs/configuration/system-config.md)
for the consuming configuration boundary.
