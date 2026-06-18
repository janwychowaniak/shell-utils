#!/usr/bin/env bash
#
# Smoke test for jw_functions__python.sh
# ======================================
# Builds a throwaway virtual environment in a tempdir and runs every jwpy_*
# function under BOTH bash and zsh, failing if any shell RUNTIME-error signature
# appears — e.g. zsh's "read-only variable" (a reserved name like `status`/`path`),
# "no matches found" (an unguarded glob), or "unbound" (a $missing under set -u).
#
# Why this exists: `bash -n` / `zsh -n` and `type <fn>` only check PARSING —
# these bugs surface only when the function actually runs. So we execute them.
#
# Coverage: the no-args path of every function, plus real-arg invocations of the
# read-only / safe functions. Nothing touches real system state — the venv lives
# entirely under a mktemp dir that is removed on exit. VIRTUAL_ENV is unset so the
# run is hermetic regardless of the caller's shell.
#
# Deliberately NOT executed (network, state, or running external tools — like
# git's smoke skips push / destructive paths): the actual install/uninstall/upgrade
# of packages, and test/lint/format (which run pytest/ruff/etc. against the cwd, and
# format even rewrites files) — only their usage / --help paths are smoked.
# jwpy_outdated, jwpy_test, jwpy_lint and jwpy_format all act on no-args, so they are
# dropped from the blind no-args sweep; their --help paths are checked in Part C.
#
# Run:  bash tests/smoke_jwpy.sh   (or ./tests/smoke_jwpy.sh)
# Exit: 0 = clean, 1 = runtime-error signature found, 2 = setup problem.

set -u
unset VIRTUAL_ENV

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LIB="$SCRIPT_DIR/../jw_functions__python.sh"

[ -f "$LIB" ] || { echo "❌ cannot find library: $LIB"; exit 2; }

# A backend to build the fixture venv with: uv (preferred) or python3 -m venv.
if command -v uv >/dev/null 2>&1; then
    BUILD="uv"
elif command -v python3 >/dev/null 2>&1; then
    BUILD="python3"
else
    echo "❌ need either uv or python3 to build the fixture venv"; exit 2
fi

# Test under whichever of bash/zsh are installed
SHELLS=()
for sh in bash zsh; do command -v "$sh" >/dev/null 2>&1 && SHELLS+=("$sh"); done
[ "${#SHELLS[@]}" -gt 0 ] || { echo "❌ neither bash nor zsh found"; exit 2; }
command -v zsh >/dev/null 2>&1 || echo "⚠️  zsh not installed — testing bash only"

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

# --- build a throwaway venv so activate/info exercise the happy path ---
(
  cd "$T" || exit 1
  if [ "$BUILD" = "uv" ]; then
    uv venv .venv
  else
    python3 -m venv .venv
  fi
) >/dev/null 2>&1 || { echo "❌ failed to build fixture venv (backend: $BUILD)"; exit 2; }
WORK="$T"

# Shell runtime-error signatures (NOT a tool's own usage/error text)
SIG='read-only variable|integer expression|command not found|parse error|bad pattern|bad substitution|no matches found|unbound|number expected|bad math|maximum nested'

FAILED=0

# run <shell> <code> -> prints any signature lines found on the run's stderr
run() {
  local sh=$1 code=$2 out
  out=$( cd "$WORK" && timeout 30 "$sh" -c "unset VIRTUAL_ENV; source '$LIB'; $code" </dev/null 2>&1 >/dev/null )
  printf '%s' "$out" | grep -nE "$SIG" | head -2
}

# Part A — every function, no-args path. Excluded: jwpy_outdated (network) and
# jwpy_test/lint/format (run external tools against the cwd; format rewrites files).
mapfile -t FNS < <(grep -oE '^jwpy_[a-z-]+' "$LIB" | sort -u \
                   | grep -vxE 'jwpy_(outdated|test|lint|format)')
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
# Any difference is a shell-specific OUTPUT bug (e.g. zsh printing a stale value
# when a bare `local x` re-declares an already-set var, or read -r stripping a
# leading space). Catches the class Part A (stderr signatures only) cannot see.
echo "=== Part C: bash-vs-zsh stdout parity (read-only functions) ==="
if [ "${#SHELLS[@]}" -ge 2 ]; then
  RO=(
    'jwpy_toc'
    'jwpy_venv-create'
    'jwpy_venv-create --help'
    'jwpy_venv-info'
    'jwpy_venv-info .venv'
    'jwpy_venv-list'
    'jwpy_venv-list --help'
    'jwpy_venv-deactivate --help'
    'jwpy_venv-remove --help'
    'jwpy_list'
    'jwpy_list --format=freeze'
    'jwpy_install --help'
    'jwpy_upgrade --help'
    'jwpy_uninstall --help'
    'jwpy_outdated --help'
    'jwpy_show --help'
    'jwpy_freeze'
    'jwpy_freeze --help'
    'jwpy_reqs-save --help'
    'jwpy_reqs-install --help'
    'jwpy_reqs-install missing-reqs.txt'
    'jwpy_version'
    'jwpy_which'
    'jwpy_which python uv'
    'jwpy_pythons'
    'jwpy_test --help'
    'jwpy_lint --help'
    'jwpy_format --help'
  )
  n=0
  for inv in "${RO[@]}"; do
    b=$( cd "$WORK" && timeout 30 bash -c "unset VIRTUAL_ENV; source '$LIB'; $inv" </dev/null 2>/dev/null )
    z=$( cd "$WORK" && timeout 30 zsh  -c "unset VIRTUAL_ENV; source '$LIB'; $inv" </dev/null 2>/dev/null )
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

# Part B — real-arg invocations of read-only / safe functions
B=(
  'jwpy_venv-info'
  'jwpy_venv-info .venv'
  'jwpy_venv-info nope'
  'jwpy_venv-activate .venv'
  'jwpy_venv-activate'
  'jwpy_venv-activate nope'
  'jwpy_venv-create --help'
  'jwpy_venv-create newenv'
  'jwpy_venv-create .venv'
  'jwpy_venv-list'
  'jwpy_venv-deactivate'
  'jwpy_venv-activate .venv && jwpy_venv-deactivate'
  'jwpy_venv-remove'
  'jwpy_venv-remove nonexistent-dir'
  'jwpy_venv-remove .'
  'jwpy_venv-remove .venv'
  'jwpy_list'
  'jwpy_list --format=freeze'
  'jwpy_show no-such-pkg-zzz'
  'jwpy_install --help'
  'jwpy_upgrade --help'
  'jwpy_uninstall --help'
  'jwpy_freeze'
  'jwpy_reqs-save --help'
  'jwpy_reqs-install missing-reqs.txt'
  'jwpy_version'
  'jwpy_which'
  'jwpy_which python uv'
  'jwpy_pythons'
  'jwpy_test --help'
  'jwpy_lint --help'
  'jwpy_format --help'
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
