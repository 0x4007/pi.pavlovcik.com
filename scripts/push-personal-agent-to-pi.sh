#!/usr/bin/env bash
set -Eeuo pipefail

# Sync submodules/personal-agent to the Pi, commit to branch, push, and open a PR to development.

PI_USER=${PI_USER:-pi}
PI_HOST=${PI_HOST:-pi.local}
PI_SSH="${PI_USER}@${PI_HOST}"
REMOTE_REPO_DIR=${REMOTE_REPO_DIR:-/home/pi/repos/personal-agent}
BRANCH=${BRANCH:-pi-integration}
BASE_BRANCH=${BASE_BRANCH:-development}

LOCAL_DIR="submodules/personal-agent"

if [[ ! -d "$LOCAL_DIR/.git" && ! -f "$LOCAL_DIR/package.json" ]]; then
  echo "Error: $LOCAL_DIR does not look like a repo checkout." >&2
  exit 1
fi

TMP_TAR=$(mktemp -t pa-XXXXXX.tar.gz)
trap 'rm -f "$TMP_TAR"' EXIT

echo "Creating tarball of $LOCAL_DIR (excluding .git) ..."
tar -C "$LOCAL_DIR" -czf "$TMP_TAR" --exclude .git .

echo "Ensuring remote repo at $REMOTE_REPO_DIR ..."
ssh "$PI_SSH" "mkdir -p '$REMOTE_REPO_DIR' || true"

echo "Uploading payload ..."
scp "$TMP_TAR" "$PI_SSH:/tmp/personal-agent.tar.gz"

echo "Preparing repository on Pi ..."
ssh "$PI_SSH" bash -lc "\
  set -Eeuo pipefail; \
  if [[ ! -d '$REMOTE_REPO_DIR/.git' ]]; then \
    rm -rf '$REMOTE_REPO_DIR' && mkdir -p '$REMOTE_REPO_DIR'; \
    gh repo clone 0x4007/personal-agent '$REMOTE_REPO_DIR'; \
  else \
    cd '$REMOTE_REPO_DIR' && git fetch origin --prune; \
  fi; \
  cd '$REMOTE_REPO_DIR'; \
  git checkout '$BASE_BRANCH' || git checkout -b '$BASE_BRANCH'; \
  git pull --ff-only origin '$BASE_BRANCH' || true; \
  git checkout -B '$BRANCH'; \
  tar -xzf /tmp/personal-agent.tar.gz -C '$REMOTE_REPO_DIR'; \
  git add -A; \
  if ! git diff --cached --quiet; then \
    git commit -m 'feat: Pi integration (Codex handler + compute workflow updates)'; \
  fi; \
  git push -u origin '$BRANCH'; \
  # Open or update PR to development
  if ! gh pr view --repo 0x4007/personal-agent --head '$BRANCH' >/dev/null 2>&1; then \
    gh pr create --repo 0x4007/personal-agent --head '$BRANCH' --base '$BASE_BRANCH' --title 'Pi integration: Codex handler + compute.yml' --body 'This merges the Pi Codex handler and workflow updates into development.'; \
  fi; \
  gh pr view --repo 0x4007/personal-agent --head '$BRANCH'; \
"

echo "If ready, merge the PR:
  ssh $PI_SSH 'cd $REMOTE_REPO_DIR && gh pr merge --merge --auto'
"

