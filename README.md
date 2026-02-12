# CANFAR Container Images

This repository contains the layered Dockerfile definitions for the CANFAR container ecosystem, optimized for the CANFAR Science Platform.

## Project Structure

The project is organized to provide a clear separation between the base foundation and specialized application layers:

```
canfar-containers/
├── README.md           # Main documentation
├── .gitignore          # Git exclusion rules
└── dockerfiles/        # Container definitions
    ├── base/           # Minimal OS foundation
    ├── terminal/       # Standard web-based terminal (webterm)
    └── terminal_opencode/    # AI-enhanced terminal (webterm-opencode)
```

## Architecture

The images follow a layered model to ensure consistency and reproducibility. All images are hosted at `images.canfar.net/skaha/`.

1. **Base Image (`base`)**: 
   - **OS**: Ubuntu 24.04 LTS (Pinned by digest)
   - **Status**: Minimal system foundation with essential utilities (`curl`, `git`, `vim`, etc.).
   - **Note**: Python runtime and Science stack layers have been moved to a local reference [README](./dockerfiles/base/README.md) for modularity.

2. **Terminal Image (`webterm`)**: 
   - **Inherits**: `base`
   - **UI**: `ttyd` (Web Terminal), `tmux`, `starship` (Gruvbox theme)
   - **Utilities**: `rclone`, `jq`, `htop`, `rsync`

3. **Terminal AI Image (`webterm-opencode`)**: 
   - **Inherits**: `webterm`
   - **AI**: Integrated **OpenCode AI** CLI (`oc` alias)

## Build & Deployment

To maintain the dependency chain, images must be built and pushed in sequence using the `26.02` version tag.

**One-Line Build & Push:**
```bash
docker login images.canfar.net && \
docker build --rm --platform linux/amd64 -t images.canfar.net/skaha/base:26.02 ./dockerfiles/base/ && \
docker push images.canfar.net/skaha/base:26.02 && \
docker build --rm --platform linux/amd64 -t images.canfar.net/skaha/webterm:26.02 ./dockerfiles/terminal/ && \
docker push images.canfar.net/skaha/webterm:26.02 && \
docker build --rm --platform linux/amd64 -t images.canfar.net/skaha/webterm-opencode:26.02 ./dockerfiles/terminal_opencode/ && \
docker push images.canfar.net/skaha/webterm-opencode:26.02
```

## Maintenance

- **Archived Layers**: The Python/Mamba runtime and CADC Science stack definitions are stored in `dockerfiles/base/README.md`. If full persistence and tool support are required in the base image, these layers should be restored to the `base/Dockerfile`.
- **Git Flow**: This repository uses a feature-branch workflow. Please fork the repository and submit a Pull Request for any changes to be merged into the main branch.
