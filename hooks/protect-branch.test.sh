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
for t in awk cat git grep head tail tr; do
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

# Pushes and merges hidden behind a shell, a wrapper or a variable
run 2 'bash -c "git push origin main"'
run 2 "sh -c 'git push origin master'"
run 2 'eval "git push origin main"'
run 2 'sudo git push origin main'
run 2 'git push origin main 2>&1 | tail -n 3'
run 2 'B=main; git push origin $B'
run 2 'git push origin "$(git branch --show-current)"'
run 2 'git push origin "refs/heads/*:refs/heads/*"'
run 2 'git --git-dir .git push origin main'
run 2 'bash -c "gh pr merge 12 --squash"'
run 2 'gh pr merge -b "body text" 12'
run 0 'git push --all origin'
run 0 'git push origin develop 2>&1 | tail -n 3'
run 0 'git push -o ci.skip origin develop'
run 0 'gh pr merge --body "merges 12" 13'

# Without jq: python3 reads the command; with neither, pushes and merges are blocked
run_path "$tmp/nojq" 2 'git push origin main'
run_path "$tmp/nojq" 0 'git push origin develop'
run_path "$tmp/nojq-nopy" 2 'git push origin develop'
run_path "$tmp/nojq-nopy" 2 'gh pr merge 13'
run_path "$tmp/nojq-nopy" 0 'ls -la'

# Skipping git hooks is blocked
run 2 'git commit --no-verify -m wip'
run 2 'git commit -n -m wip'
run 2 'git commit -anm wip'
run 2 'git push --no-verify origin develop'
run 2 'npm test && git commit --no-verify -m wip'
run 2 'git -C /some/dir commit --no-verify'
run 2 'GIT_AUTHOR_NAME=x git commit -n'
run 2 'git merge --no-verify feature'
run 2 'git commit -m "$(cat <<'"'"'EOF'"'"'
Fix the thing
EOF
)" --no-verify'
run 2 'git commit -m wip \
  --no-verify'
run 2 "git commit -m \"don't crash\" --no-verify -m \"it's fine\""
run 2 '(cd x && git commit --no-verify)'
run 2 'if git commit --no-verify -m x; then echo ok; fi'
run 2 'time git commit -n'
run 2 'env X=1 git commit --no-verify'
run 2 'git --no-pager commit -n'
run 2 'git -C "/my repo" commit -n'
run 2 'git -c core.hooksPath=/dev/null commit -m wip'
run 2 'HUSKY=0 git commit -m wip'
run_path "$tmp/nojq" 2 'git commit --no-verify -m wip'
run_path "$tmp/nojq-nopy" 2 'git commit --no-verify -m wip'
run_path "$tmp/nojq-nopy" 2 'git commit -n -m wip'
run_path "$tmp/nojq-nopy" 2 'HUSKY=0 git commit -m wip'
run_path "$tmp/nojq-nopy" 2 'git config core.hooksPath /dev/null'
run_path "$tmp/nojq-nopy" 0 'git log -n 5'
# ...but not a message, a heredoc body or another command that mentions it
run 0 'git commit -m "Block --no-verify in the hook"'
run 0 "git commit -m 'skip -n here'"
run 0 'git commit -m "say \"--no-verify\" twice" --amend'
run 0 "git commit -F - <<'EOF'
Block git commit --no-verify
EOF"
run 0 "git commit -F - <<'EOF'
Hook: block pushes; git commit --no-verify too
EOF"
run 0 'git commit -m "first line
git commit -n works"'
run 0 'echo --no-verify'
run 0 'git log -n 5'
run 0 'git commit --amend --no-edit'
run 0 'grep -rn -- --no-verify docs'
run 0 'git grep -n -- --no-verify'
run 0 'git commit -uno -m wip'
run 0 'git commit -mnote'
run 0 'git push -n origin develop'
run 0 'git merge -n feature'
run 0 'cat <<< "git commit --no-verify"'

