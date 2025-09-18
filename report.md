# Claude Code Action — Comparative Research and Integration Recommendations

This document summarizes key capabilities from `anthropics/claude-code-action`, maps them to our current architecture (`personal-agent` + `pi-agent`), and proposes targeted improvements with concrete integration points.

## Executive Summary

- Claude Code Action provides two modes (tag/agent), robust trigger detection, permission/actor validation, sticky tracking comments, and structured branch/PR workflows with MCP tool gating.
- Our current flow is streamlined: `personal-agent` parses issue comments for an `@AGENT_OWNER` mention, shapes a prompt, and calls the Pi server `/api/codex` (which shells to the `codex` CLI). Posting typically occurs Pi-side via `gh`.
- Immediate fixes: prevent self-mention loops, ignore self-authored comments, add write-permission checks for write actions, broaden triggers, and improve PR prompts.
- Medium-term: sticky tracking comments persisted via KV, workspace management + branch/PR operations, enriched `/api/codex` contract, concurrency locks, and GH data prefetch.
- Long-term: full tag/agent mode parity, commit signing, network/tool restrictions, and test coverage.

---

## Claude Code Action — Architecture & Capabilities

- Triggers and modes
  - Tag mode: Responds to @mention, label, assignee; creates and updates a sticky tracking comment; manages branches/PRs.
  - Agent mode: Direct “automation” execution when a `prompt` is provided (bypasses tag heuristics) with minimal tracking.
  - Code references:
    - Entry prepare: `submodules/claude-code-action/src/entrypoints/prepare.ts:1`
    - Mode registry: `submodules/claude-code-action/src/modes/registry.ts` (auto-detection)
    - Tag mode: `submodules/claude-code-action/src/modes/tag/index.ts:1`
    - Agent mode: `submodules/claude-code-action/src/modes/agent/index.ts:1`

- Permission and actor validation
  - Validates human actor; checks write/admin permission, with an allowlisted escape hatch.
  - Code reference: `submodules/claude-code-action/src/github/validation/permissions.ts:1`

- Tracking comments (sticky)
  - Creates a single progress comment and updates it as the run advances. Links back to the job.
  - Update link entrypoint: `submodules/claude-code-action/src/entrypoints/update-comment-link.ts:1`

- Branch and PR management
  - Sets up a working branch (configurable prefix), handles PR creation/update, and supports commit signing paths.
  - Code references in tag mode: branch setup and required tools at `submodules/claude-code-action/src/modes/tag/index.ts:117`

- MCP tools / Allowed tools gating
  - Generates MCP config and explicitly enumerates allowed tools depending on mode and signing settings.
  - Code reference: MCP config `submodules/claude-code-action/src/mcp/install-mcp-server.ts`

- Provider and environment setup
  - Supports Anthropic direct API, Bedrock, Vertex; installs `bun` and `claude` CLI dynamically.
  - Workflow definition: `submodules/claude-code-action/action.yml:1`

- Network restrictions (experimental)
  - Optional allowlist for outbound domains via wrapper script.

---

## Our System — Current Behavior

- Personal Agent
  - Entry and dispatch: `submodules/personal-agent/src/index.ts:1` (currently supports `issue_comment.created`).
  - Codex path: `submodules/personal-agent/src/handlers/codex-agent.ts:1`
    - Checks `@AGENT_OWNER` prefix, builds a rich prompt, and calls Pi `/api/codex`.
    - Default behavior prefers Pi-side posting via `gh` for persistent auth.
    - Sanitizes output if posting client-side and strips leading mentions.
  - Claude path: `submodules/personal-agent/src/handlers/claude-agent.ts:1` (experimental)
    - Spawns `claude` CLI locally in the runner and posts output.
  - Bridge to invoke personal-agent: `submodules/personal-agent-bridge/src/handlers/call-personal-agent.ts:1`.

- Pi Agent (Deno server)
  - KV API + REST Codex wrapper: `submodules/pi-agent/server/kv_server.ts:1`
  - `/api/codex` accepts `{ prompt | raw_comment, repo?, issue?|pr?, post?, timeout_ms?, mention? }`.
  - Runs `codex exec <prompt>`, optionally posts to GitHub using `gh`.
  - Mention fallback logic uses `PI_AGENT_MENTION` → `AGENT_OWNER` → `@0x4007` default; see `submodules/pi-agent/server/kv_server.ts:312`.
  - Structured JSONL logging and a “latest” file per day under `/var/lib/pi-agent/logs`.

---

## Gaps vs. Claude Code Action

1. Trigger surface and modes
   - We currently only react to explicit `@AGENT_OWNER` in issue comments. No label/assignee triggers, no PR review auto-mode, and no explicit agent mode switch.

2. Permission and actor validation
   - No enforcement of human actor or write permissions prior to write-capable behaviors.

3. Tracking comments
   - No built-in sticky comment that updates through the run.

4. Branch/PR workflow and commit signing
   - We do not have a standardized workspace lifecycle, branch prefixing, PR creation/update, or opt-in commit signing path.

5. Tool/network gating
   - Codex prompt indicates using `gh`, but there is no explicit allowlist or network confinement.

6. API semantics and observability
   - `/api/codex` lacks correlation IDs, comment IDs in responses, and a “sticky” upsert primitive.
   - No streaming endpoint or SSE for progress.

