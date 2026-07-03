#!/usr/bin/env bash
#
# Smoke test for jw_functions__files.sh
# =====================================
# Runs every jwfiles_* function under BOTH bash and zsh, failing if any zsh/bash
# RUNTIME-error signature appears — e.g. "read-only variable" (a reserved name
# like `status`/`path`), "bad substitution", or "no matches found". These
# surface only when a function RUNS, so we execute them (`-n`/`type` miss them).
#
# This area is read-only, so there is no daemon/system state to protect: every
# function is exercised against a throwaway fixture tree built under mktemp
# (rich enough — nested dirs, hidden/empty items, valid+broken symlinks, a
# spaced name, several extensions — to drive every loop past one iteration).
#
# Part A: no-args / -h path of every function (deterministic).
# Part B: real-arg invocations against the fixture + error paths.
# Part C: bash-vs-zsh stdout parity of the deterministic paths (toc, -h, and the
#         two uncapped viewers on the fixture — a diff here is a shell OUTPUT bug,
#         e.g. a stale `local` reprint). jwfiles_profile is scanned but NOT
#         parity-checked: it prints live `df`, which can shift between the runs.
#
# Run:  bash tests/smoke_jwfiles.sh   (or ./tests/smoke_jwfiles.sh)
# Exit: 0 = clean, 1 = runtime-error signature / parity diff, 2 = setup problem.

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LIB="$SCRIPT_DIR/../jw_functions__files.sh"

[ -f "$LIB" ] || { echo "❌ cannot find library: $LIB"; exit 2; }

# Test under whichever of bash/zsh are installed
SHELLS=()
for sh in bash zsh; do command -v "$sh" >/dev/null 2>&1 && SHELLS+=("$sh"); done
[ "${#SHELLS[@]}" -gt 0 ] || { echo "❌ neither bash nor zsh found"; exit 2; }
command -v zsh >/dev/null 2>&1 || echo "⚠️  zsh not installed — testing bash only"

# Shell runtime-error signatures (NOT find/du/df's own diagnostics)
SIG='read-only variable|integer expression|command not found|parse error|bad pattern|bad substitution|no matches found|unbound|number expected|bad math|maximum nested'

FAILED=0

# --- throwaway fixture tree --------------------------------------------------
FIX=$(mktemp -d 2>/dev/null) || { echo "❌ cannot mktemp"; exit 2; }
trap 'rm -rf "$FIX"' EXIT
mkdir -p "$FIX/sub/deep" "$FIX/empty_dir"
printf 'aaaa\n'              > "$FIX/a.txt"
head -c 4096 /dev/zero       > "$FIX/big.log"  2>/dev/null
printf 'note\n'             > "$FIX/readme.md"
printf 'x\n'               > "$FIX/sub/nested.txt"
printf 'y\n'              > "$FIX/sub/deep/data.json"
printf '#\n'             > "$FIX/.hidden"
: > "$FIX/empty.txt"                              # empty file
printf 'spaced\n'          > "$FIX/with space.txt"
printf 'z\n'               > "$FIX/weird\$name.txt" # shell-special char in name
printf 'z\n'               > "$FIX/ąę.txt"          # non-ASCII name
ln -s a.txt                  "$FIX/link_ok"        # valid symlink
ln -s does_not_exist         "$FIX/link_broken"    # broken symlink

# run <shell> <code> -> prints any shell-error signature lines on the run
run() {
  local sh=$1 code=$2 out
  out=$( timeout 20 "$sh" -c "source '$LIB'; $code" </dev/null 2>&1 >/dev/null )
  printf '%s' "$out" | grep -nE "$SIG" | head -2
}

# Part A — every function, no-args path
mapfile -t FNS < <(grep -oE '^jwfiles_[a-z-]+' "$LIB" | sort -u)
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

