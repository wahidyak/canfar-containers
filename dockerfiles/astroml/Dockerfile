# syntax=docker/dockerfile:1
#
# AstroML Scientific Computing Images for CANFAR
#
# Single Dockerfile with three build stages for different hardware targets:
#   - astroml-cpu:  CPU-only (inherits from CANFAR Python image)
#   - astroml-cuda: NVIDIA GPU (inherits from nvidia/cuda base)
#   - astroml-rocm: AMD GPU (inherits from rocm base)
#
# Core scientific deps (numpy, scipy, astropy, scikit-learn, matplotlib) are
# installed via uv sync --frozen from the committed uv.lock for reproducibility.
# PyTorch is installed separately per-stage from hardware-specific wheel indexes.
#
# Build a specific variant:
#   docker build --target astroml-cpu  --build-arg PYTHON_VERSION=3.12 -t astroml:2026.3 .
#   docker build --target astroml-cuda --build-arg PYTHON_VERSION=3.12 -t astroml-cuda:2026.3 .
#   docker build --target astroml-rocm --build-arg PYTHON_VERSION=3.12 -t astroml-rocm:2026.3 .

ARG REGISTRY=images.canfar.net
ARG PYTHON_VERSION=3.12

# =============================================================================
# STAGE: CPU (inherits from CANFAR Python — uv and pixi already available)
# =============================================================================
FROM ${REGISTRY}/cadc/python:${PYTHON_VERSION} AS astroml-cpu

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
LABEL org.opencontainers.image.title="CANFAR AstroML (CPU)" \
      org.opencontainers.image.description="AstroML scientific computing environment — CPU variant" \
      org.opencontainers.image.vendor="Canadian Astronomy Data Centre" \
      org.opencontainers.image.source="https://github.com/opencadc/canfar-containers"

WORKDIR /app

# Install core scientific stack from lockfile
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev

ENV PATH="/app/.venv/bin:$PATH"

# =============================================================================
# STAGE: NVIDIA CUDA
# The nvidia/cuda base does not include Python or uv, so we install them.
# uv is copied from its official image (same multi-stage pattern as python/).
# =============================================================================

# renovate: datasource=docker depName=ghcr.io/astral-sh/uv versioning=semver
FROM ghcr.io/astral-sh/uv:0.9.1@sha256:3b368e735c0227077902233a73c5ba17a3c2097ecdd83049cbaf2aa83adc8a20 AS uv-bin

# renovate: datasource=docker depName=nvidia/cuda
FROM nvidia/cuda:12.6.3-runtime-ubuntu24.04 AS astroml-cuda

ARG PYTHON_VERSION
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
LABEL org.opencontainers.image.title="CANFAR AstroML (CUDA)" \
      org.opencontainers.image.description="AstroML scientific computing environment — NVIDIA CUDA variant" \
      org.opencontainers.image.vendor="Canadian Astronomy Data Centre" \
      org.opencontainers.image.source="https://github.com/opencadc/canfar-containers"

# Install Python and minimal system deps on the CUDA base
# We use the deadsnakes PPA to ensure availability of the requested Python version
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa -y \
    && apt-get update && apt-get install -y --no-install-recommends \
    python${PYTHON_VERSION} \
    python${PYTHON_VERSION}-venv \
    python${PYTHON_VERSION}-dev \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 \
    && ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python

# Copy uv binary from its official image
COPY --from=uv-bin /uv /usr/local/bin/uv
COPY --from=uv-bin /uvx /usr/local/bin/uvx

ENV UV_PYTHON_INSTALL_DIR=/usr/local/share/uv/python \
    UV_PYTHON_BIN_DIR=/usr/local/bin \
    UV_TOOL_DIR=/usr/local/share/uv/tools \
    UV_TOOL_BIN_DIR=/usr/local/bin \
    UV_PYTHON=/usr/bin/python${PYTHON_VERSION}

WORKDIR /app

# Install core scientific stack, then add PyTorch with CUDA support
COPY pyproject.toml uv.lock ./
ARG PYTORCH_VERSION=2.6.0
ARG TORCHVISION_VERSION=0.21.0
RUN uv sync --frozen --no-dev \
    && uv pip install --no-cache \
    torch==${PYTORCH_VERSION}+cu124 \
    torchvision==${TORCHVISION_VERSION}+cu124 \
    --index-url https://download.pytorch.org/whl/cu124

ENV PATH="/app/.venv/bin:$PATH"

# =============================================================================
# STAGE: AMD ROCm
# Same approach as CUDA — different vendor base image and wheel index.
# =============================================================================

# renovate: datasource=docker depName=rocm/dev-ubuntu-24.04
FROM rocm/dev-ubuntu-24.04:6.2.4-complete AS astroml-rocm

ARG PYTHON_VERSION
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
LABEL org.opencontainers.image.title="CANFAR AstroML (ROCm)" \
      org.opencontainers.image.description="AstroML scientific computing environment — AMD ROCm variant" \
      org.opencontainers.image.vendor="Canadian Astronomy Data Centre" \
      org.opencontainers.image.source="https://github.com/opencadc/canfar-containers"

# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa -y \
    && apt-get update && apt-get install -y --no-install-recommends \
    python${PYTHON_VERSION} \
    python${PYTHON_VERSION}-venv \
    python${PYTHON_VERSION}-dev \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 \
    && ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python

COPY --from=uv-bin /uv /usr/local/bin/uv
COPY --from=uv-bin /uvx /usr/local/bin/uvx

ENV UV_PYTHON_INSTALL_DIR=/usr/local/share/uv/python \
    UV_PYTHON_BIN_DIR=/usr/local/bin \
    UV_TOOL_DIR=/usr/local/share/uv/tools \
    UV_TOOL_BIN_DIR=/usr/local/bin \
    UV_PYTHON=/usr/bin/python${PYTHON_VERSION}

WORKDIR /app

# Install core scientific stack, then add PyTorch with ROCm support
COPY pyproject.toml uv.lock ./
ARG PYTORCH_VERSION=2.6.0
ARG TORCHVISION_VERSION=0.21.0
RUN uv sync --frozen --no-dev \
    && uv pip install --no-cache \
    torch==${PYTORCH_VERSION}+rocm6.2 \
    torchvision==${TORCHVISION_VERSION}+rocm6.2 \
    --index-url https://download.pytorch.org/whl/rocm6.2

ENV PATH="/app/.venv/bin:$PATH"

