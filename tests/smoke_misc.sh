#!/usr/bin/env bash
#
# Smoke test for jw_functions__misc.sh
# ====================================
# Runs every misc function under BOTH bash and zsh, failing if any zsh/bash
# RUNTIME-error signature appears — e.g. "bad substitution", "no matches found",
# or zsh's "defining function based on alias". These surface only when a function
# RUNS (or a file is RE-SOURCED), so we execute them (`-n`/`type` miss them).
#
# No real network and no real clipboard, ever:
#   - every run gets dummy API keys (smokekey) and https_proxy pointing at a closed
#     local port, so even an un-stubbed curl fails locally (exit 7, nothing leaves
#     the machine);
#   - where a case needs an API answer, curl is replaced by a sourced stub that
#     returns a canned body and reports how the key was passed;
#   - xclip is shadowed by a PATH stub, so jwpaste dumps a marker, not your
#     clipboard. Files the functions write to /tmp carry a tag and are removed on exit.
#
# Part A: no-args / -h path of every function.
# Part B: real invocations (stubbed where they would reach the network) + error paths.
# Part C: bash-vs-zsh stdout parity of the deterministic paths (jwrandnumgen's
#         random numbers excluded).
# Part D: behaviour checks — help return codes, API key never in curl's argv,
#         loud failures, answer cleanup, re-source safety, zsh noglob alias.
#
# Run:  bash tests/smoke_misc.sh   (or ./tests/smoke_misc.sh)
# Exit: 0 = clean, 1 = runtime-error signature / parity diff / failed check, 2 = setup problem.

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LIB="$SCRIPT_DIR/../jw_functions__misc.sh"

[ -f "$LIB" ] || { echo "❌ cannot find library: $LIB"; exit 2; }

# Test under whichever of bash/zsh are installed
SHELLS=()
for sh in bash zsh; do command -v "$sh" >/dev/null 2>&1 && SHELLS+=("$sh"); done
[ "${#SHELLS[@]}" -gt 0 ] || { echo "❌ neither bash nor zsh found"; exit 2; }
command -v zsh >/dev/null 2>&1 || echo "⚠️  zsh not installed — testing bash only"
command -v jq >/dev/null 2>&1 || { echo "❌ jq not found (jwai_sonar and this test need it)"; exit 2; }

# Shell runtime-error signatures (NOT curl's / the functions' own diagnostics)
SIG='read-only variable|integer expression|command not found|parse error|bad pattern|bad substitution|no matches found|unbound|number expected|bad math|maximum nested|defining function based on alias'

FAILED=0

# --- fixture ---------------------------------------------------------------------
FIX=$(mktemp -d)
TAG="jwsmoke$$"                  # marks every /tmp file the functions write
trap 'rm -rf "$FIX"; rm -f /tmp/jina-dump-*-"$TAG".md; grep -l -- "$TAG" /tmp/clip-dump-* 2>/dev/null | xargs -r rm -f' EXIT

# xclip stub: jwpaste reads this instead of the real clipboard
mkdir -p "$FIX/bin"
printf '#!/bin/sh\necho "clipboard-%s"\n' "$TAG" > "$FIX/bin/xclip"
chmod +x "$FIX/bin/xclip"

# canned OpenRouter bodies
cat > "$FIX/ok.json" <<'EOF'
{"choices":[{"message":{"content":"## Heading\n**bold** text [1][2] and `code` [3, 4], keep __init__\n- item"}}]}
EOF
printf '%s' '{"error":{"message":"No auth credentials found","code":401}}' > "$FIX/err.json"
printf '%s' '<html>proxy denied</html>' > "$FIX/html.txt"
EXPECT=$'Heading\nbold text  and code , keep __init__\n- item'

# curl stub (sourced per case): flags the key in argv, echoes the header file and
# (with STUB_SHOWQ) the question to stderr; writes the -o target (Jina) or prints
# $STUB_BODY_FILE (OpenRouter). Never touches the network.
cat > "$FIX/curl_stub.sh" <<'EOF'
curl() {
  local a p="" o=""
  for a in "$@"; do
    case "$a" in *smokekey*) echo "LEAK: API key in curl argv" >&2 ;; esac
    case "$a" in @*) printf 'header: %s\n' "$(cat "${a#@}")" >&2 ;; esac
    if [ "$p" = "-d" ] && [ -n "${STUB_SHOWQ:-}" ]; then
      printf 'question: %s\n' "$(printf '%s' "$a" | jq -r '.messages[1].content')" >&2
    fi
    [ "$p" = "-o" ] && o=$a
    p=$a
  done
  if [ -n "$o" ]; then printf '# stub page\n' > "$o"; else cat "${STUB_BODY_FILE:-/dev/null}"; fi
}
EOF
STUB="source '$FIX/curl_stub.sh';"

