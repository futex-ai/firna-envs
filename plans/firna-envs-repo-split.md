# firna-envs Base Environment Repo Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create the public `futex-ai/firna-envs` repository as the source of truth for Firna base-environment (E2B template) definitions — starting with `general` and a new `browser` env containing the bowser CLI — plus the juno-side config/docs integration.

**Architecture:** Base envs are deployment **profile roots** (E2B templates), not env-repo `setup:` layers. firna-envs holds one directory per env (`manifest.yaml` + `Dockerfile` + `verify.sh`); its release CI builds immutable templates named `firna-<env>-v<N>` into the Firna E2B account(s) and smoke-tests them by booting a sandbox and running `verify.sh` inside. juno consumes templates purely via config (the `sandboxes` profile map) — zero Rust changes.

**Tech Stack:** Dockerfiles, E2B CLI (`e2b template build`) + Python SDK (`e2b`), GitHub Actions, bash, `yq`, shellcheck/hadolint/actionlint.

**Where this plan runs:** Milestones 1–4 execute in the new firna-envs repo workspace (this file gets copied there in Milestone 1). Milestone 5 executes in the juno repo and must wait for the env-consolidation branch (`calummoore/agent-workbench-usage`) to merge.

## Design Decisions (settled during brainstorm, 2026-08-03)

- **Shape: profile/template sources.** Not env-repo (`setup:`/`verify:`) layers: cross-workspace env refs are rejected (`validate_workspace_source` in juno `crates/fna-envs/src/chain.rs`), platform images are keyed `(workspace_id, chain_cache_key)` so a Chromium install in `setup:` would rebuild per workspace, and layers cost one of the 4 chain-depth links. Profiles are prebuilt once, platform-wide.
- **Why the repo exists at all:** `firna-general-v1` currently has no source of truth anywhere — it is an opaque template string in juno `infra/helm/firna-server/values.yaml` and nothing builds it. This repo creates that missing home, publicly auditable.
- **Precedent:** `futex-ai/firna-apps` (external definitions repo + CI sync into deployments). Difference: envs publish built E2B templates at *release* time from firna-envs CI rather than being submitted at juno deploy time.
- **Naming:** env/profile name is `browser` (product-neutral; profile names leak into specs, prompts, and UI). bowser is the tool *inside* the env. Template names are immutable: `firna-<env>-v<N>`; content changes always bump `<N>`, never rebuild an existing name.
- **bowser direction:** env-with-CLI — agents drive `bowser` through `env_terminal`. The hosted managed-browser product (bowser branch `calummoore/plan-bowser-api-product`) is out of scope and unaffected.
- **bowser install:** prebuilt x86_64-linux tarball from a pinned `futex-ai/bowser` GitHub Release, verified by sha256. Fallback if no release exists: multi-stage `cargo build` (Milestone 4).
- **Definitions only:** no platform logic, no Rust, no service code in firna-envs. If something needs runtime behavior, it belongs in juno.

## Prerequisites & Open Confirmations

- [x] `gh` authenticated for the `futex-ai` org; Docker running locally; `yq`, `shellcheck` installed (`brew install yq shellcheck`).
- [x] E2B auth available for both Firna teams through their distinct
  `E2B_API_KEY` values. The current E2B Python SDK builds templates with the
  team API key, so a deprecated CLI access token is not required.
- [x] **Confirm E2B account topology** (Milestone 3): production and preview
  use distinct API keys and template namespaces. Publishing `general-v2` in
  preview left it absent from production, confirming separate teams.
- [x] **Confirm current E2B build and sandbox APIs before first use.** E2B CLI
  2.16.1 and Python SDK 2.36.0 were checked. The implementation uses the
  current Python Template and Sandbox SDK APIs because the CLI template-build
  interface no longer matches the original draft.
- [x] **bowser release exists?** `v0.2.0` was cut from the existing workspace
  version after its full release verification passed; its four platform assets
  were published successfully.

## Global Constraints

