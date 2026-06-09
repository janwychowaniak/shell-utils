#!/usr/bin/env bash
#
# Smoke test for jw_functions__git.sh
# ===================================
# Builds a throwaway git repo and runs every jwgit_* function under BOTH bash
# and zsh, failing if any shell RUNTIME-error signature appears — e.g. zsh's
# "read-only variable" (using a reserved name like `status`), "integer
# expression expected" (a `grep -c ... || echo 0` double-zero), or a glob
# "no matches found".
#
# Why this exists: `bash -n` / `zsh -n` and `type <fn>` only check PARSING —
# these bugs surface only when the function actually runs. So we execute them.
#
# Coverage: the no-args path of every function, plus real-arg invocations of
# the read-only / non-destructive functions. The fully-destructive paths
# (reset --hard, clean -f, prune, gc --deep, conflicted merge/rebase/revert)
# are intentionally NOT executed — they get only the no-args/usage smoke.
#
# Run:  bash tests/smoke_jwgit.sh   (or ./tests/smoke_jwgit.sh)
# Exit: 0 = clean, 1 = runtime-error signature found, 2 = setup problem.

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LIB="$SCRIPT_DIR/../jw_functions__git.sh"

[ -f "$LIB" ] || { echo "❌ cannot find library: $LIB"; exit 2; }
command -v git >/dev/null 2>&1 || { echo "❌ git is required"; exit 2; }

# Test under whichever of bash/zsh are installed
SHELLS=()
for sh in bash zsh; do command -v "$sh" >/dev/null 2>&1 && SHELLS+=("$sh"); done
[ "${#SHELLS[@]}" -gt 0 ] || { echo "❌ neither bash nor zsh found"; exit 2; }
command -v zsh >/dev/null 2>&1 || echo "⚠️  zsh not installed — testing bash only"

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

# --- build a rich throwaway repo (commits, branch, tag, stash, dirty tree, remote) ---
(
  cd "$T" || exit 1
  git init -q work && cd work || exit 1
  git config user.email smoke@test.local; git config user.name smoke
  echo a1 > a.txt; git add a.txt; git commit -qm c1
  git branch feature
  echo b1 > b.txt; git add b.txt; git commit -qm c2
  git tag v0.1
  echo c1 > c.txt; git add c.txt; git commit -qm c3
  # a second author touches a.txt -> blame has 2 authors (exercises the loop >1x)
  echo a_bob >> a.txt; git add a.txt
  git -c user.name=bob -c user.email=bob@test.local commit -qm c4
  echo a2 >> a.txt; git add a.txt          # staged change
  echo c2 >> c.txt                          # modified (unstaged)
  echo u  > untracked.txt                   # untracked
  echo s  > s.txt && git stash -q -u
  git init --bare -q ../remote.git
  git init --bare -q ../remote2.git
  git remote add origin ../remote.git
  git remote add upstream ../remote2.git    # 2nd remote -> remote-show loops >1x
  git push -q -u origin master
) >/dev/null 2>&1 || { echo "❌ failed to build throwaway repo"; exit 2; }
WORK="$T/work"

# Shell runtime-error signatures (NOT git's own fatal:/error:/hint: messages)
SIG='read-only variable|integer expression|command not found|parse error|bad pattern|bad substitution|no matches found|unbound|number expected|bad math|maximum nested'

FAILED=0

# run <shell> <code> -> prints any signature lines found on the run's stderr
run() {
  local sh=$1 code=$2 out
  out=$( cd "$WORK" && timeout 15 "$sh" -c "source '$LIB'; $code" </dev/null 2>&1 >/dev/null )
  printf '%s' "$out" | grep -nE "$SIG" | head -2
}

# Part A — every function, no-args path
mapfile -t FNS < <(grep -oE '^jwgit_[a-z-]+' "$LIB" | sort -u)
echo "=== Part A: no-args path of ${#FNS[@]} functions ==="
for sh in "${SHELLS[@]}"; do
  n=0
  for fn in "${FNS[@]}"; do
    hit=$(run "$sh" "$fn")
    if [ -n "$hit" ]; then
      printf "  ❌ [%s] %-22s %s\n" "$sh" "$fn" "$(printf '%s' "$hit" | head -1)"
      FAILED=$((FAILED + 1)); n=$((n + 1))
    fi
  done
  [ "$n" -eq 0 ] && echo "  ✅ $sh: all clean"
done

# Part C — bash-vs-zsh stdout parity for deterministic (read-only) functions.
# Any difference is a shell-specific OUTPUT bug (e.g. zsh printing a stale
# value when a bare `local x` re-declares an already-set var, or leading-space
# stripping by `read -r` without IFS=). Catches the class that Part A (stderr
# signatures only) cannot see.
echo "=== Part C: bash-vs-zsh stdout parity (read-only functions) ==="
if [ "${#SHELLS[@]}" -ge 2 ]; then
  RO=(
    'jwgit_status' 'jwgit_log --oneline -5' 'jwgit_diff' 'jwgit_diff --cached'
    'jwgit_blame a.txt' 'jwgit_reflog' 'jwgit_branch list --all'
    'jwgit_remote show' 'jwgit_tag'
  )
  n=0
  for inv in "${RO[@]}"; do
    b=$( cd "$WORK" && timeout 15 bash -c "source '$LIB'; $inv" </dev/null 2>/dev/null )
    z=$( cd "$WORK" && timeout 15 zsh  -c "source '$LIB'; $inv" </dev/null 2>/dev/null )
    if [ "$b" != "$z" ]; then
      printf "  ❌ stdout differs (bash vs zsh): %s\n" "$inv"
      diff <(printf '%s\n' "$b") <(printf '%s\n' "$z") | grep -E '^[<>]' | head -4 | sed 's/^/      /'
      FAILED=$((FAILED + 1)); n=$((n + 1))
    fi
  done
  [ "$n" -eq 0 ] && echo "  ✅ identical output in bash and zsh"
else
  echo "  ⏭️  skipped (needs both bash and zsh)"
fi

# Part B — real-arg invocations of read-only / non-destructive functions
B=(
  'jwgit_status'
  'jwgit_log'
  'jwgit_log --oneline -5'
  "jwgit_log --author 'a b' -- a.txt"
  'jwgit_diff'
  'jwgit_diff --cached'
  'jwgit_diff HEAD~1 HEAD'
  'jwgit_blame a.txt'
  'jwgit_reflog'
  'jwgit_reflog HEAD'
  'jwgit_branch list'
  'jwgit_branch list --all'
  'jwgit_remote show'
  'jwgit_tag'
  'jwgit_tag v9.9'
  'jwgit_tag -a v9.8 -m ann'
  'jwgit_add untracked.txt'
  'jwgit_commit smoke-msg'
  'jwgit_branch create smoke-br'
  'jwgit_stash list'
  'jwgit_fetch'
)
echo "=== Part B: ${#B[@]} real-arg invocations (safe functions) ==="
for sh in "${SHELLS[@]}"; do
  n=0
  for inv in "${B[@]}"; do
    hit=$(run "$sh" "$inv")
    if [ -n "$hit" ]; then
      printf "  ❌ [%s] %-40s %s\n" "$sh" "$inv" "$(printf '%s' "$hit" | head -1)"
      FAILED=$((FAILED + 1)); n=$((n + 1))
    fi
  done
  [ "$n" -eq 0 ] && echo "  ✅ $sh: all clean"
done

echo
if [ "$FAILED" -eq 0 ]; then
  echo "✅ smoke OK — no runtime-error signatures (${SHELLS[*]})"
  exit 0
fi
echo "❌ smoke FAILED — $FAILED issue(s) above"
exit 1
