#!/usr/bin/env bash
# PreToolUse hook for Bash: blocks `git push` to a protected branch and
# `gh pr merge` into it, so only the user releases to production. Also blocks
# git commands that skip the project's git hooks (--no-verify, or -n on commit).
# Plugin hook, no arguments. Protected branches: AGENT_TEAM_PROTECTED_BRANCHES
# (space-separated), or `master main` when it is unset or blank.
set -uf # -f: no globbing in the word loops below
branches="${AGENT_TEAM_PROTECTED_BRANCHES:-}"
[ -z "${branches//[[:space:]]/}" ] && branches="master main"
input=$(cat)
if command -v jq >/dev/null 2>&1; then
  cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || cmd="$input"
elif command -v python3 >/dev/null 2>&1; then
  cmd=$(printf '%s' "$input" | python3 -c 'import json, sys; print(json.load(sys.stdin)["tool_input"].get("command") or "")' 2>/dev/null) || cmd="$input"
else
  # Can't read the command, so fail closed on anything that looks like a push or a merge.
  if printf '%s' "$input" | grep -Eq 'git.*push|gh[[:space:]]+pr[[:space:]]+merge|git.*--no-verify'; then
    echo "Blocked: the branch guard needs jq or python3 to check this command. Ask the user to run it." >&2
    exit 2
  fi
  exit 0
fi
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
    current=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null)
    while IFS= read -r ref; do
      ref="${ref//[\"\']/}"
      [ -z "$ref" ] && continue
      dest="${ref##*:}"; dest="${dest#+}"; dest="${dest#refs/heads/}"
      case "$dest" in HEAD | @) dest="$current" ;; esac
      is_protected "$dest" && block "git push to '$dest'" "$dest"
    done <<< "$refs"
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

# Skipping the project's git hooks: --no-verify on commit, push, merge, am or
# rebase, -n on commit, `-c core.hooksPath=...` or HUSKY=0.
#
# First, so text inside a commit message can't trigger or hide a block: drop
# heredoc bodies, join backslash-newline continuations, and replace each quoted
# string with Q (leftmost quote first, across lines). POSIX awk, for macOS too.
read -r -d '' strip_text <<'AWK'
{ lines[NR] = $0 }
END {
  text = ""; delim = ""
  for (i = 1; i <= NR; i++) {
    l = lines[i]
    if (delim != "") { t = l; sub(/^\t+/, "", t); if (t == delim) delim = ""; continue }
    if (match(l, /<<-?[ \t]*['"]?[A-Za-z_][A-Za-z0-9_]*['"]?/) && (RSTART == 1 || substr(l, RSTART - 1, 1) != "<")) {
      d = substr(l, RSTART, RLENGTH); sub(/^<<-?[ \t]*/, "", d); gsub(/['"]/, "", d); delim = d
    }
    text = text l "\n"
  }
  gsub(/\\\n/, " ", text)
  out = ""; q = ""; n = length(text)
  for (i = 1; i <= n; i++) {
    c = substr(text, i, 1)
    if (q == "") {
      if (c == "'" || c == "\"") { q = c; out = out " Q "; continue }
      if (c == "\\") { out = out substr(text, i, 2); i++; continue }
      out = out c
    } else if (q == "\"" && c == "\\") { i++ }
    else if (c == q) { q = "" }
  }
  printf "%s", out
}
AWK

# One simple command, quotes already replaced: succeeds when it skips git hooks.
skips_hooks() {
  local w c i state=pre sub="" skip=0 off=0
  for w in $1; do
    if [ "$skip" = 1 ]; then
      skip=0
      case "$state:$w" in global:core.hooks[Pp]ath=*) off=1 ;; esac
      continue
    fi
    case "$state" in
      pre) # wrappers and variable assignments before git
        case "$w" in
          if | then | do | else | elif | while | until | '!' | time | command | env | exec | nohup | sudo) ;;
          HUSKY=0) off=1 ;;
          [A-Za-z_]*=*) ;;
          git) state=global ;;
          *) return 1 ;;
        esac ;;
      global) # git's own options, then the subcommand
        case "$w" in
          -C | -c) skip=1 ;;
          -*) ;;
          commit | push | merge | am | rebase) sub="$w"; state=args; [ "$off" = 1 ] && return 0 ;;
          *) return 1 ;;
        esac ;;
      args)
        case "$w" in
          --no-verify) return 0 ;;
          --*) ;;
          -?*) # on commit, -n in a short cluster, before any option that takes a value
            [ "$sub" = commit ] || continue
            i=1
            while [ "$i" -lt "${#w}" ]; do
              c="${w:$i:1}"
              case "$c" in
                n) return 0 ;;
                m | F | C | c | t) [ "$i" -eq $((${#w} - 1)) ] && skip=1; break ;;
                u | S) break ;;
              esac
              i=$((i + 1))
            done ;;
        esac ;;
    esac
  done
  return 1
}

unquoted=$(printf '%s\n' "$cmd" | awk "$strip_text")
while IFS= read -r seg; do
  if skips_hooks "$seg"; then
    echo "Blocked: this skips the project's git hooks. Fix what the hooks report instead, or ask the user." >&2
    exit 2
  fi
done < <(printf '%s\n' "$unquoted" | tr ';&|(){}' '\n\n\n\n\n\n\n')
exit 0
