# syntax=docker/dockerfile:1
#
# CANFAR Web Terminal Image (Layer 3: Browser-based Terminal)
#
# The top of the CANFAR container stack. Inherits from the terminal image and
# adds a full web-based development environment accessible via a browser:
#   - ttyd: serves a terminal over HTTP on port 5000
#   - Starship: a fast, customizable prompt with Gruvbox theme
#   - Editors: vim, emacs (terminal-only), nano, tmux
#   - AI Tools: OpenCode, GitHub Copilot CLI, Claude Code, Gemini CLI, Codex
#
# Build chain: python:slim -> python -> terminal -> THIS IMAGE
#
# On the CANFAR Science Platform, this container is launched per-user. The
# startup script (/cadc/startup.sh) starts ttyd which gives users a bash
# login shell in their browser. User home directories are persistent via
# CADC's volume mounts (.local, .cache, .pixi are preserved across sessions).

ARG REGISTRY=images.canfar.net
ARG BASE_TAG=26.02

# --- Stage 1: Grab the ttyd binary ---
# ttyd is a tool for sharing a terminal over the web. We pull its official
# image just to extract the static binary, keeping the final image clean.
# renovate: datasource=docker depName=tsl0922/ttyd versioning=semver
FROM tsl0922/ttyd:1.7.7 AS ttyd-bin

# --- Stage 2: Runtime (the actual image) ---
FROM ${REGISTRY}/cadc/terminal:${BASE_TAG}
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
LABEL description="CANFAR Web-based Terminal Environment" \
      org.opencontainers.image.version="26.02"

# /cadc is the CANFAR platform convention for platform-managed scripts
RUN mkdir -p /cadc

# --- Pinned APT Package Versions ---
# renovate: datasource=repology depName=debian_trixie/emacs versioning=deb
ARG EMACS_VERSION=1:30.1+1-6
# renovate: datasource=repology depName=debian_trixie/unzip versioning=deb
ARG UNZIP_VERSION=6.0-29
# renovate: datasource=repology depName=debian_trixie/nano versioning=deb
ARG NANO_VERSION=8.4-1
# renovate: datasource=repology depName=debian_trixie/tmux versioning=deb
ARG TMUX_VERSION=3.5a-3
# renovate: datasource=repology depName=debian_trixie/vim versioning=deb
ARG VIM_VERSION=2:9.1.1230-2
# renovate: datasource=repology depName=debian_trixie/procps versioning=deb
ARG PROCPS_VERSION=2:4.0.4-9
# renovate: datasource=repology depName=debian_trixie/nodejs versioning=deb
ARG NODEJS_VERSION=20.19.2+dfsg-1+deb13u2
# renovate: datasource=repology depName=debian_trixie/npm versioning=deb
ARG NPM_VERSION=9.2.0~ds1-3

