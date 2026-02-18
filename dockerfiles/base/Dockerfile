# syntax=docker/dockerfile:1

# renovate: datasource=docker depName=ghcr.io/prefix-dev/pixi versioning=semver
FROM ghcr.io/prefix-dev/pixi:0.58.0@sha256:70f606d7281b16705fa39a860fc645cbbf60be89c8691b2952159b5abee9af90 AS pixi

# renovate: datasource=docker depName=ghcr.io/astral-sh/uv versioning=semver
FROM ghcr.io/astral-sh/uv:0.9.1@sha256:3b368e735c0227077902233a73c5ba17a3c2097ecdd83049cbaf2aa83adc8a20 AS uv

# renovate: datasource=docker depName=ubuntu
FROM ubuntu:24.04@sha256:cd1dba651b3080c3686ecf4e3c4220f026b521fb76978881737d24f200828b2b AS runtime

LABEL org.opencontainers.image.title="CANFAR Base Runtime" \
      org.opencontainers.image.description="Minimal Ubuntu 24.04 runtime for CANFAR Science Platform" \
      org.opencontainers.image.vendor="Canadian Astronomy Data Centre" \
      org.opencontainers.image.source="https://github.com/opencadc/canfar-containers" \
      org.opencontainers.image.licenses="AGPL-3.0-or-later"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root
WORKDIR /tmp

# Environment Settings
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    TERM=xterm-256color

# System Foundation
RUN apt-get update --yes --quiet --fix-missing \
    && apt-get install --yes --quiet --no-install-recommends \
        ca-certificates=20240203 \
        curl=8.5.0-2ubuntu10.6 \
        locales=2.39-0ubuntu8.7 \
    && apt-get clean --yes \
    && rm -rf /var/lib/apt/lists/* /var/tmp/* \
    && locale-gen en_US.UTF-8

# Copy binaries from build stages
COPY --from=pixi /usr/local/bin/pixi /usr/local/bin/pixi
COPY --from=uv /uv /usr/local/bin/uv
COPY --from=uv /uvx /usr/local/bin/uvx

# UV System Configuration (System-wide)
ENV UV_PYTHON_INSTALL_DIR=/usr/local/share/uv/python \
    UV_PYTHON_BIN_DIR=/usr/local/bin \
    UV_TOOL_DIR=/usr/local/share/uv/tools \
    UV_TOOL_BIN_DIR=/usr/local/bin

# Pixi System Configuration (System-wide)
ENV PIXI_HOME=/usr/local/share/pixi \
    PIXI_BIN_DIR=/usr/local/bin \
    PIXI_CACHE_DIR=/usr/local/share/pixi/cache