7. Self-trigger loop risk
   - Client sends empty `mention` (not `false`), server falls back to `@AGENT_OWNER`, likely causing re-invocation.

8. Performance and context hydration
   - LLM often shells out to `gh` for PR context; server could prefetch common views and provide a compact context capsule to reduce cycles.

---

## Targeted Improvements (Design)

### Immediate (P0)

- Stop self-mention loops
  - Client: pass `mention: false` when mention is not desired (change at `submodules/personal-agent/src/handlers/codex-agent.ts:90`).
  - Server: treat empty string as “no mention” to be robust (optional hardening at `submodules/pi-agent/server/kv_server.ts:312`).

- Ignore self-authored comments
  - Early return if `payload.comment.user.login === AGENT_OWNER` to avoid recursive triggers (codex agent entry).

- Write-permission check and human actor validation
  - For write-capable runs (branch/PR, file writes), require write/admin permissions or allowlist override.
  - Pattern after `submodules/claude-code-action/src/github/validation/permissions.ts:1`.

- PR-optimized prompt
  - Inject structured review guidance when `isPR`, including: correctness, tests impacted/missing, security notes, and actionable diffs.

### Medium (P1)

- Sticky tracking comment with KV
  - Add a KV-upserted sticky comment (single comment per PR/issue) with progress updates and job link.
  - Server adds an optional `sticky: true` flag in `/api/codex`, returning `comment_id`.

- Enriched `/api/codex` contract
  - Inputs: `sticky`, `mention`, `correlation_id`, `mode`.
  - Outputs: `comment_id`, `branch`, `pr_number` (when applicable).

- Workspace lifecycle and branch/PR management
  - Maintain per-repo workspaces under `/var/lib/pi-agent/workspaces`, fetch instead of reclone, standardize branch prefix `codex/`.
  - Add `POST /api/implement` for code changes: create branch → run codex edits → commit → push → open/update PR → post to sticky.

- Concurrency locks
  - KV-based locks keyed by `owner/repo:<entity>` to avoid overlapping runs; skip or queue with a note in sticky comment.

- GitHub data prefetch
  - On `/api/codex` with `repo`+`pr`, prefetch `gh pr view --json files,reviewDecision,latestReviews` and optionally `gh pr diff --patch`. Append a compact capsule to the prompt.

### Advanced (P2)

- Mode detection and registry
  - Add tag vs agent mode in `personal-agent`, mirroring Claude’s `getMode()` split, with per-mode prompt and tool gating.

- Commit signing opt-in
  - Support a path where edits use MCP file ops and server-side signing, mirroring Claude’s “use_commit_signing.”

- Tool/network restrictions
  - Explicit allowed commands and optional outbound network allowlist for Codex runs (PATH shims or shell wrapper).

- Streaming/SSE
  - `/api/codex/stream?id=…` to watch progress; combine with JSONL records and correlation IDs.

---

## Security Considerations

- Pre-LLM policy enforcement: actor is human, permissions sufficient for requested capabilities.
- Avoid self-trigger loops: suppress `@AGENT_OWNER` mentions if the client intends to post itself or if Pi will post without mention.
- Limit tools: instruct Codex to use `gh`, `git`, and local shell only; discourage external network by policy and optional enforcement.
- Secrets: no tokens in prompts or logs; prefer `gh` device/app auth on Pi.

---

## Observability & Ops

- Correlation IDs in every request/response and JSONL logs; surface the ID to GitHub comments on errors.
- Structured error replies including HTTP status, CLI exit codes, and a “Retry” instruction.
- Health and readiness endpoints exist; add progress and last-run state via KV keys and static pages (optional).

---

## Compatibility & Migration

- Maintain current `/api/codex` shape; introduce additive fields (`sticky`, `correlation_id`, `comment_id`) and defaults.
- Ship the client mention fix and self-comment ignore without changing server behavior.
- Incrementally add workspace/branch features behind a feature flag or `mode: "implement"`.

---

## Key Code References (Clickable)

- Personal Agent
  - Entry: `submodules/personal-agent/src/index.ts:1`
  - Codex agent: `submodules/personal-agent/src/handlers/codex-agent.ts:1`
  - Claude agent: `submodules/personal-agent/src/handlers/claude-agent.ts:1`
  - Supported events: `submodules/personal-agent/src/types/context.ts:12`
  - Bridge dispatcher: `submodules/personal-agent-bridge/src/handlers/call-personal-agent.ts:1`

- Pi Agent
  - Server: `submodules/pi-agent/server/kv_server.ts:1`
  - Mention fallback: `submodules/pi-agent/server/kv_server.ts:312`

- Claude Code Action
  - Workflow: `submodules/claude-code-action/action.yml:1`
  - Prepare entrypoint: `submodules/claude-code-action/src/entrypoints/prepare.ts:1`
  - Tag mode: `submodules/claude-code-action/src/modes/tag/index.ts:1`
  - Agent mode: `submodules/claude-code-action/src/modes/agent/index.ts:1`
  - Permissions check: `submodules/claude-code-action/src/github/validation/permissions.ts:1`
  - Update comment link: `submodules/claude-code-action/src/entrypoints/update-comment-link.ts:1`
