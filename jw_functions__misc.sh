# A collection of miscellaneous functions that are hard to categorize otherwise


jwgoogle()
{
cat 1>&2 <<'EOF'

=================== GOOGLE =================== (notes regarding things I keep forgetting in terms of using the Gmail inbox filters)

 older_than:1d
 newer_than:1d
 newer_than:3d  older_than:2d 
 after:2016/12/31  before:2017/1/7
 after:2017/2/8  before:2017/2/9         <- dokladnie z 8-go

 after:2016/1/1   before:2017/1/1         <- caly 2016
 after:2016/12/1  before:2017/1/1         <- caly grudzien 2016

EOF

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
print(randint(0, int(LIMIT)))" $1
}



jwtvnames()
{
    DATEHASH=`date +%Y%m%d`
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
        convert $PLIK_IN -crop 1812x823+56+165 $PLIK_TEMP
        mv $PLIK_TEMP $PLIK_IN
    ;;
    *)
        for p in $@
        do
            echo $p
            local PLIK_IN=$p
            local PLIK_TEMP="$$-"$PLIK_IN
            convert $PLIK_IN -crop 1812x823+56+165 $PLIK_TEMP
            mv $PLIK_TEMP $PLIK_IN
        done
    ;;
    esac
}


jwdatereverse()
(
	__jwjoinby() { local IFS="$1"; shift; echo "$*"; }

	IFS='-' read -r -a array <<<$1
	
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
