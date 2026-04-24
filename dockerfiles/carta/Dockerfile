# syntax=docker/dockerfile:1
#
# CANFAR CARTA Image
#
# CARTA (Cube Analysis and Rendering Tool for Astronomy), launched by Skaha
# as a first-class "carta" session type (not "contributed"). Skaha's carta
# launcher invokes `carta` directly with its own flags (--port,
# --http_url_prefix, --top_level_folder, --debug_no_auth, --idle_timeout,
# starting folder, ...) and overrides any CMD we set here.
#
# This Dockerfile intentionally matches the upstream reference at
# opencadc/science-containers/Dockerfiles/carta: bare `carta --no_browser`
# CMD, EXPOSE the CARTA default port 3002. The CMD is effectively dead
# code under Skaha but is retained so `docker run cadc/carta` still works
# standalone, and to document the minimum invocation contract.
#
# Trust model for the cartavis-team PPA: we rely on Launchpad's TLS as
# the root of trust (same posture as `apt install` from the main Ubuntu
# archive), not on a pinned key fingerprint. A compromise of Launchpad's
# HTTPS would compromise this image; this is the bar every `apt`-based
# image in the repo operates at.

# renovate: datasource=docker depName=ubuntu
ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION}@sha256:c4a8d5503dfb2a3eb8ab5f807da5bc69a85730fb49b5cfca2330194ebcc41c7b

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# CARTA version pinned against the PPA's Packages index. The deb datasource
# catches both upstream bumps and PPA-internal rebuilds without version changes.
# renovate: datasource=deb depName=carta registryUrl=https://ppa.launchpadcontent.net/cartavis-team/carta/ubuntu?suite=noble&components=main&binaryArch=amd64 versioning=deb
ARG CARTA_VERSION=5.1.0~noble1

# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        software-properties-common && \
    add-apt-repository -y ppa:cartavis-team/carta && \
    apt-get update && \
    apt-get install -y --no-install-recommends "carta=${CARTA_VERSION}" && \
    apt-get purge -y --auto-remove software-properties-common && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/tmp/*

WORKDIR /carta
RUN chmod -R a+rwx /carta

# Port 3002 is CARTA's upstream default. Skaha's "carta" session launcher
# re-specifies --port at runtime per session (observed as --port=6901 with
# --http_url_prefix=/session/carta/<id>); this EXPOSE is declarative only.
EXPOSE 3002

ENV HOME=/carta
ENV CARTA_DOCKER_DEPLOYMENT=1

LABEL org.opencontainers.image.title="cadc/carta"
LABEL org.opencontainers.image.description="CARTA: Cube Analysis and Rendering Tool for Astronomy"
LABEL org.opencontainers.image.source="https://github.com/opencadc/canfar-containers"
LABEL org.opencontainers.image.licenses="GPL-3.0-or-later"

# Bare CMD matching the upstream reference. Skaha's "carta" session launcher
# overrides this with its own flags (--port, --http_url_prefix,
# --top_level_folder, --debug_no_auth, --idle_timeout, --enable_scripting,
# starting folder). Do NOT add those flags here: duplicates and drift
# against Skaha's contract have caused Bad Gateway / routing failures.
CMD ["carta", "--no_browser"]
