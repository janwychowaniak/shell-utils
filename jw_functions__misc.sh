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

    local today=$(date +'%Y/%m/%d')
    local yesterday=$(date --date='yesterday' +'%Y/%m/%d')

    local week_this=$(date --date='last Monday' +'%Y/%m/%d')
    local week_last=$(date --date='last Monday -1 week' +'%Y/%m/%d')

    local reference_day=$(date +'%Y/%m/15')
    local month_this=$(date --date="$reference_day" +'%Y/%m/01')
    local month_last=$(date --date="$reference_day last month" +'%Y/%m/01')

    local year_this=$(date +'%Y/01/01')
    local year_last=$(date --date='last year' +'%Y/01/01')

    local month_this_extended=$(date --date="$month_this +4 days" +'%Y/%m/%d')
    local month_last_extended=$(date --date="$month_last -6 days" +'%Y/%m/%d')

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
    if [ $# -ne 1 ]; then
        echo
        echo "$FUNCNAME  LIMIT"
        echo
        echo "    A small convenience function for generating a pseudo-random integer number from the range of [1, LIMIT]."
        echo
        return 1
    fi
    
    python3 -c \
    "import sys;
LIMIT=sys.argv[1];
from random import randint;
print(randint(0, int(LIMIT)))" "$1"
}


jwdatereverse()
(
    __jwjoinby() { local IFS="$1"; shift; echo "$*"; }

    IFS='-' read -r -a array <<< "$1"
    
    min=0
    max=$(( ${#array[@]} -1 ))

    while [[ min -lt max ]]
    do
        # Swap current first and last elements
        x="${array[$min]}"
        array[$min]="${array[$max]}"
        array[$max]="$x"
    
        # Move closer
        (( min++, max-- ))
    done
    
    echo $(__jwjoinby - ${array[@]})
)


jwnotatki()
{
    local STEM_N="__notatki__"
    local STEM_K="__komendy__"

    local MODAL=${1:-""}
    [[ -n $MODAL ]] && MODAL+="__"

    local FINAL_N="$STEM_N$MODAL"
    local FINAL_K="$STEM_K$MODAL"

    echo
    echo "touch $FINAL_N"
    echo "touch $FINAL_N.md"
    echo "mkdir $FINAL_N"

    echo
    echo "touch $FINAL_K"
    echo "touch $FINAL_K.md"
    echo "mkdir $FINAL_K"

    echo
    echo "locate $STEM_N | grep $STEM_N"
    echo "locate $STEM_K | grep $STEM_K"

    [[ -n $MODAL ]] && echo
    [[ -n $MODAL ]] && echo "locate $STEM_N | grep $MODAL"
    [[ -n $MODAL ]] && echo "locate $STEM_K | grep $MODAL"

    echo
}


jwwhois_creat() {
    # The function presents the creation date of a domain from its WHOIS information

    local whois_output=$(whois "$1")
    echo

    echo "-----[ First grep (creat|date): ]----------------"
    echo "$whois_output" | grep -Ei "creat|date"
    echo

    echo "-----[ Second grep (creat): ]--------------------"
    local creation_output=$(echo "$whois_output" | grep -i creat)
    echo "$creation_output"
    echo

    echo "-----[ Third step (creat, reduced x2): ]---------"
    echo "$creation_output" | awk '{print $1, $2, $3}' | awk -F'T' '{print $1}' | uniq
    echo "$creation_output" | awk '{print $1, $2, substr($3, 1, 10)}' | uniq
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
# jwjina – fetch a page via Jina AI and store it as a dated MD file
#
#   Usage:
#     jwjina <url> [suffix]
#
#   • <url>    – the URL you want to convert to markdown (required)
#   • suffix   – optional string that will be appended to the file name
#
#   Example:
#     jwjina https://opencode.ai/docs demo
#     → Stored to /tmp/jina-dump-20251229-111313-demo.md
# ------------------------------------------------------------
jwjina() {
    # ------------------------------------------------------------------
    # Helper: print a short usage message
    # ------------------------------------------------------------------
    _jwjina_usage() {
        printf 'Usage: %s <url> [suffix]\n' "${FUNCNAME[1]}"
        printf '\n'
        printf '  <url>    URL to fetch (required)\n'
        printf '  suffix   optional text added before the .md extension\n'
        printf '\n'
        printf 'Example:\n'
        printf '  %s https://opencode.ai/docs demo\n' "${FUNCNAME[1]}"
        printf '  → Stored to /tmp/jina-dump-$(date +%%Y%%m%%d-%%H%%M%%S)-demo.md\n' "${FUNCNAME[1]}"
    }

    # ------------------------------------------------------------------
    # Validate arguments
    # ------------------------------------------------------------------
    if [[ $# -eq 0 ]]; then
        _jwjina_usage
        return 1
    fi

    local url="${1}"
    local suffix="${2:-}"               # empty string if not supplied

    # Very light URL sanity‑check (just makes sure it starts with http(s)://)
    if [[ ! "$url" =~ ^https?:// ]]; then
        printf 'Error: "%s" does not look like a valid URL.\n' "$url" >&2
        _jwjina_usage
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
    # Perform the request with curl
    # ------------------------------------------------------------------
    curl "https://r.jina.ai/${url}" \
         -H "Authorization: Bearer ${JINA_AI_API_KEY}" \
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


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


jwtvnames()
{
    DATEHASH=$(date +%Y%m%d)
    SEED=$(( ( RANDOM % 100000 ) + 10000 ))
    NUMER="$DATEHASH$SEED"
    echo "skocznie-$NUMER"
    echo "schodki-$NUMER"
    echo "kanaly-$NUMER"
    echo "hidden-$NUMER"
    echo "inne-$NUMER"
    echo "kilka-$NUMER"
    echo "zagranie-$NUMER"
}

jwtvcrop()
{
    case $# in
    "0")
        echo " *** " $FUNCNAME "arg[s]"
    ;;
    "1")
        local PLIK_IN=$1
        local PLIK_TEMP="$$-"$PLIK_IN
        convert "$PLIK_IN" -crop 1812x823+56+165 "$PLIK_TEMP"
        mv "$PLIK_TEMP" "$PLIK_IN"
    ;;
    *)
        for p in $@
        do
            echo "$p"
            local PLIK_IN=$p
            local PLIK_TEMP="$$-"$PLIK_IN
            convert "$PLIK_IN" -crop 1812x823+56+165 "$PLIK_TEMP"
            mv "$PLIK_TEMP" "$PLIK_IN"
        done
    ;;
    esac
}
