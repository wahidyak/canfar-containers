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

# /cadc is the CANFAR platform convention for platform-managed scripts
RUN mkdir -p /cadc

# --- Pinned APT Package Versions ---
# renovate: datasource=repology depName=debian_trixie/unzip versioning=deb
ARG UNZIP_VERSION=6.0-29
# renovate: datasource=repology depName=debian_trixie/jq versioning=deb
ARG JQ_VERSION=1.7.1-6+deb13u1
# renovate: datasource=repology depName=debian_trixie/libatomic1 versioning=deb
ARG LIBATOMIC1_VERSION=14.2.0-19

RUN apt-get update && apt-get install -y --no-install-recommends \
    unzip=${UNZIP_VERSION} \
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

# --- VS Code Extensions for CANFAR Users ---
# Pre-install extensions useful for astronomy/data science workflows.
# Extensions are installed to a system-wide location.
ENV OPENVSCODE_SERVER_ROOT=/opt/openvscode-server
RUN /opt/openvscode-server/bin/openvscode-server --install-extension ms-python.python \
    && /opt/openvscode-server/bin/openvscode-server --install-extension ms-toolsai.jupyter \
    && /opt/openvscode-server/bin/openvscode-server --install-extension charliermarsh.ruff \
    && /opt/openvscode-server/bin/openvscode-server --install-extension eamodio.gitlens \
    && /opt/openvscode-server/bin/openvscode-server --install-extension mhutchie.git-graph \
    && /opt/openvscode-server/bin/openvscode-server --install-extension redhat.vscode-yaml \
    && /opt/openvscode-server/bin/openvscode-server --install-extension tamasfe.even-better-toml

# --- Cursor CLI Agent ---
# Cursor's AI terminal assistant for use in the integrated terminal.
# Installed via its official script, then moved to a system-wide path.
RUN curl https://cursor.com/install -fsS | bash \
    && mv /root/.local/share/cursor-agent /usr/local/share/cursor-agent \
    && ln -sf "/usr/local/share/cursor-agent/versions/$(find /usr/local/share/cursor-agent/versions -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | head -n 1)/cursor-agent" /usr/local/bin/agent \
    && chmod +x /usr/local/bin/agent \
    && rm -rf /root/.local

# --- Continue Extension (In-editor AI) ---
# Open-source AI coding assistant that works with multiple LLM providers.
RUN /opt/openvscode-server/bin/openvscode-server --install-extension continue.continue

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
