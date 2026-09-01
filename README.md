# hexdocs-mcp-installer

Builds and distributes a **multi-arch Docker image** of the [HexDocs MCP](https://github.com/bradleygolden/hexdocs-mcp) server, so tools like VS Code can consume it over Docker STDIO — avoiding the local Node.js `npx` network layer entirely.

## Why Docker?

The native Windows `libuv` assertion crash with `npx` is exactly the friction this repo eliminates:

- **Complete isolation** — Erlang, Elixir, Mix, and Node are bundled inside an Alpine Linux layer. Your host OS stays completely clean.
- **No `npx` network crashing** — Docker handles the standard streams directly. VS Code talks to `docker` via STDIO, bypassing flaky local runtime scripts.
- **True portability** — Pull the multi-arch image onto your Mac (via Colima) or Windows machine with one line.

## Architecture (decoupled)

The runtime splits the MCP server from the Ollama service so each can live and scale
independently:

1. **HexDocs MCP** — a short-lived, on-demand container launched by your MCP client
   (VS Code) via `docker run --rm -i`. Its embedded Elixir backend always talks to
   Ollama at the **hardcoded `localhost:11434`** (it does not read an Ollama URL env var).
2. **Ollama** — a long-lived embedding server, run as a container so the MCP server
   can reach it at `localhost:11434` by sharing its network namespace.

```mermaid
graph LR
  A[VS Code / MCP client] -- stdio --> B[hexdocs-mcp container]
  B -- localhost:11434 (--network container:ollama) --> C[Ollama container]
  C -- persists --> D[(ollama_data volume)]
```

> **Why a container for Ollama?** On **Docker Desktop**, `--network host` maps the
> container's `localhost` to the Docker **VM**, not your host — so a native host Ollama
> can't be reached at `localhost:11434` from a container. Running Ollama as a container
> and sharing its network namespace (`--network container:ollama`) fixes that and works
> on every platform. (On native Linux only, `--network host` can reach a host Ollama,
> but the container approach succeeds there too, so we standardize on it.)

> **⚠️ Semantic features require Ollama.** The `fetch` (embedding) and `search`
> (semantic search) tools need a running Ollama server with the embedding model
> pulled. The MCP handshake and Hex.pm-based searches work without it, but the core
> semantic-search value of this server requires Ollama. See [step 2](#2-run-ollama-first-required-for-embeddings)
> below.

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

### 2. Run Ollama first (required for embeddings)

You don't need this repo to get Ollama running — use plain `docker run`:

```bash
docker run -d --name ollama --restart unless-stopped -p 11434:11434 \
  -v ollama_data:/root/.ollama ollama/ollama:latest
docker exec ollama ollama pull nomic-embed-text
```

> If you've cloned this repo, `docker compose up -d` does the exact same thing
> (that's what [`docker-compose.yml`](./docker-compose.yml) defines). Both produce a
> container named `ollama`, which the MCP server expects for `--network container:ollama`.
>
> **If the name `ollama` is already in use** (e.g. a previous run or `docker compose up`),
> the `docker run` command will report a name conflict — that's fine, your container is
> already running. Just skip the `docker run` line. To start fresh later, remove it first
> with `docker rm -f ollama`.
>
> Both `nomic-embed-text` and `mxbai-embed-large` are supported; pull whichever the
> server requests. The published image requests `nomic-embed-text`.

### 3. Verify the image runs

The server speaks [MCP](https://modelcontextprotocol.io) over STDIO, so the simplest
smoke test is to start it with `docker run --rm -i` and send an MCP initialize frame:

```bash
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"smoke-test","version":"1.0.0"}}}\n' \
  | docker run --rm -i ghcr.io/pranaypant/hexdocs-mcp-global:latest
```

You should see a JSON-RPC response back (an `initialize` result), which confirms the
MCP server handshake works over Docker STDIO.

### 4. Add it to VS Code

VS Code natively supports MCP servers. There are two ways to register one: a
**workspace** config (`.vscode/mcp.json`, shared via the repo) or a **user**
config (applies to every project). Both use the same file format.

#### 4a. Create `.vscode/mcp.json` (workspace — recommended)

> A ready-to-copy sample lives at the **repo root as [`mcp.json`](./mcp.json)**.

1. Start Ollama first (see step 2 above).
2. In the root of your project, create a folder named `.vscode` (if it doesn't
   already exist).
3. Inside it, create a file named `mcp.json` (or copy the sample from [`mcp.json`](./mcp.json)).
4. Use this as the contents:

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
        "--network",
        "container:ollama",
        "ghcr.io/pranaypant/hexdocs-mcp-global:latest"
      ]
    }
  }
}
```

> **Why `--network container:ollama`?** The MCP server's embedded Elixir backend
> connects to Ollama at the **hardcoded `localhost:11434`** — it does **not** read an
> `OLLAMA_URL` env var. Sharing the Ollama container's network namespace makes the MCP
> container's `localhost:11434` point directly at Ollama, and works on every platform.

5. **Approve it:** the first time VS Code sees the file it shows a prompt asking
   whether to allow the server. Click **Allow**. (If you miss the prompt, run the
   command palette → **MCP: Review Files with MCP Servers** and approve it there.)
6. **Activate it:** to start the server, use the command palette
   (`Ctrl+Shift+P`) and choose **MCP: List Servers**, or just chat with
   GitHub Copilot in this project — Copilot will spin up registered MCP servers
   automatically. You should see `hexdocs-mcp` appear in the **MCP Servers**
   list.

> **Alternative — user-level (every project):** open the command palette
> (`Ctrl+Shift+P`) → **MCP: Open User Configuration**, create/edit `.vscode/mcp.json`
> with the same JSON above, then approve and activate it the same way.

#### 4b. Verify it connected

1. Command palette → **MCP: List Servers**.
2. Confirm `hexdocs-mcp` shows **"Connected"** (not "Failed").
3. Try a prompt in GitHub Copilot Chat that uses the server's tools, for example:
   _"Use the HexDocs MCP server to search Hex docs for `Enum.map`."_ Copilot should
   invoke the server's `search` tool and return results.

If the server fails to start, see the [Troubleshooting](#troubleshooting) section.

> **Note on Ollama:** the MCP server's Elixir backend always connects to Ollama at
> the hardcoded `localhost:11434`. The way to satisfy that inside a container is to
> run Ollama as the `ollama` container (via `docker compose`) and launch the MCP
> server with `--network container:ollama` so it shares that container's loopback.
> If you don't plan to use embeddings, you can omit the model pulls.

## Option 2 — Build locally

Only needed if you are iterating on the `Dockerfile` itself or don't want to use GHCR:

```bash
docker build -t ghcr.io/pranaypant/hexdocs-mcp-global:latest .
```

Then register it in your MCP client exactly as in Option 1, but reference the local
tag you just built instead of the `ghcr.io/...` one (and keep the required
`--network container:ollama` flag so the backend reaches Ollama):

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
        "--network",
        "container:ollama",
        "hexdocs-mcp-local:latest"
      ]
    }
  }
}
```