# Every run: dummy keys, dead proxy (no real network), xclip stub first on PATH, bounded.
SANDBOX=(env -u no_proxy -u NO_PROXY -u all_proxy -u ALL_PROXY
         https_proxy=http://127.0.0.1:9 HTTPS_PROXY=http://127.0.0.1:9
         http_proxy=http://127.0.0.1:9 HTTP_PROXY=http://127.0.0.1:9
         JWSONAR_OR_APIKEY=smokekey JINA_AI_API_KEY=smokekey
         PATH="$FIX/bin:$PATH" timeout 20)

# run <shell> <code> -> prints any shell-error signature lines on the run
run() {
  local sh=$1 code=$2 out
  out=$( "${SANDBOX[@]}" "$sh" -c "source '$LIB'; $code" </dev/null 2>&1 >/dev/null )
  printf '%s' "$out" | grep -nE "$SIG" | head -2
}

# Part A — every function, no-args + -h path
mapfile -t FNS < <(grep -oE '^(function +)?jw[A-Za-z0-9_-]+' "$LIB" | sed 's/^function *//' | sort -u)
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

# Part B — real invocations (stubbed where they would reach the network) + error paths
echo "=== Part B: real invocations + error paths ==="
B=(
  "jwgoogle"
  "jwgoogle 'label:x'"                                  # prefix carried into every line
  "jwnotatki"
  "jwnotatki proj"                                      # modal lookup lines
  "jwrandnumgen 6"
  "jwrandnumgen abc"                                    # bad LIMIT -> error
  "jwrandnumgen 0"                                      # LIMIT < 1 -> error
  "jwpaste"                                             # xclip stub -> marker, not your clipboard
  "jwai_jina notaurl"                                   # bad URL -> error + usage
  "unset JINA_AI_API_KEY; jwai_jina https://example.com" # missing key
  "jwai_jina https://example.com $TAG"                  # real curl -> dead proxy -> loud failure
  "$STUB jwai_jina https://example.com $TAG"            # stubbed fetch -> tagged /tmp file
  "unset JWSONAR_OR_APIKEY; jwai_sonar q"               # missing key
  "jwai_sonar q"                                        # real curl -> dead proxy -> loud failure
  "$STUB STUB_BODY_FILE='$FIX/ok.json' jwai_sonar q"    # success, Markdown stripped
  "$STUB STUB_BODY_FILE='$FIX/err.json' jwai_sonar q"   # API error JSON
  "$STUB STUB_BODY_FILE='$FIX/html.txt' jwai_sonar q"   # non-JSON body
  "source '$LIB'; jwai_sonar -h"                        # re-source (zsh: alias already set)
)
for sh in "${SHELLS[@]}"; do
  n=0
  for inv in "${B[@]}"; do
    hit=$(run "$sh" "$inv")
    if [ -n "$hit" ]; then
      printf "  ❌ [%s] %-40s %s\n" "$sh" "${inv:0:40}" "$(printf '%s' "$hit" | head -1)"
      FAILED=$((FAILED + 1)); n=$((n + 1))
    fi
  done
  [ "$n" -eq 0 ] && echo "  ✅ $sh: all clean"
done

# Part C — bash-vs-zsh stdout parity for DETERMINISTIC paths only
echo "=== Part C: bash-vs-zsh stdout parity (help + deterministic output) ==="
if [ "${#SHELLS[@]}" -ge 2 ]; then
  RO=(
    'jwgoogle'
    "jwgoogle 'label:x'"
    'jwnotatki'
    'jwnotatki proj'
    'jwrandnumgen'                                      # no-args usage block (return 1)
    'jwrandnumgen -h'
    'jwpaste'                                           # stub marker
    'jwai_jina'                                         # no-args usage block (return 1)
    'jwai_jina -h'
    'jwai_sonar'                                        # no-args usage block (return 1)
    'jwai_sonar -h'
    "$STUB STUB_BODY_FILE='$FIX/ok.json' jwai_sonar q"  # cleaned answer
  )
  n=0
  for inv in "${RO[@]}"; do
    b=$( "${SANDBOX[@]}" bash -c "source '$LIB'; $inv" </dev/null 2>/dev/null )
    z=$( "${SANDBOX[@]}" zsh  -c "source '$LIB'; $inv" </dev/null 2>/dev/null )
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

