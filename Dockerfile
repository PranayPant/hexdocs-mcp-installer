# --- Stage 1: Build the TypeScript server wrapper using Node 24 ---
FROM node:24-alpine AS ts-builder
WORKDIR /app
RUN apk add --no-cache git && \
    git clone https://github.com/bradleygolden/hexdocs-mcp.git . && \
    git checkout v0.6.0 && \
    npm ci && \
    npm run build

# --- Stage 2: Final Cross-Platform Runtime Image ---
FROM elixir:1.16-alpine
WORKDIR /app

# Ensure runtime container uses Node 24 tools matching the builder
RUN apk add --no-cache nodejs npm git curl

RUN mix local.hex --force && \
    mix local.rebar --force

COPY --from=ts-builder /app/dist ./dist
COPY --from=ts-builder /app/package.json ./package.json
COPY --from=ts-builder /app/package-lock.json ./package-lock.json

RUN npm ci --omit=dev

ENV NODE_ENV=production
ENTRYPOINT ["node", "dist/index.js"]
