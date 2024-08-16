# A collection of miscellaneous functions that are hard to categorize elsewhere

# ---------------------------------------------------------------------------


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


# ---------------------------------------------------------------------------

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
