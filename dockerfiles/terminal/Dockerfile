# Layer 2: Interactive Terminal (No OpenCode)
FROM images.canfar.net/skaha/base:26.02

LABEL description="Standard CANFAR Terminal Environment"

# Install Interactive Tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    ttyd \
    tmux \
    htop \
    rclone \
    jq \
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

# Startup Script (Modified for Skaha home directory persistence)
RUN mkdir -p /skaha \
    && printf '#!/bin/bash\n# Ensure persistent directories exist\nmkdir -p "${HOME}/.conda/envs" "${HOME}/.conda/pkgs" "${HOME}/.local/bin" "${HOME}/.cache/uv" "${HOME}/.pixi"\nttyd --writable --port 5000 -w "${HOME}" -t titleFixed="CANFAR Webterm" /bin/bash -l\n' > /skaha/startup.sh \
    && chmod +x /skaha/startup.sh

ENV STARSHIP_CONFIG=/etc/starship.toml \
    TERM=xterm-256color

EXPOSE 5000
WORKDIR /root
CMD ["/skaha/startup.sh"]
