# GitHub Integration

This project connects GitHub activity to a Raspberry Pi server that wraps the Codex CLI and a Deno KV store, with workflows as the canonical orchestration path.

## Components

- Kernel: `submodules/ubiquity-os-kernel` (TypeScript). Routes GitHub events to plugins.
- Plugin: `submodules/personal-agent-bridge` (Cloudflare Worker). On `issue_comment.created`, it parses `@username ...` and triggers the mentioned user's `personal-agent` repository workflow via `createWorkflowDispatch`.
- Pi server: `submodules/pi-agent` exposes:
  - `POST /api/codex` → runs local `codex` binary.
  - `/kv` endpoints → Deno KV-compatible storage.

Note: The current fork of `personal-agent-bridge` is unstable; the original upstream was stable (simple "Hello world" response). Keep the useful access-control gating concept, but plan to rebuild the bridge for this architecture.

## Configuration

- Kernel plugin enablement (in your repo):

```
# .github/.ubiquity-os.config.yml
plugins:
  - uses:
      - plugin: ubiquity-os-marketplace/personal-agent-bridge
```

- Bridge env (Wrangler/Worker):
  - `APP_ID`, `APP_PRIVATE_KEY` (GitHub App credentials)
  - Optional: `LOG_LEVEL`, `KERNEL_PUBLIC_KEY`
- Pi server requirements:
  - `codex` and `gh` installed and on PATH for the systemd unit.
  - `DENO_KV_PATH` points to persistent storage.

## Canonical wiring (workflows)

- Bridge dispatches a GitHub Action in the mentioned user's `personal-agent` repo. That workflow calls the Pi server via `POST /api/codex` (single ingress).
- Pi posts the comment directly via `gh` when `repo` + `issue/pr` are provided to `/api/codex`.

## Pi-side reply via gh

- Authenticate once: `gh auth login` (or set `GH_TOKEN` in the unit environment).
- Example invocation the server may run after Codex completes:

```
# comment on an issue
gh issue comment https://github.com/OWNER/REPO/issues/123 -b "${message}"
# or reply on a PR
gh pr comment https://github.com/OWNER/REPO/pull/456 -b "${message}"
```

## End-to-end flow

1. User comments `@username do X` on GitHub.
2. GitHub App routes event into the kernel.
3. Kernel triggers the bridge plugin.
4. Bridge dispatches the user's `personal-agent` workflow.
5. The workflow calls the Pi server `POST /api/codex` and/or uses `/kv`.
6. The Pi server posts the GitHub reply via `gh` (preferred), or the workflow posts it using GitHub APIs.
7. Health and traces available on the Pi: `/health/*`, `journalctl -u pi-agent-deno.service -f`.
