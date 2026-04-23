# Handoff Notes

This document describes how the repository is organized, how the CI/CD
pipeline operates, and what external services it depends on. It is
scoped strictly to what exists in this repository today — anything that
cannot be determined from the code, workflow, or configuration files is
called out as a **pending confirmation** item for whoever operates the
stack upstream.

For the user-facing architecture overview, image descriptions, and
pinning philosophy, see [`README.md`](../README.md). For the
merge-window / release-window cadence policy, see
[`RELEASE-CADENCE.md`](RELEASE-CADENCE.md). This document focuses on
operational and maintenance concerns.

---

## 1. Repository layout

```
canfar-containers/
├── .github/workflows/image-pipeline.yml  # Single CI/CD workflow
├── .gitignore
├── .hadolint.yaml                        # Hadolint ignore list (DL3008, DL3013)
├── README.md                             # Architecture + user-facing docs
├── docker-bake.hcl                       # Multi-target build config for the interactive stack
├── renovate.json                         # Renovate schedule + custom regex manager
├── archive/                              # Retired image definitions (not built by CI)
│   ├── base/Dockerfile.retired
│   └── build.sh                          # Old manual build script (references retired images)
├── doc/
│   ├── HANDOFF.md                        # This file
│   └── RELEASE-CADENCE.md                # Merge window / release window policy
└── dockerfiles/
    ├── python/{3.10,3.11,3.12,3.13,3.14}/Dockerfile
    ├── terminal/Dockerfile
    ├── webterm/Dockerfile
    ├── openvscode/Dockerfile
    ├── marimo/Dockerfile
    └── carta/Dockerfile
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

ubuntu:24.04 (pinned @sha)      ▶ cadc/carta:<CARTA_TAG>
  + cartavis-team PPA             (standalone; does NOT inherit from cadc/terminal)
                                  (CARTA_TAG = upstream CARTA version, e.g. "5.1.0")
```

- `cadc/python:<ver>` is tagged by Python version only (e.g.
  `cadc/python:3.12`). It is overwritten in place on every rebuild — no
  dated suffix.
- `cadc/terminal`, `cadc/webterm`, `cadc/vscode`, `cadc/marimo` are
  tagged with `<RELEASE_TAG>`, which the workflow generates as
  `$(date +'%y.%m')` — e.g. `26.04` for an April 2026 build.
- `cadc/carta` is tagged with `<CARTA_TAG>`, the upstream CARTA version
  (e.g. `5.1.0`), **deliberately decoupled from `<RELEASE_TAG>`** so the
  tag reflects what astronomers install rather than our monthly cadence.
  CI derives `CARTA_TAG` from `dockerfiles/carta/Dockerfile`'s
  `ARG CARTA_VERSION` by stripping the `~noble1` PPA-rebuild suffix:
  `5.1.0~noble1 → 5.1.0`. Renovate updates `CARTA_VERSION` via its `deb`
  datasource; the tag follows automatically on the next rebuild.
- The `vscode` image is built from the `dockerfiles/openvscode/`
  directory (directory named `openvscode`, published image named
  `vscode`).
- Terminal is the only downstream image based on Python 3.12
  specifically. The other Python versions (3.10, 3.11, 3.13, 3.14) are
  published but not consumed elsewhere in this repo.
- `cadc/carta` is a standalone leaf — it builds from `ubuntu:24.04`
  (dictated by the cartavis-team PPA being Ubuntu-only) and does not
  inherit from `cadc/terminal`. The other images here are all
  Debian-based via `python:slim`.

Ports and entrypoints exposed by each interactive image:

