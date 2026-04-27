# CANFAR Container Images

This repository contains the layered Dockerfile definitions for the CANFAR container ecosystem, optimized for the CANFAR Science Platform. The stack is fully automated: Renovate keeps pinned dependencies current during a dedicated monthly merge window, and a GitHub Actions pipeline lints, builds, and publishes every image to the CANFAR Harbor registry on a staggered monthly release window (days 1 – 3). See [`doc/RELEASE-CADENCE.md`](doc/RELEASE-CADENCE.md) for the full policy.

## Project Structure

```
canfar-containers/
├── README.md           # This file
├── .gitignore          # Git exclusion rules
├── .hadolint.yaml      # Hadolint (Dockerfile linter) configuration
├── docker-bake.hcl     # Multi-target build definition for the interactive stack
├── renovate.json       # Renovate (dependency-update bot) configuration
├── archive/            # Retired image definitions (kept for historical reference; not built or published)
├── doc/                # Additional documentation
│   ├── HANDOFF.md          # Operational / maintenance reference
│   └── RELEASE-CADENCE.md  # Merge window / release window policy
├── .github/
│   └── workflows/
│       └── image-pipeline.yml  # Lint → build → push CI pipeline
└── dockerfiles/        # Container definitions
    ├── python/         # Python foundation (3.10 – 3.14)
    ├── terminal/       # Interactive CLI environment (base for the rest)
    ├── webterm/        # Web-based terminal (ttyd + Starship + AI CLIs)
    ├── openvscode/     # OpenVSCode Server (browser IDE) + Cursor agent
    ├── marimo/         # Marimo reactive notebooks
    ├── carta/          # CARTA: Cube Analysis and Rendering Tool for Astronomy
    ├── carta-psrecord/ # Diagnostic sibling of carta: same binary, wrapped in psrecord
    └── firefly/        # IPAC Firefly + CADC SSO TokenRelay adapter (Tomcat service)
```

## Architecture

The images follow a modular layered model. All images are published to `images.canfar.net/cadc/`.

1. **Python image (`python`)**
   - **Inherits**: `python:slim` (official, Debian 13 / "trixie" based, digest-pinned)
   - **Runtime**: Python 3.10 – 3.14 (one image per minor version, built in parallel)
   - **Package managers**: `uv` and `pixi` (copied in from their official binary images)

2. **Terminal image (`terminal`)**
   - **Inherits**: `cadc/python:3.12`
   - **CLI utilities**: `acl`, `bash-completion`, `ca-certificates`, `curl`, `git`, `htop`, `wget` (all version-pinned and Renovate-tracked)
   - **Locale**: UTF-8 (`en_US.UTF-8`) generated at build time; `LANG` / `LC_ALL` exported
   - **Shell**: Bash aliases (`py`, `ll`, `la`, safe `rm`/`cp`/`mv -i`, …), persistent history, and tab completion for `uv` and `pixi`

3. **Webterm image (`webterm`)**
   - **Inherits**: `terminal`
   - **Web UI**: `ttyd` on port 5000, spawning a persistent `tmux` session per connection
   - **Prompt**: Starship with a custom Gruvbox palette
   - **Editors / multiplexer**: `vim`, `emacs-nox`, `nano`, `tmux`
   - **AI coding CLIs**: OpenCode (`oc` alias), GitHub Copilot CLI, Claude Code, Gemini CLI, OpenAI Codex

