#!/usr/bin/env bash
# PreToolUse hook for Bash. Blocks:
# - `git push` to a protected branch and `gh pr merge` into one, so only the
#   user releases to production;
# - git commands that skip the project's git hooks: --no-verify or a shortened
#   form of it, -n on commit or am, core.hooksPath set through -c, --config-env,
#   GIT_CONFIG_* or `git config`, a git alias that does any of these, and the
#   skip variables of husky, lefthook and pre-commit.
# Commands run through bash -c, sh -c, eval, $(...), a heredoc or a pipe into a
# shell, or wrappers such as sudo, env or xargs, are checked the same way.
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
  # Can't read the command, so fail closed on anything that looks like a push,
  # a merge or a way to skip git hooks.
  if printf '%s' "$input" | grep -Eiq 'git.*push|gh[[:space:]]+pr[[:space:]]+merge|--no-v|hookspath|husky|lefthook|skip=|git.*(commit|am)[[:space:]](.*[[:space:]])?-[a-z]*n'; then
    echo "Blocked: the branch guard needs jq or python3 to check this command. Ask the user to run it." >&2
    exit 2
  fi
  exit 0
fi
[ -z "$cmd" ] && exit 0
repo="${CLAUDE_PROJECT_DIR:-.}"
case ${BASH_SOURCE[0]} in */*) lexer="${BASH_SOURCE[0]%/*}/shell-words.awk" ;; *) lexer=shell-words.awk ;; esac
hook_vars="HUSKY HUSKY_SKIP_HOOKS LEFTHOOK LEFTHOOK_EXCLUDE SKIP"

block() { # reason branch
  echo "Blocked: $1. Only the user merges or pushes to '$2'; ask them to do it." >&2
  exit 2
}

block_hooks() { # what
  echo "Blocked: $1 skips the project's git hooks. Fix what the hooks report instead, or ask the user." >&2
  exit 2
}

block_unknown() { # what
  echo "Blocked: the branch guard can't tell what $1 does. Write it out in full, or ask the user to run it." >&2
  exit 2
}

is_protected() {
  local b
  for b in $branches; do [ "$1" = "$b" ] && return 0; done
  return 1
}

is_hookspath() { # config key, or key=value; config keys ignore case
  case $1 in
    [Cc][Oo][Rr][Ee].[Hh][Oo][Oo][Kk][Ss][Pp][Aa][Tt][Hh] | [Cc][Oo][Rr][Ee].[Hh][Oo][Oo][Kk][Ss][Pp][Aa][Tt][Hh]=*) return 0 ;;
  esac
  return 1
}

# Checks a command line: every simple command in it, including nested ones.
check_text() { # text depth
  local depth=$2 out line kind item rc
  local -a words stdin piped
  words=(); stdin=(); piped=()
  [ "$depth" -gt 8 ] && block_unknown "a command nested this deeply"
  out=$(printf '%s\n' "$1" | awk -f "$lexer") || block_unknown "this command"
  while IFS= read -r line; do
    kind=${line:0:1}
    item=${line:1}
    item=${item//$'\001'/$'\n'}
    case $kind in
      w) words+=("$item") ;;
      i | h) stdin+=("$item") ;;
      '|' | ';') # end of a simple command; item is its nesting level
        rc=0
        check_words "$depth" "${words[@]+"${words[@]}"}" || rc=$?
        if [ "$rc" = 3 ]; then # a shell reading commands from stdin: check what reaches it
          check_text "${piped[item]-}$(printf '%s\n' "${stdin[@]+"${stdin[@]}"}")" $((depth + 1))
        fi
        if [ "$kind" = '|' ]; then
          piped[item]="${piped[item]-}$(printf '%s\n' "${words[@]+"${words[@]:1}"}" "${stdin[@]+"${stdin[@]}"}")"$'\n'
        else
          piped[item]=""
        fi
        words=(); stdin=() ;;
    esac
  done <<<"$out"
}

# One simple command. Returns 3 when it is a shell reading commands from stdin.
check_words() { # depth word...
  local depth=$1 w prev="" wrap=0
  shift
  while [ $# -gt 0 ]; do
    w=$1
    case $w in
      '{' | '}' | '!' | if | then | do | else | elif | while | until | time | command | builtin | exec | nohup | nice | sudo | doas | env | xargs | timeout | stdbuf | ionice | caffeinate) wrap=1 ;;
      export | declare | typeset | readonly | local)
        shift
        for w in "$@"; do case $w in -*) ;; *) check_assignment "$w" ;; esac; done
        return 0 ;;
      eval) shift; check_text "$*" $((depth + 1)); return 0 ;;
      [A-Za-z_]*=*) check_assignment "$w" ;;
      -*) [ "$wrap" = 1 ] || return 0 ;;
      *)
        case ${w##*/} in
          git) shift; check_git "$depth" "$@"; return 0 ;;
          gh) shift; check_gh "$@"; return 0 ;;
          bash | sh | zsh | dash | ksh) shift; check_shell "$depth" "$@"; return ;;
        esac
        # A command only known at run time ($GIT, $(which git)): check it as git.
        case $w in *'$'*) shift; check_git "$depth" "$@"; return 0 ;; esac
        # After a wrapper, only an option's value (sudo -u bob) or a number
        # (timeout 10) may come before the command.
        [ "$wrap" = 1 ] || return 0
        case $prev in -?) ;; *) case $w in [0-9]*) ;; *) return 0 ;; esac ;; esac ;;
    esac
    prev=$w
    shift
  done
  return 0
}

