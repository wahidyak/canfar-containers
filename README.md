# CANFAR Container Images

This repository contains the layered Dockerfile definitions for the CANFAR container ecosystem, optimized for the CANFAR Science Platform.

## Project Structure

The project is organized to provide a clear separation between the language runtimes and specialized application layers:

```
canfar-containers/
├── README.md           # Main documentation
├── .gitignore          # Git exclusion rules
├── archive/            # Retired/Legacy image definitions
└── dockerfiles/        # Container definitions
    ├── python/         # Python Foundation (Official Slim)
    ├── terminal/       # Interactive CLI environment
    ├── webterm/        # Web-based terminal (ttyd + Starship + OpenCode AI)
    ├── openvscode/     # VS Code in browser (vscode image)
    └── marimo/         # Marimo reactive notebooks
```

## Architecture

The images follow a modular layered model. All images are hosted at `images.canfar.net/cadc/`.

1. **Python Image (`python`)**:
   - **Inherits**: `python:slim` (Official Docker Hub)
   - **Runtime**: Python 3.10–3.14
   - **Managers**: `uv`, `pixi`

2. **Terminal Image (`terminal`)**:
   - **Inherits**: `python`
   - **Shell**: Customized bash aliases and completion
   - **Utilities**: `git`, `htop`, `acl`, `bash-completion`

3. **Webterm Image (`webterm`)**:
   - **Inherits**: `terminal`
   - **UI**: `ttyd` (Web Terminal) on port 5000
   - **Shell**: Starship prompt (Gruvbox theme)
   - **Editors**: `vim`, `emacs`, `nano`, `tmux`
   - **AI**: Integrated **OpenCode AI** CLI (`oc` alias)

4. **VS Code Image (`vscode`)**:
   - **Inherits**: `terminal`
   - **UI**: Open VS Code (browser) on port 5000

5. **Marimo Image (`marimo`)**:
   - **Inherits**: `terminal`
   - **UI**: Marimo reactive notebooks on port 5000

## Build & Deployment

The entire image stack is automated via GitHub Actions. The pipeline maintains a strict dependency chain:

1. **Python Layer**: Builds versions 3.10–3.14.
2. **Terminal Layer**: Inherits from Python 3.12.
3. **Webterm Layer**: Inherits from Terminal.
4. **Interactive stack** (vscode, marimo): Each inherits from Terminal and is built via Docker Bake.

**Release Tagging:**
The downstream images (`terminal`, `webterm`, `vscode`, `marimo`) are tagged with the current release version (e.g., `26.02`). Python images are tagged by Python version only (e.g., `python:3.12`) and are overwritten in place on each rebuild.

**Triggers:**
The pipeline runs on four events:

- **Scheduled**: 1st of every month at 06:00 UTC. All images rebuild to pick up upstream base-image and apt security updates.
- **Push to `main`**: Selective rebuild based on which files changed. The dependency chain is respected — changes to `dockerfiles/python/3.12/` or `dockerfiles/terminal/` cascade into all downstream images.
- **Pull requests**: Lint runs, plus affected images are built (with push disabled) so broken changes are caught before merge.
- **Manual**: via GitHub's "Actions" tab (`workflow_dispatch`), same behavior as scheduled.

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

## Maintenance

- **Git Flow**: This repository uses a feature-branch workflow. Please fork the repository and submit a Pull Request for any changes to be merged into the main branch.
