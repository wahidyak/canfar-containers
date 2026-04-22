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

# CARTAvis PPA signing key fingerprint (Launchpad-hosted). Not Renovate-tracked:
# a change here means CARTAvis rotated their key, a security-relevant event.
# Verified against three independent sources (2026-04-22):
#   1. Launchpad HTML page fingerprint field
#   2. Launchpad JSON API (signing_key_fingerprint in LP.cache)
#   3. keyserver.ubuntu.com (UID: "Launchpad PPA for CARTAvis")
# Key is 4096-bit RSA, created 2021-03-16.
# https://launchpad.net/~cartavis-team/+archive/ubuntu/carta
ARG CARTA_PPA_KEY_FINGERPRINT=49CD6FAB8EA28584DBDCD04186B78FB18F11E91C

# Install CARTA from the PPA with explicit key verification. Single RUN layer
# keeps the image slim by not materializing intermediate apt state.
# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        gnupg && \
    mkdir -p /etc/apt/keyrings && \
    gpg --no-default-keyring --keyring /etc/apt/keyrings/cartavis.gpg \
        --keyserver keyserver.ubuntu.com \
        --recv-keys "${CARTA_PPA_KEY_FINGERPRINT}" && \
    chmod 644 /etc/apt/keyrings/cartavis.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/cartavis.gpg] https://ppa.launchpadcontent.net/cartavis-team/carta/ubuntu noble main" \
        > /etc/apt/sources.list.d/cartavis.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends "carta=${CARTA_VERSION}" && \
    apt-get purge -y --auto-remove gnupg && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/tmp/*

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

CMD ["carta", "--no_browser", "--port", "5000"]
