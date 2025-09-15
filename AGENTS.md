# Repository Guidelines

## Project Structure & Module Organization
- Root hosts Git submodules under `submodules/`:
  - `submodules/pi-agent` — Deno KV HTTP server and static site.
  - `submodules/personal-agent-bridge` — Cloudflare Worker plugin bridging to personal agents.
  - `submodules/ubiquity-os-kernel` — Core UbiquityOS kernel (TypeScript).
  - `submodules/codex` — OpenAI Codex CLI (vendor, optional for local tooling).
- Initialize/refresh submodules: `git submodule update --init --recursive`.

## Build, Test, and Development Commands
- pi-agent (Deno ≥1.44)
  - Run: `cd submodules/pi-agent && deno run --unstable-kv --allow-net=0.0.0.0:3000 --allow-run --allow-env=DENO_KV_PATH --allow-read=public,/var/lib/pi-agent --allow-write=/var/lib/pi-agent server/kv_server.ts`
  - Optional: `export DENO_KV_PATH=/var/lib/pi-agent/kv.sqlite3` for persistence.
- personal-agent-bridge (Node ≥20)
  - Install: `cd submodules/personal-agent-bridge && npm i`
  - Dev worker: `npm run worker` (Wrangler dev)
  - Build/Test: `npm run build` · `npm test`
- ubiquity-os-kernel (Node ≥20)
  - Install: `cd submodules/ubiquity-os-kernel && npm i`
  - Dev: `npm run dev` (worker+proxy) · Build: `npm run build`
  - Tests: `npm run jest:test`
- Codex CLI (optional): `npm i -g @openai/codex` or `brew install codex`.

## Coding Style & Naming Conventions
- TypeScript/Deno: 2-space indent; prefer explicit types for public APIs.
- Lint/format where provided: `npm run format` (or `eslint --fix` / `prettier --write .`).
- File naming: use kebab-case for folders/files; tests as `*.test.ts` under `tests/` when applicable.

## Testing Guidelines
- Frameworks: Jest in Node projects; Deno apps may add `Deno.test` later.
- Run tests per module (see commands above). Aim for meaningful coverage; add unit tests with clear Arrange–Act–Assert structure.

## Commit & Pull Request Guidelines
- Commit style: Conventional Commits (e.g., `feat:`, `fix:`, `chore:`). Both Node modules include commitlint.
- PRs: include a concise description, linked issues, test evidence (logs/screenshots of endpoints like `/health` or `/kv`), and note any config changes.

## Security & Configuration Tips
- Never commit secrets. Use `.env` for Node modules and `DENO_KV_PATH` for Deno storage.
- Review `wrangler.toml` and `config/` files before deploying. Limit credentials to required scopes.