check_assignment() { # NAME=value, or a bare NAME given to export
  local name=${1%%=*} v
  for v in $hook_vars; do [ "$name" = "$v" ] && block_hooks "setting $name"; done
  case $name in
    GIT_CONFIG_PARAMETERS | GIT_CONFIG_KEY_*)
      case $1 in
        *[Hh][Oo][Oo][Kk][Ss][Pp][Aa][Tt][Hh]*) block_hooks "setting core.hooksPath" ;;
        *'$'*) block_unknown "a git setting from a variable or command" ;;
      esac ;;
  esac
  return 0
}

# bash -c '...' checks the string. Without -c or a script file, the shell reads
# its commands from stdin: return 3 so the caller checks what reaches it.
check_shell() { # depth arg...
  local depth=$1 w c=0 skip=0
  shift
  for w in "$@"; do
    if [ "$skip" = 1 ]; then skip=0; continue; fi
    case $w in
      -o | +o | -O | +O | --rcfile | --init-file) skip=1 ;;
      --*) ;;
      -*c*) c=1 ;;
      -* | +*) ;;
      *) [ "$c" = 1 ] && check_text "$w" $((depth + 1)); return 0 ;;
    esac
  done
  [ "$c" = 1 ] && return 0
  return 3
}

check_gh() { # arg...: gh pr merge [<number> | <url> | <branch>] [flags]
  [ "${1-}" = pr ] && [ "${2-}" = merge ] || return 0
  shift 2
  local w target="" skip="" base
  local -a repo_flag
  repo_flag=()
  for w in "$@"; do
    if [ -n "$skip" ]; then
      [ "$skip" = repo ] && repo_flag=(--repo "$w")
      skip=""
      continue
    fi
    case $w in
      -R | --repo) skip=repo ;;
      --repo=*) repo_flag=(--repo "${w#--repo=}") ;;
      -b | --body | -F | --body-file | -t | --subject | -A | --author-email | --match-head-commit) skip=value ;;
      -*) ;;
      *) [ -z "$target" ] && target=$w ;;
    esac
  done
  # An empty target means the current branch's PR.
  base=$(cd "$repo" && gh pr view ${target:+"$target"} "${repo_flag[@]+"${repo_flag[@]}"}" --json baseRefName -q .baseRefName </dev/null 2>/dev/null) ||
    block "could not check the base branch of this PR" "$branches"
  is_protected "$base" && block "gh pr merge into '$base'" "$base"
  return 0
}

check_git() { # depth arg...: the words after `git`
  local depth=$1 w sub=""
  shift
  while [ $# -gt 0 ]; do # git's own options, then the subcommand
    w=$1
    shift
    case $w in
      -c) check_config_pair "$depth" "${1-}"; [ $# -gt 0 ] && shift ;;
      --config-env=*) check_config_env "${w#--config-env=}" ;;
      --config-env) check_config_env "${1-}"; [ $# -gt 0 ] && shift ;;
      -C | --git-dir | --work-tree | --namespace | --super-prefix) [ $# -gt 0 ] && shift ;;
      -*) ;;
      *) sub=$w; break ;;
    esac
  done
  case $sub in
    commit | merge | am | rebase | pull | push) check_git_args "$sub" "$@" ;;
    config) check_git_config "$depth" "$@" ;;
    *'$'*) check_git_args '?' "$@" ;;
  esac
  return 0
}

check_config_pair() { # depth key=value, from `git -c`
  local key=${2%%=*}
  case $key in *'$'*) block_unknown "a git -c setting named by a variable or command" ;; esac
  is_hookspath "$key" && block_hooks "setting core.hooksPath"
  case $key in [Aa][Ll][Ii][Aa][Ss].*) case $2 in *=*) check_alias "$1" "${2#*=}" ;; esac ;; esac
  return 0
}

