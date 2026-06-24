#!/usr/bin/env bash
#
# Smoke test for jw_functions__web.sh
# ===================================
# Runs every jwweb_* function under BOTH bash and zsh, failing if any zsh/bash
# RUNTIME-error signature appears — e.g. "read-only variable" (a reserved name
# like `status`/`path`), "bad substitution", or "no matches found". These
# surface only when a function RUNS, so we execute them (`-n`/`type` miss them).
#
# Network policy: the no-args paths (Part A) and the -h/no-args stdout parity
# (Part C) touch NO network and are fully deterministic. The real-arg path
# (Part B) needs a server, so it spins a throwaway `python3 -m http.server` on
# loopback and probes that + a couple of deliberate failure targets (closed
# port, https-to-plain-http). Part B only scans for shell-error signatures —
# never output correctness (IPs/timing vary) — and self-skips without python3.
#
# Run:  bash tests/smoke_web.sh   (or ./tests/smoke_web.sh)
# Exit: 0 = clean, 1 = runtime-error signature found, 2 = setup problem.

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LIB="$SCRIPT_DIR/../jw_functions__web.sh"

[ -f "$LIB" ] || { echo "❌ cannot find library: $LIB"; exit 2; }
command -v curl >/dev/null 2>&1 || { echo "❌ curl is required"; exit 2; }

# Test under whichever of bash/zsh are installed
SHELLS=()
for sh in bash zsh; do command -v "$sh" >/dev/null 2>&1 && SHELLS+=("$sh"); done
[ "${#SHELLS[@]}" -gt 0 ] || { echo "❌ neither bash nor zsh found"; exit 2; }
command -v zsh >/dev/null 2>&1 || echo "⚠️  zsh not installed — testing bash only"

# Shell runtime-error signatures (NOT curl/openssl/dig's own diagnostics)
SIG='read-only variable|integer expression|command not found|parse error|bad pattern|bad substitution|no matches found|unbound|number expected|bad math|maximum nested'

FAILED=0

# run <shell> <code> -> prints any signature lines found on the run's stderr
run() {
  local sh=$1 code=$2 out
  out=$( timeout 20 "$sh" -c "source '$LIB'; $code" </dev/null 2>&1 >/dev/null )
  printf '%s' "$out" | grep -nE "$SIG" | head -2
}

# Part A — every function, no-args path (no network)
mapfile -t FNS < <(grep -oE '^jwweb_[a-z-]+' "$LIB" | sort -u)
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

# Part C — bash-vs-zsh stdout parity for the no-network paths (toc + -h help).
# A difference here is a shell-specific OUTPUT bug (stale `local` reprint, etc.).
echo "=== Part C: bash-vs-zsh stdout parity (toc + help, no network) ==="
if [ "${#SHELLS[@]}" -ge 2 ]; then
  RO=(
    'jwweb_toc'
    'jwweb_headers -h'
    'jwweb_timing -h'
    'jwweb_cert-expiry -h'
    'jwweb_dns -h'
    'jwweb_port -h'
    'jwweb_diag -h'
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

# Part B — real-arg invocations against a throwaway local server + failure paths.
echo "=== Part B: real-arg invocations (local fixture) ==="
if ! command -v python3 >/dev/null 2>&1; then
  echo "  ⏭️  skipped (needs python3 for the loopback HTTP fixture)"
else
  PORT=$(( 8090 + (RANDOM % 200) ))
  ( cd "$SCRIPT_DIR" && exec python3 -m http.server "$PORT" --bind 127.0.0.1 ) >/dev/null 2>&1 &
  SRV=$!
  trap 'kill "$SRV" >/dev/null 2>&1' EXIT
  # give it a moment to bind
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    curl -sS -o /dev/null "http://127.0.0.1:$PORT/" 2>/dev/null && break
    sleep 0.3
  done

  B=(
    "jwweb_headers http://127.0.0.1:$PORT/"
    "jwweb_headers 127.0.0.1:$PORT --all"
    "jwweb_timing http://127.0.0.1:$PORT/"
    "jwweb_diag http://127.0.0.1:$PORT/"
    "jwweb_diag http://127.0.0.1:1/"            # closed port -> TCP/HTTP fail path
    "jwweb_diag https://127.0.0.1:$PORT/"       # TLS-to-plaintext -> handshake fail path
    "jwweb_cert-expiry 127.0.0.1:$PORT"         # no TLS -> cert-fetch fail path
    "jwweb_cert-expiry 127.0.0.1:$PORT --exit-code"
    "jwweb_dns localhost"                       # /etc/hosts name (dig may return nothing)
    "jwweb_dns 127.0.0.1"
    "jwweb_port 127.0.0.1 $PORT 1"              # one open, one closed
    "jwweb_port http://127.0.0.1:$PORT/"        # port taken from the URL
  )
  for sh in "${SHELLS[@]}"; do
    n=0
    for inv in "${B[@]}"; do
      hit=$(run "$sh" "$inv")
      if [ -n "$hit" ]; then
        printf "  ❌ [%s] %-44s %s\n" "$sh" "$inv" "$(printf '%s' "$hit" | head -1)"
        FAILED=$((FAILED + 1)); n=$((n + 1))
      fi
    done
    [ "$n" -eq 0 ] && echo "  ✅ $sh: all clean"
  done
fi

echo
if [ "$FAILED" -eq 0 ]; then
  echo "✅ smoke OK — no runtime-error signatures (${SHELLS[*]})"
  exit 0
fi
echo "❌ smoke FAILED — $FAILED issue(s) above"
exit 1
