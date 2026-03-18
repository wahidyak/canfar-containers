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
echo "[DEBUG-19e980] JUPYTER_SERVE_AT_ROOT=${JUPYTER_SERVE_AT_ROOT:-NOT_SET}"
echo "[DEBUG-19e980] will set base_url when SESSION_ID is set and JUPYTER_SERVE_AT_ROOT is not 1"
# #endregion

# When the reverse proxy strips the path (forwards GET / instead of GET /session/contrib/ID/),
# do not set base_url so Jupyter serves at / and those requests succeed. Set JUPYTER_SERVE_AT_ROOT=1
# in the session environment when the proxy strips the path.
BASE_URL_ARGS=""
if [ -n "${SESSION_ID}" ] && [ "${JUPYTER_SERVE_AT_ROOT:-0}" != "1" ]; then
  BASE_URL_ARGS="--ServerApp.base_url=/session/contrib/${SESSION_ID}/"
  echo "[DEBUG-19e980] BASE_URL_ARGS=${BASE_URL_ARGS}"
else
  echo "[DEBUG-19e980] BASE_URL_ARGS=(none, serving at root)"
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
