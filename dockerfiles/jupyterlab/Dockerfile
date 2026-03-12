# syntax=docker/dockerfile:1
#
# CANFAR JupyterLab Image (Layer 3: Browser-based Notebook)
#
# A sibling to webterm in the CANFAR container stack. Inherits from the
# terminal image and adds JupyterLab as the browser-facing service on
# port 5000 (the CANFAR contributed session convention).
#
# Build chain: python:slim -> python -> terminal -> THIS IMAGE
#
# On the CANFAR Science Platform, this container is launched per-user.
# For contributed sessions the platform calls /cadc/startup.sh.
#
# PROXY BEHAVIOR: The CANFAR proxy STRIPS the session path before forwarding.
# Browser requests /session/contrib/<id>/... → container receives /...
# We use nginx to rewrite response URLs to include the session prefix.
# Authentication is handled externally by the platform.

ARG REGISTRY=images.canfar.net
ARG BASE_TAG=local

FROM ${REGISTRY}/cadc/terminal:${BASE_TAG}
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
LABEL description="CANFAR JupyterLab Notebook Environment" \
      org.opencontainers.image.version="26.03"

# /cadc is the CANFAR platform convention for platform-managed scripts
RUN mkdir -p /cadc

# --- nginx for URL rewriting ---
# The CANFAR proxy strips the session path, so we need nginx to:
# 1. Accept requests at / (what the proxy sends)
# 2. Proxy to JupyterLab (serving at /)
# 3. Rewrite Location headers and HTML content to include session prefix
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/lib/nginx/body /var/lib/nginx/proxy /var/lib/nginx/fastcgi /var/lib/nginx/scgi /var/lib/nginx/uwsgi \
    && chmod -R 777 /var/lib/nginx /var/log/nginx

# --- JupyterLab + Extensions ---
# Installed via uv (inherited from the python layer) into the system Python.
# renovate: datasource=pypi depName=jupyterlab
ARG JUPYTERLAB_VERSION=4.5.5
# renovate: datasource=pypi depName=notebook
ARG NOTEBOOK_VERSION=7.5.4
# renovate: datasource=pypi depName=jupyterlab-git
ARG JUPYTERLAB_GIT_VERSION=0.52.0
# renovate: datasource=pypi depName=ipywidgets
ARG IPYWIDGETS_VERSION=8.1.8
RUN uv pip install --system \
    jupyterlab==${JUPYTERLAB_VERSION} \
    notebook==${NOTEBOOK_VERSION} \
    jupyterlab-git==${JUPYTERLAB_GIT_VERSION} \
    ipywidgets==${IPYWIDGETS_VERSION}

# --- nginx configuration template ---
# This template is filled in at runtime with the session ID
# hadolint ignore=SC2016
RUN printf 'worker_processes 1;\nerror_log /dev/stderr info;\npid /tmp/nginx.pid;\n\nevents {\n    worker_connections 1024;\n}\n\nhttp {\n    include /etc/nginx/mime.types;\n    default_type application/octet-stream;\n    access_log /dev/stdout;\n    \n    # Required for sub_filter to work on all content types\n    proxy_buffering on;\n    \n    server {\n        listen 5000;\n        server_name _;\n        \n        # WebSocket support for JupyterLab terminals/kernels\n        location / {\n            proxy_pass http://127.0.0.1:8888;\n            proxy_http_version 1.1;\n            proxy_set_header Upgrade $http_upgrade;\n            proxy_set_header Connection "upgrade";\n            proxy_set_header Host $host;\n            proxy_set_header X-Real-IP $remote_addr;\n            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n            proxy_set_header X-Forwarded-Proto $scheme;\n            \n            # Rewrite Location headers for redirects\n            proxy_redirect / SESSION_PREFIX/;\n            proxy_redirect /lab SESSION_PREFIX/lab;\n            \n            # Rewrite URLs in HTML/JS responses\n            sub_filter_once off;\n            sub_filter_types application/javascript application/json;\n            sub_filter '\''href=\"/'\'' '\''href=\"SESSION_PREFIX/'\'';\n            sub_filter '\''src=\"/'\'' '\''src=\"SESSION_PREFIX/'\'';\n            sub_filter '\''action=\"/'\'' '\''action=\"SESSION_PREFIX/'\'';\n            sub_filter '\''\"/static/'\'' '\''\"SESSION_PREFIX/static/'\'';\n            sub_filter '\''\"/api/'\'' '\''\"SESSION_PREFIX/api/'\'';\n            sub_filter '\''\"/lab'\'' '\''\"SESSION_PREFIX/lab'\'';\n            sub_filter '\''url(/'\'' '\''url(SESSION_PREFIX/'\'';\n        }\n    }\n}\n' > /etc/nginx/nginx.conf.template

