# shellcheck shell=bash

# A collection of miscellaneous functions that are hard to categorize elsewhere

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


jwgoogle()
{
cat 1>&2 <<'EOF'

=================== GOOGLE =================== (notes regarding things I keep forgetting in terms of using the Gmail inbox filters)

 older_than:1d
 newer_than:1d
 newer_than:3d  older_than:2d 
 after:2016/12/31  before:2017/1/7

EOF

    local today yesterday week_this week_last reference_day month_this month_last
    local year_this year_last month_this_extended month_last_extended

    today=$(date +'%Y/%m/%d')
    yesterday=$(date --date='yesterday' +'%Y/%m/%d')

    week_this=$(date --date='last Monday' +'%Y/%m/%d')
    week_last=$(date --date='last Monday -1 week' +'%Y/%m/%d')

    reference_day=$(date +'%Y/%m/15')
    month_this=$(date --date="$reference_day" +'%Y/%m/01')
    month_last=$(date --date="$reference_day last month" +'%Y/%m/01')

    year_this=$(date +'%Y/01/01')
    year_last=$(date --date='last year' +'%Y/01/01')

    month_this_extended=$(date --date="$month_this +4 days" +'%Y/%m/%d')
    month_last_extended=$(date --date="$month_last -6 days" +'%Y/%m/%d')

    local argsstr="${*:+$*  }"  # Handle optional arguments more concisely

    # Print the output with consistent formatting
    printf "\n%safter:%s                            <- today\n" "$argsstr" "$today"
    printf "%safter:%s  before:%s         <- yesterday\n\n" "$argsstr" "$yesterday" "$today"

    printf "%safter:%s                            <- week: this\n" "$argsstr" "$week_this"
    printf "%safter:%s  before:%s         <- week: last\n\n" "$argsstr" "$week_last" "$week_this"

    printf "%safter:%s                            <- month: this\n" "$argsstr" "$month_this"
    printf "%safter:%s  before:%s         <- month: last\n" "$argsstr" "$month_last" "$month_this"
    printf "%safter:%s  before:%s         <- month: last (extended)\n\n" "$argsstr" "$month_last_extended" "$month_this_extended"

    printf "%safter:%s                            <- year: this\n" "$argsstr" "$year_this"
    printf "%safter:%s  before:%s         <- year: last\n\n" "$argsstr" "$year_last" "$year_this"
}


