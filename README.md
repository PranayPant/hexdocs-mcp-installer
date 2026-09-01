# hexdocs-mcp-installer

Builds and distributes a **multi-arch Docker image** of the [HexDocs MCP](https://github.com/bradleygolden/hexdocs-mcp) server, so tools like VS Code can consume it over Docker STDIO — avoiding the local Node.js `npx` network layer entirely.

## Why Docker?

The native Windows `libuv` assertion crash with `npx` is exactly the friction this repo eliminates:

- **Complete isolation** — Erlang, Elixir, Mix, and Node are bundled inside an Alpine Linux layer. Your host OS stays completely clean.
- **No `npx` network crashing** — Docker handles the standard streams directly. VS Code talks to `docker` via STDIO, bypassing flaky local runtime scripts.
- **True portability** — Pull the multi-arch image onto your Mac (via Colima) or Windows machine with one line.

## Image

Published to GHCR as a multi-arch (`linux/amd64`, `linux/arm64`) image:

```
ghcr.io/PranayPant/hexdocs-mcp-global:latest
```

## Build locally

```bash
docker build -t ghcr.io/PranayPant/hexdocs-mcp-global:latest .
```

## Run / Connect as an MCP server

The image connects via Docker STDIO (`--rm -i`). Configure it in your MCP client, for example `.vscode/mcp.json`:

```json
{
  "servers": {
    "hexdocs-mcp": {
      "type": "stdio",
      "command": "docker",
      "args": [
        "run",
        "--rm",
        "-i",
        "--env",
        "HEXDOCS_MCP_OLLAMA_URL=http://docker.internal",
        "ghcr.io/PranayPant/hexdocs-mcp-global:latest"
      ]
    }
  }
}
```

## Releasing

Push to `main` (or use **workflow_dispatch**) and the [GitHub Actions workflow](./.github/workflows/build-and-push.yml) builds and pushes the image to GHCR automatically.
