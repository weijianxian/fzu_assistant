#!/usr/bin/env bash
# Shared by the commit hooks; requires Git Bash (or Bash on Unix).
set -euo pipefail

fail() {
  printf 'FZU hooks: ERROR: %s\n' "$*" >&2
  exit 1
}

hook_tmp=
merge_marker=
finish() {
  local status=$?
  if [[ -n "$merge_marker" ]]; then
    if [[ -e "$merge_marker" ]]; then
      cmp -s -- "$merge_marker" "$hook_tmp/MERGE_HEAD" || status=1
    else
      cp -- "$hook_tmp/MERGE_HEAD" "$merge_marker" || status=1
    fi
    if ((status != 0)); then
      printf 'FZU hooks: check merge state at %s (backup in %s).\n' "$merge_marker" "$hook_tmp" >&2
    fi
  fi
  if [[ -n "$hook_tmp" ]]; then
    if ((status == 0)); then
      rm -f -- "$hook_tmp"/*
      rmdir -- "$hook_tmp"
    else
      printf 'FZU hooks: recovery files retained in %s\n' "$hook_tmp" >&2
    fi
  fi
  if ((status != 0)) && [[ "$hook_phase" == post-commit ]]; then
    printf 'FZU hooks: the commit already exists; build-number correction FAILED. Inspect HEAD and the error above before retrying git commit --amend --no-edit.\n' >&2
  fi
  exit "$status"
}
trap finish EXIT
cd -- "$(git rev-parse --show-toplevel)"

new_tmp() {
  hook_tmp=$(mktemp -d "${TMPDIR:-/tmp}/fzu-git-hooks.XXXXXX")
}

build_number() {
  local predict=${1:-0} branch total remaining number
  [[ "$(git rev-parse --is-shallow-repository)" == false ]] ||
    fail 'build numbering requires full history; shallow clones are unsupported.'
  branch=$(git symbolic-ref --quiet --short HEAD || true)
  if [[ "$branch" == main ]]; then
    if git rev-parse --verify --quiet HEAD >/dev/null; then
      number=$(git rev-list --first-parent --count HEAD)
    else
      number=0
    fi
    printf '%s\n' "$((number + predict))"
  else
    git rev-parse --verify --quiet refs/remotes/origin/main >/dev/null ||
      fail 'feature/detached builds require refs/remotes/origin/main.'
    total=$(git rev-list --first-parent --count refs/remotes/origin/main)
    remaining=$(git rev-list --first-parent --count refs/remotes/origin/main --not HEAD)
    number=$((total - remaining))
    ((number > 0)) || fail 'HEAD has no history in common with origin/main.'
    printf '%s\n' "$number"
  fi
}

read_number() {
  sed -nE 's/^version:[[:blank:]]+[^[:space:]+]+\+([0-9]+)[[:blank:]]*(#.*)?\r?$/\1/p' "$1"
}

write_number() {
  local input=$1 output=$2 number=$3
  [[ "$(grep -c '^version:' "$input")" == 1 ]] ||
    fail 'pubspec.yaml must have exactly one version line.'
  sed -E 's/^(version:[[:blank:]]+[^[:space:]+]+)(\+[0-9]+)?([[:blank:]]*(#.*)?\r?)$/\1+'"$number"'\3/' \
    "$input" > "$output"
  [[ "$(read_number "$output")" == "$number" ]] ||
    fail 'expected a plain version: x.y.z+number line in pubspec.yaml.'
}

# Compare actual content, even when assume-unchanged/skip-worktree hides a diff.
require_fully_staged() {
  local path=$1 staged working
  [[ -f "$path" && ! -L "$path" ]] || fail "expected a regular file: $path"
  staged=$(git rev-parse --verify ":$path") ||
    fail "file is missing from the index or unmerged: $path"
  working=$(git hash-object --path="$path" -- "$path")
  [[ "$staged" == "$working" ]] ||
    fail "$path has unstaged changes; refusing to overwrite them. Stage or stash that file before committing."
}
