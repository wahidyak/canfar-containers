# Layer 3: Interactive Terminal (With OpenCode AI)
FROM images.canfar.net/skaha/webterm:26.02

LABEL description="CANFAR Terminal Environment with OpenCode AI"

# Install OpenCode AI
RUN curl -fsSL https://opencode.ai/install | bash \
    && mv /root/.opencode/bin/opencode /usr/local/bin/opencode \
    && chmod +x /usr/local/bin/opencode \
    && rm -rf /root/.opencode

# Add OpenCode Alias
RUN echo 'alias oc="opencode"' >> /etc/profile.d/terminal.sh

CMD ["/skaha/startup.sh"]
