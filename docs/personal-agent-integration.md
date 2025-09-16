# Personal Agent Integration

Goal: integrate your `personal-agent` repo with the Pi server so requests can be authorized, executed via Codex, and replied to on GitHub.

## Current state
- Bridge fork is unstable; original upstream was stable (simple “Hello world”).
- Valuable idea to retain: pre-LLM access control by invoking the CLI with role-based auth levels.

## Repo layout
- Already added as submodule: `submodules/personal-agent`
- Dev bootstrap: `cd submodules/personal-agent && bun install || npm i`

## Baseline commit (stable)
- Use commit `7607b28135d8bf689392cfb0586f5d95dbc9baa3` as the stable boilerplate base; later commits are experimental.
- Commands:
```
cd submodules/personal-agent
git checkout 7607b28135d8bf689392cfb0586f5d95dbc9baa3
# Optional: create an integration branch from the baseline
git switch -c pi-integration
```

## Minimal integration contract
- Pi server: `POST /api/codex { prompt, timeout_ms?, repo?, issue?|pr? }` (single ingress) and KV under `/kv`.
- Personal-agent GitHub Action (workflow_dispatch) should:
  1) Parse intent and enforce auth policy (before LLM).
  2) Build a prompt and call Pi `POST /api/codex` with `repo` and `issue/pr` so the Pi posts via `gh`.
  3) Optionally persist context in `/kv` (e.g., session, rate limits).
  4) Avoid posting from the workflow unless needed for fallback.

## Access control (recommended)
- Roles: `admin`, `trusted`, `untrusted`.
- Gate examples:
  - `admin`: allow tool-using prompts and repo writes.
  - `trusted`: allow read-only GitHub/API queries.
  - `untrusted`: allow sandboxed analysis only; strip directives for external effects.
- Example prompt wrapper:
```
role=trusted
prompt="Summarize issue #123 in bullets"
curl -sS http://pi.local:3000/api/codex \
  -H 'content-type: application/json' \
  -d "{\"prompt\": \"[role:${role}] ${prompt}\"}"
```

## Tasks to rebuild cleanly
- Define a small policy module: map GitHub user → role(s); enforce per-command capabilities.
- Implement a thin runner that constructs prompts and calls the Pi server.
- Add tests for policy, prompt shaping, and API error handling.
- Wire GitHub replies via `gh` or return messages to the kernel plugin.

## Deployment notes
- Keep secrets out of git. Store GitHub tokens in the Worker (bridge) and use systemd env for `GH_TOKEN` on the Pi if replying server-side.
- Ensure `codex` and `gh` are on PATH for the service unit.

## Example: personal-agent workflow (compute.yml)
```
name: compute
on:
  workflow_dispatch:
    inputs:
      prompt:
        description: "User prompt"
        required: true
        type: string
jobs:
  run:
    runs-on: ubuntu-latest
    steps:
      - name: Enforce access policy (placeholder)
        run: |
          echo "Role-based checks before calling Pi..."
      - name: Call Raspberry Pi Codex API (and post comment)
        env:
          PI_URL: ${{ secrets.PI_URL }} # e.g., https://pi.pavlovcik.com
        run: |
          resp=$(curl -sS -X POST "$PI_URL/api/codex" \
            -H 'content-type: application/json' \
            -d "{\"prompt\": \"${{ github.event.inputs.prompt }}\", \"repo\": \"${{ github.repository }}\", \"issue\": ${{ github.event.issue.number || github.event.pull_request.number || 0 }} }")
          echo "::group::Pi response"; echo "$resp"; echo "::endgroup::"
      # Optional: post from workflow instead of Pi-side gh
      # - uses: actions/github-script@v7
      #   with:
      #     script: |
      #       const body = 'Result ready (check Pi logs for details).';
      #       github.rest.issues.createComment({
      #         owner: context.repo.owner,
      #         repo: context.repo.repo,
      #         issue_number: context.issue.number,
      #         body,
      #       });
```
