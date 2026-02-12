# CANFAR Container Images

This repository contains the layered Dockerfile definitions for the CANFAR container ecosystem, optimized for the CANFAR Science Platform.

## Project Structure

The project is organized into a 5-layer hierarchy to provide a clear separation between the base foundation, language runtimes, and specialized application layers:

```
canfar-containers/
├── README.md           # Main documentation
├── .gitignore          # Git exclusion rules
└── dockerfiles/        # Container definitions
    ├── base/           # Layer 1: Minimal OS foundation
    ├── python/         # Layer 2: Python Runtime (Mamba, UV, Pixi)
    ├── terminal/       # Layer 3: Interactive CLI environment (Starship)
    ├── webterm/        # Layer 4: Web-based terminal (ttyd)
    └── opencode/       # Layer 5: AI-enhanced terminal (OpenCode AI)
```

## Architecture

The images follow a strictly layered model to ensure consistency and reproducibility. All images are hosted at `images.canfar.net/cadc/`.

1. **Base Image (`base`)**: 
   - **OS**: Ubuntu 24.04 LTS (Pinned by digest)
   - **Status**: Minimal system foundation with essential utilities (`curl`, `git`, `vim`, etc.).

2. **Python Image (`python`)**:
   - **Inherits**: `base`
   - **Runtime**: Python 3.12, Micromamba
   - **Managers**: `uv`, `pixi`, `pip-tools`

3. **Terminal Image (`terminal`)**:
   - **Inherits**: `python`
   - **Shell**: Starship prompt (Gruvbox theme), customized aliases
   - **Utilities**: `rclone`, `jq`, `htop`, `tmux`, `rsync`

4. **Webterm Image (`webterm`)**:
   - **Inherits**: `terminal`
   - **UI**: `ttyd` (Web Terminal) on port 5000

5. **Opencode Image (`webterm-opencode`)**: 
   - **Inherits**: `webterm`
   - **AI**: Integrated **OpenCode AI** CLI (`oc` alias)

## Build & Deployment

To maintain the dependency chain, images must be built and pushed in sequence using the `26.02` version tag.

**One-Line Build & Push:**
```bash
docker login images.canfar.net && \
docker build --rm --platform linux/amd64 -t images.canfar.net/cadc/base:26.02 ./dockerfiles/base/ && \
docker push images.canfar.net/cadc/base:26.02 && \
docker build --rm --platform linux/amd64 -t images.canfar.net/cadc/python:26.02 ./dockerfiles/python/ && \
docker push images.canfar.net/cadc/python:26.02 && \
docker build --rm --platform linux/amd64 -t images.canfar.net/cadc/terminal:26.02 ./dockerfiles/terminal/ && \
docker push images.canfar.net/cadc/terminal:26.02 && \
docker build --rm --platform linux/amd64 -t images.canfar.net/cadc/webterm:26.02 ./dockerfiles/webterm/ && \
docker push images.canfar.net/cadc/webterm:26.02 && \
docker build --rm --platform linux/amd64 -t images.canfar.net/cadc/webterm-opencode:26.02 ./dockerfiles/opencode/ && \
docker push images.canfar.net/cadc/webterm-opencode:26.02
```

## Maintenance

- **Git Flow**: This repository uses a feature-branch workflow. Please fork the repository and submit a Pull Request for any changes to be merged into the main branch.
