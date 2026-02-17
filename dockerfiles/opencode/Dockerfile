# Layer 5: Interactive Terminal (With OpenCode AI)
FROM images.canfar.net/cadc/webterm

LABEL description="CANFAR Terminal Environment with OpenCode AI"

# Install OpenCode AI
ARG OPENCODE_VERSION=1.1.63
RUN curl -fsSL https://opencode.ai/install | bash -s -- --version ${OPENCODE_VERSION} \
    && mv /root/.opencode/bin/opencode /usr/local/bin/opencode \
    && chmod +x /usr/local/bin/opencode \
    && rm -rf /root/.opencode

# Add alias for easier access
RUN echo 'alias oc="opencode"' >> /etc/profile.d/terminal.sh
