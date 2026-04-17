# Handoff Notes

This document describes how the repository is organized, how the CI/CD
pipeline operates, and what external services it depends on. It is
scoped strictly to what exists in this repository today — anything that
cannot be determined from the code, workflow, or configuration files is
called out as a **pending confirmation** item for whoever operates the
stack upstream.

For the user-facing architecture overview, image descriptions, and
pinning philosophy, see [`README.md`](../README.md). This document
focuses on operational and maintenance concerns.

---

## 1. Repository layout

```
canfar-containers/
├── .github/workflows/image-pipeline.yml  # Single CI/CD workflow
├── .gitignore
├── .hadolint.yaml                        # Hadolint ignore list (DL3008, DL3013)
├── README.md                             # Architecture + user-facing docs
├── agent.md                              # Instructions for AI coding assistants
├── docker-bake.hcl                       # Multi-target build config for the interactive stack
├── renovate.json                         # Renovate schedule + custom regex manager
├── archive/                              # Retired image definitions (not built by CI)
│   ├── base/Dockerfile.retired
│   └── build.sh                          # Old manual build script (references retired images)
├── doc/
│   └── HANDOFF.md                        # This file
└── dockerfiles/
    ├── python/{3.10,3.11,3.12,3.13,3.14}/Dockerfile
    ├── terminal/Dockerfile
    ├── webterm/Dockerfile
    ├── openvscode/Dockerfile
    ├── marimo/Dockerfile
    └── jupyterlab/                       # See §8 "Known state" — present but not wired into CI
```

Each image directory contains exactly one `Dockerfile`. There are no
separate `entrypoint.sh` / `startup.sh` files checked in — all startup
logic is written inline in the Dockerfile via `RUN cat >…<<EOF` heredocs.
Search for `startup.sh` in a given Dockerfile to find the embedded script.

## 2. Image stack and inheritance

All images are published to `images.canfar.net/cadc/` (CANFAR's Harbor
instance). The dependency chain is:

```
Docker Hub                        CANFAR Harbor
──────────                        ─────────────
python:<ver>-slim (pinned @sha) ▶ cadc/python:<ver>   (ver ∈ 3.10…3.14)
                                         │
                                         └─ (3.12 only) ▶ cadc/terminal:<RELEASE_TAG>
                                                                │
                                                                ├─ cadc/webterm:<RELEASE_TAG>
                                                                ├─ cadc/vscode:<RELEASE_TAG>
                                                                └─ cadc/marimo:<RELEASE_TAG>
```

- `cadc/python:<ver>` is tagged by Python version only (e.g.
  `cadc/python:3.12`). It is overwritten in place on every rebuild — no
  dated suffix.
- `cadc/terminal`, `cadc/webterm`, `cadc/vscode`, `cadc/marimo` are
  tagged with `<RELEASE_TAG>`, which the workflow generates as
  `$(date +'%y.%m')` — e.g. `26.04` for an April 2026 build.
- The `vscode` image is built from the `dockerfiles/openvscode/`
  directory (directory named `openvscode`, published image named
  `vscode`).
- Terminal is the only downstream image based on Python 3.12
  specifically. The other Python versions (3.10, 3.11, 3.13, 3.14) are
  published but not consumed elsewhere in this repo.

Ports and entrypoints exposed by each interactive image:

| Image        | EXPOSE | ENTRYPOINT / CMD                                 |
|--------------|--------|---------------------------------------------------|
| `terminal`   | —      | inherits from `python` (no CMD override)          |
| `webterm`    | 5000   | `CMD ["/cadc/startup.sh"]`                        |
| `vscode`     | 5000   | `ENTRYPOINT ["/bin/bash", "-e", "/cadc/startup.sh"]` (runs as user `vscode`) |
| `marimo`     | 5000   | `ENTRYPOINT ["/bin/bash", "-e", "/cadc/startup.sh"]` |

## 3. Build orchestration

Two build mechanisms coexist:

**a) `docker/build-push-action` for the Python matrix.**
The five Python version images are independent; they're built in
parallel as a matrix job in the workflow. Each version lives in its own
`dockerfiles/python/<ver>/Dockerfile` and has no dependency on the other
versions.

**b) `docker buildx bake` for the interactive stack.**
`docker-bake.hcl` defines four targets (`terminal`, `webterm`, `vscode`,
`marimo`). The key mechanism here is the `contexts` block on each
downstream target:

```hcl
target "webterm" {
  contexts = {
    "${REGISTRY}/cadc/terminal:${RELEASE_TAG}" = "target:terminal"
  }
  …
}
```