| Image        | EXPOSE | ENTRYPOINT / CMD                                 |
|--------------|--------|---------------------------------------------------|
| `terminal`   | —      | inherits from `python` (no CMD override)          |
| `webterm`    | 5000   | `CMD ["/cadc/startup.sh"]`                        |
| `vscode`     | 5000   | `ENTRYPOINT ["/bin/bash", "-e", "/cadc/startup.sh"]` (runs as user `vscode`) |
| `marimo`     | 5000   | `ENTRYPOINT ["/bin/bash", "-e", "/cadc/startup.sh"]` |
| `carta`      | 3002   | `CMD ["carta", "--no_browser"]` (Skaha's `carta` session launcher overrides `CMD` and supplies `--port`, `--http_url_prefix`, `--top_level_folder`, `--debug_no_auth`, `--idle_timeout`, `--enable_scripting`, and the starting folder per-session) |

## 3. Build orchestration

Two build mechanisms coexist:

**a) `docker/build-push-action` for the Python matrix.**
The five Python version images are independent; they're built in
parallel as a matrix job in the workflow. Each version lives in its own
`dockerfiles/python/<ver>/Dockerfile` and has no dependency on the other
versions.

**b) `docker buildx bake` for the interactive stack.**
`docker-bake.hcl` defines five targets (`terminal`, `webterm`, `vscode`,
`marimo`, `carta`). For webterm / vscode / marimo the key mechanism is
the `contexts` block, which wires each downstream target to the
locally-built terminal:

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
terminal-derived interactive images in a single bake invocation without
ever pushing an intermediate terminal tag to the registry first. It also
means the workflow's `detect-changes` job must always include `terminal`
in the bake target list whenever any downstream target is selected, or
the bake substitution won't apply and the build will attempt a registry
pull. This invariant is enforced explicitly in the workflow; see §4.

The fifth target, `carta`, is a standalone leaf — it has no `contexts`
block and builds directly from `ubuntu:24.04` (plus the cartavis-team
PPA). It does not force a terminal rebuild and is not affected by
terminal changes; selecting it in isolation will not pull `terminal`
into the bake target list.

## 4. CI/CD workflow

Single workflow: [`.github/workflows/image-pipeline.yml`](../.github/workflows/image-pipeline.yml).

### Triggers

| Trigger             | Condition                                                                             |
|---------------------|---------------------------------------------------------------------------------------|
| `schedule`          | Three crons: `0 6 1 * *`, `0 6 2 * *`, `0 6 3 * *` — days 1/2/3, 06:00 UTC            |
| `push`              | To `main`, only when `dockerfiles/**`, the workflow, or `docker-bake.hcl` change      |
| `pull_request`      | Same path filter as push (plus `renovate.json`)                                       |
| `workflow_dispatch` | Manual trigger from the Actions tab                                                   |

The three `schedule` crons implement a **staggered release window**
(day 1 → python, day 2 → terminal, day 3 → interactive stack
including `webterm`, `vscode`, `marimo`, and the standalone `carta`),
with a release anchor tag (`release/YY.MM`) pushed on day 3. On
`schedule`, a **phase gate** restricts each day to its own subset of
images.

On `schedule` and `workflow_dispatch`, `detect-changes` diffs `HEAD`
against the previous month's `release/YY.MM` git tag to decide which
images actually need rebuilding. Unchanged images are skipped. If the
previous tag is missing (first run, or tag was deleted), the workflow
falls back to rebuilding everything in the current phase.

On `push` and `pull_request`, the existing `dorny/paths-filter`
cascade is used unchanged — no phase gate, no anchor-tag diff. PR
builds never push to the registry.

See [`RELEASE-CADENCE.md`](RELEASE-CADENCE.md) for the calendar,
rules, and rationale.

### Jobs

The workflow defines six jobs that fan out from a short setup stage:

1. **`setup`** — generates `RELEASE_TAG=$(date -u +'%y.%m')` once so
   every downstream job shares the same tag.
