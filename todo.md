# TODO — Claude Code Action Parity and Improvements

This backlog is ordered by priority. Each item includes the target files and success criteria.

## P0 — Immediate

- Stop self-mention loops
  - Files: `submodules/personal-agent/src/handlers/codex-agent.ts`
  - Change: when not intentionally mentioning, pass `mention: false` instead of empty string to Pi.
  - Success: Pi posts without leading mentions unless explicitly requested; no re-trigger loops.

- Ignore self-authored comments
  - Files: `submodules/personal-agent/src/handlers/codex-agent.ts`
  - Change: early return if `payload.comment.user.login === env.AGENT_OWNER`.
  - Success: agent does not respond to its own comments.

- Permission and actor validation
  - Files: `submodules/personal-agent/src/handlers/codex-agent.ts`
  - Change: before any write-capable path, verify human actor and write/admin permission; optionally allow specific users via env allowlist.
  - Success: write actions are gated; read-only analyses still allowed.

- PR-optimized prompt
  - Files: `submodules/personal-agent/src/handlers/codex-agent.ts`
  - Change: when `isPR`, include structured review instructions (correctness, tests, security, actionable diffs) in the prompt.
  - Success: higher-quality PR reviews with consistent structure.

- Error surface with correlation ID
  - Files: `submodules/personal-agent/src/handlers/codex-agent.ts`, `submodules/pi-agent/server/kv_server.ts`
  - Change: attach `correlation_id` to `/api/codex` request/response; log in JSONL.
  - Success: GitHub comments and logs reference the same ID when failures occur.

## P1 — Near Term

- Sticky tracking comment via KV
  - Files: `submodules/pi-agent/server/kv_server.ts`
  - Change: `/api/codex` accepts `sticky: true`; upsert a single comment per entity, return `comment_id`.
  - Success: one progress comment per PR/issue is created and updated.

- Enrich `/api/codex` response
  - Files: `submodules/pi-agent/server/kv_server.ts`
  - Change: return `{ comment_id?, branch?, pr_number? }` where applicable.
  - Success: client can display/act on returned identifiers.

- Workspace lifecycle and branch/PR workflow
  - Files: `submodules/pi-agent/server/kv_server.ts` (new helper modules), `docs/raspberry-pi-ops.md` (ops notes)
  - Change: manage `/var/lib/pi-agent/workspaces/<owner>__<repo>` with `git fetch`; implement `POST /api/implement` for code changes and PR workflow.
  - Success: consistent branch prefixes (`codex/`), PR opened/updated automatically, commits appear under configured identity.

- Concurrency control
  - Files: `submodules/pi-agent/server/kv_server.ts`
  - Change: KV lock keyed by `owner/repo:<entity>`; on contention, skip or enqueue and reflect status in sticky comment.
  - Success: no overlapping runs for the same entity.

- GitHub data prefetch
  - Files: `submodules/pi-agent/server/kv_server.ts`
  - Change: prefetch `gh pr view --json files,reviewDecision,latestReviews` (and optional `gh pr diff --patch`) and prepend a compact context capsule to the prompt.
  - Success: fewer shell calls inside Codex; faster, more informed responses.

## P2 — Advanced

- Mode detection and registry
  - Files: `submodules/personal-agent/src/index.ts` (routing), new `submodules/personal-agent/src/modes/*`
  - Change: introduce tag vs agent modes with per-mode prompt shaping and capability controls.
  - Success: flexible triggers (mention/label/assignee) with sticky comment in tag mode; direct automation in agent mode.

- Commit signing path
  - Files: `submodules/pi-agent/server/kv_server.ts` (PR workflow), docs
  - Change: implement a “commit signing” path (or MCP file ops) for controlled commits when required.
  - Success: signed commits and/or MCP file operations available per policy.

- Tool/network restrictions
  - Files: Pi shell wrappers and docs
  - Change: enforce an allowlist for shell commands and optionally restrict outbound network (PATH shim or wrapper shell).
  - Success: Codex stays within approved tools and hosts.

- Streaming / SSE
  - Files: `submodules/pi-agent/server/kv_server.ts`
  - Change: add `/api/codex/stream?id=…` that streams progress; correlate with JSONL records.
  - Success: live progress in dashboards or logs.

## Acceptance Criteria (Per Priority Tier)

- P0
  - No self-trigger loops, no self-replies, permission-guarded writes, improved PR prompt.

- P1
  - Sticky comments, enriched API responses, stable workspace/branch/PR flow, concurrency locks, GH data prefetch.

- P2
  - Mode registry, signing/MCP path, tool/network constraints, streaming progress.

## Notes

- Changes are additive and backward compatible; feature flags or env toggles can gate new behavior during rollout.
- Keep secrets off disk; rely on `gh` auth on Pi and workflow-provided tokens where needed.
