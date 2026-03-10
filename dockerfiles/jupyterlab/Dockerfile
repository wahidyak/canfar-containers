# syntax=docker/dockerfile:1
#
# CANFAR JupyterLab Image (Layer 3: Browser-based Notebook)
#
# A sibling to webterm in the CANFAR container stack. Inherits from the
# terminal image and adds JupyterLab as the browser-facing service on
# port 5000 (the CANFAR Science Portal convention).
#
# Build chain: python:slim -> python -> terminal -> THIS IMAGE
#
# On the CANFAR Science Platform, this container is launched per-user.
# The startup script (/cadc/startup.sh) starts JupyterLab with no
# authentication (the platform handles auth externally). User home
# directories are persistent via CADC's volume mounts.

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

# --- Container Startup Script ---
# Launches JupyterLab on port 5000 with:
#   --no-browser: headless (CANFAR portal proxies the connection)
#   --ServerApp.token='': no auth (platform handles it externally)
#   --ServerApp.allow_origin='*': allow CANFAR portal iframe embedding
#   --notebook-dir: defaults to user's home directory
# hadolint ignore=SC2016
RUN printf "#!/bin/bash\n\
mkdir -p \"\${HOME}/.local/bin\" \"\${HOME}/.cache/uv\" \"\${HOME}/.pixi\" \"\${HOME}/.jupyter\"\n\
exec jupyter lab \
--ip=0.0.0.0 \
--port=5000 \
--no-browser \
--ServerApp.token='' \
--ServerApp.password='' \
--ServerApp.allow_origin='*' \
--ServerApp.base_url=\"\${JUPYTER_BASE_URL:-/}\" \
--notebook-dir=\"\${HOME}\"\n" > /cadc/startup.sh \
    && chmod +x /cadc/startup.sh

EXPOSE 5000
WORKDIR /tmp
CMD ["/cadc/startup.sh"]
