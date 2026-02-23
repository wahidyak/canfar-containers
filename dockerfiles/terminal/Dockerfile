# syntax=docker/dockerfile:1
# Layer 3: Interactive Terminal (CLI Environment)
ARG REGISTRY=images.canfar.net
ARG PYTHON_VERSION=3.12
FROM ${REGISTRY}/cadc/python:${PYTHON_VERSION}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

LABEL description="Standard CANFAR Terminal CLI Environment" \
      org.opencontainers.image.version="26.02"

# Package Versions (Tracked by Renovate)
# renovate: datasource=repology depName=debian_trixie/acl versioning=deb
ARG ACL_VERSION=2.3.2-2+b1
# renovate: datasource=repology depName=debian_trixie/bash-completion versioning=deb
ARG BASH_COMPLETION_VERSION=1:2.16.0-7
# renovate: datasource=repology depName=debian_trixie/ca-certificates versioning=deb
ARG CA_CERTIFICATES_VERSION=20250419
# renovate: datasource=repology depName=debian_trixie/curl versioning=deb
ARG CURL_VERSION=8.14.1-2+deb13u2
# renovate: datasource=repology depName=debian_trixie/git versioning=deb
ARG GIT_VERSION=1:2.47.3-0+deb13u1
# renovate: datasource=repology depName=debian_trixie/htop versioning=deb
ARG HTOP_VERSION=3.4.1-5
# renovate: datasource=repology depName=debian_trixie/locales versioning=deb
ARG LOCALES_VERSION=2.41-12+deb13u1
# renovate: datasource=repology depName=debian_trixie/wget versioning=deb
ARG WGET_VERSION=1.25.0-2

# Install Interactive Tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    acl=${ACL_VERSION} \
    bash-completion=${BASH_COMPLETION_VERSION} \
    ca-certificates=${CA_CERTIFICATES_VERSION} \
    curl=${CURL_VERSION} \
    git=${GIT_VERSION} \
    htop=${HTOP_VERSION} \
    locales=${LOCALES_VERSION} \
    wget=${WGET_VERSION} \
    && rm -rf /var/lib/apt/lists/* \
    && sed -i '/en_US.UTF-8 UTF-8/s/^# //g' /etc/locale.gen \
    && locale-gen en_US.UTF-8

# Configure Shell, Aliases, and Theme
# hadolint ignore=SC2016
RUN printf 'alias py="python3"\nalias ..="cd .."\nalias ...="cd ../.."\nalias ll="ls -alF"\nalias la="ls -A"\nalias l="ls -CF"\nalias rm="rm -i"\nalias cp="cp -i"\nalias mv="mv -i"\ncommand -v uv >/dev/null 2>&1 && eval "$(uv generate-shell-completion bash)"\ncommand -v pixi >/dev/null 2>&1 && eval "$(pixi completion --shell bash)"\n' > /etc/profile.d/terminal.sh \
    && printf 'export HISTFILE="${HOME}/.bash_history"\nshopt -s histappend\nPROMPT_COMMAND="history -a;$PROMPT_COMMAND"\n[ -f /etc/profile.d/terminal.sh ] && . /etc/profile.d/terminal.sh\n' >> /etc/bash.bashrc

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    TERM=xterm-256color
