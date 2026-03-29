FROM ubuntu:24.04

RUN apt-get update && apt-get install -y \
    curl git unzip ca-certificates procps sudo \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user (Claude Code refuses --dangerously-skip-permissions as root)
RUN useradd -m -s /bin/bash agent && echo "agent ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Install Node.js (as root, system-wide)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code (system-wide)
RUN npm install -g @anthropic-ai/claude-code

# Switch to non-root user for Bun and runtime
USER agent
WORKDIR /home/agent

# Install Bun (as agent user)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/home/agent/.bun/bin:$PATH"

# Install Discord channel plugin, patch for multi-bot support, and backup
RUN claude plugin marketplace add anthropics/claude-plugins-official \
    && claude plugin install discord@claude-plugins-official \
    && PLUGIN_DIR=$(find /home/agent/.claude/plugins/cache -path '*/discord/*/server.ts' -printf '%h' -quit) \
    && sed -i 's/if (msg\.author\.bot) return/if (msg.author.id === client.user?.id) return/' "$PLUGIN_DIR/server.ts" \
    && mkdir -p /home/agent/.claude-plugins-backup \
    && cp -r /home/agent/.claude/plugins /home/agent/.claude-plugins-backup/plugins \
    && cp /home/agent/.claude/settings.json /home/agent/.claude-plugins-backup/settings.json

COPY --chown=agent:agent entrypoint.sh /usr/local/bin/
WORKDIR /home/agent/workspace
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
