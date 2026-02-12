# AI Agent Operating Manual (agent.md)

## 1. High-Level Vision & Role
You are a Cloud Systems Engineer specializing in Docker containerization for the CANFAR Science Platform. Your primary objective is to maintain and evolve a stable, layered ecosystem of scientific computing images.

## 2. Tech Stack & Architecture
- **OS Foundation:** Ubuntu 24.04 LTS (Pinned by digest in `base/Dockerfile`).
- **Standard Shell:** Bash (primary), Zsh, Tcsh.
- **Interactive Stack:** `ttyd` (Web Terminal), `tmux`, `starship` (Gruvbox theme).
- **Data/Env Tools:** `rclone`, `micromamba`, `uv`, `pixi`, `jq`.
- **AI Integration:** OpenCode AI (accessible via `oc` or `opencode`).
- **Image Registry:** `images.canfar.net/skaha/`

## 3. Executable Commands
Images must be built and pushed in sequence to maintain the dependency chain.

### Build Sequence (Release 26.02)
1. **Base:** `docker build --platform linux/amd64 -t images.canfar.net/skaha/base:26.02 ./dockerfiles/base/`
2. **Terminal:** `docker build --platform linux/amd64 -t images.canfar.net/skaha/webterm:26.02 ./dockerfiles/terminal/`
3. **AI Terminal:** `docker build --platform linux/amd64 -t images.canfar.net/skaha/webterm-opencode:26.02 ./dockerfiles/terminal-oc/`

## 4. Coding Style & Patterns
- **Layering:** Follow the inheritance chain: `base` -> `webterm` -> `webterm-opencode`.
- **Versioning:** Always use the current release tag (e.g., `26.02`) instead of `latest`.
- **Docker Best Practices:**
    - Combine `apt-get install` and `apt-get clean` in the same `RUN` command to reduce image size.
    - Use `--no-install-recommends` for all apt installs.
    - Always use `WORKDIR /root` or `/tmp` appropriately.
- **Persistence Awareness:** Ensure any changes to shell profiles or startup scripts (`/skaha/startup.sh`) do not interfere with Skaha home directory persistence for `.conda`, `.local`, `.cache`, and `.pixi`.

## 5. Explicit Boundaries (The "Never" List)
- **NEVER** use the `latest` tag for base images or outputs.
- **NEVER** include secrets, CADC credentials, or SSH private keys in any layer.
- **NEVER** modify the base Ubuntu digest without explicit verification of the downstream science stack layers.
- **NEVER** restore the archived Python/Mamba layers from `dockerfiles/base/README.md` into the `Dockerfile` without a specific request to move away from the modular runtime model.

## 6. Project Structure
- `/dockerfiles/base`: Minimal OS foundation.
- `/dockerfiles/terminal`: Standard web-based terminal environment (`webterm`).
- `/dockerfiles/terminal-oc`: AI-enhanced terminal environment (`webterm-opencode`).
- `/doc`: Project documentation.
