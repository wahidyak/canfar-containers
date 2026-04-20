# Next Session — Pick-Up Notes

Short context dump to resume work without re-reading the full transcript.
Authoritative references: [`README.md`](../README.md) for architecture,
[`doc/HANDOFF.md`](HANDOFF.md) for operational detail. This file is a
working scratchpad; delete or rewrite when no longer needed.

## Current state

- `main` is at the tip after merging PRs #1–#8. All Renovate cleanup,
  HANDOFF docs, README accuracy pass, `agent.md` removal, and
  `.cursor/` gitignore are landed.
- Mend Renovate dashboard: zero `no-result` warnings (last confirmed
  this session).
- Local tree is clean; no open branches on the fork besides `main`.
- Upstream (`opencadc/canfar-containers`) PR **not yet opened**.
  Maintainer (Shiny) gave the green light to open it and to include
  handoff documentation.

## Immediate next actions (ranked)

1. **Open the upstream PR** to `opencadc/canfar-containers:main`. One
   big PR, per Shiny's confirmation. Scope: everything on your fork's
   `main`.
2. **In the PR body, surface the §9 pending-confirmation items from
   HANDOFF.md as questions for the maintainer**, not guesses:
   - Registry secret names (`CANFAR_REGISTRY_USER` /
     `CANFAR_REGISTRY_PASSWORD` — do those match opencadc's?).
   - Harbor robot account permissions on `cadc/{python, terminal,
     webterm, vscode, marimo}`.
   - Tag format confirmation (`YY.MM` vs. something else opencadc uses).
   - Python-tag strategy: in-place overwrite per version vs. dated
     (`python:3.12-26.04`).
   - Renovate install decision on the upstream repo (they need to
     authorize the Mend app).
   - Auto-merge policy — mention as optional follow-up, don't push.
   - Enabling Issues on the upstream repo (for the Dependency
     Dashboard).
3. **Minor Dockerfile polish** (optional, low-priority, can bundle
   with upstream PR or skip):
   - Stale hardcoded `LABEL org.opencontainers.image.version="26.02"`
     in `dockerfiles/terminal/Dockerfile`; same with `"26.03"` in
     `openvscode/Dockerfile` and `marimo/Dockerfile`. These don't match
     the CI-computed `YY.MM` tag. Either drop the label or have CI
     substitute the value.

## Decisions made, to avoid rehashing

- **Do not change Renovate or the monthly cron cadence** (monthly
  vs. quarterly). Status quo is fine; it's a governance call for
  opencadc, not for the fork.
- **Delete `agent.md` rather than rewrite it.** Already done (PR #7).
  README + HANDOFF cover everything it claimed to.
- **Do not add CARTA or Firefly to `canfar-containers`.** Scope
  mismatch; they belong in `opencadc/science-containers`. See the
  CARTA/Firefly section below for the full reasoning.

## CARTA / Firefly — plan and recommendation

### What they actually are

- **CARTA** (`opencadc/science-containers/Dockerfiles/carta`):
  `FROM ubuntu:24.04`, installs CARTA via the cartavis-team Launchpad
  PPA (`apt install carta`), exposes port 3002, runs
  `carta --no_browser`. No shared base, no multi-stage build, no
  Renovate tracking on the PPA package. Tag is the upstream CARTA
  version (e.g. `5.1.0`). No dedicated CI workflow — release is
  manual `docker buildx build --push` then a human adds the `carta`
  label in the Harbor UI.
- **Firefly** (`opencadc/science-containers/Dockerfiles/firefly`):
  Two-stage. Stage 1 uses `gradle:jdk21-alpine` to compile the
  first-party CADC-SSO plugin (Java source in `cadc-sso/` — real code
  CADC maintains). Stage 2 starts from `ipac/firefly:2025.5` (IPAC's
  official Firefly image, itself Ubuntu-22.04-based) and copies the
  compiled JAR into its Tomcat webapp. Port 8080. Has a dedicated
  `firefly.yml` workflow with provenance, SBOM, cosign signing.

### Why they don't fit `canfar-containers`

- **No shared base.** CARTA needs Ubuntu 24.04 (PPA constraint);
  Firefly's runtime is whatever IPAC ships. Your repo's
  `python:3.12-slim` foundation is irrelevant to both.
- **Different tech stacks.** CARTA is a C++ binary; Firefly is a
  Java/Tomcat webapp with a JVM plugin. Neither is Python.
- **Different build shapes.** CARTA is a 20-line apt-install; Firefly
  is a two-stage Gradle compile + JAR injection into an upstream
  image.
- **Firefly is not just a Dockerfile.** The `cadc-sso` directory
  contains first-party Java source that CADC actively maintains.
  That code has its own life cycle and shouldn't move repos casually.
- **Upstream duplication.** Forking CARTA's PPA install or IPAC's
  Firefly image into `canfar-containers` adds zero value —
  `science-containers` already has both.
- **Existing CI quality.** The `firefly.yml` workflow already does
  provenance + SBOM + cosign signing, which your `image-pipeline.yml`
  does not. Moving Firefly into `canfar-containers` would be a
  downgrade.

### What the commonalities actually are

Not at the image level — at the **platform-contract level**:

1. Expose a single HTTP port (CARTA: 3002; Firefly: 8080).
2. Be launchable as an arbitrary UID (Skaha injects the user's UID at
   runtime).
3. Be labeled in Harbor with the session-type label (e.g. `carta`,
   `firefly`) so the Science Portal UI surfaces them.
4. Pushed to `images.canfar.net/skaha/*`.

These are **not** expressible as a shared base or build pattern.
The right artifact to capture them would be a documented "CANFAR
session-image contract" in `science-containers` or
`science-platform`, not a shared Dockerfile here.

### If CARTA/Firefly modernization is wanted later

The patterns from `canfar-containers` that **do** transfer:

- `# renovate: datasource=docker` pins on `FROM` lines.
- `# renovate:` with custom managers on version ARGs.
- Pinning philosophy (Repology check before pinning apt packages).
- Digest pinning where appropriate.
- Hadolint + CI build job shape.

The pattern that **does not** transfer: the Renovate `customManager`
for Launchpad PPA packages — no datasource exists. CARTA's `carta`
package would have to stay unpinned, with a comment explaining why
(analogous to `locales` / `libatomic1` in your terminal Dockerfile).

**Recommended form for a follow-up project:** open a separate PR on
`opencadc/science-containers` to port the Renovate annotation pattern
and pinning philosophy across the ~20 images in that repo. Reusable
GitHub Actions workflow (not per-image duplication) is the right
shape there because of the image count. **Do not mix this into the
`canfar-containers` upstream PR**; raise it as a separate conversation
with Shiny after the current PR lands.

### Suggested ask for Shiny (after upstream PR is in)

Short message:

> The Renovate/digest-pin/pinning-philosophy patterns from
> `canfar-containers` would apply cleanly to `science-containers`
> too — the CARTA and Firefly Dockerfiles in particular could benefit.
> Want me to open a separate PR there as a follow-up?

## Open questions worth flagging

- Is there a tagging convention at opencadc for CARTA-like images
  that use upstream versions (e.g. `5.1.0`) vs. the `YY.MM` cadence
  this repo uses? Relevant when the science-containers follow-up
  comes up.
- Is CADC doing anything with the attestation/SBOM/cosign stack
  that `science-containers/base.yml` uses, or is that one-off? If
  it's a pattern they value, `canfar-containers` CI probably wants
  to adopt it eventually.

## Reference — files worth re-reading first

- [`README.md`](../README.md) — architecture + pinning philosophy.
- [`doc/HANDOFF.md`](HANDOFF.md) — operational detail, §9 has the
  pending-confirmation items to surface in the upstream PR.
- [`.github/workflows/image-pipeline.yml`](../.github/workflows/image-pipeline.yml)
  — the four triggers and the cascade logic.
- [`renovate.json`](../renovate.json) — the custom manager and
  monthly schedule.
