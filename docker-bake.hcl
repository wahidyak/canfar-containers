variable "REGISTRY" {
  default = "images.canfar.net"
}

variable "RELEASE_TAG" {
  default = "26.02"
}

group "default" {
  targets = ["terminal", "webterm"]
}

target "terminal" {
  context = "./dockerfiles/terminal"
  tags = ["${REGISTRY}/cadc/terminal:${RELEASE_TAG}"]
  args = {
    REGISTRY = "${REGISTRY}"
    PYTHON_VERSION = "3.12"
  }
}

target "webterm" {
  context = "./dockerfiles/webterm"
  # This tells bake to use the local 'terminal' target as the base image
  contexts = {
    "${REGISTRY}/cadc/terminal:${RELEASE_TAG}" = "target:terminal"
  }
  tags = ["${REGISTRY}/cadc/webterm:${RELEASE_TAG}"]
  args = {
    REGISTRY = "${REGISTRY}"
    BASE_TAG = "${RELEASE_TAG}"
  }
}
