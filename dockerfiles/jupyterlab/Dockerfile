# syntax=docker/dockerfile:1
#
# CANFAR JupyterLab Image (Layer 3: Browser-based Notebook)
#
# A sibling to webterm in the CANFAR container stack. Inherits from the
# terminal image and adds JupyterLab as the browser-facing service on
# port 8888 (the CANFAR/Skaha notebook convention).
#
# Build chain: python:slim -> python -> terminal -> THIS IMAGE
#
# On the CANFAR Science Platform, this container is launched per-user.
# For contributed sessions the platform calls /cadc/startup.sh with no
# arguments; the session ID comes from the skaha_sessionid env var.
# The base_url is built dynamically as session/contrib/<session-id>.
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
# The Skaha platform calls /cadc/startup.sh with no arguments for contrib
# sessions. The base_url is derived from the skaha_sessionid env var.
# If called with $1 (notebook-type session), that takes precedence.
# hadolint ignore=SC2016
RUN printf '#!/bin/bash\nSESSION_ID="${1:-${skaha_sessionid}}"\nBASE_URL="session/contrib/${SESSION_ID}"\nmkdir -p "${HOME}/.local/bin" "${HOME}/.cache/uv" "${HOME}/.pixi" "${HOME}/.jupyter"\ncd "${HOME}"\nexec jupyter lab \\\n  --ServerApp.ip=0.0.0.0 \\\n  --ServerApp.port=8888 \\\n  --no-browser \\\n  --ServerApp.base_url="${BASE_URL}" \\\n  --ServerApp.root_dir=/ \\\n  --ServerApp.allow_origin="*" \\\n  --NotebookApp.base_url="${BASE_URL}" \\\n  --NotebookApp.notebook_dir=/ \\\n  --NotebookApp.allow_origin="*" \\\n  ${JUPYTERLAB_ARGS}\n' > /cadc/startup.sh \
    && chmod +x /cadc/startup.sh

EXPOSE 8888
WORKDIR /tmp
CMD ["/cadc/startup.sh"]