jwrandnumgen()
{
    if [ $# -ne 1 ] || ! [[ $1 =~ ^[0-9]+$ ]] || [ "$1" -lt 1 ]; then
        echo
        echo "jwrandnumgen  LIMIT"
        echo
        echo "    A small convenience function for generating a pseudo-random integer number from the range of [1, LIMIT]."
        echo "    LIMIT must be a positive integer."
        echo
        return 1
    fi

    # Fresh entropy per call from /dev/urandom (4 bytes -> 32-bit uint), mapped
    # into [1, LIMIT]. One tiny `od` — far cheaper than spawning python, and
    # unlike bare $RANDOM it stays fresh inside `$(...)` capture under zsh (whose
    # command-substitution subshells reuse the parent's RANDOM state, so pure
    # $RANDOM returns a constant for the usual  n=$(jwrandnumgen N)  pattern).
    local rnd
    rnd=$(od -An -N4 -tu4 /dev/urandom | tr -d ' ')
    echo $(( rnd % $1 + 1 ))
}


jwnotatki()
{
    local STEM_N="__notatki__"
    local STEM_K="__komendy__"

    local MODAL=${1:-""}
    [[ -n $MODAL ]] && MODAL+="__"

    echo
    echo "locate $STEM_N | grep $STEM_N"
    echo "locate $STEM_K | grep $STEM_K"

    [[ -n $MODAL ]] && echo
    [[ -n $MODAL ]] && echo "locate $STEM_N | grep $MODAL"
    [[ -n $MODAL ]] && echo "locate $STEM_K | grep $MODAL"

    echo
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


jwpaste() {
    # Dump the current clipboard to a timestamped /tmp file and stream it to stdout

    # 1. Build the timestamped name: /tmp/clip‑dump‑YYYYMMDD‑hhmmss
    local ts file
    ts=$(date '+%Y%m%d-%H%M%S')
    file="/tmp/clip-dump-${ts}"

    # 2. Grab the clipboard content.
    #    • On MXLinux (Debian‑based) the usual utilities are:
    #        - xclip  (X11)
    #        - wl-copy / wl-paste (Wayland)
    #    Choose whichever is available; fall back to the other.
    if command -v xclip >/dev/null 2>&1; then
        # X11: copy primary selection or clipboard (-selection clipboard)
        xclip -selection clipboard -o >"$file"
    elif command -v wl-paste >/dev/null 2>&1; then
        # Wayland: default clipboard
        wl-paste >"$file"
    else
        echo "Error: neither xclip nor wl-paste is installed." >&2
        return 1
    fi

    # 3. Stream the file to stdout (so it can be piped)
    cat "$file"
}


# ------------------------------------------------------------
# jwai_jina – fetch a page via Jina AI and store it as a dated MD file
#
#   Usage:
#     jwai_jina <url> [suffix]
#
#   • <url>    – the URL you want to convert to markdown (required)
#   • suffix   – optional string that will be appended to the file name
#
#   Example:
#     jwai_jina https://opencode.ai/docs demo
#     → Stored to /tmp/jina-dump-20251229-111313-demo.md
# ------------------------------------------------------------
__jwai_jina_usage__() {
    printf 'Usage: jwai_jina <url> [suffix]\n'
    printf '\n'
    printf '  Fetch <url> as Markdown via Jina AI Reader and store it under /tmp.\n'
    printf '\n'
    printf '  <url>    URL to fetch (required)\n'
    printf '  suffix   optional text added before the .md extension\n'
    printf '\n'
    printf 'Example:\n'
    printf '  jwai_jina https://opencode.ai/docs demo\n'
    printf '  → Stored to /tmp/jina-dump-<YYYYMMDD-hhmmss>-demo.md\n'
}

jwai_jina() {
    # ------------------------------------------------------------------
    # Validate arguments
    # ------------------------------------------------------------------
    if [[ $# -eq 0 ]] || [[ "$1" = "-h" ]] || [[ "$1" = "--help" ]]; then
        __jwai_jina_usage__
        [[ $# -eq 0 ]] && return 1 || return 0
    fi

    local url="${1}"
    local suffix="${2:-}"               # empty string if not supplied

    # Very light URL sanity‑check (just makes sure it starts with http(s)://)
    if [[ ! "$url" =~ ^https?:// ]]; then
        printf 'Error: "%s" does not look like a valid URL.\n' "$url" >&2
        __jwai_jina_usage__ >&2
        return 1
    fi

    # ------------------------------------------------------------------
    # Ensure the JINA AI API key is present
    # ------------------------------------------------------------------
    if [[ -z "${JINA_AI_API_KEY:-}" ]]; then
        printf 'Error: JINA_AI_API_KEY is not set in the environment.\n' >&2
        printf 'Please export it before running jwai_jina, e.g.\n' >&2
        printf '  export JINA_AI_API_KEY="your-key-here"\n' >&2
        return 1
    fi

    # ------------------------------------------------------------------
    # Build the output file name
    # ------------------------------------------------------------------
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)    # e.g. 20251229-111313

    local outfile="/tmp/jina-dump-${timestamp}"
    [[ -n "$suffix" ]] && outfile+="-${suffix}"
    outfile+=".md"

    # ------------------------------------------------------------------
    # Perform the request with curl. The key goes in through a
    # process-substitution header file, so it never appears in curl's
    # argv (readable by every local user via ps / /proc).
    # ------------------------------------------------------------------
    curl "https://r.jina.ai/${url}" \
         -H @<(printf 'Authorization: Bearer %s\n' "$JINA_AI_API_KEY") \
         -H "X-Engine: browser" \
         -H "X-With-Generated-Alt: true" \
         -o "$outfile" \
         --fail --silent --show-error

    local curl_exit=$?
    if (( curl_exit != 0 )); then
        # Remove a possibly empty/partial file
        rm -f "$outfile"
        printf 'cURL failed (exit code %d). No file was written.\n' "$curl_exit" >&2
        return $curl_exit
    fi

    # ------------------------------------------------------------------
    # Success message
    # ------------------------------------------------------------------
    printf 'Stored to %s\n' "$outfile"
}


# ------------------------------------------------------------
# jwai_sonar – ask Perplexity Sonar (web-grounded) via OpenRouter, plain-text answer
#
#   Usage:
#     jwai_sonar <question...>
#
#   • routed to Zero Data Retention endpoints only (provider.zdr)
#   • answer printed as plain text: Markdown and [n] citation markers stripped
#   • needs JWSONAR_OR_APIKEY (an OpenRouter API key) in the environment
#
#   Example:
#     jwai_sonar what is the current stable Debian release?
# ------------------------------------------------------------
# `function` keyword on purpose: under zsh the alias below exists on a re-source,
# and `jwai_sonar() {` would then hit "defining function based on alias".
function jwai_sonar {
    if [[ $# -eq 0 ]] || [[ "$1" = "-h" ]] || [[ "$1" = "--help" ]]; then
        printf 'Usage: jwai_sonar <question...>\n'
        printf '\n'
        printf '  Ask Perplexity Sonar (web search) via OpenRouter, ZDR endpoints only.\n'
        printf '  Prints a plain-text answer (no Markdown, no [n] citation markers),\n'
        printf '  in the language of the question. Needs JWSONAR_OR_APIKEY.\n'
        printf '  Quote the question if it contains shell syntax: quotes $ ; | & ( )\n'
        printf '\n'
        printf 'Examples:\n'
        printf '  jwai_sonar what is the current stable Debian release?\n'
        printf "  jwai_sonar \"what's new in curl 8.x?\"\n"
        [[ $# -eq 0 ]] && return 1 || return 0
    fi

    local tool
    for tool in curl jq; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            printf 'Error: %s is not installed.\n' "$tool" >&2
            return 1
        fi
    done

    if [[ -z "${JWSONAR_OR_APIKEY:-}" ]]; then
        printf 'Error: JWSONAR_OR_APIKEY is not set in the environment.\n' >&2
        printf 'Export an OpenRouter API key first, e.g.\n' >&2
        printf '  export JWSONAR_OR_APIKEY="sk-or-v1-..."\n' >&2
        return 1
    fi

    local sys payload resp rc msg answer
    sys='Answer in plain text without Markdown: no asterisks, underscores, # headings, tables or code blocks. Write lists as lines starting with "- ". Do not insert footnote numbers or bracketed source references. Answer in the same language as the question.'
    payload=$(jq -n --arg s "$sys" --arg q "$*" \
        '{model: "perplexity/sonar", provider: {zdr: true},
          messages: [{role: "system", content: $s}, {role: "user", content: $q}]}')

    # The key goes in through a process-substitution header file, so it never
    # appears in curl's argv (readable by every local user via ps / /proc).
    resp=$(curl -sS --connect-timeout 10 --max-time 120 \
        https://openrouter.ai/api/v1/chat/completions \
        -H @<(printf 'Authorization: Bearer %s\n' "$JWSONAR_OR_APIKEY") \
        -H 'Content-Type: application/json' \
        -d "$payload")
    rc=$?
    if (( rc != 0 )); then
        printf 'Error: request to OpenRouter failed (curl exit %d).\n' "$rc" >&2
        return "$rc"
    fi

    if msg=$(jq -er '.error.message' <<< "$resp" 2>/dev/null); then
        printf 'Error: OpenRouter: %s\n' "$msg" >&2
        return 1
    fi
    if ! answer=$(jq -er '.choices[0].message.content' <<< "$resp" 2>/dev/null); then
        printf 'Error: unexpected response from OpenRouter:\n%s\n' "$resp" >&2
        return 1
    fi

    # Strip whatever Markdown / [n] citation markers slip past the system prompt
    printf '%s\n' "$answer" | sed -E 's/\[[0-9]+(, ?[0-9]+)*\]//g; s/\*\*//g; s/^#+ +//; s/`//g'
}

# zsh: let `?` / `*` in an unquoted question reach the function instead of being
# expanded as globs (`jwai_sonar what is X?` → "no matches found")
if [ -n "${ZSH_VERSION:-}" ]; then
    alias jwai_sonar='noglob jwai_sonar'
fi
