# Architecture Overview

This repo exposes the Codex CLI over HTTP on a Raspberry Pi and persists state via Deno KV.

- Components
  - Pi server (`submodules/pi-agent`): Deno HTTP server on `:3000` with two surfaces:
    - REST Codex wrapper: `POST /api/codex { prompt, timeout_ms? }` runs local `codex` and returns stdout/stderr.
    - KV API: CRUD endpoints under `/kv` compatible with Deno KV semantics.
  - GitHub side: `submodules/ubiquity-os-kernel` with plugin architecture; `submodules/personal-agent-bridge` forwards relevant GitHub requests to the Pi server.
  - Tooling: `submodules/codex` (reference source). Production uses the installed `codex` binary.

- Typical request path
  1) Issue/PR comment hits the GitHub App and triggers the kernel.
  2) Kernel invokes the `personal-agent-bridge` plugin.
  3) The bridge dispatches your `personal-agent` workflow (modular, forkable).
  4) The `personal-agent` calls the Pi server (LAN/VPN/tunnel) to run Codex and/or use KV.
  5) The Pi server invokes `codex` and optionally writes to `/kv`.
  6) Reply is posted on GitHub (preferably by the Pi using `gh`, or by the workflow).

- Ports and endpoints
  - Health: `/health`, `/health/live`, `/health/ready`
  - KV: `GET|PUT|DELETE /kv/<...keyParts>`, `GET /kv?prefix=...`, `POST /kv/get|/kv/list|/kv/delete`
  - Codex: `POST /api/codex`

- Notes
  - Keep Deno ≥1.44, Node ≥20 on development and Pi.
  - Ensure `codex` and `gh` are on the PATH for the systemd unit.
