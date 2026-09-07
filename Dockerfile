# syntax=docker/dockerfile:1

# Build stage: compile OpenWiki from the vendored submodule.
# corepack picks up the pnpm version pinned in openwiki's package.json.
FROM node:22-bookworm-slim AS build
# Toolchain is fallback-only: better-sqlite3 ships prebuilds for amd64/arm64
# glibc, but if a prebuild download ever fails the install compiles instead.
RUN apt-get update \
 && apt-get install -y --no-install-recommends python3 make g++ \
 && rm -rf /var/lib/apt/lists/* \
 && corepack enable
WORKDIR /app
COPY openwiki-src/ ./
RUN pnpm install --frozen-lockfile \
 && pnpm run build \
 && pnpm prune --prod

# Runtime stage: dist + production deps only, non-root.
# git and ripgrep: openwiki's agent shells out to both when reading repos.
# The node user is renamed rather than added so we keep UID 1000 — the most
# common host UID for bind mounts.
FROM node:22-bookworm-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends git ripgrep \
 && rm -rf /var/lib/apt/lists/* \
 && usermod --login openwiki --home /home/openwiki --move-home node \
 && groupmod --new-name openwiki node \
 && mkdir -p /workspace /home/openwiki/.openwiki \
 && chown openwiki:openwiki /workspace /home/openwiki/.openwiki
ENV NODE_ENV=production
COPY --from=build /app/package.json /opt/openwiki/package.json
COPY --from=build /app/LICENSE /opt/openwiki/LICENSE
COPY --from=build /app/node_modules /opt/openwiki/node_modules
COPY --from=build /app/dist /opt/openwiki/dist

COPY --from=build /app/skills /opt/openwiki/skills
COPY --from=build /app/integrations /opt/openwiki/integrations

# COPY server.js /opt/openwiki/dist/visualize/server.js

# Host-side install scripts, extractable by scripts/install.sh bootstraps.
COPY scripts/openwiki-setup.sh /opt/openwiki/host/openwiki-setup.sh
COPY scripts/lib/ /opt/openwiki/host/lib/
COPY scripts/completions/ /opt/openwiki/host/completions/

LABEL org.opencontainers.image.title="openwiki" \
      org.opencontainers.image.description="Docker packaging of langchain-ai/openwiki, the DeepAgents-powered codebase wiki CLI" \
      org.opencontainers.image.source="https://github.com/InfiniteRoomLabs/langchain-ai-openwiki-docker" \
      org.opencontainers.image.licenses="MIT"

USER openwiki

COPY ./openwiki /usr/local/bin/openwiki
RUN chmod +x /usr/local/bin/openwiki

ENV LANGCHAIN_TRACING_V2="false"
ENV OPENAI_COMPATIBLE_BASE_URL="https://routellm.feg.cn/v1"
ENV OPENAI_COMPATIBLE_API_KEY="sk-123456"
ENV OPENWIKI_PROVIDER="openai-compatible"
ENV OPENWIKI_MODEL_ID="MiniMax-M3"

# Mount the repository you want documented here.
WORKDIR /workspace
ENTRYPOINT ["node", "/opt/openwiki/dist/cli/cli.js"]

