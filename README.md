# CANFAR Container Images

This repository contains the layered Dockerfile definitions for the CANFAR container ecosystem, optimized for the CANFAR Science Platform. The stack is fully automated: Renovate keeps pinned dependencies current, and a GitHub Actions pipeline lints, builds, and publishes every image to the CANFAR Harbor registry on a monthly cadence and on every merge to `main`.

## Project Structure

```
canfar-containers/
├── README.md           # This file
├── .gitignore          # Git exclusion rules
├── .hadolint.yaml      # Hadolint (Dockerfile linter) configuration
├── agent.md            # Guidance for AI coding assistants working on this repo
├── docker-bake.hcl     # Multi-target build definition for the interactive stack
├── renovate.json       # Renovate (dependency-update bot) configuration
├── archive/            # Retired image definitions (kept for historical reference; not built or published)
├── doc/                # Additional documentation
│   └── HANDOFF.md      # Operational / maintenance reference
├── .github/
│   └── workflows/
│       └── image-pipeline.yml  # Lint → build → push CI pipeline
└── dockerfiles/        # Container definitions
    ├── python/         # Python foundation (3.10 – 3.14)
    ├── terminal/       # Interactive CLI environment (base for the rest)
    ├── webterm/        # Web-based terminal (ttyd + Starship + AI CLIs)
    ├── openvscode/     # OpenVSCode Server (browser IDE) + Cursor agent
    └── marimo/         # Marimo reactive notebooks
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

## Build & Deployment

The entire image stack is automated via GitHub Actions (`.github/workflows/image-pipeline.yml`).

1. **Python layer**: builds versions 3.10 – 3.14 in a parallel matrix via `docker/build-push-action`.
2. **Terminal layer**: built on top of `cadc/python:3.12`.
3. **Interactive stack** (webterm, vscode, marimo): each inherits from `terminal` and is built together with it via `docker buildx bake` (see `docker-bake.hcl`). Bake's `contexts` feature wires the downstream images to the locally-built terminal, so no intermediate tag needs to be pushed between builds.

**Release tagging**

- Downstream images (`terminal`, `webterm`, `vscode`, `marimo`) are tagged with the current month in `YY.MM` format (e.g., `26.02`), generated fresh on each build.
- Python images are tagged by Python version only (e.g., `python:3.12`) and are overwritten in place on each rebuild.

**Triggers**

The pipeline runs on four events:

- **Scheduled**: 1st of every month at 06:00 UTC. All images rebuild to pick up upstream base-image and apt security updates.
- **Push to `main`**: selective rebuild based on which files changed. The dependency chain is respected — changes to `dockerfiles/python/3.12/` or `dockerfiles/terminal/` cascade into all downstream images.
- **Pull requests**: lint runs, and affected images are built (with push disabled) so broken changes are caught before merge.
- **Manual**: via GitHub's "Actions" tab (`workflow_dispatch`), same behavior as scheduled.

## Automation

Two complementary systems keep the stack current:

- **Renovate** (hosted by [Mend](https://www.mend.io/), configured in `renovate.json`) continuously scans the Dockerfiles and workflow files, and opens PRs to bump any pinned dependency. PRs are scheduled to appear on the 1st of each month (UTC). Every `ARG *_VERSION=…` declaration with a `# renovate:` annotation is tracked automatically — base-image digests, PyPI and npm packages, GitHub releases, and Debian apt packages (via the [Repology](https://repology.org/) API).
- **Hadolint** (`hadolint/hadolint-action`) lints every Dockerfile on every push and PR. Repo-wide rules are in `.hadolint.yaml`.

### What the monthly rebuild actually refreshes

The monthly cron only refreshes the parts of each image that are *not* explicitly pinned:

- **Refreshed every month**: the Debian apt layer (security updates for `curl`, `git`, etc. that haven't been pinned to an exact version), any `pip install` / `npm install` without an explicit version, and upstream base-image layers that the maintainer has rebuilt.
- **Not refreshed by the cron**: any dependency pinned via `ARG *_VERSION=…` with a `# renovate:` annotation, and any base image pinned by `@sha256:…` digest. These change only when a Renovate PR bumping the pin is merged into `main`.

In practice that means **Renovate and the monthly cron are complementary**: Renovate keeps the pins from going stale by opening PRs against `main` (scheduled on the 1st of each month, same cadence as the cron), and the cron publishes a fresh `YY.MM` tag from whatever is on `main` at the time. If Renovate PRs are reviewed and merged before the cron fires, that month's tag ships with both the latest pins and the latest upstream patches. If they aren't merged, the tag still ships — just with last month's pins plus any unpinned upstream updates.

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
# Build all interactive images (terminal, webterm, vscode, marimo) with tag "local"
docker buildx bake

# Build a single target
docker buildx bake terminal

# Override the release tag
RELEASE_TAG=26.04 docker buildx bake
```

Individual Python images can be built with plain `docker build`:

```
docker build -t cadc/python:3.12 dockerfiles/python/3.12
```

## Maintenance

- **Git Flow**: This repository uses a feature-branch workflow. Please fork the repository and submit a Pull Request for any changes to be merged into the main branch.
- **Operational details**: for the CI/CD job breakdown, external services, secret names, the procedure for adding a new image to the stack, and other maintenance concerns, see [`doc/HANDOFF.md`](doc/HANDOFF.md).