# Deliberate workarounds: hook-manager variables, in any form
run 2 'export HUSKY=0; git commit -m wip'
run 2 'export HUSKY; git commit -m wip'
run 2 'HUSKY="0" git commit -m wip'
run 2 "HUSKY='0' git commit -m wip"
run 2 'env HUSKY=0 git commit -m wip'
run 2 'declare -x HUSKY=0'
run 2 'HUSKY_SKIP_HOOKS=1 git commit -m wip'
run 2 'LEFTHOOK=0 git commit -m wip'
run 2 'LEFTHOOK_EXCLUDE=lint git commit -m wip'
run 2 'SKIP=eslint git commit -m wip'
# ...core.hooksPath, however it is set
run 2 'git -c "core.hooksPath=/dev/null" commit -m wip'
run 2 'git -c core.HooksPath=/x commit -m wip'
run 2 'git -c CORE.HOOKSPATH=/x commit -m wip'
run 2 'git -c core.hooksPath status'
run 2 'git --config-env=core.hooksPath=X commit -m wip'
run 2 'git --config-env core.hooksPath=X commit -m wip'
run 2 'GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0=/x git commit'
run 2 "GIT_CONFIG_PARAMETERS=\"'core.hooksPath'='/x'\" git commit"
run 2 'git config core.hooksPath /dev/null && git commit -m wip'
run 2 'git config --local core.hooksPath /dev/null'
run 2 'git config -f .git/config core.hooksPath /dev/null'
run 2 'git config --unset core.hooksPath'
run 2 'git config set core.hooksPath /dev/null'
run 2 'git -c "$K=/x" commit'
# ...a shortened --no-verify, or -n on am
run 2 'git commit --no-veri -m wip'
run 2 'git commit --no-ve -m wip'
run 2 'git push --no-verif origin develop'
run 2 'git pull --no-verify'
run 2 'git am -n patch.mbox'
run 2 'git am -3n patch.mbox'
# ...a git alias that skips them
run 2 "git config alias.ci 'commit --no-verify'"
run 2 "git config --global alias.ci '!git commit -n'"
run 2 "git -c alias.ci='commit --no-verify' ci -m wip"
# ...or another way to name or run git
run 2 'bash -c "git commit --no-verify -m wip"'
run 2 "sh -lc 'git commit -n'"
run 2 'eval "git commit --no-verify"'
run 2 'eval git commit -n'
run 2 '"git" commit --no-verify'
run 2 'g""it commit --no-verify'
run 2 '\git commit -n'
run 2 '/usr/bin/git commit -n'
run 2 '$GIT commit --no-verify'
run 2 '$(which git) commit -n'
run 2 'git $SUB --no-verify'
run 2 'git --git-dir .git commit --no-verify'
run 2 'git --work-tree . commit -n'
run 2 'sudo -u bob git commit -n'
run 2 'timeout 60 git commit --no-verify'
run 2 'nice -n 10 git commit -n'
run 2 'xargs -I {} git commit --no-verify -m {}'
run 2 '{ git commit -n; }'
run 2 'echo $(git commit --no-verify)'
run 2 'echo "$(git commit -n)"'
run 2 'echo `git commit -n`'
run 2 'GIT_AUTHOR_NAME="a b" git commit -n'
run 2 'echo "git commit --no-verify" | sh'
run 2 "printf 'git commit -n\\n' | bash"
run 2 'bash <<< "git commit --no-verify"'
run 2 'bash <<EOF
git commit --no-verify
EOF'
run 2 "cat <<'EOF' | sh
git commit -n
EOF"
# ...but reading the setting, other variables and other shells are fine
run 0 'git config core.hooksPath'
run 0 'git config --get core.hooksPath'
run 0 'git config get core.hooksPath'
run 0 'git config --list'
run 0 'git config alias.st status'
run 0 'git config user.name "Ada Lovelace"'
run 0 'git -c user.email=a@b.c commit -m wip'
run 0 'git -c "user.email=$EMAIL" commit -m wip'
run 0 'MY_HUSKY=0 npm test'
run 0 'echo HUSKY=0'
run 0 'git commit -m "set HUSKY=0 in CI"'
run 0 'git commit -m wip # --no-verify'
run 0 'git commit --no-verbose -m wip'
run 0 'git pull --no-verify-signatures'
run 0 'bash scripts/build.sh --no-verify'
run 0 'bash -c "npm test"'
run 0 'curl -fsSL https://example.com/install.sh | bash'
run 0 'cat <<EOF > notes.md
git commit --no-verify
EOF'
run 0 'git commit -F - <<EOF
Explain why bash -c "git commit -n" is blocked
EOF'
run 0 'git am patch.mbox'
run 0 'git log --oneline -n 3 | cat'
run 0 'git commit -m "$(date)" 2>&1 | tail -n 5'

# A bare push while on the protected branch is blocked.
git -C "$repo" switch -q -c master
run 2 'git push'
run 2 'git push -u origin'
run 0 'git push origin develop'
run 2 'git push --all origin'
run 2 'git push --mirror origin'
git -C "$repo" switch -q -c main
run 2 'git push'
run 2 'git push -u origin HEAD'
run 2 'git push origin @'
run 2 'git push origin HEAD:refs/heads/main'

if [ "$fails" -eq 0 ]; then echo "all tests passed"; else echo "$fails failed"; exit 1; fi