(Adjust `hexdocs-mcp-local:latest` to whatever tag you built with, and start Ollama
first with `docker compose up -d`.)

## Which label should I use?

| Situation                        | Tag                                                    |
| -------------------------------- | ------------------------------------------------------ |
| Normal use (pull once, stable)   | `ghcr.io/pranaypant/hexdocs-mcp-global:latest`         |
| Reproduce a specific build       | `ghcr.io/pranaypant/hexdocs-mcp-global:sha-<shortsha>` |
| Testing/Debugging the Dockerfile | your local tag from `Option 2`                         |

## Troubleshooting

| Symptom                                              | Cause                                                                                 | Fix                                                                                                                              |
| ---------------------------------------------------- | ------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `docker pull` → `Error response from daemon: denied` | Local GHCR auth quirk (GHCR often requires a login even for public images)            | `docker login ghcr.io`, then retry                                                                                               |
| `repository name must be lowercase`                  | Image reference uses uppercase owner                                                  | Use `ghcr.io/pranaypant/...` (all lowercase)                                                                                     |
| VS Code shows server as **"Failed"**                 | Docker isn't running, or image/tag name is wrong in `mcp.json`                        | Start Docker Desktop/Colima; double-check the image tag is lowercase and pulled                                                  |
| Server starts but `search` returns `:econnrefused`   | The MCP container can't reach Ollama (the Elixir backend hardcodes `localhost:11434`) | Make sure the `ollama` container is running (`docker run`/`docker compose up -d` in step 2) and launch the MCP server with `--network container:ollama` |
| Server starts but `search` returns `HTTPError 404`   | The embedding model isn't available to the Ollama the MCP container connects to      | `docker exec ollama ollama pull nomic-embed-text` (and/or `mxbai-embed-large`) |
| Server not listed at all                             | `mcp.json` not approved                                                               | Command palette → **MCP: Review Files with MCP Servers** → **Allow**                                                             |

## Releasing

Push to `main` (or use **workflow_dispatch**) and the [GitHub Actions workflow](./.github/workflows/build-and-push.yml) builds and pushes the image to GHCR automatically.
