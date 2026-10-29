#!/usr/bin/env bash
# Tests for protect-branch.sh. Run: bash hooks/protect-branch.test.sh
set -u
hook="$(cd "$(dirname "$0")" && pwd)/protect-branch.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Fake gh: PR 12 and the current branch's PR target master, PR 13 targets develop, PR 14 targets main.
mkdir -p "$tmp/bin"
cat > "$tmp/bin/gh" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  "pr view 12 "*|"pr view --json"*) echo master ;;
  "pr view 13 "*|"pr view https://github.com/o/r/pull/13 "*) echo develop ;;
  "pr view 14 "*) echo main ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$tmp/bin/gh"
export PATH="$tmp/bin:$PATH"

repo="$tmp/repo"
git init -q -b develop "$repo"
git -C "$repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
export CLAUDE_PROJECT_DIR="$repo"

fails=0
run() { # expected-exit command
  local payload
  payload=$(jq -n --arg c "$2" '{tool_name:"Bash",tool_input:{command:$c}}')
  printf '%s' "$payload" | PATH="${HOOK_PATH:-$PATH}" /bin/bash "$hook" >/dev/null 2>&1
  local got=$?
  if [ "$got" != "$1" ]; then echo "FAIL (want $1, got $got): $2"; fails=$((fails + 1)); fi
}
run_env() { # branches expected-exit command
  AGENT_TEAM_PROTECTED_BRANCHES="$1" run "$2" "$3"
}
run_path() { # hook-PATH expected-exit command
  HOOK_PATH="$1" run "$2" "$3"
}

# PATHs without jq: the tools the hook needs, with and without python3.
mkdir -p "$tmp/nojq" "$tmp/nojq-nopy"
for t in cat git grep head tail tr; do
  ln -s "$(command -v "$t")" "$tmp/nojq/$t"
  ln -s "$(command -v "$t")" "$tmp/nojq-nopy/$t"
done
ln -s "$(command -v python3)" "$tmp/nojq/python3"
ln -s "$tmp/bin/gh" "$tmp/nojq/gh"
ln -s "$tmp/bin/gh" "$tmp/nojq-nopy/gh"

# Blocked (exit 2)
run 2 'git push origin master'
run 2 'git push origin HEAD:master'
run 2 'git push -f origin develop:master'
run 2 'git push origin +master'
run 2 'git push origin refs/heads/master'
run 2 'npm test && git push origin master'
run 2 'git -C /some/dir push origin master'
run 2 'gh pr merge 12 --squash'
run 2 'gh pr merge --merge'
run 2 'gh pr merge 99'

# Allowed (exit 0)
run 0 'git push origin develop'
run 0 'git push -u origin feature/master-plan'
run 0 'git push origin fix-master'
run 0 'git push'
run 0 'gh pr merge 13 --squash --delete-branch'
run 0 'gh pr merge https://github.com/o/r/pull/13'
run 0 'git log master..develop'
run 0 'ls -la'

# main is guarded by default too
run 2 'git push origin main'
run 2 'git push origin HEAD:main'
run 2 'gh pr merge 14 --squash'
run 0 'git push origin maintenance'

# The env var replaces the default
run_env 'release' 2 'git push origin release'
run_env 'release' 0 'git push origin master'
run_env 'release' 0 'git push origin main'
run_env 'prod live' 2 'git push origin live'
# Empty is not an off switch
run_env '' 2 'git push origin master'
run_env ' ' 2 'git push origin master'
run_env '	' 2 'git push origin main'

# Quoted names
run 2 'git push origin "main"'
run 2 "git push origin 'master'"

# HEAD and @ from a branch that isn't protected
run 0 'git push -u origin HEAD'
run 0 'git push origin @'

# Without jq: python3 reads the command; with neither, pushes and merges are blocked
run_path "$tmp/nojq" 2 'git push origin main'
run_path "$tmp/nojq" 0 'git push origin develop'
run_path "$tmp/nojq-nopy" 2 'git push origin develop'
run_path "$tmp/nojq-nopy" 2 'gh pr merge 13'
run_path "$tmp/nojq-nopy" 0 'ls -la'

# A bare push while on the protected branch is blocked.
git -C "$repo" switch -q -c master
run 2 'git push'
run 2 'git push -u origin'
run 0 'git push origin develop'
git -C "$repo" switch -q -c main
run 2 'git push'
run 2 'git push -u origin HEAD'
run 2 'git push origin @'
run 2 'git push origin HEAD:refs/heads/main'

if [ "$fails" -eq 0 ]; then echo "all tests passed"; else echo "$fails failed"; exit 1; fi
