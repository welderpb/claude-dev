# Claude Code in an isolated container for rootless Podman.
# Build:  podman build -t claude-dev .
# Run:    alias claude-podman (see README.md)

FROM docker.io/library/node:22-bookworm

ARG CLAUDE_CODE_VERSION=latest
ARG TZ=UTC
ENV TZ=${TZ} \
    LANG=C.UTF-8 \
    DEVCONTAINER=true

# Development tools
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl wget gnupg2 \
      git gh openssh-client less man-db \
      ripgrep fd-find fzf jq tree unzip zip \
      procps psmisc htop \
      nano vim \
      python3 python3-pip python3-venv \
      build-essential pkg-config \
      zsh \
      podman-remote \
    && ln -s /usr/bin/fdfind /usr/local/bin/fd \
    && ln -s /usr/bin/podman-remote /usr/local/bin/podman \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install global npm packages into a directory owned by node,
# so Claude Code can update itself without root
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global \
    PATH=/usr/local/share/npm-global/bin:$PATH \
    CONTAINER_HOST=unix:///run/podman/podman.sock \
    EDITOR=nano \
    VISUAL=nano \
    SHELL=/bin/bash
RUN mkdir -p /usr/local/share/npm-global /home/node/.claude /home/node/.config \
    && chown -R node:node /usr/local/share/npm-global /home/node/.claude /home/node/.config

USER node
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} \
    && npm cache clean --force

CMD ["claude"]
