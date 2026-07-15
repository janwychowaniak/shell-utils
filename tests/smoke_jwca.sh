#!/usr/bin/env bash
#
# Smoke test for jw_functions__ca.sh
# =========================================
# Runs every jwca_* function under BOTH bash and zsh, failing if any zsh/bash
# RUNTIME-error signature appears — e.g. "read-only variable" (a reserved name
# like `status`/`path`), "bad substitution", or "no matches found". These surface
# only when a function RUNS, so we execute them (`-n`/`type` miss them).
#
# This area is 100% read-only: it reads the LOCAL trust store (/etc/ssl/certs,
# /usr/local/share/ca-certificates) and inspects local cert files — never opens a
# socket, never mutates the store. So there is no system state to protect. Two
# input sources drive the tools:
#   * the REAL system store, read-only (jwca_store/_list/_custom/_stores) — we cannot
#     control it, so those are error-scanned but NOT parity-checked (a CA could be
#     added/renewed between the two runs; that would be system noise, not a shell bug);
#   * a THROWAWAY openssl fixture (a self-signed CA + an EC leaf + key + CSR + a DER
#     copy + a multi-cert bundle) built in a temp dir, driving jwca_inspect's real
#     PEM/DER paths past a guaranteed match. Removed on exit.
#
# Part A: no-args / -h path of every function (deterministic).
# Part B: real invocations against the live store + the fixture + error paths.
# Part C: bash-vs-zsh stdout parity of the DETERMINISTIC paths only (toc, -h, the
#         usage / bad-arg messages, and jwca_inspect of the FIXED fixture files).
#
# Run:  bash tests/smoke_jwca.sh   (or ./tests/smoke_jwca.sh)
# Exit: 0 = clean, 1 = runtime-error signature / parity diff, 2 = setup problem.

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LIB="$SCRIPT_DIR/../jw_functions__ca.sh"

[ -f "$LIB" ] || { echo "❌ cannot find library: $LIB"; exit 2; }
command -v openssl >/dev/null 2>&1 || { echo "❌ openssl required to build the fixture"; exit 2; }

# Test under whichever of bash/zsh are installed
SHELLS=()
for sh in bash zsh; do command -v "$sh" >/dev/null 2>&1 && SHELLS+=("$sh"); done
[ "${#SHELLS[@]}" -gt 0 ] || { echo "❌ neither bash nor zsh found"; exit 2; }
command -v zsh >/dev/null 2>&1 || echo "⚠️  zsh not installed — testing bash only"

# Shell runtime-error signatures (NOT openssl's own diagnostics)
SIG='read-only variable|integer expression|command not found|parse error|bad pattern|bad substitution|no matches found|unbound|number expected|bad math|maximum nested'

FAILED=0

# --- throwaway fixture: a tiny PKI built with openssl -------------------------
FX=$(mktemp -d) || { echo "❌ mktemp failed"; exit 2; }
trap 'rm -rf "$FX"' EXIT
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$FX/ca.key" -out "$FX/ca.pem" \
    -subj "/CN=JW Smoke Root CA/O=JW Smoke" -days 3650 \
    -addext "basicConstraints=critical,CA:TRUE" 2>/dev/null
openssl ecparam -name prime256v1 -genkey -noout -out "$FX/leaf.key" 2>/dev/null
openssl req -new -key "$FX/leaf.key" -subj "/CN=smoke.example.com" -out "$FX/leaf.csr" 2>/dev/null
openssl x509 -req -in "$FX/leaf.csr" -CA "$FX/ca.pem" -CAkey "$FX/ca.key" -CAcreateserial \
    -out "$FX/leaf.pem" -days 30 \
    -extfile <(printf 'subjectAltName=DNS:smoke.example.com,DNS:www.smoke.example.com\nextendedKeyUsage=serverAuth\nkeyUsage=digitalSignature') 2>/dev/null
openssl x509 -in "$FX/ca.pem" -outform DER -out "$FX/ca.der" 2>/dev/null
cat "$FX/leaf.pem" "$FX/ca.pem" > "$FX/bundle.pem"   # a multi-cert PEM bundle
if ! { [ -s "$FX/ca.pem" ] && [ -s "$FX/leaf.pem" ] && [ -s "$FX/ca.der" ]; }; then
    echo "❌ fixture build failed"; exit 2
fi

# run <shell> <code> -> prints any shell-error signature lines on the run
run() {
  local sh=$1 code=$2 out
  out=$( timeout 30 "$sh" -c "source '$LIB'; $code" </dev/null 2>&1 >/dev/null )
  printf '%s' "$out" | grep -nE "$SIG" | head -2
}

# Part A — every function, no-args + -h path
mapfile -t FNS < <(grep -oE '^jwca_[a-z-]+' "$LIB" | sort -u)
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

# Part B — real invocations against the live store + fixture + error paths
echo "=== Part B: real invocations (fixture: $FX) ==="
B=(
  "jwca_store"                       # posture X-ray of the real store
  "jwca_list"                        # full trusted-CA list
  "jwca_custom"                      # local + disabled deviations
  "jwca_stores"                      # cross-store map (certutil/keytool may be absent)
  "jwca_inspect '$FX/ca.pem'"        # PEM, RSA, self-signed root, CA:TRUE
  "jwca_inspect '$FX/leaf.pem'"      # PEM, EC, SAN, EKU, not-CA, ~30d -> ⚠️
  "jwca_inspect '$FX/ca.der'"        # DER path (format autodetect defeated)
  "jwca_inspect '$FX/leaf.key'"      # a KEY, not a cert -> error path
  "jwca_inspect '$FX/leaf.csr'"      # a CSR, not a cert -> error path
  "jwca_inspect /no/such/file"       # missing file -> error path
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
echo "=== Part C: bash-vs-zsh stdout parity (toc + -h + fixed-fixture inspect) ==="
if [ "${#SHELLS[@]}" -ge 2 ]; then
  RO=(
    'jwca_toc'
    'jwca_store -h'
    'jwca_list -h'
    'jwca_custom -h'
    'jwca_inspect'                 # no-args usage block (return 1, deterministic stdout)
    'jwca_inspect -h'
    'jwca_stores -h'
    "jwca_inspect '$FX/ca.pem'"    # fixed fixture -> byte-identical in both shells
    "jwca_inspect '$FX/leaf.pem'"
    "jwca_inspect '$FX/ca.der'"
    "jwca_inspect '$FX/leaf.key'"  # deterministic error line
    'jwca_inspect /no/such/file'   # deterministic error line
  )
  n=0
  for inv in "${RO[@]}"; do
    b=$( timeout 20 bash -c "source '$LIB'; $inv" </dev/null 2>/dev/null )
    z=$( timeout 20 zsh  -c "source '$LIB'; $inv" </dev/null 2>/dev/null )
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
