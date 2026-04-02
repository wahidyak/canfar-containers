#!/bin/bash -e
set -e

echo "[JupyterLab] Starting JupyterLab server..."

# Ensure HOME exists and create persistence dirs (CANFAR .local, .cache, .pixi; .token for compatibility)
mkdir -p "${HOME:-/root}" \
  "${HOME:-/root}/.token" \
  "${HOME:-/root}/.local/bin" \
  "${HOME:-/root}/.cache/uv" \
  "${HOME:-/root}/.pixi"
cd "${HOME:-/root}"

# Session ID: from env (skaha_sessionid) or first argument (fallback for alternate launchers)
SESSION_ID="${skaha_sessionid:-$1}"

# CANFAR's proxy strips the path (forwards GET / not GET /session/contrib/ID/), so default to
# serving at root so / and /static/... succeed. Set JUPYTER_USE_BASE_URL=1 only when your proxy
# forwards the full path to the container.
BASE_URL_ARGS=""
if [ -n "${SESSION_ID}" ] && [ "${JUPYTER_USE_BASE_URL:-0}" = "1" ]; then
  BASE_URL_ARGS="--ServerApp.base_url=/session/contrib/${SESSION_ID}/"
fi

exec jupyter lab \
  --ServerApp.ip=0.0.0 \
  --ServerApp.port=5000 \
  --no-browser \
  --ServerApp.root_dir=/ \
  --ServerApp.allow_origin="*" \
  --ServerApp.allow_remote_access=True \
  --ServerApp.token="" \
  --ServerApp.password="" \
  --ServerApp.disable_check_xsrf=True \
  --ServerApp.log_level=DEBUG \
  '--ServerApp.terminado_settings={"shell_command": ["/bin/bash", "-l"]}' \
  ${BASE_URL_ARGS} \
  ${JUPYTERLAB_ARGS}