4. **OpenVSCode image (`vscode`)**
   - **Inherits**: `terminal`
   - **Web UI**: OpenVSCode Server (Gitpod's open-source build of VS Code) on port 5000
   - **Extras**: Cursor's agent CLI (`agent`), Starship prompt with Gruvbox theme
   - **Tooling**: `nodejs`, `npm`, `jq`, `unzip`, plus the same editor/multiplexer set as webterm
   - **User**: runs as the non-root `vscode` user by default; the Science Platform overrides the UID at runtime

5. **Marimo image (`marimo`)**
   - **Inherits**: `terminal`
   - **Web UI**: Marimo reactive notebooks on port 5000
   - **Marimo** is installed via `uv pip install --system` and pinned via PyPI
   - Includes the same Starship Gruvbox prompt and editor set for the in-notebook terminal

6. **CARTA image (`carta`)**
   - **Inherits**: `ubuntu:24.04` (digest-pinned, tracked by Renovate)
   - **Upstream**: CARTA is distributed exclusively via the `cartavis-team` PPA for Ubuntu. No Debian or RHEL build exists, so this image does **not** share the Debian-based `cadc/terminal` base and is a standalone leaf in the build graph.
   - **Web UI**: CARTA launched by Skaha's first-class `carta` session type. The image exposes CARTA's upstream default port 3002 and ships a bare `CMD ["carta", "--no_browser"]`; Skaha's per-session launcher overrides the `CMD` and supplies runtime flags itself (`--port`, `--http_url_prefix`, `--top_level_folder`, `--debug_no_auth`, `--idle_timeout`, `--enable_scripting`, and the starting folder), so those concerns are deliberately **not** baked into the image.
   - **Pinning**: the apt version string of the `carta` package is tracked via Renovate's `deb` datasource pointed at the PPA's Packages index — this catches both upstream releases (e.g. `5.1.0 → 5.2.0`) and PPA rebuilds with the same upstream version (e.g. `~noble1 → ~noble2`). The PPA is installed via `add-apt-repository` (trust rooted in Launchpad's TLS), matching the upstream reference image.
   - **Tagging**: `cadc/carta:<upstream version>` (e.g. `cadc/carta:5.1.0`), **not** the `YY.MM` cadence of the rest of the interactive stack. The tag tracks what astronomers actually install; CI derives it from the Dockerfile's `CARTA_VERSION` arg by stripping the `~noble1` suffix.

7. **CARTA-psrecord image (`carta-psrecord`)**
   - **Inherits**: `ubuntu:24.04` (digest-pinned), installs the same `carta` package from the same PPA as `cadc/carta`.
   - **Purpose**: **diagnostic sibling** of `cadc/carta`, not a replacement. The image wraps `carta` under [`psrecord`](https://github.com/astrofrog/psrecord) so each session emits a CPU %, RSS, I/O, and child-process timeline of the CARTA backend under `$HOME/.carta_logs/<timestamp>_carta-backend.{log,png}`. Use when a session is slow / OOMing / thrashing disk, then switch the Skaha `carta` session type back to plain `cadc/carta` once the investigation is done.
   - **Runtime shape**: because `psrecord` wraps `carta`, `carta` is no longer PID 1 — Skaha's `CMD` override lands on the image's `/carta/start.sh` wrapper, which reads the Skaha env contract (`SKAHA_TOP_LEVEL_DIR`, `SKAHA_PROJECTS_DIR`, `SKAHA_SESSION_URL_PATH`) and re-emits the flags Skaha would otherwise pass directly (`--top_level_folder`, `--port`, `--http_url_prefix`, `--debug_no_auth`, `--idle_timeout`, `--enable_scripting`, starting folder). This is inherent to the "wrap with profiler" pattern and means this image has a tight coupling to Skaha's env-var contract that plain `cadc/carta` does not.
   - **Pinning**: shares the CARTA `deb` pin with `cadc/carta` (same `# renovate:` annotation), so a CARTA bump opens a single PR covering both Dockerfiles. `psrecord` and `matplotlib` are pinned via Renovate's `pypi` datasource.
   - **Optional duration cap**: set `PSRECORD_DURATION_SECONDS` (build-arg or runtime env, positive integer) to make `psrecord` — and CARTA alongside it — stop after that many seconds. Leave empty to sample until CARTA exits naturally.
   - **Tagging**: `cadc/carta-psrecord:<upstream version>` (e.g. `cadc/carta-psrecord:5.1.0`), tracking the same upstream CARTA version as `cadc/carta`. Both images retag together.

8. **Firefly image (`firefly`)**
   - **Inherits**: `ipac/firefly:<FIREFLY_VERSION>` (digest-pinned, tracked by Renovate's `docker` datasource). Two-stage build: a `gradle:jdk21-alpine` builder (also digest-pinned and Renovate-tracked) compiles a small Java SSO plugin that is then layered onto the upstream Firefly image.
   - **Upstream**: [IPAC Firefly](https://github.com/Caltech-IPAC/firefly) is a server-side Tomcat web app for astronomical image / table / catalog visualisation. Unlike the per-user CARTA / VS Code / marimo images, Firefly runs as a long-lived multi-user Tomcat service inside the cluster (one pod, Skaha proxies users to it) and is launched by Skaha as a first-class `firefly` session type.
   - **What we add on top of upstream**: the vendored `cadc-sso/` Gradle multi-project (sourced verbatim from [`opencadc/science-containers`](https://github.com/opencadc/science-containers/tree/main/science-containers/Dockerfiles/firefly/cadc-sso), Java 21) builds a `cadc-sso-lib-*.jar` that implements Firefly's `sso.framework.adapter` extension point. The `org.opencadc.security.sso.TokenRelay` class reads the `CADC_SSO` cookie from inbound requests and converts it into a `Bearer <token>` header for Firefly's outbound calls to CADC services (YouCAT, VOSpace, etc.) so users see authenticated data. The plugin is dropped into Tomcat's `webapps-ref/firefly/WEB-INF/lib/` and activated at runtime by setting `PROPS_sso__framework__adapter=org.opencadc.security.sso.TokenRelay` in the deployment manifest.
   - **Pinning**: three coordinated pins, all Renovate-tracked:
     - `FIREFLY_VERSION` (final-stage `ipac/firefly` tag, e.g. `2025.5`) and `GRADLE_VERSION` (builder image tag) via the `docker` datasource on the Dockerfile `ARG` lines.
     - The Caltech-IPAC/firefly **source clone** that runs *inside* the gradle build (to obtain `firefly.jar` as a compile-time dependency for `cadc-sso-lib`) is tracked via a second custom regex manager in `renovate.json` that targets `def fireflyTag = '<value>'` in `cadc-sso/lib/build.gradle` (datasource: `github-tags depName=Caltech-IPAC/firefly`). Renovate opens a separate PR when Caltech-IPAC publishes a new `release-*` tag.
     - Renovate's built-in `gradle` manager automatically tracks the Java dependency tree inside `cadc-sso/lib/build.gradle` and `cadc-sso/gradle/libs.versions.toml` (log4j-{api,core}, junit-jupiter, mockito, javax.servlet-api, javax.websocket-api, commons-math3, guava, palantir java-format, spotless, jacoco) -- no annotations required.
   - **What we deliberately do NOT ship**: the upstream reference repo includes `manifest.yaml` (Kubernetes Deployment + Service + Traefik IngressRoute) and `docker-compose.yaml` for local dev. Both are deploy-time artefacts owned by whoever operates Skaha and are out of scope for this image-publishing repo.
   - **Tagging**: `cadc/firefly:<upstream ipac/firefly version>` (e.g. `cadc/firefly:2025.5`), **not** the `YY.MM` cadence (mirrors the CARTA pattern). CI derives the tag from the Dockerfile's `FIREFLY_VERSION` arg.

## Build & Deployment

The entire image stack is automated via GitHub Actions (`.github/workflows/image-pipeline.yml`).

1. **Python layer**: builds versions 3.10 – 3.14 in a parallel matrix via `docker/build-push-action`.
2. **Terminal layer**: built on top of `cadc/python:3.12`.
3. **Interactive stack** (webterm, vscode, marimo, carta, carta-psrecord, firefly): webterm/vscode/marimo each inherit from `terminal` and are built together with it via `docker buildx bake` (see `docker-bake.hcl`). Bake's `contexts` feature wires those downstream images to the locally-built terminal, so no intermediate tag needs to be pushed between builds. CARTA, carta-psrecord, and firefly are also bake targets but are **standalone** — CARTA and carta-psrecord build from `ubuntu:24.04`, firefly is a two-stage build on top of `gradle:jdk21-alpine` + `ipac/firefly`. None depend on `terminal`. The two CARTA images share the upstream CARTA version pin and always rebuild together; firefly is independent.

**Release tagging**

- The Debian-based interactive images (`terminal`, `webterm`, `vscode`, `marimo`) are tagged with the current month in `YY.MM` format (e.g., `26.02`), generated fresh on each build.
- `cadc/carta` and `cadc/carta-psrecord` are both tagged with the **upstream CARTA version** (e.g. `cadc/carta:5.1.0`, `cadc/carta-psrecord:5.1.0`), deliberately decoupled from the `YY.MM` cadence so the tag tracks what astronomers actually install. The tag is derived in CI from `dockerfiles/carta/Dockerfile`'s `CARTA_VERSION` arg (stripping the `~noble1` PPA-rebuild suffix) and shared between both targets.
- `cadc/firefly` is tagged with the **upstream `ipac/firefly` version** (e.g. `cadc/firefly:2025.5`), same pattern as CARTA. The tag is derived in CI from `dockerfiles/firefly/Dockerfile`'s `FIREFLY_VERSION` arg.
- Python images are tagged by Python version only (e.g., `python:3.12`) and are overwritten in place on each rebuild.

**Triggers**

The pipeline runs on four events:

- **Scheduled (tiered release window)**: three crons on the 1st, 2nd, and 3rd of every month at 06:00 UTC. Day 1 publishes the Python matrix, day 2 the terminal base, day 3 the interactive stack (webterm, vscode, marimo, carta, carta-psrecord, firefly). On each day, an image is only rebuilt & republished if its Dockerfile (or an upstream it depends on) changed since the previous month's `release/YY.MM` git tag, **or** if that release tag is more than 45 days old — the latter forces a full rebuild so apt security patches eventually propagate even when no Renovate PR has triggered a file change. After a successful day-3 run, CI pushes a new `release/YY.MM` tag that anchors next month's diff.
- **Push to `main`**: selective rebuild based on which files changed, with push to the registry. The dependency chain is respected — changes to `dockerfiles/python/3.12/` or `dockerfiles/terminal/` cascade into all downstream images. No phase gate applies on push.
- **Pull requests**: lint runs, and affected images are built (with push disabled) so broken changes are caught before merge.
- **Manual (`workflow_dispatch`)**: escape hatch via GitHub's "Actions" tab. Uses the same release-tag diff as the scheduled runs but ignores the phase gate, so it rebuilds every changed image in one shot. Does **not** push a new `release/YY.MM` tag.

See [`doc/RELEASE-CADENCE.md`](doc/RELEASE-CADENCE.md) for the merge-window / release-window policy that governs when Renovate runs and when humans should (and shouldn't) merge.

## Automation

Two complementary systems keep the stack current:

- **Renovate** (hosted by [Mend](https://www.mend.io/), configured in `renovate.json`) continuously scans the Dockerfiles and workflow files, and opens PRs to bump any pinned dependency. PRs are scheduled to appear during the monthly **merge window** — days 5 through 27 UTC — so they never overlap with the release window (days 1 – 3) or the pre-release soft freeze (day 28 onward). Every `ARG *_VERSION=…` declaration with a `# renovate:` annotation is tracked automatically — base-image digests, PyPI and npm packages, GitHub releases, and Debian apt packages (via the [Repology](https://repology.org/) API). The Firefly subsystem additionally activates Renovate's built-in `gradle` manager (which auto-tracks the Java dependency tree in `cadc-sso/lib/build.gradle` and `cadc-sso/gradle/libs.versions.toml`) and a second custom regex manager that targets a `// renovate:`-annotated `def fireflyTag = '<value>'` line in that same `build.gradle` (datasource: `github-tags depName=Caltech-IPAC/firefly`).
- **Hadolint** (`hadolint/hadolint-action`) lints every Dockerfile on every push and PR. Repo-wide rules are in `.hadolint.yaml`.

### What the monthly rebuild actually refreshes

When an image *does* get rebuilt during the release window, the rebuild refreshes the parts of the image that are *not* explicitly pinned:

- **Refreshed on rebuild**: the Debian apt layer (security updates for `curl`, `git`, etc. that haven't been pinned to an exact version), any `pip install` / `npm install` without an explicit version, and upstream base-image layers that the maintainer has rebuilt.
- **Not refreshed by the cron alone**: any dependency pinned via `ARG *_VERSION=…` with a `# renovate:` annotation, and any base image pinned by `@sha256:…` digest. These change only when a Renovate PR bumping the pin is merged into `main` during the merge window.

An important consequence of the "only republish if something changed" rule: **if an image's Dockerfile has no commits between two consecutive releases, that image is not rebuilt at all, so unpinned apt security patches also don't land for that cycle.** The previous month's `YY.MM` tag in Harbor remains the current tag; no new one is cut for that image. In practice this is rare because Renovate typically lands at least one pin bump per image per cycle. See [`doc/RELEASE-CADENCE.md`](doc/RELEASE-CADENCE.md) for the full discussion of this trade-off.

**Renovate and the release window are complementary**: Renovate opens pin-bump PRs during the merge window (days 5 – 27), humans review and merge them, and the release window (days 1 – 3 of the next month) publishes fresh `YY.MM` tags containing both the merged pin bumps and any unpinned upstream patches.

### Pinning philosophy

Not every `apt` package in the Dockerfiles is pinned to an exact version, and this is deliberate. Packages fall into two categories:

- **Version-tracked (pinned).** An `ARG <NAME>_VERSION=…` declaration with a `# renovate: datasource=repology depName=debian_13/<pkg> versioning=deb` annotation above it, referenced in the `apt-get install` line as `<pkg>=${<NAME>_VERSION}`. Renovate opens a PR to bump the version whenever Repology reports a newer Debian 13 release. Use this for anything where reproducible builds across time actually matter — CLI tools, language runtimes, applications with behavior that can change between versions (`git`, `curl`, `nodejs`, `emacs`, etc.).
- **Unpinned-by-design.** The package is listed in `apt-get install` with no version suffix and no `ARG`. Use this for binary packages that Repology doesn't expose as their own project — typically libraries distributed from a differently-named source package (e.g. `locales` ships from `glibc`, `libatomic1` ships from `gcc-14`). Pinning them to an exact Debian version string (`2.41-12+deb13u2`, `14.2.0-19`) provides little real reproducibility benefit since they're ABI-stable runtime components, and actively causes build failures when the Debian mirror rolls past the pinned version. Each unpinned package has an inline comment explaining the decision.

**How to tell which category a new package falls into:** query the Repology API before adding a pin.

```
curl -sS "https://repology.org/api/v1/project/<pkgname>" | jq '.[] | select(.repo == "debian_13")'
```

If entries come back with an `origversion` matching the Debian package-version format (e.g. `8.14.1-2+deb13u2`), pin it. If nothing comes back, the package is a binary alias — install it unpinned with a comment, and don't add a `# renovate:` annotation (Renovate would report `no-result` on every run).

## Building locally

The interactive stack is driven by Docker Bake, which can be invoked directly:

```
# Build all interactive images (terminal, webterm, vscode, marimo, carta, carta-psrecord, firefly) with tag "local"
docker buildx bake

# Build a single target
docker buildx bake terminal

# Build just the CARTA subsystem
docker buildx bake carta carta-psrecord

# Build just Firefly
docker buildx bake firefly

# Override the release tag (applies to the Debian-based stack; CARTA uses CARTA_TAG, Firefly uses FIREFLY_TAG)
RELEASE_TAG=26.04 docker buildx bake
```

Individual Python images can be built with plain `docker build`:

```
docker build -t cadc/python:3.12 dockerfiles/python/3.12
```

## Maintenance

- **Git Flow**: This repository uses a feature-branch workflow. Please fork the repository and submit a Pull Request for any changes to be merged into the main branch.
- **Operational details**: for the CI/CD job breakdown, external services, secret names, the procedure for adding a new image to the stack, and other maintenance concerns, see [`doc/HANDOFF.md`](doc/HANDOFF.md).