# --- Startup Script ---
# On CANFAR, runs nginx on port 5000 proxying to JupyterLab on 8888.
# nginx rewrites all URLs in responses to include the session prefix.
# hadolint ignore=SC2016
RUN printf '#!/bin/bash -e\nset -e\n\necho "[JupyterLab] Starting JupyterLab server..."\necho "[DEBUG-H1] Checking environment: skaha_sessionid=${skaha_sessionid:-NOT_SET}"\n\nmkdir -p "${HOME}/.local/bin" "${HOME}/.cache/uv" "${HOME}/.pixi" "${HOME}/.jupyter"\ncd "${HOME}"\n\nif [ -n "${skaha_sessionid:-}" ]; then\n  SESSION_PREFIX="/session/contrib/${skaha_sessionid}"\n  echo "[DEBUG-H2] CANFAR mode: using nginx proxy with prefix ${SESSION_PREFIX}"\n  \n  # Generate nginx config with session prefix\n  sed "s|SESSION_PREFIX|${SESSION_PREFIX}|g" /etc/nginx/nginx.conf.template > /tmp/nginx.conf\n  echo "[DEBUG-H3] Generated nginx config, starting nginx..."\n  \n  # Start JupyterLab on internal port 8888 (no base_url needed, nginx handles it)\n  jupyter lab \\\n    --ServerApp.ip=127.0.0.1 \\\n    --ServerApp.port=8888 \\\n    --no-browser \\\n    --ServerApp.root_dir=/ \\\n    --ServerApp.allow_origin="*" \\\n    --ServerApp.allow_remote_access=True \\\n    --ServerApp.token="" \\\n    --ServerApp.password="" \\\n    --ServerApp.disable_check_xsrf=True \\\n    '"'"'--ServerApp.terminado_settings={"shell_command": ["/bin/bash", "-l"]}'"'"' \\\n    ${JUPYTERLAB_ARGS} &\n  JUPYTER_PID=$!\n  \n  echo "[DEBUG-H4] JupyterLab started with PID ${JUPYTER_PID}, waiting for it to be ready..."\n  sleep 3\n  \n  # Start nginx on port 5000\n  echo "[DEBUG-H5] Starting nginx on port 5000..."\n  nginx -c /tmp/nginx.conf -g "daemon off;" &\n  NGINX_PID=$!\n  \n  echo "[DEBUG-H6] nginx started with PID ${NGINX_PID}"\n  \n  # Wait for either process to exit\n  wait -n $JUPYTER_PID $NGINX_PID\n  echo "[DEBUG-H7] A process exited, shutting down..."\n  kill $JUPYTER_PID $NGINX_PID 2>/dev/null || true\nelse\n  echo "[DEBUG-H8] Local mode: running JupyterLab directly on port 5000"\n  # Local mode: run JupyterLab directly\n  exec jupyter lab \\\n    --ServerApp.ip=0.0.0.0 \\\n    --ServerApp.port=5000 \\\n    --no-browser \\\n    --ServerApp.root_dir=/ \\\n    --ServerApp.allow_origin="*" \\\n    --ServerApp.allow_remote_access=True \\\n    --ServerApp.token="" \\\n    --ServerApp.password="" \\\n    '"'"'--ServerApp.terminado_settings={"shell_command": ["/bin/bash", "-l"]}'"'"' \\\n    ${JUPYTERLAB_ARGS}\nfi\n' > /cadc/startup.sh \
    && chmod +x /cadc/startup.sh

# --- JupyterLab Terminal Theme (Gruvbox) ---
# Configure the terminal to match the webterm Gruvbox dark theme.
# This creates system-wide JupyterLab settings that apply to all users.
RUN mkdir -p /usr/local/share/jupyter/lab/settings \
    && printf '{\n  "@jupyterlab/terminal-extension:plugin": {\n    "theme": "dark",\n    "fontFamily": "monospace",\n    "fontSize": 14\n  }\n}\n' > /usr/local/share/jupyter/lab/settings/overrides.json

# Create a non-root user for running JupyterLab locally.
# On CANFAR, the platform overrides the user at runtime.
RUN useradd -m -s /bin/bash -u 1000 jupyter

EXPOSE 5000
WORKDIR /tmp
USER jupyter
ENTRYPOINT ["/bin/bash", "-e", "/cadc/startup.sh"]
