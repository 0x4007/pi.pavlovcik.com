# Personal Agent — Rapid Handoff & Debug (Improved)

Purpose
- Give an LLM (or human) a fast, reliable path to: trigger the agent via GitHub comment, watch the compute run, inspect artifacts, and debug Pi↔Codex interactions — without repo spelunking.

Highlights
- Single ingress: personal-agent only calls `POST /api/codex` with a shaped prompt; Pi derives actions from context.
- Owner-only posting: compute posts replies only when the commenter is the owner; all others are read-only.
- Rich artifacts: prompt, sanitized event, and exact Pi request body are saved per run.
 - Correlated runs: personal-agent sends `x-run-*` headers; Pi logs include a `reqId` and correlate to the GitHub run.

## Triggering a Run (Production)
- Use the newest issue in `ubiquity/.github-private`: https://github.com/ubiquity/.github-private/issues/
- Comment must start with the owner mention at the first character:
  - Example: `@0x4007 summarize recent discussion and list 3 next steps`
- Owner-only posting: if the commenter is `0x4007`, compute posts a reply; others are read-only (no comment posted).

## Monitoring & Artifacts
- List runs: `gh run list -R 0x4007/personal-agent --workflow "Personal Agent Compute"`
- Stream logs: `gh run view <id> -R 0x4007/personal-agent --log`
- Download artifacts: `gh run download <id> -R 0x4007/personal-agent -n runtime-logs-<id> -D /tmp/pa_logs_<id>`
- Artifact contents:
  - `prompt-<id>.txt` — full prompt sent to Codex
  - `pi-request-<id>.json` — exact JSON body posted to Pi `/api/codex`
  - `event-<id>.json` — decoded GitHub event payload
  - `event-sanitized-<id>.json` — event after URL-key stripping (smaller prompt)
 - Correlation:
   - personal-agent adds headers: `x-run-id`, `x-run-repo`, `x-run-attempt`, `x-agent-owner`.
   - Pi returns `{ req_id, run_id }` in the JSON and records these in logs.

## Compute Runtime (What Executes)
- Entrypoint: `node dist/index.js` in repo `0x4007/personal-agent` (no installs/builds)
  - Workflow: `submodules/personal-agent/.github/workflows/compute.yml:1`
- Runtime env (selected):
  - `AGENT_OWNER=0x4007`
  - `PI_URL` secret (public Pi endpoint, e.g., `https://pi.pavlovcik.com`)
  - `PI_TIMEOUT_MS=900000` (15m)
  - `USER_PAT_FULL`, `USER_PAT_READ` for GitHub API (owner vs non-owner)
  - Writes runtime logs: `WRITE_PROMPT_FILE=1`, `WRITE_EVENT_FILE=1`
  - Optional output cap: `POST_CHAR_CAP=1200` (default 1200, keeps last N chars)
- Code entry and handler:
  - Index/dispatch: `submodules/personal-agent/src/index.ts:37`
  - Handler: `submodules/personal-agent/src/handlers/codex-agent.ts:13`
  - HTTP client behavior: request timeout with 1 retry on network/timeout; correlation headers are attached.
  - Runtime CWD: Pi runs Codex in `PI_AGENT_WORK_DIR` (default `/var/lib/pi-agent/work`) to avoid loading repo AGENTS.md.

## Pi Server Contract (Reference)
- Route: `POST /api/codex`
- Request (selected fields):
  - `prompt` (Codex prompt), `timeout_ms`
  - `repo: "OWNER/REPO"`, `issue` or `pr` (for context/posting), `post` (server posting toggle), `mention`
  - Optional headers (from personal-agent):
    - `x-run-id` (GitHub run id), `x-run-repo` (owner/repo), `x-run-attempt`, `x-agent-owner`
- Response: `{ ok, code, output, error, posted, gh }`
  - `code=143` means Codex timeout/termination
  - Also includes `{ req_id, run_id }` for correlation when headers are provided.

## Prompting Behavior & Options
- Default: rich prompt with context; minimal prompt is available.
- Prefetch issue/PR + comments (default on): `PROMPT_FETCH_ISSUE=1`
  - Uses GitHub API from compute to fetch and embed concise issue/PR context.
- Prefetch labels (default off): `PROMPT_FETCH_LABELS=1`
  - Warning: increases payload size; keep off unless needed for label-heavy tasks.
- Include full GitHub event JSON in prompt (optional): `PROMPT_INCLUDE_EVENT=1`
  - Combine with `PROMPT_STRIP_URLS=1` (default) to remove `*_url` keys for compactness.
- Minimal smoke test: `PI_MINIMAL=1` forces prompt to be just the user command.
- Sanitized event for prompt is stored in artifacts when `WRITE_EVENT_FILE=1`.
 - Prompt-size guard: set `PROMPT_MAX_LEN` (chars). If the composed prompt exceeds this, the handler falls back to the minimal prompt automatically.

## Debug Knobs
- Write files (enabled in workflow): `WRITE_PROMPT_FILE=1`, `WRITE_EVENT_FILE=1`.
- Verbose logging (optional): `LOG_PROMPT=1`, `LOG_PI_BODY=1`, `DEBUG_EVENT=1`, `DEBUG_EVENT_RAW=1`, `LOG_PAYLOAD=1`.
- Prompt shaping toggles: `PI_MINIMAL=1`, `PROMPT_INCLUDE_EVENT=1`, `PROMPT_STRIP_URLS=1`.
 - HTTP correlation: Pi logs include `{ reqId, run: { id, repo, attempt } }` when `x-run-*` headers are present.

## Posting Policy & Sanitization (Important)
- Posting policy: compute posts only when commenter is owner (owner path).
  - Pi is called with `post:false`; all posting happens from compute on owner path.
