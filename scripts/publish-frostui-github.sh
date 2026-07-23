#!/usr/bin/env bash
# Push the full lws-ui repository to GitHub (mirror of a local branch).
#
# Usage:
#   ./scripts/publish-frostui-github.sh [source-branch] [remote-url]
#
# Defaults:
#   source-branch = current branch (or frost-ui)
#   remote-url    = git@github.com:feng268050-ctrl/frostui.git
#   target branch on GitHub = main
#
# Env:
#   FROSTUI_GITHUB_BRANCH   target branch on GitHub (default: main)
#   FROSTUI_GITHUB_FORCE=1  force push when histories diverge
#
# Requires: git; GitHub SSH key or HTTPS credentials.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_BRANCH="${1:-$(git -C "$ROOT_DIR" rev-parse --abbrev-ref HEAD)}"
REMOTE_URL="${2:-git@github.com:feng268050-ctrl/frostui.git}"
TARGET_BRANCH="${FROSTUI_GITHUB_BRANCH:-main}"

die() { echo "ERROR: $*" >&2; exit 1; }

command -v git >/dev/null 2>&1 || die "git not found"
git -C "$ROOT_DIR" rev-parse --verify "$SOURCE_BRANCH" >/dev/null 2>&1 \
  || die "branch not found: $SOURCE_BRANCH"

if ! git -C "$ROOT_DIR" diff --quiet || ! git -C "$ROOT_DIR" diff --cached --quiet; then
  echo "WARNING: lws-ui has uncommitted changes; GitHub will receive last commit on $SOURCE_BRANCH only." >&2
  git -C "$ROOT_DIR" status -sb >&2 || true
fi

if git -C "$ROOT_DIR" remote get-url github >/dev/null 2>&1; then
  git -C "$ROOT_DIR" remote set-url github "$REMOTE_URL"
else
  git -C "$ROOT_DIR" remote add github "$REMOTE_URL"
fi

SOURCE_COMMIT="$(git -C "$ROOT_DIR" rev-parse "$SOURCE_BRANCH")"
echo "INFO: pushing full lws-ui $SOURCE_BRANCH@${SOURCE_COMMIT:0:8} -> github/$TARGET_BRANCH ($REMOTE_URL)"

PUSH_ARGS=(-u github "${SOURCE_BRANCH}:${TARGET_BRANCH}")
if [[ "${FROSTUI_GITHUB_FORCE:-0}" == "1" ]]; then
  PUSH_ARGS=(--force "${PUSH_ARGS[@]}")
fi

if ! git -C "$ROOT_DIR" push "${PUSH_ARGS[@]}"; then
  echo "INFO: push rejected; retry with FROSTUI_GITHUB_FORCE=1 if you intend to overwrite GitHub." >&2
  exit 1
fi

echo "OK: full project published to $REMOTE_URL ($TARGET_BRANCH)"
