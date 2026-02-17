# Layer 4: Web Terminal (ttyd)
FROM images.canfar.net/cadc/terminal:26.02

LABEL description="CANFAR Web-based Terminal Environment"

# Install ttyd
RUN apt-get update && apt-get install -y --no-install-recommends \
    ttyd=1.7.4-1build2 \
    && rm -rf /var/lib/apt/lists/*

# Startup Script (Modified for CADC home directory persistence)
RUN mkdir -p /cadc \
    && printf '#!/bin/bash\n# Ensure persistent directories exist\nmkdir -p "${HOME}/.conda/envs" "${HOME}/.conda/pkgs" "${HOME}/.local/bin" "${HOME}/.cache/uv" "${HOME}/.pixi"\nttyd --writable --port 5000 -w "${HOME}" -t titleFixed="CANFAR Webterm" /bin/bash -l\n' > /cadc/startup.sh \
    && chmod +x /cadc/startup.sh

EXPOSE 5000
WORKDIR /root
CMD ["/cadc/startup.sh"]
