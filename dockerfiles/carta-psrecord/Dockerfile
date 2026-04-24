# syntax=docker/dockerfile:1
#
# CANFAR CARTA-psrecord Image (Diagnostic Sibling of cadc/carta)
#
# Same CARTA binary and same Skaha "carta" session contract as cadc/carta,
# but the `carta` process runs under `psrecord` (a psutil-based process
# sampler). Each session emits a CPU %, RSS, I/O, and child-process
# timeline of the CARTA backend under $HOME/.carta_logs/, useful for
# diagnosing slow / OOMing / thrashing sessions.
#
# NOT a replacement for cadc/carta -- point the carta session type at this
# image only when actively investigating a performance issue, then switch
# back. The wrapper adds non-trivial overhead (1-second psutil sampling
# with --include-io --include-children).
#
# Because psrecord wraps carta, carta is no longer PID 1; Skaha's CMD
# override therefore lands on /carta/start.sh, and start.sh has to
# re-specify the flags Skaha would otherwise pass directly to carta. This
# is inherent to the "wrap with profiler" pattern and means this image
# has a tight coupling to Skaha's env-var contract
# (SKAHA_TOP_LEVEL_DIR / SKAHA_PROJECTS_DIR / SKAHA_SESSION_URL_PATH)
# that the plain cadc/carta image does not.
#
# Upstream reference:
#   opencadc/science-containers/Dockerfiles/carta-psrecord

# renovate: datasource=docker depName=ubuntu
ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION}@sha256:c4a8d5503dfb2a3eb8ab5f807da5bc69a85730fb49b5cfca2330194ebcc41c7b

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# CARTA version pinned against the PPA's Packages index. Kept in sync with
# cadc/carta's pin -- Renovate opens one PR per CARTA bump covering both
# Dockerfiles because the # renovate: annotation is the same.
# renovate: datasource=deb depName=carta registryUrl=https://ppa.launchpadcontent.net/cartavis-team/carta/ubuntu?suite=noble&components=main&binaryArch=amd64 versioning=deb
ARG CARTA_VERSION=5.1.0~noble1

