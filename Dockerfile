# --- Stage 1: Build the TypeScript server wrapper ---
FROM node:22-alpine AS ts-builder
WORKDIR /app
# FIXED: Clone the repo properly (was a bare URL line causing "command not found")
# Also include build tools needed to compile the project's native dependencies
RUN apk add --no-cache git python3 make g++ build-base && \
    git clone --depth 1 --branch v0.6.0 https://github.com/bradleygolden/hexdocs-mcp . && \
    npm ci && \
    npm run build

# --- Stage 2: Final Cross-Platform Runtime Image ---
FROM elixir:1.16-alpine
WORKDIR /app

# Core runtime system dependencies (keep curl/git for hex operations)
# Install Node.js + npm via apk so `node`/`npm` are properly on PATH for
# both AMD64 and ARM64 (the previous COPY --from hack broke under QEMU, exit 127)
RUN apk add --no-cache git curl libstdc++ nodejs npm

# Pre-bootstrap mix tools to prevent runtime generation loops
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy static builds from TS stage
COPY --from=ts-builder /app/dist ./dist
COPY --from=ts-builder /app/package.json ./package.json
COPY --from=ts-builder /app/package-lock.json ./package-lock.json

# Install production npm dependencies
RUN npm ci --omit=dev

ENV NODE_ENV=production
ENTRYPOINT ["node", "dist/index.js"]