- Published templates are immutable: never rebuild an existing `firna-<env>-v<N>` name with different content — bump the manifest `version`.
- Every env dir contains exactly: `manifest.yaml`, `Dockerfile`, `verify.sh` (plus optional `INVENTORY.md`); `scripts/validate_manifests.sh` enforces this.
- All shell scripts: `#!/usr/bin/env bash` + `set -euo pipefail`, shellcheck-clean. Dockerfiles hadolint-clean under the repo `.hadolint.yaml`.
- No secrets, tokens, or account IDs committed anywhere in firna-envs.
- E2B sandboxes are x86_64 — all binaries/packages target `x86_64-unknown-linux-gnu`.
- juno-side work: Conventional Commits (all lowercase), `cargo xtask check` before completion, commit and push after checks pass.
- Do not edit `docs/protocol/environments-and-builds.md` in juno before the env-consolidation branch merges (it rewrites that doc).

---

## Milestone 1: firna-envs repo bootstrap with lint CI

Public repo exists with layout, docs, conventions, manifest validation, and a green PR lint pipeline — no envs yet. Runs in the new firna-envs workspace.

- [x] Create the repo and first commit scaffold:
  ```bash
  gh repo create futex-ai/firna-envs --public --description "Source of truth for Firna base environment (E2B template) definitions" --clone
  # or, if the Conductor workspace already has an empty repo checkout, work in place
  mkdir -p envs scripts docs plans .github/workflows
  ```
- [x] Copy this plan file into the new repo as `plans/firna-envs-repo-split.md` and create a one-entry `plans/README.md` (Active: this plan).
- [x] `LICENSE`: MIT, `Copyright (c) 2026 Futex AI` (matches bowser).
- [x] `README.md` with sections: what this repo is (base envs your Firna agents run in, publicly inspectable); layout (`envs/<name>/{manifest.yaml,Dockerfile,verify.sh}`); template naming + immutability (`firna-<env>-v<N>`, tag `<env>-v<N>` ↔ template name ↔ release CI run = provenance chain); how to build locally; how deployments consume templates (juno profile map, link to juno `docs/configuration/system-config.md`).
- [x] `AGENTS.md` (symlink `CLAUDE.md` → `AGENTS.md`, as bowser does) stating the repo rules: definitions only (no service/runtime code); immutable versioning; required files per env; manifest↔Dockerfile pin parity; no secrets committed; PR CI must pass; conventional commits (lowercase); every env change bumps `version` and updates `verify.sh` to cover new tooling.
- [x] `docs/manifest.md` documenting the manifest schema:
  ```yaml
  name: general            # must equal the directory name
  version: 2               # integer; template becomes firna-<name>-v<version>
  description: Default Firna base environment
  resources:
    cpu: 2
    memory_mb: 2048
  # browser env only:
  bowser:
    version: 0.2.0
    sha256: <sha256 of the x86_64-unknown-linux-gnu release tarball>
  ```
