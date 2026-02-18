# CANFAR Container Images

This repository contains the layered Dockerfile definitions for the CANFAR container ecosystem, optimized for the CANFAR Science Platform.

## Project Structure

The project is organized to provide a clear separation between the base foundation, language runtimes, and specialized application layers. Note that the Python stack and the Ubuntu base are independent foundations:

```
canfar-containers/
├── README.md           # Main documentation
├── .gitignore          # Git exclusion rules
└── dockerfiles/        # Container definitions
    ├── base/           # Ubuntu Foundation (Generic)
    ├── python/         # Python Foundation (Official Slim)
    ├── terminal/       # Interactive CLI environment (Starship)
    ├── webterm/        # Web-based terminal (ttyd)
    └── opencode/       # AI-enhanced terminal (OpenCode AI)
```

## Architecture

The images follow a modular layered model. All images are hosted at `images.canfar.net/cadc/`.

1. **Base Image (`base`)**: 
   - **OS**: Ubuntu 24.04 LTS (Pinned by digest)
   - **Status**: Standalone system foundation with essential utilities (`curl`, `git`, `vim`, etc.).

2. **Python Image (`python`)**:
   - **Inherits**: `python:slim` (Official Docker Hub)
   - **Runtime**: Python 3.10–3.14
   - **Managers**: `uv`, `pixi`

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

The project is transitioning toward a full CI/CD automation model for the entire stack.

**Phase 1: Automated Foundation Builds (Current)**
Base and Python images (3.10–3.14) are automatically built, linted, and pushed to the registry upon merging to the `main` branch.

**Phase 2: Full Stack Automation (Roadmap)**
We are moving toward GitHub Actions automation for the entire dependency chain (Base -> Python -> Terminal -> Webterm -> Opencode). This will eliminate manual builds and ensure all layers are synchronized with the latest security updates and releases.

**Manual Downstream Build (Interim):**
Until full automation is complete, downstream layers can be built manually using the current release tag:
```bash
docker build -t images.canfar.net/cadc/terminal:26.02 ./dockerfiles/terminal/
docker push images.canfar.net/cadc/terminal:26.02
```

## Maintenance

- **Git Flow**: This repository uses a feature-branch workflow. Please fork the repository and submit a Pull Request for any changes to be merged into the main branch.
