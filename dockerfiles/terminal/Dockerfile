# Layer 3: Interactive Terminal (CLI Environment)
FROM images.canfar.net/cadc/python:3.12-26.02

LABEL description="Standard CANFAR Terminal CLI Environment"

# Install Interactive Tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    tmux=3.4-1ubuntu0.1 \
    htop=3.3.0-4build1 \
    rclone=1.60.1+dfsg-3ubuntu0.24.04.4 \
    jq=1.7.1-3ubuntu0.24.04.1 \
    && rm -rf /var/lib/apt/lists/*

# Install Starship Prompt
# renovate: datasource=github-releases depName=starship/starship
ARG STARSHIP_VERSION=v1.24.2
RUN curl -sS https://starship.rs/install.sh | sh -s -- --yes --version ${STARSHIP_VERSION}

# Configure Shell, Aliases, and Starship Theme
RUN echo 'alias py="python3"' > /etc/profile.d/terminal.sh \
    && echo 'alias ..="cd .."' >> /etc/profile.d/terminal.sh \
    && echo 'alias ...="cd ../.."' >> /etc/profile.d/terminal.sh \
    && echo 'alias ll="ls -alF"' >> /etc/profile.d/terminal.sh \
    && echo 'alias la="ls -A"' >> /etc/profile.d/terminal.sh \
    && echo 'alias l="ls -CF"' >> /etc/profile.d/terminal.sh \
    && echo 'alias rm="rm -i"' >> /etc/profile.d/terminal.sh \
    && echo 'alias cp="cp -i"' >> /etc/profile.d/terminal.sh \
    && echo 'alias mv="mv -i"' >> /etc/profile.d/terminal.sh \
    && echo 'command -v uv >/dev/null 2>&1 && eval "$(uv generate-shell-completion bash)"' >> /etc/profile.d/terminal.sh \
    && echo 'command -v pixi >/dev/null 2>&1 && eval "$(pixi completion --shell bash)"' >> /etc/profile.d/terminal.sh \
    && /usr/local/bin/starship init bash --print-full-init >> /etc/profile.d/terminal.sh \
    && echo 'export HISTFILE="${HOME}/.bash_history"' >> /etc/bash.bashrc \
    && echo 'shopt -s histappend' >> /etc/bash.bashrc \
    && echo 'PROMPT_COMMAND="history -a;$PROMPT_COMMAND"' >> /etc/bash.bashrc

# Starship Gruvbox Config
RUN mkdir -p /etc && printf 'scan_timeout = 1000\ncommand_timeout = 1000\npalette = "gruvbox"\n\n[palettes.gruvbox]\nbg0 = "#282828"\nyellow = "#d79921"\naqua = "#689d6a"\ngreen = "#98971a"\nred = "#cc241d"\n\n[username]\nshow_always = true\nstyle_user = "bg:yellow fg:bg0"\nstyle_root = "bg:red fg:bg0"\nformat = "[ $user ]($style)"\n\n[directory]\nstyle = "bg:aqua fg:bg0"\nformat = "[ $path ]($style)"\ntruncation_length = 0\ntruncate_to_repo = false\n\n[git_branch]\nsymbol = "git:"\nstyle = "bg:green fg:bg0"\nformat = "[ $symbol$branch ]($style)"\n\n[git_status]\ndisabled = true\n\n[container]\ndisabled = true\n\n[character]\nsuccess_symbol = "[ > ](bold green)"\nerror_symbol = "[ x ](bold red)"\n' > /etc/starship.toml

ENV STARSHIP_CONFIG=/etc/starship.toml \
    TERM=xterm-256color
