#!/usr/bin/env bash
# PreToolUse hook for Bash: blocks `git push` to a protected branch and
# `gh pr merge` into it, so only the user releases to production.
# Plugin hook, no arguments. Protected branches: AGENT_TEAM_PROTECTED_BRANCHES
# (space-separated), or `master main` when it is unset or empty.
set -u
branches="${AGENT_TEAM_PROTECTED_BRANCHES:-master main}"
input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || cmd="$input"
[ -z "$cmd" ] && exit 0
repo="${CLAUDE_PROJECT_DIR:-.}"

block() { # reason branch
  echo "Blocked: $1. Only the user merges or pushes to '$2'; ask them to do it." >&2
  exit 2
}

is_protected() {
  local b
  for b in $branches; do [ "$1" = "$b" ] && return 0; done
  return 1
}

# Words after `<word>` in a segment, skipping options (and `-C <dir>` for git).
args_after() {
  local seen=0 skip=0 out=()
  for w in $2; do
    if [ "$skip" = 1 ]; then skip=0; continue; fi
    if [ "$seen" = 0 ]; then [ "$w" = "$1" ] && seen=1; continue; fi
    case "$w" in
      -C) skip=1 ;;
      -*) ;;
      *) out+=("$w") ;;
    esac
  done
  printf '%s\n' "${out[@]+"${out[@]}"}"
}

# Split on command separators and check each simple command.
while IFS= read -r seg; do
  if [[ "$seg" =~ (^|[[:space:]])git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+push([[:space:]]|$) ]]; then
    refs=$(args_after push "$seg" | tail -n +2)
    while IFS= read -r ref; do
      [ -z "$ref" ] && continue
      dest="${ref##*:}"; dest="${dest#+}"; dest="${dest#refs/heads/}"
      is_protected "$dest" && block "git push to '$dest'" "$dest"
    done <<< "$refs"
    current=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ -z "$refs" ] && is_protected "$current"; then
      block "git push from '$current'" "$current"
    fi
  fi
  if [[ "$seg" =~ (^|[[:space:]])gh[[:space:]]+pr[[:space:]]+merge([[:space:]]|$) ]]; then
    target=$(args_after merge "$seg" | grep -E '^([0-9]+|https?://[^[:space:]]+/pull/[0-9]+)$' | head -n 1)
    # shellcheck disable=SC2086 # an empty target means the current branch's PR
    base=$(cd "$repo" && gh pr view $target --json baseRefName -q .baseRefName 2>/dev/null) ||
      block "could not check the base branch of this PR" "$branches"
    is_protected "$base" && block "gh pr merge into '$base'" "$base"
  fi
done < <(printf '%s\n' "$cmd" | tr ';&|' '\n\n\n')
exit 0
