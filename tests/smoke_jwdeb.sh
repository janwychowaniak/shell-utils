#!/usr/bin/env bash
#
# Smoke test for jw_functions__deb.sh
# ===================================
# Runs the jwdeb_* functions under BOTH bash and zsh, failing if any shell
# RUNTIME-error signature appears — e.g. zsh's "read-only variable" (using a
# reserved name like `status`), "integer expression expected" (a
# `grep -c ... || echo 0` double-zero), or a glob "no matches found".
#
# Why this exists: `bash -n` / `zsh -n` and `type <fn>` only check PARSING —
# these bugs surface only when the function actually runs. So we execute them.
#
# SAFETY — these functions wrap the REAL apt/dpkg on this machine. The test is
# built to never install, remove, purge, hold or upgrade anything:
#   * Prompting functions (install/remove/purge/reinstall/upgrade/dist-upgrade/
#     autoremove/autoclean/clean/fix) are fed </dev/null, so the confirmation
#     read() hits EOF and the function cancels before any sudo call.
#   * Mutating functions are additionally only ever given a NON-EXISTENT package
#     in Part B, so their validation returns before the prompt is even reached.
#   * jwdeb_update is the one exception that cannot be run safely: its no-args
#     path calls `sudo apt-get update` UNCONDITIONALLY (no prompt). It is
#     skipped — parse/zsh-safety of jwdeb_update is covered by shellcheck and
#     by reading, not by execution here.
#
# Coverage:
#   Part A — no-args path of every function (except jwdeb_update).
#   Part B — real-arg invocations of the read-only / non-destructive functions,
#            plus the non-existent-package validation paths of the mutating
#            ones. No genuine mutation is ever performed.
#   Part C — bash-vs-zsh stdout parity for deterministic read-only functions.
# NOT covered by automated parity (verified by hand instead):
#   * jwdeb_diag           — embeds `date`, so its output is non-deterministic.
#   * jwdeb_update and the real (confirmed) install/remove/... mutations.
# (jwdeb_size --top and jwdeb_installed --manual/--size used to be excluded as
#  too slow — they now run in one dpkg-query pass, so they are covered below.)
#
# Run:  bash tests/smoke_jwdeb.sh   (or ./tests/smoke_jwdeb.sh)
# Exit: 0 = clean, 1 = runtime-error signature / parity diff found, 2 = setup.

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LIB="$SCRIPT_DIR/../jw_functions__deb.sh"

[ -f "$LIB" ] || { echo "❌ cannot find library: $LIB"; exit 2; }
command -v dpkg >/dev/null 2>&1 || { echo "❌ dpkg is required (Debian/apt system)"; exit 2; }

# Test under whichever of bash/zsh are installed
SHELLS=()
for sh in bash zsh; do command -v "$sh" >/dev/null 2>&1 && SHELLS+=("$sh"); done
[ "${#SHELLS[@]}" -gt 0 ] || { echo "❌ neither bash nor zsh found"; exit 2; }
command -v zsh >/dev/null 2>&1 || echo "⚠️  zsh not installed — testing bash only"

# A package that is guaranteed installed on any apt system, for the read-only
# real-arg paths (info/policy/depends/files/size/installed filter, …).
PKG=dpkg
# A package that does NOT exist, for the validation paths of mutating functions.
NOPE=zzz-jwdeb-smoke-nonexistent

# Shell runtime-error signatures (NOT apt/dpkg's own E:/W: diagnostics)
SIG='read-only variable|integer expression|command not found|parse error|bad pattern|bad substitution|no matches found|unbound|number expected|bad math|maximum nested'

FAILED=0

# run <shell> <code> -> prints any signature lines found on the run's stderr
run() {
  local sh=$1 code=$2 out
  out=$( timeout 30 "$sh" -c "source '$LIB'; $code" </dev/null 2>&1 >/dev/null )
  printf '%s' "$out" | grep -nE "$SIG" | head -2
}