This tells bake: "when the webterm Dockerfile says
`FROM images.canfar.net/cadc/terminal:26.04`, substitute the
locally-built `terminal` target instead of pulling from the registry."

This trick is what allows the CI pipeline to build and push all four
interactive images in a single bake invocation without ever pushing an
intermediate terminal tag to the registry first. It also means the
workflow's `detect-changes` job must always include `terminal` in the
bake target list whenever any downstream target is selected, or the
bake substitution won't apply and the build will attempt a registry
pull. This invariant is enforced explicitly in the workflow; see §4.

## 4. CI/CD workflow

Single workflow: [`.github/workflows/image-pipeline.yml`](../.github/workflows/image-pipeline.yml).

### Triggers

| Trigger          | Condition                                                       |
|------------------|-----------------------------------------------------------------|
| `schedule`       | `0 6 1 * *` — 06:00 UTC on the 1st of every month               |
| `push`           | To `main`, only when `dockerfiles/**`, the workflow, `docker-bake.hcl`, or `renovate.json` change |
| `pull_request`   | Same path filter as push                                        |
| `workflow_dispatch` | Manual trigger from the Actions tab                          |

On `schedule` and `workflow_dispatch`, all image targets are force-rebuilt. On `push` and `pull_request`, only the targets affected by the changed paths are rebuilt (with dependency cascade — see below).

### Jobs

The workflow defines five jobs that fan out from a short setup stage:

1. **`setup`** — generates `RELEASE_TAG=$(date +'%y.%m')` once so every
   downstream job shares the same tag.
2. **`detect-changes`** — runs `dorny/paths-filter@v3` to figure out
   which image directories changed. Resolves the dependency cascade:
   - A change under `dockerfiles/python/3.12/**` forces `terminal` +
     all downstream to rebuild (terminal is `FROM cadc/python:3.12`).
   - A change to `dockerfiles/terminal/**` or `docker-bake.hcl`
     cascades into `webterm` + `vscode` + `marimo`.
   - Other Python versions (3.10, 3.11, 3.13, 3.14) don't cascade.
   - If any of `webterm`/`vscode`/`marimo` is selected, `terminal` is
     force-added to the bake target list (see §3).
   Emits a `bake_targets` output (newline-separated) consumed by the
   interactive-stack job.
3. **`lint`** — runs `hadolint` recursively. Two rules globally ignored
   via [`.hadolint.yaml`](../.hadolint.yaml): `DL3008` (apt version
   pinning — we selectively unpin ABI-stable binaries) and `DL3013`
   (pip version pinning — we use `uv`/`pixi` for Python package
   management).
4. **`python`** (matrix 3.10–3.14) — builds each Python image with
   `docker/build-push-action@v6`. Runs only if `python=true`. On PRs,
   `push` is set to `false` and the registry login is skipped.
5. **`interactive-stack`** — runs only if `bake_targets` is non-empty.
   Executes `docker buildx bake` with the computed target list and
   `RELEASE_TAG` from step 1. On PRs, `push` is `false` and the
   registry login is skipped.

The `python` and `interactive-stack` jobs each cache Docker layers
using `type=gha` (GitHub Actions cache) to speed up rebuilds.

### What pushes go where

On a successful non-PR run, the pipeline pushes:

| Job                  | Tags pushed (assuming all targets selected)                      |
|----------------------|------------------------------------------------------------------|
| `python` (matrix)    | `images.canfar.net/cadc/python:{3.10, 3.11, 3.12, 3.13, 3.14}`   |
| `interactive-stack`  | `images.canfar.net/cadc/{terminal, webterm, vscode, marimo}:<YY.MM>` |

Python tags are **overwritten in place** each build. Interactive-stack
tags are **per-month**, so e.g. `cadc/webterm:26.03` remains available
after `cadc/webterm:26.04` is pushed.

## 5. External services and secrets

The pipeline depends on three external services. None of them are
provisioned or managed from this repo.

### 5.1. CANFAR Harbor registry

- **Endpoint:** `images.canfar.net` (hardcoded in the workflow `env` and
  in `docker-bake.hcl` default).
- **Auth:** Workflow uses `secrets.CANFAR_REGISTRY_USER` and
  `secrets.CANFAR_REGISTRY_PASSWORD` via `docker/login-action@v3`.
