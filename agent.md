# AI Agent Operating Manual (agent.md)

## 1. High-Level Vision & Role
You are a Cloud Systems Engineer specializing in Docker containerization for the CANFAR Science Platform. Your primary objective is to maintain and evolve a stable, layered ecosystem of scientific computing images.

## 2. Tech Stack & Architecture
- **OS Foundation:** Ubuntu 24.04 LTS (Pinned by digest in `base/Dockerfile`).
- **Python Runtime:** Python 3.12, Micromamba, `uv`, `pixi`.
- **Standard Shell:** Bash (primary), Zsh, Tcsh.
- **Interactive Stack:** `ttyd` (Web Terminal), `tmux`, `starship` (Gruvbox theme).
- **Data/Env Tools:** `rclone`, `jq`, `htop`, `rsync`.
- **AI Integration:** OpenCode AI (accessible via `oc` or `opencode`).
- **Image Registry:** `images.canfar.net/cadc/`

## 3. Executable Commands
Images must be built and pushed in sequence to maintain the dependency chain.

### Build Sequence (Release 26.02)
1. **Base:** `docker build --platform linux/amd64 -t images.canfar.net/cadc/base:26.02 ./dockerfiles/base/`
2. **Python:** `docker build --platform linux/amd64 -t images.canfar.net/cadc/python:26.02 ./dockerfiles/python/`
3. **Terminal:** `docker build --platform linux/amd64 -t images.canfar.net/cadc/terminal:26.02 ./dockerfiles/terminal/`
4. **Webterm:** `docker build --platform linux/amd64 -t images.canfar.net/cadc/webterm:26.02 ./dockerfiles/webterm/`
5. **AI Terminal:** `docker build --platform linux/amd64 -t images.canfar.net/cadc/webterm-opencode:26.02 ./dockerfiles/opencode/`

## 4. Coding Style & Patterns
- **Layering:** Follow the inheritance chain: `base` -> `python` -> `terminal` -> `webterm` -> `opencode`.
- **Versioning:** Always use the current release tag (e.g., `26.02`) instead of `latest`.
- **Docker Best Practices:**
    - Combine `apt-get install` and `apt-get clean` in the same `RUN` command to reduce image size.
    - Use `--no-install-recommends` for all apt installs.
    - Always use `WORKDIR /root` or `/tmp` appropriately.
- **Persistence Awareness:** Ensure any changes to shell profiles or startup scripts (`/cadc/startup.sh`) do not interfere with CADC home directory persistence for `.conda`, `.local`, `.cache`, and `.pixi`.

## 5. Explicit Boundaries (The "Never" List)
- **NEVER** use the `latest` tag for base images or outputs.
- **NEVER** include secrets, CADC credentials, or SSH private keys in any layer.
- **NEVER** modify the base Ubuntu digest without explicit verification of the downstream science stack layers.

## 6. Project Structure
- `/dockerfiles/base`: Layer 1: Minimal OS foundation.
- `/dockerfiles/python`: Layer 2: Python Runtime (Mamba, UV, Pixi).
- `/dockerfiles/terminal`: Layer 3: Interactive CLI environment.
- `/dockerfiles/webterm`: Layer 4: Web-based terminal.
- `/dockerfiles/opencode`: Layer 5: AI-enhanced terminal.
- `/doc`: Project documentation.
