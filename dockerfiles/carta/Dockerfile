# syntax=docker/dockerfile:1
#
# CANFAR CARTA Image (Contributed Session)
#
# CARTA (Cube Analysis and Rendering Tool for Astronomy) served on port 5000
# for launching as a CANFAR "contributed" session via Skaha.
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

# Port 5000 matches the CANFAR Skaha "contributed session" contract, same as
# webterm / vscode / marimo. The upstream CARTA default is 3002; we override
# with --port 5000 in CMD so frontend WebSocket discovery (which uses
# window.location.host) picks up the right port automatically.
EXPOSE 5000

ENV HOME=/carta
ENV CARTA_DOCKER_DEPLOYMENT=1

LABEL org.opencontainers.image.title="cadc/carta"
LABEL org.opencontainers.image.description="CARTA: Cube Analysis and Rendering Tool for Astronomy"
LABEL org.opencontainers.image.source="https://github.com/opencadc/canfar-containers"
LABEL org.opencontainers.image.licenses="GPL-3.0-or-later"

# --debug_no_auth disables CARTA's own per-session token check. This is safe
# and necessary in the Skaha contributed-session model: Skaha already gates
# access to the pod via its own auth (only the logged-in, authorized user
# can reach the ingress at all), and Skaha's proxy does NOT forward CARTA's
# auto-generated token to the browser. Without this flag every WebSocket
# connection fails with "Incorrect or missing auth token supplied" and the
# session appears disconnected. Matches the behavior of the sibling webterm
# / vscode / marimo images, which likewise delegate auth to Skaha.
CMD ["carta", "--no_browser", "--debug_no_auth", "--port", "5000"]