- **Pending confirmation (for upstream adopter):**
  - Exact secret names as configured in the destination repo (the
    workflow will silently skip login if the names don't match; the
    subsequent push step will fail with an auth error).
  - That the service account behind those credentials has push rights
    to the `cadc/` project for all five image names
    (`python`, `terminal`, `webterm`, `vscode`, `marimo`). Harbor is
    per-project + per-repo ACL'd; a newly-introduced image name may
    require the repo to be created and permissions widened.
  - Credential rotation policy (who rotates, how often, what notifies
    GitHub Actions of the new secret value).

### 5.2. Mend Renovate (GitHub App)

Renovate opens PRs that bump pinned dependency versions. It is a
GitHub App installed per-repository; installing it on `opencadc/canfar-containers`
is a one-time administrative step performed via
`https://github.com/apps/renovate`.

Configuration lives in [`renovate.json`](../renovate.json):

- Extends `config:recommended`.
- Runs "on the first day of the month" in UTC.
- Defines one custom regex manager that extracts `ARG <NAME>_VERSION=…`
  values annotated by a `# renovate: datasource=… depName=… [versioning=…]`
  comment on the line above.
- Forces `versioning=pep440` for all `pypi` datasource pins, so
  PyPI-version comparisons follow PEP 440 even though the regex
  manager defaults to semver.

Once installed, Renovate's behavior on this repo is:

- Opens an "Dependency Dashboard" issue (requires Issues enabled on the
  repo; if disabled, the dashboard is silently skipped but update PRs
  still open).
- On the 1st of each month, scans all `ARG *_VERSION` pins plus standard
  `FROM` references in every Dockerfile, queries each configured
  datasource, and opens a PR for any that have newer versions available.

### 5.3. Repology

Renovate's `repology` datasource queries the public Repology API at
`https://repology.org/api/v1/` to resolve the current version of each
Debian package pin. No credentials required; Repology is a free
read-only service.

