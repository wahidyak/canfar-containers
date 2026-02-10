# syntax=docker/dockerfile:1
ARG PYTHON_VERSION=3.13

# --- STAGE 1: RUNTIME (Layer 0 & 1) ---
# OS foundation and language runtime. Built on a stable cadence.
# renovate: datasource=docker depName=ubuntu
FROM ubuntu:24.04@sha256:cd1dba651b3080c3686ecf4e3c4220f026b521fb76978881737d24f200828b2b AS runtime

LABEL maintainer="CANFAR Project <support@canfar.net>"
LABEL org.opencontainers.image.source="https://github.com/opencadc/opencadc-base"

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

# Layer 1: Runtime (Python, Mamba, UV, Pixi)
ARG TARGETARCH
ARG PYTHON_VERSION
# renovate: datasource=github-releases depName=mamba-org/micromamba-releases
ARG MICROMAMBA_VERSION=2.5.0-1
# renovate: datasource=github-releases depName=astral-sh/uv
ARG UV_VERSION=0.10.0
# renovate: datasource=github-releases depName=prefix-dev/pixi
ARG PIXI_VERSION=0.63.2

RUN set -x \
    && if [ "${TARGETARCH}" = "arm64" ]; then ARCH="aarch64"; else ARCH="64"; fi \
    && curl -Ls https://github.com/mamba-org/micromamba-releases/releases/download/${MICROMAMBA_VERSION}/micromamba-linux-${ARCH} -o ./micromamba \
    && chmod +x ./micromamba \
    && ./micromamba install \
        --root-prefix="${CONDA_DIR}" \
        --prefix="${CONDA_DIR}" \
        --yes \
        python=${PYTHON_VERSION} mamba \
    && rm ./micromamba \
    && ln -s ${CONDA_DIR}/etc/profile.d/conda.sh /etc/profile.d/conda.sh

# Install modern environment managers
RUN mamba install --yes \
        conda \
        pip \
        conda-libmamba-solver \
        pip-tools \
        uv=${UV_VERSION} \
        pixi=${PIXI_VERSION} \
    && mamba clean --all --quiet --yes

# Configure Conda for home-directory persistence
RUN mkdir -p /etc/conda && printf 'envs_dirs:\n  - ~/.conda/envs\n  - /opt/conda/envs\npkgs_dirs:\n  - ~/.conda/pkgs\n  - /opt/conda/pkgs\n' > /etc/conda/condarc

# Configure Pip for user-only installs
RUN printf '[global]\nuser = true\n' > /etc/pip.conf

# Global environment variables for user-space persistence
RUN printf 'export PATH="${HOME}/.local/bin:${PATH}"\nexport PYTHONUSERBASE="${HOME}/.local"\nexport UV_PYTHON_INSTALL_DIR="${HOME}/.local/share/uv/python"\nexport UV_CACHE_DIR="${HOME}/.cache/uv"\nexport PIXI_HOME="${HOME}/.pixi"\nexport XDG_CACHE_HOME="${HOME}/.cache"\nexport XDG_DATA_HOME="${HOME}/.local/share"\nexport XDG_CONFIG_HOME="${HOME}/.config"\n' > /etc/profile.d/opencadc.sh

# --- STAGE 2: SCIENCE (Layer 2) ---
# Curated science stacks. Built on top of the stable runtime.
FROM runtime AS science

LABEL description="OpenCADC Science Base Image"

# Install CADC Science Stack
RUN pip install --no-cache-dir \
        cadcdata \
        cadctap \
        cadcutils \
        canfar \
        vos

WORKDIR /root
CMD ["/bin/bash"]