# Install editors, terminal multiplexer, process tools, and Node.js runtime
# (Node/npm needed for the AI CLI tools installed later via npm)
RUN apt-get update && apt-get install -y --no-install-recommends \
    emacs-nox=${EMACS_VERSION} \
    unzip=${UNZIP_VERSION} \
    nano=${NANO_VERSION} \
    tmux=${TMUX_VERSION} \
    vim-nox=${VIM_VERSION} \
    procps=${PROCPS_VERSION} \
    nodejs=${NODEJS_VERSION} \
    npm=${NPM_VERSION} \
    && rm -rf /var/lib/apt/lists/*

# Copy the ttyd binary from the multi-stage build
COPY --from=ttyd-bin /usr/bin/ttyd /usr/local/bin/ttyd

# --- Starship Prompt ---
# Starship is a fast, cross-shell prompt. It's installed via its official
# installer script and configured to initialize in every bash login shell
# by appending its init script to /etc/profile.d/terminal.sh (shared with
# the aliases/completions from the terminal layer).
# renovate: datasource=github-releases depName=starship/starship
ARG STARSHIP_VERSION=v1.24.2
RUN curl -sS https://starship.rs/install.sh | sh -s -- --yes --version ${STARSHIP_VERSION} \
    && /usr/local/bin/starship init bash --print-full-init >> /etc/profile.d/terminal.sh

# --- Starship Gruvbox Theme ---
# Writes a full Starship config with the Gruvbox Dark color palette.
# Sections: username (yellow), directory (aqua, full path, no truncation),
# git branch (green, lambda symbol), git status (staged/modified/deleted
# counts), and a minimal character prompt (arrow/cross).
# The [container] section is disabled since everything runs in containers.
# hadolint ignore=SC2016
RUN printf 'scan_timeout = 1000\ncommand_timeout = 1000\npalette = "gruvbox"\n\n[palettes.gruvbox]\nbg0 = "#282828"\nyellow = "#d79921"\naqua = "#689d6a"\ngreen = "#98971a"\nred = "#cc241d"\n\n[username]\nshow_always = true\nstyle_user = "bg:yellow fg:bg0"\nstyle_root = "bg:red fg:bg0"\nformat = "[ $user ]($style)"\n\n[directory]\nstyle = "bg:aqua fg:bg0"\nformat = "[ $path ]($style)"\ntruncation_length = 0\ntruncate_to_repo = false\n\n[git_branch]\nsymbol = "λ "\nstyle = "bg:green fg:bg0"\nformat = "[ $symbol$branch ]($style)"\n\n[git_status]\ndisabled = false\nstyle = "bg:green fg:bg0"\nformat = "([$all_status$ahead_behind]($style))"\nstaged = "[+$count](bg:green fg:bg0)"\nmodified = "[~$count](bg:green fg:bg0)"\ndeleted = "[-$count](bg:green fg:bg0)"\nuntracked = "[?$count](bg:green fg:bg0)"\nahead = "[▲$count](bg:green fg:bg0)"\nbehind = "[▼$count](bg:green fg:bg0)"\n\n[container]\ndisabled = true\n\n[character]\nsuccess_symbol = "[ → ](bold green)"\nerror_symbol = "[ ✗ ](bold red)"\n' > /etc/starship.toml
ENV STARSHIP_CONFIG=/etc/starship.toml

# --- OpenCode AI ---
# OpenCode is an AI coding assistant CLI. Installed via its official script,
# then moved to a system-wide path. The "oc" alias is added to the shared
# profile so all users can access it.
# renovate: datasource=github-releases depName=opencode-ai/opencode
ARG OPENCODE_VERSION=1.1.63
RUN curl -fsSL https://opencode.ai/install | bash -s -- --version ${OPENCODE_VERSION} \
    && mv /root/.opencode/bin/opencode /usr/local/bin/opencode \
    && chmod +x /usr/local/bin/opencode \
    && rm -rf /root/.opencode \
    && echo 'alias oc="opencode"' >> /etc/profile.d/terminal.sh

# --- Additional AI CLI Agents ---
# Installed globally via npm. These provide CLI access to major AI providers:
#   - GitHub Copilot CLI: AI-powered shell suggestions
#   - Claude Code: Anthropic's coding assistant
#   - Gemini CLI: Google's AI assistant
#   - Codex CLI: OpenAI's coding agent
# renovate: datasource=npm depName=@githubnext/github-copilot-cli
ARG COPILOT_CLI_VERSION=0.1.36
# renovate: datasource=npm depName=@anthropic-ai/claude-code
ARG CLAUDE_CODE_VERSION=2.1.58
# renovate: datasource=npm depName=@google/gemini-cli
ARG GEMINI_CLI_VERSION=0.30.0
# renovate: datasource=npm depName=@openai/codex
ARG CODEX_CLI_VERSION=0.105.0
RUN npm install -g \
    @githubnext/github-copilot-cli@${COPILOT_CLI_VERSION} \
    @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} \
    @google/gemini-cli@${GEMINI_CLI_VERSION} \
    @openai/codex@${CODEX_CLI_VERSION}

# --- Cursor CLI Agent ---
# Cursor's AI terminal assistant. Installed via its official script, then
# the entire directory (which contains its bundled Node.js runtime) is moved
# to /usr/local/share for global access by the canfar user.
RUN curl https://cursor.com/install -fsS | bash \
    && mv /root/.local/share/cursor-agent /usr/local/share/cursor-agent \
    && ln -sf "/usr/local/share/cursor-agent/versions/$(find /usr/local/share/cursor-agent/versions -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | head -n 1)/cursor-agent" /usr/local/bin/agent \
    && chmod +x /usr/local/bin/agent \
    && rm -rf /root/.local

# --- tmux Persistent Sessions + Container Startup Script ---
# ttyd spawns "tmux new-session -A" for each browser connection. The -A flag
# creates a new session if none exists, or attaches to the existing one. When
# the browser disconnects, only the tmux client dies — the server keeps the
# session alive with full scrollback. On reconnect, -A reattaches automatically.
# Note: default-shell is set explicitly because CANFAR sets SHELL=/sbin/nologin
# (to block direct SSH login), which causes tmux to exit immediately without it.
# hadolint ignore=SC2016
RUN printf 'set -g default-shell /bin/bash\nset -g mouse off\nset -g history-limit 50000\nset -g status off\nset -g escape-time 50\n' > /etc/tmux.conf \
    && printf "#!/bin/bash\n\
mkdir -p \"\${HOME}/.local/bin\" \"\${HOME}/.cache/uv\" \"\${HOME}/.pixi\"\n\
ttyd --writable --port 5000 -w \"\${HOME}\" \
-t titleFixed=\"CANFAR Webterm\" \
-t theme='{\"background\": \"#282828\"}' \
tmux new-session -A -s canfar\n" > /cadc/startup.sh \
    && chmod +x /cadc/startup.sh

# --- Build info (for inspection in running sessions, e.g. cat /build_info/Dockerfile) ---
WORKDIR /build_info
COPY Dockerfile /build_info/
RUN uv pip freeze > /build_info/pip.list 2>/dev/null || true
WORKDIR /tmp

EXPOSE 5000
WORKDIR /tmp
CMD ["/cadc/startup.sh"]