# Part A — every function, no-args path (jwdeb_update excluded, see header)
mapfile -t FNS < <(grep -oE '^jwdeb_[a-z-]+' "$LIB" | sort -u)
echo "=== Part A: no-args path of ${#FNS[@]} functions (jwdeb_update skipped) ==="
for sh in "${SHELLS[@]}"; do
  n=0
  for fn in "${FNS[@]}"; do
    [ "$fn" = "jwdeb_update" ] && continue   # would run `sudo apt-get update`
    hit=$(run "$sh" "$fn")
    if [ -n "$hit" ]; then
      printf "  ❌ [%s] %-22s %s\n" "$sh" "$fn" "$(printf '%s' "$hit" | head -1)"
      FAILED=$((FAILED + 1)); n=$((n + 1))
    fi
  done
  [ "$n" -eq 0 ] && echo "  ✅ $sh: all clean"
done

# Part B — real-arg invocations: read-only with a real package, mutating with a
# non-existent package (validation returns before any prompt/sudo).
B=(
  "jwdeb_search $PKG"
  "jwdeb_search $PKG --names-only"
  "jwdeb_search $PKG --installed"
  "jwdeb_search $PKG --full"
  "jwdeb_info $PKG"
  "jwdeb_policy"
  "jwdeb_policy $PKG"
  "jwdeb_depends $PKG"
  "jwdeb_depends $PKG --tree"
  "jwdeb_files $PKG"
  "jwdeb_which /bin/sh"
  "jwdeb_which dpkg"
  "jwdeb_size $PKG"
  "jwdeb_size --top 25"
  "jwdeb_installed $PKG"
  "jwdeb_installed --size"
  "jwdeb_installed --manual"
  "jwdeb_installed --date"
  "jwdeb_history 10"
  "jwdeb_history --installs"
  "jwdeb_history --removes"
  "jwdeb_hold"
  "jwdeb_install $NOPE"
  "jwdeb_remove $NOPE"
  "jwdeb_purge $NOPE"
  "jwdeb_reinstall $NOPE"
  "jwdeb_download $NOPE"
  "jwdeb_unhold $NOPE"
)
echo "=== Part B: ${#B[@]} real-arg invocations (read-only + non-existent-pkg paths) ==="
for sh in "${SHELLS[@]}"; do
  n=0
  for inv in "${B[@]}"; do
    hit=$(run "$sh" "$inv")
    if [ -n "$hit" ]; then
      printf "  ❌ [%s] %-34s %s\n" "$sh" "$inv" "$(printf '%s' "$hit" | head -1)"
      FAILED=$((FAILED + 1)); n=$((n + 1))
    fi
  done
  [ "$n" -eq 0 ] && echo "  ✅ $sh: all clean"
done

# Part C — bash-vs-zsh stdout parity for deterministic read-only functions.
# Any difference is a shell-specific OUTPUT bug (e.g. zsh printing a stale value
# when a bare `local x` re-declares an already-set var, or leading-space
# stripping by `read -r` without IFS=). Catches the class Part A/B (stderr
# signatures only) cannot see.
echo "=== Part C: bash-vs-zsh stdout parity (read-only functions) ==="
if [ "${#SHELLS[@]}" -ge 2 ]; then
  RO=(
    "jwdeb_search $PKG"
    "jwdeb_search $PKG --names-only"
    "jwdeb_info $PKG"
    "jwdeb_policy"
    "jwdeb_policy $PKG"
    "jwdeb_depends $PKG"
    "jwdeb_files $PKG"
    "jwdeb_which /bin/sh"
    "jwdeb_size $PKG"
    "jwdeb_size --top 25"
    "jwdeb_installed $PKG"
    "jwdeb_installed --size"
    "jwdeb_installed --manual"
    "jwdeb_installed --date"
    "jwdeb_history 15"
    "jwdeb_history --installs"
    "jwdeb_hold"
    "jwdeb_orphans"
    "jwdeb_broken"
    "jwdeb_toc"
  )
  n=0
  for inv in "${RO[@]}"; do
    b=$( timeout 30 bash -c "source '$LIB'; $inv" </dev/null 2>/dev/null )
    z=$( timeout 30 zsh  -c "source '$LIB'; $inv" </dev/null 2>/dev/null )
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

echo
if [ "$FAILED" -eq 0 ]; then
  echo "✅ smoke OK — no runtime-error signatures or parity diffs (${SHELLS[*]})"
  exit 0
fi
echo "❌ smoke FAILED — $FAILED issue(s) above"
exit 1
