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
ghcr.io/pranaypant/hexdocs-mcp-global:latest
```

> **Note on casing:** GHCR image references must use **lowercase** for the owner
> segment. Use `ghcr.io/pranaypant/...` — `docker run` rejects
> `ghcr.io/PranayPant/...` with `repository name must be lowercase`.

> **This image is already public** — you don't need any GitHub account, token, or
> package settings to pull it. Just install Docker and run the commands below.
>
> **Troubleshooting `denied` on pull:** if `docker pull` fails with
> `Error response from daemon: denied`, it's almost always a local Docker/GHCR
> auth quirk (GHCR requires a login even for public images on some setups), not
> the package. Fix it with a one-time login (any consumer can use their own
> GitHub account):
>
> ```bash
> docker login ghcr.io
> ```
>
> Then retry the pull. (Package-visibility settings are only changeable by the
> package owner, so consumers should never need to touch them.)

## Option 1 — Consume from GitHub (recommended, no local build)

This is the fastest way to get started. It pulls the pre-built image straight from
GitHub Container Registry (GHCR) — you never build anything locally.

### 1. Pull the image

```bash
docker pull ghcr.io/pranaypant/hexdocs-mcp-global:latest
```

> For **Mac (Apple Silicon / ARM)** or anything that isn't `linux/amd64`, Docker
> Desktop handles the multi-arch pull automatically. If you use **Colima**, make
> sure it's running first.

### 2. Verify the image runs

The server speaks [MCP](https://modelcontextprotocol.io) over STDIO, so the simplest
smoke test is to start it with `docker run --rm -i` and send an MCP initialize frame:

```bash
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"smoke-test","version":"1.0.0"}}}\n' \
  | docker run --rm -i ghcr.io/pranaypant/hexdocs-mcp-global:latest
```

You should see a JSON-RPC response back (an `initialize` result), which confirms the
MCP server handshake works over Docker STDIO.

### 3. Register it in your MCP client

Add the server to your client config. For VS Code, create/update `.vscode/mcp.json`:

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
        "ghcr.io/pranaypant/hexdocs-mcp-global:latest"
      ]
    }
  }
}
```

> **Note on Ollama:** the server shells out to an Ollama server for embedding/search.
> Set `HEXDOCS_MCP_OLLAMA_URL` to wherever Ollama is reachable from inside the
> container (e.g. `http://docker.internal`, `http://host.docker.internal`, or the
> host IP). If you don't plan to use embeddings, you can omit this env var.

## Option 2 — Build locally

Only needed if you are iterating on the `Dockerfile` itself or don't want to use GHCR:

```bash
docker build -t ghcr.io/pranaypant/hexdocs-mcp-global:latest .
```

Then register it in your MCP client exactly as in Option 1, but reference the local
tag you just built instead of the `ghcr.io/...` one:

```json
{
  "servers": {
    "hexdocs-mcp": {
      "type": "stdio",
      "command": "docker",
      "args": ["run", "--rm", "-i", "hexdocs-mcp-local:latest"]
    }
  }
}
```

(Adjust `hexdocs-mcp-local:latest` to whatever tag you built with.)

## Which label should I use?

| Situation                        | Tag                                                    |
| -------------------------------- | ------------------------------------------------------ |
| Normal use (pull once, stable)   | `ghcr.io/pranaypant/hexdocs-mcp-global:latest`         |
| Reproduce a specific build       | `ghcr.io/pranaypant/hexdocs-mcp-global:sha-<shortsha>` |
| Testing/Debugging the Dockerfile | your local tag from `Option 2`                         |

## Releasing

Push to `main` (or use **workflow_dispatch**) and the [GitHub Actions workflow](./.github/workflows/build-and-push.yml) builds and pushes the image to GHCR automatically.
