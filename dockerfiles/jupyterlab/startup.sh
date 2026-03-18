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
# #region agent log
echo "[DEBUG-19e980] skaha_sessionid=${skaha_sessionid:-NOT_SET}"
echo "[DEBUG-19e980] SESSION_ID=${SESSION_ID:-NOT_SET}"
echo "[DEBUG-19e980] will set base_url when SESSION_ID is set"
# #endregion

BASE_URL_ARGS=""
if [ -n "${SESSION_ID}" ]; then
  BASE_URL_ARGS="--ServerApp.base_url=/session/contrib/${SESSION_ID}/"
  echo "[DEBUG-19e980] BASE_URL_ARGS=${BASE_URL_ARGS}"
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
