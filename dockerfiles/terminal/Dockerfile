# syntax=docker/dockerfile:1
#
# CANFAR Terminal Image (Layer 2: Interactive CLI Environment)
#
# Inherits from the CANFAR Python image and adds essential CLI tools, shell
# customization (aliases, tab-completion), and UTF-8 locale support. This is
# the standard interactive environment for CANFAR users who SSH or connect
# via the science platform.
#
# Build chain: python:slim -> python -> THIS IMAGE -> webterm
#
# All APT package versions are pinned via ARGs and tracked by Renovate Bot
# against the Debian Trixie repository for automated monthly updates.

ARG REGISTRY=images.canfar.net
ARG PYTHON_VERSION=3.12
FROM ${REGISTRY}/cadc/python:${PYTHON_VERSION}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

LABEL description="Standard CANFAR Terminal CLI Environment" \
      org.opencontainers.image.version="26.02"

# --- Pinned APT Package Versions ---
# Each ARG has a "# renovate:" comment that tells Renovate Bot how to find
# newer versions. The datasource is "repology" (a cross-distro package tracker)
# and the target distro is Debian Trixie (the base of python:slim).

# renovate: datasource=repology depName=debian_13/acl versioning=deb
ARG ACL_VERSION=2.3.2-2+b1
# renovate: datasource=repology depName=debian_13/bash-completion versioning=deb
ARG BASH_COMPLETION_VERSION=1:2.16.0-7
# renovate: datasource=repology depName=debian_13/ca-certificates versioning=deb
ARG CA_CERTIFICATES_VERSION=20250419
# renovate: datasource=repology depName=debian_13/curl versioning=deb
ARG CURL_VERSION=8.14.1-2+deb13u2
# renovate: datasource=repology depName=debian_13/git versioning=deb
ARG GIT_VERSION=1:2.47.3-0+deb13u1
# renovate: datasource=repology depName=debian_13/htop versioning=deb
ARG HTOP_VERSION=3.4.1-5
# renovate: datasource=repology depName=debian_13/wget versioning=deb
ARG WGET_VERSION=1.25.0-2

# Install all CLI tools in a single RUN to minimize layers.
# --no-install-recommends keeps the image lean.
# APT lists are cleaned up in the same RUN to avoid bloating the layer.
# The locale-gen at the end enables UTF-8 for proper Unicode support.
#
# locales is a binary package produced by the glibc source package and is
# not exposed as its own project in Repology, so Renovate can't track it
# via the repology datasource. It ships with glibc (ABI-stable) and is
# left unpinned to avoid "version no longer available" failures when the
# Debian mirror rolls forward.
RUN apt-get update && apt-get install -y --no-install-recommends \
    acl=${ACL_VERSION} \
    bash-completion=${BASH_COMPLETION_VERSION} \
    ca-certificates=${CA_CERTIFICATES_VERSION} \
    curl=${CURL_VERSION} \
    git=${GIT_VERSION} \
    htop=${HTOP_VERSION} \
    locales \
    wget=${WGET_VERSION} \
    && rm -rf /var/lib/apt/lists/* \
    && sed -i '/en_US.UTF-8 UTF-8/s/^# //g' /etc/locale.gen \
    && locale-gen en_US.UTF-8

# Shell customization — written to /etc/profile.d/terminal.sh so it loads
# automatically in any login shell. Includes:
#   - Convenience aliases (py, ll, la, safe rm/cp/mv with -i)
#   - Tab completion for uv and pixi (generated dynamically)
# The /etc/bash.bashrc append ensures history persistence across sessions
# and sources the profile script for non-login interactive shells too.
# hadolint ignore=SC2016
RUN printf '[ -x /usr/bin/dircolors ] && eval "$(dircolors -b)"\nalias ls='"'"'ls --color=auto'"'"'\nalias py="python3"\nalias ..="cd .."\nalias ...="cd ../.."\nalias ll="ls -alF"\nalias la="ls -A"\nalias l="ls -CF"\nalias rm="rm -i"\nalias cp="cp -i"\nalias mv="mv -i"\nif [ -n "$BASH_VERSION" ]; then\n  command -v uv >/dev/null 2>&1 && eval "$(uv generate-shell-completion bash)"\n  command -v pixi >/dev/null 2>&1 && eval "$(pixi completion --shell bash)"\nfi\n' > /etc/profile.d/terminal.sh \
    && printf 'export HISTFILE="${HOME}/.bash_history"\nshopt -s histappend\nPROMPT_COMMAND="history -a;$PROMPT_COMMAND"\n[ -f /etc/profile.d/terminal.sh ] && . /etc/profile.d/terminal.sh\n' >> /etc/bash.bashrc

# Set locale and terminal type for proper Unicode and color support
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    TERM=xterm-256color