- [x] `.hadolint.yaml` with `ignored: [DL3008]` (apt version pinning is impractical for full base images; record the rationale as a comment).
- [x] `scripts/validate_manifests.sh`:
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  shopt -s nullglob
  status=0
  for dir in envs/*/; do
    env_name="$(basename "$dir")"
    for f in manifest.yaml Dockerfile verify.sh; do
      [[ -f "$dir/$f" ]] || { echo "missing $dir$f"; status=1; }
    done
    [[ -f "$dir/manifest.yaml" ]] || continue
    name="$(yq -r '.name' "$dir/manifest.yaml")"
    version="$(yq -r '.version' "$dir/manifest.yaml")"
    [[ "$name" == "$env_name" ]] || { echo "$dir: name '$name' != dir"; status=1; }
    [[ "$version" =~ ^[0-9]+$ ]] || { echo "$dir: version must be an integer"; status=1; }
    bowser_version="$(yq -r '.bowser.version // ""' "$dir/manifest.yaml")"
    if [[ -n "$bowser_version" ]]; then
      grep -q "BOWSER_VERSION=${bowser_version}" "$dir/Dockerfile" \
        || { echo "$dir: Dockerfile BOWSER_VERSION != manifest ${bowser_version}"; status=1; }
      sha="$(yq -r '.bowser.sha256' "$dir/manifest.yaml")"
      grep -q "$sha" "$dir/Dockerfile" \
        || { echo "$dir: Dockerfile sha256 != manifest"; status=1; }
    fi
  done
  exit "$status"
  ```
- [x] `.github/workflows/pull-request.yml`:
  ```yaml
  name: pull-request
  on: pull_request
  jobs:
    lint:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4
        - name: shellcheck
          run: git ls-files '*.sh' | xargs -r shellcheck
        - name: hadolint
          run: |
            files=$(git ls-files 'envs/*/Dockerfile')
            [ -z "$files" ] || docker run --rm -v "$PWD:/repo" -w /repo \
              hadolint/hadolint hadolint --config .hadolint.yaml $files
        - name: actionlint
          run: docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:latest -color
        - name: validate manifests
          run: ./scripts/validate_manifests.sh
  ```
- [x] Run each lint locally (shellcheck, the two docker runs, `./scripts/validate_manifests.sh`) — all pass with zero envs.
- [x] Commit and push: `git add -A && git commit -m "feat: bootstrap firna-envs repo with lint ci" && git push -u origin main` (open a PR instead if branch protection is configured). Verify the PR/branch CI is green.

## Milestone 2: `general` env — recover the source of truth

`envs/general/` reproduces (or deliberately supersedes) the opaque `firna-general-v1` template as an auditable Dockerfile, built and smoke-tested as `firna-general-v2`.

- [x] `scripts/inventory.sh` (runs *inside* a sandbox; used to capture what v1 contains):
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  cat /etc/os-release
  echo "--- user: $(whoami) home: $HOME"
  dpkg -l | awk '{print $2, $3}' | sort
  for cmd in git curl wget jq python3 pip3 node npm rg cargo rustc go java docker; do
    if command -v "$cmd" >/dev/null 2>&1; then echo "HAVE $cmd: $("$cmd" --version 2>&1 | head -1)"; fi
  done
  env | sort
  ```
