# docker-bake.hcl — Docker Bake Build Configuration
#
# This file defines a multi-target build for the interactive CANFAR images
# (terminal + webterm). Run with: docker buildx bake
#
# Bake builds both targets in the correct dependency order and, critically,
# wires the webterm build to use the locally-built terminal image as its base
# (via the "contexts" block) instead of pulling from the remote registry.
# This ensures the entire stack is built atomically from source.
#
# Usage:
#   docker buildx bake                    # Build terminal and webterm (default)
#   docker buildx bake terminal           # Build terminal only
#   docker buildx bake astroml            # Build all AstroML variants (CPU/CUDA/ROCm)
#   docker buildx bake astroml-cpu        # Build AstroML CPU only
#   RELEASE_TAG=26.03 docker buildx bake  # Override the release tag

# Registry where images are hosted (CANFAR's Harbor instance)
variable "REGISTRY" {
  default = "images.canfar.net"
}

# Release tag applied to terminal and webterm images (YY.MM format)
variable "RELEASE_TAG" {
  default = "26.02"
}

# Release tag for AstroML images (YYYY.minor format)
variable "ASTROML_TAG" {
  default = "2026.3"
}

# Default group: building with no target specified builds both
group "default" {
  targets = ["terminal", "webterm"]
}

# Terminal image: interactive CLI environment built on Python 3.12
target "terminal" {
  context = "./dockerfiles/terminal"
  tags = ["${REGISTRY}/cadc/terminal:${RELEASE_TAG}"]
  args = {
    REGISTRY = "${REGISTRY}"
    PYTHON_VERSION = "3.12"
  }
}

# Webterm image: web-based terminal built on top of terminal.
# The "contexts" block overrides the FROM reference so that when the webterm
# Dockerfile pulls "images.canfar.net/cadc/terminal:26.02", Bake substitutes
# the locally-built terminal target. This avoids needing to push terminal
# to the registry before building webterm.
target "webterm" {
  context = "./dockerfiles/webterm"
  contexts = {
    "${REGISTRY}/cadc/terminal:${RELEASE_TAG}" = "target:terminal"
  }
  tags = ["${REGISTRY}/cadc/webterm:${RELEASE_TAG}"]
  args = {
    REGISTRY = "${REGISTRY}"
    BASE_TAG = "${RELEASE_TAG}"
  }
}

# =============================================================================
# AstroML Scientific Computing Images
#
# Three hardware variants built from the same Dockerfile using --target.
# The "astroml" group builds all three; individual targets can be built alone.
# These are NOT in the default group — GPU images are heavy and need explicit
# opt-in (and may require special CI runners).
# =============================================================================

group "astroml" {
  targets = ["astroml-cpu", "astroml-cuda", "astroml-rocm"]
}

# CPU variant: inherits from the CANFAR Python image (uv/pixi included)
target "astroml-cpu" {
  context = "./dockerfiles/astroml"
  target  = "astroml-cpu"
  tags    = ["${REGISTRY}/cadc/astroml:${ASTROML_TAG}"]
  args = {
    REGISTRY = "${REGISTRY}"
    PYTHON_VERSION = "3.12"
  }
}

# NVIDIA CUDA variant: built from nvidia/cuda base with PyTorch CUDA wheels
target "astroml-cuda" {
  context = "./dockerfiles/astroml"
  target  = "astroml-cuda"
  tags    = ["${REGISTRY}/cadc/astroml-cuda:${ASTROML_TAG}"]
  args = {
    REGISTRY = "${REGISTRY}"
    PYTHON_VERSION = "3.12"
  }
}

# AMD ROCm variant: built from rocm base with PyTorch ROCm wheels
target "astroml-rocm" {
  context = "./dockerfiles/astroml"
  target  = "astroml-rocm"
  tags    = ["${REGISTRY}/cadc/astroml-rocm:${ASTROML_TAG}"]
  args = {
    REGISTRY = "${REGISTRY}"
    PYTHON_VERSION = "3.12"
  }
}
