# syntax=docker/dockerfile:1
ARG PYTHON_VERSION=3.13

# --- STAGE 1: RUNTIME (Layer 0 & 1) ---
# OS foundation and language runtime. Built on a stable cadence.
# renovate: datasource=docker depName=ubuntu
FROM ubuntu:24.04@sha256:cd1dba651b3080c3686ecf4e3c4220f026b521fb76978881737d24f200828b2b AS runtime

LABEL maintainer="CANFAR Project <support@canfar.net>"
LABEL org.opencontainers.image.source="https://github.com/opencadc/canfar-containers"

USER root
WORKDIR /tmp

# Environment Settings
ENV TZ=PST \
    DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    TERM=xterm-256color \
    CONDA_DIR=/opt/conda \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1
ENV PATH="${CONDA_DIR}/bin:${PATH}"

# Layer 0: OS - System Foundation
RUN apt-get update --yes --quiet --fix-missing \
    && apt-get install --yes --quiet --no-install-recommends \
        acl \
        bash-completion \
        bzip2 \
        ca-certificates \
        curl \
        emacs-nox \
        git \
        locales \
        nano \
        rsync \
        openssh-client \
        sudo \
        tzdata \
        vim-nox \
        wget \
        zsh \
        tcsh \
    && apt-get clean --yes \
    && rm -rf /var/lib/apt/lists/* /var/tmp/* \
    && ln -fs /usr/share/zoneinfo/${TZ} /etc/localtime \
    && dpkg-reconfigure --frontend noninteractive tzdata \
    && locale-gen en_US.UTF-8

WORKDIR /root
CMD ["/bin/bash"]
