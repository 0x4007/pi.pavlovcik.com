# Use Cases (Milestone)

This milestone targets two capabilities powered by the Pi server and Codex.

## 1) Issue Q&A

- Input: GitHub issue context (title, body, labels, comments, links) and repository.
- Pi responsibilities:
  - Ensure repo is cloned/fetched (persistent under `/var/lib/pi-agent`).
  - Run Codex with a prompt that summarizes the issue context and relevant code paths.
  - Post answer as a GitHub comment (via `/api/gh/comment`).
- Minimal call pattern (from personal-agent workflow):

```
# Build a prompt string containing salient context, or send raw payload and let Pi shape it
curl -sS -X POST "$PI_URL/api/codex" -H 'content-type: application/json' \
  -d '{"prompt":"Analyze issue #123 in OWNER/REPO and propose a fix."}' | jq
```

## 2) Pull Request Review

- Input: PR metadata (title, body), diff/changed files, linked issues.
- Pi responsibilities:
  - Fetch PR changes (checkout or `gh pr diff`) and gather context.
  - Run Codex to produce a structured review (summary, risks, suggested fixes).
  - Post review as a PR comment.

## Notes

- Authentication: Pi maintains `gh` and repo clones (persistent). Personal agent workflows are ephemeral but pass event context and hints.
- Extensibility: Add higher-level endpoints (e.g., `/api/assist/issue`, `/api/assist/pr-review`) once prompt shaping is standardized.