2. **`detect-changes`** — computes which images need to be built.
   Behavior depends on the trigger:
   - **schedule**: maps the cron that fired to a phase (`python` /
     `terminal` / `interactive`), diffs `HEAD` against the previous
     month's `release/YY.MM` git tag, and emits only the images in
     this phase that actually changed. If the previous tag is missing,
     falls back to rebuilding all images in the current phase.
   - **workflow_dispatch**: uses the same release-tag diff but emits
     every changed image across all phases (no phase gate).
   - **push** / **pull_request**: uses `dorny/paths-filter@v3` on the
     pushed commits (unchanged from the pre-cadence behavior).
   Resolves the dependency cascade in all modes:
   - A change under `dockerfiles/python/3.12/**` forces `terminal` +
     all Debian-based downstream (webterm/vscode/marimo) to rebuild
     (terminal is `FROM cadc/python:3.12`).
   - A change to `dockerfiles/terminal/**` or `docker-bake.hcl`
     cascades into `webterm` + `vscode` + `marimo`.
   - Other Python versions (3.10, 3.11, 3.13, 3.14) don't cascade.
   - **CARTA is a standalone leaf.** Its rebuild trigger is its own
     directory or `docker-bake.hcl`; it does not cascade from
     `terminal` or `python`, and changes to CARTA do not cascade
     elsewhere. It shares day 3 of the release window with the
     terminal-derived interactive stack but is phase-gated
     independently.
   - If any of `webterm`/`vscode`/`marimo` is selected, `terminal` is
     force-added to the bake target list (see §3). `carta` does NOT
     force terminal; the two subsystems are independent.
   - **Freshness override (age-based forced rebuild).** On scheduled
     runs, if the previous month's `release/<YY.MM>` tag is older than
     `FORCED_REBUILD_AGE_DAYS` (default 45), every image in today's
     phase is rebuilt regardless of file diff. This guarantees apt
     security patches eventually propagate even when no Renovate PR
     has triggered a file change (e.g. Canonical batches security
     fixes without re-publishing the `ubuntu:24.04` tag's digest, so
     Renovate sees no bump and CARTA would otherwise sit stale). The
     phase gate still applies — so on day 3 only the interactive
     stack gets the force, on day 2 only terminal, etc. The override
     does **not** apply to push / PR / workflow_dispatch events.
   Emits a `bake_targets` output (newline-separated) consumed by the
   interactive-stack job, plus a `phase` output for diagnostics.
3. **`lint`** — runs `hadolint` recursively. Two rules globally ignored
   via [`.hadolint.yaml`](../.hadolint.yaml): `DL3008` (apt version
   pinning — we selectively unpin ABI-stable binaries) and `DL3013`
   (pip version pinning — we use `uv`/`pixi` for Python package
   management).
4. **`python`** (matrix 3.10–3.14) — builds each Python image with
   `docker/build-push-action@v6`. Runs only if `python=true`. On PRs,
   `push` is set to `false` and the registry login is skipped.
5. **`interactive-stack`** — runs only if `bake_targets` is non-empty.
   Before invoking bake, a "Derive CARTA tag" step greps
   `dockerfiles/carta/Dockerfile` for `ARG CARTA_VERSION=` and strips
   the `~noble1` PPA-rebuild suffix, exporting the result as
   `CARTA_TAG` (e.g. `5.1.0~noble1 → 5.1.0`). Then executes
   `docker buildx bake` with the computed target list, `RELEASE_TAG`
   (monthly, for the Debian stack) and `CARTA_TAG` (upstream version,
   for CARTA) both in env. On PRs, `push` is `false` and the registry
   login is skipped.
6. **`tag-release`** — runs only on the day-3 scheduled cron, and only
   if `python` and `interactive-stack` didn't fail. Creates and pushes
   a `release/YY.MM` annotated git tag on the current commit. That tag
   is the diff anchor for next month's `detect-changes`. Requires
   `contents: write` permission on the default `GITHUB_TOKEN` (granted
   locally to this job, not at workflow scope). If the tag already
   exists (re-run of an already-tagged release), the job exits cleanly
   without retagging.

The `python` and `interactive-stack` jobs each cache Docker layers
using `type=gha` (GitHub Actions cache) to speed up rebuilds.

### What pushes go where

On a successful non-PR run, the pipeline pushes:

