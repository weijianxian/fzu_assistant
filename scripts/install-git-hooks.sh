#!/usr/bin/env bash
set -euo pipefail

cd -- "$(git rev-parse --show-toplevel)"
for hook in .githooks/pre-commit .githooks/post-commit .githooks/post-merge; do
  [[ -f "$hook" ]] || { printf 'Missing hook: %s\n' "$hook" >&2; exit 1; }
  chmod +x "$hook"
done
git config --local core.hooksPath .githooks
printf 'Installed repository hooks via core.hooksPath=.githooks\n'
