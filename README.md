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
The downstream images (`terminal`, `webterm`, `vscode`, `marimo`) are tagged with the current release version (e.g., `26.02`).

**Manual Trigger:**
While automated on push to `main`, the workflow can also be triggered manually via GitHub's "Actions" tab.

## Maintenance

- **Git Flow**: This repository uses a feature-branch workflow. Please fork the repository and submit a Pull Request for any changes to be merged into the main branch.
