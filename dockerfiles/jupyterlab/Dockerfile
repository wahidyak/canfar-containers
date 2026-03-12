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
# For contributed sessions the platform calls /cadc/startup.sh. The proxy
# strips the path prefix before forwarding, so JupyterLab serves from root.
# Authentication is handled externally by the platform.

ARG REGISTRY=images.canfar.net
ARG BASE_TAG=local

FROM ${REGISTRY}/cadc/terminal:${BASE_TAG}
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
LABEL description="CANFAR JupyterLab Notebook Environment" \
      org.opencontainers.image.version="26.03"

# /cadc is the CANFAR platform convention for platform-managed scripts
RUN mkdir -p /cadc

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
# The CANFAR proxy strips the path prefix before forwarding, so JupyterLab
# serves from root (no base_url needed). Authentication handled by platform.
# hadolint ignore=SC2016
RUN printf '#!/bin/bash -e\nset -e\n\necho "[JupyterLab] Starting JupyterLab server..."\n\nmkdir -p "${HOME}/.local/bin" "${HOME}/.cache/uv" "${HOME}/.pixi" "${HOME}/.jupyter"\ncd "${HOME}"\n\nexec jupyter lab \\\n  --ServerApp.ip=0.0.0.0 \\\n  --ServerApp.port=5000 \\\n  --no-browser \\\n  --ServerApp.root_dir=/ \\\n  --ServerApp.allow_origin="*" \\\n  --ServerApp.token="" \\\n  --ServerApp.password="" \\\n  '"'"'--ServerApp.terminado_settings={"shell_command": ["/bin/bash", "-l"]}'"'"' \\\n  ${JUPYTERLAB_ARGS}\n' > /cadc/startup.sh \
    && chmod +x /cadc/startup.sh

# --- JupyterLab Terminal Theme (Gruvbox) ---
# Configure the terminal to match the webterm Gruvbox dark theme.
# This creates system-wide JupyterLab settings that apply to all users.
RUN mkdir -p /usr/local/share/jupyter/lab/settings \
    && printf '{\n  "@jupyterlab/terminal-extension:plugin": {\n    "theme": "dark",\n    "fontFamily": "monospace",\n    "fontSize": 14\n  }\n}\n' > /usr/local/share/jupyter/lab/settings/overrides.json

# Create a non-root user for running JupyterLab locally.
# On CANFAR, the platform overrides the user at runtime.
RUN useradd -m -s /bin/bash -u 1000 jupyter

EXPOSE 5000
WORKDIR /tmp
USER jupyter
ENTRYPOINT ["/bin/bash", "-e", "/cadc/startup.sh"]
