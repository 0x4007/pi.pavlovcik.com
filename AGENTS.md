# Repository Guidelines

## Context & Architecture

- Raspberry Pi-hosted `deno_server` on LAN; SSH with `ssh pi@pi.local`.
- REST wrapper around the Codex CLI plus a Deno KV store for state. Codex source is vendored under `submodules/codex` for reference.
- Canonical flow: GitHub App → `ubiquity-os-kernel` → `personal-agent-bridge` → `personal-agent` (workflow) → Raspberry Pi server → Codex → GitHub comment.
- Workflows are integral to the kernel’s modular, forkable design. Your `personal-agent` is a dedicated repo for your Pi-backed automation.
- Personal Agent: clone `https://github.com/0x4007/personal-agent.git` into `submodules/personal-agent` and adapt to call the Pi server. Baseline stable commit: `7607b28135d8bf689392cfb0586f5d95dbc9baa3` (post-commit changes are experimental). See `./docs/personal-agent-integration.md`.
- See `./docs/architecture.md` for diagrams and endpoint flow; ops in `./docs/raspberry-pi-ops.md`; GitHub wiring in `./docs/github-integration.md`; use cases in `./docs/use-cases.md`; E2E steps in `./docs/feedback-loop.md`.

### Primary Use Cases (Milestone)

- Single ingress: personal-agent calls Pi only via `POST /api/codex` with a rich prompt; Pi derives actions from context.
- Issue Q&A: Given an issue context, Codex provides an intelligent answer. Pi can clone/fetch code and read comments using `gh` with persistent credentials.
- PR Review: When review is requested, Codex reads the diff, related issues, and comments to produce a thoughtful review.
  Output: Post as GitHub comments (by plugin using GitHub API). Pi also exposes `/api/gh/comment` as an optional helper.

## Project Structure & Commands

- Submodules: `pi-agent` (Deno server), `personal-agent-bridge` (CF Worker), `ubiquity-os-kernel` (TypeScript kernel), `personal-agent` (user agent logic), `codex` (reference).
- Init/refresh: `git submodule update --init --recursive`.
- pi-agent (Deno ≥1.44)
  - Run: `cd submodules/pi-agent && deno run --unstable-kv --allow-net=0.0.0.0:3000 --allow-run --allow-env=DENO_KV_PATH --allow-read=public,/var/lib/pi-agent --allow-write=/var/lib/pi-agent server/kv_server.ts`
  - Persist KV: `export DENO_KV_PATH=/var/lib/pi-agent/kv.sqlite3`.
- personal-agent-bridge (Node ≥20): `cd submodules/personal-agent-bridge && npm i && npm test && npm run worker`
- ubiquity-os-kernel (Node ≥20): `cd submodules/ubiquity-os-kernel && npm i && npm run dev && npm run jest:test`
- Optional: `npm i -g @openai/codex` or `brew install codex`.

## Ops Quickstart (Production)

- SSH: `ssh pi@pi.local`. Systemd unit: `pi-agent-deno.service`.
- Common actions: `journalctl -u pi-agent-deno.service -f`, `sudo systemctl restart pi-agent-deno.service`, health: `curl http://pi.local:3000/health/ready`.
- Full details: `./docs/raspberry-pi-ops.md` and `submodules/pi-agent/docs/os-server-setup.md`.

## Style, Tests, and PRs

- 2-space indent; ESLint + Prettier where present (`npm run format`). Tests live per module (Jest for Node; Deno tests as added).
- Use Conventional Commits (`feat:`, `fix:`, `chore:`). PRs should link issues and include evidence (logs/cURL or screenshots) and any config changes.

## Security & Config

- No secrets in git. Use `.env` (Node) and systemd env for prod. Ensure `PATH` exposes `codex` and `gh`. Keep `DENO_KV_PATH` on persistent storage.