check_config_env() { # name=envvar, from `git --config-env`
  local key=${1%%=*}
  case $key in *'$'* | [Aa][Ll][Ii][Aa][Ss].*) block_unknown "a git --config-env setting" ;; esac
  is_hookspath "$key" && block_hooks "setting core.hooksPath"
  return 0
}

check_alias() { # depth value: an alias runs `git <value>`, or a shell command after !
  case $2 in
    '!'*) check_text "${2#!}" $(($1 + 1)) ;;
    *) check_text "git $2" $(($1 + 1)) ;;
  esac
}

check_git_config() { # depth arg...: the words after `git config`
  local depth=$1 w key="" value="" more=0 write=0 skip=0
  shift
  for w in "$@"; do
    if [ "$skip" = 1 ]; then skip=0; continue; fi
    case $w in
      --get | --get-all | --get-regexp | --get-urlmatch | -l | --list | get | list) return 0 ;;
      --unset | --unset-all | --add | --replace-all | set | unset) write=1 ;;
      -f | --file | --blob | --type | --default | --comment | --value) skip=1 ;;
      -*) ;;
      *) if [ -z "$key" ]; then key=$w; else more=1; [ -z "$value" ] && value=$w; fi ;;
    esac
  done
  [ "$write" = 1 ] || [ "$more" = 1 ] || return 0 # `git config <key>` only reads it
  case $key in *'$'*) block_unknown "a git config change to a setting named by a variable or command" ;; esac
  is_hookspath "$key" && block_hooks "changing core.hooksPath"
  case $key in [Aa][Ll][Ii][Aa][Ss].*) [ -n "$value" ] && check_alias "$depth" "$value" ;; esac
  return 0
}

# The words after a git subcommand that can run hooks ('?' when the subcommand
# is only known at run time).
check_git_args() { # subcommand arg...
  local sub=$1 w c i skip=0 rest=0 all=0
  local -a pos
  pos=()
  shift
  for w in "$@"; do
    if [ "$skip" = 1 ]; then skip=0; continue; fi
    if [ "$rest" = 1 ]; then pos+=("$w"); continue; fi
    case $w in
      --) rest=1 ;;
      --*)
        # --no-verify, or a shortened form git accepts, such as --no-veri
        if [ "${#w}" -ge 6 ]; then case --no-verify in "$w"*) block_hooks "$w" ;; esac; fi
        if [ "$sub" = push ]; then
          case $w in
            --all | --mirror | --branches) all=1 ;;
            --repo | --receive-pack | --exec | --push-option) skip=1 ;;
          esac
        fi ;;
      -?*)
        case $sub in
          commit | am) # -n in a short cluster, before any option that takes a value
            i=1
            while [ "$i" -lt "${#w}" ]; do
              c=${w:$i:1}
              case $sub$c in
                *n) block_hooks "$w on git $sub" ;;
                commit[mFCct]) [ "$i" -eq $((${#w} - 1)) ] && skip=1; break ;;
                commit[uS] | am[pCS]) break ;;
              esac
              i=$((i + 1))
            done ;;
          push) [ "$w" = -o ] && skip=1 ;;
        esac ;;
      *) pos+=("$w") ;;
    esac
  done
  [ "$sub" = push ] && check_push "$all" "${pos[@]+"${pos[@]}"}"
  return 0
}

check_push() { # all remote ref...
  local all=$1 current ref dest b
  shift
  current=$(git -C "$repo" rev-parse --abbrev-ref HEAD </dev/null 2>/dev/null)
  if [ "$all" = 1 ]; then
    for b in $branches; do
      git -C "$repo" show-ref --verify --quiet "refs/heads/$b" </dev/null && block "git push --all or --mirror includes '$b'" "$b"
    done
  fi
  [ $# -gt 0 ] && shift # the remote
  if [ $# -eq 0 ]; then
    is_protected "$current" && block "git push from '$current'" "$current"
    return 0
  fi
  for ref in "$@"; do
    case $ref in *'$'*)
      echo "Blocked: git push to a branch named by a variable or command. Write the branch name, or HEAD." >&2
      exit 2 ;;
    esac
    dest="${ref##*:}"; dest="${dest#+}"; dest="${dest#refs/heads/}"
    case "$dest" in HEAD | @) dest="$current" ;; esac
    is_protected "$dest" && block "git push to '$dest'" "$dest"
    case $dest in *'*'*)
      for b in $branches; do
        # shellcheck disable=SC2053 # $dest is a refspec pattern
        [[ $b == $dest ]] && block "git push to '$dest'" "$b"
      done ;;
    esac
  done
  return 0
}

check_text "$cmd" 0
exit 0
