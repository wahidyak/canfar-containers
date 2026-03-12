# docker-bake.hcl — Docker Bake Build Configuration
#
# This file defines a multi-target build for the interactive CANFAR images
# (terminal, webterm, jupyter-notebook, vscode). Run with: docker buildx bake
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

# Release tag applied to all interactive images (YY.MM format)
variable "RELEASE_TAG" {
  default = "local"
}

# Default group: building with no target specified builds all interactive images
group "default" {
  targets = ["terminal", "webterm", "jupyter-notebook", "vscode"]
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

# Jupyter Notebook image: browser-based notebook environment built on top of terminal.
target "jupyter-notebook" {
  context = "./dockerfiles/jupyterlab"
  contexts = {
    "${REGISTRY}/cadc/terminal:${RELEASE_TAG}" = "target:terminal"
  }
  tags = ["${REGISTRY}/cadc/jupyter-notebook:${RELEASE_TAG}"]
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
