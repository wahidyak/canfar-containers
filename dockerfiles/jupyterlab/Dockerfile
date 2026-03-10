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
# The Skaha platform calls /skaha-system/start-jupyterlab.sh with the
# session ID as $1 and expects JupyterLab on port 8888. Authentication
# is handled externally by the platform. User home directories are
# persistent via CADC's volume mounts.

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

# --- Startup Scripts ---
# /cadc/startup.sh: our own entrypoint following the CANFAR convention.
# /skaha-system/start-jupyterlab.sh: the path the Skaha platform expects
#   for notebook sessions. It receives the session ID as $1 and launches
#   JupyterLab on port 8888 with the correct base_url for proxy routing.
# hadolint ignore=SC2016
RUN printf '#!/bin/bash\nmkdir -p "${HOME}/.local/bin" "${HOME}/.cache/uv" "${HOME}/.pixi" "${HOME}/.jupyter"\ncd "${HOME}"\njupyter lab \\\n  --NotebookApp.base_url=session/notebook/"$1" \\\n  --NotebookApp.notebook_dir=/ \\\n  --NotebookApp.allow_origin="*" \\\n  --ServerApp.ip=0.0.0.0 \\\n  --ServerApp.port=8888 \\\n  --no-browser \\\n  --ServerApp.base_url=session/notebook/"$1" \\\n  --ServerApp.root_dir=/ \\\n  --ServerApp.allow_origin="*" \\\n  ${JUPYTERLAB_ARGS}\n' > /cadc/startup.sh \
    && chmod +x /cadc/startup.sh \
    && mkdir -p /skaha-system \
    && ln -s /cadc/startup.sh /skaha-system/start-jupyterlab.sh

EXPOSE 8888
WORKDIR /tmp
CMD ["/cadc/startup.sh"]
