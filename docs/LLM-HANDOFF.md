# Personal Agent — Rapid Handoff & Debug Guide

Purpose
- Give an LLM (or human) everything needed to: invoke the agent via GitHub comment, monitor compute runs, read runtime artifacts, and debug Pi/Codex interactions — without browsing the repo.

What You’ll Do
- Comment on the latest issue in ubiquity/.github-private to trigger the agent.
- Watch the run in 0x4007/personal-agent, inspect artifacts, and iterate quickly.
- If anything looks off, use the checklists below to pinpoint the cause.

Triggering a Run (Production)
- Always use the newest issue: https://github.com/ubiquity/.github-private/issues/
- Comment MUST start with the owner mention at the first character:
  - Example: `@0x4007 summarize recent discussion and list 3 next steps`
- Owner-only posting: if the commenter is `0x4007`, compute posts a reply; all others are read-only (no comment posted).

Monitoring & Artifacts
- List runs: `gh run list -R 0x4007/personal-agent --workflow "Personal Agent Compute"`
- Follow logs: `gh run view <id> -R 0x4007/personal-agent --log`
- Download runtime artifacts: `gh run download <id> -R 0x4007/personal-agent -n runtime-logs-<id> -D /tmp/pa_logs_<id>`
- Artifact contents:
  - `prompt-<id>.txt` — full prompt sent to Codex
  - `pi-request-<id>.json` — exact JSON body posted to Pi `/api/codex`
  - `event-<id>.json` — decoded GitHub event payload

Compute Runtime (What Executes)
- Entry: `node dist/index.js` in repo `0x4007/personal-agent` (no installs/builds).
  - File: submodules/personal-agent/.github/workflows/compute.yml:1
- Runtime environment:
  - `AGENT_OWNER=0x4007`
  - `PI_URL` secret (public Pi endpoint, e.g., https://pi.pavlovcik.com)
  - `PI_TIMEOUT_MS=900000` (15m)
  - `USER_PAT_FULL`, `USER_PAT_READ` for GitHub API (owner vs non-owner)
- The code decodes `eventPayload` and calls handler:
  - File: submodules/personal-agent/src/index.ts:1
  - Handler: submodules/personal-agent/src/handlers/codex-agent.ts:13

Pi Server Contract (reference)
- Route: `POST /api/codex`
- Request (selected fields):
  - `prompt` (runs `codex exec <prompt>`), or `raw_comment`/`comment` to bypass Codex
  - `repo: "OWNER/REPO"`, `issue` or `pr`, `post: boolean`, `mention`, `timeout_ms`
- Response: `{ ok, code, output, error, posted, gh }` (`code=143` means Codex timeout/termination)

Prompting Behavior (Handler)
- Rich prompt by default; minimal prompt optional.
- Prefetches issue/PR + comments to embed into the prompt.
  - Toggle: `PROMPT_FETCH_ISSUE=1` (default on)
- Optional labels prefetch (OFF by default to keep payload small):
  - Toggle: `PROMPT_FETCH_LABELS=1`
  - If enabled and available, appends labels to the prompt.
- Posting policy: server posting is disabled (`post:false`); compute posts a sanitized reply for owner only.
- Key file references:
  - Build prompt, call Pi, post back: submodules/personal-agent/src/handlers/codex-agent.ts:13
  - Labels prefetch toggle/guard: submodules/personal-agent/src/handlers/codex-agent.ts:111

Secrets & Tokens
- `PI_URL` must be a public URL reachable from GitHub Actions (not `http://pi.local`).
- Token precedence:
  - Owner: `USER_PAT_FULL` → `PAT_FULL` → `USER_PAT` → `PLUGIN_GITHUB_TOKEN` → `GITHUB_TOKEN`
  - Others: `USER_PAT_READ` → `PAT_READ` → `USER_PAT` → `PLUGIN_GITHUB_TOKEN` → `GITHUB_TOKEN`
- Reference doc: submodules/personal-agent/docs/PAT-PLAN.md:1

Debug Knobs (set as env in the run)
- Write files (enabled): `WRITE_PROMPT_FILE=1`, `WRITE_EVENT_FILE=1`
- Verbose logging (optional): `LOG_PROMPT=1`, `LOG_PI_BODY=1`, `DEBUG_EVENT=1`, `DEBUG_EVENT_RAW=1`
- Prompt options: `PI_MINIMAL=1`, `PROMPT_INCLUDE_EVENT=1`, `PROMPT_STRIP_URLS=1`

Quick Validation Flow
1) Create/comment on the newest issue with a real prompt: `@0x4007 <request>`
2) Confirm a compute run starts in `0x4007/personal-agent` (watch logs).
3) Download artifacts and open `pi-request-<id>.json` to verify:
   - `repo`, `issue`/`pr`, `post:false`, `mention:false`, `timeout_ms`
4) If no reply posted:
   - Check comment author (owner-only posting), and logs for GitHub API errors.
   - Inspect prompt for size; consider turning on/off `PROMPT_FETCH_*` if Codex timeouts occur.

Common Pitfalls & Fixes
- Kernel dispatch gating: the comment must start with `@0x4007` (no leading spaces).
- Codex timeout (Pi returns `code=143`):
  - Confirm `PI_TIMEOUT_MS` present; rich prompts can be large.
  - If needed, temporarily try `PI_MINIMAL=1` for a smoke check, then revert to rich.
- Owner-only posting: non-owner runs are read-only; no comment is posted by compute.
- New fix applied (compute crash prevention):
  - Symptom: “ReferenceError: enablePrefetchLabels is not defined” at dist/index.js:117.
  - Change: guarded optional labels prefetch, OFF by default.
  - Source ref: submodules/personal-agent/src/handlers/codex-agent.ts:111
  - Dist is updated; branch: `development`, latest short SHA contains this fix.

Local & Pi Utilities (for maintainers)
- Local harness (Bun): submodules/personal-agent/scripts/local-run.ts:1
- Pi sync/run: submodules/personal-agent/scripts/pi-git.sh:1
- Pi probes/curl: submodules/personal-agent/scripts/pi-dev.sh:1

What To Do Right Now (Real Prompt Path)
- Post a real prompt starting with `@0x4007` on the newest issue in ubiquity/.github-private.
- Share the run ID for debugging; we’ll inspect artifacts and iterate.

If Something Fails
- Check that `PI_URL` is set to a public endpoint and the Pi is healthy (`/health/ready`).
- Verify tokens: `PAT_FULL` and `PAT_READ` are present.
- Confirm owner vs non-owner path and that sanitize didn’t empty the reply.
- Enable debug knobs (`LOG_PROMPT=1`, `LOG_PI_BODY=1`, `DEBUG_EVENT=1`) for one run and re-check artifacts.

