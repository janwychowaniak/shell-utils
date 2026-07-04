#!/usr/bin/env bash
#
# Smoke test for jw_functions__process.sh
# =========================================
# Runs every jwps_* function under BOTH bash and zsh, failing if any zsh/bash
# RUNTIME-error signature appears — e.g. "read-only variable" (a reserved name
# like `status`/`path`), "bad substitution", or "no matches found". These surface
# only when a function RUNS, so we execute them (`-n`/`type` miss them).
#
# This area is read-only (it queries ps / ss / free, never signals or kills), so
# there is no daemon/system state to protect. The functions read the LIVE system,
# which we cannot control — so the "fixture" is a single throwaway `sleep` we spawn
# ourselves (with a known marker), driving jwps_find's real pgrep→ps path past a
# guaranteed match; it is killed on exit.
#
# Part A: no-args / -h path of every function (deterministic).
# Part B: real invocations against the live system + the tagged sleep + error paths.
# Part C: bash-vs-zsh stdout parity of the DETERMINISTIC paths only (toc, -h, the
#         no-match / bad-arg messages). The live readers (jwps_ports/_top and a
#         matching jwps_find) are scanned in A/B but NOT parity-checked: ps/ss/free
#         shift between the two runs (a %CPU tick, a socket opening) — a real diff
#         there would be system noise, not a shell-output bug.
#
# Run:  bash tests/smoke_jwps.sh   (or ./tests/smoke_jwps.sh)
# Exit: 0 = clean, 1 = runtime-error signature / parity diff, 2 = setup problem.

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LIB="$SCRIPT_DIR/../jw_functions__process.sh"

[ -f "$LIB" ] || { echo "❌ cannot find library: $LIB"; exit 2; }

# Test under whichever of bash/zsh are installed
SHELLS=()
for sh in bash zsh; do command -v "$sh" >/dev/null 2>&1 && SHELLS+=("$sh"); done
[ "${#SHELLS[@]}" -gt 0 ] || { echo "❌ neither bash nor zsh found"; exit 2; }
command -v zsh >/dev/null 2>&1 || echo "⚠️  zsh not installed — testing bash only"

# Shell runtime-error signatures (NOT ps/ss/free's own diagnostics)
SIG='read-only variable|integer expression|command not found|parse error|bad pattern|bad substitution|no matches found|unbound|number expected|bad math|maximum nested'

FAILED=0

# --- throwaway fixture: one tagged background process -------------------------
# `sleep 424242` — a unique-enough number to match on without hitting other sleeps.
sleep 424242 & SLEEP_PID=$!
trap 'kill "$SLEEP_PID" 2>/dev/null' EXIT

# run <shell> <code> -> prints any shell-error signature lines on the run
run() {
  local sh=$1 code=$2 out
  out=$( timeout 20 "$sh" -c "source '$LIB'; $code" </dev/null 2>&1 >/dev/null )
  printf '%s' "$out" | grep -nE "$SIG" | head -2
}

# Part A — every function, no-args + -h path
mapfile -t FNS < <(grep -oE '^jwps_[a-z-]+' "$LIB" | sort -u)
echo "=== Part A: no-args / -h path of ${#FNS[@]} functions ==="
for sh in "${SHELLS[@]}"; do
  n=0
  for fn in "${FNS[@]}"; do
    for inv in "$fn" "$fn -h"; do
      hit=$(run "$sh" "$inv")
      if [ -n "$hit" ]; then
        printf "  ❌ [%s] %-24s %s\n" "$sh" "$inv" "$(printf '%s' "$hit" | head -1)"
        FAILED=$((FAILED + 1)); n=$((n + 1))
      fi
    done
  done
  [ "$n" -eq 0 ] && echo "  ✅ $sh: all clean"
done

# Part B — real invocations against the live system + tagged sleep + error paths
echo "=== Part B: real invocations (tagged sleep pid: $SLEEP_PID) ==="
B=(
  "jwps_find 424242"            # real match — our tagged background sleep
  "jwps_find no_such_proc_xyz"  # zero matches -> "(no processes match: ...)"
  "jwps_find sh"               # broad match (many hits)
  "jwps_find 'sleep.*424242'"   # a real extended-regex pattern
  "jwps_ports"                 # live listening sockets
  "jwps_top"                   # default count
  "jwps_top 5"
  "jwps_top 1"                 # single row past the header
  "jwps_top notanint"          # bad-count error path
)
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

# Part C — bash-vs-zsh stdout parity for DETERMINISTIC paths only
echo "=== Part C: bash-vs-zsh stdout parity (toc + -h + deterministic messages) ==="
if [ "${#SHELLS[@]}" -ge 2 ]; then
  RO=(
    'jwps_toc'
    'jwps_find -h'
    'jwps_ports -h'
    'jwps_top -h'
    'jwps_find'                    # no-args usage block (return 1, deterministic stdout)
    'jwps_find no_such_proc_xyz'   # deterministic no-match line
    'jwps_top notanint'            # deterministic bad-count error
  )
  n=0
  for inv in "${RO[@]}"; do
    b=$( timeout 15 bash -c "source '$LIB'; $inv" </dev/null 2>/dev/null )
    z=$( timeout 15 zsh  -c "source '$LIB'; $inv" </dev/null 2>/dev/null )
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
  echo "✅ smoke OK — no runtime-error signatures (${SHELLS[*]})"
  exit 0
fi
echo "❌ smoke FAILED — $FAILED issue(s) above"
exit 1
