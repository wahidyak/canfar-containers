# syntax=docker/dockerfile:1
#
# CANFAR Python 3.12 Foundation Image
#
# This is Layer 1 of the CANFAR container stack. It takes the official Python
# slim image (Debian-based) and adds two modern package managers: uv and pixi.
# All downstream images (terminal, webterm) inherit from this layer.
#
# Build chain: python:slim (Docker Hub) -> THIS IMAGE -> terminal -> webterm
#
# Multi-stage strategy: pixi and uv are pulled as standalone images and their
# pre-compiled binaries are copied in, avoiding the need for build tools and
# keeping the final image small.

# --- Stage 1: Grab the pixi binary ---
# pixi is a conda-compatible package manager for scientific computing.
# renovate: datasource=docker depName=ghcr.io/prefix-dev/pixi versioning=semver
FROM ghcr.io/prefix-dev/pixi:0.58.0@sha256:70f606d7281b16705fa39a860fc645cbbf60be89c8691b2952159b5abee9af90 AS pixi

# --- Stage 2: Grab the uv binary ---
# uv is a fast Python package/project manager by Astral (replaces pip/venv).
# renovate: datasource=docker depName=ghcr.io/astral-sh/uv versioning=semver
FROM ghcr.io/astral-sh/uv:0.9.1@sha256:3b368e735c0227077902233a73c5ba17a3c2097ecdd83049cbaf2aa83adc8a20 AS uv

# --- Stage 3: Final runtime image ---
# The actual base: official Python 3.12 slim on Debian.
# The @sha256 digest pins the exact image for reproducibility; Renovate updates it.
# renovate: datasource=docker depName=python
FROM python:3.12-slim@sha256:9e01bf1ae5db7649a236da7be1e94ffbbbdd7a93f867dd0d8d5720d9e1f89fab AS base

# OCI standard metadata labels
LABEL org.opencontainers.image.title="CANFAR Python 3.12 Runtime" \
      org.opencontainers.image.description="Python 3.12 slim runtime for CANFAR Science Platform" \
      org.opencontainers.image.vendor="Canadian Astronomy Data Centre" \
      org.opencontainers.image.source="https://github.com/opencadc/canfar-containers" \
      org.opencontainers.image.licenses="AGPL-3.0-or-later"

# Use bash with pipefail: if any command in a pipe fails, the whole RUN fails
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Copy pre-built binaries from the multi-stage builds (no build tools needed)
COPY --from=pixi /usr/local/bin/pixi /usr/local/bin/pixi
COPY --from=uv /uv /usr/local/bin/uv
COPY --from=uv /uvx /usr/local/bin/uvx

# uv configuration: point all paths to system-wide locations so tools and
# Python installations are available to all users in the container
ENV UV_PYTHON_INSTALL_DIR=/usr/local/share/uv/python \
    UV_PYTHON_BIN_DIR=/usr/local/bin \
    UV_TOOL_DIR=/usr/local/share/uv/tools \
    UV_TOOL_BIN_DIR=/usr/local/bin

# pixi configuration: same approach — system-wide paths
ENV PIXI_HOME=/usr/local/share/pixi \
    PIXI_BIN_DIR=/usr/local/bin \
    PIXI_CACHE_DIR=/usr/local/share/pixi/cache

