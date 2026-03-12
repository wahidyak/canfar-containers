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
# For contributed sessions the platform calls /cadc/startup.sh. The proxy
# strips the path prefix before forwarding, so JupyterLab serves from root.
# Authentication is handled externally by the platform.

ARG REGISTRY=images.canfar.net
ARG BASE_TAG=local

FROM ${REGISTRY}/cadc/terminal:${BASE_TAG}
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
LABEL description="CANFAR JupyterLab Notebook Environment" \
      org.opencontainers.image.version="26.03"

# /cadc is the CANFAR platform convention for platform-managed scripts
RUN mkdir -p /cadc

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

# --- Startup Script ---
# The CANFAR proxy strips the path prefix before forwarding to JupyterLab.
# JupyterLab redirects / to /lab, but the browser needs the full session path.
# We run JupyterLab on internal port 8888, and use a Python proxy on 5000 that
# rewrites Location headers to include the session path prefix.
# hadolint ignore=SC2016
RUN printf '#!/bin/bash -e\nset -e\n\necho "[JupyterLab] Starting JupyterLab server..."\n\nmkdir -p "${HOME}/.local/bin" "${HOME}/.cache/uv" "${HOME}/.pixi" "${HOME}/.jupyter"\ncd "${HOME}"\n\n# Start JupyterLab on internal port\njupyter lab \\\n  --ServerApp.ip=127.0.0.1 \\\n  --ServerApp.port=8888 \\\n  --no-browser \\\n  --ServerApp.root_dir=/ \\\n  --ServerApp.allow_origin="*" \\\n  --ServerApp.token="" \\\n  --ServerApp.password="" \\\n  '"'"'--ServerApp.terminado_settings={"shell_command": ["/bin/bash", "-l"]}'"'"' \\\n  ${JUPYTERLAB_ARGS} &\n\nJUPYTER_PID=$!\nsleep 2\n\n# On CANFAR, run a proxy that rewrites redirect Location headers\nif [ -n "${skaha_sessionid:-}" ]; then\n  echo "[JupyterLab] Starting redirect proxy for session ${skaha_sessionid}"\n  python3 /cadc/redirect-proxy.py 5000 8888 "/session/contrib/${skaha_sessionid}" &\n  PROXY_PID=$!\n  wait $JUPYTER_PID $PROXY_PID\nelse\n  # Locally, just forward directly (socat)\n  echo "[JupyterLab] Running locally, forwarding 5000 to 8888"\n  socat TCP-LISTEN:5000,fork,reuseaddr TCP:127.0.0.1:8888 &\n  wait $JUPYTER_PID\nfi\n' > /cadc/startup.sh \
    && chmod +x /cadc/startup.sh

# --- Redirect Proxy Script ---
# A minimal Python proxy that rewrites Location headers in redirect responses.
# This fixes the issue where JupyterLab redirects to /lab but the browser needs
# /session/contrib/<session-id>/lab.
RUN printf 'import sys\nimport socket\nimport threading\n\ndef handle_client(client, upstream_port, prefix):\n    try:\n        upstream = socket.socket(socket.AF_INET, socket.SOCK_STREAM)\n        upstream.connect(("127.0.0.1", upstream_port))\n        \n        def forward(src, dst, rewrite=False):\n            try:\n                while True:\n                    data = src.recv(65536)\n                    if not data:\n                        break\n                    if rewrite and b"Location: /" in data:\n                        data = data.replace(b"Location: /", f"Location: {prefix}/".encode())\n                    dst.sendall(data)\n            except: pass\n            finally:\n                try: src.close()\n                except: pass\n                try: dst.close()\n                except: pass\n        \n        t1 = threading.Thread(target=forward, args=(client, upstream, False))\n        t2 = threading.Thread(target=forward, args=(upstream, client, True))\n        t1.start()\n        t2.start()\n        t1.join()\n        t2.join()\n    except Exception as e:\n        print(f"Error: {e}")\n\nif __name__ == "__main__":\n    listen_port = int(sys.argv[1])\n    upstream_port = int(sys.argv[2])\n    prefix = sys.argv[3]\n    \n    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)\n    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)\n    server.bind(("0.0.0.0", listen_port))\n    server.listen(100)\n    print(f"Redirect proxy listening on {listen_port}, forwarding to {upstream_port}")\n    \n    while True:\n        client, addr = server.accept()\n        threading.Thread(target=handle_client, args=(client, upstream_port, prefix)).start()\n' > /cadc/redirect-proxy.py

# Install socat for local testing (when no session ID is present)
RUN apt-get update && apt-get install -y --no-install-recommends socat \
    && rm -rf /var/lib/apt/lists/*

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