Quirk that affects this repo: Repology identifies Debian 13 (Trixie) by
the repo key `debian_13`, **not** `debian_trixie`. The `# renovate:`
comments therefore use `depName=debian_13/<pkg>`. Additionally, some
Debian binary packages are not exposed as standalone Repology projects
(they're produced by a differently-named source package). Those cannot
be tracked via the repology datasource and are installed unpinned. See
the "Pinning philosophy" section of the README for the rationale and
the decision procedure.

## 6. Local development

There is no formal dev-setup script. The following commands are
supported by the files in the repo:

### 6.1. Build the interactive stack locally

```bash
docker buildx bake                          # All four interactive targets
docker buildx bake terminal                 # Just terminal
docker buildx bake webterm vscode           # Two specific targets
RELEASE_TAG=26.05 docker buildx bake        # Override the tag (default: "local")
```

No `push` happens unless `--push` is passed or the bake config is
modified. With `RELEASE_TAG` unset, images are built with the tag
suffix `local` (defined as the default value in `docker-bake.hcl`).

### 6.2. Build a Python base image locally

```bash
docker build -t images.canfar.net/cadc/python:3.12 ./dockerfiles/python/3.12
```

The Dockerfile does not take build args, so no extra flags are needed.

### 6.3. Lint

```bash
docker run --rm -i hadolint/hadolint < dockerfiles/terminal/Dockerfile
# or recursively:
docker run --rm -v "$PWD:/src" -w /src hadolint/hadolint \
  sh -c 'find . -name Dockerfile | xargs -n1 hadolint'
```

The repo's `.hadolint.yaml` ignores `DL3008` and `DL3013` globally; no
other overrides are in effect.

### 6.4. Validate the Renovate config without installing the app

```bash
npx --yes --package renovate -- renovate-config-validator renovate.json
```

To see what the custom regex manager actually extracts from a given
Dockerfile (useful when adding new `ARG *_VERSION` pins):

```bash
npx --yes --package renovate -- renovate \
  --platform=local --dry-run=extract 2>&1 | grep -E '"depName"|"currentValue"'
```

This runs Renovate against the current working directory without
touching any remote and without needing the GitHub App installed.

## 7. Adding a new image to the stack

Concrete steps, derived from how the existing images are wired:

1. Create `dockerfiles/<newimage>/Dockerfile`.
2. Decide the base: if it inherits from `terminal`, use
   `FROM ${REGISTRY}/cadc/terminal:${BASE_TAG}` and accept `REGISTRY`
   and `BASE_TAG` as `ARG`s (see `openvscode` and `marimo` for the
   pattern).
3. Add a `target "<newimage>"` block to `docker-bake.hcl`. If it
   inherits from terminal, include the `contexts` substitution block
   used by the other downstream targets.
4. Add `"<newimage>"` to the `group "default"` targets list so a plain
   `docker buildx bake` builds it.
5. In `.github/workflows/image-pipeline.yml`:
   - Add a filter entry under the `detect-changes` job's
     `dorny/paths-filter` configuration.
   - Add the filter output to the `detect-changes` job `outputs`.
   - Update the "Resolve dependencies" step so upstream changes cascade
     correctly.
   - Update the "Determine bake targets" step to include the new
     target.
6. Confirm the Harbor `cadc/<newimage>` repository exists and the
   service account has push permission (see §5.1).

## 8. Known state and orphans

These are observed as of this handoff. They are intentional mentions,
not hidden problems.

- **`dockerfiles/jupyterlab/`** exists in the repo but is not referenced
  by `docker-bake.hcl` or the workflow. The most recent relevant commit
  on `main` is `chore: remove jupyter-notebook image from stack`. The
  directory appears to be a remnant — either delete it, or re-wire it
  in if JupyterLab is meant to be part of the stack. No build will
  produce a `cadc/jupyterlab` image until it is added to both the bake
  file and the workflow's `detect-changes` job.
- **`archive/`** contains `base/Dockerfile.retired` and `build.sh`. The
  shell script is a standalone manual build script that references an
  older five-layer hierarchy (`base`, `python`, `terminal`, `webterm`,
  `opencode`) that no longer corresponds to the current stack. It is
  not invoked by the workflow or referenced elsewhere in CI. Treat it
  as historical.
- **`agent.md`** is instructions for AI coding assistants (Cursor,
  Claude Code, etc.). It is out of sync in a few places with the
  current stack (references to "opencode" as a separate image, to a
  retired Ubuntu foundation). It does not affect the build; updating
  or removing it is orthogonal to operational concerns.
- **Two hadolint rules are globally ignored** (`DL3008`, `DL3013`) via
  `.hadolint.yaml`. The rationale is in the config file's comments:
  `DL3008` because some apt packages are deliberately unpinned
  (libatomic1, locales — see the pinning philosophy in the README) and
  pinning others is done via `ARG` which hadolint doesn't always
  recognize; `DL3013` because Python packages are managed with
  `uv`/`pixi`, not raw `pip`.

## 9. Pending confirmation items (for upstream adopter)

These are concrete questions that cannot be answered from the repo
itself. Each will surface as a real failure mode if left unaddressed.

1. **Registry secret names.** The workflow uses
   `secrets.CANFAR_REGISTRY_USER` and `secrets.CANFAR_REGISTRY_PASSWORD`.
   Confirm these exact names are provisioned in the destination repo's
   Actions secrets. If the existing convention uses different names,
   either rename the secrets or change the workflow.
2. **Harbor project layout and robot-account permissions.** Confirm
   the `cadc/` project exists on `images.canfar.net` and that the
   service account behind the secrets has push rights to
   `cadc/{python, terminal, webterm, vscode, marimo}`. Any image name
   that has never been pushed before may require a new Harbor repo
   and/or updated ACL.
3. **Tag format.** The workflow publishes interactive-stack images
   with tag `YY.MM` (e.g. `26.04`). Confirm this matches the
   project's expected tagging scheme. Alternative common choices
   include `vYY.MM`, `YYYY.MM`, or semantic versions.
4. **Python image tagging strategy.** `cadc/python:3.12` is overwritten
   in place each rebuild. If dated tags are also desired (e.g.
   `cadc/python:3.12-26.04`), the `python` job in the workflow needs
   its `tags:` input extended — a two-line change.
5. **Renovate install decision.** Renovate is a GitHub App; installing
   it on `opencadc/canfar-containers` is a separate administrative
   action from merging this code. Without the install, the
   `renovate.json` in the repo is dormant and pins will not be
   updated automatically — the monthly cron will still run, but only
   refreshes unpinned surface area (apt security updates on top of
   the same pinned base).
6. **Auto-merge policy.** Out of scope for this repo but worth
   deciding once Renovate is active: should Renovate be allowed to
   auto-merge low-risk updates (patch + digest), or should every PR
   require human review? This is a Renovate configuration change, not
   a code change. Currently nothing is auto-merged.
7. **Issues-enabled check.** Renovate's Dependency Dashboard requires
   Issues to be enabled on the repo. If disabled, the dashboard is
   silently skipped (update PRs still open, but there's no single
   pane summary).

---

Last updated alongside the handoff PR introducing this file. When the
pipeline, image stack, or external-service assumptions change, update
this file in the same PR as the code change.
