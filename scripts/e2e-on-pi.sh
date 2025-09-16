#!/usr/bin/env bash
set -Eeuo pipefail

# Run on the Pi to create a test repo, open an issue, call the Pi /api/codex,
# and verify that a comment is posted. Requires: gh auth, git configured.

OWNER=${OWNER:-0x4007}
REPO=${REPO:-pi-e2e-test}

ensure_repo() {
  if gh repo view "$OWNER/$REPO" >/dev/null 2>&1; then
    echo "Using existing $OWNER/$REPO"
    return 0
  fi
  echo "Creating single E2E repo $OWNER/$REPO ..."
  gh repo create "$OWNER/$REPO" --private -d "Single Pi/Codex E2E sandbox (reused for all tests)" --confirm
  mkdir -p "$HOME/tmp/$REPO/.github"
  cd "$HOME/tmp/$REPO"
  cat > .github/.ubiquity-os.config.yml <<'YAML'
plugins:
  - uses:
      - plugin: ubiquity-os-marketplace/personal-agent-bridge
YAML
  echo "# $REPO" > README.md
  git init -b main >/dev/null
  git remote add origin "https://github.com/$OWNER/$REPO.git"
  git add .
  git commit -m "chore: enable personal-agent-bridge for tests" >/dev/null
  git push -u origin main >/dev/null
}

main() {
  ensure_repo

  local issue_url issue_num
  issue_url=$(gh issue create -R "$OWNER/$REPO" -t "E2E test $(date --iso-8601=seconds)" -b "Test end-to-end with Pi Codex. Reused repo; separate tests use separate issues.")
  issue_num=${issue_url##*/}
  echo "Issue: $issue_num ($issue_url)"

  # Trigger Pi Codex to post a comment. Use raw comment to exercise kernel.
  local json
  json=$(printf '{"comment":"%s","repo":"%s/%s","issue":%s,"post":true,"mention":"@0x4007"}' \
    "create a new github issue called hello world in this repo" "$OWNER" "$REPO" "$issue_num")
  echo "POST /api/codex (raw) => $json"
  curl -sS -X POST http://127.0.0.1:3000/api/codex -H 'content-type: application/json' -d "$json" | jq -C . || true

  echo "--- Recent logs"
  tail -n 5 /var/lib/pi-agent/logs/codex-$(date +%F).jsonl || true
  echo "--- Latest snapshot"
  sed -n '1,120p' /var/lib/pi-agent/logs/codex-latest.json || true

  echo "--- Issue comments"
  gh issue view -R "$OWNER/$REPO" "$issue_num" --comments || true

  echo "--- Checking for created issue titled 'hello world' (may take a moment)"
  sleep 5 || true
  gh issue list -R "$OWNER/$REPO" --limit 10 --search 'hello world in:title' || true
}

main "$@"
