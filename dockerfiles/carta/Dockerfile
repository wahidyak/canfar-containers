# syntax=docker/dockerfile:1
#
# CANFAR CARTA Image
#
# CARTA (Cube Analysis and Rendering Tool for Astronomy), launched by Skaha
# as a first-class "carta" session type (not "contributed"). Skaha's carta
# launcher wraps this image: it invokes `carta` directly with its own flags
# (--port, --http_url_prefix, --top_level_folder, --debug_no_auth,
# --idle_timeout, starting folder, ...), overriding any CMD we set here.
# Consequently this Dockerfile intentionally matches the upstream reference
# at opencadc/science-containers/Dockerfiles/carta: bare `carta --no_browser`
# CMD, EXPOSE the CARTA default port 3002. The CMD is effectively dead code
# under Skaha but is retained (a) so `docker run cadc/carta` still works
# standalone and (b) to document the minimum invocation contract.
#
# Upstream base: ubuntu:24.04 (Noble Numbat). CARTA is distributed exclusively
# via the cartavis-team PPA for Ubuntu Jammy (22.04) and Noble (24.04) - no
# Debian or RHEL equivalent is available, so this image does NOT inherit from
# cadc/terminal (which is Debian-based).
#
# Pinning strategy:
#   - Base image: tag + digest via Renovate docker datasource
#   - CARTA apt package: full apt version string via Renovate deb datasource
#     pointed at the PPA's Packages index. Catches both upstream version bumps
#     (e.g. 5.1.0 -> 5.2.0) and PPA rebuilds (e.g. ~noble1 -> ~noble2).
#   - PPA signing key fingerprint: manually pinned. A change in this value
#     means CARTAvis rotated their signing key and must be investigated
#     before merging (NOT auto-updated by Renovate).

ARG REGISTRY=images.canfar.net

# renovate: datasource=docker depName=ubuntu
ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION}@sha256:c4a8d5503dfb2a3eb8ab5f807da5bc69a85730fb49b5cfca2330194ebcc41c7b

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# CARTA version pinned against the PPA's Packages index. The deb datasource
# catches both upstream bumps and PPA-internal rebuilds without version changes.
# renovate: datasource=deb depName=carta registryUrl=https://ppa.launchpadcontent.net/cartavis-team/carta/ubuntu?suite=noble&components=main&binaryArch=amd64 versioning=deb
ARG CARTA_VERSION=5.1.0~noble1

# Install CARTA from the PPA with explicit key verification.
#
# PPA signing key fingerprint (Launchpad-hosted) is pinned as a literal
# inside the RUN block -- deliberately NOT an ARG, because (a) it must not
# be overridable at build time (a change means CARTAvis rotated their key,
# which is a security-relevant event that requires a reviewed Dockerfile
# edit, not a build-invocation override) and (b) ARG form triggers buildkit's
# SecretsUsedInArgOrEnv lint (false positive; fingerprints are public, but
# cleaner to avoid the check entirely). Verified against three independent
# sources (2026-04-22): Launchpad HTML page, Launchpad JSON API
# (signing_key_fingerprint), and keyserver.ubuntu.com ("Launchpad PPA for
# CARTAvis" UID). Key is 4096-bit RSA, created 2021-03-16.
# https://launchpad.net/~cartavis-team/+archive/ubuntu/carta
#
# Key handling: fetch the armored signing key over HTTPS from
# keyserver.ubuntu.com (TLS-trusted), dearmor it locally, and verify the
# resulting fingerprint matches our pinned constant before trusting it for
# apt. This avoids dirmngr entirely (it has bootstrapping issues in buildkit
# sandboxes: no /root/.gnupg until interactive gpg creates it) and, more
# importantly, makes the fingerprint check a hard build-time gate -- if a
# MITM or a keyserver compromise swaps the key, dearmor+fingerprint-compare
# still fails closed. Single RUN layer keeps the image slim.
# hadolint ignore=DL3008
RUN PPA_KEY_FPR="49CD6FAB8EA28584DBDCD04186B78FB18F11E91C" && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x${PPA_KEY_FPR}" \
        | gpg --dearmor > /etc/apt/keyrings/cartavis.gpg && \
    chmod 644 /etc/apt/keyrings/cartavis.gpg && \
    ACTUAL_FPR="$(gpg --show-keys --with-colons --with-fingerprint /etc/apt/keyrings/cartavis.gpg \
                    | awk -F: '/^fpr:/ {print $10; exit}')" && \
    if [[ "${ACTUAL_FPR}" != "${PPA_KEY_FPR}" ]]; then \
        echo "ERROR: fetched PPA key fingerprint ${ACTUAL_FPR} does not match pinned ${PPA_KEY_FPR}" >&2; \
        exit 1; \
    fi && \
    echo "deb [signed-by=/etc/apt/keyrings/cartavis.gpg] https://ppa.launchpadcontent.net/cartavis-team/carta/ubuntu noble main" \
        > /etc/apt/sources.list.d/cartavis.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends "carta=${CARTA_VERSION}" && \
    apt-get purge -y --auto-remove curl gnupg && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/tmp/* /root/.gnupg

WORKDIR /carta
RUN chmod -R a+rwx /carta

# Port 3002 is the CARTA upstream default. Skaha's "carta" session type
# launcher re-specifies --port at runtime per session (observed in-platform
# as --port=6901 with --http_url_prefix=/session/carta/<id>), so the EXPOSE
# value is declarative only -- it matches the upstream reference image
# (opencadc/science-containers/Dockerfiles/carta) and documents the port
# `docker run cadc/carta` would listen on in the absence of Skaha overrides.
EXPOSE 3002

ENV HOME=/carta
ENV CARTA_DOCKER_DEPLOYMENT=1

LABEL org.opencontainers.image.title="cadc/carta"
LABEL org.opencontainers.image.description="CARTA: Cube Analysis and Rendering Tool for Astronomy"
LABEL org.opencontainers.image.source="https://github.com/opencadc/canfar-containers"
LABEL org.opencontainers.image.licenses="GPL-3.0-or-later"

# Bare CMD matching the upstream reference. Under Skaha's "carta" session
# type this is overridden by the platform launcher, which supplies its own
# flags (--port, --http_url_prefix, --top_level_folder, --debug_no_auth,
# --idle_timeout, --enable_scripting, and the starting folder positional).
# Do NOT add --port, --debug_no_auth, or a starting folder here: duplicates
# and drift against Skaha's contract have caused Bad Gateway / routing
# failures in the past, and the correct values are platform-side config,
# not image-side.
CMD ["carta", "--no_browser"]