# Part B — real-arg invocations against the fixture + error paths
echo "=== Part B: real-arg invocations (fixture: $FIX) ==="
B=(
  "jwfiles_profile '$FIX'"
  "jwfiles_profile '$FIX/sub'"
  "jwfiles_size '$FIX'"
  "jwfiles_size '$FIX/empty_dir'"           # empty dir -> nothing but total
  "jwfiles_newest '$FIX'"
  "jwfiles_newest 3 '$FIX'"
  "jwfiles_newest '$FIX/sub'"
  "jwfiles_find txt '$FIX'"                  # multiple hits
  "jwfiles_find no_such_phrase '$FIX'"       # zero hits
  "jwfiles_grep spaced '$FIX'"              # content hit
  "jwfiles_grep no_such_content_xyz '$FIX'" # zero hits (exit 1, not an error)
  "jwfiles_ext '$FIX'"
  "jwfiles_tree '$FIX'"
  "jwfiles_tree '$FIX' 1"
  "jwfiles_bigfiles '$FIX'"
  "jwfiles_bigfiles 3 '$FIX'"
  "jwfiles_disk '$FIX'"
  "jwfiles_oldest '$FIX'"
  "jwfiles_oldest 2 '$FIX'"
  "jwfiles_stat '$FIX/a.txt'"
  "jwfiles_stat '$FIX/link_broken'"         # broken symlink -> reports the link
  "jwfiles_stat '$FIX'"                      # a directory
  "jwfiles_perms '$FIX'"
  "jwfiles_owners '$FIX'"
  "jwfiles_symlinks '$FIX'"
  "jwfiles_empty '$FIX'"
  "jwfiles_weirdnames '$FIX'"
  "jwfiles_backup '$FIX/a.txt'"             # 🟢 prints the cp -a command (no side effect)
  "jwfiles_backup '$FIX/empty_dir'"         # prints the command for a directory too
  "jwfiles_profile /nonexistent_xyz"        # not-a-dir error path
  "jwfiles_size /nonexistent_xyz"
  "jwfiles_newest 5 /nonexistent_xyz"
  "jwfiles_find x /nonexistent_xyz"
  "jwfiles_ext /nonexistent_xyz"
  "jwfiles_tree /nonexistent_xyz"
  "jwfiles_tree '$FIX' notanint"            # bad-depth error path
  "jwfiles_disk /nonexistent_xyz"
  "jwfiles_oldest 2 /nonexistent_xyz"
  "jwfiles_stat /nonexistent_xyz"
  "jwfiles_perms /nonexistent_xyz"
  "jwfiles_owners /nonexistent_xyz"
  "jwfiles_symlinks /nonexistent_xyz"
  "jwfiles_empty /nonexistent_xyz"
  "jwfiles_weirdnames /nonexistent_xyz"
  "jwfiles_backup /nonexistent_xyz"         # missing path -> warns, still prints cmd
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

# Part C — bash-vs-zsh stdout parity for deterministic paths
echo "=== Part C: bash-vs-zsh stdout parity (toc + -h + uncapped viewers) ==="
if [ "${#SHELLS[@]}" -ge 2 ]; then
  RO=(
    'jwfiles_toc'
    'jwfiles_profile -h'
    'jwfiles_size -h'
    'jwfiles_newest -h'
    "jwfiles_size '$FIX'"
    "jwfiles_newest '$FIX'"
    "jwfiles_newest 3 '$FIX'"
    "jwfiles_ext '$FIX'"
    "jwfiles_find txt '$FIX'"
    "jwfiles_grep spaced '$FIX'"
    "jwfiles_tree '$FIX'"
    "jwfiles_tree '$FIX' 1"
    "jwfiles_bigfiles '$FIX'"
    "jwfiles_bigfiles 3 '$FIX'"
    "jwfiles_oldest '$FIX'"
    "jwfiles_perms '$FIX'"
    "jwfiles_owners '$FIX'"
    "jwfiles_symlinks '$FIX'"
    "jwfiles_empty '$FIX'"
    "jwfiles_weirdnames '$FIX'"
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
