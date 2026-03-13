# syntax=docker/dockerfile:1
#
# CANFAR Marimo Image (Browser-based Reactive Notebooks)
#
# Sibling to jupyterlab in the CANFAR container stack. Inherits from the
# terminal image and adds Marimo as the browser-facing service on port 5000
# (the CANFAR contributed session convention).
#
# Build chain: python:slim -> python -> terminal -> THIS IMAGE
#
# On the CANFAR Science Platform, this container is launched per-user.
# The platform runs the container ENTRYPOINT; we use /cadc/startup.sh.
# Marimo runs directly on port 5000 (no nginx). Authentication is external.

ARG REGISTRY=images.canfar.net
ARG BASE_TAG=local

FROM ${REGISTRY}/cadc/terminal:${BASE_TAG}
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
LABEL description="CANFAR Marimo Reactive Notebook Environment" \
      org.opencontainers.image.version="26.03"

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

# Install editors, terminal multiplexer, process tools, and Node.js runtime.
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

# --- Starship Prompt (same as webterm: Gruvbox theme for in-app terminal) ---
# Starship init is appended to /etc/profile.d/terminal.sh so the terminal inside
# Marimo (Ctrl+J) uses the same prompt and colors as the webterm shell.
# renovate: datasource=github-releases depName=starship/starship
ARG STARSHIP_VERSION=v1.24.2
RUN curl -sS https://starship.rs/install.sh | sh -s -- --yes --version ${STARSHIP_VERSION} \
    && /usr/local/bin/starship init bash --print-full-init >> /etc/profile.d/terminal.sh

# --- Starship Gruvbox Theme ---
# Same palette and sections as webterm: username, directory, git branch/status, character.
# hadolint ignore=SC2016
RUN printf 'scan_timeout = 1000\ncommand_timeout = 1000\npalette = "gruvbox"\n\n[palettes.gruvbox]\nbg0 = "#282828"\nyellow = "#d79921"\naqua = "#689d6a"\ngreen = "#98971a"\nred = "#cc241d"\n\n[username]\nshow_always = true\nstyle_user = "bg:yellow fg:bg0"\nstyle_root = "bg:red fg:bg0"\nformat = "[ $user ]($style)"\n\n[directory]\nstyle = "bg:aqua fg:bg0"\nformat = "[ $path ]($style)"\ntruncation_length = 0\ntruncate_to_repo = false\n\n[git_branch]\nsymbol = "λ "\nstyle = "bg:green fg:bg0"\nformat = "[ $symbol$branch ]($style)"\n\n[git_status]\ndisabled = false\nstyle = "bg:green fg:bg0"\nformat = "([$all_status$ahead_behind]($style))"\nstaged = "[+$count](bg:green fg:bg0)"\nmodified = "[~$count](bg:green fg:bg0)"\ndeleted = "[-$count](bg:green fg:bg0)"\nuntracked = "[?$count](bg:green fg:bg0)"\nahead = "[▲$count](bg:green fg:bg0)"\nbehind = "[▼$count](bg:green fg:bg0)"\n\n[container]\ndisabled = true\n\n[character]\nsuccess_symbol = "[ → ](bold green)"\nerror_symbol = "[ ✗ ](bold red)"\n' > /etc/starship.toml
ENV STARSHIP_CONFIG=/etc/starship.toml

# --- Marimo ---
# Installed via uv (inherited from the terminal image) into the system Python.
# renovate: datasource=pypi depName=marimo
ARG MARIMO_VERSION=0.20.4
RUN uv pip install --system marimo==${MARIMO_VERSION}

# --- Startup Script ---
# Run Marimo directly on port 5000 (same pattern as working CANFAR Marimo: no nginx).
# hadolint ignore=SC2016
RUN printf '#!/bin/bash -e\nset -e\n\necho "[Marimo Startup] Starting Marimo server..."\n\nexec marimo --log-level INFO edit \\\n  --no-token \\\n  --port 5000 \\\n  --host 0.0.0.0 \\\n  --skip-update-check \\\n  --headless\n' > /cadc/startup.sh \
    && chmod +x /cadc/startup.sh

# --- Build info (for inspection in running sessions, e.g. cat /build_info/Dockerfile) ---
WORKDIR /build_info
COPY Dockerfile /build_info/
RUN uv pip freeze > /build_info/pip.list 2>/dev/null || true
WORKDIR /tmp

EXPOSE 5000
ENTRYPOINT ["/bin/bash", "-e", "/cadc/startup.sh"]
