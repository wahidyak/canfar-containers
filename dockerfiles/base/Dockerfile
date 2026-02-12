# syntax=docker/dockerfile:1

# --- STAGE 1: RUNTIME (Layer 0 & 1) ---
# OS foundation and language runtime. Built on a stable cadence.
# renovate: datasource=docker depName=ubuntu
FROM ubuntu:24.04@sha256:cd1dba651b3080c3686ecf4e3c4220f026b521fb76978881737d24f200828b2b AS runtime

LABEL maintainer="CANFAR Project <support@canfar.net>"
LABEL org.opencontainers.image.source="https://github.com/opencadc/canfar-containers"

USER root
WORKDIR /tmp

# Environment Settings
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    TERM=xterm-256color

# Layer 0: OS - System Foundation
RUN apt-get update --yes --quiet --fix-missing \
    && apt-get install --yes --quiet --no-install-recommends \
        acl=2.3.2-1build1.1 \
        bash-completion=1:2.11-8 \
        bzip2=1.0.8-5.1build0.1 \
        ca-certificates=20240203 \
        curl=8.5.0-2ubuntu10.6 \
        emacs-nox=1:29.3+1-1ubuntu2 \
        git=1:2.43.0-1ubuntu7.3 \
        locales=2.39-0ubuntu8.7 \
        nano=7.2-2ubuntu0.1 \
        rsync=3.2.7-1ubuntu1.2 \
        openssh-client=1:9.6p1-3ubuntu13.14 \
        sudo=1.9.15p5-3ubuntu5.24.04.1 \
        tzdata=2025b-0ubuntu0.24.04.1 \
        vim-nox=2:9.1.0016-1ubuntu7.9 \
        wget=1.21.4-1ubuntu4.1 \
        zsh=5.9-6ubuntu2 \
        tcsh=6.24.10-4build1 \
    && apt-get clean --yes \
    && rm -rf /var/lib/apt/lists/* /var/tmp/* \
    && locale-gen en_US.UTF-8

WORKDIR /root
CMD ["/bin/bash"]