# Install CARTA + Python/pip (psrecord is a pip package; no Debian package
# exists). python3-pip is kept in the final image because psrecord imports
# psutil and matplotlib at runtime.
# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        software-properties-common \
        python3-pip && \
    add-apt-repository -y ppa:cartavis-team/carta && \
    apt-get update && \
    apt-get install -y --no-install-recommends "carta=${CARTA_VERSION}" && \
    apt-get purge -y --auto-remove software-properties-common && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/tmp/*

# psrecord + matplotlib pinned via PyPI so Renovate opens bump PRs, matching
# the pinning discipline of the rest of the repo (see marimo's MARIMO_VERSION).
# --break-system-packages is required on Ubuntu 24.04 (PEP 668): the system
# Python is marked externally-managed. Acceptable here because this is a
# single-purpose image with no other Python consumers to conflict with.
# renovate: datasource=pypi depName=psrecord
ARG PSRECORD_VERSION=1.4
# renovate: datasource=pypi depName=matplotlib
ARG MATPLOTLIB_VERSION=3.10.9
# hadolint ignore=DL3013
RUN pip3 install --no-cache-dir --break-system-packages \
        "psrecord==${PSRECORD_VERSION}" \
        "matplotlib==${MATPLOTLIB_VERSION}"

WORKDIR /carta
RUN chmod -R a+rwx /carta

# Port 3002 is CARTA's upstream default. Skaha's "carta" session launcher
# re-specifies --port at runtime per session; this EXPOSE is declarative only.
EXPOSE 3002

ENV HOME=/carta
ENV CARTA_DOCKER_DEPLOYMENT=1

# Optional: cap the profiling run. When set to a positive integer, psrecord
# stops sampling after that many seconds (and carta alongside it, because
# --include-children is set). Useful for time-boxed diagnostics jobs.
# Leave empty for "sample until carta exits naturally" (default).
ARG PSRECORD_DURATION_SECONDS=
ENV PSRECORD_DURATION_SECONDS=${PSRECORD_DURATION_SECONDS}

LABEL org.opencontainers.image.title="cadc/carta-psrecord"
LABEL org.opencontainers.image.description="CARTA with psrecord profiling: per-session CPU / memory / IO timeline of the CARTA backend"
LABEL org.opencontainers.image.source="https://github.com/opencadc/canfar-containers"
LABEL org.opencontainers.image.licenses="GPL-3.0-or-later"

# --- Wrapper script ---
# Builds the `carta` argv (Skaha-shaped if env vars are present, bare
# `carta --no_browser` otherwise), then execs psrecord with --include-io
# --include-children at 1-second intervals, writing log + plot under
# $HOME/.carta_logs/ with a timestamp prefix.
#
# Uses BuildKit's Dockerfile heredoc syntax (requires the `# syntax=...`
# directive at the top of this file). The inner `<<'SCRIPT'` quoted
# delimiter preserves runtime variables like ${HOME},
# ${SKAHA_TOP_LEVEL_DIR}, ${PSRECORD_DURATION_SECONDS} literally for
# shell expansion inside the running container rather than expanding
# them at build time.
# hadolint ignore=SC2016
RUN <<RUN_EOF
cat > /carta/start.sh <<'SCRIPT'
#!/bin/bash
set -euo pipefail

dtm=$(date +%Y%m%d%H%M%S)
logdir="${HOME}/.carta_logs"
mkdir -p "${logdir}"

# Default: local docker run. When Skaha env vars are present, reconstruct
# the full invocation Skaha would have passed to `carta` directly.
carta_cmd=(carta --no_browser)
if [ -n "${SKAHA_TOP_LEVEL_DIR:-}" ] || [ -n "${SKAHA_PROJECTS_DIR:-}" ] || [ -n "${SKAHA_SESSION_URL_PATH:-}" ]; then
    top_dir="${SKAHA_TOP_LEVEL_DIR:-/arc}"
    start_dir="${SKAHA_PROJECTS_DIR:-/arc/projects}"
    carta_port="${CARTA_PORT:-6901}"
    idle_timeout="${CARTA_IDLE_TIMEOUT:-100000}"

    carta_cmd+=(
        "--top_level_folder=${top_dir}"
        "--enable_scripting"
        "--port=${carta_port}"
        "--idle_timeout=${idle_timeout}"
        "--debug_no_auth"
    )
    if [ -n "${SKAHA_SESSION_URL_PATH:-}" ]; then
        carta_cmd+=("--http_url_prefix=${SKAHA_SESSION_URL_PATH}")
    fi
    carta_cmd+=("${start_dir}")
fi

command_str="$(printf '%q ' "${carta_cmd[@]}")"
command_str="${command_str% }"
echo "start.sh: command=${command_str}"

duration_args=()
if [ -n "${PSRECORD_DURATION_SECONDS:-}" ]; then
    if ! [[ "${PSRECORD_DURATION_SECONDS}" =~ ^[0-9]+$ ]] || [ "${PSRECORD_DURATION_SECONDS}" -eq 0 ]; then
        echo "start.sh: PSRECORD_DURATION_SECONDS must be a positive integer (got: ${PSRECORD_DURATION_SECONDS})" >&2
        exit 1
    fi
    duration_args=(--duration "${PSRECORD_DURATION_SECONDS}")
    echo "start.sh: psrecord will stop after ${PSRECORD_DURATION_SECONDS}s (log/plot under ${logdir})" >&2
fi

exec psrecord "${command_str}" \
    --log "${logdir}/${dtm}_carta-backend.log" \
    --plot "${logdir}/${dtm}_carta-backend.png" \
    --include-io \
    --interval 1 \
    --include-children \
    "${duration_args[@]}"
SCRIPT
chmod +x /carta/start.sh
RUN_EOF

CMD ["/carta/start.sh"]
