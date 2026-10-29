#!/usr/bin/env bash
# Packages the committed plugin as klearframe-agent-team-<version>.plugin for the claude.ai upload.
# Run from anywhere: bash scripts/package.sh. Files marked export-ignore in .gitattributes stay out.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ -n "$(git status --porcelain)" ]; then
  echo "Commit or stash your changes first: the package is built from HEAD." >&2
  exit 1
fi
version=$(jq -r .version .claude-plugin/plugin.json)
out="klearframe-agent-team-$version.plugin"
git archive --format=zip -o "$out" HEAD
echo "$PWD/$out"
