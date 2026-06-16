#!/usr/bin/env bash
#
# Smoke test for jw_functions__docker.sh
# ======================================
# Runs the jwdocker_* functions under BOTH bash and zsh, failing if any shell
# RUNTIME-error signature appears — e.g. zsh's "read-only variable" (a reserved
# name like `status`/`path`), "integer expression expected" (a
# `grep -c ... || echo 0` double-zero), a glob "no matches found", or an
# unbound variable. `bash -n`/`zsh -n`/`type` only check PARSING; these bugs
# surface only when the function actually runs, so we execute them.
#
# SAFETY — these functions wrap the REAL docker daemon on this machine. The test
# is built to never start, stop, remove, prune, build, pull, push or otherwise
# mutate anything. A container (total + running), image, network and volume
# count is snapshotted before and after the run and the test FAILS if any of
# them changed — the running count catches a stray stop/start the total misses.
#   * Prompting functions (prune, cleanup, volume-prune, network-prune, and the
#     no-args "stop all? / remove all?" paths) are fed </dev/null, so the
#     confirmation read() hits EOF and the function cancels before any docker
#     mutation.
#   * Mutating functions are only ever invoked with a NON-EXISTENT target in
#     Part B, so docker errors out ("No such ...") before changing anything.
#   * Functions that reach the registry/network or write files (run, image-pull,
#     image-build, push, search, save, load, export, import, backup) are
#     exercised ONLY on their no-args usage path (Part A), never with arguments.
#
# Coverage:
#   Part A — no-args path of every function defined in the library.
#   Part B — read-only functions with a REAL target, plus the non-existent-target
#            validation paths of the destructive container/image/volume/network
#            removers. No genuine mutation is ever performed.
#   Part C — bash-vs-zsh stdout parity for deterministic read-only functions.
# NOT covered by automated parity (verified by hand instead):
#   * jwdocker_monitor-stats/-health, jwdocker_containers/ps* — embed live
#     CPU%/"Up N minutes", so output is non-deterministic between two runs.
#   * jwdocker_container-inspect — docker returns .Mounts in non-deterministic
#     order between calls, so its byte output isn't stable (Part B still runs it).
#   * registry/filesystem mutators (run/pull/build/push/search/save/load/
#     export/import/backup) beyond their usage path, and real (confirmed) prunes.
#   * jwdocker_findcontainerbyip and jwdocker_ps/psup (aliases, not functions).
#
# Run:  bash tests/smoke_jwdocker.sh   (or ./tests/smoke_jwdocker.sh)
# Exit: 0 = clean, 1 = signature / parity diff / STATE CHANGED, 2 = setup.

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LIB="$SCRIPT_DIR/../jw_functions__docker.sh"
COLORS="$SCRIPT_DIR/../jw_colors.sh"   # jwdocker_monitor-health uses jwpaintfg*

[ -f "$LIB" ]    || { echo "❌ cannot find library: $LIB"; exit 2; }
[ -f "$COLORS" ] || { echo "❌ cannot find colors:  $COLORS"; exit 2; }
command -v docker >/dev/null 2>&1 || { echo "❌ docker is required"; exit 2; }
docker version --format '{{.Server.Version}}' >/dev/null 2>&1 \
  || { echo "❌ docker daemon not reachable"; exit 2; }

# Test under whichever of bash/zsh are installed
SHELLS=()
for sh in bash zsh; do command -v "$sh" >/dev/null 2>&1 && SHELLS+=("$sh"); done
[ "${#SHELLS[@]}" -gt 0 ] || { echo "❌ neither bash nor zsh found"; exit 2; }
command -v zsh >/dev/null 2>&1 || echo "⚠️  zsh not installed — testing bash only"

# Real targets for the read-only paths (captured once, reused by both shells so
# parity comparisons line up). A package that does NOT exist for validation.
CON=$(docker ps     --format '{{.Names}}' 2>/dev/null | head -1)
NET=$(docker network ls --format '{{.Name}}' 2>/dev/null | grep -v '^none$' | head -1)
VOL=$(docker volume ls  --format '{{.Name}}' 2>/dev/null | head -1)
IMG=$(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -v '<none>' | head -1)
NOPE=zzz-jwdocker-smoke-nonexistent

# Snapshot real state so we can prove the test mutated nothing.
snapshot() { printf '%s|%s|%s|%s|%s' \
  "$(docker ps -aq 2>/dev/null | wc -l)" "$(docker ps -q 2>/dev/null | wc -l)" \
  "$(docker images -q 2>/dev/null | wc -l)" "$(docker network ls -q 2>/dev/null | wc -l)" \
  "$(docker volume ls -q 2>/dev/null | wc -l)"; }
STATE_BEFORE=$(snapshot)

