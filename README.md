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

## Maintenance

- **Git Flow**: This repository uses a feature-branch workflow. Please fork the repository and submit a Pull Request for any changes to be merged into the main branch.
