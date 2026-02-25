# syntax=docker/dockerfile:1
# Layer 4: Web Terminal (ttyd) - Safari & Edge Fix Edition

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
ARG NODEJS_VERSION=20.19.2+dfsg-1
ARG NPM_VERSION=9.2.0~ds1-3

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
    nodejs=${NODEJS_VERSION} \
    npm=${NPM_VERSION} \
    && rm -rf /var/lib/apt/lists/*

# Copy ttyd from official image
COPY --from=ttyd-bin /usr/bin/ttyd /usr/local/bin/ttyd

# Install Hack Nerd Font (v3.3.0)
RUN mkdir -p /usr/local/share/fonts/hack \
    && curl -fLo /tmp/hack.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Hack.zip \
    && unzip /tmp/hack.zip -d /usr/local/share/fonts/hack \
    && rm /tmp/hack.zip \
    && fc-cache -fv

# Patch ttyd index.html with NO-WRAP Base64 + xterm-targeted CSS (Safari/Edge safe)
RUN (ttyd --port 7681 /bin/bash &) \
    && for _ in {1..15}; do if curl -fsS http://localhost:7681 > /tmp/orig_index.html; then break; fi; sleep 1; done \
    && pkill -f "ttyd --port 7681" || true \
    && printf "<style>\n@font-face {\n  font-family: 'Hack Nerd Font Mono';\n  src: url('data:font/ttf;base64," > /tmp/font_style.css \
    && base64 -w 0 /usr/local/share/fonts/hack/HackNerdFontMono-Regular.ttf >> /tmp/font_style.css \
    && printf "') format('truetype');\n  font-weight: 400;\n  font-style: normal;\n  font-display: swap;\n}\n" >> /tmp/font_style.css \
    && printf "html, body { margin: 0; padding: 0; overflow: hidden; height: 100%%; }\n" >> /tmp/font_style.css \
    && printf "body { font-family: 'Hack Nerd Font Mono', ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', 'Courier New', monospace !important; }\n" >> /tmp/font_style.css \
    && printf ".xterm, .xterm * { font-family: 'Hack Nerd Font Mono', ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', 'Courier New', monospace !important; }\n" >> /tmp/font_style.css \
    && printf ".xterm-rows { letter-spacing: 0px !important; }\n" >> /tmp/font_style.css \
    && printf "</style>\n" >> /tmp/font_style.css \
    && LINE=$(grep -n "</head>" /tmp/orig_index.html | head -n1 | cut -f1 -d:) \
    && head -n "$((LINE-1))" /tmp/orig_index.html > /tmp/head.html \
    && tail -n "+${LINE}" /tmp/orig_index.html > /tmp/tail.html \
    && cat /tmp/head.html /tmp/font_style.css /tmp/tail.html > /cadc/index.html \
    && rm -f /tmp/orig_index.html /tmp/font_style.css /tmp/head.html /tmp/tail.html

# Install Starship Prompt
ARG STARSHIP_VERSION=v1.24.2
RUN curl -sS https://starship.rs/install.sh | sh -s -- --yes --version ${STARSHIP_VERSION} \
    && /usr/local/bin/starship init bash --print-full-init >> /etc/profile.d/terminal.sh

# Starship Gruvbox Material Configuration (Optimized Palette for #282828)
# hadolint ignore=SC2016
RUN printf 'scan_timeout = 1000\ncommand_timeout = 1000\npalette = "gruvbox"\n\n[palettes.gruvbox]\nbg0 = "#282828"\nbg1 = "#3c3836"\nfg0 = "#fbf1c7"\nyellow = "#fabd2f"\naqua = "#8ec07c"\ngreen = "#b8bb26"\nred = "#fb4934"\n\n[username]\nshow_always = true\nstyle_user = "bg:yellow fg:bg0"\nstyle_root = "bg:red fg:bg0"\nformat = "[  $user ]($style)"\n\n[directory]\nstyle = "bg:aqua fg:bg0"\nformat = "[  $path ]($style)"\ntruncation_length = 0\ntruncate_to_repo = false\n\n[git_branch]\nsymbol = " "\nstyle = "bg:green fg:bg0"\nformat = "[ $symbol$branch ]($style)"\n\n[git_status]\ndisabled = false\nformat = "([$all_status$ahead_behind]($style) )"\nstaged = " "\nmodified = "󰏬 "\ndeleted = " "\nrenamed = "󰁔 "\nuntracked = " "\n\n[python]\nsymbol = " "\n\n[container]\ndisabled = true\n\n[character]\nsuccess_symbol = "[ 󰆍 > ](bold green)"\nerror_symbol = "[ 󰆍 x ](bold red)"\n' > /etc/starship.toml
ENV STARSHIP_CONFIG=/etc/starship.toml

# Install OpenCode AI
ARG OPENCODE_VERSION=1.1.63
RUN curl -fsSL https://opencode.ai/install | bash -s -- --version ${OPENCODE_VERSION} \
    && mv /root/.opencode/bin/opencode /usr/local/bin/opencode \
    && chmod +x /usr/local/bin/opencode \
    && rm -rf /root/.opencode \
    && echo 'alias oc="opencode"' >> /etc/profile.d/terminal.sh

# Install Additional AI CLI Agents (Copilot, Claude, Gemini, Codex)
ARG COPILOT_CLI_VERSION=0.1.36
ARG CLAUDE_CODE_VERSION=2.1.58
ARG GEMINI_CLI_VERSION=0.30.0
ARG CODEX_CLI_VERSION=0.105.0
RUN npm install -g \
    @githubnext/github-copilot-cli@${COPILOT_CLI_VERSION} \
    @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} \
    @google/gemini-cli@${GEMINI_CLI_VERSION} \
    @openai/codex@${CODEX_CLI_VERSION}

# Final Startup Script (DOM renderer for reliable font rendering in Safari/Edge)
# hadolint ignore=SC2016
RUN printf "#!/bin/bash\n\
mkdir -p \"\${HOME}/.local/bin\" \"\${HOME}/.cache/uv\" \"\${HOME}/.pixi\"\n\
ttyd --writable --port 5000 --index /cadc/index.html -w \"\${HOME}\" \
-t fontFamily=\"Hack Nerd Font Mono\" \
-t rendererType=dom \
-t letterSpacing=0 \
-t lineHeight=1.1 \
-t theme='{\"background\": \"#282828\"}' \
-t titleFixed=\"CANFAR Webterm\" \
/bin/bash -l\n" > /cadc/startup.sh \
    && chmod +x /cadc/startup.sh

EXPOSE 5000
WORKDIR /tmp
CMD ["/cadc/startup.sh"]