# Shell runtime-error signatures (NOT docker's own "Error: No such ..." messages)
SIG='read-only variable|integer expression|command not found|parse error|bad pattern|bad substitution|no matches found|unbound|number expected|bad math|maximum nested'

FAILED=0

# run <shell> <code> -> prints any signature lines found on the run's stderr
run() {
  local sh=$1 code=$2 out
  out=$( timeout 30 "$sh" -c "source '$COLORS'; source '$LIB'; $code" </dev/null 2>&1 >/dev/null )
  printf '%s' "$out" | grep -nE "$SIG" | head -2
}

# Part A — every function, no-args path (all paths are usage / read-only default
# / a prompt that cancels on EOF — see SAFETY header).
mapfile -t FNS < <(grep -oE '^jwdocker_[a-z-]+' "$LIB" | sort -u)
echo "=== Part A: no-args path of ${#FNS[@]} functions ==="
for sh in "${SHELLS[@]}"; do
  n=0
  for fn in "${FNS[@]}"; do
    hit=$(run "$sh" "$fn")
    if [ -n "$hit" ]; then
      printf "  ❌ [%s] %-26s %s\n" "$sh" "$fn" "$(printf '%s' "$hit" | head -1)"
      FAILED=$((FAILED + 1)); n=$((n + 1))
    fi
  done
  [ "$n" -eq 0 ] && echo "  ✅ $sh: all clean"
done

# Part B — read-only with a real target, plus removers with a non-existent target
# (they validate / docker errors before mutating). Entries needing a target that
# is absent on this host are skipped.
B=()
[ -n "$CON" ] && B+=("jwdocker_logs $CON" "jwdocker_container-inspect $CON" \
                     "jwdocker_port $CON" "jwdocker_monitor-top $CON" \
                     "jwdocker_monitor-stats $CON")
[ -n "$NET" ] && B+=("jwdocker_network-inspect $NET")
[ -n "$VOL" ] && B+=("jwdocker_volume-inspect $VOL")
[ -n "$IMG" ] && B+=("jwdocker_image-history $IMG")
B+=("jwdocker_container-remove $NOPE" "jwdocker_container-start $NOPE" \
    "jwdocker_container-stop $NOPE"   "jwdocker_container-restart $NOPE" \
    "jwdocker_image-rm $NOPE"         "jwdocker_volume-remove $NOPE" \
    "jwdocker_network-remove $NOPE")
echo "=== Part B: ${#B[@]} real-arg invocations (read-only + non-existent-target paths) ==="
for sh in "${SHELLS[@]}"; do
  n=0
  for inv in "${B[@]}"; do
    hit=$(run "$sh" "$inv")
    if [ -n "$hit" ]; then
      printf "  ❌ [%s] %-38s %s\n" "$sh" "$inv" "$(printf '%s' "$hit" | head -1)"
      FAILED=$((FAILED + 1)); n=$((n + 1))
    fi
  done
  [ "$n" -eq 0 ] && echo "  ✅ $sh: all clean"
done

# Part C — bash-vs-zsh stdout parity for deterministic read-only functions.
# Catches shell-specific OUTPUT bugs (bare `local x` reprint in zsh, reserved
# vars, read-r leading-space trim) that Part A/B's stderr scan cannot see.
echo "=== Part C: bash-vs-zsh stdout parity (read-only functions) ==="
if [ "${#SHELLS[@]}" -ge 2 ]; then
  RO=("jwdocker_toc")
  [ -n "$CON" ] && RO+=("jwdocker_port $CON")
  [ -n "$NET" ] && RO+=("jwdocker_network-inspect $NET")
  [ -n "$VOL" ] && RO+=("jwdocker_volume-inspect $VOL")
  [ -n "$IMG" ] && RO+=("jwdocker_image-history $IMG")
  n=0
  for inv in "${RO[@]}"; do
    b=$( timeout 30 bash -c "source '$COLORS'; source '$LIB'; $inv" </dev/null 2>/dev/null )
    z=$( timeout 30 zsh  -c "source '$COLORS'; source '$LIB'; $inv" </dev/null 2>/dev/null )
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

# Safety net — prove the test changed no real docker state.
STATE_AFTER=$(snapshot)
echo "=== State check (all|running|images|networks|volumes) ==="
if [ "$STATE_BEFORE" = "$STATE_AFTER" ]; then
  echo "  ✅ unchanged: $STATE_AFTER"
else
  echo "  ❌ STATE CHANGED!  before=$STATE_BEFORE  after=$STATE_AFTER"
  FAILED=$((FAILED + 1))
fi

echo
if [ "$FAILED" -eq 0 ]; then
  echo "✅ smoke OK — no runtime-error signatures, parity diffs, or state changes (${SHELLS[*]})"
  exit 0
fi
echo "❌ smoke FAILED — $FAILED issue(s) above"
exit 1
