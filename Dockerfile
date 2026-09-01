# --- Stage 1: Build the TypeScript server wrapper ---
FROM node:24-alpine AS ts-builder
WORKDIR /app
# FIXED: Replaced the malformed repository root link with the complete project path URL
RUN apk add --no-cache git && \
    https://github.com/bradleygolden/hexdocs-mcp . && \
    git checkout v0.6.0 && \
    npm ci && \
    npm run build

# --- Stage 2: Final Cross-Platform Runtime Image ---
FROM elixir:1.16-alpine
WORKDIR /app

# Core runtime system dependencies (keep curl/git for hex operations)
RUN apk add --no-cache git curl libstdc++

# PERFECT SYNC: Copy Node 24 binaries directly from the official stage
COPY --from=node:24-alpine /usr/local/bin/node /usr/local/bin/node
COPY --from=node:24-alpine /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm

# Pre-bootstrap mix tools to prevent runtime generation loops
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy static builds from TS stage
COPY --from=ts-builder /app/dist ./dist
COPY --from=ts-builder /app/package.json ./package.json
COPY --from=ts-builder /app/package-lock.json ./package-lock.json

# Now npm is universally available across all platforms (AMD64 & ARM64)
RUN npm ci --omit=dev

ENV NODE_ENV=production
ENTRYPOINT ["node", "dist/index.js"]