| Job                  | Tags pushed (assuming all targets selected)                      |
|----------------------|------------------------------------------------------------------|
| `python` (matrix)    | `images.canfar.net/cadc/python:{3.10, 3.11, 3.12, 3.13, 3.14}`   |
| `interactive-stack`  | `images.canfar.net/cadc/{terminal, webterm, vscode, marimo}:<YY.MM>`, `images.canfar.net/cadc/carta:<CARTA_VERSION>` |

Python tags are **overwritten in place** each build. Debian interactive-stack
tags (`terminal`, `webterm`, `vscode`, `marimo`) are **per-month**, so e.g.
`cadc/webterm:26.03` remains available after `cadc/webterm:26.04` is pushed.
`cadc/carta` tags are **per-upstream-version** (e.g. `5.1.0`), so a month
with no CARTA release doesn't push a new tag; a month with a CARTA bump
pushes a brand-new tag and the previous one stays available.

If an image's Dockerfile did not change between two consecutive
release windows, that image is **not republished** for the new month.
Its previous-month tag stays the newest in Harbor until something in
the image (or an upstream it depends on, or `docker-bake.hcl`)
actually changes.

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
    to the `cadc/` project for all six image names
    (`python`, `terminal`, `webterm`, `vscode`, `marimo`, `carta`).
    Harbor is per-project + per-repo ACL'd; a newly-introduced image
    name may require the repo to be created and permissions widened.
    `cadc/carta` is a new repository for this project and will almost
    certainly need to be created explicitly before the first push.
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
   - Update the "Diff against previous release tag" step to compute
     a changed/unchanged boolean for the new image (and respect any
     cascade it introduces).
   - Update the "Resolve dependencies and apply phase gate" step so
     the new image is emitted on the right day of the release window.
     If it belongs to the interactive stack, add it to the
     `interactive` case arm. If it deserves its own release day, add
     a fourth cron to the `schedule:` block and a new phase arm.
   - Update the "Determine bake targets" step to include the new
     target.
6. Confirm the Harbor `cadc/<newimage>` repository exists and the
   service account has push permission (see §5.1).
7. If you added a new release-window day, update
   [`RELEASE-CADENCE.md`](RELEASE-CADENCE.md) so the documented
   calendar matches the crons.

## 8. Known state and orphans

These are observed as of this handoff. They are intentional mentions,
not hidden problems.

- **`archive/`** contains `base/Dockerfile.retired` and `build.sh`. The
  shell script is a standalone manual build script that references an
  older five-layer hierarchy (`base`, `python`, `terminal`, `webterm`,
  `opencode`) that no longer corresponds to the current stack. It is
  not invoked by the workflow or referenced elsewhere in CI. Treat it
  as historical.
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
   `cadc/{python, terminal, webterm, vscode, marimo, carta}`. Any
   image name that has never been pushed before may require a new
   Harbor repo and/or updated ACL — in particular `cadc/carta` is
   newly introduced by this stack and will likely need the robot
   account's ACL extended.
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
8. **Tag-push permission.** The `tag-release` job pushes
   `release/YY.MM` tags using the default `GITHUB_TOKEN` with
   `permissions: contents: write` granted at job scope. If the
   destination org restricts `GITHUB_TOKEN` default permissions to
   read-only (Settings → Actions → General → Workflow permissions),
   the job-scoped grant still applies, but any org-level branch/tag
   protection rule that forbids `github-actions[bot]` from pushing
   tags matching `release/*` will fail the job silently — the images
   publish fine on day 3, but next month's diff has no anchor and
   falls back to a full rebuild. Confirm the org policy allows the
   bot to push release tags.
9. **Merge-window enforcement.** The cadence policy in
   [`RELEASE-CADENCE.md`](RELEASE-CADENCE.md) says "do not merge on
   days 1 – 4." This is currently a convention, not enforced by
   branch protection or by the workflow. If stricter enforcement is
   wanted, add a GitHub ruleset on `main` that blocks merges on
   those days of the month.

---

Last updated alongside the handoff PR introducing this file. When the
pipeline, image stack, or external-service assumptions change, update
this file in the same PR as the code change.
