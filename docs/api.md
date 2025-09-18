# HTTP API

## Health

- `GET /health` — detailed server info.
- `GET /health/live` — liveness probe.
- `GET /health/ready` — readiness with KV check.

## Codex Wrapper (single ingress)

- `POST /api/codex`
  - Body:
    - `prompt: string` or `comment|raw_comment: string` (one required)
    - `timeout_ms?: number`
    - `repo?: "OWNER/REPO"`, `issue?: number` or `pr?: number` — when provided, the server posts the result as a GitHub comment via `gh` (no extra API needed)
    - `post?: boolean` — defaults to true when `repo` and target are provided
    - `mention?: string | false` — when posting, prefix the body with this handle (e.g., `@0x4007`). If omitted, uses `PI_AGENT_MENTION` or `AGENT_OWNER`, falling back to `@0x4007`. Set `false` to disable.
  - Returns: `{ ok, code, output, error?, posted: boolean, gh?: { code, output, error? } }`
  - Example (run + post to an issue):

```
curl -sS -X POST http://pi.local:3000/api/codex \
  -H 'content-type: application/json' \
  -d '{"prompt":"Summarize the issue context","repo":"OWNER/REPO","issue":123}' | jq
```

- Example (raw post to trigger kernel):

```
curl -sS -X POST http://pi.local:3000/api/codex \
  -H 'content-type: application/json' \
  -d '{"comment":"create a new github issue called hello world in this repo","repo":"OWNER/REPO","issue":123,"mention":"@0x4007"}' | jq
```

## KV Store

- Path-based CRUD
  - `GET /kv/<...keyParts>` → `{ value, versionstamp }`
  - `PUT /kv/<...keyParts>` body `{ value, expireIn? }` → `{ ok, versionstamp }`
  - `DELETE /kv/<...keyParts>` → `{ ok }`
- List and JSON helpers
  - `GET /kv?prefix=[...]&limit=&cursor=` → `{ entries[], cursor }`
  - `POST /kv/get|/kv/delete|/kv/list` with JSON body
- Examples:

```
# Set
curl -sS -X PUT http://pi.local:3000/kv/app/config \
  -H 'content-type: application/json' -d '{"value": {"mode":"dev"}}' | jq
# Get
curl -sS http://pi.local:3000/kv/app/config | jq
# List under prefix
curl -sS 'http://pi.local:3000/kv?prefix=["app"]&limit=50' | jq
```

Note: There is no separate endpoint for posting comments — `/api/codex` handles it when context is provided.
