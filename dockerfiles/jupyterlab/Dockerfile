# syntax=docker/dockerfile:1
#
# CANFAR JupyterLab Image (Layer 3: Browser-based Notebook)
#
# A sibling to webterm in the CANFAR container stack. Inherits from the
# terminal image and adds JupyterLab as the browser-facing service on
# port 5000 (the CANFAR contributed session convention).
#
# Build chain: python:slim -> python -> terminal -> THIS IMAGE
#
# On the CANFAR Science Platform, this container is launched per-user.
# For contributed sessions the platform calls /cadc/startup.sh.
# JupyterLab runs directly on port 5000 (no nginx). Authentication is external.

ARG REGISTRY=images.canfar.net
ARG BASE_TAG=local

FROM ${REGISTRY}/cadc/terminal:${BASE_TAG}
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
LABEL description="CANFAR JupyterLab Notebook Environment" \
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

# --- JupyterLab + Extensions ---
# Installed via uv (inherited from the python layer) into the system Python.
# renovate: datasource=pypi depName=jupyterlab
ARG JUPYTERLAB_VERSION=4.5.5
# renovate: datasource=pypi depName=notebook
ARG NOTEBOOK_VERSION=7.5.4
# renovate: datasource=pypi depName=jupyterlab-git
ARG JUPYTERLAB_GIT_VERSION=0.52.0
# renovate: datasource=pypi depName=ipywidgets
ARG IPYWIDGETS_VERSION=8.1.8
RUN uv pip install --system \
    jupyterlab==${JUPYTERLAB_VERSION} \
    notebook==${NOTEBOOK_VERSION} \
    jupyterlab-git==${JUPYTERLAB_GIT_VERSION} \
    ipywidgets==${IPYWIDGETS_VERSION}

# --- Startup Script ---
# Run JupyterLab on port 5000. On CANFAR (skaha_sessionid set), set base_url so
# redirects and URLs include the session path and work behind the proxy.
# Session ID can come from skaha_sessionid env or from first argument ($1).
# Ensures HOME, .token, .local, .cache/uv, .pixi exist for persistence.
COPY startup.sh /cadc/startup.sh
RUN chmod +x /cadc/startup.sh

# --- JupyterLab Terminal Theme (Gruvbox) ---
# Configure the terminal to match the webterm Gruvbox dark theme.
# Run as root; CANFAR may override user at runtime.
RUN mkdir -p /usr/local/share/jupyter/lab/settings \
    && printf '{\n  "@jupyterlab/terminal-extension:plugin": {\n    "theme": "dark",\n    "fontFamily": "monospace",\n    "fontSize": 14\n  }\n}\n' > /usr/local/share/jupyter/lab/settings/overrides.json

# --- Build info (for inspection in running sessions, e.g. cat /build_info/Dockerfile) ---
WORKDIR /build_info
COPY Dockerfile /build_info/
RUN uv pip freeze > /build_info/pip.list 2>/dev/null || true
WORKDIR /tmp

EXPOSE 5000
ENTRYPOINT ["/bin/bash", "-e", "/cadc/startup.sh"]