# Part D — behaviour checks
echo "=== Part D: help rc, key off argv, loud failures, cleanup, re-source, noglob ==="
fail() { printf "  ❌ [%s] %s\n" "$sh" "$1"; FAILED=$((FAILED + 1)); n=$((n + 1)); }
for sh in "${SHELLS[@]}"; do
  n=0

  # help: no args -> 1, -h -> 0
  for fn in jwrandnumgen jwai_jina jwai_sonar; do
    "${SANDBOX[@]}" "$sh" -c "source '$LIB'; $fn" </dev/null >/dev/null 2>&1
    rc=$?; [ "$rc" -eq 1 ] || fail "$fn (no args) returned $rc, expected 1"
    "${SANDBOX[@]}" "$sh" -c "source '$LIB'; $fn -h" </dev/null >/dev/null 2>&1
    rc=$?; [ "$rc" -eq 0 ] || fail "$fn -h returned $rc, expected 0"
  done

  # the API key goes in via a header file, never in curl's argv
  for inv in "jwai_sonar q" "jwai_jina https://example.com $TAG"; do
    err=$( "${SANDBOX[@]}" "$sh" -c "source '$LIB'; $STUB STUB_BODY_FILE='$FIX/ok.json' $inv" </dev/null 2>&1 >/dev/null )
    case "$err" in *LEAK*) fail "$inv: API key visible in curl argv" ;; esac
    case "$err" in *'header: Authorization: Bearer smokekey'*) ;; *) fail "$inv: no Authorization header file" ;; esac
  done

  # failures are loud: non-zero rc + the expected message on stderr
  for c in "jwai_sonar q|request to OpenRouter failed (curl exit 7)" \
           "$STUB STUB_BODY_FILE='$FIX/err.json' jwai_sonar q|OpenRouter: No auth credentials found" \
           "$STUB STUB_BODY_FILE='$FIX/html.txt' jwai_sonar q|unexpected response from OpenRouter" \
           "jwai_jina https://example.com $TAG|cURL failed (exit code 7)"; do
    inv=${c%%|*}; want=${c#*|}
    err=$( "${SANDBOX[@]}" "$sh" -c "source '$LIB'; $inv" </dev/null 2>&1 >/dev/null )
    rc=$?
    [ "$rc" -ne 0 ] || fail "${inv##*;} returned 0 on failure"
    case "$err" in *"$want"*) ;; *) fail "${inv##*;}: stderr lacks '$want'" ;; esac
  done

  # answer cleanup: Markdown + [n] markers stripped, __identifiers__ kept
  got=$( "${SANDBOX[@]}" "$sh" -c "source '$LIB'; $STUB STUB_BODY_FILE='$FIX/ok.json' jwai_sonar q" </dev/null 2>/dev/null )
  [ "$got" = "$EXPECT" ] || fail "jwai_sonar cleanup: got '$(printf '%s' "$got" | tr '\n' '|')'"

  # re-source: a second load must stay silent and working (zsh: alias over the function)
  err=$( "${SANDBOX[@]}" "$sh" -c "source '$LIB'; source '$LIB'; jwai_sonar -h" </dev/null 2>&1 >/dev/null )
  rc=$?
  { [ "$rc" -eq 0 ] && [ -z "$err" ]; } || fail "re-source: rc=$rc $(printf '%s' "$err" | head -1)"

  # zsh: the noglob alias lets an unquoted ? reach the function (eval parses after
  # the alias exists, as an interactive line would)
  if [ "$sh" = zsh ]; then
    q=$( "${SANDBOX[@]}" zsh -c "source '$LIB'; $STUB STUB_SHOWQ=1; STUB_BODY_FILE='$FIX/ok.json'; eval 'jwai_sonar what is X?'" </dev/null 2>&1 >/dev/null | sed -n 's/^question: //p' )
    [ "$q" = "what is X?" ] || fail "noglob alias: question arrived as '$q'"
  fi

  [ "$n" -eq 0 ] && echo "  ✅ $sh: all checks pass"
done

echo
if [ "$FAILED" -eq 0 ]; then
  echo "✅ smoke OK — no runtime-error signatures (${SHELLS[*]})"
  exit 0
fi
echo "❌ smoke FAILED — $FAILED issue(s) above"
exit 1
