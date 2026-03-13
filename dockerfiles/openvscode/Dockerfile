# syntax=docker/dockerfile:1
#
# CANFAR OpenVSCode Server Image (Layer 3: Browser-based IDE)
#
# A sibling to webterm in the CANFAR container stack. Inherits from the
# terminal image and adds OpenVSCode Server as the browser-facing IDE on
# port 5000 (the CANFAR contributed session convention).
#
# Build chain: python:slim -> python -> terminal -> THIS IMAGE
#
# OpenVSCode Server is Gitpod's open-source VS Code for the browser,
# fully compatible with VS Code extensions from Open VSX.
#
# On the CANFAR Science Platform, this container is launched per-user.
# For contributed sessions the platform calls /cadc/startup.sh. The proxy
# strips the path prefix before forwarding, so the server serves from root.
# Authentication is handled externally by the platform.

ARG REGISTRY=images.canfar.net
ARG BASE_TAG=local

FROM ${REGISTRY}/cadc/terminal:${BASE_TAG}
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
LABEL description="CANFAR OpenVSCode Server IDE Environment" \
      org.opencontainers.image.version="26.03"

# Ensure bash is the default shell for terminal processes.
# On CANFAR, the platform injects users with /sbin/nologin in /etc/passwd,
# but code-server works because it respects $SHELL. OpenVSCode is stricter.
ENV SHELL=/bin/bash

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
ARG NODEJS_VERSION=20.19.2+dfsg-1
# renovate: datasource=repology depName=debian_trixie/npm versioning=deb
ARG NPM_VERSION=9.2.0~ds1-3
# renovate: datasource=repology depName=debian_trixie/jq versioning=deb
ARG JQ_VERSION=1.7.1-6+deb13u1
# renovate: datasource=repology depName=debian_trixie/libatomic1 versioning=deb
ARG LIBATOMIC1_VERSION=14.2.0-19