- [x] `scripts/run_in_sandbox.py` (shared by inventory, local smoke, and release CI; `pip install e2b` first):
  ```python
  #!/usr/bin/env python3
  """Boot an E2B sandbox from a template, run a local shell script inside it."""
  import sys
  from e2b import Sandbox

  def main() -> int:
      template, script_path = sys.argv[1], sys.argv[2]
      with open(script_path, "r", encoding="utf-8") as fh:
          script = fh.read()
      sbx = Sandbox(template, timeout=300)
      try:
          sbx.files.write("/tmp/run.sh", script)
          proc = sbx.commands.run("bash /tmp/run.sh", timeout=240)
          sys.stdout.write(proc.stdout)
          sys.stderr.write(proc.stderr)
          return proc.exit_code or 0
      finally:
          sbx.kill()

  if __name__ == "__main__":
      raise SystemExit(main())
  ```
  (v1 SDK raises `CommandExitException` on non-zero exit — that is fine, the script still fails loudly; adjust to the installed SDK's API if it differs.)
- [x] Capture the inventory of the live template: `E2B_API_KEY=... python3 scripts/run_in_sandbox.py firna-general-v1 scripts/inventory.sh > /tmp/general-v1-inventory.txt`. Distill into `envs/general/INVENTORY.md`: base OS, package list worth keeping, tool versions, anything intentionally dropped (record each drop with a reason). Neither configured team resolved the legacy `firna-general-v1` alias, so the identical live `base` template in both teams was captured as the recoverable baseline and that limitation is recorded in the inventory.
- [x] `envs/general/manifest.yaml` — `name: general`, `version: 2`, description, and `resources` matching the current template's CPU/RAM (visible in the E2B dashboard; default `cpu: 2`, `memory_mb: 2048` if unconfigured).
- [x] `envs/general/Dockerfile` — start from this draft, then adjust to INVENTORY.md parity (base image choice follows the inventory: if v1 is built on `e2bdev/base`, keep that but pin by digest via `docker buildx imagetools inspect e2bdev/base:latest`):
  ```dockerfile
  FROM ubuntu:24.04
  ENV DEBIAN_FRONTEND=noninteractive
  RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl wget git jq unzip zip ripgrep \
        build-essential pkg-config \
        python3 python3-pip python3-venv \
        nodejs npm \
      && rm -rf /var/lib/apt/lists/*
  ```
- [x] `envs/general/verify.sh`:
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  for cmd in git curl jq python3 pip3 node npm rg; do
    command -v "$cmd" >/dev/null
    echo "OK $cmd: $("$cmd" --version 2>&1 | head -1)"
  done
  ```
  Extend the list to every tool INVENTORY.md says we keep.
- [x] `scripts/build_template.sh`:
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  env_name="$1"
  dir="envs/${env_name}"
  name="$(yq -r '.name' "${dir}/manifest.yaml")"
  version="$(yq -r '.version' "${dir}/manifest.yaml")"
  cpu="$(yq -r '.resources.cpu' "${dir}/manifest.yaml")"
  mem="$(yq -r '.resources.memory_mb' "${dir}/manifest.yaml")"
  template="firna-${name}-v${version}"
  echo "building ${template}"
  e2b template build --path "$dir" -d Dockerfile -n "$template" \
    --cpu-count "$cpu" --memory-mb "$mem"
  ```
  Add `e2b.toml` to `.gitignore` (the CLI writes account-specific template IDs there; the manifest is our source of truth).
- [x] Build and smoke against the non-production account first:
  ```bash
  E2B_ACCESS_TOKEN=... ./scripts/build_template.sh general
  E2B_API_KEY=... python3 scripts/run_in_sandbox.py firna-general-v2 envs/general/verify.sh
  ```
  Expected: verify output lists every tool, exit 0. Iterate the Dockerfile until parity with INVENTORY.md.
- [x] Run `./scripts/validate_manifests.sh` and the lint suite; commit and push: `git commit -m "feat: add general base env (firna-general-v2)"`.

## Milestone 3: release automation

Tagging `<env>-v<N>` publishes that template to every E2B account and smoke-tests it; releases are gated by a protected GitHub environment.

- [x] Resolve the account-topology prerequisite (single vs separate preview E2B team). Configure `E2B_API_KEY_PROD` and `E2B_API_KEY_PREVIEW`; current SDK template builds and sandbox boots both use the team API key. Create a `release` GitHub environment with a custom `*-v[0-9]*` tag-only deployment policy.
- [x] `.github/workflows/release.yml`:
  ```yaml
  name: release
  on:
    push:
      tags: ["*-v[0-9]*"]
    workflow_dispatch:
      inputs:
        tag:
          description: "env tag, e.g. general-v2"
          required: true
  jobs:
    publish:
      runs-on: ubuntu-latest
      environment: release
      strategy:
        matrix:
          account: [prod, preview]
      steps:
        - uses: actions/checkout@v4
        - name: resolve tag
          run: echo "TAG=${{ github.event.inputs.tag || github.ref_name }}" >> "$GITHUB_ENV"
        - name: check tag matches manifest
          run: |
            env_name="${TAG%-v*}"
            version="${TAG##*-v}"
            manifest_version="$(yq -r '.version' "envs/${env_name}/manifest.yaml")"
            [ "$version" = "$manifest_version" ] || { echo "tag ${TAG} != manifest v${manifest_version}"; exit 1; }
        - name: install tooling
          run: npm install -g @e2b/cli && pip install e2b
        - name: build template
          env:
            E2B_ACCESS_TOKEN: ${{ matrix.account == 'prod' && secrets.E2B_ACCESS_TOKEN_PROD || secrets.E2B_ACCESS_TOKEN_PREVIEW }}
          run: ./scripts/build_template.sh "${TAG%-v*}"
        - name: smoke test
          env:
            E2B_API_KEY: ${{ matrix.account == 'prod' && secrets.E2B_API_KEY_PROD || secrets.E2B_API_KEY_PREVIEW }}
          run: python3 scripts/run_in_sandbox.py "firna-${TAG}" "envs/${TAG%-v*}/verify.sh"
  ```
  (Drop the matrix if there is a single account.)
- [x] Add the release/provenance section to `README.md`: tag → template name mapping, immutability rule, how a user audits a template (tag ↔ Dockerfile ↔ release run logs).
- [ ] Dry-run via `workflow_dispatch` with `general-v2`; then tag for real: `git tag general-v2 && git push origin general-v2`. Verify both matrix legs pass.
- [x] Commit and push: `git commit -m "feat: add template release workflow"`.

## Milestone 4: `browser` env with bowser

`envs/browser/` ships Chrome + Xvfb + the bowser CLI; agents will drive it via `env_terminal`. Published as `firna-browser-v1`.

- [x] Resolve the bowser release prerequisite. Record the tarball URL and hash:
  ```bash
  gh release view v0.2.0 --repo futex-ai/bowser --json assets --jq '.assets[].name'
  curl -fsSL <tarball-url> | shasum -a 256
  ```
  If cutting a release is not possible yet, use the fallback: a multi-stage build (`FROM rust:1.89-slim AS builder`, `git clone --depth 1 --branch v0.2.0 https://github.com/futex-ai/bowser`, `cargo build --release -p bowser-cli`, copy `target/release/bowser`) and pin the git tag instead of a tarball hash — still record `bowser.version` in the manifest.
- [x] Pin the Google Chrome amd64 Debian package version and SHA-256 in the
  browser manifest and Dockerfile. Validate both before installation so the
  moving `current` URL cannot silently change a build.
- [x] `envs/browser/manifest.yaml` — `name: browser`, `version: 1`, description ("Browser automation base env: Google Chrome + Xvfb + bowser CLI"), `resources: {cpu: 2, memory_mb: 4096}` (Chrome needs headroom), and the `bowser:` pin block with the real version + sha256 from the previous step.
- [x] `envs/browser/Dockerfile` (adjust package names to the chosen base: `libasound2t64` on ubuntu 24.04, `libasound2` on 22.04):
  ```dockerfile
  FROM ubuntu:24.04
  ENV DEBIAN_FRONTEND=noninteractive
  RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl python3 xvfb dbus \
        libasound2t64 fonts-liberation fonts-noto-color-emoji \
      && rm -rf /var/lib/apt/lists/*
  RUN curl -fsSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
        -o /tmp/chrome.deb \
      && apt-get update && apt-get install -y --no-install-recommends /tmp/chrome.deb \
      && rm /tmp/chrome.deb && rm -rf /var/lib/apt/lists/*
  ENV BOWSER_VERSION=0.2.0
  ENV BOWSER_SHA256=<sha256 recorded in manifest.yaml>
  RUN curl -fsSL "https://github.com/futex-ai/bowser/releases/download/v${BOWSER_VERSION}/<asset-name-from-release>" \
        -o /tmp/bowser.tgz \
      && echo "${BOWSER_SHA256}  /tmp/bowser.tgz" | sha256sum -c - \
      && tar -xzf /tmp/bowser.tgz -C /usr/local/bin bowser \
      && chmod +x /usr/local/bin/bowser && rm /tmp/bowser.tgz
  ENV BOWSER_CHROME_PATH=/usr/bin/google-chrome-stable
  ```
  Fill `<asset-name-from-release>` with the exact asset filename listed by `gh release view` (bowser's release.yml builds `x86_64-unknown-linux-gnu` tarballs); confirm the tar path of the binary inside the tarball and adjust the `tar` flags to match.
- [x] `envs/browser/verify.sh` (deterministic — captures a locally served page, no external network dependency):
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  bowser --version
  google-chrome-stable --version
  command -v Xvfb >/dev/null
  mkdir -p /tmp/verify-site
  printf '<html><head><title>bowser-smoke</title></head><body><h1>ok</h1></body></html>' \
    > /tmp/verify-site/index.html
  (cd /tmp/verify-site && python3 -m http.server 8377 >/dev/null 2>&1 &)
  sleep 1
  bowser get http://127.0.0.1:8377 | grep -i "bowser-smoke"
  ```
  Confirm the exact capture invocation against `bowser get --help` (output defaults to semantic YAML; add the format flag if required).
- [x] Build and smoke locally: `./scripts/build_template.sh browser` then `python3 scripts/run_in_sandbox.py firna-browser-v1 envs/browser/verify.sh` — expected: version lines print and the page title is found (proves Chrome launches headless and Bowser captures inside E2B). The amd64 Docker image also builds locally; the functional smoke passed on native E2B x86_64 because Chrome cannot execute reliably through Docker Desktop's arm64-to-amd64 QEMU translation.
- [x] Lints + `./scripts/validate_manifests.sh` pass (pin-parity check now exercises the `bowser:` and `chrome:` blocks).
- [ ] Commit, push, and release: `git commit -m "feat: add browser base env with bowser cli"`, then tag `browser-v1` and verify the release workflow publishes + smokes on all accounts.

## Milestone 5: juno integration (juno repo — after env-consolidation merges)

juno deployments gain the `browser` profile and move `general` to the audited v2 template; docs point at firna-envs as the provenance home. No Rust changes expected.

- [ ] Confirm the env-consolidation branch has merged: `git fetch origin main && git log origin/main --oneline | head -20` shows the env-consolidation PR. Rebase/branch from that main.
- [ ] Find every template/profile reference: `rg -n "firna-general-v1|template: base|profiles:" infra .github docs crates/fna-core`.
- [ ] Add the `browser` profile beside `general` in each config surface, and bump `general` to `firna-general-v2` in **preview/dev surfaces only** (prod bake comes last):
  - `infra/helm/firna-server/values.yaml` (profiles list under `sandboxes.config.backends[0]`):
    ```yaml
            - name: browser
              template: firna-browser-v1
              network:
                allow_public_egress: true
                deny_private_networks: true
    ```
  - `infra/helm/firna-server/production-values.yaml` — add `browser` now; leave prod `general` on v1 until the bake checkbox below.
  - `infra/compose/system-config.sandboxes.yaml` — mirror both profiles.
  - `.github/workflows/preview-deploy.yml` (currently `template: base`) — decide per the account-topology answer: point preview `general` at `firna-general-v2` and add `browser` → `firna-browser-v1` (requires Milestone 3 publishing to the preview account); otherwise leave `base` and record why in the workflow comment.
- [ ] Docs: update `docs/configuration/system-config.md` (profiles section: templates are sourced and published from `https://github.com/futex-ai/firna-envs`, naming scheme, immutability) and add a short base-template provenance note to the post-merge `docs/protocol/environments-and-builds.md`. Check whether prompts enumerate profiles (`rg -n "profile" crates/fna-agent-prompts/prompts docs/protocol/environments-and-builds.md`) and add `browser` wherever the profile set is listed.
- [ ] Validate rendering + tests: `helm template infra/helm/firna-server -f infra/helm/firna-server/values.yaml >/dev/null`, then `cargo xtask check`.
- [ ] Commit (conventional, lowercase — e.g. `feat(infra): add browser sandbox profile`), push, open a PR, and add the preview label: `gh pr edit <n> --add-label preview`.
- [ ] Preview smoke: in the preview env, create an env repo whose `.firna/env.yaml` is `extends: browser` (post-consolidation grammar), `env_open` it, and run `bowser get https://example.com` through `env_terminal` — capture succeeds.
- [ ] Follow-up (after preview bake): bump prod `general` to `firna-general-v2` in `production-values.yaml` in its own PR.

## Out of Scope

- The hosted managed-browser API product (bowser branch `calummoore/plan-bowser-api-product`) — separate bet, unaffected.
- Cross-workspace/public env-repo layer sharing (would require lifting the same-workspace check in juno `crates/fna-envs/src/chain.rs`).
- bowser as an installable Firna app, UI changes, or new agent tools — the browser env is reachable through existing `env_*` tools.
- Additional base envs (node-heavy, python-ml, etc.) — same pattern, future plans.
