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