RUN apt-get update && apt-get install -y --no-install-recommends \
    emacs-nox=${EMACS_VERSION} \
    unzip=${UNZIP_VERSION} \
    nano=${NANO_VERSION} \
    tmux=${TMUX_VERSION} \
    vim-nox=${VIM_VERSION} \
    procps=${PROCPS_VERSION} \
    nodejs=${NODEJS_VERSION} \
    npm=${NPM_VERSION} \
    jq=${JQ_VERSION} \
    libatomic1=${LIBATOMIC1_VERSION} \
    && rm -rf /var/lib/apt/lists/*

# --- OpenVSCode Server ---
# Download and install OpenVSCode Server from Gitpod's releases.
# renovate: datasource=github-releases depName=gitpod-io/openvscode-server
ARG OPENVSCODE_VERSION=v1.109.5
# hadolint ignore=SC2086
RUN ARCH=$(uname -m | sed 's/x86_64/x64/' | sed 's/aarch64/arm64/') \
    && curl -fsSL "https://github.com/gitpod-io/openvscode-server/releases/download/openvscode-server-${OPENVSCODE_VERSION}/openvscode-server-${OPENVSCODE_VERSION}-linux-${ARCH}.tar.gz" \
       | tar -xz -C /opt \
    && mv "/opt/openvscode-server-${OPENVSCODE_VERSION}-linux-${ARCH}" /opt/openvscode-server \
    && ln -s /opt/openvscode-server/bin/openvscode-server /usr/local/bin/openvscode-server

# --- Cursor CLI Agent ---
# Cursor's AI terminal assistant for use in the integrated terminal.
# Installed via its official script, then moved to a system-wide path.
RUN curl https://cursor.com/install -fsS | bash \
    && mv /root/.local/share/cursor-agent /usr/local/share/cursor-agent \
    && ln -sf "/usr/local/share/cursor-agent/versions/$(find /usr/local/share/cursor-agent/versions -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | head -n 1)/cursor-agent" /usr/local/bin/agent \
    && chmod +x /usr/local/bin/agent \
    && rm -rf /root/.local

# --- Starship Prompt ---
# Starship is a fast, cross-shell prompt. Installed via its official script
# and configured to initialize in every bash login shell via /etc/profile.d/.
# renovate: datasource=github-releases depName=starship/starship
ARG STARSHIP_VERSION=v1.24.2
RUN curl -sS https://starship.rs/install.sh | sh -s -- --yes --version ${STARSHIP_VERSION} \
    && /usr/local/bin/starship init bash --print-full-init >> /etc/profile.d/terminal.sh

# --- Starship Gruvbox Theme ---
# Writes a full Starship config with the Gruvbox Dark color palette.
# Sections: username (yellow), directory (aqua, full path), git branch/status (green).
# hadolint ignore=SC2016
RUN printf 'scan_timeout = 1000\ncommand_timeout = 1000\npalette = "gruvbox"\n\n[palettes.gruvbox]\nbg0 = "#282828"\nyellow = "#d79921"\naqua = "#689d6a"\ngreen = "#98971a"\nred = "#cc241d"\n\n[username]\nshow_always = true\nstyle_user = "bg:yellow fg:bg0"\nstyle_root = "bg:red fg:bg0"\nformat = "[ $user ]($style)"\n\n[directory]\nstyle = "bg:aqua fg:bg0"\nformat = "[ $path ]($style)"\ntruncation_length = 0\ntruncate_to_repo = false\n\n[git_branch]\nsymbol = "λ "\nstyle = "bg:green fg:bg0"\nformat = "[ $symbol$branch ]($style)"\n\n[git_status]\ndisabled = false\nstyle = "bg:green fg:bg0"\nformat = "([$all_status$ahead_behind]($style))"\nstaged = "[+$count](bg:green fg:bg0)"\nmodified = "[~$count](bg:green fg:bg0)"\ndeleted = "[-$count](bg:green fg:bg0)"\nuntracked = "[?$count](bg:green fg:bg0)"\nahead = "[▲$count](bg:green fg:bg0)"\nbehind = "[▼$count](bg:green fg:bg0)"\n\n[container]\ndisabled = true\n\n[character]\nsuccess_symbol = "[ → ](bold green)"\nerror_symbol = "[ ✗ ](bold red)"\n' > /etc/starship.toml
ENV STARSHIP_CONFIG=/etc/starship.toml

# --- Machine-level VS Code Settings ---
# Configure terminal to use bash explicitly. On CANFAR, users have /sbin/nologin
# in /etc/passwd, so we must override the terminal profile.
RUN mkdir -p /opt/openvscode-server/data/Machine \
    && printf '{\n  "terminal.integrated.defaultProfile.linux": "bash",\n  "terminal.integrated.profiles.linux": {\n    "bash": {\n      "path": "/bin/bash",\n      "args": ["-l"]\n    }\n  }\n}\n' > /opt/openvscode-server/data/Machine/settings.json

# --- Startup Script ---
# On CANFAR, the proxy does NOT strip the session path, so we must set
# --server-base-path to match /session/contrib/<session-id>.
# The skaha_sessionid env var is injected by the platform at runtime.
# hadolint ignore=SC2016
RUN printf '#!/bin/bash -e\nset -e\n\necho "[OpenVSCode] Starting OpenVSCode Server..."\n\nmkdir -p "${HOME}/.local/bin" "${HOME}/.cache/uv" "${HOME}/.pixi"\ncd "${HOME}"\n\n# Build base path from session ID if available (CANFAR platform)\nBASE_PATH_ARG=""\nif [ -n "${skaha_sessionid:-}" ]; then\n  BASE_PATH_ARG="--server-base-path /session/contrib/${skaha_sessionid}"\n  echo "[OpenVSCode] Using base path: /session/contrib/${skaha_sessionid}"\nfi\n\nexec /opt/openvscode-server/bin/openvscode-server \\\n  --host 0.0.0.0 \\\n  --port 5000 \\\n  --without-connection-token \\\n  --default-folder "${HOME}" \\\n  ${BASE_PATH_ARG}\n' > /cadc/startup.sh \
    && chmod +x /cadc/startup.sh

# Create a non-root user for running locally.
# On CANFAR, the platform overrides the user at runtime.
RUN useradd -m -s /bin/bash -u 1000 vscode

EXPOSE 5000
WORKDIR /tmp
USER vscode
ENTRYPOINT ["/bin/bash", "-e", "/cadc/startup.sh"]