- Sanitization of Codex output before posting:
  - Removes any line that mentions `@AGENT_OWNER` to prevent loops.
  - Drops noisy lines (transcripts/logs/markers). Removes `GH_*_OK` markers.
  - Collapses blank lines; may convert large comma lists to bullets.
  - Ensures owner handle is not re-mentioned.
- Hard-caps final comment to `POST_CHAR_CAP` (default 1200; keeps the last N chars).
  - Implementation: `submodules/personal-agent/src/handlers/codex-agent.ts:227` through `submodules/personal-agent/src/handlers/codex-agent.ts:313`.

## Token Selection (Owner vs Non-Owner)
- Owner path (full): `USER_PAT_FULL` → `PAT_FULL` → `USER_PAT` → `PLUGIN_GITHUB_TOKEN` → `GITHUB_TOKEN`
- Non-owner path (read-only): `USER_PAT_READ` → `PAT_READ` → `USER_PAT` → `PLUGIN_GITHUB_TOKEN` → `GITHUB_TOKEN`
- Reference: `submodules/personal-agent/docs/PAT-PLAN.md:1`

## Quick Validation Flow
1) Comment on the newest issue with a real prompt: `@0x4007 <request>`
2) Confirm a compute run starts in `0x4007/personal-agent` and stream logs.
3) Download artifacts and check `pi-request-<id>.json` includes:
   - `repo`, `issue`/`pr`, `post:false`, `mention:false`, `timeout_ms`
4) If no reply posted:
   - Check author: only owner triggers posting.
   - Check logs for GitHub API errors (403/404 indicate token scope or repo access issues).
   - If prompts are large/timeouts occur, try `PI_MINIMAL=1` or avoid `PROMPT_FETCH_LABELS`.

## Local & Pi Utilities (Maintainers)
- Local harness: `submodules/personal-agent/scripts/local-run.ts:1`.
- Pi sync/run helper: `submodules/personal-agent/scripts/pi-git.sh:1`.
- Pi probes and curl helpers: `submodules/personal-agent/scripts/pi-dev.sh:1`.

## Curl Smoke Tests (Pi)
- Health: `curl -sS "$PI_URL/health/ready" | jq`
- Minimal Codex: `curl -sS -X POST "$PI_URL/api/codex" -H 'content-type: application/json' -d '{"prompt":"echo hello","timeout_ms":30000}' | jq`
- Rich with repo context (no posting):
```
curl -sS -X POST "$PI_URL/api/codex" \
  -H 'content-type: application/json' \
  -H 'x-run-id: local-smoke' -H "x-run-repo: $USER/personal-agent" -H 'x-run-attempt: 1' \
  -d '{
    "prompt":"Summarize recent discussion and propose next steps",
    "repo":"OWNER/REPO",
    "issue":123,
    "post":false,
    "mention":false,
    "timeout_ms":900000
  }' | jq
```

## Manual workflow_dispatch Smoke Test (No Kernel)
- Inputs to set on the “Personal Agent Compute” workflow:
  - `eventName`: `issue_comment.created`
  - `eventPayload` (JSON):
```
{
  "comment": { "user": { "login": "0x4007" }, "body": "@0x4007 quick status summary" },
  "repository": { "name": "personal-agent", "owner": { "login": "0x4007" } },
  "issue": { "number": 1 }
}
```
- Owner path will attempt to post; for read-only test, change `login` to a non-owner.

## Troubleshooting by Symptom
- No run started:
  - Comment does not start with `@0x4007` as the first character. The handler checks prefix at `submodules/personal-agent/src/handlers/codex-agent.ts:29`.
- Pi 5xx / connection error:
  - Verify `PI_URL` is public/reachable from Actions; check Pi health `/health/ready`.
  - personal-agent now retries once on transient network/timeout; see Action logs for `Pi request id` and cross-check Pi logs.
- No comment posted:
  - Likely read-only path (non-owner), sanitize produced empty output, or GitHub API error.
- GitHub API 403/404 on comment:
  - Check PAT scopes and that the repo is permitted by the fine‑grained token.
- Codex timeout (`code=143` from Pi):
  - Ensure `PI_TIMEOUT_MS` is set; try `PI_MINIMAL=1`, keep `PROMPT_FETCH_LABELS` off, and prefer `PROMPT_STRIP_URLS=1`.

## Known Fixes
- Labels prefetch crash prevention:
  - Symptom: `ReferenceError: enablePrefetchLabels is not defined` (previous dist crash around `dist/index.js:117`).
  - Fix: labels prefetch is now guarded and disabled by default; enable via `PROMPT_FETCH_LABELS=1`.
  - Source: `submodules/personal-agent/src/handlers/codex-agent.ts:111`.
 - Sanitization minimized (prompt-first):
   - Behavior: sanitizer now only removes direct `@0x4007` mentions and `GH_*_OK` markers; no hard truncation or transcript stripping.
   - Rationale: rely on the strengthened prompt to shape the output instead of heavy post-processing.

## Cross‑Links
- Architecture: `docs/architecture.md:1`
- Integration: `docs/personal-agent-integration.md:1`
- Feedback loop (E2E): `docs/feedback-loop.md:1`
- Workflow: `submodules/personal-agent/.github/workflows/compute.yml:1`
- Index/handler: `submodules/personal-agent/src/index.ts:37`, `submodules/personal-agent/src/handlers/codex-agent.ts:13`
 - Pi server: `submodules/pi-agent/server/kv_server.ts:1`

## What To Do Right Now
- Post a real prompt: `@0x4007 <your request>` on the newest `ubiquity/.github-private` issue.
- Share the run ID to debug together; we’ll inspect artifacts and iterate.
