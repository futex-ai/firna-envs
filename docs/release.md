# Template release contract

Template publication combines two independently identified inputs: trusted
release tooling and immutable environment source. They must never occupy the
same checkout during recovery.

## Identities

The requested source tag `<env>-v<N>` owns:

- `envs/<env>/manifest.yaml` and its immutable template name;
- the environment Dockerfile and every file it copies into the image;
- the `verify.sh` script executed inside the staged or published template.

The release-tooling commit owns manifest validation, E2B build orchestration,
sandbox execution, promotion, and the workflow steps themselves. Manual
recovery checks this tooling out from current `main`; a tag push uses the
tooling committed with that tag. The workflow records both commits in its log.

## Checkout isolation

The tooling checkout remains at the workspace root. The requested tag is
checked out beneath `release-source/`, after its name has passed syntax
validation. All Git and manifest checks that establish source identity run
against that directory explicitly.

Trusted scripts accept the source root as data. They may read its manifests,
Dockerfiles, contracts, and verification scripts, but they never invoke helper
scripts from the source checkout. The E2B Docker build context is the verified
source root, with trusted ignore rules that exclude Git metadata and local
tooling state even when an older tag has no `.dockerignore`.

## Validation modes

Normal tag publication uses the current strict manifest contract. It cannot
omit a currently required pin or contract field.

Explicit recovery may enable legacy compatibility because an immutable older
tag cannot be rewritten to adopt fields introduced later. Compatibility still
checks the historical manifest's structure, identity, resources, declared
tool pins, Dockerfile parity, executable smoke script, and every optional
contract the tag actually declares. It does not make the current schema
optional for new releases.

Recovery is valid only when the final E2B alias already exists. A missing alias
requires a new manifest version and an ordinary release, not the recovery
override.

Compatibility does not replace upstream artifacts that have disappeared. If a
historical Dockerfile's pinned input is no longer available, publish a new
manifest version with a durable source instead of changing its immutable tag.

## Publication sequence

For each production or preview account, the release workflow:

1. validates the requested tag before any source checkout;
2. checks out trusted tooling and the requested tag separately;
3. verifies the source checkout's `HEAD` against the exact tag commit;
4. validates the source manifest and tag identity;
5. builds or reuses a unique staging alias;
6. boots and smokes that exact staged identity with the source tag's
   `verify.sh`;
7. promotes the staging build only if its identity is unchanged and the smoke
   succeeded.

Existing final aliases are still resolved and smoked on ordinary reruns.
Production and preview run serially, and runs for the same requested tag share
one non-cancelling concurrency group.

## Manual recovery

The workflow definition must come from a ref that already contains this
isolated-source contract. The repository's `release` environment currently
accepts version-tag run refs, so select `browser-v15` or a later compatible
published tag while passing the failed historical source tag separately:

```bash
gh workflow run release.yml --ref browser-v15 \
  -f tag=general-v3 -f recover_existing=true
```

If the environment policy later permits the `main` branch, `--ref main` is the
preferred workflow ref. The requested `tag` input remains the source of the
manifest, image, and smoke test in either case.
