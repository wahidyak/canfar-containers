# docker-bake.hcl — Docker Bake Build Configuration for CANFAR
#
# This file defines a multi-target build for the interactive CANFAR images
# (terminal, webterm, vscode, marimo, carta, carta-psrecord). Run with:
# docker buildx bake
#
# Bake builds all targets in the correct dependency order and, critically,
# wires downstream images to use the locally-built terminal image as their base
# (via the "contexts" block) instead of pulling from the remote registry.
# This ensures the entire stack is built atomically from source.
#
# Usage:
#   docker buildx bake                    # Build all interactive images (default)
#   docker buildx bake terminal           # Build terminal only
#   RELEASE_TAG=26.03 docker buildx bake  # Override the release tag

# Registry where images are hosted (CANFAR's Harbor instance)
variable "REGISTRY" {
  default = "images.canfar.net"
}

# Release tag applied to the Debian-based interactive images (YY.MM format).
# NOTE: CARTA uses its own CARTA_TAG variable (upstream version) and does NOT
# use RELEASE_TAG -- see the `carta` target below.
variable "RELEASE_TAG" {
  default = "local"
}

# CARTA tag = upstream CARTA version (e.g. "5.1.0"), deliberately decoupled
# from RELEASE_TAG so CARTA's tag tracks the upstream CARTA release rather
# than the month of our build. Shared between the `carta` and `carta-psrecord`
# targets (they always track the same upstream CARTA version). CI derives
# this from carta's Dockerfile CARTA_VERSION arg (stripping the ~noble1
# PPA-rebuild suffix). If invoked without an override the default "local"
# tag makes local builds obvious.
variable "CARTA_TAG" {
  default = "local"
}

# Default group: building with no target specified builds all interactive images
group "default" {
  targets = ["terminal", "webterm", "vscode", "marimo", "carta", "carta-psrecord"]
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

# VS Code image: browser-based VS Code IDE built on top of terminal.
target "vscode" {
  context = "./dockerfiles/openvscode"
  contexts = {
    "${REGISTRY}/cadc/terminal:${RELEASE_TAG}" = "target:terminal"
  }
  tags = ["${REGISTRY}/cadc/vscode:${RELEASE_TAG}"]
  args = {
    REGISTRY = "${REGISTRY}"
    BASE_TAG = "${RELEASE_TAG}"
  }
}

# Marimo image: browser-based reactive notebooks built on top of terminal.
target "marimo" {
  context = "./dockerfiles/marimo"
  contexts = {
    "${REGISTRY}/cadc/terminal:${RELEASE_TAG}" = "target:terminal"
  }
  tags = ["${REGISTRY}/cadc/marimo:${RELEASE_TAG}"]
  args = {
    REGISTRY = "${REGISTRY}"
    BASE_TAG = "${RELEASE_TAG}"
  }
}

# CARTA image: Cube Analysis and Rendering Tool for Astronomy, launched by
# Skaha as a first-class "carta" session type. Standalone -- does NOT inherit
# from terminal because CARTA is distributed only via the cartavis-team PPA
# for Ubuntu (no Debian build), while terminal is Debian-based.
#
# Tagging: CARTA uses the upstream CARTA version (e.g. "5.1.0") rather than
# the monthly RELEASE_TAG, so the tag reflects what astronomers actually
# install. CI derives CARTA_TAG from the Dockerfile's CARTA_VERSION arg
# (stripping the "~noble1" PPA-rebuild suffix). See the workflow's
# "Derive CARTA tag" step and doc/HANDOFF.md §3 for the full flow.
target "carta" {
  context = "./dockerfiles/carta"
  tags = ["${REGISTRY}/cadc/carta:${CARTA_TAG}"]
  args = {
    REGISTRY = "${REGISTRY}"
  }
}

# CARTA-psrecord image: diagnostic sibling of `carta`. Same CARTA binary and
# Skaha session contract, but wraps `carta` under `psrecord` so each session
# emits a CPU/memory/IO timeline of the CARTA backend. Shares CARTA_TAG with
# the `carta` target so both images re-tag together on each CARTA bump.
target "carta-psrecord" {
  context = "./dockerfiles/carta-psrecord"
  tags = ["${REGISTRY}/cadc/carta-psrecord:${CARTA_TAG}"]
  args = {
    REGISTRY = "${REGISTRY}"
  }
}
