# OpenCADC Base Images

This repository contains the layered Dockerfile definitions for the OpenCADC/CANFAR container ecosystem, optimized for the CANFAR Science Platform.

## Architecture

The images follow a strictly layered, multi-stage model to ensure consistency and reproducibility. All images are hosted at `images.canfar.net/skaha/`.

1. **Base Image (`opencadc-base`)**: 
   - **OS**: Ubuntu 24.04 LTS (Pinned)
   - **Runtime**: Micromamba + Python 3.13
   - **Tools**: `uv`, `pixi`, `pip-tools`
   - **Science Stack**: `cadcdata`, `cadctap`, `cadcutils`, `canfar`, `vos`
2. **Terminal Image (`opencadc-terminal`)**: 
   - **Inherits**: `opencadc-base`
   - **UI**: `ttyd` (Web Terminal), `tmux`, `starship` (Gruvbox theme)
   - **Utilities**: `rclone`, `jq`, `htop`, `rsync`
3. **Terminal AI Image (`opencadc-terminal-oc`)**: 
   - **Inherits**: `opencadc-terminal`
   - **AI**: Integrated **OpenCode AI** CLI (`oc` alias)

## Build & Deployment

Because these images inherit from each other, they must be built and pushed in the following sequence. 

**One-Line Build & Push (Tag: 26.02):**
```bash
docker login images.canfar.net && \
docker build --rm --platform linux/amd64 -t images.canfar.net/skaha/opencadc-base:26.02 ./base/ && \
docker push images.canfar.net/skaha/opencadc-base:26.02 && \
docker build --rm --platform linux/amd64 -t images.canfar.net/skaha/opencadc-terminal:26.02 ./terminal/ && \
docker push images.canfar.net/skaha/opencadc-terminal:26.02 && \
docker build --rm --platform linux/amd64 -t images.canfar.net/skaha/opencadc-terminal-oc:26.02 ./terminal-oc/ && \
docker push images.canfar.net/skaha/opencadc-terminal-oc:26.02
```

## Features & Persistence

The ecosystem is pre-configured for automatic home-directory persistence on CANFAR Skaha:

- **Conda/Mamba**: Environments and package caches are prioritized to `~/.conda/envs` and `~/.conda/pkgs` via `/etc/conda/condarc`.
- **Pip**: Configured for `--user` installs by default in `/etc/pip.conf`.
- **Modern Tooling**: `uv` and `pixi` caches are redirected to `${HOME}/.cache/uv` and `${HOME}/.pixi`.
- **Shell**: Starship prompt with Gruvbox theme and persistent shell history.
