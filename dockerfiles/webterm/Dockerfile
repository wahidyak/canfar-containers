# syntax=docker/dockerfile:1
# Layer 4: Web Terminal (ttyd)

ARG REGISTRY=images.canfar.net
ARG BASE_TAG=26.02

# Stage 1: ttyd Binary
FROM tsl0922/ttyd:1.7.7 AS ttyd-bin

# Stage 2: Runtime
FROM ${REGISTRY}/cadc/terminal:${BASE_TAG}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

LABEL description="CANFAR Web-based Terminal Environment" \
      org.opencontainers.image.version="26.02"

# Prepare specialized directories
RUN mkdir -p /cadc

# Package Versions
ARG EMACS_VERSION=1:30.1+1-6
ARG FONTS_NOTO_VERSION=2.051-0+deb13u1
ARG FONTCONFIG_VERSION=2.15.0-2.3
ARG UNZIP_VERSION=6.0-29
ARG NANO_VERSION=8.4-1
ARG TMUX_VERSION=3.5a-3
ARG VIM_VERSION=2:9.1.1230-2
ARG PROCPS_VERSION=2:4.0.4-9

# Install Web Terminal, Fonts, and Interactive Tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    emacs-nox=${EMACS_VERSION} \
    fonts-noto-color-emoji=${FONTS_NOTO_VERSION} \
    fontconfig=${FONTCONFIG_VERSION} \
    unzip=${UNZIP_VERSION} \
    nano=${NANO_VERSION} \
    tmux=${TMUX_VERSION} \
    vim-nox=${VIM_VERSION} \
    procps=${PROCPS_VERSION} \
    && rm -rf /var/lib/apt/lists/*

# Copy ttyd from official image
COPY --from=ttyd-bin /usr/bin/ttyd /usr/local/bin/ttyd

# Install Hack Nerd Font
RUN mkdir -p /usr/local/share/fonts/hack \
    && curl -fLo /tmp/hack.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Hack.zip \
    && unzip /tmp/hack.zip -d /usr/local/share/fonts/hack \
    && rm /tmp/hack.zip \
    && fc-cache -fv

# Create custom ttyd index with "Safari-proof" CSS and Glyph overrides
RUN (ttyd --port 7681 /bin/bash &) \
    && for _ in {1..10}; do if curl -s http://localhost:7681 > /tmp/orig_index.html; then break; fi; sleep 1; done \
    && pkill -f ttyd \
    && printf "<style>\n @font-face { font-family: 'Hack Nerd Font Mono'; src: url('data:font/ttf;base64," > /tmp/font_style.css \
    && base64 /usr/local/share/fonts/hack/HackNerdFontMono-Regular.ttf >> /tmp/font_style.css \
    && printf "') format('truetype'); font-display: block; }\n" >> /tmp/font_style.css \
    && printf "body { font-family: 'Hack Nerd Font Mono', monospace !important; }\n" >> /tmp/font_style.css \
    && printf ".xterm-rows { letter-spacing: -1px !important; font-variant-ligatures: none !important; }\n" >> /tmp/font_style.css \
    && printf ".xterm-normal-char, .xterm-rows span, .xterm-rows div { font-family: 'Hack Nerd Font Mono' !important; }\n</style>\n" >> /tmp/font_style.css \
    && LINE=$(grep -n "</head>" /tmp/orig_index.html | cut -f1 -d:) \
    && head -n "$((LINE-1))" /tmp/orig_index.html > /tmp/head.html \
    && tail -n "+${LINE}" /tmp/orig_index.html > /tmp/tail.html \
    && cat /tmp/head.html /tmp/font_style.css /tmp/tail.html > /cadc/index.html \
    && rm /tmp/orig_index.html /tmp/font_style.css /tmp/head.html /tmp/tail.html

# Install Starship Prompt
ARG STARSHIP_VERSION=v1.24.2
RUN curl -sS https://starship.rs/install.sh | sh -s -- --yes --version ${STARSHIP_VERSION} \
    && /usr/local/bin/starship init bash --print-full-init >> /etc/profile.d/terminal.sh

# Starship Gruvbox Material Configuration (Optimized Palette)
# hadolint ignore=SC2016
RUN printf 'scan_timeout = 1000\ncommand_timeout = 1000\npalette = "gruvbox"\n\n[palettes.gruvbox]\nbg0 = "#282828"\nbg1 = "#3c3836"\nfg0 = "#fbf1c7"\nyellow = "#fabd2f"\naqua = "#8ec07c"\ngreen = "#b8bb26"\nred = "#fb4934"\n\n[username]\nshow_always = true\nstyle_user = "bg:yellow fg:bg0"\nstyle_root = "bg:red fg:bg0"\nformat = "[  $user ]($style)"\n\n[directory]\nstyle = "bg:aqua fg:bg0"\nformat = "[  $path ]($style)"\ntruncation_length = 0\ntruncate_to_repo = false\n\n[git_branch]\nsymbol = " "\nstyle = "bg:green fg:bg0"\nformat = "[ $symbol$branch ]($style)"\n\n[git_status]\ndisabled = false\nformat = "([$all_status$ahead_behind]($style) )"\nstaged = " "\nmodified = "󰏬 "\ndeleted = " "\nrenamed = "󰁔 "\nuntracked = " "\n\n[python]\nsymbol = " "\n\n[container]\ndisabled = true\n\n[character]\nsuccess_symbol = "[ 󰆍 > ](bold green)"\nerror_symbol = "[ 󰆍 x ](bold red)"\n' > /etc/starship.toml
ENV STARSHIP_CONFIG=/etc/starship.toml

# Install OpenCode AI
ARG OPENCODE_VERSION=1.1.63
RUN curl -fsSL https://opencode.ai/install | bash -s -- --version ${OPENCODE_VERSION} \
    && mv /root/.opencode/bin/opencode /usr/local/bin/opencode \
    && chmod +x /usr/local/bin/opencode \
    && rm -rf /root/.opencode \
    && echo 'alias oc="opencode"' >> /etc/profile.d/terminal.sh

# Updated Startup Script with Atlas Disable and letterSpacing override
# hadolint ignore=SC2016
RUN printf "#!/bin/bash\n\
mkdir -p \"\${HOME}/.local/bin\" \"\${HOME}/.cache/uv\" \"\${HOME}/.pixi\"\n\
ttyd --writable --port 5000 --index /cadc/index.html -w \"\${HOME}\" \
-t fontFamily=\"'Hack Nerd Font Mono'\" \
-t rendererType=dom \
-t experimentalCharAtlas=\"none\" \
-t letterSpacing=-1 \
-t lineHeight=1.1 \
-t theme='{\"background\": \"#282828\"}' \
-t titleFixed=\"CANFAR Webterm\" /bin/bash -l\n" > /cadc/startup.sh \
    && chmod +x /cadc/startup.sh

EXPOSE 5000
WORKDIR /tmp
CMD ["/cadc/startup.sh"]